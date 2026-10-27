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


## Bronze (clear), silver (all letters in one run), gold (par time, no crashes).
## Full: icons with what each is for (results). Compact: three icons (trail cards).
class MedalRow extends Control:
	const UITheme := preload("res://scripts/ui/ui_theme.gd")
	var have: Array = [false, false, false]
	var fresh: Array = [false, false, false]
	var par := 0.0
	var letters := 0
	var compact := false
	var boss := false
	var names: Array = []   # set to replace the three labels (SUMMIT / GAUNTLET)
	var _t := 0.0

	func _init(h: Array, f: Array = [false, false, false], p := 0.0, l := 0, small := false, is_boss := false) -> void:
		have = h
		fresh = f
		par = p
		letters = l
		compact = small
		boss = is_boss
		custom_minimum_size = Vector2(44, 14) if small else Vector2(280, 16)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		if not compact and fresh.has(true):
			_t += delta
			queue_redraw()

	func _draw() -> void:
		if compact:
			var x0 := (size.x - 40.0) * 0.5
			for i in 3:
				Icons.medal(self, Vector2(x0 + 6 + i * 14, 9), i, bool(have[i]))
			return
		var font: Font = GameState.font
		var labels := ["CLEAR", "NO CRASH" if boss else ("LETTERS" if have[1] else "LETTERS %d/7" % letters),
			"PAR %.1fs" % par if par > 0.0 else "PAR"]
		if names.size() == 3:
			labels = names
		var widths := []
		var total := 0.0
		for l in labels:
			var w := font.get_string_size(String(l), HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 14.0
			widths.append(w)
			total += w
		var gap := maxf(8.0, (size.x - total) / 2.0)
		var x := maxf(0.0, (size.x - total - gap * 2.0) * 0.5)
		for i in 3:
			var c := UITheme.CREAM if have[i] else UITheme.DIM
			if fresh[i]:
				c = UITheme.GOLD if int(_t * 4.0) % 2 == 0 else UITheme.CREAM
				draw_circle(Vector2(x + 6, 9), 7.0 + sin(_t * 6.0), Color(UITheme.GOLD, 0.25))
			Icons.medal(self, Vector2(x + 6, 9), i, bool(have[i]))
			draw_string(font, Vector2(x + 14, 13), String(labels[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, c)
			x += float(widths[i]) + gap


## Grandpa's bike with the parts you've got back (missing ones as dim silhouettes).
## flash: a part just recovered, drawn with a pulsing glow.
class GrandpaBikeView extends Control:
	const StoryArt := preload("res://scripts/game/story_art.gd")
	var parts: Array = []
	var px_scale := 1.0
	var flash := ""
	var _t := 0.0

	func _init(p: Array, sc := 1.0, fl := "") -> void:
		parts = p
		px_scale = sc
		flash = fl
		custom_minimum_size = Vector2(100, 62) * sc
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var o := Vector2(floorf(size.x * 0.5), floorf(size.y - 3.0 * px_scale))
		draw_rect(Rect2(o.x - 46 * px_scale, o.y, 92 * px_scale, 1), Color("5a4a6e"))
		if flash != "":
			draw_circle(o + Vector2(0, -26) * px_scale, 40.0 * px_scale, Color(1.0, 0.85, 0.3, 0.08 + 0.06 * sin(_t * 6.0)))
		StoryArt.grandpa_bike(self, o, px_scale, parts)


## A row of the eight parts: bright when recovered, dim when still out there.
class PartRow extends Control:
	var parts: Array = []

	func _init(p: Array) -> void:
		parts = p
		custom_minimum_size = Vector2(8 * 16, 16)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var all := ["headlight", "kickstart", "seat", "wheels", "carb", "top_end", "bottom_end", "frame"]
		var x0 := (size.x - all.size() * 16.0) * 0.5 + 8.0
		for i in all.size():
			Icons.part(self, Vector2(x0 + i * 16.0, size.y * 0.5).floor(), String(all[i]), 0.8, not (all[i] in parts))


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
		BikeView.xf = Transform2D(0.0, Vector2(px_scale, px_scale), 0.0, base)
		BikeView.draw_rig(self, Vector2.ZERO, rig, _t * 8.0, _t, 0.0, 0.55)
		BikeView.xf = Transform2D.IDENTITY
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


## Pixel volume slider: drag or tap anywhere on the track; snaps to 5%.
class VolumeSlider extends Control:
	signal changed(v: float)
	signal released

	const UITheme := preload("res://scripts/ui/ui_theme.gd")
	const LABEL_W := 64.0
	const PCT_W := 40.0

	var label := ""
	var value := 1.0
	var _drag := false

	func _init(lbl: String, v: float) -> void:
		label = lbl
		value = v
		custom_minimum_size = Vector2(240, 26)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _track() -> Rect2:
		return Rect2(LABEL_W, floorf(size.y * 0.5) - 3, size.x - LABEL_W - PCT_W - 6, 6)

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				_drag = true
				_set_from(e.position.x)
			elif _drag:
				_drag = false
				released.emit()
			accept_event()
		elif e is InputEventMouseMotion and _drag:
			_set_from(e.position.x)
			accept_event()

	func _set_from(x: float) -> void:
		var t := _track()
		var v := snappedf(clampf((x - t.position.x) / t.size.x, 0.0, 1.0), 0.05)
		if not is_equal_approx(v, value):
			value = v
			changed.emit(v)
			queue_redraw()

	func _draw() -> void:
		var font: Font = GameState.font
		var cy := floorf(size.y * 0.5)
		draw_string(font, Vector2(0, cy + 4), label, HORIZONTAL_ALIGNMENT_LEFT, LABEL_W, 8, UITheme.CREAM)
		var t := _track()
		draw_rect(t.grow(1), UITheme.INK)
		draw_rect(t, Color("3d3050"))
		var fill := floorf(t.size.x * value)
		draw_rect(Rect2(t.position, Vector2(fill, t.size.y)), UITheme.GOLD)
		draw_rect(Rect2(t.position.x, t.position.y, fill, 1), Color("fff1a8"))
		for i in range(1, 4):
			var tx := floorf(t.position.x + t.size.x * i / 4.0)
			draw_rect(Rect2(tx, t.end.y + 2, 1, 2), Color("5a4a6e"))
		var kx := floorf(t.position.x + fill)
		var knob := Rect2(kx - 4, cy - 8, 8, 16)
		draw_rect(knob.grow(1), UITheme.INK)
		draw_rect(knob, UITheme.CREAM if not _drag else Color.WHITE)
		draw_rect(Rect2(knob.position.x + 2, cy - 3, 4, 1), Color("a89cb8"))
		draw_rect(Rect2(knob.position.x + 2, cy + 2, 4, 1), Color("a89cb8"))
		var pct := "OFF" if value <= 0.001 else "%d%%" % int(round(value * 100))
		draw_string(font, Vector2(size.x - PCT_W, cy + 4), pct, HORIZONTAL_ALIGNMENT_RIGHT, PCT_W, 8,
			UITheme.DIM if value <= 0.001 else UITheme.CREAM)


## An ON/OFF setting as a button ("CRASH HINTS: ON"). on_change gets the new value.
## dflt: the setting's value before it's ever been changed (most are on; SWAP LEAN off).
static func flag_button(title: String, key: String, width := 160, on_change := Callable(), dflt := true) -> Button:
	const KitC := preload("res://scripts/ui/kit.gd")
	var b: Button = KitC.button("%s: %s" % [title, "ON" if GameState.flag(key, dflt) else "OFF"], width, 22)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func():
		var v := not GameState.flag(key, dflt)
		GameState.set_flag(key, v)
		b.text = "%s: %s" % [title, "ON" if v else "OFF"]
		if on_change.is_valid():
			on_change.call(v))
	return b


## MUSIC + SOUND + ENGINE sliders, saved on release. SOUND chimes so you can hear
## it; ENGINE revs your bike (menus only: in a paused run the engine is paused too).
static func audio_sliders(rev_engine := true) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	for key in ["music", "sound", "engine"]:
		var s := VolumeSlider.new(key.to_upper(), GameState.volume(key))
		s.changed.connect(func(v): GameState.set_volume(key, v, false))
		s.released.connect(func():
			GameState.save_settings()
			if key == "sound":
				AudioDirector.play("checkpoint")
			elif key == "engine" and rev_engine:
				AudioDirector.preview_engine(GameState.equipped("bike")))
		box.add_child(s)
	return box
