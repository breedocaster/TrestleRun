## Saves for SUMMIT and GAUNTLET, in GameState.data.drive: each level's bests and
## medals, which levels are open (each opens when the one before is finished), and
## every bike's SUMMIT upgrades. Pays out a finished ride.
extends RefCounted

const Summit := preload("res://scripts/drive/summit_levels.gd")
const Gauntlet := preload("res://scripts/drive/gauntlet_levels.gd")
const Vehicles := preload("res://scripts/drive/vehicles.gd")
const Ghost := preload("res://scripts/drive/ghost.gd")
const Objectives := preload("res://scripts/drive/objectives.gd")

## Medal par times (gold, silver) per level id, written by the level checker
## (--drive-check); levels it hasn't timed fall back to a guess from their length.
const Table := preload("res://scripts/drive/drive_table.gd")


static func _d() -> Dictionary:
	if not GameState.data.has("drive"):
		GameState.data.drive = {}
	var d: Dictionary = GameState.data.drive
	for k in ["levels", "upgrades"]:
		if not d.has(k):
			d[k] = {}
	return d


static func levels(mode: String) -> Array:
	return Summit.LEVELS if mode == "summit" else Gauntlet.LEVELS


static func level_id(mode: String, i: int) -> String:
	return String(levels(mode)[i].id)


static func record(id: String) -> Dictionary:
	var lv: Dictionary = _d().levels
	if not lv.has(id):
		lv[id] = {"done": false, "best_time": 0.0, "best_m": 0, "medals": [false, false, false], "best_faults": -1}
	if not (lv[id] as Dictionary).has("obj"):
		lv[id].obj = [false, false, false]
	return lv[id]


static func unlocked(mode: String, i: int) -> bool:
	return i == 0 or bool(record(level_id(mode, i - 1)).done)


static func upgrades(bike: String) -> Dictionary:
	var u: Dictionary = _d().upgrades
	if not u.has(bike):
		u[bike] = {"engine": 0, "suspension": 0, "tires": 0, "tank": 0}
	var out := {}
	for k in Vehicles.UPGRADES:
		out[k] = int(u[bike].get(k, 0))
	return out


static func buy_upgrade(bike: String, kind: String) -> bool:
	var lvl := int(upgrades(bike)[kind])
	if lvl >= Vehicles.MAX_LEVEL:
		return false
	if not GameState.spend(Vehicles.upgrade_cost(lvl)):
		return false
	_d().upgrades[bike][kind] = lvl + 1
	GameState.save_game()
	return true


## [gold, silver] seconds.
static func pars(mode: String, i: int) -> Array:
	var id := level_id(mode, i)
	if Table.PARS.has(id):
		return Table.PARS[id]
	var m := float(levels(mode)[i].get("m", 1000))
	var g := ceilf(m * 8.0 / 150.0) if mode == "summit" else 60.0 + 10.0 * i
	return [g, ceilf(g * 1.3)]


## Bank a ride. Returns {"pay", "first", "new_best", "medals", "new_medals"}.
static func record_result(r: Dictionary, i: int) -> Dictionary:
	var mode: String = r.mode
	var rec := record(String(r.level_id))
	var ok := bool(r.ok)
	var t := float(r.time)
	var par := pars(mode, i)
	var first := ok and not bool(rec.done)
	var old: Array = (rec.medals as Array).duplicate()
	var new_best := false
	var new_best_m := false
	var pay := 0
	if mode == "summit":
		pay += int(r.coins)
		new_best_m = int(r.distance_m) > int(rec.best_m)
		rec.best_m = maxi(int(rec.best_m), int(r.distance_m))
	if ok:
		rec.done = true
		if float(rec.best_time) <= 0.0 or t < float(rec.best_time):
			rec.best_time = snappedf(t, 0.01)
			new_best = true
		var faults := int(r.get("faults", 0))
		if mode == "gauntlet" and (int(rec.best_faults) < 0 or faults < int(rec.best_faults)):
			rec.best_faults = faults
		var m: Array = rec.medals
		m[0] = true
		if t <= float(par[1]) and (mode == "summit" or faults <= 2):
			m[1] = true
		if t <= float(par[0]) and (mode == "summit" or faults == 0):
			m[1] = true
			m[2] = true
		if first:
			pay += 100 + 20 * i
		Achievements.unlock("summit_first" if mode == "summit" else "gauntlet_first")
		if mode == "gauntlet" and faults == 0:
			Achievements.unlock("gauntlet_clean")
		Achievements.recount("summit_done" if mode == "summit" else "gauntlet_done")
	var new_medals := [false, false, false]
	for k in 3:
		new_medals[k] = bool(rec.medals[k]) and not bool(old[k])
	# The level's three objectives (objectives.gd): each pays once.
	var obj_list := Objectives.of(String(r.level_id))
	var new_obj := [false, false, false]
	for k in mini(obj_list.size(), 3):
		if not bool(rec.obj[k]) and Objectives.met(obj_list[k], r):
			rec.obj[k] = true
			new_obj[k] = true
			pay += int(Objectives.PAY[k])
	if new_medals[1]:
		pay += 60 + 10 * i
	if new_medals[2]:
		pay += 120 + 20 * i
	if pay > 0:
		GameState.add_money(pay)
	GameState.save_game()
	return {"pay": pay, "first": first, "new_best": new_best, "new_best_m": new_best_m, "medals": rec.medals,
		"new_medals": new_medals, "obj": rec.obj, "new_obj": new_obj}


## The ghost to race on a level, by the GHOST setting: "best" (yours, or the gold line
## until you have one), "gold" (the level checker's own ride) or "off". {} = none.
static func ghost_for(id: String) -> Dictionary:
	var which := ghost_mode()
	if which == "off":
		return {}
	if which == "best":
		var g: Dictionary = GameState.load_ghost(Ghost.own_id(id))
		if not g.is_empty():
			return g
	var line := Ghost.load_line(id)
	if line.is_empty():
		return {}
	line.gold = true
	return line


static func ghost_mode() -> String:
	return String((GameState.data.get("settings", {}) as Dictionary).get("drive_ghost", "best"))


static func set_ghost_mode(v: String) -> void:
	GameState.data.settings["drive_ghost"] = v
	GameState.save_game()


## Keep this ride as the level's ghost if it's your best: the fastest finish, or before
## you've finished, the furthest you've got.
static func keep_ghost(r: Dictionary, paid: Dictionary, rig: Dictionary) -> void:
	var frames: PackedFloat32Array = r.get("ghost", PackedFloat32Array())
	if frames.is_empty():
		return
	var id := String(r.level_id)
	var have: Dictionary = GameState.load_ghost(Ghost.own_id(id))
	var keep := bool(paid.new_best) and bool(r.ok)
	if not keep and not bool(r.ok) and not bool(record(id).done):
		keep = bool(paid.get("new_best_m", false)) or have.is_empty()
	if keep:
		GameState.save_ghost(Ghost.own_id(id), rig, frames, float(r.time))


## Objectives done in a mode.
static func star_count(mode: String) -> int:
	var n := 0
	for i in levels(mode).size():
		for o in record(level_id(mode, i)).obj:
			if o:
				n += 1
	return n


## Every medal in a mode (for the select screen's header and achievements).
static func medal_count(mode: String) -> int:
	var n := 0
	for i in levels(mode).size():
		for m in record(level_id(mode, i)).medals:
			if m:
				n += 1
	return n


static func all_done(mode: String) -> bool:
	for i in levels(mode).size():
		if not bool(record(level_id(mode, i)).done):
			return false
	return true
