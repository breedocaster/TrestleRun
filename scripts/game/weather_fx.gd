## Screen-space weather layer drawn over the world: rain streaks or wind-blown dust.
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
	if world == null or weather == "clear":
		return
	var vs := get_viewport_rect().size
	var cx: float = world.cam.position.x if world.cam else 0.0
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
