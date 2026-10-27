## --ach-test: drives the Challenges hooks and the SUMMIT / GAUNTLET results with
## made-up events and checks the achievements for endless, daily rides, missions, the
## streak, the league, the season pass, cheats and the two physics modes unlock when
## they should (and not a step before). Runs on a blank
## copy of the save; the real one is put back afterwards, on disk too.
extends Node

var fails := 0
var checks := 0


func _expect(id: String, want: bool, why: String) -> void:
	checks += 1
	if Achievements.is_unlocked(id) != want:
		fails += 1
		print("FAIL %s should be %s %s" % [id, "unlocked" if want else "locked", why])


func _ready() -> void:
	var save := ProjectSettings.globalize_path(GameState.SAVE_PATH)
	var had_file := FileAccess.file_exists(GameState.SAVE_PATH)
	var file_bytes := FileAccess.get_file_as_bytes(GameState.SAVE_PATH) if had_file else PackedByteArray()
	var keep: Dictionary = GameState.data.duplicate(true)
	GameState.data.achievements = {}
	GameState.data.stats = {}
	GameState.data.challenges = {}
	var C = Challenges
	var A = Achievements
	# (_today_override is an absolute day number: days since 1970, like _day_number.)
	var base: int = C.today() + C._epoch()
	C._today_override = base

	# Endless distance, in endless or the league.
	C.on_run({"metres": 999}, "endless")
	_expect("endless_1k", false, "at 999 m")
	C.on_run({"metres": 1000}, "league")
	_expect("endless_1k", true, "at 1,000 m in the league")
	_expect("endless_5k", false, "at 1,000 m")
	C.on_run({"metres": 5200}, "endless")
	_expect("endless_5k", true, "at 5,200 m")
	if A.progress("endless_5k") != [5000, 5000]:
		fails += 1
		print("FAIL endless_5k progress ", A.progress("endless_5k"))

	# Daily rides: one counts per day, however many times you ride it.
	for i in 6:
		C._today_override = base + i
		C.on_run({"time": 60.0, "par": 40.0, "crashes": 1}, "daily")
		C.on_run({"time": 55.0, "par": 40.0, "crashes": 1}, "daily")
	_expect("daily_7", false, "after 6 days (12 rides)")
	C._today_override = base + 6
	C.on_run({"time": 60.0, "par": 40.0, "crashes": 1}, "daily")
	_expect("daily_7", true, "after 7 days")

	# The streak: a gap starts it again.
	C.data().streak = {}
	for d in [0, 1, 2, 4, 5, 6, 7, 8, 9, 10]:
		C._today_override = base + 20 + d
		C.check_in()
		if d == 9:
			_expect("streak_7", false, "on day 6 of a streak (after a gap)")
	_expect("streak_7", true, "on day 7 of a streak")

	# All three missions in a day.
	C._today_override = base + 40
	var ms: Array = C.missions()
	for k in 2:
		C.on_stat(String(ms[k].stat), int(ms[k].goal))
	_expect("missions_all", false, "with two of three missions done")
	C.on_stat(String(ms[2].stat), int(ms[2].goal))
	_expect("missions_all", true, "with all three done")

	# League: win the group four weeks running -> up to the Golden Spike.
	for w in 4:
		var l: Dictionary = C._league_state()
		l.runs = 1
		l.best_m = 40000  # farther than the whole line: first place
		C._today_override = base + 7 * (w + 8)
		var res: Dictionary = C.roll_week()
		if int(res.get("rank", 0)) != 1 or int(res.get("to", -1)) != w + 1:
			fails += 1
			print("FAIL league week ", w, " ", res)
		if w == 0:
			_expect("league_up", true, "after a promotion")
			_expect("league_win", true, "after first place")
		if w < 3:
			_expect("league_top", false, "in division %d" % (w + 1))
	_expect("league_top", true, "in the Golden Spike")

	# The season pass's last tier.
	C._today_override = base + 200
	C.add_xp(C.TIER_XP * C.SEASON_TIERS - 1)
	_expect("season_30", false, "one XP short")
	C.add_xp(1)
	_expect("season_30", true, "at tier 30")

	# Cheats: all three.
	for c in (load("res://scripts/catalog.gd").CHEATS as Array):
		_expect("cheats_all", false, "before " + String(c[0]))
		C._check_cheats(String(c[3]), String(c[4]), float(c[5]) - 1.0)
	_expect("cheats_all", true, "with all three")

	# SUMMIT and GAUNTLET: a failed ride unlocks nothing; the first finish does; a
	# clean course; and all twelve of each.
	var P = load("res://scripts/drive/drive_progress.gd")
	GameState.data.drive = {}
	var money0 := GameState.money()
	P.record_result({"mode": "summit", "level_id": "su_farm", "ok": false, "reason": "fuel", "time": 30.0,
		"coins": 40, "distance_m": 500, "length_m": 900, "faults": 0, "flips": 0}, 0)
	_expect("summit_first", false, "after running out of fuel")
	if GameState.money() != money0 + 40:
		fails += 1
		print("FAIL a failed SUMMIT ride should still bank its 40 coins, wallet went %d -> %d" % [money0, GameState.money()])
	for i in 12:
		var sid := String(P.levels("summit")[i].id)
		P.record_result({"mode": "summit", "level_id": sid, "ok": true, "reason": "finish", "time": 999.0,
			"coins": 0, "distance_m": 900, "length_m": 900, "faults": 0, "flips": 0}, i)
		if i == 0:
			_expect("summit_first", true, "after the first summit")
		if i == 10:
			_expect("summit_all", false, "after 11 summits")
	_expect("summit_all", true, "after all 12 summits")
	P.record_result({"mode": "gauntlet", "level_id": "ga_firstgear", "ok": true, "reason": "finish", "time": 999.0,
		"coins": 0, "faults": 3}, 0)
	_expect("gauntlet_first", true, "after a course with 3 faults")
	_expect("gauntlet_clean", false, "after a course with 3 faults")
	if not P.unlocked("gauntlet", 1) or P.unlocked("gauntlet", 2):
		fails += 1
		print("FAIL clearing course 1 should open course 2 and only that")
	for i in range(1, 12):
		P.record_result({"mode": "gauntlet", "level_id": String(P.levels("gauntlet")[i].id), "ok": true,
			"reason": "finish", "time": 999.0, "coins": 0, "faults": 0 if i == 5 else 1}, i)
		if i == 5:
			_expect("gauntlet_clean", true, "after a course with no faults")
		if i == 10:
			_expect("gauntlet_all", false, "after 11 courses")
	_expect("gauntlet_all", true, "after all 12 courses")

	print("ACH_TEST %s: %d checks, %d failed" % ["OK" if fails == 0 else "FAILED", checks, fails])
	# Put everything back.
	C._today_override = -1
	GameState.data = keep
	if had_file:
		var f := FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE)
		f.store_buffer(file_bytes)
		f.close()
	else:
		DirAccess.remove_absolute(save)
	C.apply_cheats()
	get_tree().quit(0 if fails == 0 else 1)
