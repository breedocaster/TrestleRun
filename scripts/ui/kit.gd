## Small constructors for code-built UI.
extends RefCounted

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const MoneyBadge := preload("res://scripts/ui/money_badge.gd")


static func label(text: String, size := 8, color := UITheme.CREAM, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func button(text: String, min_w := 0, min_h := 28, sound := "tap") -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, min_h)
	b.focus_mode = Control.FOCUS_NONE
	if sound != "":
		b.pressed.connect(func(): AudioDirector.play(sound))
	return b


static func spacer(h := true) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if h:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


## Content inside a ScrollContainer: let finger drags through to the scroller.
## Panels and buttons default to STOP, which swallows the touch, so a drag that starts
## on a card never scrolls. PASS lets them react and still hands the drag up; once the
## drag passes the deadzone the ScrollContainer sends NOTIFICATION_SCROLL_BEGIN, which
## cancels the button's press, so dragging across a button doesn't click it.
static func pass_drags(root: Control) -> void:
	if root.mouse_filter == Control.MOUSE_FILTER_STOP and not root is ScrollBar:
		root.mouse_filter = Control.MOUSE_FILTER_PASS
	for c in root.get_children():
		if c is Control:
			pass_drags(c)


static func full_rect(c: Control) -> Control:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.offset_left = 0
	c.offset_top = 0
	c.offset_right = 0
	c.offset_bottom = 0
	return c


## [BACK]  TITLE  [$ money]
static func top_bar(title: String, on_back: Callable) -> HBoxContainer:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	var back := button("< BACK", 72, 24)
	back.pressed.connect(on_back)
	bar.add_child(back)
	bar.add_child(spacer())
	bar.add_child(label(title, 16, UITheme.GOLD))
	bar.add_child(spacer())
	var mb := MoneyBadge.new()
	mb.custom_minimum_size.x = 72
	bar.add_child(mb)
	return bar


## Margin wrapper honouring a uniform pixel gutter.
static func margin(child: Control, m := 8) -> MarginContainer:
	var mc := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		mc.add_theme_constant_override("margin_" + side, m)
	mc.add_child(child)
	return mc
