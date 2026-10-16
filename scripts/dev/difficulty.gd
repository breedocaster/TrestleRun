## Difficulty meter (dev only). Rides each trail like a careful human: whenever riding on
## would crash, it finds the run of frames in which pressing still works (the timing
## window) and presses in the middle of it. Smaller windows and more forced jumps per
## 10 s = harder. Prints one line per trail, with the tightest spots and their chunks.
## Flags: --difficulty [--weather=clear|rain|wind] [--level=<id>] [--old] [--set=story]
extends Node

const World := preload("res://scripts/game/world.gd")
const Bot := preload("res://scripts/game/autopilot.gd")
const Phys := preload("res://scripts/game/bike_physics.gd")
const Catalog := preload("res://scripts/catalog.gd")
const Library := preload("res://scripts/game/level_library.gd")

const Careful := preload("res://scripts/dev/careful.gd")


func _ready() -> void:
	var weather := "clear"
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--weather="):
			weather = a.substr(10)
		elif a.begins_with("--level="):
			only = a.substr(8)
	var all := Catalog.all_levels()
	# --set=story: just the story trails, each in its own weather (unless --weather= says).
	var story := "--set=story" in OS.get_cmdline_user_args()
	var forced_wx := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--weather="):
			forced_wx = true
	if story:
		all = Catalog.story_levels()
	for i in all.size():
		var meta: Dictionary = all[i]
		if only != "" and meta.id != only:
			continue
		if meta.get("boss", false):
			continue  # a boss fight is timed by the boss, not the deck
		var wx := String(meta.cond.weather) if story and not forced_wx else weather
		_measure(i, meta, wx, {})
	if "--old" in OS.get_cmdline_user_args():
		# v0.4 trails, for comparison with the new ramp.
		var old = load("res://scripts/dev/old_layouts.gd")
		for i in old.OLD.size():
			var o: Array = old.OLD[i]
			var lv: Dictionary = Library.build_layout(o[2], {"id": o[0], "name": o[0], "speed": o[1]})
			_measure(i, {"id": "OLD " + o[0], "speed": o[1]}, weather, lv)
	get_tree().quit()


func _measure(idx: int, meta: Dictionary, weather: String, custom: Dictionary) -> void:
	var w = World.new()
	w.headless = true
	w.setup(String(meta.id), {"bike": "scrambler", "ability": {}}, [], {"time": "dusk", "weather": weather}, custom)
	var bot = Bot.new(w.level)
	bot.collect = false
	var c := Careful.new()
	c.level = w.level
	c.bot = bot
	w.bot = c
	var ride_ticks := 0
	while w.result.is_empty() and w.ticks < 60 * 400 and w.crashes < 3:
		if w.phase == "ride":
			ride_ticks += 1
		w.tick()
	var ms: Array = []
	for e in c.windows:
		ms.append(e.ms)
	ms.sort()
	var tight: Array = c.windows.duplicate()
	tight.sort_custom(func(a, b): return a.ms < b.ms)
	var n := ms.size()
	var secs := ride_ticks / 60.0
	if n == 0:
		print("DIFF %d %-14s no forced jumps" % [idx + 1, meta.id])
		return
	print("DIFF %d %-18s %-5s %3d px/s %4.1fs crashes %d | forced %2d = %4.1f/10s | window ms min %3d p10 %3d p25 %3d med %3d | tight %s" % [
		idx + 1, meta.id, weather, int(meta.speed), secs, w.crashes, n, n / secs * 10.0,
		int(ms[0]), int(ms[n / 10]), int(ms[n / 4]), int(ms[n / 2]),
		str(tight.slice(0, 4).map(func(t): return "%d@%d %s" % [int(t.ms), int(t.x), _chunk_at(w.level, float(t.x))]))])
	if w.crashes > 0:
		print("  DEATHS %s" % str(w.death_log))
	if "--detail" in OS.get_cmdline_user_args():
		for e in c.windows:
			if e.ms < 160.0:
				print("  DETAIL %3d ms at x=%d  %s" % [int(e.ms), int(e.x), _chunk_at(w.level, float(e.x), true)])
	w.free()


func _chunk_at(lv: Dictionary, x: float, verbose := false) -> String:
	var name := ""
	var prev := ""
	var at := 0.0
	for m in lv.get("marks", []):
		if float(m[1]) <= x:
			prev = name
			name = String(m[0])
			at = float(m[1])
	if verbose:
		return "%s +%d (after %s)" % [name, int(x - at), prev]
	return name
