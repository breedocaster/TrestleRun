## SUMMIT: twelve hill climbs. Each is a long climb to a summit flag on one tank,
## topped up by fuel cans (charge points for the electric bikes) along the way. The
## hills come from a seeded noise recipe per level, so every phone gets the same ones.
extends RefCounted

const Terrain := preload("res://scripts/drive/terrain.gd")

const PX_PER_M := 8.0
const STEP := 16.0

## id, name, backdrop theme, time, length (m), climb (px per 1000 px), hill size,
## steepest up / down (deg), bumpiness, bridges, kicker gaps, fuel spacing (m),
## upgrades the checker drives it with (engine, suspension, tires, tank).
const LEVELS := [
	{"id": "su_farm", "name": "FOOTHILL FARM", "theme": 12, "time": "day", "m": 900, "climb": 60.0, "amp": 26.0,
		"up": 16.0, "down": 18.0, "bump": 0.0, "bridges": 0, "gaps": 0, "fuel": 300, "up_req": [0, 0, 0, 0]},
	{"id": "su_redrock", "name": "RED ROCK RISE", "theme": 1, "time": "day", "m": 1050, "climb": 80.0, "amp": 38.0,
		"up": 20.0, "down": 22.0, "bump": 0.0, "bridges": 1, "gaps": 0, "fuel": 290, "up_req": [0, 0, 0, 0]},
	{"id": "su_mesa", "name": "MESA STEPS", "theme": 4, "time": "dusk", "m": 1150, "climb": 90.0, "amp": 30.0,
		"up": 24.0, "down": 26.0, "bump": 0.2, "bridges": 1, "gaps": 0, "fuel": 280, "up_req": [1, 0, 1, 0],
		"steps": true},
	{"id": "su_pines", "name": "PINE RIDGE", "theme": 8, "time": "day", "m": 1250, "climb": 100.0, "amp": 52.0,
		"up": 24.0, "down": 28.0, "bump": 0.2, "bridges": 2, "gaps": 0, "fuel": 280, "up_req": [1, 1, 1, 1]},
	{"id": "su_orchard", "name": "ORCHARD HILLS", "theme": 14, "time": "dusk", "m": 1350, "climb": 100.0, "amp": 46.0,
		"up": 26.0, "down": 28.0, "bump": 0.5, "bridges": 1, "gaps": 1, "fuel": 290, "up_req": [2, 1, 1, 1]},
	{"id": "su_hoodoo", "name": "HOODOO HUMPS", "theme": 6, "time": "day", "m": 1450, "climb": 110.0, "amp": 64.0,
		"up": 27.0, "down": 30.0, "bump": 0.3, "bridges": 1, "gaps": 2, "fuel": 300, "up_req": [2, 2, 2, 1]},
	{"id": "su_quarry", "name": "QUARRY CLIMB", "theme": 9, "time": "day", "m": 1550, "climb": 130.0, "amp": 56.0,
		"up": 30.0, "down": 30.0, "bump": 0.7, "bridges": 1, "gaps": 2, "fuel": 300, "up_req": [3, 2, 2, 2],
		"steps": true},
	{"id": "su_railbed", "name": "RAILBED GRADE", "theme": 13, "time": "dusk", "m": 1650, "climb": 120.0, "amp": 60.0,
		"up": 28.0, "down": 32.0, "bump": 0.4, "bridges": 3, "gaps": 2, "fuel": 310, "up_req": [3, 3, 2, 2]},
	{"id": "su_night", "name": "NIGHT RIDGE", "theme": 3, "time": "night", "m": 1750, "climb": 130.0, "amp": 70.0,
		"up": 30.0, "down": 32.0, "bump": 0.5, "bridges": 2, "gaps": 3, "fuel": 320, "up_req": [3, 3, 3, 3]},
	{"id": "su_mine", "name": "LANTERN HAUL", "theme": 5, "time": "night", "m": 1850, "climb": 140.0, "amp": 62.0,
		"up": 32.0, "down": 32.0, "bump": 0.8, "bridges": 2, "gaps": 3, "fuel": 320, "up_req": [4, 3, 3, 3],
		"steps": true},
	{"id": "su_rocket", "name": "ROCKET RISE", "theme": 10, "time": "dusk", "m": 1950, "climb": 160.0, "amp": 76.0,
		"up": 33.0, "down": 34.0, "bump": 0.6, "bridges": 2, "gaps": 4, "fuel": 330, "up_req": [4, 4, 4, 4]},
	{"id": "su_summit", "name": "THE SUMMIT", "theme": 11, "time": "dusk", "m": 2100, "climb": 180.0, "amp": 84.0,
		"up": 35.0, "down": 35.0, "bump": 0.8, "bridges": 3, "gaps": 4, "fuel": 340, "up_req": [5, 5, 5, 5]},
]


static func count() -> int:
	return LEVELS.size()


static func meta(i: int) -> Dictionary:
	return LEVELS[clampi(i, 0, LEVELS.size() - 1)]


static func index_of(id: String) -> int:
	for i in LEVELS.size():
		if LEVELS[i].id == id:
			return i
	return -1


static func _hash(n: float) -> float:
	var s := sin(n * 12.9898 + 78.233) * 43758.5453
	return s - floorf(s)


## Smooth 1D value noise in -1..1.
static func _noise(x: float, seed: float) -> float:
	var i := floorf(x)
	var f := x - i
	var a := _hash(i + seed * 101.0) * 2.0 - 1.0
	var b := _hash(i + 1.0 + seed * 101.0) * 2.0 - 1.0
	var u := f * f * (3.0 - 2.0 * f)
	return lerpf(a, b, u)


## Build level i: {"terrain", "surface" (drawn ground line), "bridges", "gaps",
## "coins", "fuel", "start", "finish_x", "length_m", meta...}.
static func build(i: int) -> Dictionary:
	var m := meta(i)
	var seed := float(i) * 7.31 + 3.0
	var length := float(m.m) * PX_PER_M
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + i
	# 1. The natural ground: a climb with hills on it, slopes kept within limits.
	var pts := PackedVector2Array()
	var x := -480.0
	var y := 0.0
	var up_max := tan(deg_to_rad(float(m.up)))
	var down_max := tan(deg_to_rad(float(m.down)))
	var climb := float(m.climb) / 1000.0
	var amp := float(m.amp)
	var bump := float(m.bump)
	var steps := bool(m.get("steps", false))
	while x <= length + 600.0:
		var target := 0.0
		if x > 240.0 and x < length - 120.0:
			var k := x - 240.0
			# Hills ease in over the first 600 px.
			var ease := clampf(k / 600.0, 0.0, 1.0)
			target = -climb * k
			target += ease * amp * (_noise(k / 520.0, seed) * 0.65 + _noise(k / 210.0, seed + 1.0) * 0.35)
			target += ease * bump * 7.0 * _noise(k / 48.0, seed + 2.0)
			if steps:
				# Shelves: flatten into steps every ~300 px.
				var sh := 36.0 + 10.0 * _noise(k / 900.0, seed + 3.0)
				target = lerpf(target, roundf(target / sh) * sh, 0.55)
		elif x >= length - 120.0:
			target = y  # summit plateau
		var dy := clampf(target - y, -up_max * STEP, down_max * STEP)
		if x <= 240.0:
			dy = 0.0
		y += dy
		pts.append(Vector2(x, y))
		x += STEP
	# 2. Bridges and kicker gaps, alternating, spread over the middle of the climb.
	var kinds := []
	var nb := int(m.bridges)
	var ng := int(m.gaps)
	while nb > 0 or ng > 0:
		if nb > 0:
			kinds.append("bridge")
			nb -= 1
		if ng > 0:
			kinds.append("gap")
			ng -= 1
	var feats := []
	for f in kinds.size():
		var at := lerpf(length * 0.18, length * 0.88, (float(f) + 0.5) / float(kinds.size()))
		feats.append([at + rng.randf_range(-120.0, 120.0), kinds[f]])
	var bridges := []
	var gaps := []
	for f in feats:
		var cx := float(f[0])
		var ia := int((cx - pts[0].x) / STEP)
		if ia < 2 or ia > pts.size() - 40:
			continue
		if f[1] == "bridge":
			# A trestle across a dip: the deck runs level from here; the ground under it
			# drops into a valley.
			var span := rng.randf_range(260.0, 420.0)
			var n := int(span / STEP)
			var deck_y := pts[ia].y
			var ib := mini(ia + n, pts.size() - 2)
			# Carve a valley under the deck, rejoining the hills after it.
			var end_y := pts[ib].y
			# (From the point after the deck's start: that one stays at deck height, so the
			# ground runs straight onto the deck instead of dipping and leaving a ledge.)
			for j in range(ia + 1, ib + 1):
				var u := float(j - ia) / float(ib - ia)
				var valley := deck_y + 70.0 + 30.0 * sin(u * PI)
				pts[j].y = maxf(pts[j].y, lerpf(valley, end_y, smoothstep(0.85, 1.0, u)) if u > 0.85 else valley)
			# Ground after the bridge starts at deck height (re-ease the next stretch).
			var shift := deck_y - pts[ib].y
			for j in range(ib, mini(ib + 40, pts.size())):
				var w := 1.0 - float(j - ib) / 40.0
				pts[j].y += shift * w
			bridges.append([pts[ia].x, pts[ib].x, deck_y])
		else:
			# Kicker: a flat run-in (224 px at the height the climb had 224 px back, so
			# you reach the lip at speed instead of slowed by the hill), a short ramp up
			# (18 px over 64, about 16 degrees), a 64 px pit, then a landing slope. The
			# level checker gets the scrambler over it on each climb's up_req upgrades;
			# 80 px it couldn't clear on any, so later climbs have more gaps, not wider.
			var ramp_n := 4
			var gap_n := 3   # 16 px ground steps: the pit runs from the lip point to land
			var rise := 18.0
			var base := pts[ia - 14].y if ia >= 16 else pts[ia].y
			for j in range(maxi(ia - 14, 0), ia):
				pts[j].y = base
			for j in range(ia, ia + ramp_n):
				pts[j].y = base - rise * float(j - ia + 1) / float(ramp_n)
			var lip := pts[ia + ramp_n - 1]
			var land := ia + ramp_n + gap_n
			if land >= pts.size() - 4:
				continue
			for j in range(ia + ramp_n, land):
				pts[j].y = base + 160.0
			# Landing: a little lower than the lip, then back up onto the hill over 384
			# px (the run-in held the height down, so the hill is above by now).
			var land_y := lip.y + 12.0
			var nxt := pts[mini(land + 24, pts.size() - 1)].y
			for j in range(land, mini(land + 24, pts.size())):
				pts[j].y = lerpf(land_y, nxt, smoothstep(0.0, 1.0, float(j - land) / 24.0))
			gaps.append([lip.x, pts[land].x, lip.y, land_y])
	# 3. Physics surface: the ground, but bridges replace the valley with a deck, and
	# gaps are open (their pit floor is far below and kills).
	var t := Terrain.new()
	var surf := PackedVector2Array()
	var j := 0
	while j < pts.size():
		var p := pts[j]
		var in_bridge := false
		for b in bridges:
			if p.x > float(b[0]) and p.x < float(b[1]):
				in_bridge = true
				break
		var in_gap := false
		for g in gaps:
			if p.x > float(g[0]) + 0.5 and p.x < float(g[1]) - 0.5:
				in_gap = true
				break
		if in_gap:
			if surf.size() > 1:
				t.add_polyline(surf)
			surf = PackedVector2Array()
		elif in_bridge:
			pass  # the deck goes in below
		else:
			surf.append(p)
		j += 1
	if surf.size() > 1:
		t.add_polyline(surf)
	for b in bridges:
		t.add_segment(Vector2(float(b[0]) - 0.5, float(b[2])), Vector2(float(b[1]) + 0.5, float(b[2])))
	# Gap pits: a floor far down (touching it ends the run) and the walls.
	for g in gaps:
		var floor_y := float(g[2]) + 160.0
		t.add_segment(Vector2(float(g[0]), floor_y), Vector2(float(g[1]), floor_y), 3)
		# Its walls, so a short jump drops into the pit instead of slipping in under
		# the far side's edge.
		t.add_segment(Vector2(float(g[0]), float(g[2])), Vector2(float(g[0]), floor_y))
		t.add_segment(Vector2(float(g[1]), float(g[3])), Vector2(float(g[1]), floor_y))
	# A wall at the start so nobody backs off the edge.
	t.add_segment(Vector2(-480, 0), Vector2(-480, -400))
	# 4. Pickups: fuel every so often, coins in runs along the surface.
	var fuel := []
	var fx := float(m.fuel) * PX_PER_M
	while fx < length - 200.0:
		var ok := true
		for g in gaps:
			if fx > float(g[0]) - 40.0 and fx < float(g[1]) + 40.0:
				ok = false
		if ok:
			fuel.append(Vector2(fx, _surface_y(t, fx) - 8.0))
		fx += float(m.fuel) * PX_PER_M
	var coins := []
	var cx := 420.0
	while cx < length - 160.0:
		var n := rng.randi_range(4, 8)
		var big := rng.randf() < 0.12
		for c in n:
			var px := cx + c * 14.0
			var on_gap := false
			for g in gaps:
				if px > float(g[0]) - 20.0 and px < float(g[1]) + 20.0:
					on_gap = true
			if on_gap:
				continue
			var sy := _surface_y(t, px)
			if sy == INF:
				continue
			coins.append([Vector2(px, sy - 9.0), 25 if big else 5])
		cx += rng.randf_range(260.0, 420.0)
	return {
		"id": m.id, "name": m.name, "theme": m.theme, "time": m.time, "weather": "clear",
		"terrain": t, "ground": pts, "bridges": bridges, "gaps": gaps,
		"coins": coins, "fuel": fuel, "start": Vector2(0, 0), "finish_x": length,
		"length_m": float(m.m), "kill_y": 2000.0, "mode": "summit",
	}


static func _surface_y(t, x: float) -> float:
	return t.top_at(x)
