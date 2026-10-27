## Every bike's build for the physics modes: where its wheels are (matching its
## drawing in bike_view.gd), how big, where the rider's head is, and how it goes.
## SUMMIT's upgrades scale these numbers; GAUNTLET always uses them as they are.
extends RefCounted

const Sim := preload("res://scripts/drive/vehicle_sim.gd")

## Drawing anchors (bike_view.gd): wheel centres and radius, the rider's hip and torso
## tilt. Unicycles have one wheel under the rider.
const GEO := {
	"scrambler": {"rear": Vector2(-8, -4), "front": Vector2(8, -4), "r": 4.0, "rf": 4.0, "hip": Vector2(-5, -14), "torso": 0.25},
	"dirt": {"rear": Vector2(-9, -5), "front": Vector2(9, -5), "r": 5.0, "rf": 5.0, "hip": Vector2(-6, -18), "torso": 0.35},
	"minibike": {"rear": Vector2(-6, -3), "front": Vector2(6, -3), "r": 3.0, "rf": 3.0, "hip": Vector2(-4, -11), "torso": 0.1},
	"scooter": {"rear": Vector2(-7, -3), "front": Vector2(8, -3), "r": 3.0, "rf": 3.0, "hip": Vector2(-6, -13), "torso": -0.05},
	"cafe": {"rear": Vector2(-8, -4), "front": Vector2(8, -4), "r": 4.0, "rf": 4.0, "hip": Vector2(-6, -15), "torso": 0.75},
	"chopper": {"rear": Vector2(-11, -5), "front": Vector2(14, -3), "r": 5.0, "rf": 3.0, "hip": Vector2(-6, -13), "torso": -0.25},
	"sport": {"rear": Vector2(-8, -4), "front": Vector2(9, -4), "r": 4.0, "rf": 4.0, "hip": Vector2(-4, -15), "torso": 1.0},
	"spark": {"rear": Vector2(-8, -4), "front": Vector2(8, -4), "r": 4.0, "rf": 4.0, "hip": Vector2(-5, -15), "torso": 0.3},
	"surge": {"rear": Vector2(-8, -4), "front": Vector2(9, -4), "r": 4.0, "rf": 4.0, "hip": Vector2(-4, -15), "torso": 0.9},
	"zip": {"rear": Vector2(-6, -3), "front": Vector2(7, -3), "r": 3.0, "rf": 3.0, "hip": Vector2(-5, -12), "torso": 0.0},
	"commuter": {"rear": Vector2(-8, -5), "front": Vector2(8, -5), "r": 5.0, "rf": 5.0, "hip": Vector2(-4, -16), "torso": 0.3},
	"boulder": {"rear": Vector2(-8, -5), "front": Vector2(8, -5), "r": 5.0, "rf": 5.0, "hip": Vector2(-4, -16), "torso": 0.35},
	"mono": {"wheel": Vector2(0, -5), "r": 5.0, "hip": Vector2(0, -16), "torso": 0.05},
	"goliath": {"wheel": Vector2(0, -7), "r": 7.0, "hip": Vector2(0, -19), "torso": 0.05},
}

## How each one goes. force: push at full gas (px/s^2 on a unit mass); top: top speed
## (px/s); grip: tire friction; mass; travel: suspension travel (px); lean: how hard
## the rider can throw it around; curve > 1 = an electric motor's flat torque;
## front_brake: the front brake's share (SUMMIT only, default 0.55): the chopper's tall
## seat put it over the bars under full brake at 0.55.
const SPEC := {
	"scrambler": {"force": 330.0, "top": 230.0, "grip": 1.10, "mass": 1.00, "travel": 3.0, "lean": 1.00, "com_up": 4.0},
	"dirt": {"force": 350.0, "top": 220.0, "grip": 1.30, "mass": 1.00, "travel": 4.5, "lean": 1.05, "com_up": 4.0},
	"minibike": {"force": 270.0, "top": 175.0, "grip": 1.05, "mass": 0.80, "travel": 2.0, "lean": 1.30, "com_up": 2.0},
	"scooter": {"force": 250.0, "top": 185.0, "grip": 0.95, "mass": 0.90, "travel": 1.6, "lean": 0.90, "com_up": 5.0},
	"cafe": {"force": 380.0, "top": 270.0, "grip": 1.00, "mass": 1.05, "travel": 2.0, "lean": 0.95, "com_up": 4.0},
	"chopper": {"force": 400.0, "top": 250.0, "grip": 1.05, "mass": 1.30, "travel": 2.6, "lean": 0.70, "com_up": 11.0, "front_brake": 0.25},
	"sport": {"force": 430.0, "top": 300.0, "grip": 1.00, "mass": 1.05, "travel": 2.0, "lean": 0.90, "com_up": 4.0},
	"spark": {"force": 380.0, "top": 210.0, "grip": 1.25, "mass": 0.85, "travel": 4.0, "lean": 1.15, "curve": 3.0, "com_up": 1.0},
	"surge": {"force": 470.0, "top": 290.0, "grip": 1.05, "mass": 1.10, "travel": 2.2, "lean": 0.90, "curve": 3.0, "com_up": 1.0},
	"zip": {"force": 260.0, "top": 165.0, "grip": 1.00, "mass": 0.75, "travel": 1.6, "lean": 1.00, "curve": 3.0, "com_up": 3.0},
	"commuter": {"force": 240.0, "top": 155.0, "grip": 1.10, "mass": 0.70, "travel": 2.5, "lean": 1.25, "curve": 3.0, "com_up": 4.0},
	"boulder": {"force": 270.0, "top": 165.0, "grip": 1.45, "mass": 0.80, "travel": 3.6, "lean": 1.10, "curve": 3.0, "com_up": 2.0},
	"mono": {"force": 520.0, "top": 150.0, "grip": 1.20, "mass": 0.70, "unicycle": true},
	"goliath": {"force": 600.0, "top": 195.0, "grip": 1.25, "mass": 0.90, "unicycle": true},
}

## SUMMIT upgrades: per level, what each one adds.
const UPGRADES := ["engine", "suspension", "tires", "tank"]
const MAX_LEVEL := 5


static func geo(id: String) -> Dictionary:
	return GEO.get(id, GEO.scrambler)


static func spec(id: String) -> Dictionary:
	return SPEC.get(id, SPEC.scrambler)


## Battery bikes: they top up at charge points instead of fuel cans, and whine.
const ELECTRIC := ["spark", "surge", "zip", "commuter", "boulder", "mono", "goliath"]


static func is_electric(id: String) -> bool:
	return id in ELECTRIC


## Which engine loops to play (assets/audio/engines/<id>_idle / _cruise).
static func sound_id(id: String) -> String:
	if FileAccess.file_exists("res://assets/audio/engines/%s_idle.ogg" % id) or \
			ResourceLoader.exists("res://assets/audio/engines/%s_idle.ogg" % id):
		return id
	return "scrambler"


static func is_unicycle(id: String) -> bool:
	return bool(spec(id).get("unicycle", false))


## The rider's head in drawing coordinates (the same sums draw_rider does, upright).
static func head_art(id: String) -> Vector2:
	var gm := geo(id)
	var a := float(gm.torso)
	var up := Vector2(sin(a), -cos(a))
	return (gm.hip as Vector2) + up * 10.0 + Vector2(0.5, 0)


## The rider's chest and shoulders in drawing coordinates: [centre, radius] crash sensors.
static func body_art(id: String) -> Array:
	var gm := geo(id)
	var a := float(gm.torso)
	var up := Vector2(sin(a), -cos(a))
	var hip: Vector2 = gm.hip
	return [[hip + up * 3.5, 1.8], [hip + up * 6.5, 2.0]]


## GAUNTLET riders throw their weight around much harder (trials technique: the front
## comes up on demand, so steps and ledges can be climbed), but as a held pitch, not a
## flat push (see hold_lean in vehicle_sim.gd). SUMMIT keeps it mild, so gas on a hill
## doesn't loop you over.
const TRIALS_LEAN := 10.0
## SUMMIT (since 0.10.1): each bike's centre of mass sits com_up px higher (SPEC) and
## the rider doesn't lean on the ground (only in the air). Stock, full gas on the flat
## lifts the front 5-25 degrees (by bike), but up a climb of about 30 degrees it keeps
## coming up until you're over backwards: hold gas all the way and you flip. (0.10.0's
## bikes held the front down by themselves, so holding gas topped most climbs.) com_up
## was picked per bike from held-gas tests; the electric ones, with their flat torque,
## take less. ENGINE upgrades' extra push is limited (WHEELIE_K) so they don't loop
## you on the flat. Static vars so tuning runs can shift them.
static var tune_com_up := 0.0
static var tune_lean := 0.0
## SUMMIT: the ENGINE upgrades' extra push stops at this share of what lifts the front.
const WHEELIE_K := 0.9
## SUMMIT unicycles: how far forward full gas leans the rider (rad).
static var tune_uni_lean := 0.25
## GAUNTLET hop (vehicle_sim.gd hop_v), px/s at lean 1.0: about 8 px of air.
const HOP_V := 100.0
## GAUNTLET face grip (vehicle_sim.gd face_grip): the back tyre climbs a face it's
## pressed into under gas, carrying this many times the bike's weight.
const FACE_GRIP := 1.4


## A ready-to-place sim for a bike. up: upgrade levels {"engine": n, ...} (SUMMIT).
static func build(id: String, terrain, up := {}, mode := "summit") -> RefCounted:
	var gm := geo(id)
	var sp := spec(id)
	var s = Sim.new()
	s.terrain = terrain
	var e := float(up.get("engine", 0))
	var su := float(up.get("suspension", 0))
	var ti := float(up.get("tires", 0))
	s.mass = float(sp.mass)
	s.grip = float(sp.grip) + 0.06 * ti
	var head := head_art(id)
	var hip: Vector2 = gm.hip
	if bool(sp.get("unicycle", false)):
		var wp: Vector2 = gm.wheel
		var r := float(gm.r)
		# Centre of mass: mostly the rider, standing over the wheel.
		var com := Vector2(0, (wp.y * 0.3 + (hip.y - 3.0) * 0.7))
		s.unicycle = true
		s.art = -com
		s.inertia = 45.0 * s.mass
		var w = Sim.Wheel.new()
		w.mount = wp - com
		w.r = r
		w.m = 0.18
		w.iw = 0.6 * w.m * r * r
		w.driven = true
		s.wheels = [w]
		s.torque = float(sp.force) * (s.mass + w.m) * r * (1.0 + 0.1 * e)
		s.top_w = float(sp.top) * (1.0 + 0.06 * e) / r
		# Balance: stiff enough to beat gravity's pull on the rider (3x it per radian),
		# damped near critically. Asking for more lean than the motor can hold (about
		# atan(force / g)) would tip it over, so gas and brake ask for 0.15 rad.
		var arm := absf(com.y - wp.y)
		s.balance_p = 3.0 * (s.mass + w.m) * s.g * arm
		s.balance_d = 2.0 * sqrt(s.balance_p * s.inertia)
		s.balance_lean = 0.15 if mode == "gauntlet" else tune_uni_lean
		s.lean_air = 16.0 * s.inertia
		if mode == "gauntlet":
			s.hop_v = HOP_V * 0.9
			s.face_grip = FACE_GRIP
		else:
			s.overpower_t = 0.35
		s.hulls = [[Vector2(0, wp.y - r - 1.0) - com, 2.0]]
		s.head = head - com
		s.body = body_art(id).map(func(b): return [(b[0] as Vector2) - com, b[1]])
		return s
	var rear: Vector2 = gm.rear
	var front: Vector2 = gm.front
	var rr := float(gm.r)
	var rf := float(gm.rf)
	# Centre of mass: low, just above the axles and a touch behind the middle. The
	# drawn rider stands tall for a 16-20 px wheelbase; weighting the physics by the
	# drawing would make every bike loop over backwards at the first touch of gas.
	var cu := float(sp.get("com_up", 3.0)) + tune_com_up if mode == "summit" else 0.0
	var com := Vector2((rear.x + front.x) * 0.5 - 1.0, minf(rear.y, front.y) - 3.5 - cu)
	s.art = -com
	var wb := front.x - rear.x
	s.inertia = s.mass * (wb * wb / 12.0 + 60.0)
	var travel := float(sp.travel) + 0.2 * su
	var ws := []
	for i in 2:
		var w = Sim.Wheel.new()
		var at: Vector2 = rear if i == 0 else front
		w.r = rr if i == 0 else rf
		w.m = 0.07 + 0.012 * w.r
		w.iw = 0.6 * w.m * w.r * w.r
		w.mount = at - com
		# Rear: swingarm, about straight down. Front: along the fork, raked forward.
		w.axis = Vector2(0, 1) if i == 0 else Vector2(0.32, 0.95).normalized()
		var load: float = s.mass * s.g * 0.5
		w.hi = travel * 0.4
		w.lo = -travel * 0.6
		w.preload_x = travel * 0.35
		w.k = load / w.preload_x
		var zeta := 0.32 + 0.06 * su
		w.c = 2.0 * zeta * sqrt(w.k * s.mass * 0.5)
		w.driven = i == 0
		ws.append(w)
	s.wheels = ws
	# ENGINE upgrades add power, not pull off the line: their extra torque comes in
	# with wheel speed (vehicle_sim.gd boost), so an upgraded bike doesn't loop over
	# from a standstill.
	s.torque = float(sp.force) * (s.mass + 0.3) * rr
	s.boost = 0.1 * e
	s.top_w = float(sp.top) * (1.0 + 0.06 * e) / rr
	s.curve = float(sp.get("curve", 1.0))
	s.brake_t = s.torque * 1.3
	s.front_brake = float(sp.get("front_brake", 0.55)) if mode == "summit" else 0.55
	s.reverse_w = 60.0 / rr
	var lean := float(sp.get("lean", 1.0))
	s.lean_ground = 3.2 * s.inertia * lean * (TRIALS_LEAN if mode == "gauntlet" else tune_lean)
	if mode == "gauntlet":
		s.hop_v = HOP_V * sqrt(lean)
		s.face_grip = FACE_GRIP
		# The rider holds a pitch (vehicle_sim.gd hold_lean): about 12 rad/s, a little
		# under critical damping, with lean_ground as the most they can push.
		s.hold_lean = true
		s.hold_p = s.inertia * 144.0
		s.hold_d = 2.0 * 0.8 * 12.0 * s.inertia
	s.lean_air = 9.0 * s.inertia * lean
	if mode == "summit":
		# Wheelie limit for the ENGINE upgrades' extra push (vehicle_sim.gd cap_k):
		# taking moments about the rear tyre, the front lifts when the push at the tyre
		# passes m g d' / h' (the centre of mass d' ahead of it and h' above, at the
		# bike's pitch). The extra push stops at WHEELIE_K x that, so an upgraded bike
		# is no more likely to loop over on the flat than a stock one.
		s.cap_k = WHEELIE_K
		s.top_w0 = float(sp.top) / rr
		s.cap_d = com.x - rear.x
		s.cap_h = -com.y
		s.cap_r = rr
	# Belly (engine), tail and nose: they slide on the ground; the head crashes.
	var belly_y := minf(rear.y, front.y) - 2.5
	s.hulls = [
		[Vector2((rear.x + front.x) * 0.5, belly_y) - com, 2.5],
		[Vector2(rear.x - 4.0, rear.y - 6.0) - com, 2.0],
		[Vector2(front.x - 2.0, front.y - 8.0) - com, 2.0],
	]
	s.head = head - com
	s.body = body_art(id).map(func(b): return [(b[0] as Vector2) - com, b[1]])
	return s


## SUMMIT fuel (or charge): seconds of riding in a full tank / battery.
static func tank_seconds(id: String, up := {}) -> float:
	var base := 26.0 if not bool(spec(id).get("unicycle", false)) else 24.0
	return base * (1.0 + 0.2 * float(up.get("tank", 0)))


## Price of the next level of an upgrade.
static func upgrade_cost(level: int) -> int:
	return [120, 260, 480, 800, 1250][clampi(level, 0, MAX_LEVEL - 1)]
