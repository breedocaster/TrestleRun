## 2.5D depth director. Layers in front of and behind the play plane scroll at their
## own parallax rates, and things happen in them:
##   far   x0.18  ridge causeway with a passing train (horn), balloon, hawk
##   mid   x0.35  bats at dusk, lightning + thunder in rain
##   lane  x0.6   valley trestle: rival riders race you, jump its gaps, sometimes flip
##   front x1.6   dark silhouettes rushing past, fireflies, tumbleweeds in wind
## Purely visual: nothing here touches the physics. The owner sets `cam` and
## `speed` every frame (game screen from the world camera, title from its scroll).
extends Node

const BikeView := preload("res://scripts/game/bike_view.gd")
const Catalog := preload("res://scripts/catalog.gd")

const P_FAR := 0.18
const P_MID := 0.35
const P_LANE := 0.6
const P_FRONT := 1.6
const LANE_G := 520.0
const LANE_CELL := 300.0

var cam := Vector2.ZERO
var speed := 128.0
var theme_index := 0
var time_mode := "dusk"
var weather := "clear"
var level_id := ""
var gust := 0.0
var with_front := true
var with_sound := true
var train_dir := 0.0  # dev: force a direction for captures
var t := 0.0

var lane: Node2D
var front: Node2D
var rivals: Array = []
var rng := RandomNumberGenerator.new()

var _th: Dictionary = {}
var _train: Dictionary = {}
var _next_train := 7.0
var _balloon: Dictionary = {}
var _hawk_c := Vector2.ZERO
var _bats: Dictionary = {}
var _next_bats := 9.0
var _bolt: Dictionary = {}
var _flash := 0.0
var _next_bolt := 4.0
var _thunder_at := -1.0
var _weeds: Array = []
var _next_weed := 1.0
var _flies: Array = []
var _cam_y0 = null
var _placed := false


func attach(host: Node, backdrop: Node2D) -> void:
	rng.seed = hash(level_id + time_mode + weather) ^ Time.get_ticks_usec()
	backdrop.hooks = self
	var ll := CanvasLayer.new()
	ll.layer = -9
	host.add_child(ll)
	lane = LaneLayer.new()
	lane.depth = self
	ll.add_child(lane)
	if with_front:
		var fl := CanvasLayer.new()
		fl.layer = 1
		host.add_child(fl)
		front = FrontLayer.new()
		front.depth = self
		fl.add_child(front)
	_spawn_rivals()
	if time_mode != "night" and weather != "rain" and rng.randf() < 0.7:
		_balloon = {"x": rng.randf_range(80, 360), "y": rng.randf_range(0.22, 0.4), "ph": rng.randf() * 6.0,
			"c": [Color("e85d4a"), Color("f2c14e"), Color("4fa3d9")][rng.randi() % 3]}
	_hawk_c = Vector2(rng.randf_range(100, 400), rng.randf_range(30, 60))
	if time_mode != "day" and weather != "rain":
		for i in 26:
			_flies.append({"x": rng.randf() * 900.0, "y": rng.randf_range(0.45, 0.95), "ph": rng.randf() * 6.0,
				"front": i < 14, "r": rng.randf_range(1.0, 2.2)})
	if level_id == "night_trestle":
		_next_train = 4.0


func _haze() -> Color:
	match time_mode:
		"day":
			return Color(0.8, 0.84, 0.96)
		"night":
			return Color(0.42, 0.44, 0.62)
	return Color(0.86, 0.66, 0.72)


func _process(delta: float) -> void:
	t += delta
	if _cam_y0 == null:
		_cam_y0 = cam.y
	_th = preload("res://scripts/game/backdrop.gd").theme(theme_index, time_mode, weather)
	_update_rivals(delta)
	_update_events(delta)
	if lane:
		lane.queue_redraw()
	if front:
		front.queue_redraw()


# --- lane: valley trestle with rival riders -------------------------------------

func lane_has_deck(lx: float) -> bool:
	var c := floori(lx / LANE_CELL)
	if _h(c * 1.91) < 0.3:
		return true
	var gs := c * LANE_CELL + 110.0 + _h(c * 3.7) * 90.0
	var gw := 26.0 + _h(c * 5.3) * 22.0
	return not (lx >= gs and lx <= gs + gw)


func lane_gap_ahead(lx: float, look: float) -> Vector2:
	## Returns (gap start, gap width) of the first gap within `look`, or (-1, 0).
	for c in [floori(lx / LANE_CELL), floori(lx / LANE_CELL) + 1]:
		if _h(c * 1.91) < 0.3:
			continue
		var gs: float = c * LANE_CELL + 110.0 + _h(c * 3.7) * 90.0
		var gw: float = 26.0 + _h(c * 5.3) * 22.0
		if gs > lx and gs - lx < look:
			return Vector2(gs, gw)
	return Vector2(-1, 0)


func lane_y(lx: float, vs: Vector2) -> float:
	var horizon := vs.y * 0.7
	var vy := clampf(-cam.y, -120.0, 120.0)
	return floorf(horizon + 34.0 + vy * 0.32 + 5.0 * sin(lx / 110.0) + 3.0 * sin(lx / 41.0 + 1.0))


func lane_sx(lx: float) -> float:
	return lx - cam.x * P_LANE


func _spawn_rivals() -> void:
	var mine := GameState.equipped("rider")
	var pool: Array = []
	for r in Catalog.riders():
		if r.id != mine:
			pool.append(r.id)
	pool.shuffle()
	var bikes := Catalog.bikes()
	var paints := Catalog.paints()
	for i in 2:
		var bv := BikeView.new()
		bv.rig = {"rider": pool[i % pool.size()], "bike": bikes[rng.randi() % bikes.size()].id,
			"paint": paints[rng.randi() % paints.size()].id}
		bv.scale = Vector2(0.55, 0.55)
		bv.modulate = _haze()
		lane.add_child(bv)
		rivals.append({"node": bv, "lx": cam.x * P_LANE + 140.0 + i * 170.0, "air": false, "h": 0.0, "vy": 0.0,
			"spin": 0.0, "spin_v": 0.0, "ph": rng.randf() * 6.0, "wheel": 0.0, "hop": rng.randf_range(2, 6), "jv": 0.0})


func _update_rivals(delta: float) -> void:
	if lane == null:
		return
	var vs := lane.get_viewport_rect().size
	if not _placed:  # first frame with a real camera: start them on screen
		_placed = true
		for i in rivals.size():
			rivals[i].lx = cam.x * P_LANE + vs.x * (0.62 + 0.22 * i)
	for r in rivals:
		# Pace with the player (on screen), drifting ahead and behind like a race.
		var target := vs.x * (0.5 + 0.33 * sin(t * 0.21 + r.ph))
		var sx := lane_sx(r.lx)
		var v: float = speed * P_LANE + clampf((target - sx) * 0.6, -40.0, 40.0)
		v = maxf(v, 20.0)
		if sx < -80.0 or sx > vs.x + 80.0:  # wandered off: bring back in from an edge
			r.lx = cam.x * P_LANE + (vs.x + 40.0 if sx < 0 else -40.0)
			r.air = false
			r.h = 0.0
		if r.air:
			v = maxf(v, r.jv)  # commit to the jump: no braking mid-air
		r.lx += v * delta
		r.wheel += v * delta / 2.5
		if not r.air:
			var gap := lane_gap_ahead(r.lx, v * 0.14 + 4.0)
			r.hop -= delta
			if gap.x > 0.0 or r.hop <= 0.0:
				var span := (gap.y + 22.0) if gap.x > 0.0 else 14.0
				# Throttle up for the gap so the arc stays low and quick (<= 0.5 s).
				r.jv = maxf(v, span / 0.5)
				var air_t: float = span / r.jv
				r.vy = -LANE_G * air_t * 0.5 - (10.0 if gap.x > 0.0 else 0.0)
				r.air = true
				r.hop = rng.randf_range(3.0, 7.0)
				if gap.x > 0.0 and rng.randf() < 0.3:  # show-off backflip over the gap
					r.spin_v = -TAU / maxf(air_t + 0.02, 0.2)
		else:
			r.vy += LANE_G * delta
			r.h += r.vy * delta
			r.spin += r.spin_v * delta
			if r.h >= 0.0 and r.vy > 0.0 and lane_has_deck(r.lx):
				r.h = 0.0
				r.air = false
				r.spin = 0.0
				r.spin_v = 0.0
			elif r.h > 120.0:  # fell through (shouldn't happen): reset onto the deck
				r.h = 0.0
				r.air = false
		var bv: Node2D = r.node
		bv.position = Vector2(floorf(lane_sx(r.lx)), lane_y(r.lx, vs) + floorf(r.h))
		var slope := (lane_y(r.lx + 4.0, vs) - lane_y(r.lx - 4.0, vs)) / 8.0
		bv.rotation = (atan(slope) if not r.air else clampf(r.vy * 0.002, -0.4, 0.5)) + r.spin
		bv.wheel_angle = r.wheel
		bv.anim_t = t
		bv.flutter = 0.4 + gust * 0.5
		bv.modulate = _haze()
		bv.queue_redraw()


# --- far / mid events ------------------------------------------------------------

func _update_events(delta: float) -> void:
	var vs := Vector2(480, 270)
	if lane:
		vs = lane.get_viewport_rect().size
	# Train on the far causeway.
	if _train.is_empty() and t >= _next_train:
		var dir := -1.0 if rng.randf() < 0.6 else 1.0
		if train_dir != 0.0:
			dir = train_dir
		var start_sx := vs.x + 30.0 if dir < 0 else -150.0
		_train = {"wx": start_sx + cam.x * P_FAR, "v": dir * rng.randf_range(38.0, 55.0), "cars": rng.randi_range(5, 9)}
		if with_sound:
			AudioDirector.play("train_horn", rng.randf_range(0.97, 1.03), -3.0)
	if not _train.is_empty():
		_train.wx += _train.v * delta
		var sx: float = _train.wx - cam.x * P_FAR
		if sx < -200.0 or sx > vs.x + 200.0:
			_train = {}
			_next_train = t + rng.randf_range(30.0, 55.0) * (0.6 if level_id == "night_trestle" else 1.0)
	# Bats at dusk.
	if time_mode == "dusk" and weather != "rain" and _bats.is_empty() and t >= _next_bats:
		_bats = {"wx": vs.x + 20.0 + cam.x * P_MID, "y": rng.randf_range(0.3, 0.5), "n": rng.randi_range(4, 7)}
	if not _bats.is_empty():
		_bats.wx -= 60.0 * delta
		if _bats.wx - cam.x * P_MID < -80.0:
			_bats = {}
			_next_bats = t + rng.randf_range(14.0, 26.0)
	# Lightning in rain (not at noon-bright day as often).
	if weather == "rain" and t >= _next_bolt:
		_bolt = {"x": rng.randf_range(40, vs.x - 40), "seed": rng.randi(), "life": 0.22}
		_flash = 1.0 if time_mode != "day" else 0.5
		_next_bolt = t + rng.randf_range(7.0, 15.0)
		_thunder_at = t + rng.randf_range(0.7, 2.2)
	if not _bolt.is_empty():
		_bolt.life -= delta
		if _bolt.life <= 0.0:
			_bolt = {}
	_flash = maxf(0.0, _flash - delta * 3.5)
	if _thunder_at > 0.0 and t >= _thunder_at:
		_thunder_at = -1.0
		if with_sound:
			AudioDirector.play("thunder", rng.randf_range(0.9, 1.1), -2.0)
	# Tumbleweeds in wind.
	if weather == "wind":
		_next_weed -= delta * (0.6 + gust)
		if _next_weed <= 0.0:
			_next_weed = rng.randf_range(1.2, 3.0)
			var fr := rng.randf() < 0.55
			_weeds.append({"front": fr, "x": vs.x + 30.0, "y": 0.0, "vy": 0.0, "r": rng.randf_range(7, 11) if fr else rng.randf_range(3, 4.5),
				"rot": 0.0, "v": rng.randf_range(1.0, 1.4)})
	for w in _weeds:
		var push: float = (240.0 if w.front else 70.0) * w.v * (0.6 + gust)
		w.x -= (push + speed * (P_FRONT if w.front else P_LANE)) * delta
		w.vy += (900.0 if w.front else 400.0) * delta
		w.y += w.vy * delta
		if w.y > 0.0:
			w.y = 0.0
			w.vy = -rng.randf_range(80.0, 200.0) * (1.0 if w.front else 0.5)
		w.rot -= push / w.r * delta
	_weeds = _weeds.filter(func(w): return w.x > -40.0)


func draw_far(ci: CanvasItem, vs: Vector2, c: Vector2, th: Dictionary, horizon: float, vy: float) -> void:
	var far_dark: Color = (th.far as Color).darkened(0.3)
	# Balloon and hawk float above the far ridge.
	if not _balloon.is_empty():
		var bx := fposmod(float(_balloon.x) - c.x * 0.1 + t * 3.0, vs.x + 80.0) - 40.0
		var by := floorf(horizon * float(_balloon.y) + sin(t * 0.5 + float(_balloon.ph)) * 3.0)
		var bc: Color = (_balloon.c as Color).lerp(th.sky[2], 0.35)
		ci.draw_circle(Vector2(bx, by), 6.0, bc)
		ci.draw_rect(Rect2(bx - 2, by - 6, 1, 11), bc.lightened(0.25))
		ci.draw_rect(Rect2(bx + 2, by - 6, 1, 11), bc.darkened(0.2))
		ci.draw_colored_polygon(PackedVector2Array([Vector2(bx - 5, by + 3), Vector2(bx + 5, by + 3), Vector2(bx + 2, by + 8), Vector2(bx - 2, by + 8)]), bc)
		ci.draw_line(Vector2(bx - 2, by + 8), Vector2(bx - 1, by + 11), far_dark, -1.0)
		ci.draw_line(Vector2(bx + 2, by + 8), Vector2(bx + 1, by + 11), far_dark, -1.0)
		ci.draw_rect(Rect2(bx - 1, by + 11, 3, 2), (th.beam as Color).lerp(th.far, 0.4))
	if time_mode == "day" and weather != "rain":
		var hc := Vector2(fposmod(_hawk_c.x - c.x * 0.12, vs.x + 60.0) - 30.0, _hawk_c.y)
		var hp := hc + Vector2(cos(t * 0.7), sin(t * 0.7) * 0.4) * 26.0
		var flap := 1.0 if int(t * 3.0) % 5 == 0 else 0.0
		ci.draw_line(hp + Vector2(-4, -1 - flap), hp, far_dark.darkened(0.3), -1.0)
		ci.draw_line(hp, hp + Vector2(4, -1 - flap), far_dark.darkened(0.3), -1.0)
	# A high, distant trestle bridge across the far valley; trains cross it against the sky.
	var ry := floorf(horizon * 0.66 + vy * 0.06)
	var off := c.x * P_FAR
	var leg := Color(far_dark, 0.35)
	ci.draw_line(Vector2(0, ry), Vector2(vs.x, ry), Color(far_dark, 0.85), -1.0)
	var px := -fposmod(off, 36.0)
	while px < vs.x:
		ci.draw_line(Vector2(floorf(px), ry + 1), Vector2(floorf(px), horizon + 6), leg, -1.0)
		px += 36.0
	if _train.is_empty():
		return
	var dir: float = signf(_train.v)
	var sx: float = floorf(_train.wx - off)
	var body := far_dark.darkened(0.35)
	var lit := time_mode != "day"
	var loco := Rect2(sx if dir > 0 else sx - 14, ry - 6, 14, 6)
	ci.draw_rect(loco, body)
	ci.draw_rect(Rect2(loco.position.x + (10 if dir > 0 else 1), ry - 9, 3, 3), body)
	var nose := loco.end.x if dir > 0 else loco.position.x
	if lit:
		ci.draw_rect(Rect2(nose - (1 if dir > 0 else 0), ry - 4, 1, 1), Color("fff1a8"))
		if time_mode == "night":
			ci.draw_colored_polygon(PackedVector2Array([Vector2(nose, ry - 4), Vector2(nose + dir * 40, ry - 9),
				Vector2(nose + dir * 40, ry + 1)]), Color(1, 0.95, 0.7, 0.12))
	else:
		for k in 4:  # smoke puffs drifting back
			var age := fmod(t * 1.3 + k * 0.25, 1.0)
			var pp := Vector2(loco.position.x + (11 if dir > 0 else 2) - dir * age * 22, ry - 10 - age * 10)
			ci.draw_circle(pp, 1.0 + age * 2.5, Color((th.sky[3] as Color).lightened(0.3), 0.55 * (1 - age)))
	var cx := loco.position.x - 12 if dir > 0 else loco.end.x + 1
	for i in int(_train.cars):
		var car := Rect2(cx, ry - 5, 11, 5)
		ci.draw_rect(car, body)
		if lit:
			for wi in 3:
				ci.draw_rect(Rect2(car.position.x + 2 + wi * 3, ry - 4, 1, 1), Color("ffcf6a", 0.9))
		cx += -12 if dir > 0 else 12


func draw_mid(ci: CanvasItem, vs: Vector2, c: Vector2, th: Dictionary, horizon: float, vy: float) -> void:
	if not _bats.is_empty():
		var bx: float = _bats.wx - c.x * P_MID
		for i in int(_bats.n):
			var p := Vector2(bx + i * 9 + sin(t * 9 + i) * 3, horizon * float(_bats.y) + sin(t * 4 + i * 1.7) * 5 + i * 2)
			var f := 1.0 if int(t * 12 + i) % 2 == 0 else -1.0
			var col := (th.mid as Color).darkened(0.6)
			ci.draw_line(p + Vector2(-3, -f), p, col, -1.0)
			ci.draw_line(p, p + Vector2(3, -f), col, -1.0)
	if not _bolt.is_empty() and int(_bolt.life * 40.0) % 3 != 0:
		var r := RandomNumberGenerator.new()
		r.seed = int(_bolt.seed)
		var p := Vector2(_bolt.x, 0)
		var end_y := horizon + 10.0 + vy * 0.18
		var col := Color(0.92, 0.95, 1.0, 0.95)
		while p.y < end_y:
			var q := p + Vector2(r.randf_range(-10, 10), r.randf_range(10, 22))
			ci.draw_line(p, q, Color(col, 0.3), 3.0)
			ci.draw_line(p, q, col, -1.0)
			if r.randf() < 0.18:
				ci.draw_line(q, q + Vector2(r.randf_range(-14, 14), r.randf_range(8, 16)), Color(col, 0.6), -1.0)
			p = q
	if _flash > 0.0:
		ci.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.85, 0.9, 1.0, 0.28 * _flash))


static func _h(n: float) -> float:
	var s := sin(n * 12.9898) * 43758.5453
	return s - floorf(s)


# --- layers ---------------------------------------------------------------------

## Valley trestle (behind the play deck, in front of the near hills band).
class LaneLayer extends Node2D:
	const P := 0.6
	var depth

	func _draw() -> void:
		var d = depth
		var th: Dictionary = d._th
		if th.is_empty():
			return
		var vs := get_viewport_rect().size
		var hz: Color = d._haze()
		var deck: Color = (th.deck as Color).lerp(th.mid, 0.3) * hz
		var hi: Color = (th.deck_hi as Color).lerp(th.mid, 0.25) * hz
		var post: Color = (th.beam as Color).lerp(th.mid, 0.4) * hz
		deck.a = 1.0
		hi.a = 1.0
		post.a = 1.0
		var lx0: float = d.cam.x * P
		var x := 0.0
		while x < vs.x:
			var lx := lx0 + x
			if d.lane_has_deck(lx):
				var y: float = d.lane_y(lx, vs)
				draw_rect(Rect2(x, y, 2, 2), deck)
				draw_rect(Rect2(x, y, 2, 1), hi)
				if fposmod(lx, 20.0) < 2.0:
					draw_rect(Rect2(x, y + 2, 1, vs.y - y), post)
			x += 2.0
		# Fireflies and tumbleweeds that live at this depth.
		for f in d._flies:
			if not f.front:
				var p := Vector2(fposmod(float(f.x) - d.cam.x * P * 0.9 + sin(d.t * 0.7 + f.ph) * 8.0, vs.x),
					vs.y * float(f.y) * 0.85 + sin(d.t * 1.1 + f.ph) * 4.0)
				var a := 0.4 + 0.6 * maxf(0.0, sin(d.t * 2.3 + f.ph))
				draw_circle(p, 1.6, Color(1.0, 0.9, 0.45, 0.18 * a))
				draw_rect(Rect2(p.floor(), Vector2.ONE), Color(1.0, 0.95, 0.6, a))
		for w in d._weeds:
			if not w.front:
				var base: float = d.lane_y(lx0 + float(w.x), vs)
				d._draw_weed(self, Vector2(w.x, base - w.r + w.y), w.r, w.rot, ((th.deck as Color).lerp(th.mid, 0.5) * hz))


## Foreground: dark silhouettes and particles rushing past faster than the deck.
class FrontLayer extends Node2D:
	const P := 1.6
	var depth

	func _draw() -> void:
		var d = depth
		var th: Dictionary = d._th
		if th.is_empty():
			return
		var vs := get_viewport_rect().size
		var fy := clampf(-(d.cam.y - float(d._cam_y0)) * 0.45, -30.0, 30.0)
		var dark: Color = (th.near as Color).darkened(0.62)
		dark.a = 0.94
		var off: float = d.cam.x * P
		var cell := 170.0
		var c0 := int(floor(off / cell)) - 1
		var c1 := int(ceil((off + vs.x) / cell)) + 1
		for c in range(c0, c1):
			var hv: float = d._h(c * 2.37)
			if hv < 0.45:
				continue
			var x := floorf(c * cell + d._h(c * 4.1) * 90.0 - off)
			var s: float = 0.7 + d._h(c * 6.7) * 0.45
			d._draw_front_prop(self, Vector2(x, vs.y + 8 + fy), s, dark, th.props, c)
		# A rare tall post zips through for depth (thin and see-through).
		var pcell := 1100.0
		for c in range(int(floor(off / pcell)) - 1, int(ceil((off + vs.x) / pcell)) + 1):
			var x := floorf(c * pcell + 400.0 + d._h(c * 9.1) * 300.0 - off)
			if x > -10 and x < vs.x + 10:
				draw_rect(Rect2(x, 0, 5, vs.y), Color(dark, 0.5))
				draw_rect(Rect2(x - 6, 26 + fy * 0.5, 17, 3), Color(dark, 0.5))
		# Grass tufts along the bottom edge.
		var gx := -fposmod(off, 7.0)
		while gx < vs.x:
			var gh: float = 3.0 + 3.0 * d._h(floorf((gx + off) / 7.0) * 1.3)
			var sway: float = sin(d.t * 2.0 + gx * 0.05) * (1.0 + d.gust * 2.0)
			draw_line(Vector2(gx, vs.y + fy * 0.3), Vector2(gx + sway, vs.y - gh + fy * 0.3), dark, 2.0)
			gx += 7.0
		for f in d._flies:
			if f.front:
				var p := Vector2(fposmod(float(f.x) - off * 0.8 + sin(d.t * 0.6 + f.ph) * 14.0, vs.x + 40.0) - 20.0,
					vs.y * float(f.y) + sin(d.t * 0.9 + f.ph) * 8.0)
				var a := 0.35 + 0.65 * maxf(0.0, sin(d.t * 1.9 + f.ph))
				draw_circle(p, 3.0 * f.r, Color(1.0, 0.88, 0.4, 0.12 * a))
				draw_circle(p, f.r, Color(1.0, 0.95, 0.6, 0.85 * a))
		if d.time_mode == "day" and d.weather == "clear":
			for i in 14:
				var p := Vector2(fposmod(i * 97.0 - off * 0.7 + sin(d.t * 0.4 + i) * 20.0, vs.x),
					fposmod(i * 53.0 + d.t * (6.0 + i % 3), vs.y))
				draw_rect(Rect2(p.floor(), Vector2.ONE), Color(1, 0.97, 0.85, 0.35))
		for w in d._weeds:
			if w.front:
				d._draw_weed(self, Vector2(w.x, vs.y - 4 - w.r + w.y + fy), w.r, w.rot, (th.deck as Color).darkened(0.35))


func _draw_front_prop(ci: CanvasItem, base: Vector2, s: float, col: Color, kind: String, c: int) -> void:
	var x := base.x
	var y := base.y
	match kind:
		"cactus":
			if _h(c * 3.3) < 0.5:
				var h := floorf(70.0 * s)
				ci.draw_rect(Rect2(x, y - h, 10, h), col)
				ci.draw_rect(Rect2(x - 12, y - h * 0.62, 7, 18 * s), col)
				ci.draw_rect(Rect2(x - 12, y - h * 0.62 + 14 * s, 16, 6), col)
				ci.draw_rect(Rect2(x + 15, y - h * 0.78, 7, 16 * s), col)
				ci.draw_rect(Rect2(x + 6, y - h * 0.78 + 12 * s, 16, 6), col)
			else:
				_bush(ci, Vector2(x, y), 22.0 * s, col)
		"rocks":
			var w := floorf(70.0 * s)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(x, y), Vector2(x + 6, y - 30 * s), Vector2(x + 22, y - 44 * s),
				Vector2(x + w * 0.7, y - 38 * s), Vector2(x + w, y - 12 * s), Vector2(x + w, y)]), col)
		"junk":
			ci.draw_rect(Rect2(x, y - 26 * s, 50 * s, 26 * s), col)
			ci.draw_rect(Rect2(x + 8, y - 40 * s, 24 * s, 14 * s), col)
			ci.draw_circle(Vector2(x + 52 * s, y - 10 * s), 12 * s, col)
			ci.draw_rect(Rect2(x + 70 * s, y - 60 * s, 4, 60 * s), col)
		"poles":
			if _h(c * 3.3) < 0.4:
				var see := Color(col, 0.55)
				ci.draw_rect(Rect2(x, y - 120, 6, 120), see)
				ci.draw_rect(Rect2(x - 12, y - 114, 30, 4), see)
			else:
				_bush(ci, Vector2(x, y), 20.0 * s, col)
		_:
			_bush(ci, Vector2(x, y), 20.0 * s, col)


func _bush(ci: CanvasItem, p: Vector2, r: float, col: Color) -> void:
	ci.draw_circle(p + Vector2(0, -r * 0.4), r * 0.75, col)
	ci.draw_circle(p + Vector2(r * 0.8, -r * 0.3), r * 0.6, col)
	ci.draw_circle(p + Vector2(-r * 0.7, -r * 0.2), r * 0.55, col)


func _draw_weed(ci: CanvasItem, p: Vector2, r: float, rot: float, col: Color) -> void:
	ci.draw_arc(p, r, 0.0, TAU, 14, col, -1.0)
	for k in 5:
		var a := rot + k * TAU / 5.0
		ci.draw_line(p + Vector2(cos(a), sin(a)) * r * 0.2, p + Vector2(cos(a + 1.2), sin(a + 1.2)) * r, col, -1.0)
	ci.draw_arc(p, r * 0.55, rot, rot + PI * 1.4, 8, col, -1.0)
