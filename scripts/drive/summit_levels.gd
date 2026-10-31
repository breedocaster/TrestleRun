## SUMMIT: twelve hill climbs. Each is a long climb to a summit flag on one tank,
## topped up by fuel cans (charge points for the electric bikes) along the way. The
## hills come from a seeded noise recipe per level, so every phone gets the same ones.
extends RefCounted

const Terrain := preload("res://scripts/drive/terrain.gd")
const Course := preload("res://scripts/drive/course.gd")

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
## (meta_override: a climb made to order, for events; i still picks the seeds and how
## many walls and ramps.)
static func build(i: int, meta_override: Dictionary = {}) -> Dictionary:
	var m := meta_override if not meta_override.is_empty() else meta(i)
	var seed := float(i) * 7.31 + 3.0
	var length := float(m.m) * PX_PER_M
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + i
	# Where the bridges and kicker gaps go, alternating, spread over the middle of the climb
	# (placed before the ground is made, so the walls can keep clear of them).
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
	# Walls (from climb 2): short straight climbs of 33-34 degrees, between the bridges and gaps.
	# Hold gas up one and the front keeps coming up until you're over backwards; ease
	# off and let the momentum carry you. They're why holding gas only gets you to the
	# top of the first climb.
	# (An event's climb can say how hard it is: walls and ramps as for that climb.)
	var di := int(m.get("difficulty", i))
	var walls := _walls(di, length, feats)
	# Jump ramps (from climb 2): a short steep kicker with the ground falling away after
	# it, for air: flips and tricks (tricks.gd). They go in the room the walls leave, and
	# are built the same way (the ground's steps in a window), so walls and ramps are one
	# list for the ground below.
	var ramps := _ramps(di, length, feats, walls)
	var shapes: Array = walls + ramps
	# 1. The natural ground: a climb with hills on it, slopes kept within limits. A wall
	# takes over the ground in its window (flat run-in, the straight wall, a flat shelf on
	# top); after it the hills carry on from the shelf's height (off), so a wall is
	# always the size it says rather than adding to whatever the hill was doing there.
	var pts := PackedVector2Array()
	var x := -480.0
	var y := 0.0
	# (The hills themselves stay under 26 degrees, whatever "up" says: past about 30 a bike
	# can't hold its speed up a long climb without the front coming up, so only the walls,
	# which are short, go steeper.)
	var up_max := tan(deg_to_rad(minf(float(m.up), 26.0)))
	var down_max := tan(deg_to_rad(float(m.down)))
	var climb := float(m.climb) / 1000.0
	var amp := float(m.amp)
	var bump := float(m.bump)
	var steps := bool(m.get("steps", false))
	var off := 0.0
	while x <= length + 600.0:
		var target := 0.0
		var natural := 0.0
		if x > 240.0 and x < length - 120.0:
			var k := x - 240.0
			# Hills ease in over the first 600 px.
			var ease := clampf(k / 600.0, 0.0, 1.0)
			natural = -climb * k
			natural += ease * amp * (_noise(k / 520.0, seed) * 0.65 + _noise(k / 210.0, seed + 1.0) * 0.35)
			natural += ease * bump * 7.0 * _noise(k / 48.0, seed + 2.0)
			target = natural + off
			if steps:
				# Shelves: flatten into steps every ~300 px.
				var sh := 36.0 + 10.0 * _noise(k / 900.0, seed + 3.0)
				target = lerpf(target, roundf(target / sh) * sh, 0.55)
		elif x >= length - 120.0:
			target = y  # summit plateau
		var dy := clampf(target - y, -up_max * STEP, down_max * STEP)
		for wi in shapes.size():
			var wl: Array = shapes[wi]
			if x >= float(wl[0]) and x < float(wl[5]):
				dy = 0.0
				var kk := int(roundf((x - float(wl[1])) / STEP))
				if x >= float(wl[1]) - 1.0 and kk < (wl[6] as Array).size():
					dy = -float(wl[6][kk])
		if x <= 240.0:
			dy = 0.0
		y += dy
		for wl in shapes:
			if x >= float(wl[0]) and x < float(wl[5]):
				off = y - natural
		pts.append(Vector2(x, y))
		x += STEP
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
			# The ground after the bridge carries on from deck height: everything from the
			# deck's end on moves to suit (rather than climbing back to where the hills were,
			# which made a long steep pull right off the deck).
			var shift := deck_y - pts[ib].y
			for j in range(ib, pts.size()):
				pts[j].y += shift
			# Carve a valley under the deck.
			var end_y := pts[ib].y
			# (From the point after the deck's start: that one stays at deck height, so the
			# ground runs straight onto the deck instead of dipping and leaving a ledge.)
			for j in range(ia + 1, ib + 1):
				var u := float(j - ia) / float(ib - ia)
				var valley := deck_y + 70.0 + 30.0 * sin(u * PI)
				pts[j].y = maxf(pts[j].y, lerpf(valley, end_y, smoothstep(0.85, 1.0, u)) if u > 0.85 else valley)
			bridges.append([pts[ia].x, pts[ib].x, deck_y])
		else:
			# Kicker: a flat run-in (224 px at the height the climb had 224 px back, so
			# you reach the lip at speed instead of slowed by the hill), a short ramp up
			# (18 px over 64, about 16 degrees), a 64 px pit, then a flat landing. The
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
			# Landing: a flat 96 px pad a little lower than the lip, and the hills carry on
			# from there (everything after moves to suit).
			var land_y := lip.y + 12.0
			if land + 6 < pts.size():
				var drop := land_y - pts[land + 6].y
				for j in range(land + 6, pts.size()):
					pts[j].y += drop
			for j in range(land, mini(land + 6, pts.size())):
				pts[j].y = land_y
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
				t.add_polyline(Course._rounded(surf))
			surf = PackedVector2Array()
		elif in_bridge:
			pass  # the deck goes in below
		else:
			surf.append(p)
		j += 1
	if surf.size() > 1:
		t.add_polyline(Course._rounded(surf))
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
		# A can that would sit over a gap goes just past its landing instead (dropping
		# it left QUARRY CLIMB a leg longer than a tank).
		var at := fx
		for g in gaps:
			if at > float(g[0]) - 40.0 and at < float(g[1]) + 40.0:
				at = float(g[1]) + 140.0
		# One that would sit on a wall (or the end of its run-in) goes on the shelf at the
		# top: you grab it when you've made it up.
		for wl in walls:
			if at > float(wl[1]) - 60.0 and at < float(wl[5]):
				at = float(wl[1]) + float(wl[2]) + WALL_SHELF * 0.5
		# (or a jump ramp: well after its landing, so you've got the bike back first)
		for rp in ramps:
			if at > float(rp[1]) - 60.0 and at < float(rp[5]) + 200.0:
				at = float(rp[5]) + 240.0
		fuel.append(Vector2(at, _surface_y(t, at) - 8.0))
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
	# A few coins in the air off each jump ramp's lip, along about where a bike at speed
	# flies (a bonus for taking it flat out).
	for rp in ramps:
		var lip := Vector2(float(rp[1]) + RAMP_UP * STEP, _surface_y(t, float(rp[1]) + RAMP_UP * STEP - 1.0))
		if lip.y == INF:
			continue
		for q in 3:
			var tt := 0.12 + 0.12 * float(q)
			coins.append([lip + Vector2(130.0 * tt, -85.0 * tt + 300.0 * tt * tt - 12.0), 5])
	# How-to signs: the first wall on climb 2, the first kicker gap.
	var tips := []
	if i == 1 and not walls.is_empty():
		tips.append([float(walls[0][0]), "STEEP! EASE OFF THE GAS OR YOU FLIP"])
	if not gaps.is_empty() and i == 4:
		tips.append([float(gaps[0][0]) - 300.0, "JUMP! IN THE AIR, GAS TIPS YOU BACK"])
	if i == 1 and not ramps.is_empty():
		tips.append([float(ramps[0][0]), "RAMP! TAP GAS TWICE IN THE AIR: NO-HANDER"])
	if i == 2 and not ramps.is_empty():
		tips.append([float(ramps[0][0]), "IN THE AIR: TAP GAS THEN BRAKE FOR A HEEL CLICKER"])
	tips.sort_custom(func(p, q): return float(p[0]) < float(q[0]))
	return {
		"tips": tips,
		"id": m.id, "name": m.name, "theme": m.theme, "time": m.time, "weather": "clear",
		"terrain": t, "ground": pts, "bridges": bridges, "gaps": gaps,
		"coins": coins, "fuel": fuel, "start": Vector2(0, 0), "finish_x": length,
		"length_m": float(m.m), "kill_y": 2000.0, "mode": "summit",
		"ramps": ramps.map(func(rp): return float(rp[1]) + RAMP_UP * STEP),
	}


## Walls for climb i: [[run-in start x, foot x, run, rise, degrees, shelf end x, the rise
## of each 16 px step]]. Climb 1 has none; then one to four, 33 to 34 degrees and 59 to
## 71 px high, each after a flat 288 px run-in and with a 96 px shelf on top, in the
## stretches clear of the bridges and kicker gaps. The corners get the same small
## rounding as GAUNTLET's (course.gd _rounded, in build()): a dead sharp foot kicked the
## front up hard enough at speed to flip the bike however it was ridden, while easing
## the foot and top over three steps each left so little of the wall at full slope that
## holding gas got up most of them. In calibration runs (--course-calibrate
## --only=wall, and longer walls in a scratch version) holding gas flipped nearly every
## bike on a 34 degree wall from 60 px, and the search (beam 24) got the scrambler up
## 34 x 64 stock by easing off; in
## the levels, walls past 34 degrees and 66 px stopped the search too (it rides in 0.1 s
## blocks, about as finely as a thumb can feather), so they stop there.
static var WALL_RUN_IN := 288.0
const WALL_SHELF := 96.0
static func _walls(i: int, length: float, feats: Array) -> Array:
	if i == 0:
		return []
	var n := mini(1 + i / 3, 4) + (1 if i == 1 or i == 3 else 0)
	var deg := 33.0 + 0.1 * float(i)
	var rise := 58.0 + 1.2 * float(i)
	# Rise per 16 px step: the full slope, and what's left over as one last, gentler
	# step. (Rounding the step count instead made some walls 35 degrees and some 32.)
	var full := STEP * tan(deg_to_rad(deg))
	var seq := []
	for _q in int(rise / full):
		seq.append(full)
	if rise - full * float(seq.size()) > 0.5:
		seq.append(rise - full * float(seq.size()))
	var run := float(seq.size()) * STEP
	var w := WALL_RUN_IN + run + WALL_SHELF
	# Free stretches: from 500 px past a bridge or gap's start (a bridge runs up to 420 px
	# on, a kicker's landing 384) to 300 px before the next (a kicker's run-in starts 224
	# px before its lip).
	var marks := []
	for f in feats:
		marks.append(float(f[0]))
	marks.sort()
	var free := []
	var a := maxf(length * 0.1, 900.0)
	for mk in marks:
		free.append([a, float(mk) - 300.0])
		a = float(mk) + 500.0
	free.append([a, length * 0.9])
	# Hand the walls out one at a time to the stretch with the most room per wall.
	var count := []
	for f in free:
		count.append(0)
	for _k in n:
		var best := -1
		var best_room := 0.0
		for j in free.size():
			var span := float(free[j][1]) - float(free[j][0])
			var room := (span - float(count[j] + 1) * w) / float(count[j] + 2)
			if room > 160.0 and room > best_room:
				best_room = room
				best = j
		if best < 0:
			break
		count[best] += 1
	var out := []
	for j in free.size():
		var c: int = count[j]
		if c == 0:
			continue
		var a0 := float(free[j][0])
		var gap := (float(free[j][1]) - a0 - float(c) * w) / float(c + 1)
		for q in c:
			var x0 := a0 + gap * float(q + 1) + w * float(q)
			out.append([x0, x0 + WALL_RUN_IN, run, rise, deg, x0 + w, seq])
	out.sort_custom(func(p, q): return float(p[0]) < float(q[0]))
	return out


## Jump ramps for climb i, in the same form as _walls (the step list rises then drops):
## a flat run-in, RAMP_UP steps up to about 34 degrees (25 px), then the ground falls
## away down a 32-degree landing slope, 152 px in all over 256: long enough that a fully
## upgraded sportbike taking it flat out still comes down on the slope (on a 92 px one
## the fast bikes flew past the bottom and crashed), then 80 px of flat before the hill
## carries on (straight into an uphill, the bottom was a V that threw the unicycles). A bike at speed is in the air
## about half a second, long enough for a trick. One on climbs 2-4, two on 5-8, three
## after; none on the first (holding gas there should still get you up). Placed in what
## the walls leave of the stretches clear of bridges and gaps.
const RAMP_RUN_IN := 160.0
const RAMP_UP := 3
const RAMP_SEQ := [5.0, 9.0, 11.0, -14.0, -10.0, -10.0, -10.0, -10.0, -10.0, -10.0, -10.0, -10.0, -10.0, -10.0,
	-10.0, -10.0, -8.0, -6.0, -4.0, -2.0, 0.0, 0.0, 0.0, 0.0, 0.0]
static func _ramps(i: int, length: float, feats: Array, walls: Array) -> Array:
	if i == 0:
		return []
	var n := 1 if i < 4 else (2 if i < 8 else 3)
	var run := float(RAMP_SEQ.size()) * STEP
	var w := RAMP_RUN_IN + run + 32.0
	var blocked := []
	for f in feats:
		blocked.append([float(f[0]) - 300.0, float(f[0]) + 500.0])
	for wl in walls:
		blocked.append([float(wl[0]) - 150.0, float(wl[5]) + 150.0])
	blocked.sort_custom(func(p, q): return float(p[0]) < float(q[0]))
	var free := []
	var a := maxf(length * 0.1, 900.0)
	var end := length * 0.9
	for b in blocked:
		if float(b[0]) > a:
			free.append([a, minf(float(b[0]), end)])
		a = maxf(a, float(b[1]))
	if end > a:
		free.append([a, end])
	free = free.filter(func(f): return float(f[1]) - float(f[0]) > w + 120.0)
	# The biggest stretches first, one in the middle of each, then a second at the far
	# third of a long one.
	free.sort_custom(func(p, q): return float(p[1]) - float(p[0]) > float(q[1]) - float(q[0]))
	var cands := []
	for f in free:
		cands.append((float(f[0]) + float(f[1])) * 0.5 - w * 0.5)
	for f in free:
		if float(f[1]) - float(f[0]) > 2.0 * w + 400.0:
			cands.append(float(f[0]) + (float(f[1]) - float(f[0])) * 0.75 - w * 0.5)
	var out := []
	for x0 in cands:
		if out.size() >= n:
			break
		var clash := false
		for o in out:
			if absf(float(o[0]) - float(x0)) < w + 200.0:
				clash = true
		if not clash:
			out.append([float(x0), float(x0) + RAMP_RUN_IN, run, 25.0, 34.0, float(x0) + w, RAMP_SEQ])
	out.sort_custom(func(p, q): return float(p[0]) < float(q[0]))
	return out


static func _surface_y(t, x: float) -> float:
	return t.top_at(x)
