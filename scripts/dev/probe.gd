extends Node
const Library := preload("res://scripts/game/level_library.gd")
func _ready() -> void:
	var lv := Library.build("night_trestle")
	for m in lv.marks:
		if m[1] > 2700 and m[1] < 3700:
			print("PROBE ", m)
	for e in lv.enemies:
		if e.x0 > 3000 and e.x0 < 3500:
			print("PROBE enemy type=%d x0=%.0f x1=%.0f y0=%s" % [e.type, e.x0, e.get("x1", e.x0), e.get("y0", "")])
	for t in lv.tracks:
		if t.x1 > 3000 and t.x0 < 3500:
			print("PROBE track %.0f..%.0f y=%.0f side=%s" % [t.x0, t.x1, t.pts[0].y, t.side])
	get_tree().quit()
