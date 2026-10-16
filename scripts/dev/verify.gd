## Headless check: the bot plays every level in every weather; one JSON line per run.
## Exit code = number of runs the bot could not finish without crashing.
## Flags: --level=<id>  --weather=clear|rain|wind  --bike=<id>|none|all  --trace=<x0>:<x1>
extends Node

const World := preload("res://scripts/game/world.gd")
const Bot := preload("res://scripts/game/autopilot.gd")
const Catalog := preload("res://scripts/catalog.gd")
const Phys := preload("res://scripts/game/bike_physics.gd")
const Library := preload("res://scripts/game/level_library.gd")
const Layouts := preload("res://scripts/game/level_layouts.gd")

const MAX_CRASHES := 3


func _ready() -> void:
	var only := ""
	var weathers := ["clear", "rain", "wind"]
	var bikes := ["none"]
	var trace := Vector2(-1, -1)
	var tests := []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--test="):
			tests = Array(a.substr(7).split(","))
		if a.begins_with("--level="):
			only = a.substr(8)
		elif a.begins_with("--weather="):
			weathers = [a.substr(10)]
		elif a.begins_with("--bike="):
			var b := a.substr(7)
			bikes = []
			if b == "all":
				for it in Catalog.bikes():
					bikes.append(it.id)
			else:
				bikes = [b]
		elif a.begins_with("--trace="):
			var tr := a.substr(8).split(":")
			trace = Vector2(float(tr[0]), float(tr[1]))
	var fails := 0
	for tname in tests:
		var tn := String(tname).split(":")
		for weather in weathers:
			for bike in bikes:
				if not _run("test_" + tn[0], weather, bike, trace, float(tn[1]) if tn.size() > 1 else 130.0):
					fails += 1
	if not tests.is_empty():
		print("VERIFY_DONE fails=%d" % fails)
		get_tree().quit(fails)
		return
	var set_name := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--set="):
			set_name = a.substr(6)
	var pool: Array = Catalog.all_levels()
	if set_name == "story":
		pool = Catalog.story_levels()
	elif set_name == "free":
		pool = Catalog.levels()
	for meta in pool:
		if only != "" and meta.id != only:
			continue
		for bike in bikes:
			for weather in weathers:
				if not _run(meta.id, weather, bike, trace):
					fails += 1
	print("VERIFY_DONE fails=%d" % fails)
	get_tree().quit(fails)


func _run(level_id: String, weather: String, bike: String, trace: Vector2, test_speed := 130.0) -> bool:
	var w = World.new()
	w.headless = true
	var rig := {"bike": "scrambler", "ability": {}} if bike == "none" else {"bike": bike}
	if level_id.begins_with("test_"):
		var tl: Dictionary = Library.build_layout(Layouts.TESTS[level_id.substr(5)],
			{"id": level_id, "name": level_id, "speed": test_speed, "theme": 0})
		w.setup(level_id, rig, [], {"time": "dusk", "weather": weather}, tl)
	else:
		w.setup(level_id, rig, [], {"time": "dusk", "weather": weather})
	w.bot = Bot.new(w.level)
	w.bot.trace = trace
	var t0 := Time.get_ticks_msec()
	while w.result.is_empty() and w.ticks < 60 * 400 and w.crashes < MAX_CRASHES:
		w.tick()
	var lv: Dictionary = w.level
	print("VERIFY " + JSON.stringify({
		"level": level_id,
		"weather": weather,
		"bike": bike,
		"finished": not w.result.is_empty(),
		"crashes": w.crashes,
		"deaths": w.death_log,
		"coins": "%d/%d" % [w.run_coins, lv.coin_total],
		"gears": "%d/%d" % [w.gears.count(true), lv.gear_total],
		"letters": "%d/7" % w.letter_count(),
		"powers": (w.state.got as Dictionary).size(),
		"stomps": w.stomps,
		"end_x": snappedf(float(w.state.x), 1.0),
		"end": Phys.attachment(w.level, w.state),
		"boss": "%d/%d loops %d" % [int(w.state.boss_hits), int(lv.boss.hp), int(w.state.boss_loops)] if lv.has("boss") else "",
		"time": snappedf(w.ticks / 60.0, 0.1),
		"sim_ms": Time.get_ticks_msec() - t0,
	}))
	var ok: bool = not w.result.is_empty() and w.crashes == 0
	if w.letter_count() < 7:
		var lmiss := []
		for p in lv.pickups:
			if int(p.type) == 3 and not (w.letters & (1 << int(p.letter))):
				lmiss.append(p.pos)
		print("MISSED_LETTERS %s" % str(lmiss))
	if w.gears.count(true) < lv.gear_total:
		var miss := []
		for p in lv.pickups:
			if int(p.type) == 2 and not w.gears[int(p.gear)]:
				miss.append(p.pos)
		print("MISSED_GEARS %s" % str(miss))
	if not ok or w.gears.count(true) < lv.gear_total:
		print("MARKS %s" % str(lv.marks))
	w.free()
	return ok
