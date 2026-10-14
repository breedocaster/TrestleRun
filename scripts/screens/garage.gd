## Garage: pick and buy riders, bike models and paint. Big preview of the current
## rig on the left; tiles on the right preview each option on your current setup.
extends Control

signal navigate(target: String, arg: String)

const Backdrop := preload("res://scripts/game/backdrop.gd")
const Catalog := preload("res://scripts/catalog.gd")
const Kit := preload("res://scripts/ui/kit.gd")
const UITheme := preload("res://scripts/ui/ui_theme.gd")
const Widgets := preload("res://scripts/ui/widgets.gd")

const TAB_LABELS := {"rider": "RIDERS", "bike": "BIKES", "paint": "PAINT"}

var tab := "rider"
var _grid: GridContainer
var _scroll: ScrollContainer
var _preview_box: VBoxContainer
var _tabs: Dictionary = {}
var _confirm := ""


func _ready() -> void:
	Kit.full_rect(self)
	theme = GameState.theme
	var bg := CanvasLayer.new()
	bg.layer = -10
	add_child(bg)
	var bd := Backdrop.new()
	bd.theme_index = 2
	bd.cam = Vector2(1200, 0)
	bg.add_child(bd)
	var shade := Kit.full_rect(ColorRect.new())
	shade.color = Color(0.04, 0.02, 0.07, 0.5)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.add_child(Kit.top_bar("GARAGE", func(): navigate.emit("title", "")))

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	col.add_child(body)

	var left := PanelContainer.new()
	left.custom_minimum_size = Vector2(140, 0)
	left.add_theme_stylebox_override("panel", UITheme.box(Color(UITheme.PANEL, 0.96), UITheme.GOLD, 2, 4))
	_preview_box = VBoxContainer.new()
	_preview_box.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_child(_preview_box)
	body.add_child(left)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	var group := ButtonGroup.new()
	for kind in Catalog.KINDS:
		var b := Kit.button(TAB_LABELS[kind], 0, 22)
		b.toggle_mode = true
		b.button_group = group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.button_pressed = kind == tab
		b.pressed.connect(func(): _set_tab(kind))
		tabs.add_child(b)
		_tabs[kind] = b
	right.add_child(tabs)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_grid)
	right.add_child(_scroll)
	body.add_child(right)

	add_child(Kit.full_rect(Kit.margin(col, 8)))
	_build()


func _set_tab(kind: String) -> void:
	tab = kind
	_confirm = ""
	_scroll.scroll_vertical = 0
	_build()


func _build() -> void:
	for c in _preview_box.get_children():
		c.queue_free()
	_preview_box.add_child(Widgets.RigPreview.new(GameState.loadout(), 3.0))
	for kind in Catalog.KINDS:
		var it := Catalog.item(kind, GameState.equipped(kind))
		_preview_box.add_child(Kit.label(it.name, 8, UITheme.CREAM if kind == tab else UITheme.DIM))
	var blurb: String = Catalog.item("rider", GameState.equipped("rider")).get("blurb", "")
	_preview_box.add_child(Kit.label(blurb.to_upper(), 8, UITheme.GOLD))

	for c in _grid.get_children():
		c.queue_free()
	for it in Catalog.items(tab):
		_grid.add_child(_tile(it))


func _tile(it: Dictionary) -> Control:
	var id: String = it.id
	var owned := GameState.owns(tab, id)
	var equipped := GameState.equipped(tab) == id
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UITheme.box(Color(UITheme.PANEL, 0.96),
		UITheme.GOLD if equipped else Color("5a4a6e"), 2, 3))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	var rig := GameState.loadout()
	rig[tab] = id
	var prev := Widgets.RigPreview.new(rig, 1.5)
	prev.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(prev)
	var name_l := Kit.label(it.name, 8, UITheme.CREAM)
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD
	v.add_child(name_l)
	var b: Button
	if equipped:
		b = Kit.button("RIDING", 0, 22)
		b.disabled = true
	elif owned:
		b = Kit.button("EQUIP", 0, 22)
		b.pressed.connect(func(): _equip(id))
	else:
		var price := int(it.price)
		b = Kit.button("SURE?" if _confirm == id else "BUY %d" % price, 0, 22)
		b.disabled = GameState.money() < price
		b.pressed.connect(func(): _try_buy(id))
	v.add_child(b)
	panel.add_child(v)
	return panel


func _equip(id: String) -> void:
	GameState.equip(tab, id)
	if tab == "bike":
		AudioDirector.preview_engine(id)
	_build()


func _try_buy(id: String) -> void:
	if _confirm != id:
		_confirm = id
		_build()
		return
	_confirm = ""
	if GameState.buy(tab, id):
		AudioDirector.play("purchase")
		if tab == "bike":
			AudioDirector.preview_engine(id)
	_build()


func on_back() -> void:
	navigate.emit("title", "")
