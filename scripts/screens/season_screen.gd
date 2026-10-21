## SEASON PASS: thirty tiers for this season, each with a free reward and a gold one.
## XP from every run, mission, daily ride, streak day and league week fills the bar;
## tap a lit reward to take it. The gold track opens with GET GOLD PASS.
extends Control

signal navigate(target: String, arg: String)

const Backdrop := preload("res://scripts/game/backdrop.gd")
const Catalog := preload("res://scripts/catalog.gd")
const Kit := preload("res://scripts/ui/kit.gd")
const UITheme := preload("res://scripts/ui/ui_theme.gd")
const Widgets := preload("res://scripts/ui/widgets.gd")
const Icons := preload("res://scripts/game/icons.gd")

const COL_W := 46

var _row: HBoxContainer
var _scroll: ScrollContainer
var _head: VBoxContainer
var _confirm := false


func _ready() -> void:
	Kit.full_rect(self)
	theme = GameState.theme
	var bg := CanvasLayer.new()
	bg.layer = -10
	add_child(bg)
	var bd := Backdrop.new()
	bd.theme_index = Challenges.season_theme()
	bd.time_mode = "dusk"
	bd.cam = Vector2(1500, 0)
	bg.add_child(bd)
	var shade := Kit.full_rect(ColorRect.new())
	shade.color = Color(0.04, 0.02, 0.07, 0.55)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.add_child(Kit.top_bar("SEASON PASS", func(): navigate.emit("challenges", "")))
	_head = VBoxContainer.new()
	_head.add_theme_constant_override("separation", 3)
	col.add_child(_head)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 3)
	_scroll.add_child(_row)
	col.add_child(_scroll)
	add_child(Kit.full_rect(Kit.margin(col, 8)))
	_build()
	(func():
		await get_tree().process_frame
		await get_tree().process_frame
		var t := clampi(Challenges.season_tier() - 2, 0, Challenges.SEASON_TIERS - 1)
		_scroll.scroll_horizontal = t * (COL_W + 3)).call()


func _build() -> void:
	for c in _head.get_children():
		c.queue_free()
	for c in _row.get_children():
		c.queue_free()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.add_child(Kit.label(Challenges.season_name(), 8, UITheme.GOLD))
	h.add_child(Kit.spacer())
	var tier := Challenges.season_tier()
	var xp := Challenges.season_xp()
	var next := "MAX!" if tier >= Challenges.SEASON_TIERS else "%d/%d XP" % [xp % Challenges.TIER_XP, Challenges.TIER_XP]
	h.add_child(Kit.label("TIER %d  %s" % [tier, next], 8, UITheme.CREAM))
	_head.add_child(h)
	var g := HBoxContainer.new()
	g.add_theme_constant_override("separation", 8)
	g.add_child(Kit.label("%d DAYS LEFT" % Challenges.season_days_left(), 8, UITheme.DIM))
	if Challenges.has_gold():
		g.add_child(Kit.label("GOLD PASS ON: GOLD REWARDS AS YOU REACH THEM", 8, UITheme.GOLD))
	else:
		g.add_child(Kit.label("GOLD: 3 PAINTS, MORE COINS", 8, UITheme.DIM))
		g.add_child(Kit.spacer())
		var b := Kit.button("SURE? %d" % Challenges.GOLD_PRICE if _confirm else "GOLD PASS %d" % Challenges.GOLD_PRICE, 0, 20)
		b.disabled = GameState.money() < Challenges.GOLD_PRICE
		b.pressed.connect(_buy)
		g.add_child(b)
	_head.add_child(g)
	for t in range(1, Challenges.SEASON_TIERS + 1):
		_row.add_child(_column(t))
	Kit.pass_drags(_row)


func _buy() -> void:
	if not _confirm:
		_confirm = true
		_build()
		return
	_confirm = false
	if Challenges.buy_gold():
		AudioDirector.play("purchase")
	_build()


func _column(t: int) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	var reached := t <= Challenges.season_tier()
	v.add_child(Kit.label("%d" % t, 8, UITheme.GOLD if reached else UITheme.DIM))
	v.add_child(_cell(t, false))
	v.add_child(_cell(t, true))
	return v


func _cell(t: int, gold: bool) -> Control:
	var rw := Challenges.reward(t, gold)
	var b := RewardCell.new()
	b.reward = rw
	b.gold = gold
	b.claimed = Challenges.claimed(t, gold)
	b.can_take = Challenges.can_claim(t, gold)
	b.locked = gold and not Challenges.has_gold()
	b.reached = t <= Challenges.season_tier()
	b.custom_minimum_size = Vector2(COL_W, 56)
	b.focus_mode = Control.FOCUS_NONE
	b.flat = true
	b.pressed.connect(func():
		var got := Challenges.claim(t, gold)
		if not got.is_empty():
			AudioDirector.play("purchase" if got.has("paint") else "bag")
			_build())
	return b


func on_back() -> void:
	navigate.emit("challenges", "")


class RewardCell extends Button:
	const UIThemeC := preload("res://scripts/ui/ui_theme.gd")
	const IconsC := preload("res://scripts/game/icons.gd")
	const CatalogC := preload("res://scripts/catalog.gd")
	const WidgetsC := preload("res://scripts/ui/widgets.gd")
	var reward := {}
	var gold := false
	var claimed := false
	var can_take := false
	var locked := false
	var reached := false
	var _t := 0.0

	func _process(delta: float) -> void:
		if can_take:
			_t += delta
			queue_redraw()

	func _draw() -> void:
		var font: Font = GameState.font
		var edge := UIThemeC.GOLD if gold else Color("9fe8ff")
		var bgc := Color(UIThemeC.PANEL, 0.96)
		if can_take:
			bgc = bgc.lerp(edge, 0.18 + 0.1 * sin(_t * 5.0))
		draw_rect(Rect2(Vector2.ZERO, size), bgc)
		draw_rect(Rect2(Vector2.ZERO, size), edge if reached else Color("5a4a6e"), false, 1.0)
		var mid := size * 0.5
		if reward.has("paint"):
			var p := CatalogC.paint(String(reward.paint))
			draw_rect(Rect2(mid.x - 12, mid.y - 14, 24, 12), p.body)
			draw_rect(Rect2(mid.x - 12, mid.y - 4, 24, 3), p.body_dark)
			draw_rect(Rect2(mid.x - 4, mid.y - 12, 8, 2), p.accent)
			if p.flames:
				draw_rect(Rect2(mid.x - 10, mid.y - 8, 6, 2), Color("ff8a1f"))
			draw_string(font, Vector2(0, mid.y + 12), "PAINT", HORIZONTAL_ALIGNMENT_CENTER, size.x, 8, UIThemeC.CREAM)
		else:
			IconsC.coin(self, (mid + Vector2(0, -8)).floor(), 1.0)
			draw_string(font, Vector2(0, mid.y + 12), str(int(reward.get("coins", 0))), HORIZONTAL_ALIGNMENT_CENTER, size.x, 8, UIThemeC.CREAM)
		if claimed:
			draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.55))
			draw_string(font, Vector2(0, mid.y + 3), "GOT", HORIZONTAL_ALIGNMENT_CENTER, size.x, 8, UIThemeC.GREEN)
		elif locked:
			draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.35))
			draw_string(font, Vector2(0, 10), "GOLD", HORIZONTAL_ALIGNMENT_CENTER, size.x, 8, UIThemeC.GOLD)
		elif can_take:
			draw_string(font, Vector2(0, 10), "TAKE", HORIZONTAL_ALIGNMENT_CENTER, size.x, 8, edge)
