## CHALLENGES: the season strip, then a card each for the daily ride, today's missions,
## endless and the weekly league (with its table). A week that's ended is settled here
## the first time you look in (your place, the reward, up or down a division).
extends Control

signal navigate(target: String, arg: String)

const Backdrop := preload("res://scripts/game/backdrop.gd")
const Catalog := preload("res://scripts/catalog.gd")
const Endless := preload("res://scripts/game/endless.gd")
const Kit := preload("res://scripts/ui/kit.gd")
const UITheme := preload("res://scripts/ui/ui_theme.gd")
const Widgets := preload("res://scripts/ui/widgets.gd")
const BikeView := preload("res://scripts/game/bike_view.gd")

const CARD_W := 96

var _row: HBoxContainer
var _scroll: ScrollContainer
var _overlay: Control
var focus := ""


func _ready() -> void:
	Kit.full_rect(self)
	theme = GameState.theme
	var bg := CanvasLayer.new()
	bg.layer = -10
	add_child(bg)
	var bd := Backdrop.new()
	bd.theme_index = Challenges.season_theme()
	bd.cam = Vector2(900, 0)
	bg.add_child(bd)
	var shade := Kit.full_rect(ColorRect.new())
	shade.color = Color(0.04, 0.02, 0.07, 0.5)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.add_child(Kit.top_bar("CHALLENGES", func(): navigate.emit("title", "")))
	col.add_child(_season_strip())
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 6)
	center.add_child(_row)
	_scroll.add_child(center)
	col.add_child(_scroll)
	add_child(Kit.full_rect(Kit.margin(col, 8)))
	_build()
	AudioDirector.set_track(String(Catalog.MUSIC_BY_THEME[Challenges.season_theme()]))
	var res := Challenges.week_result()
	if not res.is_empty():
		_week_result(res)
	elif focus == "league":
		_league_table()


func _exit_tree() -> void:
	AudioDirector.set_context("menu")


func _build() -> void:
	for c in _row.get_children():
		c.queue_free()
	_row.add_child(_daily_card())
	_row.add_child(_missions_card())
	_row.add_child(_endless_card())
	_row.add_child(_league_card())
	Kit.pass_drags(_row)


func _panel(title: String, sub := "") -> Array:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.box(Color(UITheme.PANEL, 0.96), Color("5a4a6e"), 2, 5))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.custom_minimum_size = Vector2(CARD_W, 0)
	v.add_child(_wrap(title, UITheme.GOLD))
	if sub != "":
		v.add_child(_wrap(sub, UITheme.DIM))
	panel.add_child(v)
	return [panel, v]


func _wrap(text: String, c: Color) -> Label:
	var l := Kit.label(text, 8, c)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.custom_minimum_size = Vector2(CARD_W, 0)
	return l


func _season_strip() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.box(Color(UITheme.PANEL, 0.96), UITheme.GOLD, 2, 3))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.add_child(Kit.label(Challenges.season_name(), 8, UITheme.GOLD))
	var tier := Challenges.season_tier()
	h.add_child(Kit.label("TIER %d" % tier, 8, UITheme.CREAM))
	var bar := XpBar.new()
	bar.custom_minimum_size = Vector2(40, 8)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(bar)
	h.add_child(Kit.label("%dD LEFT" % Challenges.season_days_left(), 8, UITheme.DIM))
	h.add_child(Kit.spacer())
	var n := Challenges.claimable()
	var b := Kit.button("PASS (%d) >" % n if n > 0 else "PASS >", 0, 20)
	b.pressed.connect(func(): navigate.emit("season", ""))
	h.add_child(b)
	panel.add_child(h)
	return panel


func _daily_card() -> Control:
	var d := Challenges.daily()
	var rec := Challenges.daily_record()
	var pv: Array = _panel("DAILY RIDE")
	var v: VBoxContainer = pv[1]
	v.add_child(_wrap(String(Challenges.WEEKDAYS[Challenges.weekday()]), UITheme.CREAM))
	var th := Widgets.LevelThumb.new(int(d.theme), false, String(d.time), String(d.weather))
	th.custom_minimum_size = Vector2(CARD_W, 32)
	v.add_child(th)
	v.add_child(_wrap("%s, %s" % [String(d.time).to_upper(), String(d.weather).to_upper()], UITheme.DIM))
	if bool(rec.cleared):
		v.add_child(_wrap("DONE! %.1fs" % float(rec.best), UITheme.GREEN))
		v.add_child(_wrap("UNDER PAR!" if bool(rec.gold) else "PAR: +XP", UITheme.GOLD if bool(rec.gold) else UITheme.DIM))
	else:
		v.add_child(_wrap("CLEAR: +%d" % Challenges.DAILY_COINS, UITheme.GOLD))
	var st := Challenges.streak_count()
	v.add_child(_wrap("STREAK %d" % st, UITheme.CREAM))
	v.add_child(Kit.spacer(false))
	var b := Kit.button("RIDE", 0, 24)
	b.pressed.connect(func(): navigate.emit("game", "daily"))
	v.add_child(b)
	return pv[0]


func _missions_card() -> Control:
	var pv: Array = _panel("MISSIONS")
	var v: VBoxContainer = pv[1]
	for m in Challenges.missions():
		var done := bool(m.done)
		v.add_child(_wrap(String(m.text), UITheme.GREEN if done else UITheme.CREAM))
		var row := HBoxContainer.new()
		var bar := ProgressBit.new()
		bar.frac = clampf(float(m.prog) / maxf(1.0, float(m.goal)), 0.0, 1.0)
		bar.done = done
		bar.custom_minimum_size = Vector2(CARD_W, 4)
		row.add_child(bar)
		v.add_child(row)
	v.add_child(Kit.spacer(false))
	v.add_child(_wrap("+%d EACH" % Challenges.MISSION_COINS, UITheme.DIM))
	return pv[0]


func _endless_card() -> Control:
	var pv: Array = _panel("ENDLESS")
	var v: VBoxContainer = pv[1]
	v.add_child(_wrap("ONE LIFE", UITheme.CREAM))
	var th := Widgets.LevelThumb.new(Challenges.season_theme(), false, "dusk", "clear")
	th.custom_minimum_size = Vector2(CARD_W, 32)
	v.add_child(th)
	var best := Challenges.endless_best()
	v.add_child(_wrap("BEST %d M" % best if best > 0 else "NO RUNS YET", UITheme.GOLD if best > 0 else UITheme.DIM))
	v.add_child(_wrap("FASTER EVERY KM", UITheme.DIM))
	v.add_child(Kit.spacer(false))
	var b := Kit.button("RIDE", 0, 24)
	b.pressed.connect(func(): navigate.emit("game", "endless"))
	v.add_child(b)
	return pv[0]


func _league_card() -> Control:
	var div := Challenges.division()
	var pv: Array = _panel("LEAGUE")
	var v: VBoxContainer = pv[1]
	v.add_child(_wrap(Challenges.DIVISIONS[div], _div_color(div)))
	var best := int(Challenges.data().league.get("best_m", 0))
	var rank := Challenges.league_rank()
	v.add_child(_wrap("BEST %d M" % best if best > 0 else "NOT RIDDEN", UITheme.CREAM))
	v.add_child(_wrap("%s OF %d" % [_ordinal(rank), Challenges.GROUP], UITheme.GREEN if rank <= Challenges.PROMOTE else UITheme.CREAM))
	v.add_child(_wrap("TOP %d GO UP" % Challenges.PROMOTE, UITheme.DIM))
	v.add_child(_wrap("%d DAY%s LEFT" % [Challenges.week_days_left(), "" if Challenges.week_days_left() == 1 else "S"], UITheme.DIM))
	v.add_child(Kit.spacer(false))
	var t := Kit.button("TABLE", 0, 20)
	t.pressed.connect(_league_table)
	v.add_child(t)
	var b := Kit.button("RIDE", 0, 24)
	b.pressed.connect(func(): navigate.emit("game", "league"))
	v.add_child(b)
	return pv[0]


static func _div_color(div: int) -> Color:
	return [Color("c9a26b"), Color("b8b0a8"), Color("8fd36a"), Color("9fc8e8"), UITheme.GOLD][div]


static func _ordinal(n: int) -> String:
	var suf := "TH"
	if n % 100 < 11 or n % 100 > 13:
		suf = ["TH", "ST", "ND", "RD", "TH", "TH", "TH", "TH", "TH", "TH"][n % 10]
	return "%d%s" % [n, suf]


# --- overlays --------------------------------------------------------------------------

func _show(content: Control) -> void:
	_close()
	var root := Kit.full_rect(Control.new())
	var dim := Kit.full_rect(ColorRect.new())
	dim.color = Color(0.04, 0.02, 0.07, 0.7)
	root.add_child(dim)
	var center := Kit.full_rect(CenterContainer.new())
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.add_child(content)
	center.add_child(panel)
	add_child(root)
	_overlay = root


func _close() -> void:
	if _overlay:
		_overlay.queue_free()
		_overlay = null


func _league_table() -> void:
	var div := Challenges.division()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	v.add_child(Kit.label("%s DIVISION" % Challenges.DIVISIONS[div], 16, _div_color(div)))
	v.add_child(Kit.label("WEEK %d - %d DAYS LEFT - TOP %d MOVE UP, BOTTOM %d DOWN" % [Challenges.week() + 1,
		Challenges.week_days_left(), Challenges.PROMOTE, Challenges.PROMOTE], 8, UITheme.DIM))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(300, minf(150.0, get_viewport_rect().size.y - 110.0))
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 1)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var st := Challenges.standings()
	var you_row: Control = null
	for i in st.size():
		var r: Dictionary = st[i]
		var row := TableRow.new()
		row.rank = i + 1
		row.who = String(r.name)
		row.rider = String(r.rider)
		row.m = int(r.m)
		row.you = bool(r.you)
		row.zone = 1 if i < Challenges.PROMOTE else (-1 if i >= Challenges.GROUP - Challenges.PROMOTE and div > 0 else 0)
		row.custom_minimum_size = Vector2(290, 14)
		list.add_child(row)
		if row.you:
			you_row = row
	scroll.add_child(list)
	v.add_child(scroll)
	var b := Kit.button("CLOSE", 100, 22)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(_close)
	v.add_child(b)
	_show(v)
	if you_row:
		(func():
			await get_tree().process_frame
			scroll.ensure_control_visible(you_row)).call()


func _week_result(res: Dictionary) -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	v.add_child(Kit.label("LAST WEEK'S LEAGUE", 16, UITheme.GOLD))
	v.add_child(Kit.label("YOU CAME %s OF %d" % [_ordinal(int(res.rank)), Challenges.GROUP], 8, UITheme.CREAM))
	v.add_child(Kit.label("+%d COINS   +%d XP" % [int(res.coins), int(res.xp)], 8, UITheme.GOLD))
	var from := int(res.from)
	var to := int(res.to)
	var msg := "YOU STAY IN %s." % Challenges.DIVISIONS[to]
	if to > from:
		msg = "UP TO %s!" % Challenges.DIVISIONS[to]
	elif to < from:
		msg = "DOWN TO %s." % Challenges.DIVISIONS[to]
	v.add_child(Kit.label(msg, 8, _div_color(to)))
	var b := Kit.button("OK", 100, 22)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func():
		_close()
		_build())
	v.add_child(b)
	_show(v)
	AudioDirector.play("finish")


func on_back() -> void:
	if _overlay:
		_close()
		return
	navigate.emit("title", "")


class XpBar extends Control:
	func _draw() -> void:
		var xp := Challenges.season_xp()
		var tier := Challenges.season_tier()
		var frac := 1.0 if tier >= Challenges.SEASON_TIERS else float(xp % Challenges.TIER_XP) / Challenges.TIER_XP
		draw_rect(Rect2(Vector2.ZERO, size), Color("2a2434"))
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * frac, size.y)), Color("9fe8ff"))
		draw_rect(Rect2(Vector2.ZERO, size), Color("5a4a6e"), false, 1.0)


class ProgressBit extends Control:
	var frac := 0.0
	var done := false

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("2a2434"))
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * frac, size.y)), Color("5bd16a") if done else Color("f2c14e"))


class TableRow extends Control:
	const UIThemeC := preload("res://scripts/ui/ui_theme.gd")
	const BikeViewC := preload("res://scripts/game/bike_view.gd")
	var rank := 0
	var who := ""
	var rider := ""
	var m := 0
	var you := false
	var zone := 0

	func _draw() -> void:
		var font: Font = GameState.font
		var bgc := Color(UIThemeC.GOLD, 0.25) if you else Color(UIThemeC.INK, 0.5)
		draw_rect(Rect2(Vector2.ZERO, size), bgc)
		if zone != 0:
			draw_rect(Rect2(0, 0, 3, size.y), UIThemeC.GREEN if zone > 0 else UIThemeC.RED)
		var c := UIThemeC.GOLD if you else UIThemeC.CREAM
		draw_string(font, Vector2(8, 11), "%2d" % rank, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UIThemeC.DIM)
		draw_string(font, Vector2(52, 11), who, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, c)
		draw_string(font, Vector2(0, 11), "%d M" % m if m > 0 else "-", HORIZONTAL_ALIGNMENT_RIGHT, size.x - 6, 8, c)
		# A tiny head for each rider (theirs, or yours).
		draw_set_transform(Vector2(36, 10), 0.0, Vector2(1, 1))
		BikeViewC.draw_head(self, Vector2.ZERO, rider, 0.0)
		draw_set_transform(Vector2.ZERO)
