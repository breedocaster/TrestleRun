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
const Art := preload("res://scripts/game/feature_art.gd")

const SWOOP_SETTLE := 190.0
const SWOOP_RANGE := 170.0
const READY_TICKS := 54
const RESPAWN_TICKS := 36
const CRASH_TICKS := 80
const FINISH_TICKS := 80
# Bonus biplane: overtakes from behind with a prize sack you can jump for.
const PLANE_REL := 75.0      # px/s faster than the trail's cruise speed
const PLANE_PRIZE_H := 68.0  # sack height above the deck where it meets you
const PLANE_ROPE := 22.0
# Rear wheel x per bike model (wheelies pivot here).
const REAR_WHEEL := {"scrambler": -8.0, "dirt": -9.0, "minibike": -6.0, "scooter": -7.0,
	"cafe": -8.0, "chopper": -11.0, "sport": -8.0}

var level: Dictionary
var level_id := ""
var state: Dictionary
var loadout: Dictionary = {}
var ability: Dictionary = {}
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
var smashes := 0
var loops_done := 0
var quiet := false
## Bonus planes fly over now and then (off in dev runs and hint demos).
var bonus_planes := true
var planes_seen := 0
var planes_caught := 0
var ride_time := 0.0
## Button state the sim used this tick (player or autopilot).
var held_now := false
var plane: Dictionary = {}
var _next_plane_t := 0.0
var _rng := RandomNumberGenerator.new()
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
var _wheelie_a := 0.0
var _umbrella := 0.0
var _trail: Array = []


## loadout: {"rider", "bike", "paint"} ids. conditions: {"time", "weather"}.
func setup(id: String, rig: Dictionary, known: Array, conditions: Dictionary = {}, custom: Dictionary = {}) -> void:
	level_id = id
	level = Library.build(id) if custom.is_empty() else custom
	loadout = rig
	ability = Catalog.ability(String(rig.get("bike", "scrambler")))
	if rig.has("ability"):
		ability = rig.ability
	if not conditions.is_empty():
		cond = conditions
	Phys.apply_weather(level, String(cond.weather))
	theme = Backdrop.theme(level.theme, String(cond.time), String(cond.weather))
	gears = []
	known_gears = []
	for i in level.gear_total:
		gears.append(false)
		known_gears.append(i < known.size() and known[i])
	state = Phys.new_state(level, level.start_x, level.start_track, 0.0, ability)
	_rng.seed = hash(id) ^ Time.get_ticks_usec()
	_next_plane_t = _rng.randf_range(9.0, 16.0)
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
	if bot != null:
		return
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
	if phase == "ride" or phase == "done" or phase == "ready":
		if _audio_on():
			var wheels_down: bool = (state.grounded or int(state.loop) >= 0) and int(state.zip) < 0
			AudioDirector.engine_update(delta, wheels_down, float(state.vx) / float(level.speed))
	if _audio_on():
		if plane.is_empty() or cam == null:
			AudioDirector.plane_set(false)
		else:
			var dx: float = float(plane.x) - cam.position.x
			var half := get_viewport_rect().size.x * 0.5
			AudioDirector.plane_set(true, 1.0 - clampf((absf(dx) - 30.0) / (half + 140.0), 0.0, 1.0), clampf(-dx / 80.0, -1.0, 1.0))
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
				if _audio_on():
					AudioDirector.engine_ride()
		"ride":
			ride_time += Phys.DT
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
					"crashes": crashes, "stomps": stomps, "conditions": cond.duplicate(),
					"time": snappedf(ride_time, 0.1), "planes": planes_caught, "planes_seen": planes_seen,
					"bike": String(loadout.get("bike", ""))}
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
	held_now = h
	var ev := Phys.step(level, state, pressed, h)
	if ev & Phys.EV_JUMP:
		_puff(Vector2(state.x - 6, state.y), 5, Color(theme.deck_hi, 0.9))
		_sfx("jump", randf_range(0.94, 1.06))
	if ev & Phys.EV_LAND:
		_squash = 1.0
		_puff(Vector2(state.x, state.y), 6, Color(theme.deck_hi, 0.9))
		_sfx("land", randf_range(0.92, 1.05))
		if level.rain:
			_splash(Vector2(state.x, state.y))
			_sfx("splash", randf_range(0.9, 1.1), -2.0)
	if ev & Phys.EV_STOMP:
		_on_stomp()
	if ev & Phys.EV_SMASH:
		_on_smash()
	_feature_events(ev)
	if ev & Phys.EV_DEAD:
		_crash()
		return
	_collect()
	if bonus_planes and not headless:
		_plane_tick()
	while _next_cp < level.checkpoints.size() and state.x >= level.checkpoints[_next_cp].x:
		var c: Dictionary = level.checkpoints[_next_cp]
		_snapshot(c.x, c.track)
		_next_cp += 1
		_float(Vector2(c.x, state.y - 34), "CHECKPOINT", Color("8ff0a4"))
		_sfx("checkpoint")
	if state.x >= level.finish_x:
		phase = "done"
		phase_ticks = 0
		_float(Vector2(state.x + 20, state.y - 40), "FINISH!", Color("fff1a8"))
		_vibrate(40)
		_sfx("finish")
		if _audio_on():
			AudioDirector.engine_coast()


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
	_sfx("stomp", randf_range(0.95, 1.05))


func _on_smash() -> void:
	var ei: int = state.last_smash
	var e: Dictionary = level.enemies[ei]
	if not e.alive:
		return
	e.alive = false
	e.squash_pos = Phys.enemy_pos(level, e, state.t)
	e.squash_t = _vis_t
	e.smashed = true
	smashes += 1
	_float(e.squash_pos + Vector2(0, -18), "SMASH!", Color("ffb347"))
	_puff(e.squash_pos, 12, Color("ffb347"))
	_puff(e.squash_pos, 6, Color("e8e2d0"))
	_shake = 3.0
	_vibrate(45)
	_sfx("smash", randf_range(0.95, 1.05))


## Sounds and effects for springs, tunnels, loops, ziplines and specialties.
func _feature_events(ev: int) -> void:
	if ev & Phys.EV_SPRING:
		_squash = 1.0
		_puff(Vector2(state.x, state.y), 6, Color("fff1a8"))
		_sfx("spring", randf_range(0.97, 1.03))
		var sp: Dictionary = level.springs[state.spring]
		sp.fired = _vis_t
	if ev & Phys.EV_BONK:
		_shake = 2.5
		_puff(Vector2(state.x, state.y - Phys.HEIGHT), 6, Color("c9b28a"))
		_float(Vector2(state.x, state.y - 30), "BONK!", Color("ffd27a"))
		_sfx("bonk", randf_range(0.95, 1.05))
		_vibrate(30)
	if ev & Phys.EV_LOOP:
		_sfx("loop")
		loops_done += 1
	if ev & Phys.EV_ZIP:
		_sfx("zip_grab")
		if _audio_on():
			AudioDirector.zip_on(true)
	if ev & Phys.EV_UNZIP:
		if _audio_on():
			AudioDirector.zip_on(false)
	if ev & Phys.EV_AIR:
		_puff(Vector2(state.x - 4, state.y), 6, Color("e8e2d0"))
		_sfx("jump", 1.25 if state.ab == "hop" else 0.8, 1.0)
		if state.ab == "dash":
			_sfx("dash")
	if ev & Phys.EV_WHEELIE:
		_sfx("wheelie", randf_range(0.97, 1.03), -3.0)
	if ev & Phys.EV_ARMOR:
		_float(Vector2(state.x, state.y - 30), "HIDE READY", Color("cfd6e0"))


func _collect() -> void:
	var br := Phys.bike_rect(state, level).grow(2.0)
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
				if _audio_on():
					AudioDirector.coin()
			Library.P_BAG:
				run_coins += int(p.value)
				_float(p.pos + Vector2(0, -10), "+%d" % int(p.value), Icons.GOLD)
				_puff(p.pos, 8, Icons.GOLD)
				_sfx("bag")
			Library.P_GEAR:
				gears[int(p.gear)] = true
				_float(p.pos + Vector2(0, -12), "GEAR!", Icons.BRASS)
				_puff(p.pos, 10, Icons.BRASS)
				_vibrate(30)
				_sfx("gear")


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
	_sfx("crash")
	if _audio_on():
		AudioDirector.engine_cut()
		AudioDirector.zip_on(false)
	plane = {}


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
	state = Phys.new_state(level, _cp.x, _cp.track, state.t, ability)
	_focus_y = state.y
	phase = "ready"
	phase_ticks = 0
	if _audio_on():
		AudioDirector.engine_start(String(loadout.get("bike", "scrambler")))


func _audio_on() -> bool:
	return not headless and not quiet


func _sfx(sfx_name: String, pitch := 1.0, vol_db := 0.0) -> void:
	if _audio_on():
		AudioDirector.play(sfx_name, pitch, vol_db)


func _vibrate(ms: int) -> void:
	if not headless and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)


# --- bonus plane -------------------------------------------------------------

## Every so often a biplane overtakes you trailing a prize sack. It is only sent
## when the stretch where it will catch up with you is calm (plain deck, nothing
## to dodge), and the sack hangs at a height a good long jump reaches.
func _plane_tick() -> void:
	if plane.is_empty():
		if state.t < _next_plane_t or not state.grounded or int(state.zip) >= 0:
			return
		var vs := get_viewport_rect().size
		var lead: float = vs.x * 0.28 + 40.0
		var v: float = level.speed
		# Pick where it catches up with you: the first calm stretch ahead (240-500 px).
		# Its speed is set so the sack arrives right there.
		var meet_x := -1.0
		var d := 240.0
		var d_max := lead * v / 45.0  # slowest overtake we allow
		while d <= d_max:
			if _calm(state.x + d - 60.0, state.x + d + 130.0):
				meet_x = state.x + d
				break
			d += 30.0
		if meet_x < 0.0:
			_next_plane_t = state.t + 0.5
			return
		var rel := clampf(lead * v / (meet_x - state.x), 45.0, 130.0)
		var gy := _ground_y(meet_x)
		plane = {"x": state.x - lead, "y": gy - PLANE_PRIZE_H - PLANE_ROPE - 2.0, "v": v + rel,
			"prize": true, "value": 10 + 3 * maxi(0, Catalog.level_index(level_id)), "waggle": 0.0}
		planes_seen += 1
		_next_plane_t = state.t + _rng.randf_range(22.0, 38.0)
		return
	plane.x += float(plane.v) * Phys.DT
	plane.waggle = maxf(0.0, float(plane.waggle) - Phys.DT)
	if plane.prize and phase == "ride":
		var sack := prize_pos()
		if Phys.bike_rect(state, level).grow(7.0).has_point(sack):
			plane.prize = false
			plane.waggle = 1.2
			planes_caught += 1
			run_coins += int(plane.value)
			_float(sack + Vector2(0, -12), "+%d BONUS!" % int(plane.value), Icons.GOLD)
			_puff(sack, 14, Icons.GOLD)
			_vibrate(40)
			_sfx("prize")
	if float(plane.x) > state.x + get_viewport_rect().size.x + 120.0:
		plane = {}


func prize_pos() -> Vector2:
	return Vector2(float(plane.x) - 6.0, float(plane.y) + 4.0 + PLANE_ROPE + 6.0)


## Plain main deck from xa to xb: level, unbroken, nothing to jump or dodge.
func _calm(xa: float, xb: float) -> bool:
	if xb > float(level.finish_x) - 40.0 or xa < float(level.start_x) + 200.0:
		return false
	var last := INF
	var px := xa
	while px <= xb:
		var gy := INF
		for ti in Phys.tracks_near(level, px):
			var tr: Dictionary = level.tracks[ti]
			if px < tr.x0 or px > tr.x1:
				continue
			if tr.side or tr.has("lift"):
				return false
			gy = Phys.height_at(tr, px)
		if gy == INF or (last != INF and absf(gy - last) > 2.0):
			return false
		last = gy
		px += 8.0
	for e in level.enemies:
		var lo: float = float(e.x0) - 24.0 - float(e.get("drift", 0.0))
		var hi: float = float(e.get("x1", e.x0)) + 24.0
		if hi > xa and lo < xb:
			return false
	for sp in level.springs:
		if sp.x > xa - 30.0 and sp.x < xb + 30.0:
			return false
	for L in level.loops:
		if float(L.x) + float(L.shift) + float(L.r) > xa and float(L.x) - float(L.r) < xb:
			return false
	for c in level.ceils:
		if c.x1 > xa - 30.0 and c.x0 < xb + 30.0:
			return false
	for z in level.zips:
		if z.x1 > xa and z.x0 < xb:
			return false
	return true


# --- visuals ---------------------------------------------------------------

func _tick_visuals() -> void:
	if phase == "ride" or phase == "done":
		_wheel += float(state.vx) * Phys.DT / 4.0
		var target := atan(state.slope) if state.grounded else clampf(state.vy * 0.0011, -0.42, 0.5)
		if int(state.loop) >= 0:
			target = Phys.loop_angle(level.loops[state.loop], state.loop_a)
			_angle = target
		elif int(state.zip) >= 0:
			target = atan(state.slope) + sin(_vis_t * 5.0) * 0.06
		_angle = lerp_angle(_angle, target, 0.3)
		_wheelie_a = lerpf(_wheelie_a, -0.34 if state.wheelie else 0.0, 0.2)
		_umbrella = move_toward(_umbrella, 1.0 if (state.ab == "glide" and held_now and not state.grounded and float(state.vy) > 0.0 and int(state.zip) < 0) else 0.0, 0.18)
		var fast: bool = float(state.dash_t) > 0.0 or (state.ab == "wheelie" and float(state.boost) > float(level.speed) * 0.05)
		if fast and ticks % 2 == 0:
			_trail.append({"p": Vector2(state.x, state.y), "a": _angle + _wheelie_a, "life": 10})
		for tp in _trail:
			tp.life -= 1
		_trail = _trail.filter(func(tp): return tp.life > 0)
		if state.wheelie and ticks % 3 == 0:
			_particles.append({"p": Vector2(state.x + float(REAR_WHEEL.get(String(loadout.get("bike", "scrambler")), -8.0)) - 2, state.y - 1),
				"v": Vector2(randf_range(-60, -30), randf_range(-30, -10)), "life": 16, "max": 16,
				"c": Color(theme.deck_hi, 0.7), "s": 1.0, "g": 80.0})
		if int(state.loop) >= 0 or int(state.zip) >= 0:
			pass
		elif state.grounded:
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
		var base := Vector2(state.x, state.y)
		var rot := _angle
		if absf(_wheelie_a) > 0.01:
			# Pivot round the rear wheel so it stays planted on the deck.
			var rear := Vector2(float(REAR_WHEEL.get(String(loadout.get("bike", "scrambler")), -8.0)), 0.0)
			base += rear.rotated(_angle) - rear.rotated(_angle + _wheelie_a)
			rot += _wheelie_a
		bike.position = base
		bike.rotation = rot
	bike.visible = not (phase == "ready" and not first_ready and int(_vis_t * 10.0) % 2 == 0)
	bike.wheel_angle = _wheel
	bike.squash = _squash
	bike.lean = clampf(-state.vy * 0.006, -1.0, 2.0) if not state.grounded else 0.0
	if int(state.loop) >= 0 or int(state.zip) >= 0:
		bike.lean = 0.0
	var gust := Phys.wind_at(level, state.t) / Phys.WIND_PEAK
	bike.flutter = clampf(0.35 + gust * 0.65 + (0.15 if not state.grounded else 0.0), 0.0, 1.0)
	if gust > 0.0 and not state.grounded:
		bike.lean += gust * 1.5
	bike.umbrella = _umbrella
	bike.hanging = int(state.zip) >= 0
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
	var top := c.y - vs.y * 0.5 - 8.0
	var bottom := c.y + vs.y * 0.5 + 8.0
	var night: bool = theme.time == "night"
	for cl in level.ceils:
		if cl.x1 > left and cl.x0 < right:
			Art.tunnel_back(self, cl, theme, bottom, _vis_t, night)
	_draw_tracks(left, right, bottom)
	for L in level.loops:
		if float(L.x) + 90.0 > left and float(L.x) - 60.0 < right:
			Art.loop(self, L, theme, bottom)
	for cl in level.ceils:
		if cl.x1 > left - 40.0 and cl.x0 < right + 40.0:
			Art.tunnel_front(self, cl, theme, top)
	for sp in level.springs:
		if sp.x > left and sp.x < right:
			Art.spring(self, sp.x, Phys.height_at(level.tracks[sp.track], sp.x), _vis_t - float(sp.get("fired", -10.0)))
	for z in level.zips:
		if z.x1 > left and z.x0 < right:
			Art.zip(self, z, _ground_y_or(z.x0, bottom), _ground_y_or(z.x1, bottom), theme)
	_draw_markers(left, right)
	_draw_pickups(left, right)
	_draw_enemies(left, right)
	if not plane.is_empty():
		if plane.prize:
			var sack := prize_pos()
			var gy := _ground_y(sack.x)
			draw_circle(Vector2(sack.x, gy - 1), 4.0, Color(0, 0, 0, 0.22))
		Art.plane(self, Vector2(plane.x, plane.y), _vis_t, PLANE_ROPE, plane.prize, sin(float(plane.waggle) * 14.0) * float(plane.waggle) * 3.0)
	for tp in _trail:
		var k: float = float(tp.life) / 10.0
		draw_set_transform(tp.p, tp.a)
		draw_rect(Rect2(-12, -14, 22, 10), Color(1.0, 0.95, 0.8, 0.12 * k))
		draw_set_transform(Vector2.ZERO)
	if int(state.zip) >= 0 and phase != "crash":
		var z: Dictionary = level.zips[state.zip]
		var grip := Vector2(state.x + 4.0, state.y - Phys.HEIGHT - 1.0)
		Art.trolley(self, Vector2(state.x + 4.0, Phys.cable_y(z, state.x + 4.0)), grip)
	if state.ab == "tough" and int(state.armor) > 0 and phase == "ride":
		var sp2 := Vector2(state.x - 2, state.y - 26).floor()
		draw_arc(sp2, 3.0, 0.0, TAU, 10, Color(0.85, 0.9, 1.0, 0.55 + 0.25 * sin(_vis_t * 4.0)), -1.0)
	if night and phase != "crash":
		_draw_headlight()
	for p in _particles:
		draw_rect(Rect2(floorf(p.p.x), floorf(p.p.y), p.s, p.s), Color(p.c, p.c.a * float(p.life) / p.max))
	var font: Font = GameState.font
	for f in _floaters:
		var a := clampf(float(f.life) / 15.0, 0.0, 1.0)
		draw_string(font, Vector2(f.p.x - 60 + 1, f.p.y + 1), f.text, HORIZONTAL_ALIGNMENT_CENTER, 120, 8, Color(0, 0, 0, a))
		draw_string(font, Vector2(f.p.x - 60, f.p.y), f.text, HORIZONTAL_ALIGNMENT_CENTER, 120, 8, Color(f.c, a))


func _ground_y_or(px: float, fallback: float) -> float:
	for ti in Phys.tracks_near(level, px):
		var tr: Dictionary = level.tracks[ti]
		if px >= tr.x0 and px <= tr.x1 and not tr.side:
			return Phys.height_at(tr, px)
	return fallback


func _draw_tracks(left: float, right: float, bottom: float) -> void:
	var beam: Color = theme.beam
	var brace: Color = theme.beam_dark
	for tr in level.tracks:
		if tr.x1 < left or tr.x0 > right or tr.has("lift"):
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
		if tr.has("lift"):
			Art.lift(self, tr, Phys.lift_dy(tr, state.t), theme, bottom, _vis_t)
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
				# 2.5D swoop: drones fly in from the background and settle into their
				# real spot >= SWOOP_SETTLE px before the rider reaches them.
				var dx: float = p.x - float(state.x)
				var k := smoothstep(0.0, 1.0, clampf((dx - SWOOP_SETTLE) / SWOOP_RANGE, 0.0, 1.0))
				if k > 0.0:
					var gy := _ground_y(p.x)
					draw_circle(Vector2(p.x, gy - 1), 6.0 - 3.0 * k, Color(0, 0, 0, 0.25 * (1.0 - k)))
					var vp := (p + Vector2(18.0 * k, -42.0 * k)).floor()
					draw_set_transform(vp, 0.0, Vector2.ONE * (1.0 - 0.5 * k))
					_draw_drone(Vector2.ZERO, k * 0.6)
					draw_set_transform(Vector2.ZERO)
					glow = Vector2.INF
				else:
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


## haze 0..1 pushes colours toward the distant hills (used while swooping in).
func _draw_drone(p: Vector2, haze := 0.0) -> void:
	var hz: Color = theme.mid
	var w := roundf(9.0 * absf(cos(_vis_t * 30.0))) + 1.0
	draw_line(Vector2(p.x, p.y - 4), Vector2(p.x, p.y - 7), Color("4a4f5c").lerp(hz, haze), -1.0)
	draw_rect(Rect2(p.x - w, p.y - 8, w * 2, 1), Color("c9d1d9").lerp(hz, haze))
	for i in 3:
		var sx := p.x - 5 + i * 5
		draw_colored_polygon(PackedVector2Array([Vector2(sx - 1, p.y - 3), Vector2(sx, p.y - 6), Vector2(sx + 1, p.y - 3)]),
			Color("e8e2d0").lerp(hz, haze))
	draw_rect(Rect2(p.x - 7, p.y - 3, 14, 6), Color("4a4f5c").lerp(hz, haze))
	draw_rect(Rect2(p.x - 6, p.y - 3, 12, 4), Color("8a93a6").lerp(hz, haze))
	draw_rect(Rect2(p.x - 6, p.y + 2, 12, 1), Color("2a2d36").lerp(hz, haze))
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

