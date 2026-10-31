## A ride in SUMMIT (hill climb) or GAUNTLET (trials). Steps the vehicle sim at 60 Hz,
## reads gas and brake (keys, pad triggers or the HUD's touch pedals), follows with
## the camera, draws the course and the rider, and keeps score: fuel, coins and
## distance in SUMMIT; time, faults and checkpoints in GAUNTLET; air tricks and combos
## in both (tricks.gd). Records the ride as a ghost, and plays one back (ghost.gd).
extends Node2D

signal done(result: Dictionary)

const Vehicles := preload("res://scripts/drive/vehicles.gd")
const Art := preload("res://scripts/drive/drive_art.gd")
const BikeView := preload("res://scripts/game/bike_view.gd")
const Backdrop := preload("res://scripts/game/backdrop.gd")
const Icons := preload("res://scripts/game/icons.gd")
const Tricks := preload("res://scripts/drive/tricks.gd")
const Ghost := preload("res://scripts/drive/ghost.gd")

const DT := 1.0 / 60.0
const PX_PER_M := 8.0
const CRASH_T := 1.2        # s of tumble before the results (SUMMIT) or a respawn (GAUNTLET)
const EMPTY_T := 1.5        # s stopped with an empty tank before the run ends
const ZOOM_SUMMIT := 1.5
const ZOOM_GAUNTLET := 2.0

var mode := "summit"
var level: Dictionary = {}
var rig: Dictionary = {}
var up: Dictionary = {}
var bike_id := "scrambler"
var electric := false
var sim: RefCounted

var phase := "ride"         # ride, crash, done
var ticks := 0
var ride_time := 0.0
var tank := 26.0
var fuel := 26.0
var coins := 0
var faults := 0
var flips := 0
var cp := 0                 # GAUNTLET: last checkpoint reached (0 = start)
var best_x := 0.0
var tricks = Tricks.new()
var trick_pts := 0          # GAUNTLET: banked trick points
var pickup_coins := 0       # coins picked up (not counting trick and flip pay)
var cans := 0               # fuel cans / charge points taken
var max_air := 0.0          # longest single jump (s)
var result: Dictionary = {}
var popups: Array = []      # [text, world pos, age]

## Inputs. The HUD sets the touch ones; a dev bot overrides everything.
var touch_gas := false
var touch_brake := false
var bot = null
var gas := 0.0
var brake := 0.0
var lean_swap := false

var cam: Camera2D
var backdrop: Node2D
var _acc := 0.0
var _t := 0.0
var _crash_t := 0.0
var _empty_t := 0.0
var _coin_got := {}
var _fuel_got := {}
var _cols: Array = []
var _th: Dictionary = {}
var _was_grounded := true
var _shake := 0.0
var _audio := true
var _horizon_ref := INF
var _hops_seen := 0
var _tip_i := 0
var tip_text := ""          # the how-to sign showing (the HUD draws it), and for how long
var tip_t := 0.0
## Ghost: this ride as it goes (ghost.gd frames), and one to race ({"frames", "rig",
## "gold"}: set before the world enters the tree).
var rec := PackedFloat32Array()
var ghost: Dictionary = {}
## The level's objectives still to do, as text, shown as the ride starts (set by the
## screen).
var objectives: Array = []
## An event's rules (events.gd, level.event; {} on a SUMMIT or GAUNTLET level) and what
## it counts.
var ev: Dictionary = {}
var items_got := 0
var _item_got := {}
var jump_m := -1.0          # LONG JUMP: the jump, once landed
var _lj_air := false
var _lj_land_t := 0.0
var _ghost_view: Node2D
var _ride_ticks := 0


func setup(p_mode: String, lv: Dictionary, p_rig: Dictionary, p_up := {}) -> void:
	mode = p_mode
	level = lv
	rig = p_rig
	up = p_up if mode == "summit" else {}
	bike_id = String(rig.get("bike", "scrambler"))
	electric = Vehicles.is_electric(bike_id)


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -10
	add_child(layer)
	backdrop = Backdrop.new()
	backdrop.theme_index = int(level.theme)
	backdrop.time_mode = String(level.time)
	backdrop.weather = String(level.get("weather", "clear"))
	layer.add_child(backdrop)
	_th = Backdrop.theme(int(level.theme), String(level.time), String(level.get("weather", "clear")))
	_cols = Art.ground_colors(int(level.theme), String(level.time))
	cam = Camera2D.new()
	# Closer than the runner: the bike is a physics object here and the obstacles are
	# its size, so they need to read. (GAUNTLET's courses are short and fiddly; SUMMIT
	# keeps more of the hill ahead in view.)
	cam.zoom = Vector2.ONE * (ZOOM_GAUNTLET if mode == "gauntlet" else ZOOM_SUMMIT)
	add_child(cam)
	cam.make_current()
	sim = Vehicles.build(bike_id, level.terrain, up, mode)
	Vehicles.apply_mods(sim, level.get("mods", {}))
	sim.place(level.start)
	tank = Vehicles.tank_seconds(bike_id, up)
	ev = level.get("event", {})
	if ev.has("tank"):
		tank = float(ev.tank)
	fuel = tank
	lean_swap = GameState.flag("lean_swap", false)
	tricks.enabled = GameState.flag("tricks", true)
	cam.position = _cam_target()
	if not ghost.is_empty():
		_ghost_view = BikeView.new()
		_ghost_view.rig = ghost.get("rig", rig)
		_ghost_view.modulate = Color(1.0, 0.85, 0.35, 0.42) if bool(ghost.get("gold", false)) else Color(0.75, 0.9, 1.0, 0.38)
		add_child(_ghost_view)
	_audio = bot == null and DisplayServer.get_name() != "headless"
	if _audio:
		AudioDirector.engine_start(Vehicles.sound_id(bike_id))
		AudioDirector.engine_ride()


func _process(delta: float) -> void:
	_acc += delta
	var n := 0
	while _acc >= DT and n < 4:
		_acc -= DT
		tick()
		n += 1
	if _acc > DT:
		_acc = 0.0
	_t += delta
	_update_cam(delta)
	if _audio and phase == "ride":
		var top: float = maxf(1.0, sim.top_w)
		AudioDirector.engine_update(delta, sim.grounded, clampf(absf(sim.drive_w) / top * 1.3 + 0.35, 0.5, 1.8))
	tip_t = maxf(0.0, tip_t - delta)
	_sync_ghost()
	for p in popups:
		p[2] += delta
	popups = popups.filter(func(p): return p[2] < 1.2)
	queue_redraw()


## One 1/60 s step of the ride.
func tick() -> void:
	ticks += 1
	match phase:
		"ride":
			_read_input()
			if mode == "summit" and fuel <= 0.0:
				gas = 0.0
			sim.gas = gas
			sim.brake = brake
			sim.lean_sign = -1.0 if lean_swap else 1.0
			sim.step()
			ride_time += DT
			if _ride_ticks % Ghost.RATE == 0:
				Ghost.add_frame(rec, sim, tricks.pose())
			_ride_ticks += 1
			if mode == "summit":
				fuel = maxf(0.0, fuel - DT)
			max_air = maxf(max_air, float(sim.airtime))
			_pickups()
			_event_tick()
			_hop_and_tips()
			_landing()
			tricks.update(DT, gas > 0.5, brake > 0.5, sim.grounded, float(sim.airtime))
			sim.air_lock = not tricks.active.is_empty() and not tricks.pending
			_trick_events()
			if phase == "ride":
				_checks()
		"crash":
			sim.gas = 0.0
			sim.brake = 0.0
			sim.step()
			_crash_t += DT
			if _crash_t >= CRASH_T:
				if mode == "gauntlet":
					_respawn()
				else:
					_finish(false, String(result.get("reason", "crash")))
		"done":
			sim.gas = 0.0
			sim.brake = 0.3
			sim.step()


func _read_input() -> void:
	if bot != null:
		var c: Vector2 = bot.control(self)
		gas = c.x
		brake = c.y
		return
	gas = Input.get_action_strength("gas")
	brake = Input.get_action_strength("brake")
	if touch_gas:
		gas = 1.0
	if touch_brake:
		brake = 1.0


func _pickups() -> void:
	var p: Vector2 = sim.pos
	var coins_list: Array = level.get("coins", [])
	for i in coins_list.size():
		if _coin_got.has(i):
			continue
		var c: Array = coins_list[i]
		if (c[0] as Vector2).distance_squared_to(p) < 196.0:
			_coin_got[i] = true
			coins += int(c[1])
			pickup_coins += int(c[1])
			_sfx("coin")
	var fl: Array = level.get("fuel", [])
	for i in fl.size():
		if _fuel_got.has(i):
			continue
		if (fl[i] as Vector2).distance_squared_to(p) < 256.0:
			_fuel_got[i] = true
			cans += 1
			fuel = tank
			popups.append(["FULL CHARGE" if electric else "FUEL!", fl[i], 0.0])
			_sfx("power")


## Event rules: collecting, the long jump, the time limit.
func _event_tick() -> void:
	if ev.is_empty():
		return
	var items: Array = level.get("items", [])
	for i in items.size():
		if not _item_got.has(i) and (items[i] as Vector2).distance_squared_to(sim.pos) < 196.0:
			_item_got[i] = true
			items_got += 1
			if _audio:
				AudioDirector.coin()
	match String(ev.kind):
		"long_jump":
			var lip := float(ev.lip_x)
			if not _lj_air and sim.pos.x > lip and not sim.grounded:
				_lj_air = true
			elif _lj_air and jump_m < 0.0 and sim.grounded:
				jump_m = maxf(0.0, (sim.pos.x - lip) / PX_PER_M)
				_lj_land_t = ride_time
				popups.append(["%.1f M!" % jump_m, sim.pos + Vector2(0, -24), 0.0])
				_sfx("prize")
			elif jump_m >= 0.0 and ride_time - _lj_land_t > 1.5:
				_finish(true, "landed")
			elif ride_time > 30.0:
				_finish(false, "time")
		"trick_attack":
			if ride_time >= float(ev.get("time_limit", 60.0)):
				_finish(true, "time")


## The event's score for this ride, or null. (ok: how the ride ended.)
func _event_score_at(ok: bool):
	match String(ev.kind):
		"long_jump":
			return snappedf(jump_m, 0.1) if jump_m >= 0.0 and ok else null
		"time_attack", "moon":
			return snappedf(ride_time, 0.01) if ok else null
	return _event_score()


func _event_score():
	match String(ev.kind):
		"long_jump":
			return snappedf(jump_m, 0.1) if jump_m >= 0.0 and phase == "ride" else null
		"collect":
			return items_got
		"trick_attack":
			return trick_pts
		"time_attack", "moon":
			return snappedf(ride_time, 0.01) if result.get("ok", false) else null
		"fuel_saver":
			return int(best_x / PX_PER_M)
	return null


## Hops (GAUNTLET) and the how-to signs.
func _hop_and_tips() -> void:
	if sim.hops > _hops_seen:
		_hops_seen = sim.hops
		_sfx("jump")
	var tips: Array = level.get("tips", [])
	while _tip_i < tips.size() and sim.pos.x >= float(tips[_tip_i][0]) - 60.0:
		tip_text = String(tips[_tip_i][1])
		tip_t = 3.5
		_tip_i += 1


func _landing() -> void:
	var g: bool = sim.grounded
	if g and not _was_grounded:
		if sim.landed_hard > 260.0:
			_shake = 2.0
		if sim.flips != 0:
			var n: int = absi(sim.flips)
			flips += n
			# Flips go into the combo (tricks.gd) and pay when it's banked.
			tricks.add_flips(n)
			popups.append(["FLIP!" if n == 1 else "%dX FLIP!" % n, sim.pos, 0.0])
			_sfx("trick")
	_was_grounded = g


## What the trick tracker said this frame.
func _trick_events() -> void:
	var evs: Array = tricks.events
	tricks.events = []
	for e in evs:
		match String(e[0]):
			"start":
				popups.append([String(e[1]), sim.pos + Vector2(0, -6), 0.4])
				_sfx("dash")
			"done":
				_sfx("trick")
			"cancel":
				pass
			"bail":
				popups.append(["BAILED!", sim.pos, 0.0])
				_crash("bail")
			"bank":
				var n := int(e[1])
				var names: Array = e[4]
				var what := String(names[0]) if n == 1 else "COMBO X%d" % n
				if mode == "summit":
					coins += int(e[2])
					popups.append(["%s +%d" % [what, int(e[2])], sim.pos + Vector2(0, -10), 0.0])
				else:
					trick_pts += int(e[3])
					popups.append(["%s +%d" % [what, int(e[3])], sim.pos + Vector2(0, -10), 0.0])
				if n > 1:
					_sfx("prize")
			"lost":
				popups.append(["COMBO LOST", sim.pos + Vector2(0, -10), 0.0])


func _checks() -> void:
	var p: Vector2 = sim.pos
	best_x = maxf(best_x, p.x)
	if sim.crashed:
		_crash("crash")
		return
	# Fell into a pit.
	for g in level.get("gaps", []):
		if p.x > float(g[0]) and p.x < float(g[1]) and p.y > float(g[2]) + 70.0:
			_crash("pit")
			return
	if p.y > float(level.get("kill_y", 3000.0)):
		_crash("pit")
		return
	if mode == "summit" and fuel <= 0.0:
		if absf(sim.speed()) < 6.0:
			_empty_t += DT
			if _empty_t >= EMPTY_T:
				_finish(false, "fuel")
				return
		else:
			_empty_t = 0.0
	if mode == "gauntlet":
		var cps: Array = level.get("checkpoints", [])
		while cp < cps.size() and p.x >= float(cps[cp]):
			cp += 1
			popups.append(["CHECKPOINT", p + Vector2(0, -30), 0.0])
			_sfx("checkpoint")
	if p.x >= float(level.finish_x):
		_finish(true, "finish")


func _crash(reason: String) -> void:
	if phase != "ride":
		return
	phase = "crash"
	_crash_t = 0.0
	sim.air_lock = false
	tricks.lose()
	_trick_events()
	result.reason = reason
	_shake = 3.0
	_sfx("crash")
	if _audio:
		AudioDirector.engine_cut()


## GAUNTLET: a fault, and back to the last checkpoint.
func _respawn() -> void:
	faults += 1
	var cps: Array = level.get("checkpoints", [])
	var x: float = float(level.start.x) if cp == 0 else float(cps[cp - 1]) + 6.0
	var t = level.terrain
	var y: float = t.top_at(x)
	var a := atan2(t.top_at(x + 8.0) - t.top_at(x - 8.0), 16.0)
	sim.place(Vector2(x, y), a)
	tricks.reset()
	phase = "ride"
	_was_grounded = true
	if _audio:
		AudioDirector.engine_start(Vehicles.sound_id(bike_id))
		AudioDirector.engine_ride()


func _finish(ok: bool, reason: String) -> void:
	if phase == "done":
		return
	if phase == "ride":
		# (A crash already lost the combo in hand; running dry or the finish banks it.)
		tricks.bank()
		_trick_events()
	phase = "done"
	result = {
		"mode": mode, "level_id": String(level.id), "ok": ok, "reason": reason,
		"time": snappedf(ride_time, 0.01), "coins": coins, "distance_m": int(best_x / PX_PER_M),
		"length_m": int(float(level.finish_x) / PX_PER_M), "faults": faults, "flips": flips,
		"fuel_left": fuel / tank if tank > 0.0 else 0.0, "bike": bike_id,
		"tricks": tricks.landed, "trick_kinds": tricks.kinds.keys(), "best_combo": tricks.best_combo, "trick_pts": trick_pts,
		"trick_coins": tricks.banked_coins, "pickup_coins": pickup_coins, "cans": cans,
		"max_air": snappedf(max_air, 0.01), "hops": int(sim.hops), "ghost": rec,
	}
	if not ev.is_empty():
		result.event = String(ev.kind)
		result.items = items_got
		result.jump_m = jump_m
		result.score = _event_score_at(ok)
	if _audio:
		AudioDirector.engine_stop(0.8)
	done.emit(result)


func _sfx(name: String) -> void:
	if _audio:
		AudioDirector.play(name)


# --- camera -------------------------------------------------------------------------

func _cam_target() -> Vector2:
	var p: Vector2 = sim.pos
	var z: float = cam.zoom.x if cam else 1.0
	var ahead := clampf(sim.vel.x * 0.35, -40.0, 110.0)
	return Vector2(p.x + (ahead + 40.0) / z, p.y - 26.0 / z)


func _update_cam(delta: float) -> void:
	var tgt := _cam_target()
	var k := 1.0 - exp(-delta * 6.0)
	var c := cam.position.lerp(tgt, k)
	# Never let the rider leave the screen.
	var vs := get_viewport_rect().size / cam.zoom   # the world the camera shows
	c.x = clampf(c.x, sim.pos.x - vs.x * 0.42, sim.pos.x + vs.x * 0.42)
	c.y = clampf(c.y, sim.pos.y - vs.y * 0.38, sim.pos.y + vs.y * 0.38)
	cam.position = c.round()
	_shake = maxf(0.0, _shake - delta * 8.0)
	cam.offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake)).round() if _shake > 0.3 and GameState.flag("shake") else Vector2.ZERO
	# The scenery's height follows the camera relative to the ground under it (eased),
	# not the absolute height: SUMMIT climbs hundreds of px, and the backdrop's hills
	# would sink out of sight behind the slope.
	var gy: float = level.terrain.top_at(cam.position.x)
	if is_finite(gy):
		_horizon_ref = gy if _horizon_ref == INF else lerpf(_horizon_ref, gy, minf(1.0, delta * 3.0))
	var ref := 0.0 if _horizon_ref == INF else _horizon_ref
	# The runner rides a trestle with the valley below; here the ground is solid, so
	# the scenery is lifted (a low camera to the backdrop) to show above the slope.
	backdrop.cam = Vector2(cam.position.x, 120.0 + (cam.position.y - ref + 26.0 / cam.zoom.y) * 0.5)


# --- drawing ------------------------------------------------------------------------

func _ground_y(x: float) -> float:
	var pts: PackedVector2Array = level.ground
	var step := pts[1].x - pts[0].x
	var i := clampi(int((x - pts[0].x) / step), 0, pts.size() - 2)
	return lerpf(pts[i].y, pts[i + 1].y, clampf((x - pts[i].x) / step, 0.0, 1.0))


func _draw() -> void:
	var vs := get_viewport_rect().size / cam.zoom
	var left := cam.position.x - vs.x * 0.5 - 24.0
	var right := cam.position.x + vs.x * 0.5 + 24.0
	var bottom := cam.position.y + vs.y * 0.5 + 40.0
	for g in level.get("gaps", []):
		if float(g[1]) > left and float(g[0]) < right:
			Art.pit(self, float(g[0]), float(g[1]), float(g[2]), _cols)
	Art.backdrop_decor(self, level.ground, left, right, int(level.theme), _cols, String(level.time))
	Art.ground(self, level.ground, left, right, bottom, _cols)
	Art.surface_decor(self, level.ground, left, right, int(level.theme), _cols)
	for b in level.get("bridges", []):
		if float(b[1]) > left and float(b[0]) < right:
			Art.bridge(self, float(b[0]), float(b[1]), float(b[2]), _ground_y, _th)
	_draw_props(left, right)
	# Distance posts (SUMMIT).
	if mode == "summit":
		var m0 := int(ceilf(left / PX_PER_M / 100.0)) * 100
		var m := maxi(m0, 100)
		while m * PX_PER_M < right and m * PX_PER_M < float(level.finish_x):
			var px := m * PX_PER_M
			Art.post(self, px, level.terrain.top_at(px), m, GameState.font)
			m += 100
	# Checkpoints and the finish.
	for i in (level.get("checkpoints", []) as Array).size():
		var cx := float(level.checkpoints[i])
		if cx > left and cx < right:
			Art.checkpoint(self, cx, level.terrain.top_at(cx), i < cp, _t)
	var fx := float(level.finish_x)
	if fx > left - 40.0 and fx < right:
		Art.summit_flag(self, fx, level.terrain.top_at(fx), _t)
	# Pickups (and an event's things to collect).
	var its: Array = level.get("items", [])
	for i in its.size():
		var ip: Vector2 = its[i]
		if not _item_got.has(i) and ip.x > left and ip.x < right:
			Art.item(self, ip, String(ev.get("item", "star")), _t)
	if String(ev.get("kind", "")) == "long_jump":
		_draw_jump_marks(left, right)
	var coins_list: Array = level.get("coins", [])
	for i in coins_list.size():
		var c: Array = coins_list[i]
		var cpnt: Vector2 = c[0]
		if _coin_got.has(i) or cpnt.x < left or cpnt.x > right:
			continue
		Icons.coin(self, cpnt, cos(_t * 4.0 + cpnt.x * 0.05))
		if int(c[1]) > 5:
			draw_arc(cpnt, 5.0, 0.0, TAU, 10, Color(1, 0.95, 0.6, 0.5), 1.0)
	var fl: Array = level.get("fuel", [])
	for i in fl.size():
		if _fuel_got.has(i) or (fl[i] as Vector2).x < left or (fl[i] as Vector2).x > right:
			continue
		Art.fuel(self, fl[i], electric, _t)
	_draw_rider()
	for p in popups:
		var a := clampf(1.2 - float(p[2]), 0.0, 1.0)
		var pp: Vector2 = (p[1] as Vector2) + Vector2(0, -18.0 - 14.0 * float(p[2]))
		var s := String(p[0])
		var w := GameState.font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		draw_string(GameState.font, (pp - Vector2(w * 0.5, 0)).round(), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 0.92, 0.5, a))


## LONG JUMP: a board every 10 m past the lip, so you can see how far you're going.
func _draw_jump_marks(left: float, right: float) -> void:
	var lip := float(ev.lip_x)
	for k in range(1, 30):
		var x := lip + k * 10.0 * PX_PER_M
		if x < left or x > right:
			continue
		var y: float = level.terrain.top_at(x)
		draw_rect(Rect2(x - 1, y - 14, 2, 14), Color("e8e2d0"))
		var s := "%dM" % (k * 10)
		var w := GameState.font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		draw_rect(Rect2(x - w * 0.5 - 2, y - 24, w + 4, 10), Color("2a2434"))
		draw_string(GameState.font, Vector2(x - w * 0.5, y - 16), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("f2c14e"))
	if jump_m >= 0.0:
		var jx := lip + jump_m * PX_PER_M
		var jy: float = level.terrain.top_at(jx)
		draw_rect(Rect2(jx - 1, jy - 10, 2, 10), Color("ff5a4a"))


## GAUNTLET props (crates, logs, plates), drawn from the level's prop list.
func _draw_props(left: float, right: float) -> void:
	for pr in level.get("props", []):
		var x0: float = float(pr.x0)
		var x1: float = float(pr.x1)
		if x1 < left or x0 > right:
			continue
		match String(pr.kind):
			"crate":
				Art.crate(self, pr.rect)
			"log":
				Art.log_end(self, pr.c, float(pr.r))
			"steel":
				Art.steel(self, pr.pts)


func _draw_rider() -> void:
	var o: Vector2 = sim.world(sim.art)
	draw_set_transform(o.round(), sim.ang)
	BikeView.xf = Transform2D(sim.ang, o.round())
	var wa: float = (sim.wheels[0] as Object).spin
	var lean := (gas - brake) * (1.0 if not lean_swap else -1.0) * 1.2 if phase == "ride" else 0.0
	var pz := tricks.pose()
	BikeView.pose_id = int(pz)
	BikeView.pose_k = pz - float(int(pz))
	BikeView.draw_rig(self, Vector2.ZERO, rig, wa, _t, lean, clampf(absf(sim.speed()) / 200.0, 0.2, 1.0))
	BikeView.pose_id = 0
	BikeView.pose_k = 0.0
	BikeView.xf = Transform2D.IDENTITY
	draw_set_transform(Vector2.ZERO)


## The ghost at the same riding time as you (hidden while it's right on top of you).
func _sync_ghost() -> void:
	if _ghost_view == null:
		return
	var g := Ghost.at(ghost.frames, ride_time)
	if g.is_empty():
		_ghost_view.visible = false
		return
	var me: Vector2 = sim.world(sim.art)
	_ghost_view.visible = (g.pos as Vector2).distance_to(me) > 6.0 or phase != "ride"
	_ghost_view.position = (g.pos as Vector2).round()
	_ghost_view.rotation = float(g.ang)
	_ghost_view.wheel_angle = float(g.spin)
	_ghost_view.pose = float(g.pose)
	_ghost_view.anim_t = _t
	_ghost_view.queue_redraw()
