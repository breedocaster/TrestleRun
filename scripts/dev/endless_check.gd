## Endless stretch checker (dev): rides every stretch (Endless.sections) on its own at
## each speed in Endless.TIERS. Per speed: the bot in clear weather at three different
## arrival times (lifts and critters move on the clock, so a stretch has to work
## whenever you get there), once in rain and once in wind; then the careful rider in
## clear for the timing windows. One JSON line per stretch and speed:
##   ENDLESS {"key", "tier", "ok": [clear, rain, wind], "t": [s, s, s], "len": px,
##            "w": [window ms...], "min": ms, "careful_crashes": n}
## tools/endless/make_table.py turns the lines into scripts/game/endless_table.gd.
## Flags: --endless-check [--part=k/n] [--only=<key>] [--tiers=118,130]
extends Node

const World := preload("res://scripts/game/world.gd")
const Bot := preload("res://scripts/game/autopilot.gd")
const Careful := preload("res://scripts/dev/careful.gd")
const Endless := preload("res://scripts/game/endless.gd")
const Library := preload("res://scripts/game/level_library.gd")
const Phys := preload("res://scripts/game/bike_physics.gd")

const OFFSETS := [0.0, 0.85, 1.7]  # s of extra run-up before the stretch
var offsets: Array = OFFSETS


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--endless-ride="):
			_ride_courses(a.substr(15))
			get_tree().quit()
			return
		if a.begins_with("--pair="):
			# Two stretches back to back at one speed (does the first one spoil the second?).
			var ks := a.substr(7).split(",")
			var tier := 154.0
			for b2 in OS.get_cmdline_user_args():
				if b2.begins_with("--tier="):
					tier = float(b2.substr(7))
			var plan := []
			for k in ks:
				plan.append([k, tier])
			var y0 := 0.0
			for b4 in OS.get_cmdline_user_args():
				if b4.begins_with("--y0="):
					y0 = float(b4.substr(5))
			var lv := Endless.build(plan, {"id": "endless", "name": "E", "theme": 0, "speed": tier}, {"y0": y0})
			var w = World.new()
			w.headless = true
			w.setup("endless", {"bike": "scrambler", "ability": {}}, [], {"time": "dusk", "weather": "clear"}, lv)
			w.mode = "endless"
			w.one_life = true
			w.bot = Bot.new(w.level)
			var cr = null
			if "--careful" in OS.get_cmdline_user_args():
				w.bot.collect = false
				cr = Careful.new()
				cr.level = w.level
				cr.bot = w.bot
				w.bot = cr
			if "--hat" in OS.get_cmdline_user_args():
				w.state.hat = 1
			var hist := []
			var tx := Vector2(INF, -INF)
			for b3 in OS.get_cmdline_user_args():
				if b3.begins_with("--trace-x="):
					var tt := b3.substr(10).split(":")
					tx = Vector2(float(tt[0]), float(tt[1]))
			while w.result.is_empty() and w.ticks < 60 * 300 and w.crashes == 0:
				w.tick()
				if float(w.state.x) >= tx.x and float(w.state.x) <= tx.y:
					print("T x=%.0f y=%.1f g=%s tr=%d vy=%.0f held=%s" % [w.state.x, w.state.y, w.state.grounded, int(w.state.track), w.state.vy, w.held_now])
				hist.append("x=%.0f y=%.1f g=%s tr=%d vy=%.0f att=%s held=%s" % [w.state.x, w.state.y, w.state.grounded,
					int(w.state.track), w.state.vy, Phys.attachment(w.level, w.state), w.held_now])
				if hist.size() > 90:
					hist.pop_front()
			if w.crashes > 0 and "--why" in OS.get_cmdline_user_args():
				for h in hist.slice(hist.size() - 90, hist.size(), 6):
					print("  ", h)
				print("kill_y ", w.level.kill_y)
				var dx := float(w.death_log[0].x)
				for ti in w.level.tracks.size():
					var tr: Dictionary = w.level.tracks[ti]
					if tr.x1 > dx - 300 and tr.x0 < dx + 200:
						print("  track %d lane %d x %.0f-%.0f y %.0f-%.0f %s" % [ti, tr.lane, tr.x0, tr.x1, tr.pts[0].y, tr.pts[tr.pts.size() - 1].y, tr.get("hold", "")])
			if cr != null:
				var ms: Array = cr.windows.map(func(e): return int(e.ms))
				ms.sort()
				print("CAREFUL windows ", ms.slice(0, 8))
			print("PAIR %s crashes=%d deaths=%s stretches=%s" % [ks, w.crashes, w.death_log,
				(w.level.stretches as Array).map(func(e): return [int(e[0]), e[1]])])
			get_tree().quit()
			return
		if a == "--endless-stats":
			var t0 := Time.get_ticks_usec()
			var plan := Endless.endless_plan(7)
			var t1 := Time.get_ticks_usec()
			var lv := Endless.build(plan, {"id": "endless", "name": "E", "theme": 0, "speed": 118.0})
			var t2 := Time.get_ticks_usec()
			print("STATS plan %d stretches %.1f ms, build %.1f ms; %d m; tracks %d pickups %d enemies %d zips %d ropes %d" % [
				plan.size(), (t1 - t0) / 1000.0, (t2 - t1) / 1000.0, Endless.metres(lv, float(lv.finish_x)),
				lv.tracks.size(), lv.pickups.size(), lv.enemies.size(), lv.zips.size(), lv.ropes.size()])
			get_tree().quit()
			return
	var part := 0
	var parts := 1
	var only := ""
	var tiers: Array = Endless.TIERS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--part="):
			var pp := a.substr(7).split("/")
			part = int(pp[0])
			parts = int(pp[1])
		elif a.begins_with("--only="):
			only = a.substr(7)
		elif a.begins_with("--tiers="):
			tiers = Array(a.substr(8).split(",")).map(func(v): return float(v))
		elif a.begins_with("--offsets="):
			offsets = Array(a.substr(10).split(",")).map(func(v): return float(v))
	var secs := Endless.sections()
	var t0 := Time.get_ticks_msec()
	for i in secs.size():
		var sec: Dictionary = secs[i]
		if i % parts != part or (only != "" and sec.key != only):
			continue
		for tier in tiers:
			_check(sec, float(tier))
	print("ENDLESS_DONE %d stretches in %d s" % [secs.size(), (Time.get_ticks_msec() - t0) / 1000])
	get_tree().quit()


func _check(sec: Dictionary, tier: float) -> void:
	var ok := [true, true, true]
	var times := [0.0, 0.0, 0.0]
	var length := 0.0
	var deaths := []
	for oi in offsets.size():
		var r := _ride(sec, tier, "clear", float(offsets[oi]), false)
		ok[0] = ok[0] and bool(r.ok)
		if oi == 0:
			times[0] = r.t
			length = r.len
		if not r.ok:
			deaths.append(["clear", oi, r.deaths])
	for wi in [1, 2]:
		var wx: String = ["clear", "rain", "wind"][wi]
		var r := _ride(sec, tier, wx, float(OFFSETS[1]), false)
		ok[wi] = bool(r.ok)
		times[wi] = r.t
		if not r.ok:
			deaths.append([wx, 1, r.deaths])
	var c := _ride(sec, tier, "clear", 0.0, true)
	var ws: Array = c.windows
	ws.sort()
	var mn: float = 999.0 if ws.is_empty() else float(ws[0])
	if int(c.crashes) > 0:
		mn = 0.0
	print("ENDLESS " + JSON.stringify({"key": sec.key, "tier": int(tier), "ok": ok,
		"t": times.map(func(v): return snappedf(v, 0.01)), "len": snappedf(length, 1.0),
		"w": ws.map(func(v): return int(v)), "min": int(mn), "careful_crashes": int(c.crashes),
		"deaths": deaths}))


## One stretch on its own: start, a joint, the stretch, a joint, the finish.
func _test_level(sec: Dictionary, tier: float, offset_s: float) -> Dictionary:
	var b = Library.new()
	b.level_id = "endless_test"
	b.no_letters_here = true
	b.c_start(220.0 + offset_s * tier)
	Endless.joint(b, false)
	var x0: float = b.x
	for c in sec.chunks:
		b.marks.append([String(c[0]), snappedf(b.x, 1.0)])
		b.callv("c_" + String(c[0]), c.slice(1))
	var x1: float = b.x
	Endless.joint(b, false)
	b.c_finish()
	var lv: Dictionary = b._finalize({"id": "endless_test", "name": "TEST", "speed": tier, "theme": 0})
	lv.marks = b.marks
	Endless.gears_to_bags(lv)
	lv.test_x0 = x0
	lv.test_x1 = x1
	return lv


func _ride(sec: Dictionary, tier: float, weather: String, offset_s: float, careful: bool) -> Dictionary:
	var lv := _test_level(sec, tier, offset_s)
	var w = World.new()
	w.headless = true
	w.setup("endless_test", {"bike": "scrambler", "ability": {}}, [], {"time": "dusk", "weather": weather}, lv)
	var bot = Bot.new(w.level)
	var c = null
	if careful:
		bot.collect = false
		c = Careful.new()
		c.level = w.level
		c.bot = bot
		w.bot = c
	else:
		w.bot = bot
	var t_in := -1.0
	var t_out := -1.0
	var x0 := float(lv.test_x0)
	var x1 := float(lv.test_x1)
	var max_crashes := 3 if careful else 1
	while w.result.is_empty() and w.ticks < 60 * 120 and w.crashes < max_crashes:
		w.tick()
		if t_in < 0.0 and float(w.state.x) >= x0:
			t_in = w.ride_time
		if t_out < 0.0 and float(w.state.x) >= x1:
			t_out = w.ride_time
	var out := {"ok": not w.result.is_empty() and w.crashes == 0, "t": maxf(0.0, t_out - t_in),
		"len": x1 - x0, "deaths": w.death_log.duplicate(), "crashes": w.crashes, "windows": []}
	if careful:
		for e in c.windows:
			if float(e.x) >= x0 - 20.0 and float(e.x) <= x1 + 20.0:
				out.windows.append(float(e.ms))
	w.free()
	return out


## --endless-ride=<seeds, e.g. 1-20> [--bike=<id>|all] [--weather=] [--mode=endless|daily|league]:
## the bot rides whole built courses; a crash (anywhere) is a failure. Prints
## RIDE {"seed", "bike", "metres", "end", "crash_at", "stretch", "sim_s"} per course.
func _ride_courses(spec: String) -> void:
	var seeds := []
	var se := spec.split("-")
	for k in range(int(se[0]), int(se[se.size() - 1]) + 1):
		seeds.append(k)
	var bikes := ["none"]
	var weather := "clear"
	var mode := "endless"
	var max_m := 999999
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--bike="):
			var b := a.substr(7)
			bikes = [b] if b != "all" else ["none", "dirt", "minibike", "scooter", "cafe", "chopper", "sport"]
		elif a.begins_with("--weather="):
			weather = a.substr(10)
		elif a.begins_with("--mode="):
			mode = a.substr(7)
		elif a.begins_with("--max-m="):
			max_m = int(a.substr(8))
	var fails := 0
	for seed in seeds:
		var plan: Array
		if mode == "daily":
			plan = Endless.daily_plan(seed, Endless.TIERS[seed % Endless.TIERS.size()], weather)
		else:
			plan = Endless.endless_plan(seed)
		var lv := Endless.build(plan, {"id": mode, "name": mode, "theme": 0, "speed": Endless.TIERS[0]},
			{"checkpoints": mode == "daily", "letters": mode == "daily" and not "--no-letters" in OS.get_cmdline_user_args()})
		for bike in bikes:
			var w = World.new()
			w.headless = true
			var rig := {"bike": "scrambler", "ability": {}} if bike == "none" else {"bike": bike}
			w.setup(mode, rig, [], {"time": "dusk", "weather": weather}, lv.duplicate(true))
			w.mode = mode
			w.one_life = mode != "daily"
			w.bot = Bot.new(w.level)
			var t0 := Time.get_ticks_msec()
			while w.result.is_empty() and w.ticks < 60 * 1800 and w.crashes == 0 and w.metres() < max_m:
				w.tick()
			var sti := Endless.stretch_at(w.level, float(w.state.x))
			var ok: bool = w.crashes == 0
			if not ok:
				fails += 1
			if w.crashes > 0 and "--why" in OS.get_cmdline_user_args():
				var dx := float(w.death_log[0].x)
				print("WHY stretches ", (w.level.stretches as Array).map(func(e): return [int(e[0]), e[1]]))
				print("WHY marks ", (w.level.marks as Array).filter(func(m): return absf(float(m[1]) - dx) < 400.0))
			print("RIDE " + JSON.stringify({"seed": seed, "bike": bike, "weather": weather, "metres": w.metres(),
				"end": "finish" if not w.result.is_empty() and w.crashes == 0 else ("crash" if w.crashes > 0 else "cap"),
				"crash_at": w.death_log, "stretch": String(w.level.stretches[sti][1]) if sti >= 0 else "",
				"speed": float(w.level.speed), "sim_s": (Time.get_ticks_msec() - t0) / 1000.0}))
			w.free()
	print("RIDE_DONE fails=%d" % fails)
