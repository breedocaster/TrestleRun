## Endless runs, the daily ride and the weekly league line. Courses are stitched from
## stretches of the hand-made trails (every Free Ride and story trail cut at its
## checkpoints; bosses aside), joined by short flat decks. Each stretch was ridden
## offline by --endless-check at five speeds, in clear, rain and wind, at three
## different arrival times (lifts and critters move on the clock); endless_table.gd
## keeps the results: which speeds it's safe at, the dev bot's time through it, and
## the timing windows a careful rider gets (the league's rivals are modelled on those).
extends RefCounted

const Library := preload("res://scripts/game/level_library.gd")
const Layouts := preload("res://scripts/game/level_layouts.gd")
const Catalog := preload("res://scripts/catalog.gd")

## Speeds a stretch can be ridden at (px/s). Endless steps up one every STEP stretches.
const TIERS := [118.0, 130.0, 142.0, 154.0, 166.0]
const STEP := 4
## A stretch counts as safe at a speed when the bot clears it with no crash in every
## weather asked for and the tightest timing window is at least this (ms).
const MIN_WINDOW := 75.0
const PX_PER_M := 8.0
const ENDLESS_STRETCHES := 90
const DAILY_STRETCHES := 5
## How fast the trail's speed moves to the next stretch's (px/s per s, on the joint).
const SPEED_RAMP := 24.0

static var _sections: Array = []
static var _by_key: Dictionary = {}
static var _table = null


## Every stretch: {"key": "copper_canyon/1", "src", "i", "chunks", "native" speed}.
static func sections() -> Array:
	if not _sections.is_empty():
		return _sections
	var srcs := []
	for id in Layouts.LAYOUTS:
		srcs.append([id, Layouts.LAYOUTS[id]])
	for id in Layouts.STORY:
		if not bool(Catalog.level(id).get("boss", false)):
			srcs.append([id, Layouts.STORY[id]])
	for s in srcs:
		var cur := []
		var n := 0
		for c in s[1]:
			var k := String(c[0])
			if k in ["chase", "start"]:
				continue
			if k in ["checkpoint", "finish"]:
				if not cur.is_empty():
					var sec := {"key": "%s/%d" % [s[0], n], "src": s[0], "i": n, "chunks": cur,
						"native": float(Catalog.level(String(s[0])).speed)}
					_sections.append(sec)
					_by_key[sec.key] = sec
					n += 1
				cur = []
				continue
			cur.append(c)
	return _sections


static func section(key: String) -> Dictionary:
	sections()
	return _by_key.get(key, {})


static func table() -> Dictionary:
	if _table == null:
		var t = load("res://scripts/game/endless_table.gd")
		_table = t.T if t != null else {}
	return _table


## The checker's numbers for one stretch at one speed, or {} if it never rode it.
static func info(key: String, tier: float) -> Dictionary:
	return (table().get(key, {}) as Dictionary).get(str(int(tier)), {})


static func safe(key: String, tier: float, weather := "clear") -> bool:
	var e := info(key, tier)
	if e.is_empty():
		return false
	var wi := ["clear", "rain", "wind"].find(weather)
	return bool((e.ok as Array)[maxi(wi, 0)]) and float(e.min) >= MIN_WINDOW


## Pick a stretch for this speed: one the checker passed, preferring stretches from
## trails ridden near that speed (so the easy trails come first) and ones not seen lately.
static func _pick(rng: RandomNumberGenerator, tier: float, recent: Array, weather: String) -> String:
	var keys := []
	var weights := []
	var total := 0.0
	for sec in sections():
		if not safe(sec.key, tier, weather):
			continue
		var w := exp(-absf(float(sec.native) - tier) / 14.0)
		if sec.key in recent:
			w *= 0.05
		keys.append(sec.key)
		weights.append(w)
		total += w
	if keys.is_empty():
		return ""
	var r := rng.randf() * total
	for i in keys.size():
		r -= float(weights[i])
		if r <= 0.0:
			return keys[i]
	return keys[keys.size() - 1]


## Endless (and the league's weekly line): one stretch after another, a speed step every
## STEP stretches up to the top tier. Returns [[key, speed], ...].
static func endless_plan(seed: int, n := ENDLESS_STRETCHES, weather := "clear") -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var plan := []
	var recent := []
	for i in n:
		var tier: float = TIERS[mini(i / STEP, TIERS.size() - 1)]
		var key := _pick(rng, tier, recent, weather)
		if key == "":
			continue
		plan.append([key, tier])
		recent.append(key)
		if recent.size() > 14:
			recent.pop_front()
	return plan


## The daily ride: DAILY_STRETCHES stretches at one speed, in the day's weather.
static func daily_plan(seed: int, tier: float, weather: String) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var plan := []
	var recent := []
	for i in DAILY_STRETCHES:
		var key := _pick(rng, tier, recent, weather)
		if key == "":
			continue
		plan.append([key, tier])
		recent.append(key)
	return plan


## Build the level for a plan. opts: checkpoints (bool, a checkpoint at every joint),
## letters (bool), finish (bool; endless ends in a finish far out, "the end of the line").
static func build(plan: Array, meta: Dictionary, opts := {}) -> Dictionary:
	var b = Library.new()
	b.level_id = String(meta.get("id", "endless"))
	b.no_letters_here = not bool(opts.get("letters", false))
	b.y = float(opts.get("y0", 0.0))  # dev: build the course at another height
	b.c_start(220.0)
	var zones := []
	var starts := []
	for p in plan:
		var sec := section(String(p[0]))
		zones.append([b.x, float(p[1])])
		joint(b, bool(opts.get("checkpoints", false)))
		starts.append([b.x, String(p[0]), float(p[1])])
		for c in sec.chunks:
			b.marks.append([String(c[0]), snappedf(b.x, 1.0)])
			b.callv("c_" + String(c[0]), c.slice(1))
	joint(b, false)
	b.c_finish()
	var lv: Dictionary = b._finalize(meta)
	lv.marks = b.marks
	lv.zones = zones
	lv.stretches = starts
	lv.speed = float(plan[0][1]) if not plan.is_empty() else float(meta.get("speed", 128.0))
	gears_to_bags(lv)
	_kill_lines(lv)
	return lv


## A fall line per 256 px of course: 140 px under the lowest deck within 768 px either
## side (so a drop to any deck you could still land on is never cut short). One line for
## the whole course would sit under its deepest point, and a fall from a high stretch
## would take seconds to count.
static func _kill_lines(lv: Dictionary) -> void:
	var B := 256.0
	var x0 := -512.0
	var n := int(ceil((float(lv.finish_x) + 1200.0 - x0) / B))
	var low := PackedFloat32Array()
	low.resize(n)
	low.fill(-INF)
	for tr in lv.tracks:
		var amp := float((tr.get("lift", {}) as Dictionary).get("amp", 0.0))
		var y := -INF
		for p in tr.pts:
			y = maxf(y, p.y + amp)
		for i in range(maxi(0, int((float(tr.x0) - x0) / B)), mini(n, int((float(tr.x1) - x0) / B) + 1)):
			low[i] = maxf(low[i], y)
	var kb := PackedFloat32Array()
	kb.resize(n)
	for i in n:
		var m := -INF
		for j in range(maxi(0, i - 3), mini(n, i + 4)):
			m = maxf(m, low[j])
		kb[i] = (m if m > -INF else float(lv.kill_y) - 140.0) + 140.0
	lv.kill_by = kb
	lv.kill_x0 = x0


## The flat deck between two stretches. It eases the deck back toward its starting
## height (so a long run doesn't wander off up or down) and gives the speed room to
## change before the next stretch.
static func joint(b, checkpoint: bool) -> void:
	# Every stretch starts at deck height 0, exactly where the checker rode it (the
	# riding can come out a hair different at another height, and a marginal spot can
	# tip the other way), on a slope of at most 1 in 7.
	var dy := -float(b.y)
	b.run(40.0)
	if absf(dy) > 0.01:
		b.slope(maxf(200.0, absf(dy) * 7.0), dy)
		b.y = 0.0
	# A full second of flat deck at top speed before the next stretch (a slope here
	# can leave you settling, and some stretches open straight into a jump).
	if checkpoint:
		b.c_checkpoint(100.0)
		b.run(70.0)
	else:
		b.run(170.0)


## Gears belong to their trails (three each, paid once); here they're money bags.
static func gears_to_bags(lv: Dictionary) -> void:
	var total := 0
	for p in lv.pickups:
		if int(p.type) == Library.P_GEAR:
			p.type = Library.P_BAG
			p.value = 10
			p.erase("gear")
		total += int(p.value)
	lv.coin_total = total
	lv.gear_total = 0


## Par for a daily ride: the bot's clean time through each stretch (from the checker)
## plus the joints, start and finish at that speed, plus a second, to the half second.
static func par(plan: Array, lv: Dictionary, weather: String) -> float:
	var wi := maxi(0, ["clear", "rain", "wind"].find(weather))
	var t := 0.0
	var sec_px := 0.0
	for p in plan:
		var e := info(String(p[0]), float(p[1]))
		t += float((e.get("t", [0.0, 0.0, 0.0]) as Array)[wi])
		sec_px += float(e.get("len", 0.0))
	var rest := float(lv.finish_x) - float(lv.start_x) - sec_px
	t += maxf(0.0, rest) / float(lv.speed)
	return ceilf((t + 1.0) * 2.0) / 2.0


## Metres for a position on an endless course.
static func metres(lv: Dictionary, x: float) -> int:
	return maxi(0, int((x - float(lv.get("start_x", 40.0))) / PX_PER_M))


## The stretch you're on (index into lv.stretches), or -1 before the first.
static func stretch_at(lv: Dictionary, x: float) -> int:
	var st: Array = lv.get("stretches", [])
	var k := -1
	for i in st.size():
		if x >= float(st[i][0]):
			k = i
		else:
			break
	return k
