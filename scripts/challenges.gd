## Autoload: the things that come round on the calendar. The daily ride, three daily
## missions and the login streak; endless records; the weekly league (a 20-rider group
## on the week's endless line, five divisions); the season pass (three weeks per season,
## each in one trail's look); and the cheats. All offline: days, weeks and seasons come
## from the phone's date, and the league's other riders are computer rivals modelled on
## the course (see rival_best). State lives in GameState.data.challenges.
extends CanvasLayer

const Catalog := preload("res://scripts/catalog.gd")
const Endless := preload("res://scripts/game/endless.gd")
const UITheme := preload("res://scripts/ui/ui_theme.gd")

## Day 0 of week 0 and season 0: Monday 19 October 2026.
const EPOCH := {"year": 2026, "month": 10, "day": 19}
const WEEKDAYS := ["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY", "SUNDAY"]

# --- streak ---
## Coins for day 1..7 of a streak (then it goes round again).
const STREAK_COINS := [25, 40, 60, 80, 100, 125, 200]
const STREAK_XP := 20

# --- daily ---
## The daily ride's speed by weekday: easy Monday, quickest at the weekend.
const DAILY_TIERS := [118.0, 130.0, 130.0, 142.0, 142.0, 154.0, 154.0]
const DAILY_COINS := 100
const DAILY_XP := 60
const DAILY_GOLD_XP := 40

# --- missions ---
## [stat, text (%d = goal), goals, kind]: add = counts up; max = best single run.
const MISSIONS := [
	["flips", "LAND %d FLIPS", [3, 5], "add"],
	["stomps", "STOMP %d CRITTERS", [6, 12], "add"],
	["coins", "COLLECT %d COINS", [150, 300], "add"],
	["rails", "GRIND %d RAILS", [3, 6], "add"],
	["ropes", "SWING ON %d ROPES", [2, 4], "add"],
	["walls", "RIDE %d WALLS", [2, 4], "add"],
	["zips", "RIDE %d ZIPLINES", [3, 6], "add"],
	["powerups", "GRAB %d POWER-UPS", [3, 5], "add"],
	["endless_best", "RIDE %d M IN ONE ENDLESS RUN", [600, 1200], "max"],
	["endless_total", "RIDE %d M IN ENDLESS", [1500, 3000], "add"],
	["clean", "CLEAR A TRAIL WITHOUT CRASHING", [1], "add"],
	["daily", "FINISH TODAY'S DAILY RIDE", [1], "add"],
	["planes", "CATCH A PRIZE SACK", [1], "add"],
	["tricks_run", "LAND %d TRICKS IN ONE RUN", [4, 6], "max"],
	["letters", "FIND ALL OF T-R-E-S-T-L-E", [1], "add"],
	["clears", "CLEAR %d TRAILS", [2, 3], "add"],
	["air_tricks", "LAND %d AIR TRICKS IN SUMMIT OR GAUNTLET", [2, 4], "add"],
	["event_ride", "RIDE THIS WEEK'S EVENT", [1], "add"],
]
const MISSION_COINS := 40
const MISSION_XP := 40
const MISSIONS_ALL_COINS := 50
const MISSIONS_ALL_XP := 60

# --- season ---
const SEASON_DAYS := 21
## The trail look of each season in turn (Backdrop theme index).
const SEASON_THEMES := [1, 12, 8, 14, 6, 13, 0, 15, 4, 9, 2, 10, 3, 7, 5, 11]
const SEASON_TIERS := 30
const TIER_XP := 100
## The gold track. Coins for now: real money needs the store billing plugins and
## accounts (next phase), then this becomes a purchase.
const GOLD_PRICE := 1500
## Tiers that give a season paint: [tier, paint slot] on each track.
const FREE_PAINTS := [[10, 0], [20, 1]]
const GOLD_PAINTS := [[5, 2], [15, 3], [30, 4]]

# --- league ---
const DIVISIONS := ["DIRT", "GRAVEL", "TIMBER", "IRON", "GOLDEN SPIKE"]
const GROUP := 20
const PROMOTE := 5
## Rivals per division: how often one fumbles a forced jump whose timing window is
## 75 ms (the tightest the endless lines use); a wider window w goes wrong
## slip * 75 / w of the time. Lower is sharper. See rival_best.
## Calibrated with tools/endless/league_calibrate.py so a group's middle rider ends the
## week near 1.2 km in DIRT, 2.2 in GRAVEL, 3.5 in TIMBER, 5.5 in IRON, 8.5 in GOLDEN SPIKE.
const RIVAL_SLIP := [[0.35, 0.6], [0.2, 0.3], [0.13, 0.19], [0.085, 0.12], [0.05, 0.08]]
## ...and a chance per stretch of a slip that has nothing to do with timing.
const RIVAL_HAZARD := 0.004
## Weekly rewards by finishing place: [up to place, coins, xp].
const LEAGUE_REWARDS := [[1, 600, 300], [3, 350, 200], [10, 150, 100], [20, 50, 50]]
const RIVAL_NAMES := ["GRAVEL GUS", "MESA MAVIS", "RUSTY BOLT", "DUSTDEVIL DEE", "TUMBLEWEED TOM",
	"CACTUS KATE", "SPOKES MCGEE", "LUGNUT LOU", "SADDLE SAL", "HOLLER HANK", "PISTON PETE",
	"BRAKES BETTY", "KICKSTAND KAY", "SPROCKET SAM", "MUDFLAP MO", "WHEELIE WANDA", "THROTTLE TESS",
	"RAMBLIN ROY", "COYOTE CAL", "BUCKSHOT BEA", "GULCH GRADY", "TRESTLE TRIX", "HAYSEED HAL",
	"CANYON CORA", "DYNAMO DOT", "FENCEPOST FRED", "LOCO LENNY", "BOOTS BAXTER", "PRAIRIE PEG",
	"CHROME CHARLIE", "DIESEL DAISY", "SIDECAR SID"]

var _toast: Control
var _toasts: Array = []
var _toast_t := 0.0
## Set by --today=YYYY-MM-DD (dev): pretend it's that day.
var _today_override := -1


func _ready() -> void:
	layer = 51
	process_mode = Node.PROCESS_MODE_ALWAYS
	_toast = Notice.new()
	_toast.visible = false
	add_child(_toast)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--today="):
			var p := a.substr(8).split("-")
			_today_override = _day_number(int(p[0]), int(p[1]), int(p[2]))
	apply_cheats()


func data() -> Dictionary:
	if not GameState.data.has("challenges"):
		GameState.data.challenges = {}
	var c: Dictionary = GameState.data.challenges
	for k in ["streak", "missions", "daily", "endless", "league", "season", "cheats"]:
		if not c.has(k):
			c[k] = {}
	return c


# --- the calendar ------------------------------------------------------------------

static func _day_number(y: int, m: int, d: int) -> int:
	return int(Time.get_unix_time_from_datetime_dict({"year": y, "month": m, "day": d, "hour": 12,
		"minute": 0, "second": 0}) / 86400)


## Days since the epoch, by the phone's local date.
func today() -> int:
	if _today_override >= 0:
		return _today_override - _epoch()
	var d := Time.get_date_dict_from_system()
	return _day_number(int(d.year), int(d.month), int(d.day)) - _epoch()


static func _epoch() -> int:
	return _day_number(int(EPOCH.year), int(EPOCH.month), int(EPOCH.day))


func weekday() -> int:
	return posmod(today(), 7)


func week() -> int:
	return floori(today() / 7.0)


func season() -> int:
	return maxi(0, floori(today() / float(SEASON_DAYS)))


func season_theme(s := -1) -> int:
	return int(SEASON_THEMES[posmod(season() if s < 0 else s, SEASON_THEMES.size())])


func season_name(s := -1) -> String:
	var i := season() if s < 0 else s
	return "SEASON %d: %s" % [i + 1, Catalog.theme_name(season_theme(i))]


func season_days_left() -> int:
	return SEASON_DAYS - posmod(today(), SEASON_DAYS)


func week_days_left() -> int:
	return 7 - weekday()


func _rng(tag: String, n: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash("%s:%d" % [tag, n])
	return r


# --- login streak ----------------------------------------------------------------

## Call when the title screen opens. Returns the streak day if there's a reward to show.
func check_in() -> int:
	var st: Dictionary = data().streak
	var t := today()
	var last := int(st.get("last", -999))
	if last == t:
		return int(st.count) if int(st.get("claimed", -999)) != t else 0
	st.count = int(st.get("count", 0)) + 1 if last == t - 1 else 1
	st.last = t
	GameState.save_game()
	Achievements.record_max("best_streak", int(st.count))
	return int(st.count)


func streak_count() -> int:
	var st: Dictionary = data().streak
	var t := today()
	var last := int(st.get("last", -999))
	return int(st.get("count", 0)) if last >= t - 1 else 0


static func streak_coins(day: int) -> int:
	return int(STREAK_COINS[posmod(day - 1, STREAK_COINS.size())])


func claim_streak() -> int:
	var st: Dictionary = data().streak
	if int(st.get("claimed", -999)) == today() or int(st.get("last", -999)) != today():
		return 0
	st.claimed = today()
	var coins := streak_coins(int(st.count))
	GameState.add_money(coins)
	add_xp(STREAK_XP)
	GameState.save_game()
	return coins


# --- the daily ride -------------------------------------------------------------------

## Today's course: {"day", "name", "tier", "time", "weather", "theme", "plan", "seed"}.
func daily() -> Dictionary:
	var d := today()
	var r := _rng("daily", d)
	var wx := "clear"
	var roll := r.randf()
	if roll > 0.75:
		wx = "wind"
	elif roll > 0.5:
		wx = "rain"
	var time: String = ["day", "dusk", "night"][r.randi_range(0, 2)]
	var theme := r.randi_range(0, SEASON_THEMES.size() - 1)
	var tier: float = DAILY_TIERS[posmod(d, 7)]
	var seed := r.randi()
	return {"day": d, "name": "%s RIDE" % WEEKDAYS[posmod(d, 7)], "tier": tier, "time": time, "weather": wx,
		"theme": theme, "plan": Endless.daily_plan(seed, tier, wx), "seed": seed}


func daily_record() -> Dictionary:
	var dr: Dictionary = data().daily
	if int(dr.get("day", -999)) != today():
		dr.clear()
		dr.day = today()
		dr.cleared = false
		dr.gold = false
		dr.best = 0.0
	return dr


# --- missions -------------------------------------------------------------------------

## Today's three missions: [{"stat", "text", "goal", "kind", "prog", "done"}].
func missions() -> Array:
	var m: Dictionary = data().missions
	if int(m.get("day", -999)) != today():
		m.day = today()
		m.bonus = false
		var r := _rng("missions", today())
		var pool := range(MISSIONS.size())
		var list := []
		while list.size() < 3 and not pool.is_empty():
			var k: int = pool.pop_at(r.randi_range(0, pool.size() - 1))
			var spec: Array = MISSIONS[k]
			var goals: Array = spec[2]
			var goal := int(goals[r.randi_range(0, goals.size() - 1)])
			var text := String(spec[1]) % goal if String(spec[1]).contains("%d") else String(spec[1])
			list.append({"stat": spec[0], "text": text, "goal": goal, "kind": spec[3], "prog": 0, "done": false})
		m.list = list
		GameState.save_game()
	return m.list


## Something happened that a mission might count (also fed by the world's stat hooks).
func on_stat(stat: String, n := 1) -> void:
	var changed := false
	for ms in missions():
		if ms.done or String(ms.stat) != stat:
			continue
		if String(ms.kind) == "max":
			ms.prog = maxi(int(ms.prog), n)
		else:
			ms.prog = int(ms.prog) + n
		changed = true
		if int(ms.prog) >= int(ms.goal):
			ms.prog = int(ms.goal)
			ms.done = true
			GameState.add_money(MISSION_COINS)
			add_xp(MISSION_XP)
			notice("MISSION DONE!", "%s  +%d" % [String(ms.text), MISSION_COINS])
	var m: Dictionary = data().missions
	if changed and not bool(m.get("bonus", false)) and missions().all(func(x): return bool(x.done)):
		m.bonus = true
		GameState.add_money(MISSIONS_ALL_COINS)
		add_xp(MISSIONS_ALL_XP)
		notice("ALL THREE MISSIONS!", "+%d COINS  +%d XP" % [MISSIONS_ALL_COINS, MISSIONS_ALL_XP])
		Achievements.unlock("missions_all")
	# No save here: this runs on every stomp and grind. The run's end saves (and a
	# finished mission already did, when it paid out).


# --- season pass ------------------------------------------------------------------------

func _season_state() -> Dictionary:
	var s: Dictionary = data().season
	if int(s.get("id", -1)) != season():
		s.clear()
		s.id = season()
		s.xp = 0
		s.free = []
		s.gold_claimed = []
		s.gold = false
	elif not _ints_done:
		# The save is JSON, so claimed tiers come back as floats; make them ints again.
		s.free = (s.free as Array).map(func(v): return int(v))
		s.gold_claimed = (s.gold_claimed as Array).map(func(v): return int(v))
	_ints_done = true
	return s


var _ints_done := false


func season_xp() -> int:
	return int(_season_state().xp)


func season_tier() -> int:
	return mini(SEASON_TIERS, season_xp() / TIER_XP)


func has_gold() -> bool:
	return bool(_season_state().gold)


func add_xp(n: int) -> void:
	if n <= 0:
		return
	var before := season_tier()
	_season_state().xp = season_xp() + n
	if season_tier() > before:
		notice("SEASON TIER %d!" % season_tier(), "REWARDS WAITING ON THE SEASON PASS")
		if season_tier() >= SEASON_TIERS:
			Achievements.unlock("season_30")


## The reward at a tier on a track: {"coins": n} or {"paint": id}.
func reward(tier: int, gold: bool) -> Dictionary:
	for e in (GOLD_PAINTS if gold else FREE_PAINTS):
		if int(e[0]) == tier:
			return {"paint": Catalog.season_paint_id(season_theme(), int(e[1]))}
	if gold:
		return {"coins": 60 + 10 * (tier / 5) * 2}
	return {"coins": 25 + 5 * (tier / 5)}


func claimed(tier: int, gold: bool) -> bool:
	return tier in (_season_state().gold_claimed if gold else _season_state().free)


func can_claim(tier: int, gold: bool) -> bool:
	return tier <= season_tier() and not claimed(tier, gold) and (not gold or has_gold())


func claim(tier: int, gold: bool) -> Dictionary:
	if not can_claim(tier, gold):
		return {}
	var rw := reward(tier, gold)
	(_season_state().gold_claimed if gold else _season_state().free).append(tier)
	if rw.has("paint"):
		if GameState.owns("paint", String(rw.paint)):
			rw = {"coins": 150}  # a repeat season: you have it already
		else:
			(GameState.data.paint_owned as Array).append(String(rw.paint))
	if rw.has("coins"):
		GameState.add_money(int(rw.coins))
	GameState.save_game()
	return rw


func claimable() -> int:
	var n := 0
	for t in range(1, season_tier() + 1):
		if can_claim(t, false):
			n += 1
		if can_claim(t, true):
			n += 1
	return n


func buy_gold() -> bool:
	if has_gold() or not GameState.spend(GOLD_PRICE):
		return false
	_season_state().gold = true
	GameState.save_game()
	return true


# --- endless ---------------------------------------------------------------------------

func endless_best() -> int:
	return int(data().endless.get("best_m", 0))


# --- weekly league ------------------------------------------------------------------------

func _league_state() -> Dictionary:
	var l: Dictionary = data().league
	if not l.has("week"):
		l.week = week()
		l.div = 0
		l.best_m = 0
		l.runs = 0
	return l


func division() -> int:
	return int(_league_state().div)


var _course_cache := {}


## The league's weekly line (same for every phone): its plan and look.
func league_course(w := -1) -> Dictionary:
	var wk := week() if w < 0 else w
	if _course_cache.has(wk):
		return _course_cache[wk]
	_course_cache[wk] = _league_course(wk)
	return _course_cache[wk]


func _league_course(wk: int) -> Dictionary:
	var r := _rng("league", wk)
	var time: String = ["day", "dusk", "night"][r.randi_range(0, 2)]
	var theme := season_theme(maxi(0, floori(wk * 7 / float(SEASON_DAYS))))
	return {"week": wk, "time": time, "theme": theme, "seed": r.randi(),
		"plan": Endless.endless_plan(r.randi(), Endless.ENDLESS_STRETCHES)}


var _stand_key := ""
var _stand: Array = []


## This week's group: [{"name", "rider", "m", "you"}], best first.
func standings(w := -1, final := false) -> Array:
	var l := _league_state()
	var wk := week() if w < 0 else w
	var div := int(l.div)
	var key := "%d:%d:%d:%d:%s:%s" % [wk, div, today(), int(l.best_m), final, GameState.equipped("rider")]
	if key == _stand_key:
		return _stand.duplicate(true)
	_stand_key = key
	_stand = _standings(wk, div, final, int(l.best_m))
	return _stand.duplicate(true)


func _standings(wk: int, div: int, final: bool, mine: int) -> Array:
	var course := league_course(wk)
	var r := _rng("rivals:%d" % div, wk)
	var names := RIVAL_NAMES.duplicate()
	var riders := Catalog.riders()
	var out := []
	# Rivals ride a few times a day; by the end of the week they've had their go.
	var day := 6 if final else posmod(today(), 7) if wk == week() else 6
	for i in GROUP - 1:
		var name: String = names.pop_at(r.randi_range(0, names.size() - 1))
		var sl: Array = RIVAL_SLIP[div]
		var slip := r.randf_range(float(sl[0]), float(sl[1]))
		var tries := 1 + day  # a run a day, about
		var seed := r.randi()
		out.append({"name": name, "rider": String(riders[r.randi_range(0, riders.size() - 1)].id),
			"m": rival_best(course.plan, slip, seed, tries), "you": false})
	out.append({"name": "YOU", "rider": GameState.equipped("rider"), "m": mine, "you": true})
	out.sort_custom(func(a, b): return int(a.m) > int(b.m) or (int(a.m) == int(b.m) and bool(a.you)))
	return out


func league_rank() -> int:
	var st := standings()
	for i in st.size():
		if bool(st[i].you):
			return i + 1
	return GROUP


## A rival's best distance from `tries` runs at the week's line. Each forced jump in a
## stretch (the timing windows the careful rider measured there) goes wrong with a
## chance that grows as its window narrows, plus a small slip chance per stretch, so
## rivals go farther on an easier week, like you do, and less far as it speeds up.
static func rival_best(plan: Array, slip: float, seed: int, tries: int) -> int:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var best := 0
	for k in tries:
		var x := 0.0
		for p in plan:
			var e := Endless.info(String(p[0]), float(p[1]))
			var len_m := float(e.get("len", 1500.0)) / Endless.PX_PER_M
			var fell := -1.0
			var ws: Array = e.get("w", [])
			for j in ws.size():
				var f := 75.0 / maxf(16.0, float(ws[j]))
				if r.randf() < minf(0.9, slip * f):
					fell = clampf((j + r.randf()) / float(ws.size() + 1), 0.0, 1.0)
					break
			if fell < 0.0 and r.randf() < RIVAL_HAZARD:
				fell = r.randf()
			if fell >= 0.0:
				x += len_m * fell
				break
			x += len_m + 30.0
		best = maxi(best, int(x))
	return best


## Last week's result if it hasn't been shown yet (and mark it shown).
func week_result() -> Dictionary:
	roll_week()
	var last: Dictionary = _league_state().get("last", {})
	if last.is_empty() or bool(last.get("shown", true)):
		return {}
	last.shown = true
	GameState.save_game()
	return last


## A new week: settle last week's group (place, reward, up or down a division).
## Returns {} or {"week", "rank", "coins", "xp", "from", "to"}.
func roll_week() -> Dictionary:
	var l := _league_state()
	if int(l.week) == week():
		return {}
	var res := {}
	if int(l.runs) > 0:
		var st := standings(int(l.week), true)
		var rank := GROUP
		for i in st.size():
			if bool(st[i].you):
				rank = i + 1
		var coins := 0
		var xp := 0
		for rw in LEAGUE_REWARDS:
			if rank <= int(rw[0]):
				coins = int(rw[1])
				xp = int(rw[2])
				break
		var from := int(l.div)
		var to := from
		if rank <= PROMOTE:
			to = mini(from + 1, DIVISIONS.size() - 1)
		elif rank > GROUP - PROMOTE:
			to = maxi(from - 1, 0)
		GameState.add_money(coins)
		add_xp(xp)
		res = {"week": int(l.week), "rank": rank, "coins": coins, "xp": xp, "from": from, "to": to, "shown": false}
		l.div = to
		l.last = res
		if to > from:
			Achievements.unlock("league_up")
		if rank == 1:
			Achievements.unlock("league_win")
		Achievements.record_max("best_div", to)
	l.week = week()
	l.best_m = 0
	l.runs = 0
	GameState.save_game()
	return res


# --- after every run ------------------------------------------------------------------------

## mode: "" (Free Ride / story), "endless", "daily", "league". Returns lines for the
## results screen ([text, colour]).
func on_run(r: Dictionary, mode: String) -> Array:
	var lines := []
	var xp := 10
	on_stat("coins", int(r.get("coins", 0)))
	on_stat("tricks_run", int(r.get("tricks", 0)))
	if mode == "endless" or mode == "league":
		var m := int(r.get("metres", 0))
		xp += mini(80, m / 40)
		var e: Dictionary = data().endless
		e.runs = int(e.get("runs", 0)) + 1
		e.total_m = int(e.get("total_m", 0)) + m
		if mode == "endless" and m > int(e.get("best_m", 0)):
			e.best_m = m
			lines.append(["NEW BEST DISTANCE!", UITheme.GOLD])
		e.best_any = maxi(int(e.get("best_any", 0)), m)  # endless or league
		Achievements.recount("endless_m")
		on_stat("endless_best", m)
		on_stat("endless_total", m)
		if mode == "league":
			roll_week()
			var l := _league_state()
			l.runs = int(l.runs) + 1
			if m > int(l.best_m):
				l.best_m = m
				lines.append(["NEW BEST THIS WEEK!", UITheme.GOLD])
	else:
		xp += 10
		on_stat("clears")
		if int(r.get("crashes", 0)) == 0:
			on_stat("clean")
		if bool(r.get("letters_all", false)):
			on_stat("letters")
		var wx := String((r.get("conditions", {}) as Dictionary).get("weather", "clear"))
		lines.append_array(_check_cheats(String(r.get("level_id", "")), wx, float(r.get("time", 0.0))))
	if mode == "daily":
		var dr := daily_record()
		var t := float(r.get("time", 0.0))
		if not bool(dr.cleared):
			dr.cleared = true
			GameState.add_money(DAILY_COINS)
			xp += DAILY_XP
			lines.append(["DAILY RIDE DONE!", UITheme.GOLD])
			on_stat("daily")
			Achievements.add("daily_clears")
		if int(r.get("crashes", 0)) == 0 and t <= float(r.get("par", 0.0)) and not bool(dr.gold):
			dr.gold = true
			xp += DAILY_GOLD_XP
			lines.append(["UNDER PAR! +%d XP" % DAILY_GOLD_XP, UITheme.GOLD])
		if float(dr.best) <= 0.0 or t < float(dr.best):
			dr.best = t
	add_xp(xp)
	lines.append(["+%d SEASON XP" % xp, Color("9fe8ff")])
	GameState.save_game()
	return lines


# --- cheats ---------------------------------------------------------------------------------

static func cheat(id: String) -> Array:
	for c in Catalog.CHEATS:
		if c[0] == id:
			return c
	return []


func cheat_unlocked(id: String) -> bool:
	return id in (data().cheats.get("unlocked", []) as Array)


func cheat_on(id: String) -> bool:
	return cheat_unlocked(id) and id in (data().cheats.get("on", []) as Array)


func set_cheat(id: String, on: bool) -> void:
	var c: Dictionary = data().cheats
	var list: Array = c.get("on", [])
	list.erase(id)
	if on and cheat_unlocked(id):
		list.append(id)
	c.on = list
	GameState.save_game()
	apply_cheats()


## Push the cosmetic cheats to where they're drawn.
func apply_cheats() -> void:
	load("res://scripts/game/bike_view.gd").big_head = cheat_on("bighead")


func _check_cheats(level_id: String, weather: String, t: float) -> Array:
	var out := []
	for c in Catalog.CHEATS:
		if String(c[3]) == level_id and String(c[4]) == weather and t > 0.0 and t <= float(c[5]) \
				and not cheat_unlocked(String(c[0])):
			var cc: Dictionary = data().cheats
			var un: Array = cc.get("unlocked", [])
			un.append(String(c[0]))
			cc.unlocked = un
			set_cheat(String(c[0]), true)
			notice("CHEAT UNLOCKED!", String(c[1]))
			Achievements.recount("cheats")
			out.append(["CHEAT UNLOCKED: %s" % String(c[1]), Color("ff9ad8")])
	return out


# --- notices ------------------------------------------------------------------------------

func notice(title: String, line: String) -> void:
	_toasts.append([title, line])


func _process(delta: float) -> void:
	if _toast_t > 0.0:
		_toast_t -= delta
		_toast.t = 2.6 - _toast_t
		_toast.queue_redraw()
		if _toast_t <= 0.0:
			_toast.visible = false
	elif not _toasts.is_empty() and not (Achievements._toast_t > 0.0):
		var n: Array = _toasts.pop_front()
		_toast.title = String(n[0])
		_toast.line = String(n[1])
		_toast.visible = true
		_toast_t = 2.6
		AudioDirector.play("checkpoint")


class Notice extends Control:
	const UIThemeC := preload("res://scripts/ui/ui_theme.gd")
	var title := ""
	var line := ""
	var t := 0.0

	func _init() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var font: Font = GameState.font
		var slide := clampf(t / 0.25, 0.0, 1.0) * clampf((2.6 - t) / 0.3, 0.0, 1.0)
		var w := maxf(font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x,
			font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x) + 16.0
		var r := Rect2(floorf((size.x - w) * 0.5), floorf(-30.0 + 36.0 * slide), w, 28)
		draw_rect(r.grow(1), Color("9fe8ff"))
		draw_rect(r, Color(UIThemeC.INK, 0.95))
		draw_string(font, r.position + Vector2(8, 12), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("9fe8ff"))
		draw_string(font, r.position + Vector2(8, 23), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UIThemeC.CREAM)
