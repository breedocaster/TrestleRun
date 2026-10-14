## Tiny custom-drawn controls: gear row, rider+bike preview, level thumbnail.
extends RefCounted

const Icons := preload("res://scripts/game/icons.gd")
const BikeView := preload("res://scripts/game/bike_view.gd")
const Backdrop := preload("res://scripts/game/backdrop.gd")


class GearRow extends Control:
	var flags: Array = [false, false, false]

	func _init(f: Array = []) -> void:
		if not f.is_empty():
			flags = f
		custom_minimum_size = Vector2(flags.size() * 14, 14)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var x0 := (size.x - flags.size() * 14) * 0.5 + 7
		for i in flags.size():
			Icons.gear(self, Vector2(x0 + i * 14, size.y * 0.5), 4.5, 0.2, bool(flags[i]))


class RigPreview extends Control:
	var rig: Dictionary
	var px_scale := 2.0
	var deck := Color("6b3f2a")
	var _t := 0.0

	func _init(r: Dictionary, sc := 2.0) -> void:
		rig = r
		px_scale = sc
		custom_minimum_size = Vector2(40, 32) * sc
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var base := Vector2(floorf(size.x * 0.5), floorf(size.y - 2 * px_scale))
		draw_rect(Rect2(base.x - 19 * px_scale, base.y, 38 * px_scale, 2 * px_scale), deck)
		draw_set_transform(base, 0.0, Vector2(px_scale, px_scale))
		BikeView.line_w = 1.0
		BikeView.draw_rig(self, Vector2.ZERO, rig, _t * 8.0, _t, 0.0, 0.55)
		BikeView.line_w = -1.0
		draw_set_transform(Vector2.ZERO)


class LevelThumb extends Control:
	var theme_index := 0
	var locked := false
	var time_mode := "dusk"
	var weather := "clear"

	func _init(ti: int, is_locked: bool, t_mode := "dusk", wx := "clear") -> void:
		theme_index = ti
		locked = is_locked
		time_mode = t_mode
		weather = wx
		custom_minimum_size = Vector2(88, 40)
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_delta: float) -> void:
		if weather != "clear":
			queue_redraw()

	func _draw() -> void:
		var th := Backdrop.theme(theme_index, time_mode, weather)
		var t := Time.get_ticks_msec() / 1000.0
		Backdrop.draw_scene(self, size, Vector2(theme_index * 900.0, 40.0), th, t)
		var y := floorf(size.y * 0.72)
		draw_rect(Rect2(0, y, size.x, 3), th.deck)
		draw_rect(Rect2(0, y, size.x, 1), th.deck_hi)
		var px := 4.0
		while px < size.x:
			draw_rect(Rect2(px, y + 3, 2, size.y), th.beam)
			px += 16.0
		if weather == "rain":
			for i in int(size.x / 6.0):
				var hx := fposmod(i * 37.0 - t * 30.0, size.x)
				var hy := fposmod(i * 23.0 + t * 180.0, size.y)
				draw_line(Vector2(hx, hy), Vector2(hx - 1, hy + 4), Color(0.75, 0.85, 1.0, 0.4), -1.0)
		elif weather == "wind":
			for i in 8:
				var hx := size.x - fposmod(i * 41.0 + t * 160.0, size.x + 20.0)
				var hy := floorf(fposmod(i * 13.0, size.y * 0.8))
				draw_line(Vector2(hx, hy), Vector2(hx + 8, hy), Color(1, 0.95, 0.85, 0.35), -1.0)
		if locked:
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.03, 0.08, 0.7))
			var c := size * 0.5
			draw_rect(Rect2(c.x - 6, c.y - 2, 12, 9), Color("c9d1d9"))
			draw_rect(Rect2(c.x - 4, c.y - 8, 2, 6), Color("c9d1d9"))
			draw_rect(Rect2(c.x + 2, c.y - 8, 2, 6), Color("c9d1d9"))
			draw_rect(Rect2(c.x - 4, c.y - 9, 8, 2), Color("c9d1d9"))
			draw_rect(Rect2(c.x - 1, c.y + 1, 2, 3), Color("2b2135"))
		draw_rect(Rect2(Vector2.ZERO, size), Color("5a4a6e"), false, 1.0)
