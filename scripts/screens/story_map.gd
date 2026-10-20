## Story map: Grandpa's bike on the left (parts recovered so far), the county's areas on
## the right. Each area: three trails and its boss; beat the boss to get its part back
## and open the next area. Tap a trail for its card (conditions, tips, GO!).
extends Control

signal navigate(target: String, arg: String)

const Backdrop := preload("res://scripts/game/backdrop.gd")
const Catalog := preload("res://scripts/catalog.gd")
const Kit := preload("res://scripts/ui/kit.gd")
const UITheme := preload("res://scripts/ui/ui_theme.gd")
const Widgets := preload("res://scripts/ui/widgets.gd")
const HintCard := preload("res://scripts/ui/hint_card.gd")
const BossArt := preload("res://scripts/game/boss_art.gd")
const Icons := preload("res://scripts/game/icons.gd")

const TIME_NAMES := {"day": "DAY", "dusk": "DUSK", "night": "NIGHT"}
const WEATHER_NAMES := {"clear": "CLEAR", "rain": "RAIN", "wind": "WIND"}

var _row: HBoxContainer
var _scroll: ScrollContainer
var _card: Control
var _hint: Control


func _ready() -> void:
	Kit.full_rect(self)
	theme = GameState.theme
	var bg := CanvasLayer.new()
	bg.layer = -10
	add_child(bg)
	var bd := Backdrop.new()
	bd.theme_index = 12
	bd.time_mode = "dusk"
	bd.cam = Vector2(700, 0)
	bg.add_child(bd)
	var shade := Kit.full_rect(ColorRect.new())
	shade.color = Color(0.04, 0.02, 0.07, 0.45)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.add_child(Kit.top_bar("STORY", func(): navigate.emit("title", "")))
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 6)
	col.add_child(body)
	body.add_child(_bike_panel())
	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 6)
	_scroll.add_child(_row)
	body.add_child(_scroll)
	add_child(Kit.full_rect(Kit.margin(col, 8)))
	_build()
	_scroll_to_current.call_deferred()
	# The map plays the loop of the area you're up to (the boss's area loop, not its fight).
	AudioDirector.set_track(String(Catalog.MUSIC_BY_THEME[int(Catalog.level(GameState.story_current()).theme)]))


func _bike_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(132, 0)
	panel.add_theme_stylebox_override("panel", UITheme.box(Color(UITheme.PANEL, 0.96), UITheme.GOLD, 2, 4))
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 4)
	v.add_child(Kit.label("GRANDPA'S BIKE", 8, UITheme.GOLD))
	var parts := GameState.story_parts()
	var bike := Widgets.GrandpaBikeView.new(parts, 1.15)
	bike.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(bike)
	v.add_child(Kit.label("PARTS %d/%d" % [parts.size(), Catalog.PARTS.size()], 8, UITheme.CREAM))
	v.add_child(Widgets.PartRow.new(parts))
	var again := Kit.button("STORY SO FAR", 0, 22)
	again.pressed.connect(func(): navigate.emit("story_intro", ""))
	v.add_child(again)
	panel.add_child(v)
	return panel


func _scroll_to_current() -> void:
	await get_tree().process_frame
	var cur := GameState.story_current()
	var area := int(Catalog.level(cur).get("story", 0))
	if area < _row.get_child_count():
		var card: Control = _row.get_child(area)
		_scroll.scroll_horizontal = int(maxf(0.0, card.position.x - 4.0))


func _build() -> void:
	for c in _row.get_children():
		c.queue_free()
	var areas := Catalog.STORY_AREAS
	for i in areas.size():
		_row.add_child(_area_card(i, areas[i]))
	_row.add_child(_coming_card())
	Kit.pass_drags(_row)


func _area_open(i: int) -> bool:
	return GameState.level_unlocked(String(Catalog.STORY_AREAS[i].trails[0]))


func _area_card(i: int, area: Dictionary) -> Control:
	var open := _area_open(i)
	var got: bool = String(area.part) in GameState.story_parts()
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(150, 0)
	panel.add_theme_stylebox_override("panel", UITheme.box(Color(UITheme.PANEL, 0.96), UITheme.GOLD if got else Color("5a4a6e"), 2, 4))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.add_child(Kit.label("AREA %d" % (i + 1), 8, UITheme.DIM))
	v.add_child(Kit.label(String(area.name), 8, UITheme.CREAM if open else UITheme.DIM))
	var thumb := Widgets.LevelThumb.new(int(area.theme), not open, "dusk")
	thumb.custom_minimum_size = Vector2(134, 34)
	v.add_child(thumb)
	if open:
		var blurb := Kit.label(String(area.blurb), 8, UITheme.DIM, HORIZONTAL_ALIGNMENT_LEFT)
		blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		blurb.custom_minimum_size = Vector2(134, 0)
		v.add_child(blurb)
	else:
		var prev: Dictionary = Catalog.STORY_AREAS[maxi(0, i - 1)]
		var need := Kit.label("LOCKED: BEAT %s FIRST" % BossArt.boss_name(_boss_kind(String(prev.boss))), 8, UITheme.DIM)
		need.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		need.custom_minimum_size = Vector2(134, 0)
		v.add_child(need)
	# The three trails and the boss.
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 3)
	var ids: Array = (area.trails as Array) + [area.boss]
	for k in ids.size():
		grid.add_child(_node_button(String(ids[k]), "BOSS" if k == 3 else str(k + 1)))
	v.add_child(grid)
	# The part this area hides.
	var pr := HBoxContainer.new()
	pr.alignment = BoxContainer.ALIGNMENT_CENTER
	pr.add_child(PartIcon.new(String(area.part), got))
	pr.add_child(Kit.label(BossArt.part_name(String(area.part)) if got else "???", 8, UITheme.GOLD if got else UITheme.DIM))
	v.add_child(pr)
	panel.add_child(v)
	return panel


func _coming_card() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(150, 0)
	panel.add_theme_stylebox_override("panel", UITheme.box(Color(UITheme.PANEL, 0.85), Color("3d3050"), 2, 4))
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 6)
	v.add_child(Kit.label("STILL OUT THERE", 8, UITheme.GOLD))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for p in Catalog.PARTS_COMING:
		row.add_child(PartIcon.new(String(p), false))
	v.add_child(row)
	var l := Kit.label("THE CARB, THE ENGINE'S TOP AND BOTTOM END, AND THE FRAME. MORE OF THE COUNTY IS COMING SOON.", 8, UITheme.DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(134, 0)
	v.add_child(l)
	panel.add_child(v)
	return panel


func _boss_kind(boss_id: String) -> String:
	var lv: Array = preload("res://scripts/game/level_layouts.gd").STORY.get(boss_id, [])
	for ch in lv:
		if String(ch[0]) == "boss":
			return String(ch[1])
	return ""


func _node_button(id: String, text: String) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	var open := GameState.level_unlocked(id)
	var rec := GameState.level_record(id)
	var b := Kit.button(text, 32 if text != "BOSS" else 36, 22)
	b.disabled = not open
	if rec.cleared:
		b.add_theme_color_override("font_color", UITheme.GOLD)
	b.pressed.connect(func(): _show_card(id))
	v.add_child(b)
	var medals := Widgets.MedalRow.new(GameState.medals(id), [false, false, false], 0.0, 0, true)
	medals.custom_minimum_size = Vector2(32, 12)
	medals.visible = open
	v.add_child(medals)
	return v


## The trail's card: its fixed time and weather, what's new, tips, and GO!.
func _show_card(id: String) -> void:
	_close_card()
	var meta := Catalog.level(id)
	var cond: Dictionary = meta.get("cond", {"time": "dusk", "weather": "clear"})
	var root := Kit.full_rect(Control.new())
	var dim := Kit.full_rect(ColorRect.new())
	dim.color = Color(0.04, 0.02, 0.07, 0.65)
	root.add_child(dim)
	var center := Kit.full_rect(CenterContainer.new())
	root.add_child(center)
	var panel := PanelContainer.new()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	v.add_child(Kit.label(Catalog.level_label(id), 8, UITheme.DIM))
	v.add_child(Kit.label(String(meta.name), 16, UITheme.GOLD))
	var thumb := Widgets.LevelThumb.new(int(meta.theme), false, String(cond.time), String(cond.weather))
	thumb.custom_minimum_size = Vector2(220, 44)
	v.add_child(thumb)
	v.add_child(Kit.label("%s, %s" % [TIME_NAMES.get(cond.time, ""), WEATHER_NAMES.get(cond.weather, "")], 8, UITheme.CREAM))
	v.add_child(Kit.label("NEW: " + Catalog.feature_names(meta, ", "), 8, UITheme.GOLD))
	var rec := GameState.level_record(id)
	var info := "BEST TIME %.1fs" % float(rec.best_time) if float(rec.get("best_time", 0.0)) > 0.0 else "NOT CLEARED YET"
	if meta.get("boss", false):
		info = ("BEATEN" if rec.cleared else "IT'S HOLDING THE %s" % BossArt.part_name(String(meta.part)))
	v.add_child(Kit.label(info, 8, UITheme.DIM))
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	var back := Kit.button("BACK", 64, 26)
	back.pressed.connect(_close_card)
	var tips := Kit.button("? TIPS", 64, 26)
	tips.pressed.connect(func(): _show_hint(id))
	var go := Kit.button("GO!", 64, 26)
	go.pressed.connect(func(): navigate.emit("game", id))
	btns.add_child(back)
	btns.add_child(tips)
	btns.add_child(go)
	v.add_child(btns)
	panel.add_child(v)
	center.add_child(panel)
	add_child(root)
	_card = root


func _close_card() -> void:
	if _card:
		_card.queue_free()
		_card = null


func _show_hint(id: String) -> void:
	_close_hint()
	var root := Kit.full_rect(Control.new())
	var dim := Kit.full_rect(ColorRect.new())
	dim.color = Color(0.04, 0.02, 0.07, 0.7)
	root.add_child(dim)
	var center := Kit.full_rect(CenterContainer.new())
	var card := HintCard.new(id)
	card.closed.connect(_close_hint)
	center.add_child(card)
	root.add_child(center)
	add_child(root)
	_hint = root


func _close_hint() -> void:
	if _hint:
		_hint.queue_free()
		_hint = null


func on_back() -> void:
	if _hint:
		_close_hint()
		return
	if _card:
		_close_card()
		return
	navigate.emit("title", "")


class PartIcon extends Control:
	const IconsC := preload("res://scripts/game/icons.gd")
	var part := ""
	var got := false

	func _init(p: String, g: bool) -> void:
		part = p
		got = g
		custom_minimum_size = Vector2(20, 18)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		IconsC.part(self, (size * 0.5).floor(), part, 1.0, not got)


func _exit_tree() -> void:
	AudioDirector.set_context("menu")  # back to the theme unless the next screen picks a loop
