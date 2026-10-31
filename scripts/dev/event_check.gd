## --event-check: rides every event course (events.gd: each kind's variants and the
## holiday ones) on a stock scrambler with the input search, proving it can be done and
## setting its bronze / silver / gold from how the search did:
##   LONG JUMP     its jump x 0.5 / 0.75 / 0.92
##   COLLECT       what it picked up riding fuel can to fuel can x 0.4 / 0.7 / 0.9
##   TRICK ATTACK  the points from one trick on each jump it could fit one on (drive_air.gd)
##                 x 0.25 / 0.5 / 0.8 (at least 100 / 150 / 200 apart)
##   TIME ATTACK, LOW GRAVITY  its time x 1.6 / 1.3 / 1.1
##   LAST DROP     how far it got in the tank's 10 s x 0.5 / 0.8 / 1.0 (you coast on after)
##   --only=<course id,...>   --write (scripts/drive/event_table.gd)
extends Node

const Events := preload("res://scripts/drive/events.gd")
const Search := preload("res://scripts/drive/drive_search.gd")
const Vehicles := preload("res://scripts/drive/vehicles.gd")
const Air := preload("res://scripts/dev/drive_air.gd")
const Tricks := preload("res://scripts/drive/tricks.gd")

const REF := "scrambler"


func _ready() -> void:
	var only := []
	var write := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = Array(a.substr(7).split(","))
		elif a == "--write":
			write = true
	var tiers := {}
	var refs := {}
	var fails := 0
	for ev in Events.all_courses():
		if not only.is_empty() and not only.has(String(ev.id)):
			continue
		var t0 := Time.get_ticks_msec()
		var lv := Events.build(ev)
		var r := check(ev, lv)
		if not bool(r.ok):
			fails += 1
			print("%-16s FAIL %s" % [ev.id, String(r.why)])
			continue
		tiers[ev.id] = r.tiers
		refs[ev.id] = r.ref
		print("%-16s ok  ref %s  tiers %s  (%.0fs)" % [ev.id, str(r.ref), str(r.tiers), (Time.get_ticks_msec() - t0) / 1000.0])
	print("EVENT CHECK done, %d fail(s)" % fails)
	if write:
		_write(tiers, refs)
	get_tree().quit()


## Chain the search through targets (checkpoints, fuel cans, the finish), carrying the
## state across: {"ok", "path", "time", "best_x"}.
static func ride(lv: Dictionary, targets: Array, max_leg: float, tank := 0.0) -> Dictionary:
	var state = null
	var x := 0.0
	var path := PackedByteArray()
	var frames := 0
	for tx in targets:
		var r: Dictionary = Search.solve(lv, REF, x, float(tx), 24, max_leg, {}, 1.0, state)
		if not r.ok:
			return {"ok": false, "why": "stuck at x=%.0f on the way to %.0f" % [r.best_x, float(tx)], "best_x": r.best_x}
		if tank > 0.0 and r.frames / 60.0 > tank:
			return {"ok": false, "why": "leg to %.0f longer than a tank" % float(tx)}
		path.append_array(r.path)
		frames += int(r.frames)
		state = r.end
		x = float(tx)
	return {"ok": true, "path": path, "time": frames / 60.0}


static func check(ev: Dictionary, lv: Dictionary) -> Dictionary:
	match String(ev.kind):
		"long_jump":
			var lip := float(lv.event.lip_x)
			var r := ride(lv, [lip + 900.0], 40.0)
			if not r.ok:
				return r
			var land := _landing(lv, r.path, lip)
			if land < 0.0:
				return {"ok": false, "why": "no jump in the ride"}
			var d := (land - lip) / 8.0
			return {"ok": true, "ref": snappedf(d, 0.1), "tiers": [snappedf(d * 0.5, 0.5), snappedf(d * 0.75, 0.5), snappedf(d * 0.92, 0.5)]}
		"time_attack", "moon":
			var tg: Array = (lv.checkpoints as Array).duplicate()
			tg.append(float(lv.finish_x))
			var r := ride(lv, tg, 40.0)
			if not r.ok:
				return r
			var t := float(r.time)
			return {"ok": true, "ref": snappedf(t, 0.1), "tiers": [ceilf(t * 1.6), ceilf(t * 1.3), ceilf(t * 1.1)]}
		"trick_attack":
			var tg: Array = (lv.checkpoints as Array).duplicate()
			tg.append(float(lv.finish_x))
			var r := ride(lv, tg, 40.0)
			if not r.ok:
				return r
			var air: Dictionary = Air.check_path(lv, {}, r.path)
			var pts := 0
			for j in air.jumps:
				var best := 0
				for k in Tricks.TRICKS:
					if (j[2] as Array).has(Tricks.TRICKS[k].id):
						best = maxi(best, int(Tricks.TRICKS[k].pts))
				pts += best
			if pts < 300:
				return {"ok": false, "why": "only %d points of tricks fit (%d jumps)" % [pts, air.jumps.size()]}
			var g := maxi(300, int(pts * 0.8) / 50 * 50)
			var sv := mini(g - 100, maxi(200, int(pts * 0.5) / 50 * 50))
			var b := mini(sv - 100, maxi(100, int(pts * 0.25) / 50 * 50))
			return {"ok": true, "ref": pts, "tiers": [b, sv, g]}
		"collect":
			var tg := []
			for f in lv.fuel:
				tg.append((f as Vector2).x + 10.0)
			tg.append(float(lv.finish_x))
			var tank := Vehicles.tank_seconds(REF, {})
			var r := ride(lv, tg, tank + 4.0, tank)
			if not r.ok:
				return r
			var n := _picked(lv, r.path)
			if n < 5:
				return {"ok": false, "why": "only %d picked up" % n}
			return {"ok": true, "ref": n, "tiers": [ceili(n * 0.4), ceili(n * 0.7), ceili(n * 0.9)]}
		"fuel_saver":
			var sr: Dictionary = Search.solve(lv, REF, 0.0, float(lv.finish_x), 24, float(lv.event.tank), {})
			var d := float(sr.best_x) / 8.0
			if d < 50.0:
				return {"ok": false, "why": "only %.0f m" % d}
			return {"ok": true, "ref": int(d), "tiers": [int(d * 0.5), int(d * 0.8), int(d)]}
	return {"ok": false, "why": "unknown kind"}


## Replay a path: where the bike first touched down after leaving the ground past x.
static func _landing(lv: Dictionary, path: PackedByteArray, lip: float) -> float:
	var s = Search.start_sim(lv, REF, 0.0)
	var air := false
	for ai in path:
		var act: Vector2 = Search.ACTIONS[ai]
		for k in Search.BLOCK:
			s.gas = act.x
			s.brake = act.y
			s.step()
			if not air and s.pos.x > lip and not s.grounded:
				air = true
			elif air and s.grounded:
				return s.pos.x
	return -1.0


## Replay a path: how many of the level's items it picks up (as drive_world.gd does).
static func _picked(lv: Dictionary, path: PackedByteArray) -> int:
	var s = Search.start_sim(lv, REF, 0.0)
	var items: Array = lv.get("items", [])
	var got := {}
	for ai in path:
		var act: Vector2 = Search.ACTIONS[ai]
		for k in Search.BLOCK:
			s.gas = act.x
			s.brake = act.y
			s.step()
			for i in items.size():
				if not got.has(i) and (items[i] as Vector2).distance_squared_to(s.pos) < 196.0:
					got[i] = true
	return got.size()


func _write(tiers: Dictionary, refs: Dictionary) -> void:
	var fresh = ResourceLoader.load("res://scripts/drive/event_table.gd", "", ResourceLoader.CACHE_MODE_IGNORE)
	var all_t: Dictionary = (fresh.TIERS as Dictionary).duplicate(true)
	var all_r: Dictionary = (fresh.REF as Dictionary).duplicate(true)
	all_t.merge(tiers, true)
	all_r.merge(refs, true)
	var lines := [
		"## Event tiers ([bronze, silver, gold] in the event's own score) for each event course,",
		"## from the level checker riding it on a stock scrambler (REF: what it did). Written by",
		"##   godot --headless --path . -- --event-check --write",
		"extends RefCounted",
		"",
		"const TIERS := {",
	]
	var ids := all_t.keys()
	ids.sort()
	for id in ids:
		lines.append("\t\"%s\": %s," % [id, JSON.stringify(all_t[id])])
	lines.append("}")
	lines.append("")
	lines.append("const REF := {")
	for id in ids:
		lines.append("\t\"%s\": %s," % [id, JSON.stringify(all_r.get(id, 0))])
	lines.append("}")
	var path := ProjectSettings.globalize_path("res://scripts/drive/event_table.gd")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	print("wrote ", path)
