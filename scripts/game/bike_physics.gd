## Deterministic fixed-step rider physics, shared by the live game and the dev bot.
## Everything here is a pure function of (level, state, input), so the bot can
## roll states forward to test whether a jump is safe.
extends RefCounted

const DT := 1.0 / 60.0

# Vertical motion (pixels, seconds). Full hold peaks ~60px, a tap ~26px.
const G_UP := 1000.0       # rising while the button is held
const G_CUT := 2300.0      # rising after release: short hop
const G_FALL := 1200.0
const MAX_FALL := 520.0
const JUMP_V := 345.0
const RAMP_BOOST := 0.6    # share of an upslope's vertical speed added to a jump
const STOMP_V := 250.0
const STOMP_V_HELD := 330.0

# Weather. Rain: weaker takeoff and a forward slide after landing that grip slowly
# pulls back to cruise speed. Wind: gusty headwind that drags airborne speed down.
const RAIN_TAKEOFF := 0.95  # jump velocity multiplier on a wet deck
const RAIN_SLIDE := 0.32    # landing slide, as a share of cruise speed at a hard landing
const GRIP_DRY := 14.0      # per second: how fast speed returns to cruise on the deck
const GRIP_WET := 1.6
const WIND_PEAK := 34.0     # px/s of headwind at the top of a gust
const WIND_DRAG := 3.2      # per second: how fast airborne speed follows the wind

# Forgiveness windows.
const COYOTE := 0.08       # can still jump this long after leaving an edge
const BUFFER := 0.12       # a press this early before landing still counts
const CONT_TOL := 6.0      # max step between joined track pieces

# Track features.
const SPRING_V := 440.0    # spring pad launch (~97 px high, fixed arc)
const SPRING_W := 7.0      # half width of a pad
const SPRING_KICK := 1.35  # pads also kick you forward (share of cruise speed)
const BONK_VY := 200.0     # knocked down this fast after hitting a low ceiling
const BONK_SLOW := 0.7     # ...and keep this share of speed until the tire grips again
const ZIP_HANG := 19.0     # contact point below the cable while hanging from it
const ZIP_GRAB := 7.0      # hands this close to the cable (while holding) grab it
const ZIP_SPEED := 1.15    # cable ride speed vs cruise
const LOOP_SLOW := 0.14    # loop speed dips by this share at the top

# Bike specialties (see Catalog.bikes()).
const WHEELIE_RISE := 1.4  # per second: how fast a wheelie builds to its boost
const BOOST_DECAY := 0.8   # per second: boost bleeds off once the front wheel drops
const HOP_V := 285.0       # minibike second hop
const GLIDE_G := 260.0     # scooter umbrella: gravity while gliding
const GLIDE_MAX := 64.0    # ...and terminal fall speed
const DASH_T := 0.22       # cafe racer air dash: seconds of flat flight
const DASH_K := 0.6        # ...at this much extra speed
const SMASH_INV := 0.5     # chopper: brief invulnerability after smashing through

# Flips: tap in the air (rising = backflip, falling = front flip, again = one more).
const FLIP_RATE := 15.0     # rad/s: one flip takes ~0.42 s
const FLIP_TOL := 0.6       # rad either side of upright that still counts as landed
const SKETCHY_KEEP := 0.72  # share of speed kept after landing mid-flip
## An air tap only starts a flip if you'll stay up long enough to finish one: frames
## for a full turn, less the landing tolerance (~23 frames, 0.38 s). Otherwise the press
## is just a press (buffered jump near the deck; held through landing = wheelie).
const FLIP_MIN_AIR := int(ceil((TAU - FLIP_TOL) / FLIP_RATE / DT))

# Lanes (2.5D): -1 foreground, 0 main, 1 background. Switch ramps swing you across.
const SWITCH_W := 7.0

# Power-ups: pickups on the trail, timers in seconds (the HUD shows a bar).
const STICKY_T := 10.0      # sticky tires: jump at a marked wall to drive up it
const ROCKET_T := 2.5       # rocket: a burst of speed
const ROCKET_K := 0.75      # ...adding this share of cruise speed
const ROCKET_JUMP := 1.2    # ...and jumps take off this much harder
const MAGNET_T := 8.0       # coin magnet (pulls coins in; handled by the world)
const POWER_R := 8.0        # reach around a pickup icon
const CLIMB_K := 0.85       # wall climb speed vs cruise
const WALL_FRONT := 7.0     # front of the bike ahead of the contact point
## Crumbling planks hold this long after your wheels first touch them.
const CRUMBLE_DELAY := 0.3
## Collapse chase: the trestle falls away behind you. It starts CHASE_GAP px back,
## advances at CHASE_K x trail speed, and never trails by more than CHASE_MAX.
const CHASE_GAP := 80.0
const CHASE_MAX := 150.0
const CHASE_K := 0.99
const CHASE_K_WIND := 0.84
const CHASE_SURGE := 0.04

# Rider hitbox, relative to the contact point under the bike.
const HALF_W := 9.0
const HEIGHT := 16.0

const BUCKET := 256.0

enum {
	EV_JUMP = 1, EV_LAND = 2, EV_STOMP = 4, EV_DEAD = 8, EV_LEAVE = 16, EV_SPRING = 32,
	EV_BONK = 64, EV_LOOP = 128, EV_LOOP_OUT = 256, EV_ZIP = 512, EV_UNZIP = 1024,
	EV_AIR = 2048, EV_SMASH = 4096, EV_WHEELIE = 8192, EV_ARMOR = 16384,
	EV_FLIP = 32768, EV_TRICK = 65536, EV_SKETCHY = 131072, EV_SWITCH = 262144, EV_SWITCH_OUT = 524288,
	EV_POWER = 1048576, EV_CLIMB = 2097152, EV_CLIMB_OUT = 4194304, EV_WALL = 8388608, EV_HAT = 16777216,
	EV_CRUMBLE = 33554432,
}
enum { CRAWLER, SPIKER, DRONE }

static var _EMPTY := PackedInt32Array()


## ab: the bike's specialty, {"id": "wheelie"|"hop"|"glide"|"dash"|"tough", "k": strength}.
static func new_state(level: Dictionary, x: float, track: int, t: float = 0.0, ab: Dictionary = {}) -> Dictionary:
	var tr: Dictionary = level.tracks[track]
	var ab_id := String(ab.get("id", ""))
	var lane := int(tr.get("lane", 0))
	return {
		"x": x, "y": deck_y(tr, x, t), "vx": float(level.speed), "vy": 0.0,
		"grounded": true, "track": track, "slope": slope_at(tr, x),
		"coyote": COYOTE, "buffer": 0.0, "jumping": false, "cut": false,
		"alive": true, "death": "", "t": t,
		"stomped": {}, "last_stomp": -1, "last_smash": -1,
		"ab": ab_id, "ab_k": float(ab.get("k", 0.0)),
		"wheelie": false, "boost": 0.0, "air_used": false, "dash_t": 0.0,
		"armor": 1 if ab_id == "tough" else 0, "inv_t": 0.0,
		"loop": -1, "loop_a": 0.0, "zip": -1, "spring": -1,
		"lane": lane, "lane_z": float(lane), "sw": -1, "sw_u": 0.0, "sw_x0": 0.0,
		"flip_dir": 0, "flip_a": 0.0, "flip_target": 0.0, "tb": 0, "tf": 0,
		"trick_coins": 0, "trick_name": "",
		"sticky_t": 0.0, "rocket_t": 0.0, "magnet_t": 0.0, "hat": 0, "got": {}, "last_power": "",
		"climb": -1, "crumb": {},
		"chase_x": x - CHASE_GAP if level.has("chase") else -INF,
	}


## A state you can roll forward without touching the original (nested dicts copied).
static func copy_state(s0: Dictionary) -> Dictionary:
	var s := s0.duplicate()
	s.stomped = (s0.stomped as Dictionary).duplicate()
	s.got = (s0.got as Dictionary).duplicate()
	s.crumb = (s0.crumb as Dictionary).duplicate()
	return s


## Has this crumbling plank already fallen away (for this rider)?
static func track_gone(level: Dictionary, s: Dictionary, ti: int) -> bool:
	var tr: Dictionary = level.tracks[ti]
	return tr.has("crumble") and (s.crumb as Dictionary).has(ti) and float(s.t) - float(s.crumb[ti]) >= float(tr.crumble)


## Wheels on a crumbling plank start its countdown.
static func _touch(level: Dictionary, s: Dictionary, ti: int) -> int:
	if ti >= 0 and level.tracks[ti].has("crumble") and not (s.crumb as Dictionary).has(ti):
		s.crumb[ti] = s.t
		return EV_CRUMBLE
	return 0


## weather: "clear", "rain" or "wind".
static func apply_weather(level: Dictionary, weather: String) -> void:
	level.weather = weather
	level.rain = weather == "rain"
	level.wind = WIND_PEAK if weather == "wind" else 0.0


## Headwind at level time t: gusts between ~20% and 100% of the peak.
static func wind_at(level: Dictionary, t: float) -> float:
	var w: float = level.get("wind", 0.0)
	if w <= 0.0:
		return 0.0
	return w * (0.6 + 0.4 * sin(t * 0.83) * sin(t * 0.29 + 1.1))


# --- geometry ----------------------------------------------------------------

static func height_at(tr: Dictionary, x: float) -> float:
	var pts: PackedVector2Array = tr.pts
	var n := pts.size()
	if x <= pts[0].x:
		return pts[0].y
	if x >= pts[n - 1].x:
		return pts[n - 1].y
	var i := _segment(pts, x)
	var a := pts[i]
	var b := pts[i + 1]
	return a.y + (b.y - a.y) * (x - a.x) / (b.x - a.x)


## Lifts bob up and down: {"amp", "period", "phase"} on the track.
static func lift_dy(tr: Dictionary, t: float) -> float:
	if not tr.has("lift"):
		return 0.0
	var l: Dictionary = tr.lift
	return float(l.amp) * sin(TAU * t / float(l.period) + float(l.phase))


## Deck surface at level time t (includes lift motion).
static func deck_y(tr: Dictionary, x: float, t: float) -> float:
	return height_at(tr, x) + lift_dy(tr, t)


static func slope_at(tr: Dictionary, x: float) -> float:
	var pts: PackedVector2Array = tr.pts
	var n := pts.size()
	var i := 0
	if x >= pts[n - 1].x:
		i = n - 2
	elif x > pts[0].x:
		i = _segment(pts, x)
	var a := pts[i]
	var b := pts[i + 1]
	return (b.y - a.y) / (b.x - a.x)


static func _segment(pts: PackedVector2Array, x: float) -> int:
	var lo := 0
	var hi := pts.size() - 1
	while hi - lo > 1:
		var mid := (lo + hi) >> 1
		if pts[mid].x <= x:
			lo = mid
		else:
			hi = mid
	return lo


## Buckets are keyed by x cell and lane, so each lane only sees its own things.
static func bucket_key(x: float, lane: int) -> int:
	return int(floor(x / BUCKET)) * 4 + lane + 1


static func _near(level: Dictionary, key: String, x: float, lane := 0) -> PackedInt32Array:
	var b: Dictionary = level.get(key, {})
	return b.get(bucket_key(x, lane), _EMPTY)


static func tracks_near(level: Dictionary, x: float, lane := 0) -> PackedInt32Array:
	return level.track_buckets.get(bucket_key(x, lane), _EMPTY)


static func enemies_near(level: Dictionary, x: float, lane := 0) -> PackedInt32Array:
	return level.enemy_buckets.get(bucket_key(x, lane), _EMPTY)


static func pickups_near(level: Dictionary, x: float, lane := 0) -> PackedInt32Array:
	return level.pickup_buckets.get(bucket_key(x, lane), _EMPTY)


## Underside of a tunnel roof above x, or INF.
static func ceil_at(level: Dictionary, x: float, lane := 0) -> float:
	for ci in _near(level, "ceil_buckets", x, lane):
		var c: Dictionary = level.ceils[ci]
		if x >= c.x0 and x <= c.x1:
			return height_at(c, x)
	return INF


## Top surface of the rock over a tunnel at x (-INF: a mountain; cliffs have a deck on top).
static func ceil_top_at(level: Dictionary, x: float, lane := 0) -> float:
	for ci in _near(level, "ceil_buckets", x, lane):
		var c: Dictionary = level.ceils[ci]
		if x >= c.x0 and x <= c.x1:
			return float(c.get("top", -INF))
	return -INF


static func cable_y(z: Dictionary, x: float) -> float:
	return lerpf(z.y0, z.y1, clampf((x - z.x0) / (z.x1 - z.x0), 0.0, 1.0))


## Point on a loop at angle a (0 = entry at the bottom, TAU = exit).
static func loop_pos(L: Dictionary, a: float) -> Vector2:
	var r: float = L.r
	return Vector2(L.x + r * sin(a) + L.shift * a / TAU, L.y - r * (1.0 - cos(a)))


## Direction of travel around a loop (radians), for drawing the bike.
static func loop_angle(L: Dictionary, a: float) -> float:
	var r: float = L.r
	return atan2(-r * sin(a), r * cos(a) + L.shift / TAU)


## Enemy anchor at level time t: ground contact for walkers/spikers, centre for drones.
static func enemy_pos(level: Dictionary, e: Dictionary, t: float) -> Vector2:
	match int(e.type):
		CRAWLER:
			var span: float = e.x1 - e.x0
			var px: float = e.x0
			if span > 0.0:
				px = e.x1 - pingpong(t * e.speed + e.phase, span)
			return Vector2(px, deck_y(level.tracks[e.track], px, t))
		DRONE:
			return Vector2(e.x0 + sin(t * 1.3 + e.phase) * e.drift, e.y0 + sin(t * 3.0 + e.phase) * 3.0)
	if e.has("track"):
		return Vector2(e.x0, e.y0 + lift_dy(level.tracks[e.track], t))
	return Vector2(e.x0, e.y0)


static func enemy_rect(level: Dictionary, e: Dictionary, t: float) -> Rect2:
	var p := enemy_pos(level, e, t)
	match int(e.type):
		CRAWLER:
			return Rect2(p.x - 7.0, p.y - 9.0, 14.0, 9.0)
		SPIKER:
			return Rect2(p.x - 6.0, p.y - 12.0, 12.0, 12.0)
	return Rect2(p.x - 7.0, p.y - 4.0, 14.0, 8.0)


## Middle of the bike body (inside a loop the body points at the loop's centre).
static func bike_center(level: Dictionary, s: Dictionary) -> Vector2:
	if int(s.loop) >= 0:
		var L: Dictionary = level.loops[s.loop]
		var a: float = s.loop_a
		return loop_pos(L, a) + Vector2(-sin(a), -cos(a)) * (HEIGHT * 0.5)
	return Vector2(s.x, s.y - HEIGHT * 0.5)


static func bike_rect(s: Dictionary, level: Dictionary = {}) -> Rect2:
	if int(s.loop) >= 0 and not level.is_empty():
		var c := bike_center(level, s)
		return Rect2(c.x - HALF_W, c.y - HEIGHT * 0.5, HALF_W * 2.0, HEIGHT - 1.0)
	return Rect2(s.x - HALF_W, s.y - HEIGHT, HALF_W * 2.0, HEIGHT - 1.0)


static func find_continuation(level: Dictionary, x: float, y: float, cur: int, t: float, lane := 0,
		s: Dictionary = {}) -> int:
	var best := -1
	var best_d := CONT_TOL
	for ti in tracks_near(level, x, lane):
		if ti == cur or (not s.is_empty() and track_gone(level, s, ti)):
			continue
		var tr: Dictionary = level.tracks[ti]
		if x < tr.x0 or x > tr.x1:
			continue
		var d := absf(deck_y(tr, x, t) - y)
		if d <= best_d:
			best = ti
			best_d = d
	return best


## Is there a deck within `dist` px under the rider? (An air press that close to a
## landing is treated as a buffered jump, not a specialty move.)
static func deck_below(level: Dictionary, s: Dictionary, dist: float) -> bool:
	for ti in tracks_near(level, s.x, int(s.lane)):
		var tr: Dictionary = level.tracks[ti]
		if s.x < tr.x0 or s.x > tr.x1 or track_gone(level, s, ti):
			continue
		var d := deck_y(tr, s.x, s.t) - float(s.y)
		if d >= -1.0 and d <= dist:
			return true
	return false


# --- step --------------------------------------------------------------------

## Advance one fixed step. Returns a bitmask of EV_* flags.
static func step(level: Dictionary, s: Dictionary, pressed: bool, held: bool) -> int:
	var ev := 0
	var base: float = level.speed
	var rain: bool = level.get("rain", false)
	var t_old: float = s.t
	s.t += DT
	if s.inv_t > 0.0:
		s.inv_t = maxf(0.0, s.inv_t - DT)
	for k in ["sticky_t", "rocket_t", "magnet_t"]:
		if float(s[k]) > 0.0:
			s[k] = maxf(0.0, float(s[k]) - DT)
	if float(s.chase_x) > -INF and float(s.x) < float(level.finish_x):
		# Headwind slows you in the air, so in wind the collapse comes on slower.
		var k := CHASE_K_WIND if float(level.get("wind", 0.0)) > 0.0 else CHASE_K
		# It surges every 10 s (you see the dust wall creep up), then falls back.
		k += CHASE_SURGE * maxf(0.0, sin(TAU * float(s.t) / 10.0))
		s.chase_x = maxf(float(s.chase_x) + base * k * DT, float(s.x) - CHASE_MAX)
		if float(s.chase_x) >= float(s.x) - HALF_W:
			s.alive = false
			s.death = "collapse"
			return ev | EV_DEAD

	if pressed:
		s.buffer = BUFFER
	elif s.buffer > 0.0:
		s.buffer = maxf(0.0, s.buffer - DT)
	if s.grounded:
		s.coyote = COYOTE
	elif s.coyote > 0.0:
		s.coyote = maxf(0.0, s.coyote - DT)

	# Wheelie: front wheel up while held after a landing; speed builds, then bleeds off.
	if s.ab == "wheelie":
		if s.wheelie and (not held or not s.grounded):
			s.wheelie = false
		if s.wheelie:
			s.boost += (base * float(s.ab_k) - s.boost) * minf(1.0, WHEELIE_RISE * DT)
		elif s.boost > 0.0:
			s.boost = maxf(0.0, s.boost - s.boost * minf(1.0, BOOST_DECAY * DT) - 0.05)
	var cruise: float = base + s.boost + (base * ROCKET_K if float(s.rocket_t) > 0.0 else 0.0)

	if s.loop >= 0:
		return _loop_step(level, s, cruise)
	if s.sw >= 0:
		return _switch_step(level, s, cruise)
	if int(s.climb) >= 0:
		return _climb_step(level, s, cruise)

	var ox: float = s.x
	var oy: float = s.y
	if s.zip >= 0:
		ev |= _zip_step(level, s, held, cruise)
		return _finish_step(level, s, ev, oy, false, held)

	if s.buffer > 0.0 and s.coyote > 0.0:
		var boost := minf(0.0, s.slope * s.vx) * RAMP_BOOST if s.grounded else 0.0
		s.vy = -JUMP_V * (RAIN_TAKEOFF if rain else 1.0) * (ROCKET_JUMP if float(s.rocket_t) > 0.0 else 1.0) + boost
		s.grounded = false
		s.track = -1
		s.coyote = 0.0
		s.buffer = 0.0
		s.jumping = true
		s.cut = false
		s.wheelie = false
		s.air_used = false
		ev |= EV_JUMP
	elif pressed and not s.grounded and not s.air_used and (s.ab == "hop" or s.ab == "dash"):
		if s.vy < 0.0 or not deck_below(level, s, maxf(10.0, s.vy * BUFFER + 6.0)):
			s.air_used = true
			s.buffer = 0.0
			if s.ab == "hop":
				s.vy = -HOP_V
				s.jumping = true
				s.cut = false
			else:
				s.dash_t = DASH_T
				s.vy = 0.0
				s.jumping = false
			ev |= EV_AIR
	elif pressed and not s.grounded and s.coyote <= 0.0 and s.zip < 0:
		# Flip: rising = backflip, falling = front flip; tapping mid-flip adds one more
		# (that one isn't checked: stacking flips is the gamble). The scooter's press
		# while falling is its umbrella, not a flip.
		if int(s.flip_dir) != 0:
			s.buffer = 0.0
			s.flip_target = float(s.flip_target) + TAU
			ev |= EV_FLIP
		elif not (s.ab == "glide" and s.vy >= 0.0) \
				and (s.vy < 0.0 or not deck_below(level, s, maxf(10.0, s.vy * BUFFER + 6.0))) \
				and air_frames(level, s) >= FLIP_MIN_AIR:
			s.buffer = 0.0
			s.flip_dir = -1 if s.vy < 0.0 else 1
			s.flip_a = 0.0
			s.flip_target = TAU
			ev |= EV_FLIP
	if s.jumping and not held and s.vy < 0.0:
		s.cut = true

	if s.grounded:
		var grip := GRIP_WET if rain else GRIP_DRY
		s.vx += (cruise - s.vx) * minf(1.0, grip * DT)
	elif s.dash_t > 0.0:
		s.vx = base * (1.0 + DASH_K) + s.boost
	else:
		s.vx += (cruise - wind_at(level, s.t) - s.vx) * minf(1.0, WIND_DRAG * DT)

	var nx: float = ox + s.vx * DT
	var descending := false

	if s.grounded:
		var tr: Dictionary = level.tracks[s.track]
		var gone := track_gone(level, s, int(s.track))
		if nx <= tr.x1 and not gone:
			s.y = deck_y(tr, nx, s.t)
			s.slope = slope_at(tr, nx)
			ev |= _touch(level, s, int(s.track))
		else:
			var c := -1 if gone else find_continuation(level, nx, oy, s.track, s.t, int(s.lane), s)
			if c >= 0:
				ev |= _touch(level, s, c)
				s.track = c
				s.y = deck_y(level.tracks[c], nx, s.t)
				s.slope = slope_at(level.tracks[c], nx)
			else:
				# Ran off the end (or the plank fell): carry the slope's vertical speed into the air.
				s.grounded = false
				s.track = -1
				s.jumping = false
				s.cut = false
				s.wheelie = false
				s.air_used = false
				s.vy = 0.0 if gone else s.slope * s.vx
				s.y = oy + s.vy * DT
				ev |= EV_LEAVE
		s.x = nx
		if s.grounded:
			ev |= _deck_features(level, s, ox)
	else:
		if int(s.flip_dir) != 0:
			s.flip_a = minf(float(s.flip_a) + FLIP_RATE * DT, float(s.flip_target))
			if s.flip_a >= float(s.flip_target):
				# Came round upright: bank the flips and wait for the next tap.
				var n := int(round(float(s.flip_target) / TAU))
				if int(s.flip_dir) < 0:
					s.tb = int(s.tb) + n
				else:
					s.tf = int(s.tf) + n
				s.flip_dir = 0
				s.flip_a = 0.0
				s.flip_target = 0.0
		if s.dash_t > 0.0:
			s.dash_t = maxf(0.0, s.dash_t - DT)
			s.vy = 0.0
		elif s.ab == "glide" and held and s.vy > 0.0:
			# Umbrella: fall slows toward a gentle drift.
			s.vy = minf(s.vy + GLIDE_G * DT, maxf(GLIDE_MAX, s.vy - 900.0 * DT))
		else:
			var g := G_FALL
			if s.vy < 0.0:
				g = G_CUT if s.cut else G_UP
			s.vy = minf(s.vy + g * DT, MAX_FALL)
		descending = s.vy > 0.0
		var impact: float = s.vy
		var ny: float = oy + s.vy * DT

		# Marked cliff faces: sticky tires stick and climb; otherwise the face bonks you
		# back down (the way on is the tunnel underneath).
		for wi in _near(level, "wall_buckets", nx, int(s.lane)):
			var w: Dictionary = level.walls[wi]
			# The front reaching the face, or (jumping right at the tunnel mouth) the head
			# rising into the rock before the wheels are inside: both count as the face.
			if ox < float(w.x) and nx + WALL_FRONT > float(w.x) \
					and ny - HEIGHT < float(w.y_bot) and ny > float(w.y_top):
				if float(s.sticky_t) > 0.0:
					ev |= _end_tricks(s, true)
					s.climb = wi
					s.x = float(w.x)
					s.y = minf(ny, float(w.y_bot) + HEIGHT * 0.5)
					s.vy = 0.0
					s.jumping = false
					s.cut = false
					s.wheelie = false
					s.dash_t = 0.0
					s.coyote = 0.0
					return _finish_step(level, s, ev | EV_CLIMB, oy, false, held)
				nx = float(w.x) - WALL_FRONT - 1.0
				s.vx = 0.0
				s.vy = maxf(s.vy, BONK_VY)
				ny = oy + s.vy * DT
				s.jumping = false
				s.cut = false
				ev |= EV_WALL | EV_BONK
				break

		# Tunnel roof: rising into it is a bonk; flying into the rock face is a crash.
		var cy := ceil_at(level, nx, int(s.lane))
		if cy < INF and ny - HEIGHT < cy and ny > ceil_top_at(level, nx, int(s.lane)) + 2.0:
			if ceil_at(level, ox, int(s.lane)) < INF:
				ny = cy + HEIGHT
				s.vy = maxf(s.vy, BONK_VY)
				s.vx *= BONK_SLOW
				s.jumping = false
				s.cut = false
				ev |= EV_BONK
			else:
				s.x = nx
				s.y = ny
				s.alive = false
				s.death = "wall"
				return ev | EV_DEAD

		# Zipline: holding as your hands pass the cable grabs it.
		if held:
			for zi in _near(level, "zip_buckets", nx, int(s.lane)):
				var z: Dictionary = level.zips[zi]
				if nx < z.x0 + 2.0 or nx > z.x1 - 14.0:
					continue
				var g_old := oy - HEIGHT - 2.0 - cable_y(z, ox)
				var g_new := ny - HEIGHT - 2.0 - cable_y(z, nx)
				if g_old * g_new <= 0.0 or absf(g_new) <= ZIP_GRAB:
					s.zip = zi
					s.x = nx
					s.y = cable_y(z, nx) + ZIP_HANG
					s.vy = 0.0
					s.jumping = false
					s.cut = false
					s.dash_t = 0.0
					s.slope = (z.y1 - z.y0) / (z.x1 - z.x0)
					_end_tricks(s, false)
					return _finish_step(level, s, ev | EV_ZIP, oy, false, held)

		var landed := false
		if descending:
			# One-way decks: land only when crossing a deck from above.
			var best := -1
			var best_y := INF
			for ti in tracks_near(level, nx, int(s.lane)):
				var tr: Dictionary = level.tracks[ti]
				if nx < tr.x0 or nx > tr.x1 or track_gone(level, s, ti):
					continue
				var ty_new := deck_y(tr, nx, s.t)
				var ty_old := deck_y(tr, ox, t_old) if ox >= tr.x0 else ty_new
				if oy <= ty_old + 1.5 and ny >= ty_new and ty_new < best_y:
					best = ti
					best_y = ty_new
			if best >= 0:
				s.y = best_y
				s.vy = 0.0
				s.grounded = true
				s.track = best
				s.jumping = false
				s.cut = false
				s.air_used = false
				s.dash_t = 0.0
				s.slope = slope_at(level.tracks[best], nx)
				if rain:
					s.vx += base * RAIN_SLIDE * clampf(impact / MAX_FALL, 0.35, 1.0)
				landed = true
				ev |= EV_LAND
				ev |= _end_tricks(s, true)
				ev |= _touch(level, s, best)
				if s.ab == "wheelie" and held:
					s.wheelie = true
					ev |= EV_WHEELIE
		if not landed:
			s.y = ny
		s.x = nx
		if landed:
			ev |= _deck_features(level, s, ox)
	return _finish_step(level, s, ev, oy, descending, held)


## Springs and loop entries on the deck the rider is rolling along.
static func _deck_features(level: Dictionary, s: Dictionary, ox: float) -> int:
	var lane := int(s.lane)
	for wi in _near(level, "switch_buckets", s.x, lane):
		var w: Dictionary = level.switches[wi]
		var hw: float = w.get("w", SWITCH_W)
		if int(w.track) == int(s.track) and ox < w.x + hw and s.x >= w.x - hw:
			s.sw = wi
			s.sw_u = 0.0
			s.sw_x0 = s.x
			s.grounded = false
			s.coyote = 0.0
			s.wheelie = false
			return EV_SWITCH
	for si in _near(level, "spring_buckets", s.x, lane):
		var sp: Dictionary = level.springs[si]
		if int(sp.track) == int(s.track) and ox < sp.x + SPRING_W and s.x >= sp.x - SPRING_W:
			s.vy = -SPRING_V
			s.vx = maxf(s.vx, (float(level.speed) + s.boost) * SPRING_KICK)
			s.grounded = false
			s.track = -1
			s.jumping = false
			s.cut = false
			s.coyote = 0.0
			s.buffer = 0.0
			s.wheelie = false
			s.air_used = false
			s.spring = si
			s.y -= 1.0
			return EV_SPRING
	for li in _near(level, "loop_buckets", s.x, lane):
		var L: Dictionary = level.loops[li]
		if int(L.track) == int(s.track) and ox < L.x and s.x >= L.x:
			s.loop = li
			s.loop_a = (s.x - L.x) / float(L.r)
			s.grounded = false
			s.coyote = 0.0
			s.wheelie = false
			var p := loop_pos(L, s.loop_a)
			s.x = p.x
			s.y = p.y
			return EV_LOOP
	return 0


## Landing (or grabbing a cable) ends the air's tricks. Upright within FLIP_TOL banks
## any flip in progress; landing further round than that is a sketchy landing.
static func _end_tricks(s: Dictionary, landing: bool) -> int:
	var ev := 0
	if int(s.flip_dir) != 0:
		var a: float = s.flip_a
		var done := int(floor(a / TAU))
		var rest := a - done * TAU
		if rest <= FLIP_TOL or TAU - rest <= FLIP_TOL:
			done = int(round(a / TAU))
			if int(s.flip_dir) < 0:
				s.tb = int(s.tb) + done
			else:
				s.tf = int(s.tf) + done
		elif landing:
			s.vx = float(s.vx) * SKETCHY_KEEP
			s.tb = 0
			s.tf = 0
			ev |= EV_SKETCHY
	var n := int(s.tb) + int(s.tf)
	if n > 0 and ev == 0:
		# Coins: 2 per backflip, 3 per front flip, times the number of flips.
		s.trick_coins = (2 * int(s.tb) + 3 * int(s.tf)) * n
		s.trick_name = trick_name(int(s.tb), int(s.tf))
		ev |= EV_TRICK
	s.flip_dir = 0
	s.flip_a = 0.0
	s.flip_target = 0.0
	s.tb = 0
	s.tf = 0
	return ev


## Frames until the rider touches down if no more input comes in; 0 if the arc ends
## in a crash or a fall (no flips over an open pit: there's nothing to land on).
static func air_frames(level: Dictionary, s0: Dictionary, limit := 240) -> int:
	var s := copy_state(s0)
	for i in limit:
		step(level, s, false, false)
		if not s.alive:
			return 0
		if s.grounded or int(s.loop) >= 0 or int(s.zip) >= 0:
			return i + 1
	return 0


static func trick_name(tb: int, tf: int) -> String:
	var words := ["", "", "DOUBLE ", "TRIPLE ", "QUAD "]
	if tb > 0 and tf > 0:
		return "FLIP COMBO x%d" % (tb + tf)
	var n := tb + tf
	return (words[mini(n, 4)] if n <= 4 else "%dx " % n) + ("BACKFLIP" if tb > 0 else "FRONT FLIP")


## Riding a switch ramp: carried across from one lane to the next (~1 s), no
## steering; a press near the end is buffered into a jump on the new deck.
static func _switch_step(level: Dictionary, s: Dictionary, cruise: float) -> int:
	var w: Dictionary = level.switches[s.sw]
	var from: Dictionary = level.tracks[w.track]
	var to: Dictionary = level.tracks[w.to_track]
	s.vx += (cruise - s.vx) * minf(1.0, GRIP_DRY * DT)
	s.x += s.vx * DT
	s.sw_u = minf(1.0, (float(s.x) - float(s.sw_x0)) / float(w.len))
	var k := smoothstep(0.0, 1.0, float(s.sw_u))
	s.y = lerpf(deck_y(from, s.x, s.t), deck_y(to, s.x, s.t), k)
	s.lane_z = lerpf(float(w.lane), float(w.to_lane), k)
	if s.sw_u >= 1.0:
		s.sw = -1
		s.lane = int(w.to_lane)
		s.lane_z = float(w.to_lane)
		s.track = int(w.to_track)
		s.y = deck_y(to, s.x, s.t)
		s.slope = slope_at(to, s.x)
		s.grounded = true
		s.vy = 0.0
		s.coyote = COYOTE
		return EV_SWITCH_OUT
	return 0


## On a cliff face with sticky tires: drive straight up it, then roll over the lip
## onto the deck on top. A press on the way up is buffered for a jump at the top.
static func _climb_step(level: Dictionary, s: Dictionary, cruise: float) -> int:
	var w: Dictionary = level.walls[s.climb]
	s.vx = cruise * CLIMB_K
	s.y -= cruise * CLIMB_K * DT
	s.x = float(w.x)
	if float(s.y) <= float(w.y_top) + 1.0:
		var top: Dictionary = level.tracks[w.top]
		s.climb = -1
		s.x = float(w.x) + 3.0
		s.y = deck_y(top, s.x, s.t)
		s.slope = slope_at(top, s.x)
		s.track = int(w.top)
		s.grounded = true
		s.vy = 0.0
		s.vx = cruise
		s.coyote = COYOTE
		return _finish_step(level, s, EV_CLIMB_OUT, s.y, false, false)
	return _finish_step(level, s, 0, s.y, false, false)


## Power-up pickups: touch the icon to start (or refresh) its timer.
static func _powerups(level: Dictionary, s: Dictionary) -> int:
	if not level.has("power_buckets"):
		return 0
	var br := bike_rect(s, level).grow(POWER_R)
	for pi in _near(level, "power_buckets", s.x, int(s.lane)):
		if (s.got as Dictionary).has(pi):
			continue
		var p: Dictionary = level.powerups[pi]
		if not br.has_point(p.pos):
			continue
		s.got[pi] = true
		s.last_power = p.kind
		match String(p.kind):
			"sticky":
				s.sticky_t = STICKY_T
			"rocket":
				s.rocket_t = ROCKET_T
			"magnet":
				s.magnet_t = MAGNET_T
			"hat":
				s.hat = 1
		return EV_POWER
	return 0


## Inside a loop: the track carries the bike round; no steering, no hazards.
## A press near the exit is buffered into a jump as soon as the wheels are back down.
static func _loop_step(level: Dictionary, s: Dictionary, cruise: float) -> int:
	var L: Dictionary = level.loops[s.loop]
	var a: float = s.loop_a
	var v := cruise * (1.0 - LOOP_SLOW * (1.0 - cos(a)) * 0.5)
	s.vx = v
	a += v / float(L.r) * DT
	if a >= TAU:
		var tr: Dictionary = level.tracks[L.track]
		s.loop = -1
		s.loop_a = 0.0
		s.x = float(L.x) + float(L.shift) + (a - TAU) * float(L.r)
		s.y = deck_y(tr, s.x, s.t)
		s.slope = slope_at(tr, s.x)
		s.grounded = true
		s.track = L.track
		s.vy = 0.0
		s.coyote = COYOTE
		return EV_LOOP_OUT
	s.loop_a = a
	var p := loop_pos(L, a)
	s.x = p.x
	s.y = p.y
	return 0


## Hanging from a zipline: ride it while held; let go to drop, or fly off the end.
static func _zip_step(level: Dictionary, s: Dictionary, held: bool, cruise: float) -> int:
	var z: Dictionary = level.zips[s.zip]
	s.vx += (cruise * ZIP_SPEED - s.vx) * minf(1.0, 3.0 * DT)
	var nx: float = s.x + s.vx * DT
	var at_end := nx >= float(z.x1) - 2.0
	s.x = nx
	s.y = cable_y(z, nx) + ZIP_HANG
	if not held or at_end:
		s.zip = -1
		s.grounded = false
		s.track = -1
		s.jumping = false
		s.cut = false
		s.coyote = 0.0
		s.air_used = false
		s.vy = -70.0 if at_end else 20.0
		return EV_UNZIP
	s.vy = 0.0
	return 0


## Enemies, checkpoint armour refresh and falling out of the world.
static func _finish_step(level: Dictionary, s: Dictionary, ev: int, oy: float, descending: bool, held: bool) -> int:
	ev |= _powerups(level, s)
	if s.ab == "tough" and int(s.armor) < 1:
		for c in level.checkpoints:
			if s.x >= float(c.x) and s.x - s.vx * DT < float(c.x):
				s.armor = 1
				ev |= EV_ARMOR
	# Enemies: stomp from above if allowed; anything else is a crash (or a smash).
	var bike := bike_rect(s)
	for ei in enemies_near(level, s.x, int(s.lane)):
		var e: Dictionary = level.enemies[ei]
		if not e.alive or s.stomped.has(ei):
			continue
		var r := enemy_rect(level, e, s.t)
		if not bike.intersects(r):
			continue
		var tol := maxf(5.0, absf(s.vy) * DT + 2.0)
		if e.stompable and descending and oy <= r.position.y + tol:
			s.stomped[ei] = true
			s.last_stomp = ei
			s.vy = -(STOMP_V_HELD if held else STOMP_V)
			s.y = minf(s.y, r.position.y)
			s.grounded = false
			s.track = -1
			s.jumping = true
			s.cut = false
			s.coyote = 0.0
			s.air_used = false
			s.zip = -1
			ev |= EV_STOMP
		elif s.inv_t > 0.0 or int(s.armor) > 0 or int(s.hat) > 0:
			if s.inv_t <= 0.0:
				if int(s.armor) > 0:
					s.armor = int(s.armor) - 1
				else:
					s.hat = int(s.hat) - 1  # the hard hat takes the hit
					ev |= EV_HAT
				s.inv_t = SMASH_INV
			s.stomped[ei] = true
			s.last_smash = ei
			ev |= EV_SMASH
		else:
			s.alive = false
			s.death = "hit"
			return ev | EV_DEAD

	if s.y > level.kill_y:
		s.alive = false
		s.death = "fall"
		ev |= EV_DEAD
	return ev
