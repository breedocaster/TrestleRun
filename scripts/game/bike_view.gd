## Pixel bike + rider, drawn from primitives. A rig is {rider, bike, paint} ids:
## bike models are different frames, paint recolours the bike, riders sit on the
## model's seat/peg/grip anchors. Origin = ground contact centred between wheels.
## In the runner every model shares one hitbox (bike_physics) and differs by its
## ability; SUMMIT and GAUNTLET ride each one's own build (scripts/drive/vehicles.gd).
extends Node2D

const Catalog := preload("res://scripts/catalog.gd")
const Icons := preload("res://scripts/game/icons.gd")

const LIGHT := Color("ffe9a8")
const TAIL := Color("ff4a3a")

## 1px detail lines: -1 draws a true 1-pixel primitive (survives pixel snapping at 1x);
## scaled previews set this to 1.0 so details scale with the art.
static var line_w := -1.0

var rig: Dictionary = {}
var wheel_angle := 0.0
var squash := 0.0
var lean := 0.0       # >0 leans back (rising), <0 forward
var flutter := 0.4    # 0..1: how hard scarves/tails/flames stream
var anim_t := 0.0
var umbrella := 0.0   # 0..1: scooter's umbrella opening while gliding
var hanging := false  # on a zipline
var sticky := false   # sticky tires: green, gooey
var rocket := 0.0     # rocket flame 0..1
var hat := false      # hard hat on
var pose := 0.0       # SUMMIT / GAUNTLET air trick: id + how far into it (drive/tricks.gd)

## Set while one rig draws (draw_rig reads them), so menus never see them.
static var _tire_override := Color(0, 0, 0, 0)
static var _hat := false
## BIG HEAD cheat (Challenges.apply_cheats): every rider's head drawn twice the size.
static var big_head := false
const BIG_HEAD := 2.0
## The canvas transform the current draw_rig call sits under (callers that scale or
## move the rig set it), so a big head can be scaled about its own centre.
static var xf := Transform2D.IDENTITY
## The trick pose draw_rig draws (1 whip, 2 no-hander, 3 heel clicker, 4 superman) and
## how far into it (0..1); set by the caller around one draw_rig call.
static var pose_id := 0
static var pose_k := 0.0


func _draw() -> void:
	if rig.is_empty():
		return
	xf = Transform2D.IDENTITY
	if squash > 0.01:
		xf = Transform2D(0.0, Vector2(1.0 + 0.12 * squash, 1.0 - 0.14 * squash), 0.0, Vector2.ZERO)
		draw_set_transform_matrix(xf)
	if rocket > 0.02:
		_rocket_flame(self, Vector2(-13, -7), rocket, anim_t)
	_tire_override = Color("6fe84a") if sticky else Color(0, 0, 0, 0)
	_hat = hat
	pose_id = int(pose)
	pose_k = pose - float(pose_id)
	var a := draw_rig(self, Vector2.ZERO, rig, wheel_angle, anim_t, lean, flutter)
	pose_id = 0
	pose_k = 0.0
	_tire_override = Color(0, 0, 0, 0)
	_hat = false
	if umbrella > 0.02:
		draw_umbrella(self, Vector2.ZERO + a.grip, umbrella, Catalog.paint(String(rig.get("paint", "stock"))), anim_t)
	xf = Transform2D.IDENTITY


static func draw_rig(ci: CanvasItem, o: Vector2, r: Dictionary, wa: float, t: float,
		lean := 0.0, flutter := 0.4) -> Dictionary:
	var paint := Catalog.paint(String(r.get("paint", "stock")))
	if _tire_override.a > 0.0:
		paint = paint.duplicate()
		paint.tire = _tire_override
	var a: Dictionary
	if pose_id == 1 and pose_k > 0.0:
		# WHIP: the bike thrown sideways under the rider, so it's seen end-on-ish: drawn
		# narrower and turned nose-down about the seat, the rider's feet and hands with it.
		var piv := o + Vector2(-2, -10)
		var m := Transform2D(0.0, piv) * Transform2D(0.45 * pose_k, Vector2(1.0 - 0.5 * pose_k, 1.0), 0.0, Vector2.ZERO) \
			* Transform2D(0.0, -piv)
		ci.draw_set_transform_matrix(xf * m)
		a = draw_bike(ci, o, String(r.get("bike", "scrambler")), paint, wa).duplicate()
		ci.draw_set_transform_matrix(xf)
		for key in ["peg", "grip"]:
			a[key] = m * (o + (a[key] as Vector2)) - o
	else:
		a = draw_bike(ci, o, String(r.get("bike", "scrambler")), paint, wa)
	draw_rider(ci, o, String(r.get("rider", "dusty")), a, t, lean, flutter)
	return a


## Striped umbrella held up from the handlebar; open 0..1.
static func draw_umbrella(ci: CanvasItem, grip: Vector2, open: float, k: Dictionary, t: float) -> void:
	var top := grip + Vector2(-2, -15)
	ci.draw_line(grip, top, Color("3a3440"), line_w)
	var w := 3.0 + 9.0 * open
	var h := 2.0 + 4.0 * open
	var sway := sin(t * 4.0) * 0.6
	var pts := PackedVector2Array()
	for i in 9:
		var u := float(i) / 8.0
		pts.append(top + Vector2((u - 0.5) * 2.0 * w + sway, -h * sin(u * PI)))
	pts.append(top + Vector2(w + sway, 1))
	pts.append(top + Vector2(-w + sway, 1))
	ci.draw_colored_polygon(pts, k.body)
	for i in 3:
		var u := (float(i) + 0.5) / 3.0
		var x := (u - 0.5) * 2.0 * w + sway
		ci.draw_line(top + Vector2(x, 1), top + Vector2(x * 0.6, -h * sin(u * PI) + 1), k.accent, line_w)
	ci.draw_rect(Rect2(top.x - 1 + sway, top.y - h - 1, 2, 1), k.accent)


# --- helpers ---------------------------------------------------------------

static func _p(ci: CanvasItem, o: Vector2, pts: Array, c: Color) -> void:
	var pv := PackedVector2Array()
	for p in pts:
		pv.append(o + Vector2(p[0], p[1]))
	ci.draw_colored_polygon(pv, c)


static func _r(ci: CanvasItem, o: Vector2, x: float, y: float, w: float, h: float, c: Color) -> void:
	ci.draw_rect(Rect2(o.x + x, o.y + y, w, h), c)


static func _l(ci: CanvasItem, o: Vector2, x0: float, y0: float, x1: float, y1: float, c: Color, w := -1.0) -> void:
	ci.draw_line(o + Vector2(x0, y0), o + Vector2(x1, y1), c, w if w > 0.0 else line_w)


static func _wheel(ci: CanvasItem, c: Vector2, rad: float, k: Dictionary, wa: float, knobby := false) -> void:
	if knobby:
		for i in 8:
			var a := wa * 0.5 + i * TAU / 8.0
			ci.draw_rect(Rect2(c + Vector2(cos(a), sin(a)) * rad - Vector2(1, 1), Vector2(2, 2)), k.tire)
	ci.draw_circle(c, rad, k.tire)
	ci.draw_circle(c, maxf(1.0, rad - 1.5), k.rim)
	ci.draw_circle(c, 1.0, k.tire)
	var d := Vector2(cos(wa), sin(wa)) * maxf(1.0, rad - 1.5)
	ci.draw_line(c - d, c + d, k.tire, line_w)


# --- bike models -------------------------------------------------------------
# Each returns anchors: hip, peg, grip (offsets from origin) and torso tilt (rad,
# positive = forward).

static func draw_bike(ci: CanvasItem, o: Vector2, model: String, k: Dictionary, wa: float) -> Dictionary:
	match model:
		"dirt":
			return _dirt(ci, o, k, wa)
		"minibike":
			return _minibike(ci, o, k, wa)
		"scooter":
			return _scooter(ci, o, k, wa)
		"cafe":
			return _cafe(ci, o, k, wa)
		"chopper":
			return _chopper(ci, o, k, wa)
		"sport":
			return _sport(ci, o, k, wa)
		"spark":
			return _spark(ci, o, k, wa)
		"surge":
			return _surge(ci, o, k, wa)
		"zip":
			return _zip(ci, o, k, wa)
		"commuter":
			return _commuter(ci, o, k, wa)
		"boulder":
			return _boulder(ci, o, k, wa)
		"mono":
			return _mono(ci, o, k, wa)
		"goliath":
			return _goliath(ci, o, k, wa)
	return _scrambler(ci, o, k, wa)


static func _scrambler(ci: CanvasItem, o: Vector2, k: Dictionary, wa: float) -> Dictionary:
	_l(ci, o, -5, -6, -13, -7, k.chrome, 2.0)
	_r(ci, o, -14, -8, 2, 2, k.frame)
	_l(ci, o, -8, -4, -2, -7, k.frame, 2.0)
	_wheel(ci, o + Vector2(-8, -4), 4.0, k, wa)
	_wheel(ci, o + Vector2(8, -4), 4.0, k, wa + 0.7)
	_l(ci, o, 8, -4, 5, -13, k.chrome)
	_r(ci, o, -4, -9, 7, 5, k.engine)
	_r(ci, o, -3, -9, 1, 4, k.frame)
	_r(ci, o, -1, -9, 1, 4, k.frame)
	_p(ci, o, [[-13, -13], [-7, -13], [-7, -10], [-11, -10]], k.body_dark)
	_r(ci, o, -9, -14, 7, 2, k.seat)
	_p(ci, o, [[-2, -14], [4, -14], [6, -10], [-3, -9]], k.body)
	_l(ci, o, -1, -13, 4, -13, k.accent)
	_flames(ci, o, k)
	_r(ci, o, 6, -13, 2, 2, LIGHT)
	_r(ci, o, -13, -12, 1, 1, TAIL)
	_l(ci, o, 4, -15, 6, -16, k.chrome)
	return {"hip": Vector2(-5, -14), "peg": Vector2(0, -5), "grip": Vector2(5, -15), "torso": 0.25}


static func _dirt(ci: CanvasItem, o: Vector2, k: Dictionary, wa: float) -> Dictionary:
	_l(ci, o, -9, -5, -2, -9, k.frame, 2.0)
	_wheel(ci, o + Vector2(-9, -5), 5.0, k, wa, true)
	_wheel(ci, o + Vector2(9, -5), 5.0, k, wa + 0.7, true)
	_l(ci, o, 9, -5, 5, -17, k.chrome)
	_l(ci, o, -3, -11, -12, -14, k.chrome, 2.0)
	_r(ci, o, -4, -11, 7, 5, k.engine)
	_l(ci, o, -2, -9, 3, -15, k.frame)
	_p(ci, o, [[-6, -16], [-16, -19], [-15, -16]], k.body)
	_r(ci, o, -11, -18, 11, 2, k.seat)
	_p(ci, o, [[-2, -17], [5, -17], [7, -13], [-1, -12]], k.body)
	_l(ci, o, 0, -16, 5, -16, k.accent)
	_r(ci, o, 7, -13, 7, 2, k.body)
	_r(ci, o, 5, -19, 3, 4, Color("f4f4f4"))
	_r(ci, o, 6, -18, 1, 2, k.body_dark)
	_l(ci, o, 4, -19, 7, -20, k.chrome)
	return {"hip": Vector2(-6, -18), "peg": Vector2(0, -7), "grip": Vector2(6, -19), "torso": 0.35}


static func _minibike(ci: CanvasItem, o: Vector2, k: Dictionary, wa: float) -> Dictionary:
	_wheel(ci, o + Vector2(-6, -3), 3.0, k, wa)
	_wheel(ci, o + Vector2(6, -3), 3.0, k, wa + 0.7)
	_l(ci, o, -6, -3, -2, -7, k.body, 1.0)
	_l(ci, o, -2, -7, 5, -8, k.body, 1.0)
	_l(ci, o, 6, -3, 5, -13, k.chrome)
	_r(ci, o, -4, -8, 5, 4, k.engine)
	ci.draw_circle(o + Vector2(-4, -6), 1.5, k.chrome)
	_l(ci, o, -3, -8, -3, -10, k.frame)
	_r(ci, o, -6, -11, 6, 2, k.seat)
	_l(ci, o, 5, -13, 4, -16, k.chrome)
	_r(ci, o, 2, -16, 4, 1, k.chrome)
	_r(ci, o, 5, -12, 2, 2, LIGHT)
	return {"hip": Vector2(-4, -11), "peg": Vector2(1, -4), "grip": Vector2(3, -16), "torso": 0.1}


static func _scooter(ci: CanvasItem, o: Vector2, k: Dictionary, wa: float) -> Dictionary:
	_wheel(ci, o + Vector2(-7, -3), 3.0, k, wa)
	_wheel(ci, o + Vector2(8, -3), 3.0, k, wa + 0.7)
	_p(ci, o, [[-13, -7], [-11, -11], [-3, -11], [-1, -6], [-3, -4], [-12, -4]], k.body)
	_l(ci, o, -12, -8, -4, -8, k.accent)
	_r(ci, o, -2, -6, 7, 2, k.body_dark)
	_p(ci, o, [[4, -6], [7, -6], [8, -15], [5, -15]], k.body)
	_r(ci, o, 6, -7, 5, 2, k.body)
	_l(ci, o, 7, -15, 6, -18, k.chrome)
	_r(ci, o, 3, -19, 6, 2, k.body)
	_r(ci, o, 8, -19, 2, 2, LIGHT)
	_r(ci, o, -10, -13, 8, 2, k.seat)
	_r(ci, o, -14, -9, 1, 1, TAIL)
	return {"hip": Vector2(-6, -13), "peg": Vector2(1, -6), "grip": Vector2(4, -19), "torso": -0.05}


static func _cafe(ci: CanvasItem, o: Vector2, k: Dictionary, wa: float) -> Dictionary:
	_p(ci, o, [[-4, -6], [-14, -8], [-14, -6], [-4, -5]], k.chrome)
	_l(ci, o, -8, -4, -2, -7, k.frame, 2.0)
	_wheel(ci, o + Vector2(-8, -4), 4.0, k, wa)
	_wheel(ci, o + Vector2(8, -4), 4.0, k, wa + 0.7)
	_l(ci, o, 8, -4, 6, -12, k.chrome)
	_r(ci, o, -5, -10, 9, 6, k.engine)
	for x in [-4, -2, 0, 2]:
		_r(ci, o, x, -10, 1, 5, k.frame)
	_p(ci, o, [[-3, -14], [6, -14], [7, -11], [-3, -10]], k.body)
	_l(ci, o, -2, -13, 6, -13, k.accent)
	_flames(ci, o, k)
	_r(ci, o, -10, -14, 6, 2, k.seat)
	_p(ci, o, [[-14, -15], [-10, -16], [-10, -13], [-14, -13]], k.body)
	ci.draw_circle(o + Vector2(8, -12), 1.5, LIGHT)
	_l(ci, o, 5, -13, 7, -13, k.chrome)
	_r(ci, o, -14, -14, 1, 1, TAIL)
	return {"hip": Vector2(-6, -15), "peg": Vector2(-1, -6), "grip": Vector2(6, -13), "torso": 0.75}


static func _chopper(ci: CanvasItem, o: Vector2, k: Dictionary, wa: float) -> Dictionary:
	_l(ci, o, -3, -7, -15, -6, k.chrome, 1.0)
	_l(ci, o, -3, -9, -15, -9, k.chrome, 1.0)
	_l(ci, o, -11, -5, -2, -6, k.frame, 2.0)
	_wheel(ci, o + Vector2(-11, -5), 5.0, k, wa)
	_wheel(ci, o + Vector2(14, -3), 3.0, k, wa + 0.7)
	_l(ci, o, 14, -3, 6, -16, k.chrome)
	_l(ci, o, 13, -3, 5, -16, k.chrome)
	_l(ci, o, -4, -11, 6, -16, k.frame, 2.0)
	_r(ci, o, -4, -11, 6, 6, k.engine)
	_p(ci, o, [[-4, -11], [-2, -16], [0, -11]], k.chrome)
	_p(ci, o, [[0, -11], [2, -16], [4, -11]], k.chrome)
	_p(ci, o, [[1, -16], [6, -16], [7, -14], [2, -13]], k.body)
	_flames(ci, o + Vector2(3, -2), k)
	_p(ci, o, [[-16, -9], [-8, -11], [-6, -9], [-15, -7]], k.body)
	_r(ci, o, -10, -13, 8, 2, k.seat)
	_l(ci, o, -12, -12, -13, -21, k.chrome)
	_r(ci, o, -15, -22, 3, 4, k.seat)
	_l(ci, o, 6, -16, 5, -23, k.chrome)
	_l(ci, o, 5, -23, 7, -23, k.chrome)
	ci.draw_circle(o + Vector2(8, -15), 1.5, LIGHT)
	_r(ci, o, -16, -10, 1, 1, TAIL)
	return {"hip": Vector2(-6, -13), "peg": Vector2(5, -6), "grip": Vector2(6, -23), "torso": -0.25}


static func _sport(ci: CanvasItem, o: Vector2, k: Dictionary, wa: float) -> Dictionary:
	_l(ci, o, -8, -4, -2, -7, k.frame, 2.0)
	_wheel(ci, o + Vector2(-8, -4), 4.0, k, wa)
	_wheel(ci, o + Vector2(9, -4), 4.0, k, wa + 0.7)
	_l(ci, o, 9, -4, 7, -13, k.chrome)
	_r(ci, o, -4, -10, 7, 5, k.engine)
	_l(ci, o, -5, -11, -12, -14, k.chrome, 2.0)
	_p(ci, o, [[-14, -16], [-5, -14], [-5, -11], [-12, -12]], k.body)
	_l(ci, o, -13, -15, -6, -13, k.accent)
	_r(ci, o, -6, -15, 5, 2, k.seat)
	_p(ci, o, [[-3, -7], [3, -6], [4, -8], [-3, -9]], k.body_dark)
	_p(ci, o, [[0, -14], [7, -15], [11, -12], [10, -8], [3, -6], [-1, -9]], k.body)
	_l(ci, o, 2, -11, 9, -11, k.accent)
	_p(ci, o, [[6, -17], [9, -15], [7, -15]], Color(0.75, 0.9, 1.0, 0.7))
	_r(ci, o, 9, -12, 2, 1, LIGHT)
	_r(ci, o, -14, -15, 1, 1, TAIL)
	return {"hip": Vector2(-4, -15), "peg": Vector2(-1, -7), "grip": Vector2(6, -13), "torso": 1.0}


# --- battery bikes (v0.10) ------------------------------------------------------
# No exhaust or engine block: a battery pack (with its charge light) where the engine
# would be, a motor at the swingarm or in the hub.

const CHARGE := Color("5bf08a")


## A thin bicycle wheel: tyre ring, two spokes, hub.
static func _spoked(ci: CanvasItem, c: Vector2, rad: float, k: Dictionary, wa: float) -> void:
	ci.draw_arc(c, rad - 0.75, 0.0, TAU, 20, k.tire, 1.5)
	ci.draw_arc(c, rad - 2.0, 0.0, TAU, 16, Color(k.rim, 0.55), 1.0)
	for i in 2:
		var d := Vector2(cos(wa + i * PI * 0.5), sin(wa + i * PI * 0.5)) * (rad - 1.5)
		ci.draw_line(c - d, c + d, Color(k.rim, 0.8), line_w)
	ci.draw_rect(Rect2(c - Vector2(1, 1), Vector2(2, 2)), k.chrome)


static func _spark(ci: CanvasItem, o: Vector2, k: Dictionary, wa: float) -> Dictionary:
	_l(ci, o, -8, -4, -1, -8, k.frame, 2.0)
	_wheel(ci, o + Vector2(-8, -4), 4.0, k, wa, true)
	_wheel(ci, o + Vector2(8, -4), 4.0, k, wa + 0.7, true)
	_l(ci, o, 8, -4, 5, -16, k.chrome)
	_l(ci, o, -2, -8, -4, -13, k.chrome)
	_p(ci, o, [[-4, -14], [4, -15], [3, -8], [-3, -8]], k.body_dark)
	_r(ci, o, -2, -12, 4, 1, CHARGE)
	ci.draw_circle(o + Vector2(0, -7), 1.5, k.engine)
	_l(ci, o, -3, -15, 5, -16, k.frame)
	_r(ci, o, -12, -17, 9, 2, k.seat)
	_p(ci, o, [[-11, -16], [-16, -18], [-15, -16]], k.body)
	_p(ci, o, [[6, -12], [12, -11], [11, -10], [7, -11]], k.body)
	_r(ci, o, 4, -19, 3, 4, Color("f4f4f4"))
	_r(ci, o, 5, -18, 1, 2, k.accent)
	_l(ci, o, 3, -18, 6, -19, k.chrome)
	return {"hip": Vector2(-5, -15), "peg": Vector2(0, -6), "grip": Vector2(5, -18), "torso": 0.3}


static func _surge(ci: CanvasItem, o: Vector2, k: Dictionary, wa: float) -> Dictionary:
	_l(ci, o, -8, -4, -2, -7, k.frame, 2.0)
	_wheel(ci, o + Vector2(-8, -4), 4.0, k, wa)
	_wheel(ci, o + Vector2(9, -4), 4.0, k, wa + 0.7)
	_l(ci, o, 9, -4, 7, -13, k.chrome)
	_p(ci, o, [[-4, -12], [5, -12], [4, -6], [-3, -6]], k.engine)
	_r(ci, o, -3, -10, 7, 1, k.body_dark)
	_r(ci, o, -3, -8, 6, 1, k.body_dark)
	_r(ci, o, 3, -7, 1, 1, CHARGE)
	ci.draw_circle(o + Vector2(-2, -6), 1.5, k.chrome)
	_p(ci, o, [[-13, -16], [-5, -14], [-5, -12], [-11, -13]], k.body)
	_r(ci, o, -6, -15, 5, 2, k.seat)
	_p(ci, o, [[-1, -15], [6, -15], [9, -12], [5, -11], [-1, -12]], k.body)
	_l(ci, o, 0, -14, 7, -13, k.accent)
	_r(ci, o, 8, -13, 2, 2, LIGHT)
	_r(ci, o, -13, -15, 1, 1, TAIL)
	_l(ci, o, 4, -16, 8, -15, k.chrome)
	return {"hip": Vector2(-4, -15), "peg": Vector2(-1, -7), "grip": Vector2(6, -15), "torso": 0.9}


static func _zip(ci: CanvasItem, o: Vector2, k: Dictionary, wa: float) -> Dictionary:
	_wheel(ci, o + Vector2(-6, -3), 3.0, k, wa)
	_wheel(ci, o + Vector2(7, -3), 3.0, k, wa + 0.7)
	_r(ci, o, -7, -4, 2, 2, k.engine)
	_p(ci, o, [[-10, -6], [-9, -10], [-2, -10], [0, -6], [-2, -4], [-9, -4]], k.body)
	_r(ci, o, -8, -8, 4, 1, CHARGE)
	_r(ci, o, -1, -5, 6, 2, k.body_dark)
	_p(ci, o, [[4, -5], [6, -5], [7, -14], [5, -14]], k.body)
	_l(ci, o, 6, -14, 6, -16, k.chrome)
	_r(ci, o, 3, -17, 5, 2, k.body)
	_r(ci, o, 7, -16, 2, 2, LIGHT)
	_r(ci, o, -9, -12, 7, 2, k.seat)
	_r(ci, o, -11, -8, 1, 1, TAIL)
	return {"hip": Vector2(-5, -12), "peg": Vector2(1, -6), "grip": Vector2(4, -17), "torso": 0.0}


static func _commuter(ci: CanvasItem, o: Vector2, k: Dictionary, wa: float) -> Dictionary:
	_spoked(ci, o + Vector2(-8, -5), 5.0, k, wa)
	_spoked(ci, o + Vector2(8, -5), 5.0, k, wa + 0.7)
	_l(ci, o, -8, -5, -1, -6, k.frame)
	_l(ci, o, -8, -5, -4, -13, k.frame)
	_l(ci, o, -1, -6, -4, -13, k.frame)
	_l(ci, o, -4, -13, 5, -13, k.body)
	_l(ci, o, -1, -6, 5, -12, k.body, 2.0)
	_p(ci, o, [[0, -9], [3, -12], [4, -11], [1, -8]], k.body_dark)
	_r(ci, o, 1, -10, 1, 1, CHARGE)
	_l(ci, o, 5, -13, 8, -5, k.chrome)
	_l(ci, o, 5, -13, 5, -16, k.chrome)
	_l(ci, o, 4, -16, 7, -16, k.chrome)
	_l(ci, o, -4, -13, -5, -15, k.chrome)
	_r(ci, o, -7, -16, 4, 1, k.seat)
	ci.draw_circle(o + Vector2(-1, -6), 1.5, k.engine)
	_r(ci, o, -9, -6, 2, 2, k.engine)
	_r(ci, o, 6, -14, 1, 1, LIGHT)
	_l(ci, o, -11, -11, -6, -11, k.chrome)
	_r(ci, o, -12, -11, 1, 1, TAIL)
	return {"hip": Vector2(-4, -16), "peg": Vector2(0, -5), "grip": Vector2(6, -16), "torso": 0.3}


static func _boulder(ci: CanvasItem, o: Vector2, k: Dictionary, wa: float) -> Dictionary:
	_wheel(ci, o + Vector2(-8, -5), 5.0, k, wa, true)
	_wheel(ci, o + Vector2(8, -5), 5.0, k, wa + 0.7, true)
	_l(ci, o, -8, -5, -1, -6, k.frame, 2.0)
	_l(ci, o, -8, -5, -4, -12, k.frame)
	_l(ci, o, -1, -6, -4, -13, k.frame, 2.0)
	_p(ci, o, [[-1, -6], [5, -13], [7, -12], [1, -5]], k.body)
	_l(ci, o, 1, -7, 5, -11, k.accent)
	_r(ci, o, 2, -9, 1, 1, CHARGE)
	_l(ci, o, 6, -13, 8, -5, k.chrome, 2.0)
	_l(ci, o, 6, -13, 5, -17, k.chrome)
	_l(ci, o, 4, -17, 8, -17, k.chrome)
	_l(ci, o, -4, -13, -5, -15, k.chrome)
	_r(ci, o, -7, -16, 5, 2, k.seat)
	_l(ci, o, -12, -11, -5, -11, k.chrome)
	_l(ci, o, -10, -11, -8, -6, k.chrome)
	ci.draw_circle(o + Vector2(-1, -6), 1.5, k.engine)
	_r(ci, o, 7, -15, 2, 1, LIGHT)
	_r(ci, o, -12, -12, 1, 1, TAIL)
	return {"hip": Vector2(-4, -16), "peg": Vector2(0, -5), "grip": Vector2(6, -17), "torso": 0.35}


## Electric unicycles: one wheel under a shell, the rider standing on the pedals.
static func _mono(ci: CanvasItem, o: Vector2, k: Dictionary, wa: float) -> Dictionary:
	_wheel(ci, o + Vector2(0, -5), 5.0, k, wa)
	_p(ci, o, [[-3, -3], [-4, -6], [-4, -10], [-2, -12], [2, -12], [4, -10], [4, -6], [3, -3]], k.body)
	_l(ci, o, -3, -9, 3, -9, k.accent)
	_r(ci, o, -1, -13, 2, 1, k.frame)
	_r(ci, o, -1, -6, 2, 1, CHARGE)
	_r(ci, o, -4, -4, 8, 1, k.chrome)
	_r(ci, o, 3, -8, 1, 2, LIGHT)
	_r(ci, o, -4, -8, 1, 2, TAIL)
	return {"hip": Vector2(0, -16), "peg": Vector2(1, -4), "grip": Vector2(5, -12), "torso": 0.05,
		"knee": Vector2(1.5, -1)}


static func _goliath(ci: CanvasItem, o: Vector2, k: Dictionary, wa: float) -> Dictionary:
	_wheel(ci, o + Vector2(0, -7), 7.0, k, wa, true)
	_p(ci, o, [[-4, -4], [-5, -8], [-5, -14], [-3, -16], [3, -16], [5, -14], [5, -8], [4, -4]], k.body)
	_r(ci, o, -5, -13, 10, 1, k.body_dark)
	_l(ci, o, -4, -11, 4, -11, k.accent)
	_r(ci, o, -1, -8, 2, 1, CHARGE)
	_l(ci, o, -4, -15, -6, -19, k.chrome)
	_r(ci, o, -7, -20, 3, 1, k.chrome)
	_r(ci, o, -5, -6, 10, 2, k.chrome)
	_r(ci, o, 4, -13, 2, 2, LIGHT)
	_r(ci, o, -6, -12, 1, 2, TAIL)
	return {"hip": Vector2(0, -19), "peg": Vector2(1, -6), "grip": Vector2(5, -14), "torso": 0.05,
		"knee": Vector2(1.5, -1)}


static func _flames(ci: CanvasItem, o: Vector2, k: Dictionary) -> void:
	if k.get("flames", false):
		_p(ci, o, [[-2, -11], [3, -12], [1, -11], [5, -11], [-2, -10]], k.accent)


# --- riders --------------------------------------------------------------------

static func draw_rider(ci: CanvasItem, o: Vector2, id: String, a: Dictionary, t: float,
		lean: float, flutter: float) -> void:
	var hip: Vector2 = o + a.hip
	var peg: Vector2 = o + a.peg
	var grip: Vector2 = o + a.grip
	var big := id == "frosty"
	var tl := 8.0 if big else 6.5
	var ang: float = float(a.torso) - lean * 0.18
	var knee_off: Vector2 = a.get("knee", Vector2(3, -2))
	var pk := pose_k
	if pose_id == 4:
		# SUPERMAN: off the seat, stretched out flat behind the bars, legs out the back.
		hip = hip.lerp(hip + Vector2(-6, -3), pk)
		ang = lerpf(ang, 1.3, pk)
		peg = peg.lerp(hip + Vector2(-8, 0), pk)
		knee_off = knee_off.lerp(Vector2(0, 1), pk)
	elif pose_id == 3:
		# HEEL CLICKER: both feet off the pegs and up over the bars.
		peg = peg.lerp(grip + Vector2(3, 2), pk)
		knee_off = knee_off.lerp(Vector2(1, -3), pk)
	var up := Vector2(sin(ang), -cos(ang))
	var shoulder := hip + up * tl
	var head := shoulder + up * (4.5 if big else 3.5) + Vector2(0.5, 0)
	if big_head:
		head = shoulder + up * ((4.5 if big else 3.5) * BIG_HEAD * 0.85) + Vector2(0.5, 0)
	if pose_id == 2:
		# NO-HANDER: hands off the bars and up.
		grip = grip.lerp(shoulder + Vector2(6, -6), pk)
	var knee: Vector2 = hip.lerp(peg, 0.5) + knee_off
	var fl := clampf(flutter, 0.0, 1.0)
	var R := _rider_colors(id)

	# Trailing pieces go behind the body.
	match id:
		"granny":
			_trail(ci, shoulder + Vector2(-1, 0), 7, 2.2, Color("d9453b"), t, fl, 2.0)
		"bandit":
			_ringed_tail(ci, hip + Vector2(-2, 1), t, fl)
		"bones":
			_flame_hair(ci, head, t, fl)
		"frosty":
			_trail(ci, head + Vector2(-3, 0), 4, 2.0, Color("f0f4f8"), t, fl, -1.0)

	# Legs.
	ci.draw_line(hip, knee, R.legs, 3.0 if big else 2.0)
	ci.draw_line(knee, peg, R.legs, 3.0 if big else 2.0)
	ci.draw_rect(Rect2(peg.x - 1, peg.y - 1, 3, 2), R.boots)
	# Torso + arm.
	ci.draw_line(hip, shoulder, R.body, 5.0 if big else 3.0)
	if id == "bones":
		for i in 3:
			var rp := hip.lerp(shoulder, 0.3 + i * 0.22)
			ci.draw_line(rp - Vector2(1, 0), rp + Vector2(1, 0), Color("eae6da"), line_w)
	if id == "granny":
		ci.draw_rect(Rect2(shoulder.x, shoulder.y + 1, 1, 1), Color.WHITE)
		ci.draw_rect(Rect2(shoulder.x + 1, shoulder.y + 2, 1, 1), Color.WHITE)
	if id == "robo":
		ci.draw_rect(Rect2(hip.lerp(shoulder, 0.6).x - 1, hip.lerp(shoulder, 0.6).y - 1, 2, 2),
			Color("5bd1ff") if int(t * 3.0) % 2 == 0 else Color("2a6a8a"))
	ci.draw_line(shoulder, grip, R.arms, 3.0 if big else 2.0)
	ci.draw_rect(Rect2(grip.x - 1, grip.y - 1, 2, 2), R.hands)
	# Head (BIG HEAD: scaled about its centre under the caller's transform).
	if big_head:
		ci.draw_set_transform_matrix(xf * Transform2D(0.0, Vector2(BIG_HEAD, BIG_HEAD), 0.0, head * (1.0 - BIG_HEAD)))
	draw_head(ci, head, id, t)
	if _hat:
		Icons.hard_hat(ci, head + Vector2(0, -3))
	if big_head:
		ci.draw_set_transform_matrix(xf)


## One rider's head centred on h (also used for the league table's little faces).
static func draw_head(ci: CanvasItem, h: Vector2, id: String, t: float) -> void:
	match id:
		"granny":
			_head_granny(ci, h)
		"bandit":
			_head_bandit(ci, h)
		"bones":
			_head_bones(ci, h)
		"zorp":
			_head_zorp(ci, h, t)
		"robo":
			_head_robo(ci, h, t)
		"finn":
			_head_finn(ci, h)
		"frosty":
			_head_frosty(ci, h)
		_:
			_head_dusty(ci, h)


## Rocket strapped behind the seat: a flickering flame pointing back.
static func _rocket_flame(ci: CanvasItem, o: Vector2, k: float, t: float) -> void:
	ci.draw_rect(Rect2(o.x - 1, o.y - 2, 7, 4), Color("e8e2d0"))
	ci.draw_rect(Rect2(o.x + 3, o.y - 2, 2, 4), Color("e04848"))
	var L := (8.0 + 5.0 * sin(t * 40.0)) * k
	ci.draw_colored_polygon(PackedVector2Array([o + Vector2(-1, -2), o + Vector2(-1 - L, 0), o + Vector2(-1, 2)]), Color("ff7a2a"))
	ci.draw_colored_polygon(PackedVector2Array([o + Vector2(-1, -1), o + Vector2(-1 - L * 0.55, 0), o + Vector2(-1, 1)]), Color("fff1a8"))

static func _rider_colors(id: String) -> Dictionary:
	match id:
		"granny":
			return _rc("d9779a", "8a7ab0", "d9779a", "e8b89a", "4a3a5a")
		"bandit":
			return _rc("8a8d96", "6a6d76", "8a8d96", "1e1e24", "1e1e24")
		"bones":
			return _rc("1c1a20", "eae6da", "eae6da", "eae6da", "1c1a20")
		"zorp":
			return _rc("c9d1d9", "9aa3ad", "c9d1d9", "7ed957", "5a6270")
		"robo":
			return _rc("7f8a96", "5a6270", "9aa3ad", "3a3f48", "3a3f48")
		"finn":
			return _rc("1e1c22", "3b5a8a", "1e1c22", "6f8aa6", "2a2a2e")
		"frosty":
			return _rc("f0f4f8", "dfe7ef", "f0f4f8", "5a8fc4", "c9d6e3")
	return _rc("2f3b52", "23262f", "2f3b52", "3a3440", "17121a")


static func _rc(body: String, legs: String, arms: String, hands: String, boots: String) -> Dictionary:
	return {"body": Color.html(body), "legs": Color.html(legs), "arms": Color.html(arms),
		"hands": Color.html(hands), "boots": Color.html(boots)}


static func _trail(ci: CanvasItem, from: Vector2, n: int, seg: float, c: Color, t: float, fl: float, w: float) -> void:
	var p := from
	for i in n:
		var q := p + Vector2(-seg, sin(t * 14.0 + i * 1.1) * (0.4 + fl) * (0.4 + i * 0.25) - 0.15 * fl)
		ci.draw_line(p, q, c, w if w > 0.0 else line_w)
		p = q


static func _ringed_tail(ci: CanvasItem, from: Vector2, t: float, fl: float) -> void:
	var p := from
	for i in 6:
		var q := p + Vector2(-1.8, -0.6 + sin(t * 10.0 + i * 0.9) * (0.3 + fl * 0.8) * (0.5 + i * 0.2))
		ci.draw_line(p, q, Color("6a6d76") if i % 2 == 0 else Color("1e1e24"), 3.0)
		p = q


static func _flame_hair(ci: CanvasItem, head: Vector2, t: float, fl: float) -> void:
	for i in 3:
		var base := head + Vector2(-1 - i, -2 + i)
		var length := 5.0 + 3.0 * fl + 2.0 * sin(t * 18.0 + i * 2.1)
		var tip := base + Vector2(-length, -1.5 + sin(t * 11.0 + i) * 1.5)
		var col := Color("ff8a1f") if i != 1 else Color("ffcf3a")
		ci.draw_colored_polygon(PackedVector2Array([base + Vector2(0, -1.5), tip, base + Vector2(0, 1.5)]), col)


static func _head_dusty(ci: CanvasItem, h: Vector2) -> void:
	ci.draw_circle(h, 3.0, Color("e8e2d0"))
	ci.draw_rect(Rect2(h.x, h.y - 1, 3, 2), Color("2b4c6f"))
	ci.draw_rect(Rect2(h.x - 3, h.y - 1, 2, 1), Color("c8323c"))


static func _head_granny(ci: CanvasItem, h: Vector2) -> void:
	ci.draw_circle(h + Vector2(-1.5, -2.5), 1.6, Color("c9c9d1"))
	ci.draw_circle(h, 3.0, Color("c9c9d1"))
	ci.draw_rect(Rect2(h.x, h.y - 1, 3, 3), Color("e8b89a"))
	ci.draw_rect(Rect2(h.x + 1, h.y - 1, 1, 1), Color("1e1e24"))
	ci.draw_rect(Rect2(h.x + 3, h.y - 1, 1, 1), Color("1e1e24"))
	ci.draw_rect(Rect2(h.x + 2, h.y - 1, 1, 1), Color("1e1e24", 0.6))


static func _head_bandit(ci: CanvasItem, h: Vector2) -> void:
	ci.draw_colored_polygon(PackedVector2Array([h + Vector2(-3, -2), h + Vector2(-2, -5), h + Vector2(-1, -2)]), Color("6a6d76"))
	ci.draw_colored_polygon(PackedVector2Array([h + Vector2(0, -2), h + Vector2(1, -5), h + Vector2(2, -2)]), Color("6a6d76"))
	ci.draw_circle(h, 3.0, Color("8a8d96"))
	ci.draw_rect(Rect2(h.x + 1, h.y, 3, 2), Color("d8d8dc"))
	ci.draw_rect(Rect2(h.x - 2, h.y - 2, 5, 2), Color("1e1e24"))
	ci.draw_rect(Rect2(h.x + 1, h.y - 2, 1, 1), Color.WHITE)
	ci.draw_rect(Rect2(h.x + 4, h.y, 1, 1), Color("1e1e24"))


static func _head_bones(ci: CanvasItem, h: Vector2) -> void:
	ci.draw_circle(h, 3.0, Color("eae6da"))
	ci.draw_rect(Rect2(h.x + 1, h.y + 1, 3, 2), Color("eae6da"))
	ci.draw_rect(Rect2(h.x, h.y - 1, 2, 2), Color("1c1a20"))
	ci.draw_rect(Rect2(h.x + 2, h.y - 1, 1, 2), Color("1c1a20"))
	ci.draw_rect(Rect2(h.x + 2, h.y + 2, 1, 1), Color("1c1a20"))


static func _head_zorp(ci: CanvasItem, h: Vector2, t: float) -> void:
	var tip := h + Vector2(-1 + sin(t * 4.0), -7)
	ci.draw_line(h + Vector2(0, -3), tip, Color("5aa83a"), line_w)
	ci.draw_circle(tip, 1.2, Color("ff6ad5"))
	ci.draw_circle(h, 3.5, Color("7ed957"))
	ci.draw_rect(Rect2(h.x, h.y - 2, 2, 3), Color("101014"))
	ci.draw_rect(Rect2(h.x + 3, h.y - 2, 1, 3), Color("101014"))
	ci.draw_arc(h, 5.5, 0.0, TAU, 16, Color(0.7, 0.9, 1.0, 0.45), 1.0)
	ci.draw_rect(Rect2(h.x - 2, h.y - 4, 1, 1), Color(1, 1, 1, 0.7))


static func _head_robo(ci: CanvasItem, h: Vector2, t: float) -> void:
	ci.draw_line(h + Vector2(-1, -3), h + Vector2(-1, -6), Color("5a6270"), line_w)
	ci.draw_rect(Rect2(h.x - 2, h.y - 7, 2, 1), Color("ff4a3a") if int(t * 2.0) % 2 == 0 else Color("5a2a2a"))
	ci.draw_rect(Rect2(h.x - 3, h.y - 3, 7, 6), Color("5a6270"))
	ci.draw_rect(Rect2(h.x - 2, h.y - 2, 5, 4), Color("9aa3ad"))
	ci.draw_rect(Rect2(h.x - 2, h.y - 1, 6, 2), Color("101014"))
	var scan := h.x - 1 + roundf((sin(t * 5.0) + 1.0) * 2.0)
	ci.draw_rect(Rect2(scan, h.y - 1, 1, 2), Color("ff4a3a"))


static func _head_finn(ci: CanvasItem, h: Vector2) -> void:
	ci.draw_colored_polygon(PackedVector2Array([h + Vector2(-3, -2), h + Vector2(-1, -8), h + Vector2(1, -2)]), Color("5a7290"))
	ci.draw_colored_polygon(PackedVector2Array([h + Vector2(-3, -3), h + Vector2(2, -3), h + Vector2(6, 0),
		h + Vector2(2, 3), h + Vector2(-3, 2)]), Color("6f8aa6"))
	ci.draw_colored_polygon(PackedVector2Array([h + Vector2(-1, 1), h + Vector2(5, 0.5), h + Vector2(2, 3), h + Vector2(-2, 2.5)]), Color("e8eef4"))
	for i in 3:
		ci.draw_rect(Rect2(h.x + i * 1.5, h.y + 1, 1, 1), Color("1e1e24"))
	ci.draw_rect(Rect2(h.x - 1, h.y - 2, 4, 1), Color("101014"))


static func _head_frosty(ci: CanvasItem, h: Vector2) -> void:
	ci.draw_colored_polygon(PackedVector2Array([h + Vector2(-4, -2), h + Vector2(-5, -6), h + Vector2(-2, -4)]), Color("c9d6e3"))
	ci.draw_colored_polygon(PackedVector2Array([h + Vector2(2, -3), h + Vector2(3, -7), h + Vector2(4, -3)]), Color("c9d6e3"))
	ci.draw_circle(h, 4.0, Color("f0f4f8"))
	ci.draw_rect(Rect2(h.x, h.y - 1, 4, 4), Color("5a8fc4"))
	ci.draw_rect(Rect2(h.x + 1, h.y, 1, 1), Color("101014"))
	ci.draw_rect(Rect2(h.x + 3, h.y, 1, 1), Color("101014"))
	ci.draw_rect(Rect2(h.x + 1, h.y + 2, 3, 1), Color("f0f4f8"))
