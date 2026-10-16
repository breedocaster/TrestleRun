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
##        --guide-test --rope-windows[=<level>]: catch and let-go windows for every rope
##        --guide-test --pacing: checkpoint stretches, forced jumps and quiet stretches per trail
##        --guide-test --wheelie-probe: re-press timing before touchdown -> wheelie or jump
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
		if a.begins_with("--rope-windows"):
			_rope_windows(a.substr(15))
			return
		if a == "--pacing":
			_pacing()
			return
		if a == "--wheelie-probe":
			_wheelie_probe()
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
## Also: a tap during the wreck skips it, but only after CRASH_SKIP_TICKS.
func _flow() -> void:
	var w0 = World.new()
	w0.headless = true
	w0.setup("dusty_trail", {"bike": "scrambler", "ability": {}}, [], {"time": "dusk", "weather": "clear"})
	while w0.crashes == 0 and w0.ticks < 60 * 60:
		w0.tick()
	var tap := InputEventAction.new()
	tap.action = "jump"
	tap.pressed = true
	w0._unhandled_input(tap)
	var early: String = w0.phase
	for i in w0.CRASH_SKIP_TICKS:
		w0.tick()
	w0._unhandled_input(tap)
	print("SKIP tap at once -> %s, tap after %d ticks -> %s (x=%.0f)" % [early, w0.CRASH_SKIP_TICKS, w0.phase, w0.state.x])
	w0.free()
	Guide._wrecks = {}  # that wreck shouldn't count towards the hint check below
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


## Dev (--guide-test --rope-windows[=<level>]): for every rope, the catch window (press
## and keep holding, frames that catch it) and the let-go window (frames on the swing
## where letting go ends on a deck or on the next rope). Both in ms of the longest run.
func _rope_windows(only: String) -> void:
	var Phys = load("res://scripts/game/bike_physics.gd")
	for meta in Catalog.all_levels():
		if only != "" and String(meta.id) != only:
			continue
		var lv0: Dictionary = load("res://scripts/game/level_library.gd").build(String(meta.id))
		if (lv0.get("ropes", []) as Array).is_empty():
			continue
		for weather in ["clear", "rain", "wind"]:
			var w = World.new()
			w.headless = true
			w.setup(String(meta.id), {"bike": "scrambler", "ability": {}}, [], {"time": "dusk", "weather": weather})
			w.bot = Bot.new(w.level)
			w.bot.collect = false
			var lv: Dictionary = w.level
			var line := []
			for ri in lv.ropes.size():
				var rp: Dictionary = lv.ropes[ri]
				# Ride with the bot to well before this rope; skip ropes it reaches on a swing.
				# (the rope's own run-up deck is the 70 px ending 40 px before it)
				while (float(w.state.x) < float(rp.ax) - 108.0 or not w.state.grounded) and float(w.state.x) < float(rp.ax) - 44.0 \
						and w.result.is_empty() and w.crashes == 0:
					w.tick()
				if not w.result.is_empty() or w.crashes > 0:
					break
				var st0: Dictionary = Phys.copy_state(w.state)
				if not st0.grounded:
					line.append("r%d:air" % ri)
					continue
				# Catch: ride on k frames, then press and hold until caught.
				var st: Dictionary = Phys.copy_state(st0)
				var oks := []
				var catch_state := {}
				for k in 90:
					var s: Dictionary = Phys.copy_state(st)
					var got := false
					var late_mode := "--late" in OS.get_cmdline_user_args()
					for i in 200:
						# --late: a medium jump (14 frames held), then the button again only once the hands are
						# 10 px past the rope (catching it late).
						var hold: bool = (i < 14 or float(s.x) + 4.0 > float(rp.ax) + 10.0) if late_mode else true
						Phys.step(lv, s, i == 0, hold)
						if int(s.rope) == ri:
							got = true
							if catch_state.is_empty() or k == 45:
								catch_state = Phys.copy_state(s)
							break
						if not s.alive or (i > 2 and s.grounded):
							break
					oks.append(got)
					Phys.step(lv, st, false, false)
					if not st.alive or not st.grounded:
						break
				var cw := _longest(oks)
				# Let go: from the middle catch, hold k frames then release.
				var rel := []
				if not catch_state.is_empty():
					for k in 150:
						var s: Dictionary = Phys.copy_state(catch_state)
						var fine := false
						for i in 600:
							var h: bool = i < k or (i > k and Phys.auto_hold(lv, s))
							Phys.step(lv, s, false, h)
							if not s.alive:
								break
							if i >= k and (int(s.rope) > ri or (s.grounded and Phys.attachment(lv, s) == "")):
								fine = float(s.x) > float(rp.ax)
								break
						rel.append(fine)
						if int(Phys.copy_state(catch_state).rope) < 0:
							break
				line.append("r%d@%d catch %dms let-go %dms" % [ri, int(rp.ax), int(cw * 1000.0 / 60.0), int(_longest(rel) * 1000.0 / 60.0)])
			print("ROPES %-15s %-5s %s" % [String(meta.id), weather, " | ".join(line)])
			w.free()
	get_tree().quit()


static func _longest(a: Array) -> int:
	var best := 0
	var run := 0
	for v in a:
		run = run + 1 if v else 0
		best = maxi(best, run)
	return best


## Dev (--guide-test --pacing): per trail, how the ride is spread out: seconds between
## checkpoints, the forced jumps (the careful rider's), the longest stretch with nothing
## to do, and how many stretches go 6 s or more without a forced jump.
func _pacing() -> void:
	var Careful = load("res://scripts/dev/careful.gd")
	for meta in Catalog.all_levels():
		if meta.get("boss", false):
			continue
		var w = World.new()
		w.headless = true
		var wx := String(meta.cond.weather) if meta.has("cond") else "clear"
		w.setup(String(meta.id), {"bike": "scrambler", "ability": {}}, [], {"time": "dusk", "weather": wx})
		var bot = Bot.new(w.level)
		bot.collect = false
		var c = Careful.new()
		c.level = w.level
		c.bot = bot
		w.bot = c
		var ride := 0
		var xs := PackedFloat32Array()
		while w.result.is_empty() and w.ticks < 60 * 400 and w.crashes < 3:
			if w.phase == "ride":
				ride += 1
				xs.append(float(w.state.x))
			w.tick()
		var t_at := func(x: float) -> float:
			for i in xs.size():
				if xs[i] >= x:
					return i / 60.0
			return xs.size() / 60.0
		var cps := [0.0]
		for cp in w.level.checkpoints:
			cps.append(float(t_at.call(float(cp.x))))
		cps.append(ride / 60.0)
		var segs := []
		for i in cps.size() - 1:
			segs.append("%.0f" % (float(cps[i + 1]) - float(cps[i])))
		var ft := []
		for e in c.windows:
			ft.append(float(t_at.call(float(e.x))))
		ft.sort()
		var gaps := []
		var prev := 0.0
		var longest := 0.0
		var long_at := 0.0
		var n6 := 0
		for t in ft + [ride / 60.0]:
			var g: float = float(t) - prev
			if g >= 6.0:
				n6 += 1
			if g > longest:
				longest = g
				long_at = prev
			prev = float(t)
		print("PACE %-15s %-5s %4.1fs  checkpoint stretches %s s  forced %d  longest quiet %.1fs at %.0fs  quiet>=6s x%d  crashes %d" % [
			String(meta.id), wx, ride / 60.0, "/".join(segs), ft.size(), longest, long_at, n6, w.crashes])
		# What the quiet stretches (>= 7 s) are made of.
		prev = 0.0
		for t in ft + [ride / 60.0]:
			if float(t) - prev >= 7.0:
				var x0: float = xs[mini(int(prev * 60.0), xs.size() - 1)]
				var x1: float = xs[mini(int(float(t) * 60.0), xs.size() - 1)]
				var names := []
				for m in w.level.marks:
					if float(m[1]) >= x0 - 60.0 and float(m[1]) < x1:
						names.append(String(m[0]))
				print("   quiet %.1fs %.0f-%.0fs x%d-%d: %s" % [float(t) - prev, prev, float(t), int(x0), int(x1), " ".join(names)])
			prev = float(t)
		w.free()
	get_tree().quit()


## Dev (--guide-test --wheelie-probe): on a flat deck, jump, let go, then press again d
## frames before touchdown and keep holding: does it wheelie or jump again?
func _wheelie_probe() -> void:
	var Phys = load("res://scripts/game/bike_physics.gd")
	var w = World.new()
	w.headless = true
	w.setup("dusty_trail", {"bike": "scrambler"}, [], {"time": "dusk", "weather": "clear"})
	w.phase = "ride"
	var s0: Dictionary = Phys.copy_state(w.state)
	# Where a 14-frame jump lands (frames from the press).
	var s: Dictionary = Phys.copy_state(s0)
	var land := -1
	for i in 120:
		Phys.step(w.level, s, i == 0, i < 14)
		if i > 1 and s.grounded:
			land = i
			break
	var out := []
	for d in range(-3, 12):
		s = Phys.copy_state(s0)
		var res := "-"
		var p := land - d
		for i in 160:
			var held: bool = i < 14 or i >= p
			var ev: int = Phys.step(w.level, s, i == 0 or i == p, held)
			if i > land and (ev & Phys.EV_JUMP):
				res = "JUMP"
				break
			if i > land + 4 and s.wheelie:
				res = "WHEELIE"
				break
		out.append("%+d:%s" % [d, res])
	print("WHEELIE_PROBE land@%d  (frames the re-press came before touchdown: result)  %s" % [land, " ".join(out)])
	get_tree().quit()
