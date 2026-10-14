## Headless check: the bot plays every level in every weather; one JSON line per run.
## Exit code = number of runs the bot could not finish without crashing.
## Flags: --level=<id>  --weather=clear|rain|wind  --trace=<x0>:<x1>
extends Node

const World := preload("res://scripts/game/world.gd")
const Bot := preload("res://scripts/dev/bot.gd")
const Catalog := preload("res://scripts/catalog.gd")

const MAX_CRASHES := 3


func _ready() -> void:
	var only := ""
	var weathers := ["clear", "rain", "wind"]
	var trace := Vector2(-1, -1)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--level="):
			only = a.substr(8)
		elif a.begins_with("--weather="):
			weathers = [a.substr(10)]
		elif a.begins_with("--trace="):
			var tr := a.substr(8).split(":")
			trace = Vector2(float(tr[0]), float(tr[1]))
	var fails := 0
	for meta in Catalog.levels():
		if only != "" and meta.id != only:
			continue
		for weather in weathers:
			if not _run(meta.id, weather, trace):
				fails += 1
	print("VERIFY_DONE fails=%d" % fails)
	get_tree().quit(fails)


func _run(level_id: String, weather: String, trace: Vector2) -> bool:
	var w = World.new()
	w.headless = true
	w.setup(level_id, {}, [], {"time": "dusk", "weather": weather})
	w.bot = Bot.new(w.level)
	w.bot.trace = trace
	var t0 := Time.get_ticks_msec()
	while w.result.is_empty() and w.ticks < 60 * 400 and w.crashes < MAX_CRASHES:
		w.tick()
	var lv: Dictionary = w.level
	print("VERIFY " + JSON.stringify({
		"level": level_id,
		"weather": weather,
		"finished": not w.result.is_empty(),
		"crashes": w.crashes,
		"deaths": w.death_log,
		"coins": "%d/%d" % [w.run_coins, lv.coin_total],
		"gears": "%d/%d" % [w.gears.count(true), lv.gear_total],
		"stomps": w.stomps,
		"sim_ms": Time.get_ticks_msec() - t0,
	}))
	var ok: bool = not w.result.is_empty() and w.crashes == 0
	w.free()
	return ok
