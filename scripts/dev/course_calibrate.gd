## --course-calibrate: how big can each GAUNTLET obstacle be? Builds a short track per
## obstacle size (run-up, obstacle, run-out) and has the input search try it on a few
## bikes. Prints ok / how far it got, so course.gd's moves can be sized to the physics.
##   --bike=a,b  --only=<move>
extends Node

const Course := preload("res://scripts/drive/course.gd")
const Search := preload("res://scripts/drive/drive_search.gd")

const CASES := {
	"step_up": [3.0, 4.0, 5.0, 6.0, 8.0],
	"step_down": [20.0, 40.0, 60.0, 90.0],
	"crate": [3.0, 4.0, 5.0, 6.0, 8.0],
	"log": [3.0, 4.0, 5.0, 6.0, 8.0],
	"kicker_gap": [20.0, 40.0, 60.0, 80.0, 100.0],
	"pit_up": [8.0, 16.0, 24.0],
	"stairs": [3.0, 4.0, 5.0, 6.0],
	"table": [3.0, 4.0, 5.0, 6.0],
	"steep": [30.0, 35.0, 40.0, 45.0],
	"crate_stairs": [3.0, 4.0, 5.0],
}


func _track(kind: String, v: float) -> Dictionary:
	var c = Course.new()
	c.flat(300.0 + 300.0)   # from -300: a 300 px run-up past x = 0
	match kind:
		"step_up":
			c.step(v)
		"step_down":
			c.step(-v)
		"crate":
			c.crate(16.0, v, 0.0)
		"log":
			c.log_at(v, 0.0)
		"kicker_gap":
			c.kicker(40.0, 12.0)
			c.pit(v)
		"pit_up":
			c.pit(40.0, v)
		"stairs":
			c.stairs(4, v, 14.0)
		"table":
			c.table(v, 40.0)
		"steep":
			c.slope(40.0 / tan(deg_to_rad(v)), 40.0)
		"crate_stairs":
			c.crate_stairs([v, v * 2.0, v * 3.0, v * 2.0, v], 16.0)
	var end_x: float = c.x
	c.flat(200.0)
	var lv: Dictionary = c.finish({"id": "cal", "theme": 0, "time": "day"})
	lv.target = end_x + 60.0
	return lv


func _ready() -> void:
	var bikes := ["scrambler", "dirt", "scooter", "mono"]
	var only := ""
	var lean_k := 1.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--bike="):
			bikes = Array(a.substr(7).split(","))
		elif a.begins_with("--only="):
			only = a.substr(7)
		elif a.begins_with("--lean="):
			lean_k = float(a.substr(7))
	for kind in CASES:
		if only != "" and kind != only:
			continue
		for b in bikes:
			var line := "%-12s %-10s" % [kind, b]
			for v in CASES[kind]:
				var lv := _track(kind, v)
				var t0 := Time.get_ticks_msec()
				var r: Dictionary = Search.solve(lv, b, 0.0, float(lv.target), 12, 9.0, {}, lean_k)
				line += "  %s:%s" % [str(v), ("ok %.1fs" % (r.frames / 60.0)) if r.ok else "NO@%.0f" % (float(r.best_x) - 300.0)]
			print(line)
	print("CALIBRATE done")
	get_tree().quit()
