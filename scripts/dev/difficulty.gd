## Difficulty meter (dev only). Rides each trail like a careful human: whenever riding on
## would crash, it finds the run of frames in which pressing still works (the timing
## window) and presses in the middle of it. Smaller windows and more forced jumps per
## 10 s = harder. Prints one line per trail, with the tightest spots and their chunks.
## Flags: --difficulty [--weather=clear|rain|wind] [--level=<id>] [--old]
extends Node

const World := preload("res://scripts/game/world.gd")
const Bot := preload("res://scripts/game/autopilot.gd")
const Phys := preload("res://scripts/game/bike_physics.gd")
const Catalog := preload("res://scripts/catalog.gd")
const Library := preload("res://scripts/game/level_library.gd")

const PROBE_HOLDS := [3, 5, 7, 9, 12, 16, 22, 30]
const LOOK := 70


## Drives the world in place of the bot.
class Careful:
	var level: Dictionary
	var bot
	var windows: Array = []
	var _plan_in := -1
	var _death_x := 0.0
	var _plan_hold := 0
	var _hold_left := 0

	func decide(s: Dictionary) -> Array:
		if int(s.zip) >= 0:
			_hold_left = 0
			return [false, not bot._release_better(s)]
		if _hold_left > 0:
			_hold_left -= 1
			return [false, true]
		if _plan_in > 0:
			_plan_in -= 1
			return [false, false]
		if _plan_in == 0:
			_plan_in = -1
			_hold_left = _plan_hold - 1
			return [true, true]
		if not s.grounded and float(s.coyote) <= 0.0:
			return [false, false]
		if bot._ride(s, bot.horizon).safe:
			return [false, false]
		# Riding on crashes at death_x. Scan ahead for the frames where a press gets
		# you past that point.
		var dx: Dictionary = bot._copy(s)
		var leave_x := float(dx.x)
		for k in 200:
			var ev := Phys.step(level, dx, false, false)
			if ev & Phys.EV_LEAVE:
				leave_x = float(dx.x)
			if not dx.alive:
				break
		# A fall counts from where the wheels left the deck; a crash from the hit.
		_death_x = leave_x if dx.death == "fall" else float(dx.x)
		var st: Dictionary = bot._copy(s)
		var first := -1
		var last := -1
		var mid_state: Dictionary = {}
		var states := []
		for k in LOOK:
			var ok := _good_holds(st)
			states.append([bot._copy(st), ok])
			if not ok.is_empty():
				if first < 0:
					first = k
				last = k
			elif first >= 0:
				break
			Phys.step(level, st, false, false)
			if not st.alive:
				break
		if first < 0:
			if OS.get_cmdline_user_args().has("--dbg"):
				print("DBG none at x=%.1f y=%.1f g=%s coy=%.3f vy=%.1f zip=%d loop=%d track=%d" % [s.x, s.y, s.grounded, s.coyote, s.vy, s.zip, s.loop, s.track])
			windows.append({"ms": 0.0, "x": s.x})
			return [false, false]
		var n := last - first + 1
		if OS.get_cmdline_user_args().has("--dbg"):
			print("DBG at x=%.0f first=%d last=%d" % [s.x, first, last])
		windows.append({"ms": n * 1000.0 / 60.0, "x": float(s.x) + (first + n / 2) * float(s.vx) / 60.0})
		var mid := first + n / 2
		# Like a person: jump to get past the trouble, not a hop that lands in front of
		# it. Among equally good holds take the middle one; if none leaves any free
		# riding, take the one that lands farthest on.
		var scored := []
		var top := -1
		for h in states[mid][1]:
			var f := _free_after(states[mid][0], h)
			var free := int(f / 100000.0) if f >= 0.0 else -1
			scored.append([h, free, f])
			top = maxi(top, free)
		var best_h := 0
		var best_free := -2.0
		if top > 0:
			var tops := scored.filter(func(e): return e[1] == top)
			best_h = tops[tops.size() / 2][0]
			best_free = tops[tops.size() / 2][2]
		else:
			for e in scored:
				if e[2] > best_free:
					best_free = e[2]
					best_h = e[0]
		_plan_hold = best_h
		if OS.get_cmdline_user_args().has("--dbg"):
			print("DBG   plan mid=%d hold=%d free=%.0f holds=%s" % [mid, best_h, best_free, str(states[mid][1])])
		if mid == 0:
			_hold_left = _plan_hold - 1
			return [true, true]
		_plan_in = mid - 1
		return [false, false]

	## Jump with this hold, then count frames of riding before you'd have to act again
	## (ties go to the jump that lands farthest on).
	func _free_after(s0: Dictionary, hold: int) -> float:
		var s: Dictionary = bot._copy(s0)
		var i := 0
		while i < 400:
			var hanging := int(s.zip) >= 0
			Phys.step(level, s, i == 0, i < hold or hanging)
			i += 1
			if not s.alive:
				return -1.0
			if i > 1 and s.grounded:
				break
		var land_x: float = s.x
		var free := 0
		while free < 66:
			if not bot._ride(s, 30).safe:
				break
			Phys.step(level, s, false, false)
			free += 3
			for k in 2:
				Phys.step(level, s, false, false)
			if not s.alive:
				break
		return free * 100000.0 + land_x

	func _good_holds(s: Dictionary) -> Array:
		var out := []
		if not s.alive or not (s.grounded or float(s.coyote) > 0.0) or int(s.loop) >= 0:
			return out
		for h in PROBE_HOLDS:
			if bot._jump(s, h, 1).safe and _land_x(s, h) > _death_x - 4.0:
				out.append(h)
		return out

	func _land_x(s0: Dictionary, hold: int) -> float:
		var s: Dictionary = bot._copy(s0)
		for i in 600:
			var hanging := int(s.zip) >= 0
			Phys.step(level, s, i == 0, i < hold or hanging)
			if not s.alive:
				return -INF
			if i > 1 and s.grounded:
				return float(s.x)
		return -INF


func _ready() -> void:
	var weather := "clear"
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--weather="):
			weather = a.substr(10)
		elif a.begins_with("--level="):
			only = a.substr(8)
	for i in Catalog.levels().size():
		var meta: Dictionary = Catalog.levels()[i]
		if only != "" and meta.id != only:
			continue
		_measure(i, meta, weather, {})
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
	print("DIFF %d %-18s %3d px/s %4.1fs crashes %d | forced %2d = %4.1f/10s | window ms min %3d p10 %3d p25 %3d med %3d | tight %s" % [
		idx + 1, meta.id, int(meta.speed), secs, w.crashes, n, n / secs * 10.0,
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
