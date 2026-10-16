## Screen-space weather layer drawn over the world: rain streaks or wind-blown dust,
## plus each trail's own ambient particles (dust, sparks, steam, drips, snow).
## Reads level time from the world so gust visuals match the physics.
extends Node2D

const Phys := preload("res://scripts/game/bike_physics.gd")

var world: Node2D
var weather := "clear"
var time_mode := "dusk"
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if world == null:
		return
	var vs := get_viewport_rect().size
	var cx: float = world.cam.position.x if world.cam else 0.0
	_ambient(vs, world.cam.position if world.cam else Vector2.ZERO)
	match weather:
		"rain":
			_rain(vs, cx)
		"wind":
			_wind(vs, cx)


func _rain(vs: Vector2, cx: float) -> void:
	var c := Color(0.75, 0.85, 1.0, 0.32 if time_mode != "night" else 0.22)
	var n := int(vs.x * vs.y / 1100.0)
	for i in n:
		var h1 := _hash(i * 1.37)
		var h2 := _hash(i * 7.11)
		var spd := 380.0 + h2 * 160.0
		var x := fposmod(h1 * vs.x * 1.4 - _t * 70.0 - cx * 0.6, vs.x + 20.0) - 10.0
		var y := fposmod(h2 * vs.y + _t * spd, vs.y + 20.0) - 10.0
		draw_line(Vector2(floorf(x), floorf(y)), Vector2(floorf(x) - 2, floorf(y) + 7), c, -1.0)


func _wind(vs: Vector2, cx: float) -> void:
	var gust: float = Phys.wind_at(world.level, world.state.t) / Phys.WIND_PEAK
	var a := 0.3 + gust * 0.4
	var streak := Color(1.0, 0.95, 0.85, a)
	for i in 34:
		var h1 := _hash(i * 2.71)
		var h2 := _hash(i * 5.13)
		var spd := 260.0 + h1 * 220.0 + gust * 200.0
		var x := vs.x - fposmod(h2 * vs.x * 1.3 + _t * spd + cx * 0.4, vs.x + 60.0)
		var y := floorf(h1 * vs.y * 0.9 + sin(_t * 2.0 + i) * 3.0)
		var length := 6.0 + h2 * 14.0 * (0.5 + gust)
		draw_line(Vector2(floorf(x), y), Vector2(floorf(x + length), y), streak, -1.0)
	var dust := Color(0.85, 0.72, 0.5, 0.55 + gust * 0.35)
	for i in 18:
		var h1 := _hash(i * 9.31)
		var x := vs.x - fposmod(h1 * vs.x * 2.0 + _t * (320.0 + gust * 260.0) + cx * 0.5, vs.x + 20.0)
		var y := floorf(vs.y * (0.35 + h1 * 0.6) + sin(_t * 7.0 + i * 1.7) * 4.0)
		draw_rect(Rect2(floorf(x), y, 1, 1), dust)


static func _hash(n: float) -> float:
	var s := sin(n * 12.9898) * 43758.5453
	return s - floorf(s)


# --- per-trail ambient particles ------------------------------------------------

func _ambient(vs: Vector2, cam: Vector2) -> void:
	var night := time_mode == "night"
	match int(world.level.get("theme", 0)):
		0:  # Dusty Trail: drifting dust motes
			_motes(vs, cam.x, 16, Color(0.98, 0.86, 0.6, 0.45), 9.0)
		1:  # Copper Canyon: copper glints twinkling in the air
			for i in 22:
				var h1 := _hash(i * 3.17)
				var h2 := _hash(i * 8.41)
				var x := fposmod(h1 * vs.x * 1.6 - cam.x * 1.15 - _t * 6.0, vs.x + 10.0) - 5.0
				var y := floorf(vs.y * (0.15 + h2 * 0.8) + sin(_t * 0.9 + i) * 6.0)
				var tw := sin(_t * (2.0 + h2 * 3.0) + i * 2.3)
				if tw > 0.2:
					draw_rect(Rect2(floorf(x), y, 1, 1), Color(1.0, 0.72, 0.42, 0.25 + 0.55 * tw))
		2:  # Rustyard: welding spark showers from the gantries overhead
			_sparks(vs, cam, 230.0, Color("ffd27a"), Color("ff6a2a"), 2.4)
		3:  # Night Trestle: low mist drifting through the trestle legs
			_mist(vs, cam.x, Color(0.75, 0.8, 0.95, 0.07 if night else 0.06))
		4:  # Mesa Springs: steam rising from the hot springs below
			_steam(vs, cam, 260.0, Color(1, 1, 1, 0.22))
		5:  # Lantern Mine: water drips and lantern-lit dust
			_drips(vs, cam)
			_motes(vs, cam.x, 12, Color(1.0, 0.8, 0.45, 0.4), 4.0)
		6:  # Hoodoo Loops: red sand blowing low across the hoodoos
			for i in 26:
				var h1 := _hash(i * 4.03)
				var h2 := _hash(i * 6.77)
				var x := vs.x - fposmod(h1 * vs.x * 1.5 + _t * (70.0 + h2 * 60.0) + cam.x * 0.3, vs.x + 30.0)
				var y := floorf(vs.y * (0.55 + h2 * 0.42) + sin(_t * 3.0 + i * 1.3) * 3.0)
				draw_line(Vector2(floorf(x), y), Vector2(floorf(x) + 2.0 + h1 * 3.0, y), Color(0.9, 0.5, 0.35, 0.4), -1.0)
		7:  # Hoist Yard: bluish arc-weld sparks and vent steam
			_sparks(vs, cam, 300.0, Color("e8f4ff"), Color("6ab8ff"), 3.2)
			_steam(vs, cam, 380.0, Color(0.9, 0.92, 1.0, 0.16))
		8:  # Skyline Pass: snow
			_snow(vs, cam.x)
		9:  # Quarry Cliffs: grit and pebbles trickling down, pale dust
			_motes(vs, cam.x, 12, Color(0.95, 0.88, 0.72, 0.45), 6.0)
			for i in 10:
				var h1 := _hash(i * 3.33 + 0.1)
				var h2 := _hash(i * 7.77 + 0.2)
				var x := fposmod(h1 * vs.x * 1.4 - cam.x * 1.05, vs.x + 10.0) - 5.0
				var y := fposmod(h2 * vs.y + _t * (60.0 + h2 * 50.0), vs.y + 10.0) - 5.0
				draw_rect(Rect2(floorf(x), floorf(y), 1 + int(h1 * 2.0), 1 + int(h1 * 2.0)), Color(0.78, 0.68, 0.52, 0.7))
		10:  # Rocket Ridge: exhaust haze drifting across low
			_mist(vs, cam.x, Color(1.0, 0.95, 0.9, 0.06))
			_motes(vs, cam.x, 10, Color(1.0, 0.7, 0.4, 0.4), 12.0)
		11:  # Last Trestle: splinters and ash on the wind
			for i in 24:
				var h1 := _hash(i * 2.71 + 0.5)
				var h2 := _hash(i * 4.13 + 0.3)
				var x := vs.x - fposmod(h1 * vs.x * 1.5 + _t * (40.0 + h2 * 50.0) + cam.x * 0.4, vs.x + 20.0)
				var y := fposmod(h2 * vs.y + _t * (14.0 + h1 * 20.0) + sin(_t * 2.0 + i) * 6.0, vs.y + 10.0) - 5.0
				var c := Color(0.55, 0.45, 0.35, 0.6) if i % 3 else Color(1.0, 0.55, 0.3, 0.6)
				draw_line(Vector2(floorf(x), floorf(y)), Vector2(floorf(x) + 2.0, floorf(y) + 1.0), c, -1.0)


func _motes(vs: Vector2, cx: float, n: int, c: Color, drift: float) -> void:
	for i in n:
		var h1 := _hash(i * 2.13 + 0.7)
		var h2 := _hash(i * 5.91 + 0.3)
		var x := fposmod(h1 * vs.x * 1.5 - cx * (1.1 + h2 * 0.3) - _t * drift, vs.x + 10.0) - 5.0
		var y := floorf(vs.y * (0.1 + h2 * 0.85) + sin(_t * (0.6 + h1) + i * 1.9) * 7.0)
		draw_rect(Rect2(floorf(x), y, 1, 1), Color(c, c.a * (0.6 + 0.4 * sin(_t * 1.7 + i))))


## Spark showers raining off the underside of the deck (welders at work below),
## from fixed points along the trail.
func _sparks(vs: Vector2, cam: Vector2, spacing: float, hot: Color, cool: Color, period: float) -> void:
	var left := cam.x - vs.x * 0.5
	var top := cam.y - vs.y * 0.5
	for cell in range(floori(left / spacing) - 1, floori((left + vs.x) / spacing) + 2):
		var hc := _hash(cell * 1.731 + 0.21)
		var age := fmod(_t + hc * period, period)
		if age > 1.4:
			continue
		var wx := cell * spacing + 40.0 + hc * spacing * 0.5
		var wy: float = world._ground_y_or(wx, NAN)
		if is_nan(wy):
			continue
		var src := Vector2(wx - left, wy - top + 3.0)
		if age < 0.5:  # the torch flaring
			draw_rect(Rect2(floorf(src.x) - 1, floorf(src.y) - 1, 3, 2), Color(hot, 0.9 - age))
		for j in 16:
			var hj := _hash(cell * 3.1 + j * 0.77)
			var hk := _hash(cell * 7.3 + j * 1.91)
			var a := age - hj * 0.5
			if a <= 0.0:
				continue
			var v := Vector2((hk - 0.5) * 70.0, -10.0 + hj * 30.0 + 260.0 * a)
			var p := src + Vector2(v.x * a, (-10.0 + hj * 30.0) * a + 0.5 * 260.0 * a * a)
			if p.y > vs.y:
				continue
			var k := clampf(a / 0.9, 0.0, 1.0)
			var c := Color(hot.lerp(cool, k), 1.0 - k * 0.6)
			draw_line(p.floor(), (p - v * 0.025).floor(), c, -1.0)


## Steam puffs rising from below the deck (world-anchored vents).
func _steam(vs: Vector2, cam: Vector2, spacing: float, c: Color) -> void:
	var left := cam.x - vs.x * 0.5
	for cell in range(floori(left / spacing) - 1, floori((left + vs.x) / spacing) + 2):
		var hc := _hash(cell * 2.917 + 0.5)
		if hc < 0.25:
			continue
		var sx := cell * spacing + hc * spacing * 0.7 - left
		for j in 6:
			var age := fmod(_t * 0.35 + j / 6.0 + hc, 1.0)
			var p := Vector2(sx + sin(age * 5.0 + j) * 4.0 + age * 18.0, vs.y + 6.0 - age * vs.y * 0.55)
			draw_circle(p.floor(), 2.0 + age * 7.0, Color(c, c.a * (1.0 - age) * minf(1.0, age * 6.0)))


## Flat pixel fog banks drifting below the deck.
func _mist(vs: Vector2, cx: float, c: Color) -> void:
	for i in 8:
		var h1 := _hash(i * 3.71 + 0.4)
		var h2 := _hash(i * 1.37 + 0.9)
		var w := 70.0 + h1 * 90.0
		var x := floorf(fposmod(h1 * vs.x * 2.0 - cx * 1.25 - _t * 5.0, vs.x + w + 40.0) - w - 20.0)
		var y := floorf(vs.y * (0.72 + h2 * 0.22) + sin(_t * 0.4 + i) * 2.0)
		draw_rect(Rect2(x, y, w, 4), c)
		draw_rect(Rect2(x + w * 0.15, y - 3, w * 0.6, 3), c)
		draw_rect(Rect2(x + w * 0.3, y - 5, w * 0.25, 2), c)
		draw_rect(Rect2(x - w * 0.1, y + 4, w * 0.8, 2), Color(c, c.a * 0.7))


func _drips(vs: Vector2, cam: Vector2) -> void:
	var left := cam.x - vs.x * 0.5
	var spacing := 70.0
	var c := Color(0.7, 0.85, 1.0, 0.75)
	for cell in range(floori(left / spacing), floori((left + vs.x) / spacing) + 1):
		var hc := _hash(cell * 4.33 + 0.1)
		if hc < 0.35:
			continue
		var sx := floorf(cell * spacing + hc * 50.0 - left)
		var age := fmod(_t / (1.4 + hc) + hc * 3.0, 1.0)
		if age < 0.35:  # swelling at the drip point
			draw_rect(Rect2(sx, 1, 1, 1 + int(age * 6.0)), Color(c, 0.5))
		else:
			var a := (age - 0.35) * 1.6
			var y := floorf(2.0 + 0.5 * 420.0 * a * a)
			if y < vs.y:
				draw_rect(Rect2(sx, y, 1, 2), c)


func _snow(vs: Vector2, cx: float) -> void:
	var c := Color(1, 1, 1, 0.85 if time_mode != "night" else 0.6)
	for i in 70:
		var h1 := _hash(i * 1.913 + 0.33)
		var h2 := _hash(i * 6.271 + 0.71)
		var near := h2 > 0.75
		var spd := 14.0 + h2 * 26.0
		var x := fposmod(h1 * vs.x * 1.3 - cx * (0.7 + h2 * 0.6) - _t * 8.0 + sin(_t * 0.8 + i) * 6.0, vs.x + 10.0) - 5.0
		var y := fposmod(h2 * vs.y * 3.1 + _t * spd, vs.y + 10.0) - 5.0
		draw_rect(Rect2(floorf(x), floorf(y), 2 if near else 1, 2 if near else 1), Color(c, c.a * (0.5 + h2 * 0.5)))
