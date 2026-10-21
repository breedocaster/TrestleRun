## Per-trail art: how each trail builds its track (posts, arches, girders, rails...)
## and which enemy skins it uses. Hitboxes never change with the skin.
extends RefCounted

const Phys := preload("res://scripts/game/bike_physics.gd")

const STEEL := Color("4a4f5c")
const STEEL_HI := Color("9aa3ad")
const HAZARD := Color("f0c040")

## Indexed by Backdrop theme (one per trail).
const STYLES := [
	{"track": "wood", "crawler": "beetle", "spiker": "cactus", "drone": "vulture"},     # Dusty Trail
	{"track": "stone", "crawler": "scorpion", "spiker": "cactus", "drone": "vulture"},  # Copper Canyon
	{"track": "girder", "crawler": "rustbot", "spiker": "mine", "drone": "drone"},      # Rustyard
	{"track": "truss", "crawler": "beetle", "spiker": "urchin", "drone": "bat"},        # Night Trestle
	{"track": "adobe", "crawler": "beetle", "spiker": "cactus", "drone": "vulture"},    # Mesa Springs
	{"track": "mine", "crawler": "mole", "spiker": "crystal", "drone": "bat"},          # Lantern Mine
	{"track": "rock", "crawler": "scorpion", "spiker": "cactus", "drone": "vulture"},   # Hoodoo Loops
	{"track": "catwalk", "crawler": "rustbot", "spiker": "mine", "drone": "drone"},     # Hoist Yard
	{"track": "log", "crawler": "marmot", "spiker": "ice", "drone": "owl"},             # Skyline Pass
	{"track": "scaffold", "crawler": "mole", "spiker": "tnt", "drone": "vulture"},      # Quarry Cliffs
	{"track": "launch", "crawler": "rustbot", "spiker": "mine", "drone": "drone"},      # Rocket Ridge
	{"track": "wood", "crawler": "beetle", "spiker": "urchin", "drone": "bat"},         # Last Trestle
	# Story mode: the aliens' critters (gloops, spore pods, probes) all over the county.
	{"track": "farm", "crawler": "gloop", "spiker": "thistle", "drone": "probe", "rope": "beam"},       # Grandma's Farm
	{"track": "railbed", "crawler": "gloop", "spiker": "spore", "drone": "probe", "rope": "crane"},     # Rail Yard
	{"track": "stump", "crawler": "gloop", "spiker": "spore", "drone": "probe", "rope": "branch"},      # Old Orchard
	{"track": "bleacher", "crawler": "gloop", "spiker": "spore", "drone": "probe", "rope": "crane", "wall": "drome"},  # Speedway
]


static func style(theme_index: int) -> Dictionary:
	return STYLES[clampi(theme_index, 0, STYLES.size() - 1)]


static func _h(n: float) -> float:
	var s := sin(n * 12.9898) * 43758.5453
	return s - floorf(s)


# --- tracks -----------------------------------------------------------------------

## Supports first (behind every deck in the lane), then the decks.
## idx: only these track indices (the world passes the ones near the view); [] = all.
static func draw_tracks(ci: CanvasItem, tracks: Array, lane: int, left: float, right: float,
		bottom: float, th: Dictionary, st: Dictionary, t: float, sim_t: float, night: bool, idx: Array = []) -> void:
	var kind: String = st.track
	var list: Array = tracks if idx.is_empty() else idx.map(func(i): return tracks[i])
	for tr in list:
		if int(tr.get("lane", 0)) != lane or tr.x1 < left or tr.x0 > right or tr.has("lift") \
				or tr.has("crumble") or tr.get("no_supports", false):
			continue
		_supports(ci, tr, left, right, bottom, th, kind)
	for tr in list:
		if int(tr.get("lane", 0)) != lane or tr.x1 < left or tr.x0 > right or tr.has("crumble") or tr.has("hold"):
			continue
		if tr.has("lift"):
			_lift(ci, tr, Phys.lift_dy(tr, sim_t), th, bottom, t)
			continue
		_deck(ci, tr, left, right, th, kind, t, night)


## Grind rails (a steel pipe on posts) and wall-rides (a curved board wall). The one
## you're on glows, so you can see it only holds while you hold.
static func draw_holds(ci: CanvasItem, tracks: Array, lane: int, left: float, right: float, bottom: float,
		th: Dictionary, st: Dictionary, t: float, active: int, idx: Array = []) -> void:
	for ti in (range(tracks.size()) if idx.is_empty() else idx):
		var tr: Dictionary = tracks[ti]
		if not tr.has("hold") or int(tr.get("lane", 0)) != lane or tr.x1 < left or tr.x0 > right:
			continue
		var on: bool = ti == active
		if String(tr.hold) == "wall":
			_wall_ride(ci, tr, bottom, th, st, t, on)
		else:
			_rail(ci, tr, bottom, th, t, on)


static func _rail(ci: CanvasItem, tr: Dictionary, bottom: float, th: Dictionary, t: float, on: bool) -> void:
	var pts: PackedVector2Array = tr.pts
	var a := pts[0]
	var b := pts[pts.size() - 1]
	# Posts every 40 px down out of sight, angled braces.
	var px := ceilf((a.x + 6.0) / 40.0) * 40.0
	while px < b.x - 4.0:
		var py := Phys.height_at(tr, px)
		ci.draw_rect(Rect2(px - 1, py + 2, 2, bottom - py), STEEL)
		ci.draw_rect(Rect2(px - 1, py + 2, 1, bottom - py), STEEL_HI.darkened(0.3))
		px += 40.0
	ci.draw_rect(Rect2(a.x - 2, a.y - 1, 3, bottom - a.y), STEEL)
	ci.draw_rect(Rect2(b.x - 1, b.y - 1, 3, bottom - b.y), STEEL)
	# The pipe: dark underside, bright top, end caps.
	var glow := 0.5 + 0.5 * sin(t * 6.0)
	ci.draw_line(a + Vector2(0, 2), b + Vector2(0, 2), Color("2a2d36"), 2.0)
	ci.draw_line(a, b, Color("c9d1d9"), 2.0)
	ci.draw_line(a + Vector2(0, -1), b + Vector2(0, -1), Color(1, 1, 1, 0.8), -1.0)
	# Chevrons along the rail mark it as a grind rail (hold to ride).
	var n := int((b.x - a.x) / 24.0)
	for i in n:
		var u := (i + 0.5) / float(n)
		var c := a.lerp(b, u)
		var col := Color(0.55, 0.9, 1.0, (0.9 if on else 0.35 + 0.25 * glow))
		ci.draw_line(c + Vector2(-2, 3), c + Vector2(0, 5), col, -1.0)
		ci.draw_line(c + Vector2(0, 5), c + Vector2(2, 3), col, -1.0)
	for e in [a, b]:
		ci.draw_rect(Rect2(e.x - 2, e.y - 2, 4, 4), Color("e04848"))
	if on:
		ci.draw_line(a + Vector2(0, -2), b + Vector2(0, -2), Color(0.6, 0.95, 1.0, 0.35), 3.0)


static func _wall_ride(ci: CanvasItem, tr: Dictionary, bottom: float, th: Dictionary, st: Dictionary, t: float, on: bool) -> void:
	var pts: PackedVector2Array = tr.pts
	var drome := String(st.get("wall", "boards")) == "drome"
	var board: Color = Color("c08a4a") if drome else th.deck
	var dark: Color = Color("6b3f2a") if drome else th.beam_dark
	var hi: Color = Color("f0c27a") if drome else th.deck_hi
	# A curved wall of boards: the riding band, then the wall face falling away under it
	# and posts holding it up.
	var depth := 12.0
	for i in pts.size() - 1:
		var p0 := pts[i]
		var p1 := pts[i + 1]
		ci.draw_colored_polygon(PackedVector2Array([p0, p1, p1 + Vector2(0, depth), p0 + Vector2(0, depth)]), board.darkened(0.15))
		ci.draw_colored_polygon(PackedVector2Array([p0, p1, p1 + Vector2(0, 6), p0 + Vector2(0, 6)]), board)
		ci.draw_line(p0, p1, hi, -1.0)
		ci.draw_line(p0 + Vector2(0, depth), p1 + Vector2(0, depth), dark, -1.0)
		if i % 2 == 0:
			ci.draw_line(p0 + Vector2(0, 6), p0 + Vector2(0, depth), dark, -1.0)
		if i % 3 == 0:
			ci.draw_rect(Rect2(p0.x - 1, p0.y + depth, 3, bottom - p0.y - depth), Color(th.beam, 0.9))
	if drome:
		# Motordrome stripe and a row of bulbs along the top.
		for i in pts.size() - 1:
			ci.draw_line(pts[i] + Vector2(0, 12), pts[i + 1] + Vector2(0, 12), Color("c8323c"), 2.0)
			if i % 2 == 0:
				var lit := int(t * 6.0 + i) % 3 == 0
				ci.draw_rect(Rect2(pts[i].x, pts[i].y + 16, 2, 2), Color("fff1a8") if lit else Color("7a6a4a"))
	var glow := 0.5 + 0.5 * sin(t * 6.0)
	var band := Color(0.55, 0.9, 1.0, 0.85 if on else 0.3 + 0.25 * glow)
	for i in range(0, pts.size() - 1, 2):
		ci.draw_line(pts[i] + Vector2(0, 3), pts[i + 1] + Vector2(0, 3), band, -1.0)


static func _span(tr: Dictionary, left: float, right: float, step: float, inset := 4.0) -> Array:
	var out := []
	var px := ceilf(maxf(tr.x0 + inset, left) / step) * step
	var stop := minf(tr.x1 - inset, right)
	while px <= stop:
		out.append(px)
		px += step
	return out


static func _supports(ci: CanvasItem, tr: Dictionary, left: float, right: float, bottom: float,
		th: Dictionary, kind: String) -> void:
	var beam: Color = th.beam
	var brace: Color = th.beam_dark
	match kind:
		"stone":
			# Masonry piers with arches between them.
			for px: float in _span(tr, left - 96.0, right, 96.0, 6.0):
				var ty := Phys.height_at(tr, px)
				ci.draw_rect(Rect2(px - 6, ty + 5, 12, bottom - ty), beam)
				ci.draw_rect(Rect2(px - 6, ty + 5, 2, bottom - ty), brace)
				var yy := ty + 14.0
				while yy < bottom:
					ci.draw_line(Vector2(px - 6, yy), Vector2(px + 6, yy), brace, -1.0)
					yy += 9.0
				var bx := px + 96.0
				if bx <= tr.x1 - 6.0:
					var ty2 := Phys.height_at(tr, bx)
					var poly := PackedVector2Array([Vector2(px + 6, ty + 5), Vector2(bx - 6, ty2 + 5)])
					var arc := PackedVector2Array()
					for k in 9:
						var u := float(k) / 8.0
						var ax := lerpf(px + 6, bx - 6, u)
						arc.append(Vector2(ax, lerpf(ty, ty2, u) + 30.0 - 20.0 * sin(PI * u)))
					for k in range(arc.size() - 1, -1, -1):
						poly.append(arc[k])
					ci.draw_colored_polygon(poly, beam)
					for k in arc.size() - 1:
						ci.draw_line(arc[k], arc[k + 1], brace, -1.0)
		"girder":
			# Rusty steel columns with a lattice girder under the deck.
			for px: float in _span(tr, left, right, 64.0):
				var ty := Phys.height_at(tr, px)
				ci.draw_rect(Rect2(px - 2, ty + 6, 5, bottom - ty), beam)
				ci.draw_rect(Rect2(px - 3, ty + 6, 7, 1), brace)
				ci.draw_rect(Rect2(px, ty + 6, 1, bottom - ty), brace)
			for px: float in _span(tr, left, right, 16.0, 2.0):
				var ty := Phys.height_at(tr, px)
				var up := int(px / 16.0) % 2 == 0
				ci.draw_line(Vector2(px, ty + (6.0 if up else 20.0)), Vector2(px + 16, ty + (20.0 if up else 6.0)), beam, -1.0)
				ci.draw_line(Vector2(px, ty + 20), Vector2(px + 16, ty + 20), brace, -1.0)
		"truss":
			# Slim steel towers, double cross-braced.
			for px: float in _span(tr, left, right, 48.0):
				var ty := Phys.height_at(tr, px)
				ci.draw_rect(Rect2(px - 1, ty + 5, 2, bottom - ty), beam)
				if px + 48.0 <= tr.x1:
					var ty2 := Phys.height_at(tr, px + 48.0)
					for d in [8.0, 30.0]:
						ci.draw_line(Vector2(px, ty + d), Vector2(px + 48, ty2 + d + 22), brace, -1.0)
						ci.draw_line(Vector2(px + 48, ty2 + d), Vector2(px, ty + d + 22), brace, -1.0)
		"adobe":
			# Fat plastered piers with rounded shoulders and wooden vigas.
			for px: float in _span(tr, left, right, 80.0, 8.0):
				var ty := Phys.height_at(tr, px)
				ci.draw_rect(Rect2(px - 8, ty + 9, 16, bottom - ty), beam)
				ci.draw_circle(Vector2(px, ty + 10), 8.0, beam)
				ci.draw_rect(Rect2(px - 8, ty + 9, 2, bottom - ty), brace)
			for px: float in _span(tr, left, right, 24.0, 3.0):
				var ty := Phys.height_at(tr, px)
				ci.draw_rect(Rect2(px - 1, ty + 6, 3, 3), Color("6a4228"))
		"mine":
			# Timber cribbing: stacked logs, alternately offset.
			for px: float in _span(tr, left, right, 64.0, 8.0):
				var ty := Phys.height_at(tr, px)
				var yy := ty + 6.0
				var k := 0
				while yy < bottom:
					var off := 2.0 if k % 2 == 0 else -2.0
					ci.draw_rect(Rect2(px - 7 + off, yy, 14, 3), beam)
					ci.draw_rect(Rect2(px - 7 + off, yy + 2, 14, 1), brace)
					yy += 4.0
					k += 1
				if px + 64.0 <= tr.x1:
					var ty2 := Phys.height_at(tr, px + 64.0)
					ci.draw_line(Vector2(px + 7, ty + 8), Vector2(px + 57, ty2 + 34), brace, 2.0)
		"rock":
			# Natural rock columns of uneven width.
			for px: float in _span(tr, left - 90.0, right, 88.0, 10.0):
				var ty := Phys.height_at(tr, px)
				var w := 10.0 + 8.0 * _h(px * 0.13)
				var poly := PackedVector2Array([Vector2(px - w * 0.6, ty + 5), Vector2(px + w * 0.6, ty + 5),
					Vector2(px + w * 0.5, ty + 30), Vector2(px + w * 0.8, ty + 60), Vector2(px + w * 0.6, bottom),
					Vector2(px - w * 0.7, bottom), Vector2(px - w * 0.9, ty + 50), Vector2(px - w * 0.5, ty + 22)])
				ci.draw_colored_polygon(poly, beam)
				ci.draw_line(Vector2(px - w * 0.2, ty + 14), Vector2(px + w * 0.1, ty + 40), brace, -1.0)
				ci.draw_line(Vector2(px - w * 0.5, ty + 48), Vector2(px + w * 0.3, ty + 70), brace, -1.0)
		"catwalk":
			# Thin I-beam legs, light X-bracing.
			for px: float in _span(tr, left, right, 56.0):
				var ty := Phys.height_at(tr, px)
				ci.draw_rect(Rect2(px - 2, ty + 7, 1, bottom - ty), beam)
				ci.draw_rect(Rect2(px + 1, ty + 7, 1, bottom - ty), beam)
				if px + 56.0 <= tr.x1:
					var ty2 := Phys.height_at(tr, px + 56.0)
					ci.draw_line(Vector2(px, ty + 10), Vector2(px + 56, ty2 + 40), brace, -1.0)
					ci.draw_line(Vector2(px + 56, ty2 + 10), Vector2(px, ty + 40), brace, -1.0)
		"log":
			# Log trestle: upright logs and crossed braces.
			for px: float in _span(tr, left, right, 40.0):
				var ty := Phys.height_at(tr, px)
				ci.draw_rect(Rect2(px - 2, ty + 5, 4, bottom - ty), beam)
				ci.draw_rect(Rect2(px - 2, ty + 5, 1, bottom - ty), brace)
				if px + 40.0 <= tr.x1:
					var ty2 := Phys.height_at(tr, px + 40.0)
					ci.draw_line(Vector2(px, ty + 10), Vector2(px + 40, ty2 + 34), beam, 2.0)
					ci.draw_line(Vector2(px + 40, ty2 + 10), Vector2(px, ty + 34), beam, 2.0)
		"scaffold":
			# Quarry scaffolding: poles, ledger boards every 22 px, a diagonal every other bay.
			for px: float in _span(tr, left, right, 30.0):
				var ty := Phys.height_at(tr, px)
				ci.draw_rect(Rect2(px - 1, ty + 4, 2, bottom - ty), beam)
				if px + 30.0 <= tr.x1:
					var ty2 := Phys.height_at(tr, px + 30.0)
					var yy := 18.0
					while ty + yy < bottom:
						ci.draw_line(Vector2(px, ty + yy), Vector2(px + 30, ty2 + yy), brace, -1.0)
						yy += 22.0
					if int(px / 30.0) % 2 == 0:
						ci.draw_line(Vector2(px, ty + 18), Vector2(px + 30, ty2 + 40), Color(brace, 0.8), -1.0)
		"farm":
			# Square timber posts with knee braces, every 48 px.
			for px: float in _span(tr, left, right, 48.0):
				var ty := Phys.height_at(tr, px)
				ci.draw_rect(Rect2(px - 2, ty + 4, 4, bottom - ty), beam)
				ci.draw_rect(Rect2(px - 2, ty + 4, 1, bottom - ty), beam.lightened(0.15))
				ci.draw_line(Vector2(px - 12, ty + 5), Vector2(px - 2, ty + 15), brace, 2.0)
				ci.draw_line(Vector2(px + 12, ty + 5), Vector2(px + 2, ty + 15), brace, 2.0)
		"railbed":
			# Concrete piers under a plate girder.
			for px: float in _span(tr, left - 80.0, right, 80.0, 10.0):
				var ty := Phys.height_at(tr, px)
				var pier := Color("8a8a84").lerp(th.mid, 0.35)
				ci.draw_rect(Rect2(px - 7, ty + 14, 14, bottom - ty), pier)
				ci.draw_rect(Rect2(px - 7, ty + 14, 2, bottom - ty), pier.darkened(0.25))
				ci.draw_rect(Rect2(px - 9, ty + 12, 18, 3), pier.lightened(0.1))
			for px: float in _span(tr, left, right, 8.0, 2.0):
				var ty := Phys.height_at(tr, px)
				ci.draw_rect(Rect2(px, ty + 6, 8, 7), beam)
				ci.draw_rect(Rect2(px, ty + 12, 8, 1), brace)
				if int(px / 8.0) % 3 == 0:
					ci.draw_rect(Rect2(px + 3, ty + 8, 1, 1), STEEL_HI)
		"stump":
			# Old log posts and a split-rail brace.
			for px: float in _span(tr, left, right, 44.0):
				var ty := Phys.height_at(tr, px)
				ci.draw_rect(Rect2(px - 3, ty + 4, 6, bottom - ty), beam)
				ci.draw_rect(Rect2(px - 3, ty + 4, 2, bottom - ty), brace)
				var yy := ty + 16.0
				while yy < bottom:
					ci.draw_line(Vector2(px - 3, yy), Vector2(px + 3, yy + 2), brace, -1.0)
					yy += 14.0
				if px + 44.0 <= tr.x1:
					var ty2 := Phys.height_at(tr, px + 44.0)
					ci.draw_line(Vector2(px, ty + 24), Vector2(px + 44, ty2 + 24), beam, 2.0)
		"bleacher":
			# Red steel bleacher frame: verticals and stepped diagonals.
			for px: float in _span(tr, left, right, 36.0):
				var ty := Phys.height_at(tr, px)
				ci.draw_rect(Rect2(px - 1, ty + 5, 3, bottom - ty), beam)
				if px + 36.0 <= tr.x1:
					var ty2 := Phys.height_at(tr, px + 36.0)
					ci.draw_line(Vector2(px, ty + 8), Vector2(px + 36, ty2 + 40), brace, 2.0)
					ci.draw_line(Vector2(px, ty + 22), Vector2(px + 36, ty2 + 22), Color(brace, 0.8), -1.0)
		"launch":
			# White lattice towers, two legs with X bracing, every 64 px.
			for px: float in _span(tr, left, right, 64.0):
				var ty := Phys.height_at(tr, px)
				var white := Color("d8dce2").lerp(beam, 0.25)
				ci.draw_rect(Rect2(px - 6, ty + 6, 2, bottom - ty), white)
				ci.draw_rect(Rect2(px + 4, ty + 6, 2, bottom - ty), white)
				var yy := 10.0
				while ty + yy < bottom:
					ci.draw_line(Vector2(px - 5, ty + yy), Vector2(px + 5, ty + yy + 10), Color(white, 0.8), -1.0)
					ci.draw_line(Vector2(px + 5, ty + yy), Vector2(px - 5, ty + yy + 10), Color(white, 0.8), -1.0)
					yy += 10.0
		_:
			# Wooden trestle.
			for px: float in _span(tr, left, right, 32.0):
				var ty := Phys.height_at(tr, px)
				ci.draw_rect(Rect2(px - 1, ty + 4, 3, bottom - ty), beam)
				if px + 32.0 <= tr.x1:
					var ty2 := Phys.height_at(tr, px + 32.0)
					ci.draw_line(Vector2(px, ty + 8), Vector2(px + 32, ty2 + 28), brace, -1.0)
					ci.draw_line(Vector2(px + 32, ty2 + 8), Vector2(px, ty + 28), brace, -1.0)
					ci.draw_line(Vector2(px, ty + 28), Vector2(px + 32, ty2 + 28), brace, -1.0)


static func _deck(ci: CanvasItem, tr: Dictionary, left: float, right: float, th: Dictionary,
		kind: String, t: float, night: bool) -> void:
	var deck: Color = th.deck
	var hi: Color = th.deck_hi
	var brace: Color = th.beam_dark
	var pts: PackedVector2Array = tr.pts
	var thick := 5.0
	match kind:
		"stone", "adobe", "girder":
			thick = 6.0
		"mine", "catwalk":
			thick = 4.0
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		if b.x < left or a.x > right:
			continue
		if a.x < left:  # clipped (the collapse chase cuts the trestle off behind you)
			a = a.lerp(b, (left - a.x) / (b.x - a.x))
		var dn := Vector2(0, thick)
		ci.draw_colored_polygon(PackedVector2Array([a, b, b + dn, a + dn]), deck)
		ci.draw_line(a + dn, b + dn, brace, -1.0)
		var x0 := maxf(a.x, left)
		var x1 := minf(b.x, right)
		var k := (b.y - a.y) / (b.x - a.x)
		match kind:
			"stone":
				ci.draw_line(a, b, hi, -1.0)
				var rx := ceilf(x0 / 16.0) * 16.0
				while rx < x1:
					var ry := a.y + k * (rx - a.x)
					ci.draw_line(Vector2(rx, ry + 1), Vector2(rx, ry + 5), brace, -1.0)
					rx += 16.0
			"girder":
				ci.draw_line(a, b, hi, -1.0)
				ci.draw_line(a + Vector2(0, 1), b + Vector2(0, 1), hi.darkened(0.25), -1.0)
				var rx := ceilf(x0 / 8.0) * 8.0
				while rx < x1:
					var ry := a.y + k * (rx - a.x)
					ci.draw_rect(Rect2(rx, ry + 3, 1, 1), hi)
					if _h(rx * 0.37) < 0.18:
						ci.draw_rect(Rect2(rx + 2, ry + 4, 2, 2), Color("8a3a1a"))
					rx += 8.0
			"truss":
				ci.draw_line(a, b, hi, -1.0)
				# Low guard rail, and a lamp post every 160 px.
				var rx := ceilf(x0 / 24.0) * 24.0
				while rx < x1:
					var ry := a.y + k * (rx - a.x)
					ci.draw_line(Vector2(rx, ry), Vector2(rx, ry - 5), brace.lightened(0.15), -1.0)
					if int(rx) % 168 == 0:
						ci.draw_rect(Rect2(rx, ry - 20, 1, 20), STEEL)
						ci.draw_rect(Rect2(rx - 1, ry - 22, 4, 2), STEEL_HI)
						if night:
							ci.draw_circle(Vector2(rx + 1, ry - 18), 10.0, Color(1.0, 0.85, 0.5, 0.12))
						ci.draw_rect(Rect2(rx, ry - 20, 2, 1), Color(1.0, 0.9, 0.6, 1.0 if night else 0.6))
					rx += 24.0
				ci.draw_line(a + Vector2(0, -5), b + Vector2(0, -5), Color(brace.lightened(0.15), 0.7), -1.0)
			"adobe":
				ci.draw_line(a, b, hi, -1.0)
				var rx := ceilf(x0 / 6.0) * 6.0
				while rx < x1:
					var ry := a.y + k * (rx - a.x)
					ci.draw_rect(Rect2(rx, ry + 1, 4, 1), hi.darkened(0.12))
					rx += 6.0
			"mine":
				# Sleepers with a steel rail on top.
				var rx := ceilf(x0 / 6.0) * 6.0
				while rx < x1:
					var ry := a.y + k * (rx - a.x)
					ci.draw_rect(Rect2(rx, ry, 3, 4), th.beam)
					rx += 6.0
				ci.draw_line(a, b, STEEL_HI, -1.0)
				ci.draw_line(a + Vector2(0, 1), b + Vector2(0, 1), STEEL, -1.0)
			"scaffold":
				# Scaffold boards with a toe board and a rail on posts.
				ci.draw_line(a, b, hi, -1.0)
				var rx := ceilf(x0 / 10.0) * 10.0
				while rx < x1:
					var ry := a.y + k * (rx - a.x)
					ci.draw_rect(Rect2(rx, ry + 1, 1, 3), brace)
					if int(rx) % 60 == 0:
						ci.draw_rect(Rect2(rx, ry - 9, 1, 9), th.beam)
					rx += 10.0
				ci.draw_line(a + Vector2(0, -9), b + Vector2(0, -9), Color(th.beam, 0.8), -1.0)
			"farm":
				# Planks with a white rail fence along the far edge.
				ci.draw_line(a, b, hi, -1.0)
				var rx := ceilf(x0 / 9.0) * 9.0
				while rx < x1:
					var ry := a.y + k * (rx - a.x)
					ci.draw_rect(Rect2(rx, ry + 1, 1, 3), brace)
					if int(rx) % 36 == 0:
						ci.draw_rect(Rect2(rx, ry - 9, 2, 9), Color("ece6d6"))
					rx += 9.0
				ci.draw_line(a + Vector2(0, -8), b + Vector2(0, -8), Color("ece6d6"), -1.0)
				ci.draw_line(a + Vector2(0, -4), b + Vector2(0, -4), Color(Color("ece6d6"), 0.8), -1.0)
			"railbed":
				# Ties with two steel rails on top.
				var rx := ceilf(x0 / 5.0) * 5.0
				while rx < x1:
					var ry := a.y + k * (rx - a.x)
					ci.draw_rect(Rect2(rx, ry + 1, 3, 4), th.deck)
					ci.draw_rect(Rect2(rx, ry + 1, 3, 1), hi.darkened(0.2))
					rx += 5.0
				ci.draw_line(a + Vector2(0, -1), b + Vector2(0, -1), STEEL_HI, -1.0)
				ci.draw_line(a, b, STEEL, -1.0)
			"stump":
				# Rough boardwalk planks of uneven tone.
				var rx := ceilf(x0 / 7.0) * 7.0
				while rx < x1:
					var ry := a.y + k * (rx - a.x)
					var tone := 0.08 * _h(rx * 0.21)
					ci.draw_rect(Rect2(rx, ry, 6, 4), (th.deck as Color).darkened(tone))
					ci.draw_rect(Rect2(rx, ry, 6, 1), hi.darkened(tone))
					rx += 7.0
			"bleacher":
				# White boards with a red kick plate.
				ci.draw_line(a, b, hi, -1.0)
				ci.draw_line(a + Vector2(0, 3), b + Vector2(0, 3), Color("c8323c"), 2.0)
				var rx := ceilf(x0 / 12.0) * 12.0
				while rx < x1:
					var ry := a.y + k * (rx - a.x)
					ci.draw_rect(Rect2(rx, ry + 1, 1, 2), (th.deck as Color).darkened(0.25))
					rx += 12.0
			"launch":
				# Steel grating with a red and white edge.
				ci.draw_line(a, b, Color("f4f6f8"), -1.0)
				var rx := ceilf(x0 / 6.0) * 6.0
				while rx < x1:
					var ry := a.y + k * (rx - a.x)
					ci.draw_rect(Rect2(rx, ry + 2, 1, 1), STEEL)
					ci.draw_rect(Rect2(rx, ry + 4, 6, 1), Color("e04848") if int(rx / 6.0) % 2 == 0 else Color("f4f6f8"))
					rx += 6.0
			"catwalk":
				ci.draw_line(a, b, STEEL_HI, -1.0)
				var rx := ceilf(x0 / 4.0) * 4.0
				while rx < x1:
					var ry := a.y + k * (rx - a.x)
					ci.draw_rect(Rect2(rx + (int(rx / 4.0) % 2), ry + 2, 1, 1), STEEL_HI)
					ci.draw_rect(Rect2(rx, ry + 4, 4, 2), HAZARD if int(rx / 4.0) % 2 == 0 else Color("1e1a1f"))
					rx += 4.0
			"log":
				var rx := ceilf(x0 / 6.0) * 6.0
				while rx < x1:
					var ry := a.y + k * (rx - a.x)
					ci.draw_circle(Vector2(rx + 3, ry + 3), 2.6, th.beam)
					ci.draw_circle(Vector2(rx + 3, ry + 3), 1.4, hi)
					rx += 6.0
				ci.draw_line(a + Vector2(0, -1), b + Vector2(0, -1), Color("f4f8fc"), -1.0)
				ci.draw_line(a, b, Color("dfe8f0"), -1.0)
				# Rope rail on posts.
				var px := ceilf(x0 / 40.0) * 40.0
				while px < x1:
					var py := a.y + k * (px - a.x)
					ci.draw_line(Vector2(px, py), Vector2(px, py - 8), th.beam, 2.0)
					if px + 40.0 < x1:
						var py2 := a.y + k * (px + 40.0 - a.x)
						var prev := Vector2(px, py - 7)
						for s in range(1, 5):
							var u := s / 4.0
							var q := Vector2(px + 40.0 * u, lerpf(py, py2, u) - 7.0 + 3.0 * sin(PI * u))
							ci.draw_line(prev, q, Color("c9b28a"), -1.0)
							prev = q
					px += 40.0
			_:
				ci.draw_line(a, b, hi, -1.0)
				var rx := ceilf(x0 / 8.0) * 8.0
				while rx < x1:
					var ry := a.y + k * (rx - a.x)
					ci.draw_rect(Rect2(rx, ry + 2, 1, 1), brace)
					rx += 8.0
	var s := pts[0]
	var e := pts[pts.size() - 1]
	ci.draw_rect(Rect2(s.x - 1, s.y - 1, 3, thick + 2), brace)
	ci.draw_rect(Rect2(e.x - 2, e.y - 1, 3, thick + 2), brace)


static func _lift(ci: CanvasItem, tr: Dictionary, dy: float, th: Dictionary, bottom: float, t: float) -> void:
	var x0: float = tr.x0
	var x1: float = tr.x1
	var y: float = Phys.height_at(tr, x0) + dy
	var mid := (x0 + x1) * 0.5
	ci.draw_rect(Rect2(mid - 5, y + 9, 10, bottom - y), STEEL)
	ci.draw_rect(Rect2(mid - 3, y + 5, 6, bottom - y), STEEL_HI)
	ci.draw_rect(Rect2(x0, y, x1 - x0, 5), th.deck)
	ci.draw_line(Vector2(x0, y), Vector2(x1, y), th.deck_hi, -1.0)
	var sx := x0
	var k := 0
	while sx < x1:
		ci.draw_rect(Rect2(sx, y + 5, minf(6.0, x1 - sx), 3), HAZARD if k % 2 == 0 else Color("1e1a1f"))
		sx += 6.0
		k += 1
	var blink := 1.0 if int(t * 2.0) % 2 == 0 else 0.35
	ci.draw_rect(Rect2(x0 + 1, y + 6, 2, 1), Color(1.0, 0.3, 0.2, blink))
	ci.draw_rect(Rect2(x1 - 3, y + 6, 2, 1), Color(1.0, 0.3, 0.2, blink))


## Switch plate on the deck: a sign with an arrow into (dir > 0) or out of the screen.
static func switch_plate(ci: CanvasItem, x: float, y: float, dir: float, wide: float, t: float) -> void:
	var glow := 0.6 + 0.4 * sin(t * 5.0)
	var col := Color("5bd1ff")
	if wide > 10.0:
		# Merge plate: a long chevron strip.
		var sx := x - wide
		while sx < x + wide:
			ci.draw_rect(Rect2(sx, y - 1, 3, 2), Color(col, 0.35 + 0.4 * glow))
			sx += 8.0
		return
	ci.draw_rect(Rect2(x - 7, y - 2, 14, 2), STEEL)
	ci.draw_rect(Rect2(x - 6, y - 3, 12, 1), Color(col, glow))
	# Signpost with an arrow pointing into or out of the screen.
	ci.draw_rect(Rect2(x - 1, y - 22, 2, 20), STEEL)
	ci.draw_rect(Rect2(x - 7, y - 30, 14, 10), Color("1e2a3a"))
	ci.draw_rect(Rect2(x - 6, y - 29, 12, 8), Color(col, 0.85))
	var c := Vector2(x, y - 25)
	if dir > 0.0:
		ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-3, 2), c + Vector2(2, -3), c + Vector2(3, 2)]), Color("1e2a3a"))
	else:
		ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-3, -2), c + Vector2(3, -2), c + Vector2(-2, 3)]), Color("1e2a3a"))


# --- enemies ----------------------------------------------------------------------

## Ground-walker you can stomp. p = ground contact, face = -1/1.
static func crawler(ci: CanvasItem, p: Vector2, face: float, skin: String, t: float) -> Vector2:
	var step := int(t * 8.0) % 2
	match skin:
		"scorpion":
			var body := Color("9a5a2a")
			var dark := Color("5a2e14")
			for i in 3:
				var lx := p.x - 5 + i * 4
				ci.draw_rect(Rect2(lx + (step if i % 2 == 0 else 1 - step), p.y - 2, 1, 2), dark)
			ci.draw_rect(Rect2(p.x - 6, p.y - 6, 11, 4), body)
			ci.draw_rect(Rect2(p.x - 5, p.y - 7, 9, 1), body.lightened(0.2))
			# Tail curled over the back (kept low), claws out front.
			var tb := Vector2(p.x - face * 6.0, p.y - 5)
			ci.draw_line(tb, tb + Vector2(-face * 2.0, -3), body, 2.0)
			ci.draw_line(tb + Vector2(-face * 2.0, -3), tb + Vector2(face * 1.0, -6), body, 2.0)
			ci.draw_rect(Rect2(tb.x + face * 1.0 - 1, tb.y - 8, 2, 2), Color("f0d060"))
			var cx := p.x + face * 7.0
			ci.draw_rect(Rect2(cx - 1, p.y - 6, 3, 2), body)
			ci.draw_rect(Rect2(cx + face * 2.0 - 1, p.y - 7, 2, 1), dark)
			ci.draw_rect(Rect2(p.x + face * 3.0, p.y - 7, 1, 1), Color("111111"))
			return p + Vector2(face * 3.0, -7)
		"rustbot":
			var shell := Color("8a5a3a")
			ci.draw_rect(Rect2(p.x - 7, p.y - 3, 14, 3), Color("2a2a30"))
			for i in 4:
				ci.draw_rect(Rect2(p.x - 6 + i * 4 + step, p.y - 2, 1, 1), STEEL_HI)
			ci.draw_rect(Rect2(p.x - 6, p.y - 9, 12, 6), shell)
			ci.draw_rect(Rect2(p.x - 6, p.y - 9, 12, 1), shell.lightened(0.25))
			ci.draw_rect(Rect2(p.x - 4, p.y - 7, 2, 2), Color("5a3a24"))
			ci.draw_line(Vector2(p.x, p.y - 9), Vector2(p.x - face, p.y - 12), STEEL, -1.0)
			var ex := p.x + face * 4.0
			ci.draw_rect(Rect2(ex - 1, p.y - 7, 2, 2), Color(1.0, 0.4, 0.2, 0.7 + 0.3 * sin(t * 9.0)))
			return Vector2(ex, p.y - 6)
		"mole":
			var fur := Color("6a4a3a")
			ci.draw_circle(p + Vector2(0, -4), 6.5, fur)
			ci.draw_rect(Rect2(p.x - 7, p.y - 4, 14, 4), fur)
			# Hard hat with a lamp.
			ci.draw_rect(Rect2(p.x - 5, p.y - 11, 10, 3), Color("e0b020"))
			ci.draw_rect(Rect2(p.x + face * 3.0 - 1, p.y - 11, 2, 2), Color("fff1a8"))
			ci.draw_rect(Rect2(p.x + face * 6.0 - 1, p.y - 4, 2, 2), Color("e89aa0"))
			ci.draw_rect(Rect2(p.x + face * 6.0 - 2 + step, p.y - 1, 3, 1), Color("e0d0c0"))
			ci.draw_rect(Rect2(p.x + face * 3.0, p.y - 6, 1, 1), Color("111111"))
			return p + Vector2(face * 3.0, -6)
		"marmot":
			var fur := Color("a07a50")
			ci.draw_circle(p + Vector2(0, -4), 6.0, fur)
			ci.draw_rect(Rect2(p.x - 6, p.y - 4, 12, 4), fur)
			ci.draw_circle(p + Vector2(face * 4.0, -7), 3.0, fur.lightened(0.1))
			ci.draw_rect(Rect2(p.x - 6, p.y - 10, 12, 1), Color("f4f8fc"))
			ci.draw_rect(Rect2(p.x + face * 5.0, p.y - 8, 1, 1), Color("111111"))
			ci.draw_rect(Rect2(p.x - face * 6.0 - 1, p.y - 5, 2, 3), fur.darkened(0.3))
			for i in 2:
				ci.draw_rect(Rect2(p.x - 3 + i * 5 + step, p.y - 1, 2, 1), fur.darkened(0.4))
			return p + Vector2(face * 5.0, -8)
	if skin == "gloop":
		# A green alien blob that wobbles along on its own goo; eye stalks wave.
		var wob := sin(t * 6.0) * 1.0
		var body := Color("62c24a")
		ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-7, 0), p + Vector2(-6 - wob, -6), p + Vector2(-2, -9 + wob * 0.5),
			p + Vector2(3, -9 - wob * 0.5), p + Vector2(6 + wob, -6), p + Vector2(7, 0)]), body)
		ci.draw_rect(Rect2(p.x - 7, p.y - 1, 14, 1), Color("3a8a2a"))
		ci.draw_rect(Rect2(p.x - 4, p.y - 7, 3, 2), body.lightened(0.35))
		for sx in [-2.0, 3.0]:
			var tip := Vector2(p.x + sx + face * 1.0 + sin(t * 4.0 + sx) * 1.0, p.y - 13.0)
			ci.draw_line(Vector2(p.x + sx, p.y - 8), tip, body, -1.0)
			ci.draw_rect(Rect2(tip.x - 1, tip.y - 1, 3, 3), Color("f4f4f4"))
			ci.draw_rect(Rect2(tip.x + (0 if face > 0 else -1), tip.y, 1, 1), Color("111111"))
		return Vector2(p.x + face * 3.0, p.y - 12)
	# Beetle (default).
	for i in 3:
		var lx := p.x - 5 + i * 5
		ci.draw_rect(Rect2(lx + (step if i % 2 == 0 else 1 - step), p.y - 2, 1, 2), Color("3a1c10"))
	var shell := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in 9:
		var a := PI * float(i) / 8.0
		shell.append(p + Vector2(cos(a) * 7.0, -2.0 - sin(a) * 7.0))
		inner.append(p + Vector2(cos(a) * 5.5, -2.5 - sin(a) * 5.5))
	ci.draw_colored_polygon(shell, Color("7a3a16"))
	ci.draw_colored_polygon(inner, Color("c8692a"))
	ci.draw_rect(Rect2(p.x - 3, p.y - 8, 2, 1), Color("f0a060"))
	ci.draw_line(Vector2(p.x, p.y - 8), Vector2(p.x, p.y - 3), Color("7a3a16"), -1.0)
	var ex2 := p.x + face * 5.0
	ci.draw_rect(Rect2(ex2 - 1, p.y - 5, 2, 2), Color("f4f4f4"))
	ci.draw_rect(Rect2(ex2 + (0 if face > 0 else -1), p.y - 5, 1, 1), Color("111111"))
	return Vector2(ex2, p.y - 4)


## Can't be stomped. p = ground contact; body centred 6 px up.
static func spiker(ci: CanvasItem, p: Vector2, skin: String, t: float) -> Vector2:
	var c := p + Vector2(0, -6)
	match skin:
		"cactus":
			ci.draw_circle(c, 5.5, Color("4e8a3a"))
			ci.draw_circle(c + Vector2(-1, -1), 3.5, Color("6aa84a"))
			for i in 10:
				var a := i * TAU / 10.0
				var d := Vector2(cos(a), sin(a))
				ci.draw_line(c + d * 5.0, c + d * 8.0, Color("f4ead5"), -1.0)
			ci.draw_rect(Rect2(c.x - 1, c.y - 7, 3, 2), Color("ff6ad5"))
			ci.draw_rect(Rect2(c.x - 5, p.y - 1, 10, 1), Color("7a5a3a"))
			return c
		"mine":
			for i in 6:
				var a := t * 0.6 + i * TAU / 6.0
				var d := Vector2(cos(a), sin(a))
				ci.draw_rect(Rect2((c + d * 6.5).floor() - Vector2(1, 1), Vector2(3, 3)), Color("b0b4ba"))
			ci.draw_circle(c, 5.0, Color("3a3c44"))
			ci.draw_circle(c + Vector2(-1, -1), 3.0, Color("5a5e68"))
			ci.draw_rect(Rect2(c.x - 1, c.y - 1, 2, 2), Color(1.0, 0.25, 0.2, 0.6 + 0.4 * sin(t * 8.0)))
			return c
		"crystal":
			var glow := 0.5 + 0.5 * sin(t * 3.0)
			ci.draw_circle(c, 9.0, Color(0.7, 0.4, 1.0, 0.10 + 0.08 * glow))
			for spec in [[-4.0, 9.0, 3.0], [0.0, 12.0, 3.5], [4.0, 8.0, 3.0]]:
				var bx: float = c.x + float(spec[0])
				var h: float = spec[1]
				var w: float = spec[2]
				ci.draw_colored_polygon(PackedVector2Array([Vector2(bx - w, p.y), Vector2(bx, p.y - h), Vector2(bx + w, p.y)]), Color("8a5ad0"))
				ci.draw_line(Vector2(bx, p.y - h), Vector2(bx - w * 0.5, p.y), Color("d0b0ff"), -1.0)
			return c
		"tnt":
			# Dynamite: three red sticks, a band, and a fizzing fuse.
			for i in 3:
				ci.draw_rect(Rect2(c.x - 5 + i * 3.5, p.y - 11, 3, 11), Color("c8302a"))
				ci.draw_rect(Rect2(c.x - 5 + i * 3.5, p.y - 11, 1, 11), Color("e85a48"))
			ci.draw_rect(Rect2(c.x - 6, p.y - 7, 12, 2), Color("3a2a1e"))
			var fz := c + Vector2(1, -8)
			ci.draw_line(fz, fz + Vector2(2, -4), Color("8a7a5a"), -1.0)
			var spark := 0.5 + 0.5 * sin(t * 30.0)
			ci.draw_circle(fz + Vector2(2, -5), 1.5 + spark, Color(1.0, 0.85, 0.3, 0.8))
			for i in 3:
				var a := t * 9.0 + i * 2.1
				ci.draw_rect(Rect2(fz.x + 2 + cos(a) * 3.0, fz.y - 5 + sin(a) * 3.0, 1, 1), Color("fff1a8"))
			return c
		"thistle":
			# A spiky weed with a purple flower head (can't be stomped: prickly).
			ci.draw_line(Vector2(c.x, p.y), Vector2(c.x, c.y - 2), Color("4e7a3a"), 2.0)
			for sd in [-1.0, 1.0]:
				ci.draw_colored_polygon(PackedVector2Array([Vector2(c.x, p.y - 3), Vector2(c.x + sd * 6.0, p.y - 6),
					Vector2(c.x + sd * 2.0, p.y - 1)]), Color("5a8a3a"))
			ci.draw_circle(c + Vector2(0, -3), 4.0, Color("6a9a4a"))
			for i in 7:
				var a := -PI + i * PI / 6.0
				ci.draw_line(c + Vector2(0, -3) + Vector2(cos(a), sin(a)) * 3.0, c + Vector2(0, -3) + Vector2(cos(a), sin(a)) * 6.5,
					Color("e8e2d0"), -1.0)
			ci.draw_rect(Rect2(c.x - 3, c.y - 9, 6, 3), Color("b05ad0"))
			ci.draw_rect(Rect2(c.x - 2, c.y - 10, 4, 1), Color("d890f0"))
			return c
		"spore":
			# An alien spore pod: glowing core, spines that pulse.
			var pulse := 0.5 + 0.5 * sin(t * 4.0)
			ci.draw_circle(c, 9.0, Color(0.7, 0.3, 1.0, 0.08 + 0.08 * pulse))
			for i in 9:
				var a := i * TAU / 9.0 + 0.2
				var d := Vector2(cos(a), sin(a))
				var n := Vector2(-d.y, d.x)
				ci.draw_colored_polygon(PackedVector2Array([c + d * 3.5 + n * 1.4, c + d * (7.5 + pulse), c + d * 3.5 - n * 1.4]), Color("c8a0f0"))
			ci.draw_circle(c, 5.0, Color("5a2a7a"))
			ci.draw_circle(c, 3.0, Color(0.85, 0.5, 1.0, 0.7 + 0.3 * pulse))
			ci.draw_rect(Rect2(c.x - 1, c.y - 1, 1, 1), Color.WHITE)
			return c
		"ice":
			for i in 8:
				var a := i * TAU / 8.0
				var d := Vector2(cos(a), sin(a))
				var n := Vector2(-d.y, d.x)
				ci.draw_colored_polygon(PackedVector2Array([c + d * 3.5 + n * 1.5, c + d * 8.5, c + d * 3.5 - n * 1.5]), Color("cfe8ff"))
			ci.draw_circle(c, 4.5, Color("7fb0e0"))
			ci.draw_circle(c + Vector2(-1, -1), 2.0, Color("f4fbff"))
			return c
	# Urchin (default).
	var spin := t * 1.5
	for i in 8:
		var a := spin + i * TAU / 8.0
		var d := Vector2(cos(a), sin(a))
		var n := Vector2(-d.y, d.x)
		ci.draw_colored_polygon(PackedVector2Array([c + d * 4.0 + n * 1.5, c + d * 8.5, c + d * 4.0 - n * 1.5]), Color("e8e2d0"))
	ci.draw_circle(c, 5.0, Color("2a2433"))
	ci.draw_circle(c, 3.0, Color("3b3346"))
	ci.draw_rect(Rect2(c.x - 1, c.y - 1, 2, 2), Color("ff4a4a", 0.6 + 0.4 * sin(t * 8.0)))
	return c


## Hovering hazard. p = centre. haze 0..1 fades it toward hz (swooping in from far).
static func drone(ci: CanvasItem, p: Vector2, skin: String, t: float, haze := 0.0, hz := Color.BLACK) -> Vector2:
	match skin:
		"bat":
			var flap := sin(t * 14.0)
			var body := Color("3a2a44").lerp(hz, haze)
			var wing := Color("5a3a6a").lerp(hz, haze)
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-2, -1), p + Vector2(-9, -4 - 4 * flap), p + Vector2(-7, 2), p + Vector2(-4, 1)]), wing)
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(2, -1), p + Vector2(9, -4 - 4 * flap), p + Vector2(7, 2), p + Vector2(4, 1)]), wing)
			ci.draw_circle(p, 3.5, body)
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-3, -2), p + Vector2(-2, -6), p + Vector2(-1, -3)]), body)
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(1, -3), p + Vector2(2, -6), p + Vector2(3, -2)]), body)
			ci.draw_rect(Rect2(p.x - 2, p.y - 1, 1, 1), Color(1.0, 0.3, 0.3).lerp(hz, haze))
			ci.draw_rect(Rect2(p.x + 1, p.y - 1, 1, 1), Color(1.0, 0.3, 0.3).lerp(hz, haze))
			ci.draw_rect(Rect2(p.x - 1, p.y + 2, 1, 2), Color("f4f4f4").lerp(hz, haze))
			ci.draw_rect(Rect2(p.x + 1, p.y + 2, 1, 2), Color("f4f4f4").lerp(hz, haze))
			return p + Vector2(0, -1)
		"vulture", "owl":
			var flap := sin(t * 7.0)
			var owl := skin == "owl"
			var body := (Color("f0f4f8") if owl else Color("4a3a30")).lerp(hz, haze)
			var wing := (Color("d0dae4") if owl else Color("3a2c24")).lerp(hz, haze)
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-3, -1), p + Vector2(-10, -3 - 4 * flap), p + Vector2(-8, 1)]), wing)
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(3, -1), p + Vector2(10, -3 - 4 * flap), p + Vector2(8, 1)]), wing)
			ci.draw_circle(p, 4.0, body)
			# Hooked beak and talons: not something to land on.
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-4, -1), p + Vector2(-7, 0), p + Vector2(-4, 1)]), Color("e0a020").lerp(hz, haze))
			ci.draw_rect(Rect2(p.x - 2, p.y - 2, 1, 1), (Color("e0a020") if owl else Color("111111")).lerp(hz, haze))
			for i in 3:
				ci.draw_line(p + Vector2(-2 + i * 2, 3), p + Vector2(-2 + i * 2, 5), Color("e8e2d0").lerp(hz, haze), -1.0)
			if not owl:
				ci.draw_rect(Rect2(p.x - 3, p.y - 5, 3, 1), Color("c06060").lerp(hz, haze))
			return p + Vector2(-2, -2)
	if skin == "probe":
		# A little alien probe: a mini saucer with one red eye on a stalk.
		var hull := Color("a8b0bc").lerp(hz, haze)
		ci.draw_rect(Rect2(p.x - 8, p.y - 1, 16, 3), hull)
		ci.draw_rect(Rect2(p.x - 6, p.y + 2, 12, 2), Color("4a4f5c").lerp(hz, haze))
		ci.draw_circle(p + Vector2(0, -2), 4.0, Color(0.55, 1.0, 0.72, 0.6).lerp(hz, haze))
		var blink := 1.0 if int(t * 3.0) % 4 != 0 else 0.3
		ci.draw_rect(Rect2(p.x - 1, p.y - 3, 2, 2), Color(1.0, 0.25, 0.2, blink).lerp(hz, haze))
		for i in 3:
			var lit := int(t * 8.0 + i) % 3 == 0
			ci.draw_rect(Rect2(p.x - 6 + i * 5, p.y, 2, 1), (Color("fff1a8") if lit else Color("e04848")).lerp(hz, haze))
		ci.draw_rect(Rect2(p.x - 1, p.y + 4, 2, 2), Color(0.6, 1.0, 0.7, 0.6).lerp(hz, haze))
		return p + Vector2(0, -2)
	# Drone (default).
	var w := roundf(9.0 * absf(cos(t * 30.0))) + 1.0
	ci.draw_line(Vector2(p.x, p.y - 4), Vector2(p.x, p.y - 7), Color("4a4f5c").lerp(hz, haze), -1.0)
	ci.draw_rect(Rect2(p.x - w, p.y - 8, w * 2, 1), Color("c9d1d9").lerp(hz, haze))
	for i in 3:
		var sx := p.x - 5 + i * 5
		ci.draw_colored_polygon(PackedVector2Array([Vector2(sx - 1, p.y - 3), Vector2(sx, p.y - 6), Vector2(sx + 1, p.y - 3)]),
			Color("e8e2d0").lerp(hz, haze))
	ci.draw_rect(Rect2(p.x - 7, p.y - 3, 14, 6), Color("4a4f5c").lerp(hz, haze))
	ci.draw_rect(Rect2(p.x - 6, p.y - 3, 12, 4), Color("8a93a6").lerp(hz, haze))
	ci.draw_rect(Rect2(p.x - 6, p.y + 2, 12, 1), Color("2a2d36").lerp(hz, haze))
	var blink := 1.0 if int(t * 3.0) % 4 != 0 else 0.3
	ci.draw_rect(Rect2(p.x - 5, p.y - 1, 2, 2), Color(1.0, 0.25, 0.2, blink))
	return p + Vector2(-4, 0)
