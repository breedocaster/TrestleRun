## The story so far, as a short comic: tap to turn the page, SKIP to jump to the map.
extends Control

signal navigate(target: String, arg: String)

const StoryArt := preload("res://scripts/game/story_art.gd")
const Kit := preload("res://scripts/ui/kit.gd")
const UITheme := preload("res://scripts/ui/ui_theme.gd")

var page := 0
var _t := 0.0
var _art: Control
var _caption: Label
var _hint: Label


func _ready() -> void:
	Kit.full_rect(self)
	theme = GameState.theme
	_art = Kit.full_rect(PanelArt.new())
	_art.host = self
	add_child(_art)
	var box := PanelContainer.new()
	box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	box.offset_top = -52
	box.offset_left = 12
	box.offset_right = -12
	box.offset_bottom = -8
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_stylebox_override("panel", UITheme.box(Color(UITheme.INK, 0.88), UITheme.GOLD, 2, 4))
	var v := VBoxContainer.new()
	_caption = Kit.label("", 8, UITheme.CREAM, HORIZONTAL_ALIGNMENT_LEFT)
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_caption)
	_hint = Kit.label("TAP TO CONTINUE", 8, UITheme.DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	v.add_child(_hint)
	box.add_child(v)
	add_child(box)
	var skip := Kit.button("SKIP >", 64, 22)
	skip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	skip.offset_left = -72
	skip.offset_top = 6
	skip.offset_right = -8
	skip.offset_bottom = 28
	skip.pressed.connect(_done)
	add_child(skip)
	_show(0)


func _show(i: int) -> void:
	page = i
	_t = 0.0
	_caption.text = String(StoryArt.CAPTIONS[i])
	_hint.text = "TAP TO START" if i == StoryArt.CAPTIONS.size() - 1 else "TAP TO CONTINUE  %d/%d" % [i + 1, StoryArt.CAPTIONS.size()]


func _process(delta: float) -> void:
	_t += delta
	_art.queue_redraw()


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		_next()


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("jump"):
		_next()


func _next() -> void:
	if _t < 0.25:
		return  # a double tap shouldn't skip a page
	AudioDirector.play("page")
	if page + 1 >= StoryArt.CAPTIONS.size():
		_done()
	else:
		_show(page + 1)


func _done() -> void:
	GameState.set_intro_seen()
	navigate.emit("story", "")


func on_back() -> void:
	_done()


class PanelArt extends Control:
	const Art := preload("res://scripts/game/story_art.gd")
	var host

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS

	func _draw() -> void:
		var vs := size
		Art.panel(self, int(host.page), vs, float(host._t) + 0.5)
		# Comic frame and a page-turn wipe.
		draw_rect(Rect2(Vector2(4, 4), vs - Vector2(8, 8)), Color("1a1424"), false, 3.0)
		var k := clampf(float(host._t) / 0.3, 0.0, 1.0)
		if k < 1.0:
			draw_rect(Rect2(vs.x * k, 0, vs.x * (1.0 - k), vs.y), Color("0e0a14"))
