## --drive-levels: rides SUMMIT and GAUNTLET levels with the input search (the game's
## own sim, gas / coast / brake every 0.1 s), proving each can be finished and timing
## it for the medal pars.
##   --mode=summit|gauntlet   both when left out
##   --only=0,3               level indexes
##   --bikes=a,b | all        default: the free SCRAMBLER, which pars are timed on
##   --beam=n                 search width (default 24)
##   --write                  rewrite drive_table.gd: pars from the SCRAMBLER's times,
##                            and per level the bikes that made it (with more than one
##                            bike; added to what's there, so clear RIDEABLE first)
## GAUNTLET rides section by section (checkpoint to checkpoint), carrying the bike's
## speed across, then each section again from a standstill (as after a fault); SUMMIT
## rides fuel can to fuel can and fails if a leg takes longer than a tank: the SCRAMBLER
## on the level's listed upgrades (up_req), other bikes fully upgraded.
extends Node

const Summit := preload("res://scripts/drive/summit_levels.gd")
const Gauntlet := preload("res://scripts/drive/gauntlet_levels.gd")
const Search := preload("res://scripts/drive/drive_search.gd")
const Vehicles := preload("res://scripts/drive/vehicles.gd")
const Catalog := preload("res://scripts/catalog.gd")

const REF := "scrambler"
## Medal pars from the reference bike's searched time: the search rides near-perfect
## lines, so gold leaves some room and silver a lot.
const GOLD_K := 1.15
const SILVER_K := 1.45


func _ready() -> void:
	var modes := ["summit", "gauntlet"]
	var only := []
	var bikes := [REF]
	var beam := 24
	var write := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mode="):
			modes = [a.substr(7)]
		elif a.begins_with("--only="):
			only = Array(a.substr(7).split(",")).map(func(s): return int(s))
		elif a.begins_with("--bikes="):
			var v := a.substr(8)
			if v == "all":
				bikes = Catalog.bikes().map(func(b): return String(b.id))
			else:
				bikes = Array(v.split(","))
		elif a.begins_with("--beam="):
			beam = int(a.substr(7))
		elif a == "--write":
			write = true
	# Only this run's results; merged into the table as it is on disk when writing, so
	# runs split over several processes (--only=...) can each --write.
	var pars := {}
	var rideable := {}
	var fails := 0
	for mode in modes:
		var n: int = Summit.count() if mode == "summit" else Gauntlet.count()
		for i in n:
			if not only.is_empty() and not only.has(i):
				continue
			var lv: Dictionary = Summit.build(i) if mode == "summit" else Gauntlet.build(i)
			var id := String(lv.id)
			var ok_bikes := []
			for b in bikes:
				var t0 := Time.get_ticks_msec()
				var r: Dictionary = _ride_summit(lv, i, b, beam) if mode == "summit" else _ride_gauntlet(lv, b, beam)
				var ms := Time.get_ticks_msec() - t0
				if r.ok:
					ok_bikes.append(b)
					print("%-14s %-10s ok %6.1fs   (%d legs, %.0fs to check)" % [id, b, r.time, r.legs, ms / 1000.0])
					if b == REF:
						pars[id] = [ceilf(float(r.time) * GOLD_K), ceilf(float(r.time) * SILVER_K)]
				else:
					fails += 1
					print("%-14s %-10s FAIL leg %d of %d at x=%.0f (%.0f%%)%s%s" % [id, b, r.leg, r.legs, r.best_x,
						100.0 * float(r.best_x) / float(lv.finish_x), "  " + String(r.get("why", "")), _near(lv, float(r.best_x))])
			if bikes.size() > 1:
				rideable[id] = ok_bikes
	print("DRIVE LEVELS done, %d fail(s)" % fails)
	if write:
		_write(pars, rideable)
	get_tree().quit()


## GAUNTLET: the moves around where a ride got stuck.
func _near(lv: Dictionary, x: float) -> String:
	var marks: Array = lv.get("marks", [])
	var out := []
	for k in marks.size():
		if float(marks[k][0]) <= x + 40.0 and (k + 1 >= marks.size() or float(marks[k + 1][0]) >= x - 60.0):
			out.append("%s@%.0f" % [str(marks[k][1]), float(marks[k][0])])
	return "" if out.is_empty() else "  near " + " ".join(out)


func _ride_gauntlet(lv: Dictionary, bike: String, beam: int) -> Dictionary:
	var targets: Array = (lv.checkpoints as Array).duplicate()
	targets.append(float(lv.finish_x))
	var state = null
	var x := 0.0
	var frames := 0
	for k in targets.size():
		var r: Dictionary = Search.solve(lv, bike, x, float(targets[k]), beam, 40.0, {}, 1.0, state)
		if not r.ok:
			return {"ok": false, "leg": k + 1, "legs": targets.size(), "best_x": r.best_x}
		frames += int(r.frames)
		state = r.end
		x = float(targets[k])
	# After a fault you start the section again from a standstill at its checkpoint
	# (drive_world.gd _respawn), so each one has to be rideable from rest too.
	for k in range(1, targets.size()):
		var x0 := float(targets[k - 1]) + 6.0
		var r: Dictionary = Search.solve(lv, bike, x0, float(targets[k]), beam, 40.0)
		if not r.ok:
			return {"ok": false, "leg": k + 1, "legs": targets.size(), "best_x": r.best_x, "why": "from rest"}
	return {"ok": true, "time": frames / 60.0, "legs": targets.size()}


## The reference bike rides on the climb's listed upgrades (up_req; the pars come from
## that); every other bike fully upgraded, so a bike is only marked as struggling on a
## climb when no amount of upgrading gets it up.
func _ride_summit(lv: Dictionary, i: int, bike: String, beam: int) -> Dictionary:
	var req: Array = Summit.meta(i).up_req
	var up := {}
	for k in Vehicles.UPGRADES.size():
		up[Vehicles.UPGRADES[k]] = int(req[k]) if bike == REF else Vehicles.MAX_LEVEL
	var tank := Vehicles.tank_seconds(bike, up)
	var targets := []
	for f in lv.fuel:
		targets.append((f as Vector2).x + 10.0)
	targets.append(float(lv.finish_x))
	var state = null
	var x := 0.0
	var frames := 0
	for k in targets.size():
		var r: Dictionary = Search.solve(lv, bike, x, float(targets[k]), beam, tank + 4.0, up, 1.0, state)
		if not r.ok:
			return {"ok": false, "leg": k + 1, "legs": targets.size(), "best_x": r.best_x}
		if r.frames / 60.0 > tank:
			return {"ok": false, "leg": k + 1, "legs": targets.size(), "best_x": float(targets[k]),
				"why": "out of fuel (%.1fs leg, %.0fs tank)" % [r.frames / 60.0, tank]}
		frames += int(r.frames)
		state = r.end
		x = float(targets[k])
	return {"ok": true, "time": frames / 60.0, "legs": targets.size()}


func _write(new_pars: Dictionary, new_ride: Dictionary) -> void:
	var fresh = ResourceLoader.load("res://scripts/drive/drive_table.gd", "", ResourceLoader.CACHE_MODE_IGNORE)
	var pars: Dictionary = (fresh.PARS as Dictionary).duplicate(true)
	var rideable: Dictionary = (fresh.RIDEABLE as Dictionary).duplicate(true)
	pars.merge(new_pars, true)
	# Bikes that got through add to a level's list (runs can split the bikes between
	# processes); clear RIDEABLE in drive_table.gd before a full re-check. The SCRAMBLER
	# is in every list of a level it has medal times for (that's the run they came from).
	for id in new_ride:
		var have: Array = rideable.get(id, [])
		for b in new_ride[id]:
			if not have.has(b):
				have.append(b)
		if pars.has(id) and not have.has(REF):
			have.push_front(REF)
		rideable[id] = have
	var lines := [
		"## Medal pars for SUMMIT and GAUNTLET levels ([gold, silver] seconds) and the bikes",
		"## the checker got through each level. Written by the level checker (README, Dev checks):",
		"##   godot --headless --path . -- --drive-levels --write             (pars, on the scrambler)",
		"##   godot --headless --path . -- --drive-levels --bikes=all --beam=12 --write  (the lists)",
		"extends RefCounted",
		"",
		"const PARS := {",
	]
	var ids := pars.keys()
	ids.sort()
	for id in ids:
		lines.append("\t\"%s\": [%.0f, %.0f]," % [id, float(pars[id][0]), float(pars[id][1])])
	lines.append("}")
	lines.append("")
	lines.append("const RIDEABLE := {")
	ids = rideable.keys()
	ids.sort()
	for id in ids:
		var bs: Array = rideable[id]
		lines.append("\t\"%s\": [%s]," % [id, ", ".join(bs.map(func(b): return "\"%s\"" % b))])
	lines.append("}")
	var path := ProjectSettings.globalize_path("res://scripts/drive/drive_table.gd")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	print("wrote ", path)
