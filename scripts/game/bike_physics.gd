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

# Rider hitbox, relative to the contact point under the bike.
const HALF_W := 9.0
const HEIGHT := 16.0

const BUCKET := 256.0

enum { EV_JUMP = 1, EV_LAND = 2, EV_STOMP = 4, EV_DEAD = 8, EV_LEAVE = 16 }
enum { CRAWLER, SPIKER, DRONE }

static var _EMPTY := PackedInt32Array()


static func new_state(level: Dictionary, x: float, track: int, t: float = 0.0) -> Dictionary:
	var tr: Dictionary = level.tracks[track]
	return {
		"x": x, "y": height_at(tr, x), "vx": float(level.speed), "vy": 0.0,
		"grounded": true, "track": track, "slope": slope_at(tr, x),
		"coyote": COYOTE, "buffer": 0.0, "jumping": false, "cut": false,
		"alive": true, "death": "", "t": t,
		"stomped": {}, "last_stomp": -1,
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


static func tracks_near(level: Dictionary, x: float) -> PackedInt32Array:
	return level.track_buckets.get(int(floor(x / BUCKET)), _EMPTY)


static func enemies_near(level: Dictionary, x: float) -> PackedInt32Array:
	return level.enemy_buckets.get(int(floor(x / BUCKET)), _EMPTY)


static func pickups_near(level: Dictionary, x: float) -> PackedInt32Array:
	return level.pickup_buckets.get(int(floor(x / BUCKET)), _EMPTY)


## Enemy anchor at level time t: ground contact for walkers/spikers, centre for drones.
static func enemy_pos(level: Dictionary, e: Dictionary, t: float) -> Vector2:
	match int(e.type):
		CRAWLER:
			var span: float = e.x1 - e.x0
			var px: float = e.x0
			if span > 0.0:
				px = e.x1 - pingpong(t * e.speed + e.phase, span)
			return Vector2(px, height_at(level.tracks[e.track], px))
		DRONE:
			return Vector2(e.x0 + sin(t * 1.3 + e.phase) * e.drift, e.y0 + sin(t * 3.0 + e.phase) * 3.0)
	return Vector2(e.x0, e.y0)


static func enemy_rect(level: Dictionary, e: Dictionary, t: float) -> Rect2:
	var p := enemy_pos(level, e, t)
	match int(e.type):
		CRAWLER:
			return Rect2(p.x - 7.0, p.y - 9.0, 14.0, 9.0)
		SPIKER:
			return Rect2(p.x - 6.0, p.y - 12.0, 12.0, 12.0)
	return Rect2(p.x - 7.0, p.y - 4.0, 14.0, 8.0)


static func bike_rect(s: Dictionary) -> Rect2:
	return Rect2(s.x - HALF_W, s.y - HEIGHT, HALF_W * 2.0, HEIGHT - 1.0)


static func find_continuation(level: Dictionary, x: float, y: float, cur: int) -> int:
	var best := -1
	var best_d := CONT_TOL
	for ti in tracks_near(level, x):
		if ti == cur:
			continue
		var tr: Dictionary = level.tracks[ti]
		if x < tr.x0 or x > tr.x1:
			continue
		var d := absf(height_at(tr, x) - y)
		if d <= best_d:
			best = ti
			best_d = d
	return best


## Advance one fixed step. Returns a bitmask of EV_* flags.
static func step(level: Dictionary, s: Dictionary, pressed: bool, held: bool) -> int:
	var ev := 0
	var base: float = level.speed
	var rain: bool = level.get("rain", false)
	s.t += DT

	if pressed:
		s.buffer = BUFFER
	elif s.buffer > 0.0:
		s.buffer = maxf(0.0, s.buffer - DT)
	if s.grounded:
		s.coyote = COYOTE
	elif s.coyote > 0.0:
		s.coyote = maxf(0.0, s.coyote - DT)

	if s.buffer > 0.0 and s.coyote > 0.0:
		var boost := minf(0.0, s.slope * s.vx) * RAMP_BOOST if s.grounded else 0.0
		s.vy = -JUMP_V * (RAIN_TAKEOFF if rain else 1.0) + boost
		s.grounded = false
		s.track = -1
		s.coyote = 0.0
		s.buffer = 0.0
		s.jumping = true
		s.cut = false
		ev |= EV_JUMP
	if s.jumping and not held and s.vy < 0.0:
		s.cut = true

	if s.grounded:
		var grip := GRIP_WET if rain else GRIP_DRY
		s.vx += (base - s.vx) * minf(1.0, grip * DT)
	else:
		s.vx += (base - wind_at(level, s.t) - s.vx) * minf(1.0, WIND_DRAG * DT)

	var ox: float = s.x
	var oy: float = s.y
	var nx: float = ox + s.vx * DT
	var descending := false

	if s.grounded:
		var tr: Dictionary = level.tracks[s.track]
		if nx <= tr.x1:
			s.y = height_at(tr, nx)
			s.slope = slope_at(tr, nx)
		else:
			var c := find_continuation(level, nx, oy, s.track)
			if c >= 0:
				s.track = c
				s.y = height_at(level.tracks[c], nx)
				s.slope = slope_at(level.tracks[c], nx)
			else:
				# Ran off the end: carry the slope's vertical speed into the air.
				s.grounded = false
				s.track = -1
				s.jumping = false
				s.cut = false
				s.vy = s.slope * s.vx
				s.y = oy + s.vy * DT
				ev |= EV_LEAVE
		s.x = nx
	else:
		var g := G_FALL
		if s.vy < 0.0:
			g = G_CUT if s.cut else G_UP
		s.vy = minf(s.vy + g * DT, MAX_FALL)
		descending = s.vy > 0.0
		var impact: float = s.vy
		var ny: float = oy + s.vy * DT
		var landed := false
		if descending:
			# One-way decks: land only when crossing a deck from above.
			var best := -1
			var best_y := INF
			for ti in tracks_near(level, nx):
				var tr: Dictionary = level.tracks[ti]
				if nx < tr.x0 or nx > tr.x1:
					continue
				var ty_new := height_at(tr, nx)
				var ty_old := height_at(tr, ox) if ox >= tr.x0 else ty_new
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
				s.slope = slope_at(level.tracks[best], nx)
				if rain:
					s.vx += base * RAIN_SLIDE * clampf(impact / MAX_FALL, 0.35, 1.0)
				landed = true
				ev |= EV_LAND
		if not landed:
			s.y = ny
		s.x = nx

	# Enemies: stomp from above if allowed, anything else is a crash.
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
			ev |= EV_STOMP
		else:
			s.alive = false
			s.death = "hit"
			return ev | EV_DEAD

	if s.y > level.kill_y:
		s.alive = false
		s.death = "fall"
		ev |= EV_DEAD
	return ev
