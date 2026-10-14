## Trail select: one card per level, buy-to-unlock with a confirm tap. RIDE opens a
## conditions picker (time of day + weather) before the run.
extends Control

signal navigate(target: String, arg: String)

const Backdrop := preload("res://scripts/game/backdrop.gd")
const Catalog := preload("res://scripts/catalog.gd")
const Kit := preload("res://scripts/ui/kit.gd")
const UITheme := preload("res://scripts/ui/ui_theme.gd")
const Widgets := preload("res://scripts/ui/widgets.gd")

const TIME_OPTS := [["day", "DAY"], ["dusk", "DUSK"], ["night", "NIGHT"]]
const WEATHER_OPTS := [["clear", "CLEAR"], ["rain", "RAIN"], ["wind", "WIND"]]
const HINTS := {
	"clear": "", "rain": "WET DECK: WEAKER JUMPS, SLIDE ON LANDING",
	"wind": "HEADWIND GUSTS PUSH YOU BACK IN THE AIR",
}

var _row: HBoxContainer
var _confirm := ""
var _setup: Control
var _setup_id := ""


func _ready() -> void:
	Kit.full_rect(self)
	theme = GameState.theme
	var bg := CanvasLayer.new()
	bg.layer = -10
	add_child(bg)
	var bd := Backdrop.new()
	bd.theme_index = 1
	bd.cam = Vector2(400, 0)
	bg.add_child(bd)
	var shade := Kit.full_rect(ColorRect.new())
	shade.color = Color(0.04, 0.02, 0.07, 0.45)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.add_child(Kit.top_bar("TRAILS", func(): navigate.emit("title", "")))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 6)
	center.add_child(_row)
	scroll.add_child(center)
	col.add_child(scroll)
	add_child(Kit.full_rect(Kit.margin(col, 8)))
	_build_cards()
	GameState.money_changed.connect(func(_m): _build_cards())


func _build_cards() -> void:
	for c in _row.get_children():
		c.queue_free()
	var ls := Catalog.levels()
	for i in ls.size():
		_row.add_child(_card(i, ls[i]))


func _card(i: int, meta: Dictionary) -> Control:
	var id: String = meta.id
	var unlocked := GameState.level_unlocked(id)
	var rec := GameState.level_record(id)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.box(Color(UITheme.PANEL, 0.96), Color("5a4a6e"), 2, 5))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	v.add_child(Kit.label("TRAIL %d" % (i + 1), 8, UITheme.DIM))
	var title_l := Kit.label(meta.name, 8, UITheme.CREAM)
	title_l.autowrap_mode = TextServer.AUTOWRAP_WORD
	title_l.custom_minimum_size = Vector2(92, 20)
	v.add_child(title_l)
	v.add_child(Widgets.LevelThumb.new(int(meta.theme), not unlocked))
	v.add_child(Widgets.GearRow.new(rec.gears))
	var info := "BEST %d" % int(rec.best_coins) if rec.cleared else "UNCLEARED"
	if not unlocked:
		info = "COST %d" % int(meta.price)
	v.add_child(Kit.label(info, 8, UITheme.GOLD if not unlocked else UITheme.DIM))
	var b: Button
	if unlocked:
		b = Kit.button("RIDE", 0, 26)
		b.pressed.connect(func(): _show_setup(id))
	else:
		var price := int(meta.price)
		b = Kit.button("SURE?" if _confirm == id else "UNLOCK", 0, 26)
		b.disabled = GameState.money() < price
		b.pressed.connect(func(): _try_unlock(id))
	v.add_child(b)
	panel.add_child(v)
	return panel


func _try_unlock(id: String) -> void:
	if _confirm != id:
		_confirm = id
		_build_cards()
		return
	_confirm = ""
	if GameState.buy_level(id):
		AudioDirector.play("purchase")
	_build_cards()


func _show_setup(id: String) -> void:
	_setup_id = id
	if _setup:
		_setup.queue_free()
	var cond := GameState.conditions()
	var root := Kit.full_rect(Control.new())
	var dim := Kit.full_rect(ColorRect.new())
	dim.color = Color(0.04, 0.02, 0.07, 0.65)
	root.add_child(dim)
	var center := Kit.full_rect(CenterContainer.new())
	root.add_child(center)
	var panel := PanelContainer.new()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	var meta := Catalog.level(id)
	v.add_child(Kit.label(meta.name, 16, UITheme.GOLD))
	var thumb := Widgets.LevelThumb.new(int(meta.theme), false, String(cond.time), String(cond.weather))
	thumb.custom_minimum_size = Vector2(220, 44)
	v.add_child(thumb)
	v.add_child(_option_row("TIME", TIME_OPTS, "time", String(cond.time)))
	v.add_child(_option_row("WEATHER", WEATHER_OPTS, "weather", String(cond.weather)))
	var hint: String = HINTS.get(String(cond.weather), "")
	if cond.time == "night":
		hint = ("HEADLIGHT ONLY. " + hint) if hint != "" else "HEADLIGHT ONLY"
	var hint_l := Kit.label(hint if hint != "" else " ", 8, UITheme.DIM)
	hint_l.autowrap_mode = TextServer.AUTOWRAP_WORD
	hint_l.custom_minimum_size = Vector2(220, 20)
	v.add_child(hint_l)
	var pct := Catalog.condition_bonus(cond)
	v.add_child(Kit.label("COIN BONUS +%d%%" % pct if pct > 0 else "NO COIN BONUS",
		8, UITheme.GOLD if pct > 0 else UITheme.DIM))
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	var back := Kit.button("BACK", 80, 26)
	back.pressed.connect(_close_setup)
	var go := Kit.button("GO!", 80, 26)
	go.pressed.connect(func(): navigate.emit("game", id))
	btns.add_child(back)
	btns.add_child(go)
	v.add_child(btns)
	panel.add_child(v)
	center.add_child(panel)
	add_child(root)
	_setup = root


func _option_row(title: String, opts: Array, key: String, current: String) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	var l := Kit.label(title, 8, UITheme.DIM, HORIZONTAL_ALIGNMENT_LEFT)
	l.custom_minimum_size = Vector2(64, 0)
	h.add_child(l)
	var group := ButtonGroup.new()
	for o in opts:
		var b := Kit.button(o[1], 60, 24)
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = o[0] == current
		var value: String = o[0]
		b.pressed.connect(func(): _pick(key, value))
		h.add_child(b)
	return h


func _pick(key: String, value: String) -> void:
	GameState.set_condition(key, value)
	_show_setup.call_deferred(_setup_id)


func _close_setup() -> void:
	if _setup:
		_setup.queue_free()
		_setup = null


func on_back() -> void:
	if _setup:
		_close_setup()
		return
	navigate.emit("title", "")
