## A ride in SUMMIT (hill climb) or GAUNTLET (trials). Steps the vehicle sim at 60 Hz,
## reads gas and brake (keys, pad triggers or the HUD's touch pedals), follows with
## the camera, draws the course and the rider, and keeps score: fuel, coins and
## distance in SUMMIT; time, faults and checkpoints in GAUNTLET.
extends Node2D

signal done(result: Dictionary)

const Vehicles := preload("res://scripts/drive/vehicles.gd")
const Art := preload("res://scripts/drive/drive_art.gd")
const BikeView := preload("res://scripts/game/bike_view.gd")
const Backdrop := preload("res://scripts/game/backdrop.gd")
const Icons := preload("res://scripts/game/icons.gd")

const DT := 1.0 / 60.0
const PX_PER_M := 8.0
const CRASH_T := 1.2        # s of tumble before the results (SUMMIT) or a respawn (GAUNTLET)
const EMPTY_T := 1.5        # s stopped with an empty tank before the run ends
const FLIP_COINS := 25
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
	sim.place(level.start)
	tank = Vehicles.tank_seconds(bike_id, up)
	fuel = tank
	lean_swap = GameState.flag("lean_swap", false)
	cam.position = _cam_target()
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
			if mode == "summit":
				fuel = maxf(0.0, fuel - DT)
			_pickups()
			_landing()
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
			_sfx("coin")
	var fl: Array = level.get("fuel", [])
	for i in fl.size():
		if _fuel_got.has(i):
			continue
		if (fl[i] as Vector2).distance_squared_to(p) < 256.0:
			_fuel_got[i] = true
			fuel = tank
			popups.append(["FULL CHARGE" if electric else "FUEL!", fl[i], 0.0])
			_sfx("power")


func _landing() -> void:
	var g: bool = sim.grounded
	if g and not _was_grounded:
		if sim.landed_hard > 260.0:
			_shake = 2.0
		if sim.flips != 0:
			var n: int = absi(sim.flips)
			flips += n
			if mode == "summit":
				coins += FLIP_COINS * n
				popups.append(["%s +%d" % ["FLIP!" if n == 1 else "%dX FLIP!" % n, FLIP_COINS * n], sim.pos, 0.0])
			else:
				popups.append(["FLIP!" if n == 1 else "%dX FLIP!" % n, sim.pos, 0.0])
			_sfx("trick")
	_was_grounded = g


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
	phase = "crash"
	_crash_t = 0.0
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
	phase = "ride"
	_was_grounded = true
	if _audio:
		AudioDirector.engine_start(Vehicles.sound_id(bike_id))
		AudioDirector.engine_ride()


func _finish(ok: bool, reason: String) -> void:
	if phase == "done":
		return
	phase = "done"
	result = {
		"mode": mode, "level_id": String(level.id), "ok": ok, "reason": reason,
		"time": snappedf(ride_time, 0.01), "coins": coins, "distance_m": int(best_x / PX_PER_M),
		"length_m": int(float(level.finish_x) / PX_PER_M), "faults": faults, "flips": flips,
		"fuel_left": fuel / tank if tank > 0.0 else 0.0, "bike": bike_id,
	}
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
	# Pickups.
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
	var wa: float = (sim.wheels[0] as Object).spin
	var lean := (gas - brake) * (1.0 if not lean_swap else -1.0) * 1.2 if phase == "ride" else 0.0
	BikeView.draw_rig(self, Vector2.ZERO, rig, wa, _t, lean, clampf(absf(sim.speed()) / 200.0, 0.2, 1.0))
	draw_set_transform(Vector2.ZERO)
