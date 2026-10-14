## Prints jump distance and landing slide per weather, on Dusty Trail's opening deck.
extends Node

const Phys := preload("res://scripts/game/bike_physics.gd")
const Library := preload("res://scripts/game/level_library.gd")


func _ready() -> void:
	for wx in ["clear", "rain", "wind"]:
		var dists := []
		var slide := 0.0
		for t0 in [0.0, 2.0, 4.0, 6.0, 8.0]:
			var lv := Library.build("dusty_trail")
			Phys.apply_weather(lv, wx)
			var s := Phys.new_state(lv, -300.0, 0, t0)
			var x0: float = s.x
			var i := 0
			Phys.step(lv, s, true, true)
			while not s.grounded and i < 200:
				Phys.step(lv, s, false, i < 30)
				i += 1
			dists.append(snappedf(s.x - x0, 0.1))
			# Ground distance gained over the next second vs. cruising.
			var xl: float = s.x
			for k in 60:
				Phys.step(lv, s, false, false)
			slide = s.x - xl - float(lv.speed)
		print("PHYS %s full-jump distance px (at 5 gust phases): %s | extra px slid in 1s after landing: %.1f" % [wx, dists, slide])
	get_tree().quit()
