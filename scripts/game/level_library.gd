## Builds level data from chunk layouts. A layout is a list of [chunk_name, args...];
## each chunk appends track, hazards and pickups at the builder's cursor.
extends RefCounted

const Phys := preload("res://scripts/game/bike_physics.gd")
const Catalog := preload("res://scripts/catalog.gd")
const Layouts := preload("res://scripts/game/level_layouts.gd")

enum { P_COIN, P_BAG, P_GEAR }

var tracks: Array = []
var enemies: Array = []
var pickups: Array = []
var checkpoints: Array = []
var springs: Array = []
var ceils: Array = []
var loops: Array = []
var zips: Array = []
var finish_x := 0.0
var marks: Array = []
var x := 0.0
var y := 0.0
var _cur := -1
var _gears := 0


static func build(level_id: String) -> Dictionary:
	return build_layout(Layouts.LAYOUTS[level_id], Catalog.level(level_id))


static func build_layout(layout: Array, meta: Dictionary) -> Dictionary:
	var b = load("res://scripts/game/level_library.gd").new()
	for chunk in layout:
		b.marks.append([String(chunk[0]), snappedf(b.x, 1.0)])
		b.callv("c_" + String(chunk[0]), chunk.slice(1))
	var lv: Dictionary = b._finalize(meta)
	lv.marks = b.marks
	return lv


# --- primitives ------------------------------------------------------------

func run(length: float) -> int:
	if _cur == -1:
		tracks.append({"pts": PackedVector2Array([Vector2(x, y)])})
		_cur = tracks.size() - 1
	x += length
	tracks[_cur].pts.append(Vector2(x, y))
	return _cur


func slope(length: float, dy: float) -> int:
	if _cur == -1:
		run(1.0)
	x += length
	y += dy
	tracks[_cur].pts.append(Vector2(x, y))
	return _cur


func gap(length: float, dy := 0.0) -> void:
	_cur = -1
	x += length
	y += dy


## Free-standing deck (branches). segs = [[length, dy], ...].
func side(x0: float, y0: float, segs: Array) -> int:
	var pts := PackedVector2Array([Vector2(x0, y0)])
	var cx := x0
	var cy := y0
	for sg in segs:
		cx += float(sg[0])
		cy += float(sg[1])
		pts.append(Vector2(cx, cy))
	tracks.append({"pts": pts, "side": true})
	return tracks.size() - 1


func ground(t: int, px: float) -> float:
	return Phys.height_at(tracks[t], px)


func coin(px: float, py: float) -> void:
	pickups.append({"type": P_COIN, "pos": Vector2(px, py), "value": 1})


func bag(px: float, py: float) -> void:
	pickups.append({"type": P_BAG, "pos": Vector2(px, py), "value": 10})


func gear(px: float, py: float) -> void:
	pickups.append({"type": P_GEAR, "pos": Vector2(px, py), "value": 0, "gear": _gears})
	_gears += 1


func coins_on(t: int, xa: float, n: int, spacing: float, h := 10.0) -> void:
	for i in n:
		var px := xa + i * spacing
		coin(px, ground(t, px) - h)


func coin_arc(xa: float, ya: float, xb: float, yb: float, peak: float, n: int) -> void:
	for i in n:
		var u := float(i) / float(n - 1)
		coin(lerpf(xa, xb, u), lerpf(ya, yb, u) - 10.0 - peak * 4.0 * u * (1.0 - u))


func crawler(t: int, xa: float, xb: float, speed := 16.0) -> void:
	enemies.append({"type": Phys.CRAWLER, "track": t, "x0": xa, "x1": xb, "speed": speed,
		"phase": float(enemies.size()) * 7.3, "stompable": true})


func spiker(t: int, px: float) -> void:
	var e := {"type": Phys.SPIKER, "x0": px, "y0": ground(t, px), "stompable": false}
	if tracks[t].has("lift"):
		e.track = t
	enemies.append(e)


func drone(px: float, py: float, drift := 0.0) -> void:
	enemies.append({"type": Phys.DRONE, "x0": px, "y0": py, "drift": drift,
		"phase": float(enemies.size()) * 1.7, "stompable": false})


func spring(t: int, px: float) -> void:
	springs.append({"x": px, "track": t, "y": ground(t, px)})


## Flat tunnel roof `h` px above the deck from xa to xb.
func roof(xa: float, xb: float, deck_y: float, h: float) -> void:
	ceils.append({"pts": PackedVector2Array([Vector2(xa, deck_y - h), Vector2(xb, deck_y - h)]),
		"x0": xa, "x1": xb, "h": h, "deck": deck_y})


# --- chunks: basics ----------------------------------------------------------

func c_start(length := 260.0) -> void:
	# Deck extends off-screen to the left so the opening frame isn't an empty void.
	x = -320.0
	run(320.0)
	var x0 := x
	var t := run(length)
	coins_on(t, x0 + 130.0, 5, 16.0)


func c_flat(length := 160.0, coins := 1) -> void:
	var x0 := x
	var t := run(length)
	if coins:
		coins_on(t, x0 + length * 0.3, 4, 14.0)


func c_gap(w := 48.0, dy := 0.0) -> void:
	run(56.0)
	var xa := x
	var ya := y
	gap(w, dy)
	run(70.0)
	coin_arc(xa - 10.0, ya, xa + w + 10.0, ya + dy, 34.0, 5)


## A row of short gaps: hop, hop, hop.
func c_hops(n := 3, w := 30.0, deck := 64.0) -> void:
	run(50.0)
	for i in n:
		var xa := x
		gap(w)
		coin(xa + w * 0.5, y - 26.0)
		run(deck)
	run(30.0)


## Coins hanging high over the deck: hold the jump to reach them.
func c_high_coins(length := 200.0, h := 50.0) -> void:
	var x0 := x
	run(length)
	coin_arc(x0 + 60.0, y, x0 + 140.0, y, h - 12.0, 5)


func c_drop(dy := 24.0) -> void:
	run(30.0)
	gap(6.0, dy)
	var x0 := x
	var t := run(70.0)
	coins_on(t, x0 + 20.0, 3, 14.0)


func c_climb(dy := 22.0) -> void:
	run(60.0)
	var xa := x
	var ya := y
	gap(28.0, -dy)
	run(90.0)
	coin_arc(xa - 6.0, ya, xa + 40.0, ya - dy, 18.0, 3)


func c_crawler(length := 170.0, count := 1) -> void:
	var x0 := x
	var t := run(length)
	for i in count:
		var cx := x0 + 70.0 + i * 64.0
		crawler(t, cx - 14.0, cx + 14.0)
		coin(cx - 4.0, ground(t, cx) - 40.0)
		coin(cx + 10.0, ground(t, cx) - 44.0)


func c_crawler_chain(n := 3, spacing := 58.0) -> void:
	var x0 := x
	var t := run(80.0 + n * spacing + 60.0)
	for i in n:
		var cx := x0 + 80.0 + i * spacing
		crawler(t, cx - 5.0, cx + 5.0, 8.0)
		coin(cx + 18.0, ground(t, cx) - 46.0)


func c_spiker(length := 150.0) -> void:
	var x0 := x
	var t := run(length)
	spiker(t, x0 + 80.0)
	coin_arc(x0 + 50.0, y, x0 + 110.0, y, 26.0, 4)


func c_double_spiker(spacing := 90.0) -> void:
	var x0 := x
	var t := run(140.0 + spacing)
	spiker(t, x0 + 70.0)
	spiker(t, x0 + 70.0 + spacing)


func c_drone(length := 170.0, h := 30.0) -> void:
	var x0 := x
	var t := run(length)
	drone(x0 + 90.0, y - h)
	coins_on(t, x0 + 60.0, 5, 14.0, 8.0)


## Two or three drones in a row: stay low the whole way.
func c_drone_row(n := 2, spacing := 70.0) -> void:
	var x0 := x
	var t := run(110.0 + n * spacing)
	for i in n:
		drone(x0 + 80.0 + i * spacing, y - 30.0, 6.0 if i % 2 == 1 else 0.0)
	coins_on(t, x0 + 60.0, 2 + n * 3, 18.0, 8.0)


func c_spiker_drone() -> void:
	var x0 := x
	var t := run(250.0)
	spiker(t, x0 + 60.0)
	drone(x0 + 175.0, y - 30.0)
	coins_on(t, x0 + 150.0, 4, 14.0, 8.0)


## A gap with a drone hanging over it: a quick tap gets you across underneath.
func c_drone_gap(w := 56.0, h := 62.0) -> void:
	run(64.0)
	var xa := x
	var ya := y
	gap(w)
	run(90.0)
	drone(xa + w * 0.5, ya - h)
	coin_arc(xa - 6.0, ya, xa + w + 6.0, ya, 20.0, 4)


func c_stairs_down(n := 3, step := 24.0) -> void:
	for i in n:
		var x0 := x
		var t := run(64.0)
		coin(x0 + 32.0, ground(t, x0 + 32.0) - 10.0)
		gap(6.0, step)
	run(50.0)


func c_stairs_up(n := 3, step := 22.0) -> void:
	run(40.0)
	for i in n:
		gap(30.0, -step)
		var x0 := x
		var t := run(100.0)
		coin(x0 + 50.0, ground(t, x0 + 50.0) - 10.0)
	run(30.0)


func c_ramp(w := 84.0) -> void:
	run(40.0)
	slope(60.0, -16.0)
	var xa := x
	var ya := y
	gap(w, 28.0)
	run(100.0)
	coin_arc(xa, ya, xa + w, ya + 28.0, 40.0, 6)


## Upper deck over a lower route. lower: "sc" spiker+crawler, "s", "c", "d" drone,
## "g" a small gap, "" nothing.
func c_branch_upper(with_gear := 0, lower := "sc") -> void:
	var x0 := x
	var y0 := y
	var t := -1
	if lower == "g":
		run(150.0)
		var xa := x
		gap(36.0)
		coin(xa + 18.0, y - 24.0)
		t = run(254.0)
	else:
		t = run(440.0)
		if "s" in lower:
			spiker(t, x0 + 150.0)
		if "c" in lower:
			crawler(t, x0 + 250.0, x0 + 285.0)
		if "d" in lower:
			drone(x0 + 200.0, y0 - 30.0)
	var ux := x0 + 64.0
	var uy := y0 - 40.0
	var u := side(ux, uy, [[290.0, 0.0]])
	coins_on(u, ux + 30.0, 9, 26.0)
	if with_gear:
		gear(ux + 270.0, uy - 16.0)


func c_split(with_gear := 0, lower := "dcc") -> void:
	var x0 := x
	var y0 := y
	var t := run(540.0)
	if "d" in lower:
		drone(x0 + 160.0, y0 - 30.0)
	if lower.count("c") >= 1:
		crawler(t, x0 + 330.0, x0 + 350.0)
	if lower.count("c") >= 2:
		crawler(t, x0 + 410.0, x0 + 426.0)
	if "s" in lower:
		spiker(t, x0 + 340.0)
	coins_on(t, x0 + 130.0, 4, 14.0, 8.0)
	var a := side(x0 + 70.0, y0 - 44.0, [[162.0, 0.0]])
	var b := side(x0 + 262.0, y0 - 52.0, [[190.0, 0.0]])
	coins_on(a, x0 + 100.0, 5, 24.0)
	coin_arc(x0 + 220.0, y0 - 44.0, x0 + 262.0, y0 - 52.0, 16.0, 3)
	coins_on(b, x0 + 290.0, 5, 26.0)
	if with_gear:
		gear(x0 + 430.0, y0 - 52.0 - 16.0)


func c_secret_low(with_gear := 0) -> void:
	run(60.0)
	var xa := x
	var ya := y
	gap(70.0)
	run(250.0)
	coin_arc(xa - 10.0, ya, xa + 80.0, ya, 34.0, 5)
	# Hidden deck under the gap that climbs back up and merges into the main deck.
	var low := side(xa - 30.0, ya + 56.0, [[170.0, 0.0], [100.0, -56.0]])
	coin(xa + 14.0, ya + 20.0)
	coin(xa + 24.0, ya + 34.0)
	coins_on(low, xa + 30.0, 5, 18.0)
	if with_gear:
		gear(xa + 125.0, ya + 56.0 - 16.0)


func c_perch(with_gear := 0) -> void:
	var x0 := x
	var y0 := y
	var t := run(220.0)
	side(x0 + 80.0, y0 - 50.0, [[60.0, 0.0]])
	bag(x0 + 104.0, y0 - 64.0)
	if with_gear:
		gear(x0 + 126.0, y0 - 66.0)
	coins_on(t, x0 + 60.0, 6, 16.0)


func c_checkpoint(length := 100.0) -> void:
	var x0 := x
	var t := run(length)
	checkpoints.append({"x": x0 + length * 0.5, "track": t})


func c_finish() -> void:
	var x0 := x
	run(140.0)
	finish_x = x0 + 70.0
	run(420.0)


# --- chunks: springs -----------------------------------------------------------

## Spring up to a high deck. Ride onto the pad to take the high road; hop over it
## to stay low. lower: what waits on the low road ("s" spiker, "c" crawler, "d" drone).
func c_spring_up(with_gear := 0, lower := "s") -> void:
	var x0 := x
	var y0 := y
	var t := run(520.0)
	spring(t, x0 + 70.0)
	var ux := x0 + 150.0
	var uy := y0 - 84.0
	var u := side(ux, uy, [[230.0, 0.0]])
	coins_on(u, ux + 24.0, 8, 24.0)
	if with_gear:
		gear(ux + 214.0, uy - 16.0)
	if "s" in lower:
		spiker(t, x0 + 260.0)
	if "c" in lower:
		crawler(t, x0 + 330.0, x0 + 360.0)
	if "d" in lower:
		drone(x0 + 300.0, y0 - 30.0)
	# Coins along the launch arc, so riding onto the pad is the rewarding choice.
	coin(x0 + 92.0, y0 - 60.0)
	coin(x0 + 112.0, y0 - 88.0)


## A canyon you can barely jump: the spring 14 px before the edge carries you over
## easily, even into a headwind. Don't hop the pad!
func c_spring_gap(w := 84.0) -> void:
	var t := run(110.0)
	spring(t, x - 14.0)
	var xa := x
	var ya := y
	gap(w)
	run(120.0)
	coin_arc(xa - 14.0, ya, xa + w + 10.0, ya, 72.0, 7)


## Spring with a drone hanging over the launch: hop over the pad to stay safe.
func c_spring_trap() -> void:
	var x0 := x
	var t := run(320.0)
	spring(t, x0 + 90.0)
	drone(x0 + 150.0, y - 76.0)
	coins_on(t, x0 + 130.0, 6, 16.0)


## Two springs in a row with a deck between (bounce, bounce).
func c_spring_chain(w := 78.0) -> void:
	var t := run(100.0)
	spring(t, x - 14.0)
	var xa := x
	var ya := y
	gap(w)
	t = run(90.0)
	spring(t, x - 14.0)
	var xb := x
	gap(w)
	run(110.0)
	coin_arc(xa - 14.0, ya, xa + w + 20.0, ya, 72.0, 6)
	coin_arc(xb - 14.0, ya, xb + w + 20.0, ya, 72.0, 6)


# --- chunks: tunnels (low ceilings) ------------------------------------------

## A mine tunnel with a low roof. items: list of "gap", "spiker", "crawler", "flat".
## Full jumps bonk your head; short taps are the way through.
func c_tunnel(items: Array = ["gap"], h := 60.0, w := 42.0) -> void:
	run(70.0)
	var xa := x - 10.0
	var ya := y
	run(70.0)
	for it in items:
		match String(it):
			"gap":
				var gx := x
				gap(w)
				coin(gx + w * 0.5, ya - 22.0)
				run(96.0)
			"spiker":
				var x0 := x
				var t := run(130.0)
				spiker(t, x0 + 60.0)
				coin(x0 + 60.0, ya - 24.0)
			"crawler":
				var x0 := x
				var t := run(150.0)
				crawler(t, x0 + 70.0, x0 + 80.0, 8.0)
			"bag":
				var x0 := x
				run(110.0)
				bag(x0 + 55.0, ya - 26.0)
			_:
				var x0 := x
				var t := run(110.0)
				coins_on(t, x0 + 20.0, 5, 16.0, 8.0)
	run(60.0)
	roof(xa, x - 20.0, ya, h)
	run(50.0)


# --- chunks: loops --------------------------------------------------------------

## A loop-the-loop. Keep rolling and it carries you round past a ring of coins.
## after: "" or "gap" (a gap right at the exit: press as you come out).
func c_loop(r := 38.0, after := "", w := 50.0) -> void:
	var t := run(90.0)
	var lx := x
	var shift := 30.0
	loops.append({"x": lx, "y": y, "r": r, "shift": shift, "track": t})
	var L: Dictionary = loops[loops.size() - 1]
	for k in range(1, 12):
		var a := TAU * k / 12.0
		var p := Phys.loop_pos(L, a) + Vector2(-sin(a), -cos(a)) * 8.0
		coin(p.x, p.y)
	run(shift + 40.0)
	if after == "gap":
		var xa := x
		gap(w)
		run(80.0)
		coin_arc(xa - 10.0, y, xa + w + 10.0, y, 30.0, 4)
	else:
		run(60.0)


# --- chunks: lifts ----------------------------------------------------------------

## A chasm crossed on bobbing lifts. lifts: [[width, amp, period, phase], ...]
func c_lifts(lifts: Array = [[56.0, 18.0, 2.4, 0.0]], gap_w := 46.0, gear_on := -1) -> void:
	run(60.0)
	var ya := y
	var cx := x + gap_w
	for i in lifts.size():
		var L: Array = lifts[i]
		var lw: float = L[0]
		var li := side(cx, ya, [[lw, 0.0]])
		tracks[li].lift = {"amp": float(L[1]), "period": float(L[2]), "phase": float(L[3])}
		tracks[li].lift_base = ya
		for k in 3:
			coin(cx + lw * (0.25 + 0.25 * k), ya - float(L[1]) - 12.0)
		if i == gear_on:
			gear(cx + lw * 0.5, ya - float(L[1]) - 18.0)
		cx += lw + gap_w
	gap(cx - x)
	run(110.0)


# --- chunks: ziplines -------------------------------------------------------------

## Jump up and hold to grab the cable, keep holding to ride it across, let go over
## the far deck. low: put a secret lower deck (with a gear) partway across.
func c_zip(span := 300.0, h := 60.0, drop := 30.0, low := 0, hazard := "") -> void:
	run(80.0)
	var xa := x
	var ya := y
	zips.append({"x0": xa - 60.0, "y0": ya - h, "x1": xa + span + 40.0, "y1": ya - h + drop})
	gap(span)
	var t := run(170.0)
	var z: Dictionary = zips[zips.size() - 1]
	for i in 8:
		var px := xa + 20.0 + i * (span - 40.0) / 7.0
		coin(px, Phys.cable_y(z, px) + Phys.ZIP_HANG - 8.0)
	if hazard == "s":
		spiker(t, xa + span + 140.0)
	if low:
		var lx := xa + span * 0.42
		var lo := side(lx, ya + 40.0, [[80.0, 0.0]])
		gear(lx + 50.0, ya + 40.0 - 16.0)
		coins_on(lo, lx + 10.0, 3, 14.0)
		# A spring on the low deck sends you back up to the far side.
		spring(lo, lx + 74.0)


# --- finalize --------------------------------------------------------------

func _finalize(meta: Dictionary) -> Dictionary:
	var max_y := -INF
	var track_buckets := {}
	for i in tracks.size():
		var tr: Dictionary = tracks[i]
		var pts: PackedVector2Array = tr.pts
		tr.x0 = pts[0].x
		tr.x1 = pts[pts.size() - 1].x
		tr.side = tr.get("side", false)
		var amp := float((tr.get("lift", {}) as Dictionary).get("amp", 0.0))
		for p in pts:
			max_y = maxf(max_y, p.y + amp)
		_bucket(track_buckets, tr.x0, tr.x1, i)

	var enemy_buckets := {}
	for i in enemies.size():
		var e: Dictionary = enemies[i]
		e.alive = true
		var lo: float = e.x0
		var hi: float = e.get("x1", e.x0)
		var drift: float = e.get("drift", 0.0)
		_bucket(enemy_buckets, lo - drift - 24.0, hi + drift + 24.0, i)

	var pickup_buckets := {}
	var coin_total := 0
	for i in pickups.size():
		var p: Dictionary = pickups[i]
		p.alive = true
		coin_total += int(p.value)
		_bucket(pickup_buckets, p.pos.x - 16.0, p.pos.x + 16.0, i)

	var spring_buckets := {}
	for i in springs.size():
		_bucket(spring_buckets, springs[i].x - 16.0, springs[i].x + 16.0, i)
	var ceil_buckets := {}
	for i in ceils.size():
		_bucket(ceil_buckets, ceils[i].x0, ceils[i].x1, i)
	var loop_buckets := {}
	for i in loops.size():
		_bucket(loop_buckets, loops[i].x - 16.0, loops[i].x + 16.0, i)
	var zip_buckets := {}
	for i in zips.size():
		_bucket(zip_buckets, zips[i].x0, zips[i].x1, i)

	return {
		"id": meta.get("id", "custom"), "name": meta.get("name", ""),
		"speed": meta.get("speed", 128.0), "theme": meta.get("theme", 0),
		"feature": meta.get("feature", ""),
		"tracks": tracks, "enemies": enemies, "pickups": pickups,
		"checkpoints": checkpoints, "finish_x": finish_x,
		"springs": springs, "ceils": ceils, "loops": loops, "zips": zips,
		"start_x": 40.0, "start_track": 0,
		"kill_y": max_y + 140.0,
		"track_buckets": _pack(track_buckets),
		"enemy_buckets": _pack(enemy_buckets),
		"pickup_buckets": _pack(pickup_buckets),
		"spring_buckets": _pack(spring_buckets),
		"ceil_buckets": _pack(ceil_buckets),
		"loop_buckets": _pack(loop_buckets),
		"zip_buckets": _pack(zip_buckets),
		"coin_total": coin_total, "gear_total": _gears,
	}


func _bucket(buckets: Dictionary, lo: float, hi: float, idx: int) -> void:
	var a := int(floor(lo / Phys.BUCKET))
	var b := int(floor(hi / Phys.BUCKET))
	for k in range(a, b + 1):
		if not buckets.has(k):
			buckets[k] = []
		buckets[k].append(idx)


func _pack(buckets: Dictionary) -> Dictionary:
	var out := {}
	for k in buckets:
		out[k] = PackedInt32Array(buckets[k])
	return out
