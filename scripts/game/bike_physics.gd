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
const BONK_SLOW := 0.7     # ...and keep this share of speed until the tyre grips again
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

# Rider hitbox, relative to the contact point under the bike.
const HALF_W := 9.0
const HEIGHT := 16.0

const BUCKET := 256.0

enum {
	EV_JUMP = 1, EV_LAND = 2, EV_STOMP = 4, EV_DEAD = 8, EV_LEAVE = 16, EV_SPRING = 32,
	EV_BONK = 64, EV_LOOP = 128, EV_LOOP_OUT = 256, EV_ZIP = 512, EV_UNZIP = 1024,
	EV_AIR = 2048, EV_SMASH = 4096, EV_WHEELIE = 8192, EV_ARMOR = 16384,
}
enum { CRAWLER, SPIKER, DRONE }

static var _EMPTY := PackedInt32Array()


## ab: the bike's specialty, {"id": "wheelie"|"hop"|"glide"|"dash"|"tough", "k": strength}.
static func new_state(level: Dictionary, x: float, track: int, t: float = 0.0, ab: Dictionary = {}) -> Dictionary:
	var tr: Dictionary = level.tracks[track]
	var ab_id := String(ab.get("id", ""))
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
	}


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


static func _near(level: Dictionary, key: String, x: float) -> PackedInt32Array:
	var b: Dictionary = level.get(key, {})
	return b.get(int(floor(x / BUCKET)), _EMPTY)


static func tracks_near(level: Dictionary, x: float) -> PackedInt32Array:
	return level.track_buckets.get(int(floor(x / BUCKET)), _EMPTY)


static func enemies_near(level: Dictionary, x: float) -> PackedInt32Array:
	return level.enemy_buckets.get(int(floor(x / BUCKET)), _EMPTY)


static func pickups_near(level: Dictionary, x: float) -> PackedInt32Array:
	return level.pickup_buckets.get(int(floor(x / BUCKET)), _EMPTY)


## Underside of a tunnel roof above x, or INF.
static func ceil_at(level: Dictionary, x: float) -> float:
	for ci in _near(level, "ceil_buckets", x):
		var c: Dictionary = level.ceils[ci]
		if x >= c.x0 and x <= c.x1:
			return height_at(c, x)
	return INF


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


static func find_continuation(level: Dictionary, x: float, y: float, cur: int, t: float) -> int:
	var best := -1
	var best_d := CONT_TOL
	for ti in tracks_near(level, x):
		if ti == cur:
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
	for ti in tracks_near(level, s.x):
		var tr: Dictionary = level.tracks[ti]
		if s.x < tr.x0 or s.x > tr.x1:
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
	var cruise: float = base + s.boost

	if s.loop >= 0:
		return _loop_step(level, s, cruise)

	var ox: float = s.x
	var oy: float = s.y
	if s.zip >= 0:
		ev |= _zip_step(level, s, held, cruise)
		return _finish_step(level, s, ev, oy, false, held)

	if s.buffer > 0.0 and s.coyote > 0.0:
		var boost := minf(0.0, s.slope * s.vx) * RAMP_BOOST if s.grounded else 0.0
		s.vy = -JUMP_V * (RAIN_TAKEOFF if rain else 1.0) + boost
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
		if nx <= tr.x1:
			s.y = deck_y(tr, nx, s.t)
			s.slope = slope_at(tr, nx)
		else:
			var c := find_continuation(level, nx, oy, s.track, s.t)
			if c >= 0:
				s.track = c
				s.y = deck_y(level.tracks[c], nx, s.t)
				s.slope = slope_at(level.tracks[c], nx)
			else:
				# Ran off the end: carry the slope's vertical speed into the air.
				s.grounded = false
				s.track = -1
				s.jumping = false
				s.cut = false
				s.wheelie = false
				s.air_used = false
				s.vy = s.slope * s.vx
				s.y = oy + s.vy * DT
				ev |= EV_LEAVE
		s.x = nx
		if s.grounded:
			ev |= _deck_features(level, s, ox)
	else:
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

		# Tunnel roof: rising into it is a bonk; flying into the rock face is a crash.
		var cy := ceil_at(level, nx)
		if cy < INF and ny - HEIGHT < cy:
			if ceil_at(level, ox) < INF:
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
			for zi in _near(level, "zip_buckets", nx):
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
					return _finish_step(level, s, ev | EV_ZIP, oy, false, held)

		var landed := false
		if descending:
			# One-way decks: land only when crossing a deck from above.
			var best := -1
			var best_y := INF
			for ti in tracks_near(level, nx):
				var tr: Dictionary = level.tracks[ti]
				if nx < tr.x0 or nx > tr.x1:
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
	for si in _near(level, "spring_buckets", s.x):
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
	for li in _near(level, "loop_buckets", s.x):
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
	if s.ab == "tough" and int(s.armor) < 1:
		for c in level.checkpoints:
			if s.x >= float(c.x) and s.x - s.vx * DT < float(c.x):
				s.armor = 1
				ev |= EV_ARMOR
	# Enemies: stomp from above if allowed; anything else is a crash (or a smash).
	var bike := bike_rect(s)
	for ei in enemies_near(level, s.x):
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
		elif s.inv_t > 0.0 or int(s.armor) > 0:
			if s.inv_t <= 0.0:
				s.armor = int(s.armor) - 1
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
