## Vehicle physics for SUMMIT (hill climb) and GAUNTLET (trials). One rigid frame
## (bike + rider), one or two wheels on spring-damper suspension (an electric
## unicycle's wheel sits on a fixed axle and a balance controller keeps it upright),
## tire friction against the terrain's segments, a motor and brakes whose reaction
## twists the frame (so gas lifts the nose and braking dips it, like a real bike),
## and rider lean: gas leans back, brake leans forward.
##
## Fixed 1/240 s substeps with sequential impulses, all in GDScript floats, so a run
## with the same inputs comes out the same every time; the level checkers rely on it.
##
## Units: px, s. Angles: radians, positive = clockwise on screen (nose down when
## facing right). Vectors in a frame-local space have the centre of mass at (0, 0).
extends RefCounted

const SUB := 4
const H := 1.0 / 240.0
const ITER := 8
const SLOP := 0.25      # px of overlap allowed before pushing out
const BETA := 0.25      # share of overlap pushed out per substep

## Tunables, set from the vehicle spec (vehicles.gd) by setup().
var g := 600.0
var mass := 1.0
var inertia := 70.0
var torque := 1200.0        # peak motor torque at the driven wheel
var top_w := 65.0           # wheel spin (rad/s) where the motor gives out
var curve := 1.0            # 1 = torque falls linearly to top_w; >1 holds flat longer (electric)
var brake_t := 1600.0
var reverse_w := 14.0       # reverse top spin
var lean_ground := 260.0    # rider lean torque on the ground
var lean_air := 620.0       # ...and in the air
var air_damp := 0.0
var grip := 1.1             # tire friction coefficient
var hull_grip := 0.55
var unicycle := false
var balance_p := 9000.0     # unicycle balance controller
var balance_d := 900.0
var balance_lean := 0.32    # rad of lean asked for at full gas / brake
var tip_limit := 1.25       # unicycle: past this lean it can't recover (a crash)
## GAUNTLET: on the ground the rider throws their weight with the full lean_ground
## push, but only up to an envelope: hold_up rad nose-up above the slope just ahead
## (gas) or hold_down nose-down (brake). Past it they hold the bike there instead
## (stiffness hold_p, damping hold_d, up to twice the push). So a tap of gas pops the front up hard, and
## holding it gives a steady wheelie instead of a loop-out onto the tail.
## Off (SUMMIT): lean_ground is a flat push.
var hold_lean := false
var hold_up := 0.6
var hold_down := 0.25
var hold_p := 0.0           # set by place(): stiffness and damping of the hold
var hold_d := 0.0
var ground_ang := 0.0       # the slope under and just ahead of the bike (step())

## State.
var pos := Vector2.ZERO
var vel := Vector2.ZERO
var ang := 0.0
var angvel := 0.0
var wheels: Array = []      # Wheel
var hulls: Array = []       # [local centre, radius]: the frame's belly and ends, they slide
var head := Vector2(0, -14) # local: the rider's head; touching ground = a crash
var head_r := 3.0
var art := Vector2(0, 10)   # local position of the drawing's origin (ground point between the wheels)

## Inputs (0..1), set before step().
var gas := 0.0
var brake := 0.0
var lean_sign := 1.0        # -1: SWAP LEAN (gas tips the nose down instead)

## Outputs, refreshed every step.
var crashed := false
var grounded := false       # any wheel touching
var wheel_grounded := []    # per wheel
var landed_hard := 0.0      # biggest touchdown speed this frame
var airtime := 0.0
var flips := 0              # full turns since leaving the ground (sign = direction)
var _air_ang := 0.0
var drive_w := 0.0          # driven wheel's spin, for the engine sound
var terrain = null          # terrain.gd


class Wheel:
	var mount := Vector2.ZERO    # local: where the wheel's centre sits at rest
	var axis := Vector2(0, 1)    # local: suspension direction (out of the frame)
	var lo := -3.0               # travel: most compressed (along axis)
	var hi := 2.0                # ...most extended
	var preload_x := 1.5         # spring's free position (sags back to ~0 under load)
	var k := 200.0
	var c := 10.0
	var r := 4.0
	var m := 0.12
	var iw := 0.96
	var driven := false
	var brakes := true
	var p := Vector2.ZERO
	var v := Vector2.ZERO
	var spin := 0.0
	var omega := 0.0
	var contacts: Array = []     # [n, depth, ln, lt] (ln/lt: accumulated impulses)
	var lim_l := 0.0             # accumulated travel-limit impulse
	var lat_l := 0.0


static func _cross(a: Vector2, b: Vector2) -> float:
	return a.x * b.y - a.y * b.x


static func _perp(w: float, r: Vector2) -> Vector2:
	return Vector2(-w * r.y, w * r.x)


## Put the vehicle at rest with the drawing's origin (between the wheels, on the
## ground) at `ground` and the frame turned by `a`.
func place(ground: Vector2, a := 0.0) -> void:
	ang = a
	pos = ground - art.rotated(a)
	vel = Vector2.ZERO
	angvel = 0.0
	for w: Wheel in wheels:
		w.p = pos + w.mount.rotated(a)
		w.v = Vector2.ZERO
		w.omega = 0.0
	crashed = false
	airtime = 0.0
	flips = 0


func _vel_at(r: Vector2) -> Vector2:
	return vel + _perp(angvel, r)


func _impulse(j: Vector2, r: Vector2) -> void:
	vel += j / mass
	angvel += _cross(r, j) / inertia


## One 1/60 s frame.
func step() -> void:
	landed_hard = 0.0
	var was := grounded
	if hold_lean and terrain != null:
		# The rider reads the ground from the back wheel to a little past the front.
		var x0 := pos.x - 10.0
		var x1 := pos.x + 14.0
		var y0: float = terrain.top_at(x0)
		var y1: float = terrain.top_at(x1)
		# Over a pit (or nothing) keep the last reading.
		if is_finite(y0) and is_finite(y1) and absf(y1 - y0) < 60.0:
			ground_ang = clampf(atan2(y1 - y0, x1 - x0), -0.9, 0.9)
	for i in SUB:
		_substep()
	grounded = false
	wheel_grounded = []
	for w: Wheel in wheels:
		var on: bool = not (w.contacts as Array).is_empty()
		wheel_grounded.append(on)
		grounded = grounded or on
	if grounded:
		airtime = 0.0
		_air_ang = ang
	else:
		airtime += SUB * H
		if was:
			_air_ang = ang
		# Full turns so far in this jump (85% of a turn counts, so landing a touch
		# short still scores).
		var turned := ang - _air_ang
		flips = int(signf(turned)) * int((absf(turned) + TAU * 0.15) / TAU)


func _substep() -> void:
	var rot := Transform2D(ang, Vector2.ZERO)
	# --- forces: gravity, suspension, motor, brakes, lean ------------------------
	vel.y += g * H
	var any_ground := false
	for w: Wheel in wheels:
		w.v.y += g * H
		any_ground = any_ground or not (w.contacts as Array).is_empty()
	for w: Wheel in wheels:
		if unicycle:
			break
		var ax: Vector2 = rot * w.axis
		var rm: Vector2 = rot * w.mount
		var x: float = (w.p - (pos + rm)).dot(ax)
		var rel: float = (w.v - _vel_at(rm)).dot(ax)
		var f: float = -w.k * (x - w.preload_x) - w.c * rel
		var j: float = f * H
		w.v += ax * j / w.m
		_impulse(-ax * j, rm)
	# Motor (driven wheels) and brakes, with the reaction on the frame.
	var lean_in := (gas - brake) * lean_sign   # >0 leans back (nose up)
	if unicycle:
		var w: Wheel = wheels[0]
		# Gas leans the rider forward and the wheel drives under them; brake leans back.
		var target := (gas - brake) * balance_lean
		# Tilt-back: past top speed the pedals push the rider back, as real ones do.
		var v := _forward_speed()
		var over := absf(v) - top_w * w.r
		if over > 0.0:
			target -= signf(v) * minf(over * 0.006, 0.3)
		if any_ground:
			var tq := clampf(balance_p * (ang - target) + balance_d * angvel, -torque, torque)
			w.omega += tq * H / w.iw
			angvel -= tq * H / inertia
		else:
			# In the air the wheel coasts and the rider holds the board level with body
			# English (gas / brake still tip it, like a bike).
			var ta := clampf(0.5 * balance_p * (ang - (gas - brake) * 0.08) + balance_d * angvel, -lean_air, lean_air)
			angvel -= ta * H / inertia
		drive_w = w.omega
	else:
		for w: Wheel in wheels:
			var tq := 0.0
			if w.driven:
				if gas > 0.0:
					var f := clampf(1.0 - pow(maxf(w.omega, 0.0) / top_w, curve), 0.0, 1.0)
					tq += gas * torque * f
				elif brake > 0.0 and w.omega < 1.5:
					# Stopped (or rolling back) and braking: reverse, slowly.
					var fr := clampf(1.0 - maxf(-w.omega, 0.0) / reverse_w, 0.0, 1.0)
					tq -= brake * torque * 0.4 * fr
				drive_w = w.omega
			if brake > 0.0 and w.brakes and w.omega >= 1.5:
				var stop := -w.omega * w.iw / H
				# Front brake softer, so hard braking dips the nose without an endo.
				var lim := brake * brake_t * (1.0 if w.driven else 0.55)
				tq += clampf(stop, -lim, lim)
			w.omega += tq * H / w.iw
			angvel -= tq * H / inertia
		if hold_lean and any_ground:
			if lean_in != 0.0:
				var tq := lean_in * lean_ground
				var rel := ang - ground_ang       # < 0: nose up
				if lean_in > 0.0 and rel < -hold_up * lean_in:
					tq = clampf(hold_p * (ang - (ground_ang - hold_up * lean_in)) + hold_d * angvel, -2.0 * lean_ground, 2.0 * lean_ground)
				elif lean_in < 0.0 and rel > hold_down * -lean_in:
					tq = clampf(hold_p * (ang - (ground_ang + hold_down * -lean_in)) + hold_d * angvel, -2.0 * lean_ground, 2.0 * lean_ground)
				angvel -= tq * H / inertia
		else:
			var lt := lean_ground if any_ground else lean_air
			angvel -= lean_in * lt * H / inertia
	if not any_ground and air_damp > 0.0:
		angvel *= 1.0 - air_damp * H
	# --- contacts -------------------------------------------------------------------
	for w: Wheel in wheels:
		w.contacts = []
		for c in terrain.circle_contacts(w.p, w.r, 0.4):
			w.contacts.append([c[0], c[1], 0.0, 0.0])
		w.lim_l = 0.0
		w.lat_l = 0.0
	var hc := []   # [local r, n, depth, ln, lt]
	for hl in hulls:
		var rl: Vector2 = rot * (hl[0] as Vector2)
		for c in terrain.circle_contacts(pos + rl, float(hl[1]), 0.3):
			hc.append([rl, c[0], c[1], 0.0, 0.0, float(hl[1])])
	var hr: Vector2 = rot * head
	var head_hits: Array = terrain.circle_contacts(pos + hr, head_r, 0.0)
	for c in head_hits:
		if float(c[1]) > 0.2:
			crashed = true
		hc.append([hr, c[0], c[1], 0.0, 0.0, head_r])
	for w: Wheel in wheels:
		for c in w.contacts:
			var vn: float = (w.v as Vector2).dot(c[0])
			if vn < -landed_hard:
				landed_hard = -vn
	# --- solve ----------------------------------------------------------------------
	for it in ITER:
		for w: Wheel in wheels:
			_solve_joint(w, rot)
			_solve_wheel_contacts(w)
		for c in hc:
			_solve_hull(c)
	# --- integrate positions ---------------------------------------------------------
	pos += vel * H
	ang += angvel * H
	for w: Wheel in wheels:
		w.p += w.v * H
		w.spin += w.omega * H
	if unicycle and absf(ang) > tip_limit:
		crashed = true


func _forward_speed() -> float:
	return vel.dot(Vector2.RIGHT.rotated(ang))


## The wheel rides in a slot along the suspension axis: no sideways play, and hard
## stops at both ends of the travel (a unicycle's axle is locked: both ends at 0).
func _solve_joint(w: Wheel, rot: Transform2D) -> void:
	var ax: Vector2 = rot * w.axis
	var rm: Vector2 = rot * w.mount
	var d: Vector2 = w.p - (pos + rm)
	# Sideways.
	var n := Vector2(-ax.y, ax.x)
	var cn := _cross(rm, n)
	var k := 1.0 / w.m + 1.0 / mass + cn * cn / inertia
	var cdot := (w.v - _vel_at(rm)).dot(n)
	var lam := -(cdot + BETA / H * d.dot(n)) / k
	w.v += n * lam / w.m
	_impulse(-n * lam, rm)
	# Along: travel limits.
	var x := d.dot(ax)
	var lo: float = 0.0 if unicycle else w.lo
	var hi: float = 0.0 if unicycle else w.hi
	var ca := _cross(rm, ax)
	var ka := 1.0 / w.m + 1.0 / mass + ca * ca / inertia
	var vrel := (w.v - _vel_at(rm)).dot(ax)
	if unicycle:
		var l2 := -(vrel + BETA / H * x) / ka
		w.v += ax * l2 / w.m
		_impulse(-ax * l2, rm)
	elif x < lo + 0.05:
		# Bottomed out: may only push the wheel back out (+axis).
		var l3 := -(vrel + BETA / H * minf(x - lo, 0.0)) / ka
		var old := w.lim_l
		w.lim_l = maxf(old + l3, 0.0)
		l3 = w.lim_l - old
		w.v += ax * l3 / w.m
		_impulse(-ax * l3, rm)
	elif x > hi - 0.05:
		var l4 := -(vrel + BETA / H * maxf(x - hi, 0.0)) / ka
		var old2 := w.lim_l
		w.lim_l = minf(old2 + l4, 0.0)
		l4 = w.lim_l - old2
		w.v += ax * l4 / w.m
		_impulse(-ax * l4, rm)


func _solve_wheel_contacts(w: Wheel) -> void:
	for c in w.contacts:
		var n: Vector2 = c[0]
		var depth: float = c[1]
		# Normal: the wheel alone (the joint passes it on to the frame).
		var vn := w.v.dot(n)
		var bias := -BETA / H * maxf(depth - SLOP, 0.0)
		var ln := -(vn + bias) * w.m
		var old: float = c[2]
		c[2] = maxf(old + ln, 0.0)
		ln = c[2] - old
		w.v += n * ln / w.m
		# Friction couples the wheel's travel and its spin.
		var t := Vector2(-n.y, n.x)
		var rc := -n * w.r
		var vc := w.v + _perp(w.omega, rc)
		var vt := vc.dot(t)
		var crt := _cross(rc, t)
		var kt := 1.0 / w.m + crt * crt / w.iw
		var lt := -vt / kt
		var maxf_ := grip * float(c[2])
		var old_t: float = c[3]
		c[3] = clampf(old_t + lt, -maxf_, maxf_)
		lt = c[3] - old_t
		w.v += t * lt / w.m
		w.omega += crt * lt / w.iw


## A frame part (belly, tail, the rider's head) on the ground: pushes the frame out,
## slides with some friction.
func _solve_hull(c: Array) -> void:
	var rl: Vector2 = c[0]
	var n: Vector2 = c[1]
	var depth: float = c[2]
	var rc: Vector2 = rl - n * float(c[5])
	var cn := _cross(rc, n)
	var k := 1.0 / mass + cn * cn / inertia
	var vn := _vel_at(rc).dot(n)
	var bias := -BETA / H * maxf(depth - SLOP, 0.0)
	var ln := -(vn + bias) / k
	var old: float = c[3]
	c[3] = maxf(old + ln, 0.0)
	ln = c[3] - old
	_impulse(n * ln, rc)
	var t := Vector2(-n.y, n.x)
	var ct := _cross(rc, t)
	var kt := 1.0 / mass + ct * ct / inertia
	var lt := -_vel_at(rc).dot(t) / kt
	var lim := hull_grip * float(c[3])
	var old_t: float = c[4]
	c[4] = clampf(old_t + lt, -lim, lim)
	lt = c[4] - old_t
	_impulse(t * lt, rc)


# --- snapshots (bots search from a saved state) ------------------------------------

## Everything the next step depends on, so a reloaded state steps exactly as the
## original would (the search reloads every 0.1 s; dropping the wheels' contacts made a
## unicycle think it was in the air for a moment each time and fall on climbs).
func save() -> Array:
	var ws := []
	for w: Wheel in wheels:
		ws.append([w.p, w.v, w.spin, w.omega, (w.contacts as Array).duplicate(true)])
	return [pos, vel, ang, angvel, ws, crashed, airtime, _air_ang, grounded, wheel_grounded.duplicate(),
		flips, ground_ang]


func load_state(s: Array) -> void:
	pos = s[0]
	vel = s[1]
	ang = s[2]
	angvel = s[3]
	for i in wheels.size():
		var ws: Array = s[4][i]
		wheels[i].p = ws[0]
		wheels[i].v = ws[1]
		wheels[i].spin = ws[2]
		wheels[i].omega = ws[3]
		wheels[i].contacts = (ws[4] as Array).duplicate(true) if ws.size() > 4 else []
	crashed = s[5]
	airtime = s[6]
	_air_ang = s[7]
	grounded = s[8]
	if s.size() > 11:
		wheel_grounded = (s[9] as Array).duplicate()
		flips = s[10]
		ground_ang = s[11]


## World position of a frame-local point.
func world(local: Vector2) -> Vector2:
	return pos + local.rotated(ang)


func speed() -> float:
	return _forward_speed()
