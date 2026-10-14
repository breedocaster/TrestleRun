## Builds the shared pixel UI theme in code (no .tres to keep in sync).
extends RefCounted

const INK := Color("1b1424")
const PANEL := Color("2b2135")
const PANEL_HI := Color("3d3050")
const CREAM := Color("f4ead5")
const DIM := Color("a89cb8")
const GOLD := Color("f2c14e")
const RED := Color("d9453b")
const GREEN := Color("5bd16a")


static func box(bg: Color, border: Color, bw := 2, pad := 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(0)
	s.anti_aliasing = false
	s.content_margin_left = pad + 2
	s.content_margin_right = pad + 2
	s.content_margin_top = pad
	s.content_margin_bottom = pad - 1
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 0
	s.shadow_offset = Vector2(2, 2)
	return s


static func build(font: Font) -> Theme:
	var t := Theme.new()
	t.default_font = font
	t.default_font_size = 8

	var normal := box(PANEL, GOLD)
	normal.shadow_size = 1
	var hover := box(PANEL_HI, GOLD)
	hover.shadow_size = 1
	var pressed := box(GOLD, GOLD)
	pressed.content_margin_top += 1
	var disabled := box(Color("221a2b"), Color("4a4058"))
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("hover_pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", CREAM)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", INK)
	t.set_color("font_hover_pressed_color", "Button", INK)
	t.set_color("font_disabled_color", "Button", Color("6a5f78"))
	t.set_color("font_focus_color", "Button", CREAM)

	var panel := box(Color(PANEL, 0.96), Color("5a4a6e"), 2, 8)
	panel.shadow_size = 2
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)

	t.set_color("font_color", "Label", CREAM)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.7))
	t.set_constant("shadow_offset_x", "Label", 1)
	t.set_constant("shadow_offset_y", "Label", 1)
	t.set_constant("line_spacing", "Label", 3)

	t.set_constant("separation", "VBoxContainer", 4)
	t.set_constant("separation", "HBoxContainer", 6)
	t.set_constant("h_separation", "GridContainer", 6)
	t.set_constant("v_separation", "GridContainer", 6)
	return t
