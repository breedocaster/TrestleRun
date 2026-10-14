## Builds level data from chunk layouts. A layout is a list of [chunk_name, args...];
## each chunk appends track, hazards and pickups at the builder's cursor.
extends RefCounted

const Phys := preload("res://scripts/game/bike_physics.gd")
const Catalog := preload("res://scripts/catalog.gd")

enum { P_COIN, P_BAG, P_GEAR }

const LAYOUTS := {
	"dusty_trail": [
		["start"], ["flat", 140.0], ["gap", 40.0], ["flat", 120.0], ["crawler", 170.0],
		["gap", 52.0], ["spiker"], ["flat", 100.0], ["branch_upper", 1],
		["checkpoint"],
		["drone"], ["gap", 56.0], ["drop", 24.0], ["flat", 110.0], ["crawler", 180.0],
		["secret_low", 1],
		["checkpoint"],
		["spiker"], ["gap", 60.0], ["perch", 1], ["climb", 22.0], ["flat", 110.0],
		["spiker_drone"], ["flat", 100.0], ["finish"],
	],
	"copper_canyon": [
		["start"], ["flat", 120.0], ["gap", 56.0], ["stairs_down", 3], ["spiker"],
		["crawler", 220.0, 2], ["ramp"], ["branch_upper", 1],
		["checkpoint"],
		["drone"], ["double_spiker", 96.0], ["stairs_up", 3], ["gap", 64.0, 24.0],
		["split", 1],
		["checkpoint"],
		["spiker_drone"], ["drone_gap", 52.0], ["flat", 90.0], ["perch", 1],
		["gap", 60.0], ["crawler", 170.0], ["finish"],
	],
	"rustyard": [
		["start"], ["crawler_chain", 3], ["gap", 60.0], ["drone_gap", 56.0], ["spiker"],
		["checkpoint"],
		["secret_low", 1], ["stairs_up", 3], ["double_spiker", 90.0], ["ramp"],
		["checkpoint"],
		["split", 1], ["crawler_chain", 4], ["gap", 64.0], ["drone"], ["perch", 1],
		["spiker_drone"], ["flat", 90.0], ["finish"],
	],
	"night_trestle": [
		["start"], ["gap", 60.0], ["spiker_drone"], ["stairs_down", 3], ["crawler_chain", 3],
		["drone_gap", 58.0],
		["checkpoint"],
		["branch_upper", 1], ["double_spiker", 82.0], ["ramp"], ["gap", 70.0, 20.0],
		["checkpoint"],
		["secret_low", 1], ["stairs_up", 3], ["crawler_chain", 4], ["split", 1],
		["drone_gap", 60.0], ["double_spiker", 78.0], ["flat", 80.0], ["finish"],
	],
}

var tracks: Array = []
var enemies: Array = []
var pickups: Array = []
var checkpoints: Array = []
var finish_x := 0.0
var x := 0.0
var y := 0.0
var _cur := -1
var _gears := 0


static func build(level_id: String) -> Dictionary:
	var meta := Catalog.level(level_id)
	var b = load("res://scripts/game/level_library.gd").new()
	for chunk in LAYOUTS[level_id]:
		b.callv("c_" + String(chunk[0]), chunk.slice(1))
	return b._finalize(meta)


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
	enemies.append({"type": Phys.SPIKER, "x0": px, "y0": ground(t, px), "stompable": false})


func drone(px: float, py: float, drift := 0.0) -> void:
	enemies.append({"type": Phys.DRONE, "x0": px, "y0": py, "drift": drift,
		"phase": float(enemies.size()) * 1.7, "stompable": false})


# --- chunks ----------------------------------------------------------------

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


func c_drone(length := 170.0) -> void:
	var x0 := x
	var t := run(length)
	drone(x0 + 90.0, y - 30.0)
	coins_on(t, x0 + 60.0, 5, 14.0, 8.0)


func c_spiker_drone() -> void:
	var x0 := x
	var t := run(250.0)
	spiker(t, x0 + 60.0)
	drone(x0 + 175.0, y - 30.0)
	coins_on(t, x0 + 150.0, 4, 14.0, 8.0)


func c_drone_gap(w := 56.0) -> void:
	run(64.0)
	var xa := x
	var ya := y
	gap(w)
	run(90.0)
	drone(xa + w * 0.5, ya - 54.0)
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


func c_ramp() -> void:
	run(40.0)
	slope(60.0, -16.0)
	var xa := x
	var ya := y
	gap(84.0, 28.0)
	run(100.0)
	coin_arc(xa, ya, xa + 84.0, ya + 28.0, 40.0, 6)


func c_branch_upper(with_gear := 0) -> void:
	var x0 := x
	var y0 := y
	var t := run(440.0)
	spiker(t, x0 + 150.0)
	crawler(t, x0 + 250.0, x0 + 285.0)
	var ux := x0 + 64.0
	var uy := y0 - 40.0
	var u := side(ux, uy, [[290.0, 0.0]])
	coins_on(u, ux + 30.0, 9, 26.0)
	if with_gear:
		gear(ux + 270.0, uy - 16.0)


func c_split(with_gear := 0) -> void:
	var x0 := x
	var y0 := y
	var t := run(540.0)
	drone(x0 + 160.0, y0 - 30.0)
	crawler(t, x0 + 300.0, x0 + 320.0)
	crawler(t, x0 + 380.0, x0 + 396.0)
	coins_on(t, x0 + 130.0, 4, 14.0, 8.0)
	var a := side(x0 + 70.0, y0 - 44.0, [[150.0, 0.0]])
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
		for p in pts:
			max_y = maxf(max_y, p.y)
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

	return {
		"id": meta.id, "name": meta.name, "speed": meta.speed, "theme": meta.theme,
		"tracks": tracks, "enemies": enemies, "pickups": pickups,
		"checkpoints": checkpoints, "finish_x": finish_x,
		"start_x": 40.0, "start_track": 0,
		"kill_y": max_y + 140.0,
		"track_buckets": _pack(track_buckets),
		"enemy_buckets": _pack(enemy_buckets),
		"pickup_buckets": _pack(pickup_buckets),
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
