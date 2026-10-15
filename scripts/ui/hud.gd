## In-run HUD: coins, gears, progress, pause. Taps anywhere else fall through as jumps.
extends Control

signal pause_pressed
signal hint_pressed

const Icons := preload("res://scripts/game/icons.gd")
const UITheme := preload("res://scripts/ui/ui_theme.gd")
const Kit := preload("res://scripts/ui/kit.gd")
const Phys := preload("res://scripts/game/bike_physics.gd")

var world: Node2D
var show_hint := false
## This trail's new feature; on a first visit the "?" button pulses for a while.
var feature := ""
var feature_new := false
var ability_title := ""
var _t := 0.0
var _hint_btn: Button


func _ready() -> void:
	Kit.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pb := Kit.button("II", 30, 26)
	pb.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pb.offset_left = -36
	pb.offset_top = 4
	pb.offset_right = -6
	pb.offset_bottom = 30
	pb.pressed.connect(func(): pause_pressed.emit())
	add_child(pb)
	var hb := Kit.button("?", 30, 26)
	hb.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	hb.offset_left = -70
	hb.offset_top = 4
	hb.offset_right = -40
	hb.offset_bottom = 30
	hb.pressed.connect(func(): hint_pressed.emit())
	add_child(hb)
	_hint_btn = hb


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if world == null:
		return
	var font: Font = GameState.font
	# Coins.
	draw_rect(Rect2(4, 4, 58, 18), Color(UITheme.INK, 0.75))
	Icons.coin(self, Vector2(13, 13), cos(_t * 4.0))
	_text(font, Vector2(22, 17), "%03d" % world.run_coins, UITheme.CREAM)
	# Gears: bright = this run, dim outline = found on an earlier run.
	var n: int = world.gears.size()
	draw_rect(Rect2(66, 4, n * 14 + 6, 18), Color(UITheme.INK, 0.75))
	for i in n:
		var p := Vector2(76 + i * 14, 13)
		if world.gears[i]:
			Icons.gear(self, p, 4.5, _t * 2.0, true)
		else:
			Icons.gear(self, p, 4.5, 0.0, false, 1.0 if world.known_gears[i] else 0.55)
	# Conditions: rain drop / live wind gauge.
	var wx: String = world.cond.weather
	if wx != "clear":
		var bx := 66.0 + n * 14 + 10.0
		draw_rect(Rect2(bx, 4, 30, 18), Color(UITheme.INK, 0.75))
		if wx == "rain":
			for i in 3:
				var dx := bx + 6 + i * 8
				var dy := 8.0 + fmod(_t * 14.0 + i * 3.0, 8.0)
				draw_rect(Rect2(dx, dy, 2, 3), Color("8fc7ff"))
		else:
			var gust: float = Phys.wind_at(world.level, world.state.t) / Phys.WIND_PEAK
			draw_line(Vector2(bx + 4, 10), Vector2(bx + 14, 10), UITheme.CREAM, -1.0)
			draw_colored_polygon(PackedVector2Array([Vector2(bx + 3, 10), Vector2(bx + 6, 7), Vector2(bx + 6, 13)]), UITheme.CREAM)
			for i in 4:
				var on := gust > (i + 0.5) / 4.0
				draw_rect(Rect2(bx + 17 + i * 3, 15 - i * 2, 2, 3 + i * 2), UITheme.GOLD if on else Color("4a4058"))
	# Progress strip.
	var lv: Dictionary = world.level
	var x0 := maxf(size.x * 0.36, 160.0)
	var x1 := size.x - 82.0
	var y := 12.0
	draw_rect(Rect2(x0, y, x1 - x0, 3), Color(UITheme.INK, 0.8))
	var span: float = lv.finish_x - lv.start_x
	var frac := clampf((world.state.x - lv.start_x) / span, 0.0, 1.0)
	draw_rect(Rect2(x0, y, (x1 - x0) * frac, 3), UITheme.GOLD)
	for c in lv.checkpoints:
		var cx: float = x0 + (x1 - x0) * clampf((c.x - lv.start_x) / span, 0.0, 1.0)
		draw_rect(Rect2(cx - 1, y - 2, 2, 7), UITheme.GREEN)
	draw_rect(Rect2(x1 - 1, y - 3, 3, 9), UITheme.CREAM)
	draw_rect(Rect2(x0 + (x1 - x0) * frac - 2, y - 2, 4, 7), UITheme.CREAM)

	if world.phase == "ready" and world.first_ready:
		var msg := "READY" if world.phase_ticks < 36 else "GO!"
		_center_text(font, size.y * 0.38, msg, 16, UITheme.GOLD)
	# First visit: the "?" pulses and a small tag names what's new on this trail.
	if feature_new and _t < 7.0:
		var pulse := 0.5 + 0.5 * sin(_t * 6.0)
		var r := _hint_btn.get_rect().grow(2.0 + 2.0 * pulse)
		draw_rect(r, Color(UITheme.GOLD, 0.35 + 0.5 * pulse), false, 1.0)
		var tag := "NEW: %s - TAP ? FOR TIPS" % feature
		var tw := font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var tx := size.x - tw - 8.0
		var fade := clampf((7.0 - _t) / 1.5, 0.0, 1.0)
		draw_rect(Rect2(tx - 4, 33, tw + 8, 13), Color(UITheme.INK, 0.8 * fade))
		_text(font, Vector2(tx, 43), tag, Color(UITheme.GOLD, fade))
	# Bike specialty indicator, bright while it's doing its thing.
	if ability_title != "":
		var on := _ability_active()
		_text(font, Vector2(6, size.y - 8.0), ability_title, UITheme.GOLD if on else Color(UITheme.DIM, 0.8))
	if show_hint and world.state.x < lv.start_x + 520.0:
		var a := 0.6 + 0.4 * sin(_t * 4.0)
		_center_text(font, size.y - 22.0, "TAP TO JUMP - HOLD TO JUMP HIGHER", 8, Color(UITheme.CREAM, a))


func _ability_active() -> bool:
	var st: Dictionary = world.state
	match String(st.ab):
		"wheelie":
			return bool(st.wheelie) or float(st.boost) > 2.0
		"hop", "dash":
			return not st.grounded and not bool(st.air_used) and int(st.zip) < 0 and int(st.loop) < 0
		"glide":
			return not st.grounded and float(st.vy) > 0.0 and world.held_now
		"tough":
			return int(st.armor) > 0
	return false


func _text(font: Font, p: Vector2, s: String, c: Color, sz := 8) -> void:
	draw_string(font, p + Vector2(1, 1), s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(0, 0, 0, 0.8))
	draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, c)


func _center_text(font: Font, y: float, s: String, sz: int, c: Color) -> void:
	draw_string(font, Vector2(1, y + 1), s, HORIZONTAL_ALIGNMENT_CENTER, size.x, sz, Color(0, 0, 0, c.a * 0.8))
	draw_string(font, Vector2(0, y), s, HORIZONTAL_ALIGNMENT_CENTER, size.x, sz, c)
