## --drive-hold: rides SUMMIT and GAUNTLET levels with the dumbest input there is, gas
## held the whole way, through the real drive_world.gd (fuel, pits, crashes, faults),
## and says how far it got. From climb 2 on, holding gas shouldn't get you to the top.
## Also reports any stretch where the bike was upside down (past 120 degrees) for more
## than half a second without a crash, which the rider's body should never allow.
##   --mode=summit|gauntlet  --only=0,3  --bikes=a,b  --up=req|max|none|e,s,t,f (SUMMIT upgrades)
##   --lean=k  scale the rider's ground lean (for tuning)
extends Node

const World := preload("res://scripts/drive/drive_world.gd")
const Summit := preload("res://scripts/drive/summit_levels.gd")
const Gauntlet := preload("res://scripts/drive/gauntlet_levels.gd")
const Vehicles := preload("res://scripts/drive/vehicles.gd")


class HoldGas:
	func control(_w) -> Vector2:
		return Vector2(1, 0)


func _ready() -> void:
	var modes := ["summit", "gauntlet"]
	var only := []
	var bikes := ["scrambler"]
	var up_mode := "req"
	var lean_k := 1.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mode="):
			modes = [a.substr(7)]
		elif a.begins_with("--only="):
			only = Array(a.substr(7).split(",")).map(func(s): return int(s))
		elif a.begins_with("--bikes="):
			bikes = Array(a.substr(8).split(","))
		elif a.begins_with("--up="):
			up_mode = a.substr(5)
		elif a.begins_with("--lean="):
			lean_k = float(a.substr(7))
		elif a.begins_with("--uni-lean="):
			Vehicles.tune_uni_lean = float(a.substr(11))
	for mode in modes:
		var n: int = Summit.count() if mode == "summit" else Gauntlet.count()
		for i in n:
			if not only.is_empty() and not only.has(i):
				continue
			for b in bikes:
				print(_ride(mode, i, b, up_mode, lean_k))
	print("DRIVE_HOLD done")
	get_tree().quit()


func _ride(mode: String, i: int, bike: String, up_mode: String, lean_k := 1.0) -> String:
	var lv: Dictionary = Summit.build(i) if mode == "summit" else Gauntlet.build(i)
	var up := {}
	if mode == "summit" and up_mode != "none":
		var req: Array = Summit.meta(i).up_req
		var fixed: Array = Array(up_mode.split(",")) if "," in up_mode else []
		for k in Vehicles.UPGRADES.size():
			if not fixed.is_empty():
				up[Vehicles.UPGRADES[k]] = int(fixed[k])
			else:
				up[Vehicles.UPGRADES[k]] = int(req[k]) if up_mode == "req" else Vehicles.MAX_LEVEL
	var w = World.new()
	w.bot = HoldGas.new()
	w.setup(mode, lv, {"bike": bike, "rider": "dusty", "paint": "stock"}, up)
	add_child(w)
	w.set_process(false)
	w.sim.lean_ground *= lean_k   # (tuning experiments: --lean=k)
	var flipped := 0
	var worst_flip := 0
	var first_fault_x := -1.0
	while w.phase != "done" and w.ticks < 60 * 180:
		w.tick()
		# Upside down on the ground with no crash called.
		var a := absf(wrapf(float(w.sim.ang), -PI, PI))
		if w.phase == "ride" and a > deg_to_rad(120.0):
			flipped += 1
			worst_flip = maxi(worst_flip, flipped)
		else:
			flipped = 0
		if mode == "gauntlet" and w.faults > 0 and first_fault_x < 0.0:
			first_fault_x = w.best_x
		# GAUNTLET: one fault is enough to know holding gas doesn't work there.
		if mode == "gauntlet" and w.faults >= 3:
			break
	var r: Dictionary = w.result
	var out := ""
	if mode == "summit":
		out = "%-14s %-10s %s at %d/%d m (%s), %.0fs" % [lv.id, bike, "TOP" if r.get("ok", false) else "stopped",
			int(w.best_x / 8.0), int(float(lv.finish_x) / 8.0), String(r.get("reason", "time")), w.ride_time]
	else:
		out = "%-14s %-10s %s, faults %d (first at x=%.0f of %.0f), %.0fs" % [lv.id, bike,
			"FINISHED" if r.get("ok", false) else "not finished", w.faults, first_fault_x, float(lv.finish_x), w.ride_time]
	if worst_flip > 30:
		out += "  !! upside down %.1fs with no crash" % (worst_flip / 60.0)
	if not r.get("ok", false):
		out += "  [end: x=%.0f ang=%.0f deg wheels down=%s speed=%.0f]" % [w.sim.pos.x, rad_to_deg(wrapf(float(w.sim.ang), -PI, PI)),
			str(w.sim.grounded), w.sim.speed()]
	w.queue_free()
	return out
