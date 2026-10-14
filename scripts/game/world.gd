## One run of one level: fixed-step simulation, pickups, checkpoints, crash/respawn,
## camera and world drawing. Set `bot` to drive it automatically (dev/verify).
extends Node2D

signal run_finished(result: Dictionary)

const Phys := preload("res://scripts/game/bike_physics.gd")
const Library := preload("res://scripts/game/level_library.gd")
const BikeView := preload("res://scripts/game/bike_view.gd")
const Backdrop := preload("res://scripts/game/backdrop.gd")
const Icons := preload("res://scripts/game/icons.gd")
const Catalog := preload("res://scripts/catalog.gd")

const READY_TICKS := 54
const RESPAWN_TICKS := 36
const CRASH_TICKS := 80
const FINISH_TICKS := 80

var level: Dictionary
var level_id := ""
var state: Dictionary
var loadout: Dictionary = {}
var cond: Dictionary = {"time": "dusk", "weather": "clear"}
var theme: Dictionary
var bot = null
var headless := false

var phase := "ready"
var phase_ticks := 0
var first_ready := true
var ticks := 0
var press_queued := false
var held := false

var run_coins := 0
var gears: Array = []
var known_gears: Array = []
var crashes := 0
var stomps := 0
var death_log: Array = []
var result: Dictionary = {}
var _cp: Dictionary = {}
var _next_cp := 0
var _acc := 0.0

var cam: Camera2D
var bike: Node2D
var _angle := 0.0
var _wheel := 0.0
var _squash := 0.0
var _shake := 0.0
var _focus_y := 0.0
var _particles: Array = []
var _floaters: Array = []
var _wreck: Dictionary = {}
var _vis_t := 0.0


## loadout: {"rider", "bike", "paint"} ids. conditions: {"time", "weather"}.
func setup(id: String, rig: Dictionary, known: Array, conditions: Dictionary = {}) -> void:
	level_id = id
	level = Library.build(id)
	loadout = rig
	if not conditions.is_empty():
		cond = conditions
	Phys.apply_weather(level, String(cond.weather))
	theme = Backdrop.theme(level.theme, String(cond.time), String(cond.weather))
	gears = []
	known_gears = []
	for i in level.gear_total:
		gears.append(false)
		known_gears.append(i < known.size() and known[i])
	state = Phys.new_state(level, level.start_x, level.start_track)
	_focus_y = state.y
	_snapshot(level.start_x, level.start_track)


func _ready() -> void:
	if headless:
		return
	cam = Camera2D.new()
	add_child(cam)
	cam.make_current()
	bike = BikeView.new()
	bike.rig = loadout
	add_child(bike)
	cam.position = _cam_target()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		press_queued = true
		held = true
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if event.is_action_released("jump"):
		held = false


func _process(delta: float) -> void:
	if headless:
		return
	_acc += minf(delta, 0.1)
	while _acc >= Phys.DT:
		_acc -= Phys.DT
		tick()
	_vis_t += delta
	_sync_visuals()
	queue_redraw()


func tick() -> void:
	ticks += 1
	match phase:
		"ready":
			phase_ticks += 1
			press_queued = false
			if phase_ticks >= (READY_TICKS if first_ready else RESPAWN_TICKS):
				phase = "ride"
				phase_ticks = 0
				first_ready = false
		"ride":
			_ride_tick()
		"crash":
			phase_ticks += 1
			if not headless:
				_wreck.vel.y += 900.0 * Phys.DT
				_wreck.pos += _wreck.vel * Phys.DT
				_wreck.rot += _wreck.spin * Phys.DT
			if phase_ticks >= CRASH_TICKS:
				_respawn()
		"done":
			phase_ticks += 1
			if state.alive:
				Phys.step(level, state, false, false)
			if phase_ticks == FINISH_TICKS:
				result = {"level_id": level_id, "coins": run_coins, "gears": gears.duplicate(),
					"crashes": crashes, "stomps": stomps, "conditions": cond.duplicate()}
				run_finished.emit(result)
	if not headless:
		_tick_visuals()


func _ride_tick() -> void:
	var pressed := press_queued
	var h := held
	press_queued = false
	if bot != null:
		var d: Array = bot.decide(state)
		pressed = d[0]
		h = d[1]
	var ev := Phys.step(level, state, pressed, h)
	if ev & Phys.EV_JUMP:
		_puff(Vector2(state.x - 6, state.y), 5, Color(theme.deck_hi, 0.9))
	if ev & Phys.EV_LAND:
		_squash = 1.0
		_puff(Vector2(state.x, state.y), 6, Color(theme.deck_hi, 0.9))
		if level.rain:
			_splash(Vector2(state.x, state.y))
	if ev & Phys.EV_STOMP:
		_on_stomp()
	if ev & Phys.EV_DEAD:
		_crash()
		return
	_collect()
	while _next_cp < level.checkpoints.size() and state.x >= level.checkpoints[_next_cp].x:
		var c: Dictionary = level.checkpoints[_next_cp]
		_snapshot(c.x, c.track)
		_next_cp += 1
		_float(Vector2(c.x, state.y - 34), "CHECKPOINT", Color("8ff0a4"))
	if state.x >= level.finish_x:
		phase = "done"
		phase_ticks = 0
		_float(Vector2(state.x + 20, state.y - 40), "FINISH!", Color("fff1a8"))
		_vibrate(40)


func _on_stomp() -> void:
	var ei: int = state.last_stomp
	var e: Dictionary = level.enemies[ei]
	e.alive = false
	e.squash_pos = Phys.enemy_pos(level, e, state.t)
	e.squash_t = _vis_t
	stomps += 1
	run_coins += Catalog.STOMP_COINS
	_float(e.squash_pos + Vector2(0, -16), "+%d" % Catalog.STOMP_COINS, Icons.GOLD)
	_puff(e.squash_pos, 8, Color("fff1a8"))
	_vibrate(25)


func _collect() -> void:
	var br := Phys.bike_rect(state).grow(2.0)
	for pi in Phys.pickups_near(level, state.x):
		var p: Dictionary = level.pickups[pi]
		if not p.alive:
			continue
		var r := 4.0
		match int(p.type):
			Library.P_BAG:
				r = 6.0
			Library.P_GEAR:
				r = 7.0
		if not br.grow(r).has_point(p.pos):
			continue
		p.alive = false
		match int(p.type):
			Library.P_COIN:
				run_coins += 1
				_puff(p.pos, 3, Icons.GOLD_LIGHT)
			Library.P_BAG:
				run_coins += int(p.value)
				_float(p.pos + Vector2(0, -10), "+%d" % int(p.value), Icons.GOLD)
				_puff(p.pos, 8, Icons.GOLD)
			Library.P_GEAR:
				gears[int(p.gear)] = true
				_float(p.pos + Vector2(0, -12), "GEAR!", Icons.BRASS)
				_puff(p.pos, 10, Icons.BRASS)
				_vibrate(30)


func _snapshot(x: float, track: int) -> void:
	var dead_p := {}
	for i in level.pickups.size():
		if not level.pickups[i].alive:
			dead_p[i] = true
	var dead_e := {}
	for i in level.enemies.size():
		if not level.enemies[i].alive:
			dead_e[i] = true
	_cp = {"x": x, "track": track, "coins": run_coins, "gears": gears.duplicate(),
		"stomps": stomps, "dead_p": dead_p, "dead_e": dead_e}


func _crash() -> void:
	phase = "crash"
	phase_ticks = 0
	crashes += 1
	death_log.append({"x": snappedf(state.x, 0.1), "cause": state.death})
	if headless:
		return
	var up := -170.0 if state.death == "hit" else -20.0
	_wreck = {"pos": Vector2(state.x, state.y), "vel": Vector2(float(state.vx) * 0.4, up),
		"rot": _angle, "spin": 10.0}
	_shake = 5.0
	_puff(Vector2(state.x, state.y - 8), 14, Color("ffb347"))
	_puff(Vector2(state.x, state.y - 8), 8, Color("e8e2d0"))
	_vibrate(70)


func _respawn() -> void:
	run_coins = _cp.coins
	gears = _cp.gears.duplicate()
	stomps = _cp.stomps
	for i in level.pickups.size():
		level.pickups[i].alive = not _cp.dead_p.has(i)
	for i in level.enemies.size():
		var e: Dictionary = level.enemies[i]
		e.alive = not _cp.dead_e.has(i)
		if e.alive:
			e.erase("squash_t")
	state = Phys.new_state(level, _cp.x, _cp.track, state.t)
	_focus_y = state.y
	phase = "ready"
	phase_ticks = 0


func _vibrate(ms: int) -> void:
	if not headless and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)


# --- visuals ---------------------------------------------------------------

func _tick_visuals() -> void:
	if phase == "ride" or phase == "done":
		_wheel += float(state.vx) * Phys.DT / 4.0
		var target := atan(state.slope) if state.grounded else clampf(state.vy * 0.0011, -0.42, 0.5)
		_angle = lerp_angle(_angle, target, 0.3)
		if state.grounded:
			_focus_y = lerpf(_focus_y, state.y, 0.15)
			var sliding: bool = level.rain and float(state.vx) > float(level.speed) + 4.0
			if sliding and ticks % 2 == 0:
				# Rooster tail of spray while the tyre skids on the wet deck.
				_particles.append({"p": Vector2(state.x - 10, state.y - 1),
					"v": Vector2(randf_range(-70, -30), randf_range(-60, -25)),
					"life": 16, "max": 16, "c": Color(0.75, 0.88, 1.0, 0.85), "s": 1.0, "g": 260.0})
			elif ticks % 5 == 0:
				_particles.append({"p": Vector2(state.x - 11, state.y - 1), "v": Vector2(-30, -12),
					"life": 18, "max": 18, "c": Color(theme.deck_hi, 0.6), "s": 1.0, "g": 0.0})
		else:
			_focus_y = lerpf(_focus_y, state.y, 0.04)
	_squash = maxf(0.0, _squash - 0.12)
	_shake = maxf(0.0, _shake - 0.35)
	for p in _particles:
		p.v.y += p.g * Phys.DT
		p.p += p.v * Phys.DT
		p.life -= 1
	_particles = _particles.filter(func(p): return p.life > 0)
	for f in _floaters:
		f.p.y -= 0.4
		f.life -= 1
	_floaters = _floaters.filter(func(f): return f.life > 0)
	if cam and phase != "crash":
		var tgt := _cam_target()
		cam.position.x = tgt.x
		cam.position.y = lerpf(cam.position.y, tgt.y, 0.1)


func _cam_target() -> Vector2:
	var vs := get_viewport_rect().size
	return Vector2(state.x + vs.x * 0.22, _focus_y - vs.y * 0.08)


func _sync_visuals() -> void:
	if bike == null:
		return
	if phase == "crash":
		bike.position = _wreck.pos
		bike.rotation = _wreck.rot
	else:
		bike.position = Vector2(state.x, state.y)
		bike.rotation = _angle
	bike.visible = not (phase == "ready" and not first_ready and int(_vis_t * 10.0) % 2 == 0)
	bike.wheel_angle = _wheel
	bike.squash = _squash
	bike.lean = clampf(-state.vy * 0.006, -1.0, 2.0) if not state.grounded else 0.0
	var gust := Phys.wind_at(level, state.t) / Phys.WIND_PEAK
	bike.flutter = clampf(0.35 + gust * 0.65 + (0.15 if not state.grounded else 0.0), 0.0, 1.0)
	if gust > 0.0 and not state.grounded:
		bike.lean += gust * 1.5
	bike.anim_t = _vis_t
	bike.queue_redraw()
	if cam:
		cam.offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake)) if _shake > 0.3 else Vector2.ZERO


func _puff(at: Vector2, n: int, c: Color) -> void:
	if headless:
		return
	for i in n:
		var a := randf() * TAU
		var sp := randf_range(20.0, 70.0)
		_particles.append({"p": at, "v": Vector2(cos(a), sin(a)) * sp + Vector2(0, -20),
			"life": 22, "max": 22, "c": c, "s": 1.0 + float(randi() % 2), "g": 160.0})


func _splash(at: Vector2) -> void:
	for i in 10:
		var dir := -1.0 if i % 2 == 0 else 1.0
		_particles.append({"p": at + Vector2(dir * 3, -1),
			"v": Vector2(dir * randf_range(20, 70), randf_range(-90, -40)),
			"life": 20, "max": 20, "c": Color(0.75, 0.88, 1.0, 0.9), "s": 1.0, "g": 320.0})


func _float(at: Vector2, text: String, c: Color) -> void:
	if headless:
		return
	_floaters.append({"p": at, "text": text, "c": c, "life": 50, "max": 50})


func _draw() -> void:
	if cam == null:
		return
	var vs := get_viewport_rect().size
	var c := cam.position
	var left := c.x - vs.x * 0.5 - 48.0
	var right := c.x + vs.x * 0.5 + 48.0
	var bottom := c.y + vs.y * 0.5 + 8.0
	_draw_tracks(left, right, bottom)
	_draw_markers(left, right)
	_draw_pickups(left, right)
	_draw_enemies(left, right)
	if theme.time == "night" and phase != "crash":
		_draw_headlight()
	for p in _particles:
		draw_rect(Rect2(floorf(p.p.x), floorf(p.p.y), p.s, p.s), Color(p.c, p.c.a * float(p.life) / p.max))
	var font: Font = GameState.font
	for f in _floaters:
		var a := clampf(float(f.life) / 15.0, 0.0, 1.0)
		draw_string(font, Vector2(f.p.x - 60 + 1, f.p.y + 1), f.text, HORIZONTAL_ALIGNMENT_CENTER, 120, 8, Color(0, 0, 0, a))
		draw_string(font, Vector2(f.p.x - 60, f.p.y), f.text, HORIZONTAL_ALIGNMENT_CENTER, 120, 8, Color(f.c, a))


func _draw_tracks(left: float, right: float, bottom: float) -> void:
	var beam: Color = theme.beam
	var brace: Color = theme.beam_dark
	for tr in level.tracks:
		if tr.x1 < left or tr.x0 > right:
			continue
		var px := ceilf(maxf(tr.x0 + 4.0, left) / 32.0) * 32.0
		var stop := minf(tr.x1 - 4.0, right)
		while px <= stop:
			var ty := Phys.height_at(tr, px)
			draw_rect(Rect2(px - 1, ty + 4, 3, bottom - ty), beam)
			if px + 32.0 <= tr.x1:
				var ty2 := Phys.height_at(tr, px + 32.0)
				draw_line(Vector2(px, ty + 8), Vector2(px + 32, ty2 + 28), brace, -1.0)
				draw_line(Vector2(px + 32, ty2 + 8), Vector2(px, ty + 28), brace, -1.0)
				draw_line(Vector2(px, ty + 28), Vector2(px + 32, ty2 + 28), brace, -1.0)
			px += 32.0
	for tr in level.tracks:
		if tr.x1 < left or tr.x0 > right:
			continue
		var pts: PackedVector2Array = tr.pts
		for i in pts.size() - 1:
			var a := pts[i]
			var b := pts[i + 1]
			if b.x < left or a.x > right:
				continue
			draw_colored_polygon(PackedVector2Array([a, b, b + Vector2(0, 5), a + Vector2(0, 5)]), theme.deck)
			draw_line(a, b, theme.deck_hi, -1.0)
			draw_line(a + Vector2(0, 5), b + Vector2(0, 5), brace, -1.0)
			var rx := ceilf(a.x / 8.0) * 8.0
			while rx < b.x:
				var ry := a.y + (b.y - a.y) * (rx - a.x) / (b.x - a.x)
				draw_rect(Rect2(rx, ry + 2, 1, 1), brace)
				rx += 8.0
		var s := pts[0]
		var e := pts[pts.size() - 1]
		draw_rect(Rect2(s.x - 1, s.y - 1, 3, 7), brace)
		draw_rect(Rect2(e.x - 2, e.y - 1, 3, 7), brace)


func _draw_markers(left: float, right: float) -> void:
	for i in level.checkpoints.size():
		var c: Dictionary = level.checkpoints[i]
		if c.x < left or c.x > right:
			continue
		var ty := Phys.height_at(level.tracks[c.track], c.x)
		var reached: bool = i < _next_cp
		draw_line(Vector2(c.x, ty), Vector2(c.x, ty - 28), Color("d8d8d8"), -1.0)
		var wave := sin(_vis_t * 6.0) * 1.5
		var col := Color("5bd16a") if reached else Color("e04848")
		draw_colored_polygon(PackedVector2Array([Vector2(c.x + 1, ty - 28), Vector2(c.x + 12, ty - 24 + wave),
			Vector2(c.x + 1, ty - 20)]), col)
	var fx: float = level.finish_x
	if fx > left - 40 and fx < right + 40:
		var tr_y := _ground_y(fx)
		for sx in [fx - 22.0, fx + 22.0]:
			draw_rect(Rect2(sx - 1, tr_y - 46, 3, 46), Color("d8d8d8"))
		for i in 22:
			for j in 4:
				var col := Color("f4f4f4") if (i + j) % 2 == 0 else Color("1a1a1a")
				draw_rect(Rect2(fx - 22 + i * 2, tr_y - 50 + j * 2, 2, 2), col)


func _ground_y(px: float) -> float:
	for ti in Phys.tracks_near(level, px):
		var tr: Dictionary = level.tracks[ti]
		if px >= tr.x0 and px <= tr.x1 and not tr.side:
			return Phys.height_at(tr, px)
	return state.y


func _draw_pickups(left: float, right: float) -> void:
	for p in level.pickups:
		if not p.alive or p.pos.x < left or p.pos.x > right:
			continue
		var pos: Vector2 = p.pos
		match int(p.type):
			Library.P_COIN:
				Icons.coin(self, pos.floor(), cos(_vis_t * 5.0 + pos.x * 0.05))
			Library.P_BAG:
				Icons.bag(self, pos.floor() + Vector2(0, sin(_vis_t * 3.0) * 1.5).floor())
			Library.P_GEAR:
				var ghost: bool = known_gears[int(p.gear)]
				var bob := Vector2(0, roundf(sin(_vis_t * 2.5) * 2.0))
				if not ghost:
					draw_circle(pos + bob, 10.0, Color(Icons.BRASS, 0.18 + 0.08 * sin(_vis_t * 4.0)))
				Icons.gear(self, pos + bob, 6.0, _vis_t * 1.5, true, 0.4 if ghost else 1.0)


func _draw_enemies(left: float, right: float) -> void:
	for e in level.enemies:
		if not e.alive:
			if e.has("squash_t") and _vis_t - e.squash_t < 0.5:
				var sp: Vector2 = e.squash_pos
				draw_rect(Rect2(sp.x - 8, sp.y - 3, 16, 3), Color("7a3a16"))
				draw_rect(Rect2(sp.x - 7, sp.y - 4, 14, 1), Color("c8692a"))
			continue
		var p := Phys.enemy_pos(level, e, state.t)
		if p.x < left or p.x > right:
			continue
		var glow := Vector2.INF
		match int(e.type):
			Phys.CRAWLER:
				var ahead := Phys.enemy_pos(level, e, state.t + 0.05)
				var face := -1.0 if ahead.x <= p.x else 1.0
				_draw_crawler(p.floor(), face)
				glow = p.floor() + Vector2(face * 5.0, -4)
			Phys.SPIKER:
				_draw_spiker(p.floor())
				glow = p.floor() + Vector2(0, -6)
			Phys.DRONE:
				_draw_drone(p.floor())
				glow = p.floor() + Vector2(-4, 0)
		if theme.time == "night" and glow != Vector2.INF:
			draw_circle(glow, 4.0, Color(1.0, 0.35, 0.25, 0.22 + 0.08 * sin(_vis_t * 6.0)))


func _draw_crawler(p: Vector2, face: float) -> void:
	var step := int(_vis_t * 8.0) % 2
	for i in 3:
		var lx := p.x - 5 + i * 5
		draw_rect(Rect2(lx + (step if i % 2 == 0 else 1 - step), p.y - 2, 1, 2), Color("3a1c10"))
	var shell := PackedVector2Array()
	for i in 9:
		var a := PI * float(i) / 8.0
		shell.append(p + Vector2(cos(a) * 7.0, -2.0 - sin(a) * 7.0))
	draw_colored_polygon(shell, Color("7a3a16"))
	var inner := PackedVector2Array()
	for i in 9:
		var a := PI * float(i) / 8.0
		inner.append(p + Vector2(cos(a) * 5.5, -2.5 - sin(a) * 5.5))
	draw_colored_polygon(inner, Color("c8692a"))
	draw_rect(Rect2(p.x - 3, p.y - 8, 2, 1), Color("f0a060"))
	draw_line(Vector2(p.x, p.y - 8), Vector2(p.x, p.y - 3), Color("7a3a16"), -1.0)
	var ex := p.x + face * 5.0
	draw_rect(Rect2(ex - 1, p.y - 5, 2, 2), Color("f4f4f4"))
	draw_rect(Rect2(ex + (0 if face > 0 else -1), p.y - 5, 1, 1), Color("111111"))


func _draw_spiker(p: Vector2) -> void:
	var c := p + Vector2(0, -6)
	var spin := _vis_t * 1.5
	for i in 8:
		var a := spin + i * TAU / 8.0
		var d := Vector2(cos(a), sin(a))
		var n := Vector2(-d.y, d.x)
		draw_colored_polygon(PackedVector2Array([c + d * 4.0 + n * 1.5, c + d * 8.5, c + d * 4.0 - n * 1.5]), Color("e8e2d0"))
	draw_circle(c, 5.0, Color("2a2433"))
	draw_circle(c, 3.0, Color("3b3346"))
	draw_rect(Rect2(c.x - 1, c.y - 1, 2, 2), Color("ff4a4a", 0.6 + 0.4 * sin(_vis_t * 8.0)))


func _draw_drone(p: Vector2) -> void:
	var w := roundf(9.0 * absf(cos(_vis_t * 30.0))) + 1.0
	draw_line(Vector2(p.x, p.y - 4), Vector2(p.x, p.y - 7), Color("4a4f5c"), -1.0)
	draw_rect(Rect2(p.x - w, p.y - 8, w * 2, 1), Color("c9d1d9"))
	for i in 3:
		var sx := p.x - 5 + i * 5
		draw_colored_polygon(PackedVector2Array([Vector2(sx - 1, p.y - 3), Vector2(sx, p.y - 6), Vector2(sx + 1, p.y - 3)]), Color("e8e2d0"))
	draw_rect(Rect2(p.x - 7, p.y - 3, 14, 6), Color("4a4f5c"))
	draw_rect(Rect2(p.x - 6, p.y - 3, 12, 4), Color("8a93a6"))
	draw_rect(Rect2(p.x - 6, p.y + 2, 12, 1), Color("2a2d36"))
	var blink := 1.0 if int(_vis_t * 3.0) % 4 != 0 else 0.3
	draw_rect(Rect2(p.x - 5, p.y - 1, 2, 2), Color(1.0, 0.25, 0.2, blink))


## Night: a warm cone from the headlight and glowing eyes on enemies.
func _draw_headlight() -> void:
	var o := Vector2(state.x, state.y)
	var rot := Transform2D(_angle, Vector2.ZERO)
	var src := o + rot * Vector2(8, -12)
	var fwd := rot * Vector2(1, 0)
	var side := rot * Vector2(0, 1)
	var far := src + fwd * 130.0
	draw_colored_polygon(PackedVector2Array([src - side * 2.0, far - side * 22.0, far + side * 30.0, src + side * 2.0]),
		Color(1.0, 0.93, 0.65, 0.07))
	var mid := src + fwd * 70.0
	draw_colored_polygon(PackedVector2Array([src - side * 1.5, mid - side * 9.0, mid + side * 14.0, src + side * 1.5]),
		Color(1.0, 0.93, 0.65, 0.09))

