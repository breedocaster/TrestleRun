## ACHIEVEMENTS: every achievement with its badge, how to get it, and progress.
extends Control

signal navigate(target: String, arg: String)

const Backdrop := preload("res://scripts/game/backdrop.gd")
const Kit := preload("res://scripts/ui/kit.gd")
const UITheme := preload("res://scripts/ui/ui_theme.gd")
const Art := preload("res://scripts/ui/achievement_art.gd")
const AchList := preload("res://scripts/achievements.gd")


func _ready() -> void:
	Kit.full_rect(self)
	theme = GameState.theme
	var bg := CanvasLayer.new()
	bg.layer = -10
	add_child(bg)
	var bd := Backdrop.new()
	bd.theme_index = 15
	bd.time_mode = "night"
	bd.cam = Vector2(300, 0)
	bg.add_child(bd)
	var shade := Kit.full_rect(ColorRect.new())
	shade.color = Color(0.04, 0.02, 0.07, 0.55)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.add_child(Kit.top_bar("ACHIEVEMENTS", func(): navigate.emit("title", "")))
	var n := 0
	for a in AchList.LIST:
		if Achievements.is_unlocked(String(a[0])):
			n += 1
	var head := HBoxContainer.new()
	head.add_child(Kit.label("%d / %d UNLOCKED" % [n, AchList.LIST.size()], 8, UITheme.GOLD, HORIZONTAL_ALIGNMENT_LEFT))
	head.add_child(Kit.spacer())
	var store := Achievements.stores_connected()
	if store != "":
		var open := Kit.button(("OPEN " if Achievements.store_signed_in else "SIGN IN: ") + store, 0, 20)
		open.pressed.connect(func(): Achievements.show_store_ui())
		head.add_child(open)
	else:
		head.add_child(Kit.label("SAVED ON THIS PHONE", 8, UITheme.DIM, HORIZONTAL_ALIGNMENT_RIGHT))
	col.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 4)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Unlocked first, then the ones in progress, then the rest.
	var order := AchList.LIST.duplicate()
	order.sort_custom(func(a, b):
		var ua := Achievements.is_unlocked(String(a[0]))
		var ub := Achievements.is_unlocked(String(b[0]))
		if ua != ub:
			return ua
		return false)
	for a in order:
		grid.add_child(Row.new(String(a[0])))
	scroll.add_child(grid)
	col.add_child(scroll)
	add_child(Kit.full_rect(Kit.margin(col, 8)))
	Kit.pass_drags(grid)


func on_back() -> void:
	navigate.emit("title", "")


class Row extends Control:
	const ArtC := preload("res://scripts/ui/achievement_art.gd")
	const UIThemeC := preload("res://scripts/ui/ui_theme.gd")
	const L := preload("res://scripts/achievements.gd")
	var id := ""
	var _t := 0.0

	func _init(i: String) -> void:
		id = i
		custom_minimum_size = Vector2(226, 46)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_PASS

	func _process(delta: float) -> void:
		_t += delta
		if Achievements.is_unlocked(id):
			queue_redraw()

	func _draw() -> void:
		var a: Array = L.info(id)
		var on: bool = Achievements.is_unlocked(id)
		var font: Font = GameState.font
		draw_rect(Rect2(Vector2.ZERO, size), Color(UIThemeC.PANEL, 0.92))
		draw_rect(Rect2(Vector2.ZERO, size), UIThemeC.GOLD if on else Color("5a4a6e"), false, 1.0)
		ArtC.badge(self, Vector2(18, size.y * 0.5), 13.0, id, on, _t)
		draw_string(font, Vector2(36, 12), String(a[1]), HORIZONTAL_ALIGNMENT_LEFT, size.x - 40, 8, UIThemeC.CREAM if on else UIThemeC.DIM)
		var words := String(a[2]).split(" ")
		var lines := [""]
		for w in words:
			var trial: String = (lines[lines.size() - 1] + " " + w).strip_edges()
			if font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x > size.x - 42 and lines[lines.size() - 1] != "":
				lines.append(w)
			else:
				lines[lines.size() - 1] = trial
		var pr: Array = Achievements.progress(id)
		var bar: bool = int(pr[1]) > 0 and not on
		for i in mini(2 if bar else 3, lines.size()):
			draw_string(font, Vector2(36, 22 + i * 9), String(lines[i]), HORIZONTAL_ALIGNMENT_LEFT, size.x - 40, 8, UIThemeC.DIM)
		if bar:
			var bw := size.x - 92.0
			draw_rect(Rect2(36, size.y - 7, bw, 3), Color("2a2434"))
			draw_rect(Rect2(36, size.y - 7, bw * float(pr[0]) / float(pr[1]), 3), UIThemeC.GOLD)
			draw_string(font, Vector2(size.x - 52, size.y - 2), "%d/%d" % [pr[0], pr[1]], HORIZONTAL_ALIGNMENT_RIGHT, 48, 8, UIThemeC.DIM)
