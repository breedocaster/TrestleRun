## Builds level data from chunk layouts. A layout is a list of [chunk_name, args...];
## each chunk appends track, hazards and pickups at the builder's cursor.
extends RefCounted

const Phys := preload("res://scripts/game/bike_physics.gd")
const Catalog := preload("res://scripts/catalog.gd")
const Layouts := preload("res://scripts/game/level_layouts.gd")
const LetterSpots := preload("res://scripts/game/letter_spots.gd")

enum { P_COIN, P_BAG, P_GEAR, P_LETTER }
const LETTERS := "TRESTLE"

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
var switches: Array = []
var walls: Array = []
var ramps: Array = []
var powerups: Array = []
var chase := false
var level_id := ""
## Dev (--place-letters): build without letters so every coin is a coin.
static var no_letters := false
## Lane new things go into: -1 foreground, 0 main, 1 background.
var lane := 0
var x := 0.0
var y := 0.0
var _cur := -1
var _gears := 0


static func build(level_id: String) -> Dictionary:
	return build_layout(Layouts.LAYOUTS[level_id], Catalog.level(level_id))


static func build_layout(layout: Array, meta: Dictionary) -> Dictionary:
	var b = load("res://scripts/game/level_library.gd").new()
	b.level_id = String(meta.get("id", ""))
	for chunk in layout:
		b.marks.append([String(chunk[0]), snappedf(b.x, 1.0)])
		b.callv("c_" + String(chunk[0]), chunk.slice(1))
	var lv: Dictionary = b._finalize(meta)
	lv.marks = b.marks
	return lv


# --- primitives ------------------------------------------------------------

func run(length: float) -> int:
	if _cur == -1:
		tracks.append({"lane": lane, "pts": PackedVector2Array([Vector2(x, y)])})
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
	tracks.append({"lane": lane, "pts": pts, "side": true})
	return tracks.size() - 1


func ground(t: int, px: float) -> float:
	return Phys.height_at(tracks[t], px)


func coin(px: float, py: float) -> void:
	pickups.append({"lane": lane, "type": P_COIN, "pos": Vector2(px, py), "value": 1})


func bag(px: float, py: float) -> void:
	pickups.append({"lane": lane, "type": P_BAG, "pos": Vector2(px, py), "value": 10})


func gear(px: float, py: float) -> void:
	pickups.append({"lane": lane, "type": P_GEAR, "pos": Vector2(px, py), "value": 0, "gear": _gears})
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
	enemies.append({"lane": lane, "type": Phys.CRAWLER, "track": t, "x0": xa, "x1": xb, "speed": speed,
		"phase": float(enemies.size()) * 7.3, "stompable": true})


func spiker(t: int, px: float) -> void:
	var e := {"lane": lane, "type": Phys.SPIKER, "x0": px, "y0": ground(t, px), "stompable": false}
	if tracks[t].has("lift"):
		e.track = t
	enemies.append(e)


func drone(px: float, py: float, drift := 0.0) -> void:
	enemies.append({"lane": lane, "type": Phys.DRONE, "x0": px, "y0": py, "drift": drift,
		"phase": float(enemies.size()) * 1.7, "stompable": false})


func spring(t: int, px: float) -> void:
	springs.append({"lane": lane, "x": px, "track": t, "y": ground(t, px)})


## Flat tunnel roof `h` px above the deck from xa to xb. top: the rock's upper surface
## (-INF = solid mountain up to the sky; a cliff has a deck on top instead).
func roof(xa: float, xb: float, deck_y: float, h: float, top := -INF) -> void:
	ceils.append({"lane": lane, "pts": PackedVector2Array([Vector2(xa, deck_y - h), Vector2(xb, deck_y - h)]),
		"x0": xa, "x1": xb, "h": h, "deck": deck_y, "top": top})


## A power-up icon floating over the deck: "sticky", "rocket", "magnet" or "hat".
func power(px: float, py: float, kind: String) -> void:
	powerups.append({"lane": lane, "kind": kind, "pos": Vector2(px, py)})


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


## Rolling dunes: up and over n crests, coins along the tops. Jumping on an upslope
## launches higher (RAMP_BOOST), so crests are where the big air and flips come from.
func c_hills(n := 2, h := 14.0, w := 64.0) -> void:
	run(30.0)
	for i in n:
		var xa := x
		var t := slope(w, -h)
		coin(xa + w * 0.5, ground(t, xa + w * 0.5) - 12.0)
		var xc := x
		run(18.0)
		coin(xc + 9.0, y - 14.0)
		slope(w, h)
		coin(xc + 18.0 + w * 0.5, ground(t, xc + 18.0 + w * 0.5) - 12.0)
	run(30.0)


## A long downhill run in n slopes, picking up a coin on each.
func c_descent(n := 3, dy := 16.0, seg := 64.0) -> void:
	run(24.0)
	for i in n:
		var xa := x
		var t := slope(seg, dy)
		coin(xa + seg * 0.5, ground(t, xa + seg * 0.5) - 12.0)
		run(14.0)
	run(30.0)


## A long climb in n slopes.
func c_rise(n := 2, dy := 12.0, seg := 70.0) -> void:
	run(24.0)
	for i in n:
		var xa := x
		var t := slope(seg, -dy)
		coin(xa + seg * 0.5, ground(t, xa + seg * 0.5) - 12.0)
		run(16.0)
	run(30.0)


## Kicker ramp over a gap onto a lower deck: lots of air for flips. Coins mark the arc.
func c_kicker(w := 76.0, drop := 40.0) -> void:
	run(40.0)
	slope(44.0, -14.0)
	var xa := x
	var ya := y
	gap(w, drop + 14.0)
	run(120.0)
	coin_arc(xa, ya, xa + w, ya + drop + 14.0, 52.0, 6)


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
	var ux := x0 + 146.0
	var uy := y0 - 78.0
	var u := side(ux, uy, [[234.0, 0.0]])
	coins_on(u, ux + 24.0, 8, 24.0)
	if with_gear:
		gear(ux + 150.0, uy - 16.0)
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
	loops.append({"lane": lane, "x": lx, "y": y, "r": r, "shift": shift, "track": t})
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
	zips.append({"lane": lane, "x0": xa - 60.0, "y0": ya - h, "x1": xa + span + 40.0, "y1": ya - h + drop})
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


# --- chunks: power-ups ------------------------------------------------------------

## A stretch of deck with a power-up hovering over it (a hop grabs it, so does riding).
func c_power(kind := "magnet", length := 150.0) -> void:
	var x0 := x
	run(length)
	power(x0 + length * 0.5, y - 12.0, kind)


## Sticky-tire cliff: the trail runs through a tunnel in a rock cliff. With sticky
## tires, jump at the green-marked face to drive up it and ride the top (coins, gear),
## then drop off the far end for big air. Without them the face bonks you back down
## and you take the tunnel. sticky: put the pickup on the approach.
func c_cliff(length := 300.0, h := 110.0, with_gear := 0, sticky := 1, roof_h := 58.0, items: Array = []) -> void:
	var x0 := x
	run(150.0 if sticky else 90.0)
	if sticky:
		power(x0 + 40.0, y - 12.0, "sticky")
	run(40.0)
	var xa := x
	var ya := y
	# Inside the tunnel: taps only (it's a low roof), maybe a hazard.
	var t := run(length)
	var k := 0
	for it in items:
		var px := xa + length * (0.35 + 0.3 * k)
		match String(it):
			"spiker":
				spiker(t, px)
			"crawler":
				crawler(t, px - 8.0, px + 8.0, 8.0)
		k += 1
	coins_on(t, xa + 30.0, 4, 18.0, 8.0)
	roof(xa, xa + length, ya, roof_h, ya - h)
	var top := side(xa, ya - h, [[length, 0.0]])
	tracks[top].no_supports = true
	walls.append({"lane": lane, "x": xa, "y_top": ya - h, "y_bot": ya - roof_h, "top": top})
	coins_on(top, xa + 30.0, 8, (length - 60.0) / 7.0)
	if with_gear:
		gear(xa + length - 30.0, ya - h - 18.0)
	# Landing zone past the tunnel mouth for the drop off the top.
	run(200.0)
	coin_arc(xa + length, ya - h, xa + length + 120.0, ya, 10.0, 5)


## Three-way ramp (castle-style routes): a steep kicker at the end of the approach.
## Rocket + full jump reaches the high deck, a full jump alone the middle deck, a tap
## or no jump drops you to the low road. All three ride on and rejoin.
func c_tri_ramp(with_gear := 1, low := "c") -> void:
	var x0 := x
	run(60.0)
	power(x0 + 40.0, y - 12.0, "rocket")
	run(250.0)
	var t0 := slope(40.0, -36.0)
	var xl := x
	var yl := y
	ramps.append({"lane": lane, "x": xl, "y": yl})
	gap(26.0, 66.0)  # low road starts just past the lip, 30 px under the approach
	var low_t := run(720.0)
	var mid := side(xl + 60.0, yl - 55.0, [[360.0, 0.0]])
	var top := side(xl + 120.0, yl - 115.0, [[340.0, 0.0]])
	coins_on(top, xl + 150.0, 9, 32.0)
	bag(xl + 300.0, yl - 130.0)
	if with_gear:
		gear(xl + 440.0, yl - 115.0 - 18.0)
	coins_on(mid, xl + 90.0, 6, 40.0)
	coins_on(low_t, xl + 60.0, 4, 30.0)
	# Low-road hazards sit well past where a roll-off lands, so there's room to set up.
	if "c" in low:
		crawler(low_t, xl + 320.0, xl + 350.0)
	if "s" in low:
		spiker(low_t, xl + 480.0)
	if "d" in low:
		drone(xl + 380.0, yl + 30.0 - 30.0)
	coin_arc(xl - 30.0, yl + 10.0, xl + 30.0, yl - 30.0, 16.0, 3)


# --- chunks: crumbling trestle ------------------------------------------------------

## Old planks that give way CRUMBLE_DELAY s after your wheels touch them. Short ones
## you roll across; long ones (more than ~50 px) drop out under you, so hop.
func c_crumble(pieces: Array = [44.0, 44.0, 76.0, 44.0, 88.0, 44.0], delay := -1.0) -> void:
	run(30.0)
	var d := Phys.CRUMBLE_DELAY if delay < 0.0 else delay
	for L in pieces:
		_cur = -1
		var x0 := x
		var t := run(float(L))
		tracks[t].crumble = d
		coin(x0 + float(L) * 0.5, y - (26.0 if float(L) > 60.0 else 10.0))
	_cur = -1
	run(60.0)


## The whole trail collapses behind you (see Phys.CHASE_*). Put this first.
func c_chase() -> void:
	chase = true


# --- chunks: lanes (2.5D) ----------------------------------------------------

const SW_LEN := 120.0   # distance a switch ramp takes to swing across lanes
const RET_W := 36.0     # half width of the wide merge plate back to the main lane


## Fork onto another lane (to_lane: 1 = background, -1 = foreground). Roll onto the
## switch plate to swing across and ride `inner` there; hop over it to stay on the
## main deck, which carries `main`. A wide merge plate brings you back. forced = the
## main deck breaks off past the plate, so the switch is the only way on.
func c_fork(to_lane := 1, inner: Array = [["flat", 200.0]], main: Array = [["flat", 200.0]],
		with_gear := 0, forced := 0) -> void:
	var main_lane := lane
	var t_main := run(80.0)
	var pad_x := x - 30.0
	var save_x := x
	var save_y := y
	# The other lane, starting under the switch so the ramp has somewhere to land.
	lane = to_lane
	x = pad_x
	_cur = -1
	var t_in := run(SW_LEN + 40.0)
	coins_on(t_in, pad_x + SW_LEN + 10.0, 3, 16.0)
	for ch in inner:
		callv("c_" + String(ch[0]), ch.slice(1))
	if with_gear:
		run(40.0)
		gear(x - 20.0, y - 18.0)
	var t_ret := run(30.0 + RET_W * 2.0 + 8.0)
	var ret_x := x - RET_W - 8.0
	var ret_y := y
	var join_end := ret_x + RET_W + SW_LEN + 40.0
	# Back on the main lane.
	lane = main_lane
	x = save_x
	y = save_y
	_cur = t_main
	if forced:
		run(30.0)
		gap(maxf(160.0, ret_x - RET_W - 40.0 - x), ret_y - y)
		run(join_end - x + 60.0)
	else:
		for ch in main:
			callv("c_" + String(ch[0]), ch.slice(1))
		if x < join_end:
			run(join_end - x)
	var t_join := -1
	for i in tracks.size():
		var tr: Dictionary = tracks[i]
		if int(tr.lane) == main_lane and not tr.get("side", false) \
				and tr.pts[0].x <= ret_x - RET_W and tr.pts[tr.pts.size() - 1].x >= ret_x + RET_W + SW_LEN:
			t_join = i
	assert(t_join >= 0, "fork: main deck must run under the merge")
	switches.append({"lane": main_lane, "x": pad_x, "w": Phys.SWITCH_W, "track": t_main,
		"to_lane": to_lane, "to_track": t_in, "len": SW_LEN})
	switches.append({"lane": to_lane, "x": ret_x, "w": RET_W, "track": t_ret,
		"to_lane": main_lane, "to_track": t_join, "len": SW_LEN})


# --- finalize --------------------------------------------------------------

func _finalize(meta: Dictionary) -> Dictionary:
	_place_letters()
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
		_bucket(track_buckets, tr.x0, tr.x1, i, int(tr.lane))

	var enemy_buckets := {}
	for i in enemies.size():
		var e: Dictionary = enemies[i]
		e.alive = true
		var lo: float = e.x0
		var hi: float = e.get("x1", e.x0)
		var drift: float = e.get("drift", 0.0)
		_bucket(enemy_buckets, lo - drift - 24.0, hi + drift + 24.0, i, int(e.lane))

	var pickup_buckets := {}
	var coin_total := 0
	for i in pickups.size():
		var p: Dictionary = pickups[i]
		p.alive = true
		coin_total += int(p.value)
		_bucket(pickup_buckets, p.pos.x - 16.0, p.pos.x + 16.0, i, int(p.lane))

	var spring_buckets := {}
	for i in springs.size():
		_bucket(spring_buckets, springs[i].x - 16.0, springs[i].x + 16.0, i, int(springs[i].lane))
	var ceil_buckets := {}
	for i in ceils.size():
		_bucket(ceil_buckets, ceils[i].x0, ceils[i].x1, i, int(ceils[i].lane))
	var loop_buckets := {}
	for i in loops.size():
		_bucket(loop_buckets, loops[i].x - 16.0, loops[i].x + 16.0, i, int(loops[i].lane))
	var zip_buckets := {}
	for i in zips.size():
		_bucket(zip_buckets, zips[i].x0, zips[i].x1, i, int(zips[i].lane))
	var switch_buckets := {}
	for i in switches.size():
		var w: Dictionary = switches[i]
		_bucket(switch_buckets, w.x - w.w - 16.0, w.x + w.w + 16.0, i, int(w.lane))
	var wall_buckets := {}
	for i in walls.size():
		_bucket(wall_buckets, walls[i].x - 24.0, walls[i].x + 24.0, i, int(walls[i].lane))
	var power_buckets := {}
	for i in powerups.size():
		_bucket(power_buckets, powerups[i].pos.x - 24.0, powerups[i].pos.x + 24.0, i, int(powerups[i].lane))

	var lv := {
		"id": meta.get("id", "custom"), "name": meta.get("name", ""),
		"speed": meta.get("speed", 128.0), "theme": meta.get("theme", 0),
		"feature": meta.get("feature", ""),
		"tracks": tracks, "enemies": enemies, "pickups": pickups,
		"checkpoints": checkpoints, "finish_x": finish_x,
		"springs": springs, "ceils": ceils, "loops": loops, "zips": zips, "switches": switches,
		"walls": walls, "powerups": powerups, "ramps": ramps,
		"wall_buckets": _pack(wall_buckets), "power_buckets": _pack(power_buckets),
		"start_x": 40.0, "start_track": 0,
		"kill_y": max_y + 140.0,
		"track_buckets": _pack(track_buckets),
		"enemy_buckets": _pack(enemy_buckets),
		"pickup_buckets": _pack(pickup_buckets),
		"spring_buckets": _pack(spring_buckets),
		"ceil_buckets": _pack(ceil_buckets),
		"loop_buckets": _pack(loop_buckets),
		"zip_buckets": _pack(zip_buckets),
		"switch_buckets": _pack(switch_buckets),
		"coin_total": coin_total, "gear_total": _gears,
	}
	if chase:
		lv.chase = true
	return lv


## T-R-E-S-T-L-E: turn seven coins into letters. Trails use the spots in
## letter_spots.gd (chosen by --place-letters from coins the dev bot really picks up);
## anything else falls back to choose_letters() over all coins.
func _place_letters() -> void:
	if no_letters:
		return
	var spots: Array = LetterSpots.SPOTS.get(level_id, [])
	if spots.size() == LETTERS.length():
		for i in spots.size():
			var want := Vector2(float(spots[i][0]), float(spots[i][1]))
			for p in pickups:
				if int(p.type) == P_COIN and p.pos.distance_to(want) < 1.0:
					p.type = P_LETTER
					p.value = 0
					p.letter = i
					break
		return
	var all := []
	for i in pickups.size():
		all.append(i)
	for e in choose_letters(all):
		pickups[e[0]].type = P_LETTER
		pickups[e[0]].value = 0
		pickups[e[0]].letter = e[1]


## Pick seven coins (from `allowed` pickup indices): one per seventh of the trail,
## each the most airborne coin there. Returns [[pickup index, letter index], ...].
func choose_letters(allowed: Array) -> Array:
	var x_lo := 300.0
	var x_hi := finish_x - 150.0
	if x_hi - x_lo < 700.0:
		return []
	var best := []
	for i in LETTERS.length():
		best.append([-1, -INF])
	for pi in allowed:
		var p: Dictionary = pickups[pi]
		if int(p.type) != P_COIN or p.pos.x < x_lo or p.pos.x > x_hi:
			continue
		var bin := clampi(int((p.pos.x - x_lo) / (x_hi - x_lo) * LETTERS.length()), 0, LETTERS.length() - 1)
		var g := INF
		for t in tracks:
			if int(t.lane) == 0 and not t.get("side", false) and not t.has("crumble") \
					and p.pos.x >= t.pts[0].x and p.pos.x <= t.pts[t.pts.size() - 1].x:
				g = Phys.height_at(t, p.pos.x)
				break
		# Up in the air is good (jump arcs, upper decks). Coins sitting on the deck,
		# hidden low roads, other lanes and power-up-only heights (cliff tops, rocket
		# decks) only get a letter if nothing else is in that stretch.
		var h: float = 0.0 if g == INF else g - float(p.pos.y)
		if h > 85.0 or h < 0.0:
			continue
		if h < 14.0 or int(p.lane) != 0:
			h -= 100.0
		# Prefer the middle of the bin a little, so letters spread out.
		var mid := x_lo + (bin + 0.5) * (x_hi - x_lo) / LETTERS.length()
		h -= absf(p.pos.x - mid) * 0.02
		if h > float(best[bin][1]):
			best[bin] = [pi, h]
	var out := []
	for i in best.size():
		if int(best[i][0]) >= 0:
			out.append([int(best[i][0]), i])
	return out


func _bucket(buckets: Dictionary, lo: float, hi: float, idx: int, ln := 0) -> void:
	var a := int(floor(lo / Phys.BUCKET))
	var b := int(floor(hi / Phys.BUCKET))
	for k in range(a, b + 1):
		var key := k * 4 + ln + 1
		if not buckets.has(key):
			buckets[key] = []
		buckets[key].append(idx)


func _pack(buckets: Dictionary) -> Dictionary:
	var out := {}
	for k in buckets:
		out[k] = PackedInt32Array(buckets[k])
	return out
