## Crash-hint check (dev): rides each trail with the bot and, at every checkpoint,
## works out the hint line from there to the next checkpoint the way a wreck would
## (Guide.compute from the respawn state). Reports lines that don't get through,
## and how long they took (the phone does this on a worker thread during the crash).
## Flags: --guide-test [--level=<id>] [--weather=clear|rain|wind] [--set=story|free]
##        --guide-test --flow: a rider who never presses, to check when hints switch on
##        --guide-test --probe=<level>:<x>: what pressing (with a few holds) does over the
##            next 60 frames from where the bot is at x
##        --guide-test --boss-trace=<level>:<weather>: catches, let-gos and hits in a boss arena
##        --guide-test --ride-trace=<level>:<weather>:<bike>:<x0>:<x1>: the bot's ride, frame by frame
extends Node

const World := preload("res://scripts/game/world.gd")
const Bot := preload("res://scripts/game/autopilot.gd")
const Catalog := preload("res://scripts/catalog.gd")
const Guide := preload("res://scripts/game/guide.gd")


func _ready() -> void:
	if "--flow" in OS.get_cmdline_user_args():
		_flow()
		return
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--probe="):
			_probe(a.substr(8))
			return
		if a.begins_with("--boss-trace="):
			_boss_trace(a.substr(13))
			return
		if a.begins_with("--ride-trace="):
			_ride_trace(a.substr(13))
			return
	var only := ""
	var weathers := ["clear", "rain", "wind"]
	var pool: Array = Catalog.all_levels()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--level="):
			only = a.substr(8)
		elif a.begins_with("--weather="):
			weathers = [a.substr(10)]
		elif a == "--set=story":
			pool = Catalog.story_levels()
		elif a == "--set=free":
			pool = Catalog.levels()
	var fails := 0
	var worst := 0.0
	for meta in pool:
		if only != "" and meta.id != only:
			continue
		for weather in weathers:
			var r := _run(String(meta.id), weather)
			fails += int(r.x)
			worst = maxf(worst, r.y)
	print("GUIDE_DONE fails=%d worst_ms_per_100_frames=%.1f" % [fails, worst])
	get_tree().quit(fails)


func _run(id: String, weather: String) -> Vector2:
	var w = World.new()
	w.headless = true
	w.setup(id, {"bike": "scrambler", "ability": {}}, [], {"time": "dusk", "weather": weather})
	w.bot = Bot.new(w.level)
	w.hints = false
	var cps: Array = w.level.checkpoints
	var fails := 0
	var worst := 0.0
	var done := {}
	var line := []
	while w.result.is_empty() and w.ticks < 60 * 400 and w.crashes == 0:
		w.tick()
		# Just passed a checkpoint (or the start): hint from here to the next one.
		var k: int = w._next_cp
		if w.phase == "ride" and not done.has(k) and not w._cp.is_empty():
			done[k] = true
			var end_x: float = float(cps[k].x) + 60.0 if k < cps.size() else float(w.level.finish_x)
			var lv: Dictionary = w.level.duplicate(true)
			var t0 := Time.get_ticks_usec()
			var g := Guide.compute({"level": lv, "s0": w._respawn_state(lv), "end_x": end_x, "collect": w.level.has("boss")})
			var ms := (Time.get_ticks_usec() - t0) / 1000.0
			var per := ms / maxf(1.0, (g.pts as PackedVector2Array).size()) * 100.0
			worst = maxf(worst, per)
			var taps := 0
			for m in g.marks:
				if String(m[1]) != "LET GO":
					taps += 1
			line.append("%d%s" % [int(w._cp.x), "" if g.ok else "!"])
			if not g.ok:
				fails += 1
				var last: Vector2 = (g.pts as PackedVector2Array)[-1]
				print("GUIDE_FAIL %s %s from x=%d to %d: stopped at x=%d (%s) after %d frames" % [id, weather, int(w._cp.x), int(end_x), int(last.x),
					Guide.section_name(w.level, Guide.section_at(w.level, last.x)), (g.pts as PackedVector2Array).size()])
	print("GUIDE %-16s %-5s checkpoints %s  fails %d  %.1f ms/100 frames" % [id, weather, " ".join(line), fails, worst])
	w.free()
	return Vector2(fails, worst)


## Nobody pressing: wreck after wreck at the first trouble, and when the hint comes on.
func _flow() -> void:
	for id in ["dusty_trail", "night_trestle", "rocket_ridge", "s1_clothesline", "s2_siding", "s4_drome"]:
		var w = World.new()
		w.headless = true
		w.setup(id, {"bike": "scrambler", "ability": {}}, [], {"time": "dusk", "weather": "clear"})
		var log := []
		var last := 0
		while w.crashes < 6 and w.ticks < 60 * 200:
			w.tick()
			if w.crashes != last:
				last = w.crashes
				log.append("%d@%d:%s%s" % [w.crashes, int(w.death_log[-1].x), "HINT" if w.guide_on else "-",
					"+line" if not w.guide.is_empty() else ""])
		print("FLOW %-15s needs %d  %s  tip: %s" % [id, Guide.threshold(id, Guide.section_name(w.level, Guide.section_at(w.level, float(w.death_log[0].x)))),
			" ".join(log), w.guide_tip])
		w.free()
	get_tree().quit()


## Dev probe (--guide-test --probe=<level>:<x>): from where the bot is at x, press at
## each of the next 60 frames with a few holds and show what happens.
func _probe(spec: String) -> void:
	var p := spec.split(":")
	var w = World.new()
	w.headless = true
	w.setup(p[0], {"bike": "scrambler", "ability": {}}, [], {"time": "dusk", "weather": "clear"})
	w.bot = Bot.new(w.level)
	w.bot.collect = false
	while float(w.state.x) < float(p[1]) and w.result.is_empty():
		w.tick()
	var Phys = load("res://scripts/game/bike_physics.gd")
	var st: Dictionary = Phys.copy_state(w.state)
	for k in 60:
		var row := "k=%2d x=%.0f g=%s  " % [k, st.x, st.grounded]
		for h in [5, 9, 14, 22, 30]:
			var s: Dictionary = Phys.copy_state(st)
			var out := "?"
			for i in 300:
				var ev: int = Phys.step(w.level, s, i == 0, i < h or Phys.auto_hold(w.level, s))
				if not s.alive:
					out = "DIE(%s)@%d" % [s.death, int(s.x)]
					break
				var att: String = Phys.attachment(w.level, s)
				if att != "":
					out = "%s@%d" % [att, int(s.x)]
					break
				if i > 1 and s.grounded:
					out = "land@%d" % int(s.x)
					break
			row += "h%d:%s/%d  " % [h, out, Guide.catches(w.level, st, h)]
		print(row)
		Phys.step(w.level, st, false, false)
	get_tree().quit()



## Dev (--guide-test --boss-trace=<level>:<weather>): the bot's run through a boss
## arena: where it catches and lets go of things, and where it lands hits.
func _boss_trace(spec: String) -> void:
	var p := spec.split(":")
	var Phys = load("res://scripts/game/bike_physics.gd")
	var w = World.new()
	w.headless = true
	w.setup(p[0], {"bike": "scrambler", "ability": {}}, [], {"time": "dusk", "weather": p[1]})
	w.bot = Bot.new(w.level)
	var att := ""
	var hits := 0
	while w.result.is_empty() and w.ticks < 60 * 120:
		w.tick()
		var a: String = Phys.attachment(w.level, w.state)
		if a != att:
			print("  t=%.2f x=%.0f y=%.0f %s -> %s" % [w.ticks / 60.0, w.state.x, w.state.y, att, a])
			att = a
		if int(w.state.boss_hits) != hits:
			hits = int(w.state.boss_hits)
			print("  t=%.2f x=%.0f HIT %d" % [w.ticks / 60.0, w.state.x, hits])
	print("BOSS_TRACE %s loops=%d crashes=%d" % [spec, int(w.state.boss_loops), w.crashes])
	get_tree().quit()


## Dev (--guide-test --ride-trace=<level>:<weather>:<bike>:<x0>:<x1>): every frame of
## the bot's ride between x0 and x1.
func _ride_trace(spec: String) -> void:
	var p := spec.split(":")
	var Phys = load("res://scripts/game/bike_physics.gd")
	var w = World.new()
	w.headless = true
	w.setup(p[0], {"bike": p[2]}, [], {"time": "dusk", "weather": p[1]})
	w.bot = Bot.new(w.level)
	while w.result.is_empty() and w.ticks < 60 * 200 and w.crashes == 0:
		w.tick()
		if float(w.state.x) >= float(p[3]) and float(w.state.x) <= float(p[4]):
			var s: Dictionary = w.state
			print("  x=%.1f y=%.1f vx=%.0f vy=%.0f g=%s tr=%d att=%s held=%s whl=%s boost=%.1f" % [s.x, s.y, s.vx, s.vy, s.grounded, s.track,
				Phys.attachment(w.level, s), w.held_now, s.wheelie, s.boost])
	print("RIDE_TRACE crashes=%d %s" % [w.crashes, str(w.death_log)])
	get_tree().quit()
