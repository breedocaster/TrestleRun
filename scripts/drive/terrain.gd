## Collision ground for SUMMIT and GAUNTLET: line segments (the hills' surface, the
## edges of crates, logs, ramps...) bucketed by x so a wheel only checks the few near
## it. Drawing lives in drive_art.gd; this is just geometry.
extends RefCounted

const BUCKET := 48.0

## Each segment: [a: Vector2, b: Vector2, kind: int]. kind 0 = ground, 1 = obstacle
## (crates, logs: same physics, drawn differently), 2 = finish/checkpoint marker (no
## collision; kept with the rest so the art can find it).
var segs: Array = []
var _buckets: Dictionary = {}
var x_min := 0.0
var x_max := 0.0
## Filled shapes to draw: {"pts": PackedVector2Array, "kind": String} (ground body,
## crates, logs...). The surface segments come from these.
var shapes: Array = []


func add_segment(a: Vector2, b: Vector2, kind := 0) -> void:
	if a.distance_squared_to(b) < 0.01:
		return
	var i := segs.size()
	segs.append([a, b, kind])
	var b0 := int(floorf(minf(a.x, b.x) / BUCKET))
	var b1 := int(floorf(maxf(a.x, b.x) / BUCKET))
	for k in range(b0, b1 + 1):
		# (Packed arrays are values: append to a copy and store it back.)
		var arr: PackedInt32Array = _buckets.get(k, PackedInt32Array())
		arr.append(i)
		_buckets[k] = arr
	x_min = minf(x_min, minf(a.x, b.x))
	x_max = maxf(x_max, maxf(a.x, b.x))


## A polyline as the top of the ground (kind 0) or an obstacle outline (closed).
func add_polyline(pts: PackedVector2Array, kind := 0, closed := false) -> void:
	for i in pts.size() - 1:
		add_segment(pts[i], pts[i + 1], kind)
	if closed and pts.size() > 2:
		add_segment(pts[pts.size() - 1], pts[0], kind)


## Contacts for a circle: [[normal (out of the ground, toward the centre), depth], ...]
## for every segment closer than r + margin. depth < 0 = a gap of that size.
func circle_contacts(c: Vector2, r: float, margin := 0.5) -> Array:
	var out := []
	var b0 := int(floorf((c.x - r - margin) / BUCKET))
	var b1 := int(floorf((c.x + r + margin) / BUCKET))
	var seen := {}
	for k in range(b0, b1 + 1):
		if not _buckets.has(k):
			continue
		for i in (_buckets[k] as PackedInt32Array):
			if seen.has(i):
				continue
			seen[i] = true
			var s: Array = segs[i]
			if int(s[2]) == 2:
				continue
			var a: Vector2 = s[0]
			var b: Vector2 = s[1]
			var ab := b - a
			var t := clampf((c - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
			var q := a + ab * t
			var d := c - q
			var dist := d.length()
			if dist > r + margin:
				continue
			var n: Vector2
			if dist > 0.0001:
				n = d / dist
			else:
				n = Vector2(-ab.y, ab.x).normalized()
				if n.y > 0.0:
					n = -n
			# Two contacts with nearly the same normal (a polyline vertex): keep the deeper.
			var dup := false
			for o in out:
				if (o[0] as Vector2).dot(n) > 0.995:
					dup = true
					if r - dist > float(o[1]):
						o[0] = n
						o[1] = r - dist
					break
			if not dup:
				out.append([n, r - dist])
	return out


## Height of the topmost surface at x (the lowest y), for cameras and placing things.
## Scans the buckets at x; INF if there's nothing there.
func top_at(x: float) -> float:
	var k := int(floorf(x / BUCKET))
	if not _buckets.has(k):
		return INF
	var best := INF
	for i in (_buckets[k] as PackedInt32Array):
		var s: Array = segs[i]
		if int(s[2]) == 2:
			continue
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		if (a.x - x) * (b.x - x) > 0.0 or absf(b.x - a.x) < 0.001:
			continue
		var y := lerpf(a.y, b.y, (x - a.x) / (b.x - a.x))
		best = minf(best, y)
	return best
