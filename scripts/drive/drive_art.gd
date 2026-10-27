## Drawing for SUMMIT and GAUNTLET courses: the ground (a soil body under a grass or
## sand lip), trestle bridges, pits, crates and logs, fuel cans and charge points,
## coins, distance posts, checkpoints and the summit flag. Colours come from the
## trail's backdrop theme so each course matches its sky.
extends RefCounted

const Icons := preload("res://scripts/game/icons.gd")

## Per backdrop theme: [lip, soil, deep, speck] (the soil body darkens with depth).
const GROUND := {
	0: ["e0b070", "b07a48", "6b4a30", "8a5a38"],     # desert sand
	1: ["d9744a", "a8452e", "5e2418", "c25a38"],     # red rock
	2: ["9a7a62", "6e4e3c", "3a2a22", "84624c"],     # rustyard
	3: ["5a6a8a", "3a3f5c", "1e2034", "4a5070"],     # night
	4: ["e2a86a", "b8784a", "6e4430", "c88a5a"],     # mesa
	5: ["8a7a6a", "5a4a3e", "2a221e", "6e5e50"],     # mine
	6: ["e09060", "b0603e", "60301e", "c87a50"],     # hoodoo
	7: ["8a8a96", "5e5e6c", "2e2e38", "74747e"],     # hoist yard
	8: ["6aa84a", "6a5a3a", "3a3022", "7a6a48"],     # pines
	9: ["c8b8a0", "8a7e6e", "4a4238", "a89a88"],     # quarry
	10: ["d08a5a", "8a4a32", "48261a", "a85e40"],    # rocket ridge
	11: ["8a6a7a", "5a4050", "2e2030", "6e5060"],    # last trestle
	12: ["7ac24e", "7a5a3a", "3e2e20", "8a6a48"],    # farm
	13: ["9a8a7a", "5e5248", "2e2824", "7a6e62"],    # rail yard
	14: ["86c050", "6e5038", "36281c", "7e6046"],    # orchard
	15: ["a8b04a", "6a5a40", "34301e", "7a6e4a"],    # speedway
}


static func ground_colors(theme: int, time: String) -> Array:
	var g: Array = GROUND.get(theme, GROUND[0])
	var out := []
	for c in g:
		var col := Color.html(c)
		if time == "night":
			col = col.darkened(0.45).lerp(Color("1a2040"), 0.25)
		elif time == "dusk":
			col = col.darkened(0.12).lerp(Color("5a2a52"), 0.12)
		out.append(col)
	return out


static func _h(n: float) -> float:
	var s := sin(n * 12.9898) * 43758.5453
	return s - floorf(s)


## The ground between left and right: a filled body under the surface points, a 3 px
## lip on top, specks of stone. pts: the drawn ground line (x ascending).
static func ground(ci: CanvasItem, pts: PackedVector2Array, left: float, right: float, bottom: float,
		cols: Array) -> void:
	if pts.size() < 2:
		return
	# Points needn't be evenly spaced (GAUNTLET's steps are vertical): find the
	# visible run by bisection.
	var i0 := maxi(_first_at(pts, left) - 1, 0)
	var i1 := mini(_first_at(pts, right) + 1, pts.size() - 1)
	if i1 <= i0:
		return
	# Body in vertical strips (cheap, and it never trips over a concave outline).
	for i in range(i0, i1):
		var a := pts[i]
		var b := pts[i + 1]
		# A vertical face (a GAUNTLET step) has no strip: zero width won't triangulate.
		if b.x - a.x < 0.05:
			continue
		var poly := PackedVector2Array([a, b, Vector2(b.x, bottom), Vector2(a.x, bottom)])
		ci.draw_colored_polygon(poly, cols[1])
		# A darker band further down.
		if maxf(a.y, b.y) + 26.0 < bottom:
			var d := PackedVector2Array([a + Vector2(0, 26), b + Vector2(0, 26), Vector2(b.x, bottom), Vector2(a.x, bottom)])
			ci.draw_colored_polygon(d, cols[2])
		# Lip.
		ci.draw_colored_polygon(PackedVector2Array([a, b, b + Vector2(0, 3), a + Vector2(0, 3)]), cols[0])
		# Specks.
		var hx := _h(a.x * 0.37)
		if hx > 0.55:
			var sx := floorf(a.x + hx * (b.x - a.x))
			var sy := floorf(lerpf(a.y, b.y, hx) + 7.0 + _h(a.x) * 14.0)
			ci.draw_rect(Rect2(sx, sy, 2, 1), cols[3])
		if hx < 0.12:
			var tx := floorf(a.x + 3.0)
			var ty := floorf(lerpf(a.y, b.y, 0.2)) - 1.0
			ci.draw_rect(Rect2(tx, ty, 1, 1), (cols[0] as Color).lightened(0.25))


## What grows on (or lies about) each theme's ground: "grass", "desert", "rock",
## "yard" (scrap and bolts) or "mine".
const DECOR := {0: "desert", 1: "desert", 2: "yard", 3: "rock", 4: "desert", 5: "mine", 6: "desert",
	7: "yard", 8: "grass", 9: "rock", 10: "desert", 11: "rock", 12: "grass", 13: "yard", 14: "grass",
	15: "grass"}


## Scenery standing on the ground, drawn before it so the ground hides the roots:
## trees and bushes (green themes), cacti and sage (desert), boulders, posts. Placed by
## a hash of x, so it's the same every ride.
static func backdrop_decor(ci: CanvasItem, pts: PackedVector2Array, left: float, right: float, theme: int,
		cols: Array, time: String) -> void:
	var kind: String = DECOR.get(theme, "rock")
	var shade := Color(0, 0, 0, 0.0)
	var night := time == "night"
	var x := floorf(left / 40.0) * 40.0
	while x < right + 40.0:
		var h := _h(x * 0.0173 + float(theme))
		var px := x + floorf(_h(x * 0.031) * 24.0)
		x += 40.0
		if h < 0.45:
			continue
		var gy := _y_at(pts, px)
		var gy2 := _y_at(pts, px + 6.0)
		if not is_finite(gy) or absf(gy2 - gy) > 4.0:
			continue
		var base := Vector2(floorf(px), floorf(gy) + 2.0)
		var leaf := (cols[0] as Color).darkened(0.25)
		var dark := (cols[2] as Color)
		match kind:
			"grass":
				if h > 0.8:
					# A tree: trunk and a round crown (or a pine on odd spots).
					var th := 10.0 + floorf(_h(px) * 8.0)
					ci.draw_rect(Rect2(base.x - 1, base.y - th, 2, th), dark)
					if _h(px * 3.3) > 0.5:
						for k in 3:
							var w := 7.0 - k * 2.0
							var yy := base.y - th - 2.0 + k * 4.0 - 8.0
							ci.draw_colored_polygon(PackedVector2Array([Vector2(base.x - w, yy + 7), Vector2(base.x + w, yy + 7),
								Vector2(base.x, yy - 1)]), leaf.darkened(0.15 * k))
					else:
						ci.draw_circle(base + Vector2(0, -th - 3), 6.0, leaf)
						ci.draw_circle(base + Vector2(-2, -th - 5), 3.0, leaf.lightened(0.12))
				else:
					ci.draw_circle(base + Vector2(0, -2), 3.0, leaf)
					ci.draw_circle(base + Vector2(3, -1), 2.0, leaf.darkened(0.1))
			"desert":
				if h > 0.78:
					var ch := 8.0 + floorf(_h(px) * 6.0)
					var cc := Color("5a8a4a").darkened(0.4 if night else 0.0)
					ci.draw_rect(Rect2(base.x - 1, base.y - ch, 3, ch), cc)
					ci.draw_rect(Rect2(base.x - 4, base.y - ch + 3, 3, 1), cc)
					ci.draw_rect(Rect2(base.x - 4, base.y - ch + 1, 1, 3), cc)
					ci.draw_rect(Rect2(base.x + 2, base.y - ch + 5, 3, 1), cc)
					ci.draw_rect(Rect2(base.x + 4, base.y - ch + 3, 1, 3), cc)
				else:
					var sc := Color("8a8a5a").darkened(0.4 if night else 0.1)
					ci.draw_circle(base + Vector2(0, -1), 2.5, sc)
					ci.draw_circle(base + Vector2(2, 0), 1.5, sc.darkened(0.1))
			"yard":
				if h > 0.75:
					# A post with a lamp or a sign plate.
					ci.draw_rect(Rect2(base.x, base.y - 14, 1, 14), Color("4a4a54"))
					ci.draw_rect(Rect2(base.x - 2, base.y - 15, 5, 2), Color("8a8a96") if not night else Color("ffd27a"))
				else:
					ci.draw_rect(Rect2(base.x - 3, base.y - 3, 6, 3), Color("6a4a3a").darkened(0.3 if night else 0.0))
					ci.draw_rect(Rect2(base.x - 2, base.y - 4, 3, 1), Color("8a5a42").darkened(0.3 if night else 0.0))
			_:
				var rc := (cols[3] as Color).darkened(0.1)
				var r := 2.0 + floorf(h * 3.0)
				ci.draw_circle(base + Vector2(0, -r * 0.5), r, rc)
				ci.draw_circle(base + Vector2(-r * 0.3, -r * 0.8), r * 0.4, rc.lightened(0.15))
				if kind == "mine" and h > 0.85:
					# A lantern on a stake.
					ci.draw_rect(Rect2(base.x + 5, base.y - 12, 1, 12), Color("4a3a2a"))
					ci.draw_rect(Rect2(base.x + 4, base.y - 14, 3, 3), Color("ffd27a"))
					ci.draw_circle(base + Vector2(5.5, -12.5), 5.0, Color(1.0, 0.85, 0.5, 0.15))


## Tufts and stones on the lip, drawn after the ground.
static func surface_decor(ci: CanvasItem, pts: PackedVector2Array, left: float, right: float, theme: int,
		cols: Array) -> void:
	var kind: String = DECOR.get(theme, "rock")
	var x := floorf(left / 12.0) * 12.0
	var tuft := (cols[0] as Color).lightened(0.18)
	while x < right:
		var h := _h(x * 0.071 + 3.0)
		var px := x + floorf(h * 8.0)
		x += 12.0
		if h < 0.5:
			continue
		var gy := _y_at(pts, px)
		var gy2 := _y_at(pts, px + 3.0)
		if not is_finite(gy) or absf(gy2 - gy) > 3.0:
			continue
		var p := Vector2(floorf(px), floorf(gy))
		if kind == "grass":
			ci.draw_rect(Rect2(p.x, p.y - 2, 1, 2), tuft)
			ci.draw_rect(Rect2(p.x + 2, p.y - 3, 1, 3), tuft)
			if h > 0.92:
				ci.draw_rect(Rect2(p.x + 1, p.y - 4, 1, 1), Color("f0d070"))
		elif h > 0.75:
			ci.draw_rect(Rect2(p.x, p.y - 1, 3, 2), (cols[3] as Color).lightened(0.1))


## The ground's height at x along a drawn line (INF past its ends).
static func _y_at(pts: PackedVector2Array, x: float) -> float:
	if pts.size() < 2 or x < pts[0].x or x > pts[pts.size() - 1].x:
		return INF
	var i := clampi(_first_at(pts, x), 1, pts.size() - 1)
	var a := pts[i - 1]
	var b := pts[i]
	if absf(b.x - a.x) < 0.001:
		return minf(a.y, b.y)
	return lerpf(a.y, b.y, (x - a.x) / (b.x - a.x))


## Index of the first point at or past x.
static func _first_at(pts: PackedVector2Array, x: float) -> int:
	var lo := 0
	var hi := pts.size() - 1
	while lo < hi:
		var mid := (lo + hi) >> 1
		if pts[mid].x < x:
			lo = mid + 1
		else:
			hi = mid
	return lo


## A trestle bridge: deck planks over X-braced bents down to the valley floor.
static func bridge(ci: CanvasItem, x0: float, x1: float, y: float, ground_at: Callable, th: Dictionary) -> void:
	var beam: Color = th.beam
	var dark: Color = th.beam_dark
	var bx := x0 + 4.0
	while bx < x1 - 2.0:
		var gy: float = ground_at.call(bx)
		if gy == INF or gy < y:
			gy = y + 60.0
		ci.draw_rect(Rect2(bx - 1, y + 2, 2, gy - y), beam)
		var nx := minf(bx + 32.0, x1 - 2.0)
		var ny: float = ground_at.call(nx)
		if ny == INF or ny < y:
			ny = y + 60.0
		var bot := minf(gy, ny)
		var yy := y + 4.0
		while yy + 20.0 < bot:
			ci.draw_line(Vector2(bx, yy), Vector2(nx, yy + 20.0), dark, -1.0)
			ci.draw_line(Vector2(nx, yy), Vector2(bx, yy + 20.0), dark, -1.0)
			yy += 20.0
		bx += 32.0
	ci.draw_rect(Rect2(x0, y, x1 - x0, 4), th.deck)
	ci.draw_rect(Rect2(x0, y, x1 - x0, 1), th.deck_hi)
	var px := x0
	while px < x1:
		ci.draw_rect(Rect2(px, y + 3, 1, 1), th.beam_dark)
		px += 6.0


## A pit under a kicker gap: a dark shaft with a warning post at the lip.
static func pit(ci: CanvasItem, x0: float, x1: float, lip_y: float, cols: Array) -> void:
	ci.draw_rect(Rect2(x0, lip_y + 4, x1 - x0, 300), (cols[2] as Color).darkened(0.5))
	ci.draw_rect(Rect2(x0 - 1, lip_y - 9, 1, 9), Color("d8d8d8"))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(x0, lip_y - 9), Vector2(x0 + 5, lip_y - 7), Vector2(x0, lip_y - 5)]),
		Color("f0c040"))


## Fuel can (red jerry can) or, for the electric bikes, a charge point (battery).
static func fuel(ci: CanvasItem, p: Vector2, electric: bool, t: float) -> void:
	var bob := floorf(sin(t * 3.0 + p.x * 0.01) * 1.5)
	var q := p + Vector2(0, bob)
	if electric:
		ci.draw_rect(Rect2(q.x - 4, q.y - 6, 8, 11), Color("2a2f3a"))
		ci.draw_rect(Rect2(q.x - 2, q.y - 8, 4, 2), Color("2a2f3a"))
		ci.draw_rect(Rect2(q.x - 3, q.y - 5, 6, 9), Color("4ad06a"))
		ci.draw_colored_polygon(PackedVector2Array([q + Vector2(0, -4), q + Vector2(-2, 0), q + Vector2(0, 0),
			q + Vector2(-1, 3), q + Vector2(2, -1), q + Vector2(0, -1)]), Color("ffffff"))
	else:
		ci.draw_rect(Rect2(q.x - 4, q.y - 5, 8, 10), Color("c8323c"))
		ci.draw_rect(Rect2(q.x - 3, q.y - 4, 6, 1), Color("e85a5a"))
		ci.draw_rect(Rect2(q.x + 1, q.y - 7, 3, 2), Color("2a2a2e"))
		ci.draw_line(q + Vector2(-3, -2), q + Vector2(3, 4), Color("8a1c24"), -1.0)
		ci.draw_line(q + Vector2(3, -2), q + Vector2(-3, 4), Color("8a1c24"), -1.0)
	# Glow ring so it reads at speed.
	ci.draw_arc(q, 9.0, 0.0, TAU, 14, Color(1, 1, 0.8, 0.18 + 0.1 * sin(t * 4.0)), 1.0)


## Distance post every 100 m: a little sign with the metres on it.
static func post(ci: CanvasItem, x: float, y: float, m: int, font: Font) -> void:
	var s := "%dM" % m
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x if font else 24.0
	ci.draw_rect(Rect2(x, y - 16, 1, 16), Color("d8d0c0"))
	ci.draw_rect(Rect2(x - w * 0.5 - 2, y - 27, w + 4, 11), Color("f4ecd8"))
	ci.draw_rect(Rect2(x - w * 0.5 - 2, y - 27, w + 4, 1), Color("c8323c"))
	if font:
		ci.draw_string(font, Vector2(roundf(x - w * 0.5), y - 18), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("2a2230"))


## Summit flag: a tall pole with a chequered flag that waves.
static func summit_flag(ci: CanvasItem, x: float, y: float, t: float) -> void:
	ci.draw_rect(Rect2(x, y - 40, 2, 40), Color("e8e2d0"))
	for i in 4:
		for j in 3:
			var wave := sin(t * 5.0 + i * 0.8) * 1.2
			var c := Color("f4f4f4") if (i + j) % 2 == 0 else Color("1a1a1a")
			ci.draw_rect(Rect2(x + 2 + i * 4, y - 40 + j * 4 + wave, 4, 4), c)
	ci.draw_circle(Vector2(x + 1, y - 41), 1.5, Color("f0c040"))


## Checkpoint: two posts with a banner; lit once reached.
static func checkpoint(ci: CanvasItem, x: float, y: float, lit: bool, t: float) -> void:
	var c := Color("5bd16a") if lit else Color("d8d0c0")
	ci.draw_rect(Rect2(x - 1, y - 26, 2, 26), c)
	var f := Color("5bd16a") if lit else Color("f0c040")
	var wave := sin(t * 4.0) * 1.0
	ci.draw_colored_polygon(PackedVector2Array([Vector2(x + 1, y - 26), Vector2(x + 10, y - 23 + wave),
		Vector2(x + 1, y - 20)]), f)


## GAUNTLET props: crates, logs (circles), steel plates.
static func crate(ci: CanvasItem, r: Rect2) -> void:
	ci.draw_rect(r, Color("8a5a32"))
	ci.draw_rect(r.grow(-1.0), Color("b07a48"))
	ci.draw_line(r.position + Vector2(1, 1), r.end - Vector2(1, 1), Color("6b4428"), -1.0)
	ci.draw_line(Vector2(r.position.x + 1, r.end.y - 1), Vector2(r.end.x - 1, r.position.y + 1), Color("6b4428"), -1.0)
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), Color("d09a62"))


static func log_end(ci: CanvasItem, c: Vector2, r: float) -> void:
	ci.draw_circle(c, r, Color("6b4428"))
	ci.draw_circle(c, r - 1.5, Color("c89a62"))
	ci.draw_arc(c, r * 0.55, 0.0, TAU, 12, Color("a87a48"), 1.0)
	ci.draw_circle(c, 1.0, Color("8a5a32"))


static func steel(ci: CanvasItem, pts: PackedVector2Array) -> void:
	ci.draw_colored_polygon(pts, Color("5a6270"))
	for i in pts.size():
		ci.draw_line(pts[i], pts[(i + 1) % pts.size()], Color("9aa3ad"), -1.0)
