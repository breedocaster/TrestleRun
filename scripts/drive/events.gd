## EVENTS (in CHALLENGES): one at a time, ridden with SUMMIT's or GAUNTLET's physics on a
## course of its own, scored its own way, with bronze, silver and gold tiers that each
## pay once. Around holidays a themed one runs (PUMPKIN PATCH at Halloween, SNOW DAY at
## Christmas...); the rest of the year a new one each week, round six kinds of game:
##   LONG JUMP     one ramp: how far you fly (and ride away)
##   COLLECT       pick up as many as you can on one tank
##   TRICK ATTACK  60 seconds of kickers: air-trick points (tricks.gd)
##   TIME ATTACK   a short course, against the clock
##   LOW GRAVITY   a course on the moon, against the clock
##   LAST DROP     a nearly empty tank: how far you get
## Everyone rides on stock bikes (no SUMMIT upgrades), so the tiers mean the same for all.
## Each course is fixed (a kind, a variant), and the tiers come from the level checker
## riding it on the scrambler (event_table.gd, --event-check). All offline: the dates
## come from the phone (Challenges.today()).
extends RefCounted

const Summit := preload("res://scripts/drive/summit_levels.gd")
const Gauntlet := preload("res://scripts/drive/gauntlet_levels.gd")
const Course := preload("res://scripts/drive/course.gd")
const Table := preload("res://scripts/drive/event_table.gd")

## name, how it goes, what the score is in, which way is better, whose physics.
const KINDS := {
	"long_jump": {"name": "LONG JUMP", "how": "ONE BIG RAMP. FLY AS FAR AS YOU CAN, THEN RIDE IT OUT.",
		"unit": "M", "better": "high", "physics": "summit"},
	"collect": {"name": "COLLECT", "how": "A SHORT CLIMB. PICK UP AS MANY AS YOU CAN.",
		"unit": "", "better": "high", "physics": "summit"},
	"trick_attack": {"name": "TRICK ATTACK", "how": "60 SECONDS OF KICKERS. AIR TRICKS AND COMBOS SCORE.",
		"unit": "PTS", "better": "high", "physics": "gauntlet"},
	"time_attack": {"name": "TIME ATTACK", "how": "A SHORT COURSE AGAINST THE CLOCK. A CRASH SENDS YOU BACK.",
		"unit": "S", "better": "low", "physics": "gauntlet"},
	"moon": {"name": "LOW GRAVITY", "how": "A COURSE ON THE MOON: BIG AIR, SLOW FALLS. AGAINST THE CLOCK.",
		"unit": "S", "better": "low", "physics": "gauntlet"},
	"fuel_saver": {"name": "LAST DROP", "how": "TEN SECONDS OF FUEL AND A LONG ROLLING ROAD. HOW FAR?",
		"unit": "M", "better": "high", "physics": "summit"},
}

## Holiday events (month, day, inclusive), each its own course.
const HOLIDAYS := [
	{"id": "fireworks", "name": "FIREWORKS", "from": [1, 1], "to": [1, 7], "kind": "trick_attack", "variant": 0,
		"theme": 13, "time": "night"},
	{"id": "sweetheart", "name": "SWEETHEART RUN", "from": [2, 10], "to": [2, 16], "kind": "collect", "variant": 1,
		"item": "heart", "theme": 12, "time": "dusk"},
	{"id": "egg_hunt", "name": "EGG HUNT", "from": [3, 28], "to": [4, 10], "kind": "collect", "variant": 2,
		"item": "egg", "theme": 14, "time": "day"},
	{"id": "sparkler", "name": "SPARKLER LEAP", "from": [7, 1], "to": [7, 7], "kind": "long_jump", "variant": 1,
		"theme": 15, "time": "dusk"},
	{"id": "moon_hop", "name": "MOON HOP", "from": [7, 16], "to": [7, 24], "kind": "moon", "variant": 0,
		"theme": 10, "time": "night"},
	{"id": "pumpkin", "name": "PUMPKIN PATCH", "from": [10, 24], "to": [11, 2], "kind": "collect", "variant": 0,
		"item": "pumpkin", "theme": 14, "time": "night"},
	{"id": "snow_day", "name": "SNOW DAY", "from": [12, 18], "to": [12, 31], "kind": "time_attack", "variant": 3,
		"theme": 8, "time": "day", "grip": 0.7},
]
## The weekly ones, in turn; each kind has VARIANTS courses, used a turn at a time.
const ROTATION := ["long_jump", "time_attack", "trick_attack", "fuel_saver", "collect"]
const VARIANTS := 3
const WEEK_THEMES := [1, 6, 9, 4, 12, 2, 15, 0, 14, 7, 10, 3]
## [coins, season XP] for bronze, silver, gold.
const PAY := [[100, 30], [200, 60], [400, 100]]

## The courses. GAUNTLET-physics kinds are move lists (gauntlet_levels.gd's moves).
const TIME_COURSES := [
	[["f", 120], ["s", 5], ["f", 60], ["l", 4, 40], ["f", 60], ["k", 40, 10], ["p", 30, 0], ["f", 80], ["cp"],
		["c", 16, 5, 40], ["f", 60], ["sl", 60, 20], ["f", 30], ["s", -20], ["f", 60], ["t", 6, 40], ["f", 60]],
	[["f", 120], ["w", 3, 50, 8], ["f", 40], ["s", 6], ["f", 50], ["s", -6], ["f", 60], ["cp"],
		["sl", 70, -24], ["f", 40], ["k", 44, 12], ["p", 40, 0], ["f", 80], ["l", 5, 40], ["f", 60]],
	[["f", 120], ["st", 3, 5, 32], ["f", 40], ["s", -15], ["f", 60], ["c", 18, 6, 40], ["f", 60], ["cp"],
		["h", 80, 14], ["f", 40], ["k", 40, 12], ["p", 36, 0], ["f", 80], ["m", 16, 48, 30, 30], ["f", 60]],
	# SNOW DAY: gentler, the grip's the problem.
	[["f", 120], ["h", 70, 8], ["f", 50], ["s", 4], ["f", 60], ["sl", 70, -20], ["f", 50], ["cp"],
		["sl", 60, 18], ["f", 40], ["s", -18], ["f", 60], ["w", 3, 50, 6], ["f", 50], ["l", 4, 40], ["f", 80]],
]
## (At 0.4 g the tyres grip at 0.4 of the weight too, so the run-ups are long: a short
## one into the last kicker left the checker short of a 110 px pit.)
const MOON_COURSES := [
	[["f", 120], ["k", 40, 12], ["p", 60, 0], ["f", 60], ["t", 8, 50], ["f", 50], ["s", -8], ["f", 50], ["cp"],
		["k", 50, 16], ["p", 90, 10], ["f", 60], ["st", 3, 8, 40], ["f", 40], ["s", -24], ["f", 60], ["cp"],
		["f", 80], ["sl", 80, -30], ["k", 50, 18], ["p", 80, 0], ["f", 80]],
]
## (Big kickers onto downhill landings: the checker's ride is in the air 0.5-0.7 s off
## them, room for a trick each.)
const TRICK_COURSES := [
	[["f", 140], ["sl", 90, -34], ["k", 56, 26], ["p", 64, -30], ["sl", 90, -40], ["f", 60],
		["sl", 90, -34], ["k", 56, 26], ["p", 64, -30], ["sl", 90, -40], ["f", 60], ["cp"],
		["h", 80, 16], ["sl", 90, -34], ["k", 56, 26], ["p", 64, -30], ["sl", 90, -40], ["f", 60],
		["sl", 90, -34], ["k", 56, 26], ["p", 64, -30], ["sl", 90, -40], ["f", 60], ["cp"],
		["sl", 100, -40], ["k", 58, 28], ["p", 70, -32], ["sl", 90, -40], ["f", 80]],
	[["f", 140], ["sl", 100, -38], ["k", 56, 26], ["p", 64, -30], ["sl", 90, -40], ["f", 50],
		["h", 70, 14], ["sl", 90, -34], ["k", 54, 24], ["p", 60, -26], ["sl", 80, -34], ["f", 60], ["cp"],
		["sl", 100, -38], ["k", 56, 26], ["p", 64, -30], ["sl", 90, -40], ["f", 50],
		["sl", 90, -34], ["k", 56, 26], ["p", 64, -30], ["sl", 90, -40], ["f", 80]],
	[["f", 140], ["sl", 110, -44], ["k", 58, 28], ["p", 70, -32], ["sl", 100, -44], ["f", 60], ["cp"],
		["sl", 90, -34], ["k", 56, 26], ["p", 64, -30], ["sl", 90, -40], ["f", 40],
		["sl", 110, -44], ["k", 58, 28], ["p", 70, -32], ["sl", 100, -44], ["f", 60], ["cp"],
		["w", 3, 50, 10], ["sl", 90, -34], ["k", 56, 26], ["p", 64, -30], ["sl", 90, -40], ["f", 80]],
]
## LONG JUMP: [run-in length, its drop, ramp length, ramp height].
const JUMP_RAMPS := [[360.0, 120.0, 56.0, 30.0], [440.0, 160.0, 60.0, 34.0], [300.0, 100.0, 48.0, 26.0]]
## COLLECT and LAST DROP: the climb's look (summit_levels.gd's level fields). (No kicker
## gaps: on a stock bike the checker couldn't clear SUMMIT's 64 px ones.)
const CLIMBS := [
	{"m": 600, "climb": 60.0, "amp": 30.0, "up": 18.0, "down": 22.0, "bump": 0.2, "bridges": 0, "gaps": 0, "fuel": 280},
	{"m": 650, "climb": 50.0, "amp": 40.0, "up": 20.0, "down": 24.0, "bump": 0.3, "bridges": 1, "gaps": 0, "fuel": 300},
	{"m": 700, "climb": 60.0, "amp": 36.0, "up": 22.0, "down": 24.0, "bump": 0.4, "bridges": 1, "gaps": 0, "fuel": 320,
		"difficulty": 1},
]
const DROP_ROADS := [
	{"m": 1600, "climb": 0.0, "amp": 60.0, "up": 14.0, "down": 18.0, "bump": 0.1, "bridges": 0, "gaps": 0, "fuel": 9999},
	{"m": 1600, "climb": -10.0, "amp": 80.0, "up": 16.0, "down": 20.0, "bump": 0.2, "bridges": 1, "gaps": 0, "fuel": 9999},
	{"m": 1600, "climb": 10.0, "amp": 50.0, "up": 12.0, "down": 16.0, "bump": 0.1, "bridges": 0, "gaps": 0, "fuel": 9999},
]
const DROP_TANK := 10.0
const TRICK_TIME := 60.0
const ITEMS := {"pumpkin": "PUMPKINS", "heart": "HEARTS", "egg": "EGGS", "star": "STARS"}


static func _epoch_unix() -> int:
	return int(Time.get_unix_time_from_datetime_dict({"year": 2026, "month": 10, "day": 19, "hour": 12, "minute": 0, "second": 0}))


## The calendar date of a Challenges day number.
static func date_of(day: int) -> Dictionary:
	return Time.get_date_dict_from_unix_time(_epoch_unix() + day * 86400)


static func _md(d: Dictionary) -> int:
	return int(d.month) * 100 + int(d.day)


## The event on a day (default: today): {"key" (this run of it, for the save), "id" (its
## course, for the tiers), "name", "kind", "variant", "theme", "time", "item", "grip",
## "days_left", "holiday"}.
static func current(day := -999) -> Dictionary:
	var t: int = Challenges.today() if day == -999 else day
	var d := date_of(t)
	for h in HOLIDAYS:
		var a := int(h.from[0]) * 100 + int(h.from[1])
		var b := int(h.to[0]) * 100 + int(h.to[1])
		if _md(d) >= a and _md(d) <= b:
			var left := 1
			while _md(date_of(t + left)) <= b and _md(date_of(t + left)) >= a:
				left += 1
			var ev: Dictionary = h.duplicate()
			ev.key = "h:%s:%d" % [h.id, int(d.year)]
			ev.days_left = left
			ev.holiday = true
			return ev
	var w := floori(t / 7.0)
	var kind: String = ROTATION[posmod(w, ROTATION.size())]
	var v := posmod(floori(w / float(ROTATION.size())), VARIANTS)
	var names := {"long_jump": ["BIG AIR", "CANYON LEAP", "HOP SCOTCH"],
		"time_attack": ["QUICK LAP", "SPRINT", "SHORTCUT"], "trick_attack": ["SHOWTIME", "STUNT SHOW", "DAREDEVIL"],
		"fuel_saver": ["LAST DROP", "FUMES", "RUNNING ON EMPTY"], "collect": ["STAR HUNT", "STARGAZER", "SHOOTING STARS"]}
	return {"key": "w:%d" % w, "id": "%s_%d" % [kind, v], "name": String(names[kind][v]), "kind": kind,
		"variant": v, "theme": int(WEEK_THEMES[posmod(w, WEEK_THEMES.size())]), "time": ["day", "dusk", "day"][v],
		"item": "star", "days_left": 7 - posmod(t, 7), "holiday": false}


## Every event course (for the checker): the rotation's and the holidays'.
static func all_courses() -> Array:
	var out := []
	for kind in ROTATION:
		for v in VARIANTS:
			out.append({"key": "check", "id": "%s_%d" % [kind, v], "name": "%s %d" % [kind, v], "kind": kind,
				"variant": v, "theme": 0, "time": "day", "item": "star", "days_left": 7, "holiday": false})
	for h in HOLIDAYS:
		var ev: Dictionary = h.duplicate()
		ev.key = "check"
		ev.days_left = 1
		ev.holiday = true
		out.append(ev)
	return out


static func physics(ev: Dictionary) -> String:
	return String(KINDS[ev.kind].physics)


## The course as a level dict for drive_world.gd, with its rules in lv.event and any
## change to the bike's physics in lv.mods (vehicles.gd apply_mods).
static func build(ev: Dictionary) -> Dictionary:
	var kind := String(ev.kind)
	var v := int(ev.get("variant", 0))
	var meta := {"id": "ev_" + String(ev.id), "name": String(ev.name), "theme": int(ev.theme), "time": String(ev.time)}
	var lv: Dictionary
	var rules := {"kind": kind}
	match kind:
		"long_jump":
			var r: Array = JUMP_RAMPS[clampi(v, 0, JUMP_RAMPS.size() - 1)]
			var c = Course.new()
			c.flat(420.0)
			c.slope(float(r[0]), -float(r[1]))
			c.flat(80.0)
			c.kicker(float(r[2]), float(r[3]))
			rules.lip_x = c.x
			c.flat(1800.0)
			lv = c.finish(meta)
			lv.finish_x = float(rules.lip_x) + 1700.0
			lv.mode = "summit"
		"time_attack", "moon", "trick_attack":
			var pool: Array = TIME_COURSES if kind == "time_attack" else (MOON_COURSES if kind == "moon" else TRICK_COURSES)
			lv = Gauntlet.build(0, pool[clampi(v, 0, pool.size() - 1)], meta)
			lv.mode = "gauntlet"
			if kind == "trick_attack":
				rules.time_limit = TRICK_TIME
		"collect", "fuel_saver":
			var spec: Dictionary = (CLIMBS if kind == "collect" else DROP_ROADS)[clampi(v, 0, 2)].duplicate()
			spec.merge(meta, true)
			spec.up_req = [0, 0, 0, 0]
			# (The level index picks the seeds; difficulty the walls and ramps: COLLECT
			# gets one of each, as on climb 3; LAST DROP none.)
			spec.difficulty = int(spec.get("difficulty", 2)) if kind == "collect" else 0
			lv = Summit.build(40 + v if kind == "collect" else 50 + v, spec)
			lv.id = meta.id
			lv.name = meta.name
			if kind == "collect":
				# The climb's coins become the things to collect.
				lv.items = (lv.coins as Array).map(func(c): return c[0])
				lv.coins = []
				rules.item = String(ev.get("item", "star"))
			else:
				lv.fuel = []
				rules.tank = DROP_TANK
	lv.event = rules
	var mods := {}
	if kind == "moon":
		mods.gravity = 0.4
	if ev.has("grip"):
		mods.grip = float(ev.grip)
	lv.mods = mods
	return lv


## The score in a finished ride's result (drive_world.gd puts it there), or null if
## the ride didn't score.
static func score_of(ev: Dictionary, r: Dictionary):
	return r.get("score", null)


static func better(ev: Dictionary, a: float, b: float) -> bool:
	return a > b if String(KINDS[ev.kind].better) == "high" else a < b


## [bronze, silver, gold] for an event's course.
static func tiers(ev: Dictionary) -> Array:
	return Table.TIERS.get(String(ev.id), [])


## How many tiers a score reaches.
static func tier_of(ev: Dictionary, score: float) -> int:
	var t := tiers(ev)
	var n := 0
	for k in t.size():
		if String(KINDS[ev.kind].better) == "high" and score >= float(t[k]):
			n = k + 1
		elif String(KINDS[ev.kind].better) == "low" and score <= float(t[k]):
			n = k + 1
	return n


static func fmt(ev: Dictionary, score: float) -> String:
	match String(ev.kind):
		"long_jump":
			return "%.1f M" % score
		"fuel_saver":
			return "%d M" % int(score)
		"time_attack", "moon":
			return "%.2fS" % score
		"trick_attack":
			return "%d PTS" % int(score)
		"collect":
			return "%d %s" % [int(score), String(ITEMS.get(String(ev.get("item", "star")), "STARS"))]
	return str(score)


# --- the save ------------------------------------------------------------------------

static func record(ev: Dictionary) -> Dictionary:
	var c: Dictionary = Challenges.data()
	if not c.has("events"):
		c.events = {}
	var all: Dictionary = c.events
	if not all.has(String(ev.key)):
		all[String(ev.key)] = {"best": null, "paid": 0}
	return all[String(ev.key)]


## Bank a ride: {"score", "new_best", "tier", "new_tiers" (how many paid now), "coins"}.
static func record_result(ev: Dictionary, r: Dictionary) -> Dictionary:
	var rec := record(ev)
	var sc = score_of(ev, r)
	var out := {"score": sc, "new_best": false, "tier": 0, "new_tiers": 0, "coins": 0}
	if sc == null:
		return out
	if rec.best == null or better(ev, float(sc), float(rec.best)):
		rec.best = sc
		out.new_best = true
	var tier := tier_of(ev, float(rec.best))
	out.tier = tier
	var paid := int(rec.paid)
	for k in range(paid, tier):
		GameState.add_money(int(PAY[k][0]))
		Challenges.add_xp(int(PAY[k][1]))
		out.coins = int(out.coins) + int(PAY[k][0])
	out.new_tiers = maxi(0, tier - paid)
	rec.paid = maxi(paid, tier)
	GameState.save_game()
	return out
