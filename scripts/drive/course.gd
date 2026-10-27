## Builds a GAUNTLET course left to right from obstacle "moves": the floor line (steps,
## stairs, ramps, pits), crates and logs sitting on it, and checkpoints between
## sections. The result plugs into drive_world.gd like a SUMMIT level does.
extends RefCounted

const Terrain := preload("res://scripts/drive/terrain.gd")

var x := -300.0
var y := 0.0
var floor := PackedVector2Array()
var props: Array = []
var solids: Array = []      # closed outlines that collide (crates, logs)
var gaps: Array = []        # [x0, x1, lip_y, land_y]
var checkpoints: Array = []


func _init() -> void:
	floor.append(Vector2(x, y))


func _pt() -> void:
	floor.append(Vector2(x, y))


func flat(len: float) -> void:
	x += len
	_pt()


## Up (h > 0) or down (h < 0) a vertical face.
func step(h: float) -> void:
	y -= h
	_pt()


func slope(len: float, rise: float) -> void:
	x += len
	y -= rise
	_pt()


## A smooth hump (or a dip, h < 0).
func hump(len: float, h: float) -> void:
	var n := maxi(4, int(len / 6.0))
	var y0 := y
	var x0 := x
	for i in range(1, n + 1):
		var u := float(i) / float(n)
		x = x0 + len * u
		y = y0 - h * sin(u * PI)
		_pt()
	y = y0


## A kicker: a ramp up, then the lip drops straight back down.
func kicker(len: float, h: float) -> void:
	slope(len, h)
	step(-h)


## A pit: the floor stops at the lip and carries on w later (land: the far side's
## height relative to the lip, + = higher).
func pit(w: float, land := 0.0) -> void:
	var lip := y
	gaps.append([x, x + w, lip, lip - land])
	step(-140.0)
	flat(w)
	y = lip - land
	_pt()


## A crate (or a row of them) sitting on the floor ahead; the floor runs on underneath.
func crate(w: float, h: float, gap_before := 24.0) -> void:
	flat(gap_before)
	var r := Rect2(x, y - h, w, h)
	_solid(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]))
	props.append({"kind": "crate", "rect": r, "x0": r.position.x, "x1": r.end.x})
	flat(w)


## Crates stacked into steps going up then down: heights like [8, 16, 24, 16, 8].
func crate_stairs(heights: Array, w := 14.0) -> void:
	flat(20.0)
	for h in heights:
		var r := Rect2(x, y - float(h), w, float(h))
		_solid(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]))
		# Draw as stacked 8 px crates.
		var top := r.position.y
		while top < r.end.y - 0.5:
			var ch := minf(8.0, r.end.y - top)
			props.append({"kind": "crate", "rect": Rect2(r.position.x, top, w, ch), "x0": r.position.x, "x1": r.end.x})
			top += ch
		flat(w)


func log_at(r: float, gap_before := 24.0) -> void:
	flat(gap_before)
	var c := Vector2(x + r, y - r)
	var pts := PackedVector2Array()
	for i in 14:
		var a := TAU * float(i) / 14.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	_solid(pts)
	props.append({"kind": "log", "c": c, "r": r, "x0": c.x - r, "x1": c.x + r})
	flat(2.0 * r)


func stairs(n: int, rise: float, tread: float) -> void:
	for i in n:
		step(rise)
		flat(tread)


## A raised block: up h, across len, back down.
func table(h: float, len: float) -> void:
	step(h)
	flat(len)
	step(-h)


## A row of n smooth humps (whoops), each len long and h high.
func whoops(n: int, len: float, h: float) -> void:
	for i in n:
		hump(len, h)


## A raised block with ramps: up a slope of up_len to h, across top, then down a
## slope of down_len (0: a sheer drop).
func mesa(h: float, up_len: float, top: float, down_len := 0.0) -> void:
	slope(up_len, h)
	flat(top)
	if down_len > 0.0:
		slope(down_len, -h)
	else:
		step(-h)


func checkpoint() -> void:
	flat(30.0)
	checkpoints.append(x)
	flat(40.0)


## Rounds the floor's corners between sloped or flat runs (the foot and top of a ramp,
## a slope change) into short curves, so wheels roll over them instead of slamming into
## a kink. Vertical faces (steps, pit walls, kicker lips) stay sharp.
static func _rounded(pts: PackedVector2Array, r := 10.0) -> PackedVector2Array:
	var out := PackedVector2Array([pts[0]])
	for i in range(1, pts.size() - 1):
		var a := pts[i - 1]
		var p := pts[i]
		var b := pts[i + 1]
		var d0 := p - a
		var d1 := b - p
		if absf(d0.x) < 0.5 or absf(d1.x) < 0.5 or d0.length() < 2.0 or d1.length() < 2.0:
			out.append(p)
			continue
		var turn := absf(d0.normalized().angle_to(d1.normalized()))
		if turn < deg_to_rad(4.0):
			out.append(p)
			continue
		var k := minf(r, minf(d0.length(), d1.length()) * 0.45)
		var p0 := p - d0.normalized() * k
		var p1 := p + d1.normalized() * k
		var n := 4 + int(turn * 8.0)
		for j in n + 1:
			var u := float(j) / float(n)
			out.append(p0.lerp(p, u).lerp(p.lerp(p1, u), u))
	out.append(pts[pts.size() - 1])
	return out


func _solid(pts: PackedVector2Array) -> void:
	solids.append(pts)


## The level dict drive_world.gd rides.
func finish(meta: Dictionary) -> Dictionary:
	flat(60.0)
	var finish_x := x
	flat(400.0)
	floor = _rounded(floor)
	var t := Terrain.new()
	t.add_polyline(floor)
	for s in solids:
		t.add_polyline(s, 1, true)
	t.add_segment(Vector2(-300, 0), Vector2(-300, -400))
	var lv := meta.duplicate()
	lv.merge({"terrain": t, "ground": floor, "props": props, "gaps": gaps, "bridges": [],
		"checkpoints": checkpoints, "coins": [], "fuel": [], "start": Vector2(0, 0),
		"finish_x": finish_x, "kill_y": 3000.0, "mode": "gauntlet"}, true)
	return lv
