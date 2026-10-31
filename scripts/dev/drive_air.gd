## --drive-air: which jumps on each SUMMIT and GAUNTLET level have room for which air
## trick, so objectives and events only ask for tricks that can be done. Replays the
## level's GOLD LINE (the checker's own ride, assets/lines); at each takeoff where that
## ride is in the air AIR_MIN or more, tries each trick from there the way a quick thumb
## would do it (two taps TAP_ON frames down, TAP_OFF apart, starting as soon as taps
## count), run through tricks.gd as the game does, then has the search ride on from
## wherever that left the bike to make sure it can be landed and ridden away.
##   --mode=summit|gauntlet  --only=0,3
## Also counts what that ride did (coins picked up, fuel left at the top, its longest
## jump, hops) and makes each level's three objectives from all that and the bikes the
## level checker got through (objectives.gd; the rules are in _objectives below).
##   --write   rewrite scripts/drive/extras_table.gd (JUMPS, STATS, OBJECTIVES)
extends Node

const Summit := preload("res://scripts/drive/summit_levels.gd")
const Gauntlet := preload("res://scripts/drive/gauntlet_levels.gd")
const Search := preload("res://scripts/drive/drive_search.gd")
const Ghost := preload("res://scripts/drive/ghost.gd")
const Tricks := preload("res://scripts/drive/tricks.gd")
const Vehicles := preload("res://scripts/drive/vehicles.gd")
const DriveTable := preload("res://scripts/drive/drive_table.gd")

const REF := "scrambler"
const AIR_MIN := 0.25
const TAP_ON := 4
const TAP_OFF := 4


func _ready() -> void:
	var modes := ["summit", "gauntlet"]
	var only := []
	var write := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mode="):
			modes = [a.substr(7)]
		elif a.begins_with("--only="):
			only = Array(a.substr(7).split(",")).map(func(s): return int(s))
		elif a == "--write":
			write = true
	var table := {}
	var stats := {}
	var objs := {}
	for mode in modes:
		var n: int = Summit.count() if mode == "summit" else Gauntlet.count()
		for i in n:
			if not only.is_empty() and not only.has(i):
				continue
			var lv: Dictionary = Summit.build(i) if mode == "summit" else Gauntlet.build(i)
			var res = check_level(lv)
			if res == null:
				print("%-14s no gold line (--drive-levels --lines)" % lv.id)
				continue
			var jumps: Array = res.jumps
			table[lv.id] = jumps
			stats[lv.id] = res.stats
			objs[lv.id] = _objectives(mode, i, jumps, res.stats)
			var fits := {}
			for j in jumps:
				for t in j[2]:
					fits[t] = int(fits.get(t, 0)) + 1
			print("%-14s %d jumps of %.2fs+: %s" % [lv.id, jumps.size(), AIR_MIN, ", ".join(jumps.map(func(j):
				return "x%d %.2fs [%s]" % [int(j[0]), float(j[1]), " ".join(j[2])]))])
			print("               fits: %s  stats: %s" % [str(fits), str(res.stats)])
			print("               objectives: %s" % str(objs[lv.id]))
	print("DRIVE AIR done")
	if write:
		_write(table, stats, objs)
	get_tree().quit()


## {"jumps": [[takeoff x, the line's air time, [trick ids that fit]]], "stats": {coins,
## fuel_left, max_air, hops}} for a level, or null without a gold line.
static func check_level(lv: Dictionary):
	var line := Ghost.load_line(String(lv.id))
	if line.is_empty():
		return null
	return check_path(lv, line.up, line.path)


## The same for any winning ride of the reference bike (inputs per search block).
static func check_path(lv: Dictionary, up: Dictionary, path: PackedByteArray) -> Dictionary:
	var s = Search.start_sim(lv, REF, 0.0, up)
	var states := []
	var ground := []
	# What the ride picks up, as drive_world.gd counts it.
	var got := {}
	var coins := 0
	var tank: float = Vehicles.tank_seconds(REF, up)
	var fuel := tank
	var cans := {}
	var max_air := 0.0
	for ai in path:
		var act: Vector2 = Search.ACTIONS[ai]
		for k in Search.BLOCK:
			s.gas = act.x
			s.brake = act.y
			s.step()
			states.append(s.save())
			ground.append(bool(s.grounded))
			max_air = maxf(max_air, float(s.airtime))
			fuel -= 1.0 / 60.0
			var cl: Array = lv.get("coins", [])
			for ci in cl.size():
				if not got.has(ci) and (cl[ci][0] as Vector2).distance_squared_to(s.pos) < 196.0:
					got[ci] = true
					coins += int(cl[ci][1])
			var fl: Array = lv.get("fuel", [])
			for fi in fl.size():
				if not cans.has(fi) and (fl[fi] as Vector2).distance_squared_to(s.pos) < 256.0:
					cans[fi] = true
					fuel = tank
	var stats := {"coins": coins, "fuel_left": snappedf(maxf(fuel, 0.0) / tank, 0.01) if lv.get("mode", "") == "summit" else 0.0,
		"max_air": snappedf(max_air, 0.01), "hops": int(s.hops)}
	var out := []
	var f := 1
	while f < ground.size():
		if ground[f - 1] and not ground[f]:
			var e := f
			while e < ground.size() and not ground[e]:
				e += 1
			var air := float(e - f) / 60.0
			if air >= AIR_MIN:
				var x0: float = (states[f][0] as Vector2).x
				var ok := []
				for key in Tricks.TRICKS:
					if try_trick(lv, up, states[f - 1], key, x0) == "ok":
						ok.append(String(Tricks.TRICKS[key].id))
				out.append([snappedf(x0, 1.0), snappedf(air, 0.01), ok])
			f = e
		f += 1
	return {"jumps": out, "stats": stats}


## From the frame before a takeoff, ride off with no input until taps count, tap the
## trick out, wait while it lasts, then let the search take over. "ok", or why not.
static func try_trick(lv: Dictionary, up: Dictionary, state: Array, key: String, x0: float) -> String:
	var s = Search.start_sim(lv, REF, 0.0, up)
	s.load_state(state)
	var tk = Tricks.new()
	var start := -1
	for f in 300:
		var g := 0.0
		var b := 0.0
		if start < 0 and not s.grounded and float(s.airtime) >= Tricks.MIN_AIR:
			start = f
		if start >= 0:
			var k := f - start
			var press := k < TAP_ON or (k >= TAP_ON + TAP_OFF and k < 2 * TAP_ON + TAP_OFF)
			if press:
				var c := key[0] if k < TAP_ON else key[1]
				g = 1.0 if c == "G" else 0.0
				b = 1.0 if c == "B" else 0.0
		s.gas = g
		s.brake = b
		s.step()
		tk.update(1.0 / 60.0, g > 0.5, b > 0.5, bool(s.grounded), float(s.airtime))
		s.air_lock = not tk.active.is_empty() and not tk.pending
		for e in tk.events:
			if e[0] == "bail":
				return "bail"
			if e[0] == "cancel":
				return "cancelled"
		if s.crashed:
			return "crash"
		if tk.landed > 0:
			break
		if s.grounded and f > 2 and start >= 0 and tk.active.is_empty():
			return "landed first"
	if tk.landed == 0:
		return "no trick"
	var r: Dictionary = Search.solve(lv, REF, s.pos.x, x0 + 360.0, 12, 10.0, up, 1.0, s.save())
	return "ok" if r.ok else "no recovery"


## A level's three objectives, easy to hard, from what the checker's ride showed can be
## done (and only that): pick up 60% of the coins it did; land half as many tricks as
## there are jumps where one fit, or score that many points (GAUNTLET), or a long jump;
## then by turns a trick that fit, a bike class it got through, the fuel it had left
## (SUMMIT) or its hops plus a couple (GAUNTLET). GAUNTLET's first is a clean run.
static func _objectives(mode: String, i: int, jumps: Array, st: Dictionary) -> Array:
	var any := jumps.filter(func(j): return not (j[2] as Array).is_empty()).size()
	var best_trick := ""
	for id in ["superman", "heel", "nohander", "whip"]:
		for j in jumps:
			if (j[2] as Array).has(id) and best_trick == "":
				best_trick = id
	var bikes: Array = DriveTable.RIDEABLE.get(_id(mode, i), [])
	var uni := bikes.filter(func(b): return bool(Vehicles.spec(b).get("unicycle", false))).size() > 0
	var elec := bikes.filter(func(b): return Vehicles.is_electric(b) and not bool(Vehicles.spec(b).get("unicycle", false))).size() > 0
	var out := []
	if mode == "gauntlet":
		out.append(["clean"])
	else:
		out.append(["coins", maxi(5, int(floorf(float(st.coins) * 0.6 / 5.0)) * 5)])
	# Second: the air.
	if any > 0:
		if mode == "gauntlet" and i % 2 == 0:
			out.append(["points", 100 * maxi(1, ceili(any * 0.5))])
		else:
			out.append(["tricks", maxi(1, ceili(any * 0.5))])
	elif mode == "summit" and float(st.fuel_left) >= 0.2:
		out.append(["fuel", int(floorf(float(st.fuel_left) * 60.0 / 5.0)) * 5])
	elif float(st.max_air) >= 0.3:
		out.append(["air", snappedf(float(st.max_air) * 0.9, 0.1)])
	else:
		out.append(["hops", int(st.hops) + 3] if mode == "gauntlet" else ["coins", maxi(5, int(floorf(float(st.coins) * 0.8 / 5.0)) * 5)])
	# Third, by turns.
	var options := []
	var turn := i % 3
	var bike_o = ["bike", "unicycle"] if uni else (["bike", "electric"] if elec else null)
	var trick_o = ["trick", best_trick] if best_trick in ["heel", "superman"] or (best_trick != "" and any > 1) else null
	var other_o = (["fuel", int(floorf(float(st.fuel_left) * 60.0 / 5.0)) * 5] if mode == "summit" and float(st.fuel_left) >= 0.2
		else (["hops", int(st.hops) + 2] if mode == "gauntlet" and int(st.hops) > 0 else null))
	options = [bike_o, trick_o, other_o]
	# (Never two of one kind in a level's three.)
	var used := out.map(func(o): return String(o[0]))
	for k in 3:
		var o = options[(turn + k) % 3]
		if o != null and not used.has(String(o[0])):
			out.append(o)
			break
	if out.size() < 3:
		var spare := [
			["air", snappedf(float(st.max_air) * 0.8, 0.1)] if float(st.max_air) >= 0.25 else null,
			["bike", "electric"] if elec else null,
			["hops", int(st.hops) + 3] if mode == "gauntlet" else null,
			["fuel", int(floorf(float(st.fuel_left) * 60.0 / 5.0)) * 5] if mode == "summit" and float(st.fuel_left) >= 0.1 else null,
		]
		for o in spare:
			if o != null and not used.has(String(o[0])):
				out.append(o)
				break
	return out


static func _id(mode: String, i: int) -> String:
	return String((Summit.LEVELS if mode == "summit" else Gauntlet.LEVELS)[i].id)


func _write(table: Dictionary, stats: Dictionary, objs: Dictionary) -> void:
	var path := ProjectSettings.globalize_path("res://scripts/drive/extras_table.gd")
	var fresh = ResourceLoader.load("res://scripts/drive/extras_table.gd", "", ResourceLoader.CACHE_MODE_IGNORE)
	var all := {"JUMPS": (fresh.JUMPS as Dictionary).duplicate(true), "STATS": (fresh.STATS as Dictionary).duplicate(true),
		"OBJECTIVES": (fresh.OBJECTIVES as Dictionary).duplicate(true)}
	all.JUMPS.merge(table, true)
	all.STATS.merge(stats, true)
	all.OBJECTIVES.merge(objs, true)
	var lines := [
		"## Per SUMMIT and GAUNTLET level, from the level checker's gold line: the jumps with room",
		"## for an air trick ([takeoff x, s in the air, [tricks that fit]]), what its ride did",
		"## (STATS), and the three objectives made from those (objectives.gd). Written by",
		"##   godot --headless --path . -- --drive-air --write",
		"extends RefCounted",
	]
	for name in ["JUMPS", "STATS", "OBJECTIVES"]:
		lines.append("")
		lines.append("const %s := {" % name)
		var ids: Array = (all[name] as Dictionary).keys()
		ids.sort()
		for id in ids:
			lines.append("\t\"%s\": %s," % [id, JSON.stringify(all[name][id])])
		lines.append("}")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	print("wrote ", path)
