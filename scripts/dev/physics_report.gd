## Prints jump distance/height per hold length and speed, landing slide per weather,
## and what each bike specialty adds. Used to size gaps and tune the difficulty ramp.
extends Node

const Phys := preload("res://scripts/game/bike_physics.gd")
const Library := preload("res://scripts/game/level_library.gd")

const HOLDS := [1, 3, 5, 7, 9, 12, 15, 20, 30]


func _flat(speed: float) -> Dictionary:
	return Library.build_layout([["start", 3000.0]], {"speed": speed})


## Jump on flat ground: [distance, peak height]. holdf = frames held; extra = per-frame
## input after takeoff ([pressed, held] callable) for specialties.
func _jump(lv: Dictionary, holdf: int, ab: Dictionary = {}, air_press := -1, t0 := 0.0) -> Vector2:
	var s := Phys.new_state(lv, 0.0, 0, t0, ab)
	var x0: float = s.x
	var y0: float = s.y
	var peak := 0.0
	Phys.step(lv, s, true, holdf > 0)
	var i := 1
	while not s.grounded and i < 400:
		Phys.step(lv, s, i == air_press, i < holdf)
		peak = maxf(peak, y0 - float(s.y))
		i += 1
	return Vector2(s.x - x0, peak)


func _ready() -> void:
	print("PHYS jump table: hold frames -> distance px / peak px")
	for sp in [118.0, 126.0, 134.0, 142.0, 150.0]:
		var lv := _flat(sp)
		var row := []
		for h in HOLDS:
			var r := _jump(lv, h)
			row.append("%d:%d/%d" % [h, int(r.x), int(r.y)])
		print("PHYS speed %d  %s" % [int(sp), " ".join(row)])
	for wx in ["clear", "rain", "wind"]:
		var dists := []
		var slide := 0.0
		for t0 in [0.0, 2.0, 4.0, 6.0, 8.0]:
			var lv := _flat(134.0)
			Phys.apply_weather(lv, wx)
			dists.append(int(_jump(lv, 30, {}, -1, t0).x))
			var s := Phys.new_state(lv, 0.0, 0, t0)
			Phys.step(lv, s, true, true)
			var i := 0
			while not s.grounded and i < 200:
				Phys.step(lv, s, false, i < 30)
				i += 1
			var xl: float = s.x
			for k in 60:
				Phys.step(lv, s, false, false)
			slide = s.x - xl - float(lv.speed)
		print("PHYS %s full-jump px at 134 (5 gust phases): %s | slide px: %.1f" % [wx, dists, slide])
	var lv2 := _flat(134.0)
	print("PHYS specialties at 134 px/s (full hold unless noted):")
	print("PHYS   base full %s  tap %s" % [_jump(lv2, 30), _jump(lv2, 3)])
	print("PHYS   hop (2nd press at apex f20) %s" % _jump(lv2, 40, {"id": "hop"}, 20))
	print("PHYS   glide (hold 60f) %s" % _jump(lv2, 120, {"id": "glide"}))
	print("PHYS   dash (press at f18) %s" % _jump(lv2, 30, {"id": "dash"}, 18))
	# Wheelie: land holding, keep holding 2 s, measure speed.
	for k in [0.10, 0.14, 0.18]:
		var s := Phys.new_state(lv2, 0.0, 0, 0.0, {"id": "wheelie", "k": k})
		Phys.step(lv2, s, true, true)
		var i := 0
		while not s.grounded and i < 200:
			Phys.step(lv2, s, false, true)
			i += 1
		var v := []
		for f in 180:
			Phys.step(lv2, s, false, f < 120)
			if f in [30, 60, 119, 150, 179]:
				v.append(int(s.vx))
		print("PHYS   wheelie k=%.2f speed at 0.5/1/2 s held, then 0.5/1 s after: %s" % [k, v])
	# Spring arc and tunnel bonk.
	var sp_lv := Library.build_layout([["start", 200.0], ["spring_up", 0, ""], ["flat", 600.0]], {"speed": 134.0})
	var s2 := Phys.new_state(sp_lv, 0.0, 0)
	var peak := 0.0
	var y0: float = s2.y
	var x_launch := 0.0
	var air := 0
	for f in 400:
		var ev := Phys.step(sp_lv, s2, false, false)
		if ev & Phys.EV_SPRING:
			x_launch = s2.x
		if x_launch > 0.0:
			peak = maxf(peak, y0 - float(s2.y))
			if not s2.grounded:
				air += 1
			elif air > 0:
				break
	print("PHYS   spring: peak %d px, landed %d px past the pad (on the upper deck), air %.2f s" % [int(peak), int(s2.x - x_launch), air / 60.0])
	for h in [56.0, 60.0, 64.0]:
		var tl := Library.build_layout([["start", 200.0], ["tunnel", ["flat", "flat", "flat"], h], ["flat", 300.0]], {"speed": 134.0})
		var ok := []
		for hold in [1, 3, 5, 7, 8, 9, 10, 12, 30]:
			var s3 := Phys.new_state(tl, 420.0, 0)
			var bonk := false
			Phys.step(tl, s3, true, hold > 0)
			var x0: float = s3.x
			var i := 1
			while not s3.grounded and i < 200:
				var ev := Phys.step(tl, s3, false, i < hold)
				bonk = bonk or (ev & Phys.EV_BONK) != 0
				i += 1
			ok.append("%d:%d%s" % [hold, int(s3.x - x0), "B" if bonk else ""])
		print("PHYS   tunnel h=%d  hold:dist (B = bonked) %s" % [int(h), " ".join(ok)])
	get_tree().quit()
