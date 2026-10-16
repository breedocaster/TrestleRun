## Title: scrolling canyon, idling bike, RIDE / GARAGE.
extends Control

signal navigate(target: String, arg: String)

const Backdrop := preload("res://scripts/game/backdrop.gd")
const BikeView := preload("res://scripts/game/bike_view.gd")
const Kit := preload("res://scripts/ui/kit.gd")
const UITheme := preload("res://scripts/ui/ui_theme.gd")
const MoneyBadge := preload("res://scripts/ui/money_badge.gd")
const Widgets := preload("res://scripts/ui/widgets.gd")


class TitleRide extends Node2D:
	const BikeViewC := preload("res://scripts/game/bike_view.gd")
	const BackdropC := preload("res://scripts/game/backdrop.gd")
	var scroll := 0.0
	var _t := 0.0
	var _hop := 0.0
	var _hop_v := 0.0
	var bike: Node2D

	func _ready() -> void:
		bike = BikeViewC.new()
		bike.rig = GameState.loadout()
		add_child(bike)

	func _process(delta: float) -> void:
		_t += delta
		scroll += 110.0 * delta
		if _hop <= 0.0 and fmod(_t, 3.2) < delta:
			_hop_v = -150.0
		_hop_v += 700.0 * delta
		_hop = minf(0.0, _hop + _hop_v * delta)
		var vs := get_viewport_rect().size
		var deck_y := floorf(vs.y * 0.86)
		bike.position = Vector2(floorf(vs.x * 0.24), deck_y + floorf(_hop))
		bike.rotation = clampf(_hop_v * 0.0015, -0.3, 0.3) if _hop < 0.0 else 0.0
		bike.wheel_angle = scroll / 4.0
		bike.anim_t = _t
		bike.flutter = 0.5
		bike.queue_redraw()
		queue_redraw()

	func _draw() -> void:
		var th := BackdropC.theme(0)
		var vs := get_viewport_rect().size
		var y := floorf(vs.y * 0.86)
		var off := fposmod(scroll, 32.0)
		var px := -off
		while px < vs.x + 32:
			draw_rect(Rect2(px - 1, y + 4, 3, vs.y), th.beam)
			draw_line(Vector2(px, y + 8), Vector2(px + 32, y + 28), th.beam_dark, -1.0)
			draw_line(Vector2(px + 32, y + 8), Vector2(px, y + 28), th.beam_dark, -1.0)
			px += 32.0
		draw_rect(Rect2(0, y, vs.x, 5), th.deck)
		draw_rect(Rect2(0, y, vs.x, 1), th.deck_hi)
		draw_rect(Rect2(0, y + 5, vs.x, 1), th.beam_dark)


var _backdrop: Node2D
var _ride: Node2D
var _taps := 0
var _settings: Control
var _depth: Node


func _ready() -> void:
	Kit.full_rect(self)
	theme = GameState.theme
	var bg := CanvasLayer.new()
	bg.layer = -10
	add_child(bg)
	_backdrop = Backdrop.new()
	_backdrop.theme_index = 0
	bg.add_child(_backdrop)
	var rl := CanvasLayer.new()
	rl.layer = -5
	add_child(rl)
	_ride = TitleRide.new()
	rl.add_child(_ride)
	_depth = preload("res://scripts/game/depth.gd").new()
	_depth.with_front = false
	_depth.with_sound = false
	_depth.level_id = "title"
	add_child(_depth)
	_depth.attach(self, _backdrop)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 6)
	col.add_child(Kit.label("TRESTLE", 32, UITheme.GOLD))
	col.add_child(Kit.label("RUN", 32, UITheme.CREAM))
	col.add_child(Kit.label("ONE-BUTTON CANYON RIDER", 8, UITheme.DIM))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	col.add_child(gap)
	var story := Kit.button("STORY", 150, 26)
	story.pressed.connect(func(): navigate.emit("story" if GameState.story().intro_seen else "story_intro", ""))
	var ride := Kit.button("FREE RIDE", 150, 26)
	ride.pressed.connect(func(): navigate.emit("levels", ""))
	var garage := Kit.button("GARAGE", 150, 26)
	garage.pressed.connect(func(): navigate.emit("garage", ""))
	for b in [story, ride, garage]:
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(b)
	var center := Kit.full_rect(CenterContainer.new())
	center.offset_top = 16
	center.offset_bottom = -30
	center.add_child(col)
	add_child(center)

	var opts := HBoxContainer.new()
	opts.add_theme_constant_override("separation", 4)
	opts.position = Vector2(8, 6)
	var settings := Kit.button("SETTINGS", 0, 22)
	settings.pressed.connect(_open_settings)
	var credits := Kit.button("CREDITS", 0, 22)
	credits.pressed.connect(func(): navigate.emit("credits", ""))
	var awards := Kit.button("ACHIEVEMENTS", 0, 22)
	awards.pressed.connect(func(): navigate.emit("achievements", ""))
	for b in [settings, credits, awards]:
		opts.add_child(b)
	add_child(opts)

	var mb := MoneyBadge.new()
	mb.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	mb.offset_left = -96
	mb.offset_right = -8
	mb.offset_top = 6
	mb.offset_bottom = 30
	add_child(mb)
	if OS.is_debug_build() or OS.has_feature("testing"):
		# Dev shortcut: tap the wallet five times for +500 to test unlocks.
		var hit := Button.new()
		hit.flat = true
		hit.focus_mode = Control.FOCUS_NONE
		hit.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		hit.offset_left = -96
		hit.offset_right = -8
		hit.offset_top = 6
		hit.offset_bottom = 30
		hit.pressed.connect(_dev_tap)
		add_child(hit)


func _process(_delta: float) -> void:
	_backdrop.cam = Vector2(_ride.scroll, 0)
	_depth.cam = _backdrop.cam
	_depth.speed = 110.0


func _open_settings() -> void:
	if _settings:
		return
	var root := Kit.full_rect(Control.new())
	var dim := Kit.full_rect(ColorRect.new())
	dim.color = Color(0.04, 0.02, 0.07, 0.6)
	root.add_child(dim)
	var center := Kit.full_rect(CenterContainer.new())
	root.add_child(center)
	var panel := PanelContainer.new()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.add_child(Kit.label("SETTINGS", 16, UITheme.GOLD))
	v.add_child(Widgets.audio_sliders())
	var gb := Kit.button("GHOST RUN: %s" % ("ON" if GameState.flag("ghost") else "OFF"), 160, 22)
	gb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	gb.pressed.connect(func():
		GameState.set_flag("ghost", not GameState.flag("ghost"))
		gb.text = "GHOST RUN: %s" % ("ON" if GameState.flag("ghost") else "OFF"))
	v.add_child(gb)
	var done := Kit.button("DONE", 100, 26)
	done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	done.pressed.connect(_close_settings)
	v.add_child(done)
	panel.add_child(v)
	center.add_child(panel)
	add_child(root)
	_settings = root


func _close_settings() -> void:
	if _settings:
		_settings.queue_free()
		_settings = null


func _dev_tap() -> void:
	_taps += 1
	if _taps >= 5:
		_taps = 0
		GameState.add_money(500)


func on_back() -> void:
	if _settings:
		_close_settings()
		return
	get_tree().quit()
