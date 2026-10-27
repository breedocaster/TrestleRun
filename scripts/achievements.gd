## Autoload: achievements. Tracks unlocks and progress in the save, pops a toast when
## one unlocks, and reports to Google Play Games / Apple Game Center when those plugins
## are in the build (they need store accounts; see ACHIEVEMENTS.md). Without them every
## achievement still works in the game and shows on the ACHIEVEMENTS screen.
extends CanvasLayer

const Catalog := preload("res://scripts/catalog.gd")
const UITheme := preload("res://scripts/ui/ui_theme.gd")

## id, name, how to get it, store points (multiples of 5, at most 100 each and 1,000 in
## all: Game Center's limits, tighter than Play's 200 and 2,000; exactly 1,000 since
## v0.10, so a new one has to take points from an old one), goal (0 = one step; otherwise a count shown as progress), stat
## it counts. Ids, types and goals are fixed once they're published on a store.
const LIST := [
	["story_start", "OFF YOU GO", "FINISH THE FIRST STORY TRAIL.", 5, 0, ""],
	["part_headlight", "LIGHTS ON", "GET GRANDPA'S HEADLIGHT BACK FROM THE SCOOPER.", 35, 0, ""],
	["part_kickstart", "KICKED OFF", "GET THE KICKSTART BACK FROM THE RAIL HOG.", 35, 0, ""],
	["part_seat", "TAKE A SEAT", "GET THE SEAT BACK FROM THE HARVESTER.", 35, 0, ""],
	["part_wheels", "ROLLING AGAIN", "GET BOTH WHEELS BACK FROM THE SPINNER.", 35, 0, ""],
	["parts_4", "HALFWAY HOME", "RECOVER FOUR PARTS OF GRANDPA'S BIKE.", 25, 4, "parts"],
	["boss_flawless", "NOT A SCRATCH", "BEAT A BOSS WITHOUT CRASHING.", 25, 0, ""],
	["boss_quick", "SHORT WORK", "KNOCK OUT A BOSS BEFORE IT CIRCLES ROUND.", 25, 0, ""],
	["first_clear", "TRAIL BLAZER", "CLEAR YOUR FIRST FREE RIDE TRAIL.", 5, 0, ""],
	["free_all", "EVERY TRESTLE", "CLEAR ALL 12 FREE RIDE TRAILS.", 60, 12, "free_cleared"],
	["no_crash", "CLEAN RUN", "CLEAR A TRAIL WITHOUT CRASHING.", 10, 0, ""],
	["gold_first", "GOLD RUSH", "WIN A GOLD MEDAL.", 15, 0, ""],
	["gold_ten", "GOLDEN TOUCH", "WIN 10 GOLD MEDALS.", 40, 10, "golds"],
	["letters_first", "SPELL IT OUT", "FIND ALL OF T-R-E-S-T-L-E IN ONE RUN.", 15, 0, ""],
	["gears_all", "GEAR HEAD", "FIND ALL 36 GEARS IN FREE RIDE.", 50, 36, "free_gears"],
	["flip", "HEAD OVER WHEELS", "LAND A FLIP.", 5, 0, ""],
	["double_flip", "DOUBLE TROUBLE", "LAND A DOUBLE FLIP.", 20, 0, ""],
	["tricks_run", "SHOWBOAT", "LAND 10 TRICKS IN ONE RUN.", 20, 0, ""],
	["stomp_100", "STOMPER", "STOMP 100 CRITTERS.", 25, 100, "stomps"],
	["zip_chain", "CABLE HOPPER", "RIDE THREE CABLES IN A ROW WITHOUT TOUCHING DOWN.", 15, 0, ""],
	["rails_25", "SPARK SHOW", "GRIND 25 RAILS.", 20, 25, "rails"],
	["ropes_25", "ROPE TRICK", "SWING ON 25 ROPES.", 20, 25, "ropes"],
	["walls_25", "WALL OF DEATH", "RIDE 25 WALLS.", 20, 25, "walls"],
	["planes_10", "AIR MAIL", "CATCH 10 PRIZE SACKS FROM THE BONUS PLANE.", 20, 10, "planes"],
	["any_weather", "ANY WEATHER", "CLEAR A TRAIL IN THE RAIN AND ONE IN THE WIND.", 15, 0, ""],
	["night_5", "AFTER DARK", "CLEAR 5 TRAILS AT NIGHT.", 20, 5, "night_clears"],
	["garage_bikes", "FULL GARAGE", "OWN ALL 14 BIKES.", 35, 14, "bikes"],
	["garage_riders", "THE WHOLE GANG", "OWN ALL 8 RIDERS.", 35, 8, "riders"],
	["rich", "SAVINGS JAR", "HAVE 2,000 COINS AT ONCE.", 15, 0, ""],
	["ghost_beat", "BEAT YOUR GHOST", "SET A NEW BEST TIME WHILE YOUR GHOST RIDES.", 15, 0, ""],
	["outrun", "OUTRUN IT", "FINISH LAST TRESTLE WITHOUT CRASHING.", 30, 0, ""],
	# Endless, the daily ride and missions, the streak, the league, the season pass, cheats.
	["endless_1k", "FIRST MILEPOST", "RIDE 1,000 M IN ONE ENDLESS RUN.", 10, 1000, "endless_m"],
	["endless_5k", "LONG HAUL", "RIDE 5,000 M IN ONE ENDLESS RUN.", 30, 5000, "endless_m"],
	["daily_7", "DAILY GRIND", "CLEAR 7 DAILY RIDES.", 20, 7, "daily_clears"],
	["missions_all", "HAT TRICK", "FINISH ALL THREE DAILY MISSIONS IN ONE DAY.", 15, 0, ""],
	["streak_7", "SEVEN STRAIGHT", "PLAY 7 DAYS IN A ROW.", 20, 7, "best_streak"],
	["league_up", "MOVING UP", "GET PROMOTED IN THE WEEKLY LEAGUE.", 15, 0, ""],
	["league_win", "TOP OF THE TABLE", "FINISH A LEAGUE WEEK FIRST IN YOUR GROUP.", 20, 0, ""],
	["league_top", "GOLDEN SPIKE", "REACH THE GOLDEN SPIKE DIVISION.", 30, 4, "best_div"],
	["season_30", "TOP OF THE PASS", "REACH TIER 30 ON A SEASON PASS.", 25, 0, ""],
	["cheats_all", "CHEAT CODES", "UNLOCK ALL 3 CHEATS.", 20, 3, "cheats"],
	# SUMMIT and GAUNTLET (v0.10). These bring the total to 1,000, Game Center's cap.
	["summit_first", "HILLTOP", "REACH THE TOP OF A SUMMIT CLIMB.", 5, 0, ""],
	["summit_all", "TOP OF THE WORLD", "REACH THE TOP OF ALL 12 SUMMIT CLIMBS.", 15, 12, "summit_done"],
	["gauntlet_first", "RUN THE GAUNTLET", "CLEAR A GAUNTLET COURSE.", 5, 0, ""],
	["gauntlet_clean", "NO FAULTS", "CLEAR A GAUNTLET COURSE WITHOUT A FAULT.", 10, 0, ""],
	["gauntlet_all", "THE FULL GAUNTLET", "CLEAR ALL 12 GAUNTLET COURSES.", 15, 12, "gauntlet_done"],
]

## Store ids. Google Play Console makes its own ("CgkI..."): paste them in here once the
## achievements exist there (ACHIEVEMENTS.md has a script that turns the Console's
## export into this dictionary). Game Center uses the ids you type into App Store
## Connect: "trestlerun." + the id in LIST.
const PLAY_IDS := {}
const GC_PREFIX := "trestlerun."

var _play: Object = null
var _gc: Object = null
var _toasts: Array = []
var _toast: Control
var _toast_t := 0.0
var _quiet := false


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_toast = Toast.new()
	_toast.visible = false
	add_child(_toast)
	_connect_stores()
	# Progress from before achievements existed (an older save) unlocks quietly.
	_quiet = true
	_check_counts()
	on_wallet()
	_quiet = false


# --- state -----------------------------------------------------------------------

func _store() -> Dictionary:
	if not GameState.data.has("achievements"):
		GameState.data.achievements = {}
	return GameState.data.achievements


func stats() -> Dictionary:
	if not GameState.data.has("stats"):
		GameState.data.stats = {}
	return GameState.data.stats


func is_unlocked(id: String) -> bool:
	return _store().has(id)


static func info(id: String) -> Array:
	for a in LIST:
		if a[0] == id:
			return a
	return []


## [current, goal] for counted achievements ([0, 0] for one-step ones).
func progress(id: String) -> Array:
	var a := info(id)
	if a.is_empty() or int(a[4]) <= 0:
		return [1 if is_unlocked(id) else 0, 0]
	return [mini(_stat_value(String(a[5])), int(a[4])), int(a[4])]


func _stat_value(stat: String) -> int:
	match stat:
		"parts":
			return GameState.story_parts().size()
		"free_cleared":
			var n := 0
			for l in Catalog.levels():
				if GameState.level_record(l.id).cleared:
					n += 1
			return n
		"golds":
			var g := 0
			for l in Catalog.all_levels():
				if GameState.data.levels.has(l.id) and bool(GameState.level_record(l.id).get("gold", false)):
					g += 1
			return g
		"free_gears":
			var c := 0
			for l in Catalog.levels():
				if GameState.data.levels.has(l.id):
					c += (GameState.level_record(l.id).gears as Array).count(true)
			return c
		"bikes":
			return (GameState.data.bike_owned as Array).size()
		"riders":
			return (GameState.data.rider_owned as Array).size()
		# Kept by Challenges (an autoload after this one, so read from the save here).
		"endless_m":
			var e: Dictionary = (GameState.data.get("challenges", {}) as Dictionary).get("endless", {})
			return maxi(int(e.get("best_any", 0)), int(e.get("best_m", 0)))
		"cheats":
			var c: Dictionary = (GameState.data.get("challenges", {}) as Dictionary).get("cheats", {})
			return (c.get("unlocked", []) as Array).size()
		# SUMMIT / GAUNTLET levels finished (drive_progress.gd keeps them in the save).
		"summit_done", "gauntlet_done":
			var lv: Dictionary = (GameState.data.get("drive", {}) as Dictionary).get("levels", {})
			var pre := "su_" if stat == "summit_done" else "ga_"
			var n := 0
			for id in lv:
				if String(id).begins_with(pre) and bool((lv[id] as Dictionary).get("done", false)):
					n += 1
			return n
	return int(stats().get(stat, 0))


func unlock(id: String) -> void:
	if is_unlocked(id) or info(id).is_empty():
		return
	_store()[id] = int(Time.get_unix_time_from_system())
	GameState.save_game()
	if not _quiet:
		_toasts.append(id)
	_report(id)


## Add to a counter (stomps, rails, ropes...) and unlock whatever it completes.
func add(stat: String, n := 1) -> void:
	stats()[stat] = int(stats().get(stat, 0)) + n
	_check_counts(stat)


## Raise a best-ever counter (longest streak, highest division) and check it.
func record_max(stat: String, v: int) -> void:
	if v > int(stats().get(stat, 0)):
		stats()[stat] = v
	_check_counts(stat)


## Check the achievements counting a stat that lives elsewhere (endless_m, cheats).
func recount(stat: String) -> void:
	_check_counts(stat)


func _check_counts(stat := "") -> void:
	for a in LIST:
		if int(a[4]) > 0 and (stat == "" or String(a[5]) == stat):
			var v := _stat_value(String(a[5]))
			if v >= int(a[4]):
				unlock(String(a[0]))
			elif v > 0:
				_report_steps(String(a[0]), v)


## After every finished run (game screen).
func on_run(r: Dictionary, pay: Dictionary) -> void:
	var id := String(r.level_id)
	var meta := Catalog.level(id)
	var crashes := int(r.get("crashes", 0))
	var cond: Dictionary = r.get("conditions", {})
	if meta.has("story"):
		if id == String(Catalog.story_levels()[0].id):
			unlock("story_start")
		if pay.has("new_part"):
			unlock("part_" + String(pay.new_part))
		if bool(r.get("boss_down", false)):
			if crashes == 0:
				unlock("boss_flawless")
			if int(r.get("boss_loops", 0)) == 0:
				unlock("boss_quick")
	else:
		unlock("first_clear")
	if crashes == 0:
		unlock("no_crash")
		if id == "last_trestle":
			unlock("outrun")
	if (pay.get("new_medals", [false, false, false]) as Array)[2] or bool(GameState.level_record(id).get("gold", false)):
		unlock("gold_first")
	if bool(r.get("letters_all", false)):
		unlock("letters_first")
	if int(r.get("tricks", 0)) >= 10:
		unlock("tricks_run")
	var wx := String(cond.get("weather", "clear"))
	if wx == "rain" or wx == "wind":
		stats()[wx + "_clears"] = int(stats().get(wx + "_clears", 0)) + 1
	if int(stats().get("rain_clears", 0)) > 0 and int(stats().get("wind_clears", 0)) > 0:
		unlock("any_weather")
	if String(cond.get("time", "dusk")) == "night":
		add("night_clears")
	if bool(r.get("had_ghost", false)) and bool(pay.get("new_best", false)):
		unlock("ghost_beat")
	_check_counts()
	GameState.save_game()


## Garage purchases and the wallet.
func on_wallet() -> void:
	if GameState.money() >= 2000:
		unlock("rich")
	_check_counts("bikes")
	_check_counts("riders")


# --- stores -------------------------------------------------------------------------

## Google Play Games (the GodotPlayGameServices Android plugin, v3.4) and Game Center
## (the GameCenterKit iOS add-on, v1.0.1) when the build includes them; silently off
## otherwise. Calls and signals are the plugins' own (checked against their sources):
##   Play:  initialize(), isAuthenticated(), signIn(), unlockAchievement(id),
##          setAchievementSteps(id, n), showAchievements(); signal userAuthenticated(ok)
##   Apple: authenticate(), is_authenticated(), report_achievement(id, percent),
##          show_achievements(); signal authenticated(ok, error)
## Unlocks made while signed out are re-sent on sign-in (the stores ignore repeats).
var store_signed_in := false


func _connect_stores() -> void:
	if Engine.has_singleton("GodotPlayGameServices"):
		_play = Engine.get_singleton("GodotPlayGameServices")
		if _play.has_signal("userAuthenticated"):
			_play.connect("userAuthenticated", _on_signed_in)
		_play.call("initialize")
		_play.call("isAuthenticated")  # answers through userAuthenticated
	if Engine.has_singleton("GameCenterKit"):
		_gc = Engine.get_singleton("GameCenterKit")
		if _gc.has_signal("authenticated"):
			_gc.connect("authenticated", func(ok: bool, _err: String): _on_signed_in(ok))
		_gc.call("authenticate")


func _on_signed_in(ok: bool) -> void:
	store_signed_in = ok
	if ok:
		sync_stores()


func stores_connected() -> String:
	if _play != null:
		return "GOOGLE PLAY GAMES"
	if _gc != null:
		return "GAME CENTER"
	return ""


## The ACHIEVEMENTS screen's store button: sign in first if need be.
func sign_in_store() -> void:
	if _play != null:
		_play.call("signIn")
	elif _gc != null:
		_gc.call("authenticate")


## Re-send everything unlocked, and progress on the counted ones.
func sync_stores() -> void:
	for id in _store().keys():
		_report(String(id))
	for a in LIST:
		if int(a[4]) > 0 and not is_unlocked(String(a[0])):
			var v := _stat_value(String(a[5]))
			if v > 0:
				_report_steps(String(a[0]), v)


func _report(id: String) -> void:
	if not store_signed_in:
		return
	if _play != null and PLAY_IDS.has(id):
		_play.call("unlockAchievement", String(PLAY_IDS[id]))
	if _gc != null:
		_gc.call("report_achievement", GC_PREFIX + id, 100.0)


func _report_steps(id: String, steps: int) -> void:
	if not store_signed_in or steps <= 0:
		return
	if _play != null and PLAY_IDS.has(id):
		_play.call("setAchievementSteps", String(PLAY_IDS[id]), steps)
	if _gc != null:
		var a := info(id)
		_gc.call("report_achievement", GC_PREFIX + id, clampf(100.0 * float(steps) / float(maxi(1, int(a[4]))), 0.0, 100.0))


func show_store_ui() -> void:
	if not store_signed_in:
		sign_in_store()
		return
	if _play != null:
		_play.call("showAchievements")
	elif _gc != null:
		_gc.call("show_achievements")


# --- toast --------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _toast_t > 0.0:
		_toast_t -= delta
		_toast.t = 3.0 - _toast_t
		_toast.queue_redraw()
		if _toast_t <= 0.0:
			_toast.visible = false
	elif not _toasts.is_empty():
		_toast.id = String(_toasts.pop_front())
		_toast.visible = true
		_toast_t = 3.0
		AudioDirector.play("achievement")


class Toast extends Control:
	const Art := preload("res://scripts/ui/achievement_art.gd")
	const UIThemeC := preload("res://scripts/ui/ui_theme.gd")
	var id := ""
	var t := 0.0

	func _init() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var a: Array = preload("res://scripts/achievements.gd").info(id)
		if a.is_empty():
			return
		var font: Font = GameState.font
		var slide := clampf(t / 0.25, 0.0, 1.0) * clampf((3.0 - t) / 0.3, 0.0, 1.0)
		var w := maxf(150.0, font.get_string_size(String(a[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 44.0)
		var r := Rect2(floorf((size.x - w) * 0.5), floorf(-30.0 + 36.0 * slide), w, 28)
		draw_rect(r.grow(1), UIThemeC.GOLD)
		draw_rect(r, Color(UIThemeC.INK, 0.95))
		Art.badge(self, r.position + Vector2(15, 14), 10.0, id, true, t)
		draw_string(font, r.position + Vector2(30, 12), "ACHIEVEMENT!", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UIThemeC.GOLD)
		draw_string(font, r.position + Vector2(30, 23), String(a[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UIThemeC.CREAM)
