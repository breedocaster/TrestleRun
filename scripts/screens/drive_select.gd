## SUMMIT / GAUNTLET level select: twelve cards (each opens when the one before is
## done), the bike you're riding, GARAGE, and for SUMMIT the upgrade shop.
## arg = "summit" | "gauntlet" | "summit:upgrades" (opens the shop).
extends Control

signal navigate(target: String, arg: String)

const Backdrop := preload("res://scripts/game/backdrop.gd")
const Kit := preload("res://scripts/ui/kit.gd")
const UITheme := preload("res://scripts/ui/ui_theme.gd")
const Widgets := preload("res://scripts/ui/widgets.gd")
const Catalog := preload("res://scripts/catalog.gd")
const Progress := preload("res://scripts/drive/drive_progress.gd")
const Vehicles := preload("res://scripts/drive/vehicles.gd")
const Table := preload("res://scripts/drive/drive_table.gd")

const NAMES := {"summit": "SUMMIT", "gauntlet": "GAUNTLET"}
const BLURB := {
	"summit": "HILL CLIMBS ON ONE TANK. FULL GAS UP A STEEP HILL FLIPS YOU: EASE OFF. IN THE AIR, GAS TIPS YOU BACK, BRAKE FORWARD.",
	"gauntlet": "OBSTACLES AGAINST THE CLOCK. GAS LIFTS THE FRONT, BRAKE DIPS IT. BRAKE THEN GAS QUICKLY TO HOP. EVERY CRASH IS A FAULT.",
}
const GHOST_NAMES := {"best": "GHOST: BEST", "gold": "GHOST: GOLD", "off": "GHOST: OFF"}
const UPGRADE_NAMES := {"engine": "ENGINE", "suspension": "SUSPENSION", "tires": "TIRES", "tank": "TANK"}
const UPGRADE_NAMES_E := {"engine": "MOTOR", "suspension": "SUSPENSION", "tires": "TIRES", "tank": "BATTERY"}

var mode := "summit"
var _open_shop := false
var _ghost_btn: Button
var _bottom: Control
var _row: HBoxContainer
var _scroll: ScrollContainer
var _shop: Control


func setup(arg: String) -> void:
	var p := arg.split(":")
	mode = p[0] if p[0] in NAMES else "summit"
	_open_shop = p.size() > 1 and p[1] == "upgrades"


func _ready() -> void:
	Kit.full_rect(self)
	theme = GameState.theme
	var bg := CanvasLayer.new()
	bg.layer = -10
	add_child(bg)
	var bd := Backdrop.new()
	bd.theme_index = 8 if mode == "summit" else 2
	bd.cam = Vector2(900, 0)
	bg.add_child(bd)
	var shade := Kit.full_rect(ColorRect.new())
	shade.color = Color(0.04, 0.02, 0.07, 0.45)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	var bar := Kit.top_bar(NAMES[mode], func(): navigate.emit("title", ""))
	# Which ghost rides with you: your best run (the gold line until you have one), the
	# level checker's gold line, or none.
	var gb := Kit.button(GHOST_NAMES[Progress.ghost_mode()], 92, 22)
	gb.pressed.connect(func():
		var order := ["best", "gold", "off"]
		var nxt: String = order[(order.find(Progress.ghost_mode()) + 1) % order.size()]
		Progress.set_ghost_mode(nxt)
		gb.text = GHOST_NAMES[nxt]
		AudioDirector.play("toggle"))
	bar.add_child(gb)
	# Beside BACK: on a pad, up from GARAGE should reach the cards' RIDE, not this
	# (nav_input.gd picks the nearest button in line, and on the right it was in line).
	bar.move_child(gb, 1)
	_ghost_btn = gb
	col.add_child(bar)
	var blurb := Kit.label(BLURB[mode], 8, UITheme.DIM)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD
	col.add_child(blurb)
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
	_bottom = _bottom_bar()
	col.add_child(_bottom)
	add_child(Kit.full_rect(Kit.margin(col, 8)))
	_build_cards()
	_scroll_to_current.call_deferred()
	if _open_shop:
		_show_shop.call_deferred()


func _bottom_bar() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	var rig := GameState.loadout()
	var prev := Widgets.RigPreview.new(rig, 1.0)
	prev.custom_minimum_size = Vector2(40, 26)
	h.add_child(prev)
	var bike := Catalog.item("bike", String(rig.bike))
	var info := String(bike.get("name", rig.bike))
	if mode == "summit":
		var u := Progress.upgrades(String(rig.bike))
		info += "  LV %d/%d/%d/%d" % [u.engine, u.suspension, u.tires, u.tank]
	h.add_child(Kit.label(info, 8, UITheme.CREAM))
	var g := Kit.button("GARAGE", 70, 22)
	g.pressed.connect(func(): navigate.emit("garage", ""))
	h.add_child(g)
	if mode == "summit":
		var s := Kit.button("UPGRADES", 80, 22)
		s.pressed.connect(_show_shop)
		h.add_child(s)
	return h


func _scroll_to_current() -> void:
	await get_tree().process_frame
	var n := Progress.levels(mode).size()
	for i in n:
		if Progress.unlocked(mode, i) and not bool(Progress.record(Progress.level_id(mode, i)).done):
			var card: Control = _row.get_child(i)
			_scroll.scroll_horizontal = int(maxf(0.0, card.position.x - 40.0))
			return



func _build_cards() -> void:
	for c in _row.get_children():
		c.queue_free()
	var ls: Array = Progress.levels(mode)
	for i in ls.size():
		_row.add_child(_card(i, ls[i]))
	Kit.pass_drags(_row)


func _card(i: int, meta: Dictionary) -> Control:
	var open := Progress.unlocked(mode, i)
	var rec := Progress.record(String(meta.id))
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.box(Color(UITheme.PANEL, 0.96), Color("5a4a6e"), 2, 5))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.add_child(Kit.label("%s %d" % ["CLIMB" if mode == "summit" else "COURSE", i + 1], 8, UITheme.DIM))
	var tl := Kit.label(String(meta.name), 8, UITheme.CREAM)
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD
	tl.custom_minimum_size = Vector2(92, 20)
	v.add_child(tl)
	v.add_child(ProfileThumb.new(mode, i, int(meta.theme), String(meta.time), not open))
	var mr := HBoxContainer.new()
	mr.add_theme_constant_override("separation", 2)
	mr.alignment = BoxContainer.ALIGNMENT_CENTER
	mr.add_child(Widgets.MedalRow.new(rec.medals, [false, false, false], 0.0, 0, true))
	mr.add_child(Widgets.StarRow.new(rec.obj))
	v.add_child(mr)
	var info := ""
	if mode == "summit":
		info = "%d M" % int(meta.m)
		if int(rec.best_m) > 0 and not bool(rec.done):
			info = "BEST %d/%d M" % [int(rec.best_m), int(meta.m)]
	if bool(rec.done):
		info = "BEST %.1fs" % float(rec.best_time)
		if mode == "gauntlet":
			info += " F%d" % int(rec.best_faults)
	v.add_child(Kit.label(info if open else "FINISH %d FIRST" % i, 8, UITheme.DIM))
	# The level checker records which bikes it got through each level (SUMMIT on the
	# upgrades in the level's list); warn when yours isn't one of them.
	var bike := GameState.equipped("bike")
	var ok_bikes: Array = Table.RIDEABLE.get(String(meta.id), [])
	var why := ""
	if open and not ok_bikes.is_empty() and not ok_bikes.has(bike):
		why = "TOUGH ON THIS BIKE"
	elif open and mode == "summit":
		# Checked on these upgrades (summit_levels.gd up_req): say so if yours are lower.
		var u := Progress.upgrades(bike)
		var req: Array = meta.get("up_req", [0, 0, 0, 0])
		for k in Vehicles.UPGRADES.size():
			if int(u[Vehicles.UPGRADES[k]]) < int(req[k]):
				why = "NEEDS UPGRADES"
	var warn := Kit.label(why, 8, Color("ff9a5a"))
	warn.autowrap_mode = TextServer.AUTOWRAP_WORD
	warn.custom_minimum_size = Vector2(92, 0)
	v.add_child(warn)
	var b := Kit.button("RIDE" if open else "LOCKED", 0, 26)
	b.disabled = not open
	b.pressed.connect(func(): navigate.emit("drive", "%s:%d" % [mode, i]))
	v.add_child(b)
	panel.add_child(v)
	return panel


## The card's picture: the level's own ground, start to finish, squeezed into the box
## over its sky (SUMMIT climbs up to the right; GAUNTLET's obstacles show as bumps).
class ProfileThumb extends Control:
	const Art := preload("res://scripts/drive/drive_art.gd")
	const Summit := preload("res://scripts/drive/summit_levels.gd")
	const Gauntlet := preload("res://scripts/drive/gauntlet_levels.gd")
	var theme_index := 0
	var time_mode := "day"
	var locked := false
	var pts := PackedVector2Array()
	var in_pit := []   # per point: inside a pit (left out of the height range, drawn as a gap)

	func _init(mode: String, i: int, ti: int, t_mode: String, is_locked: bool) -> void:
		theme_index = ti
		time_mode = t_mode
		locked = is_locked
		custom_minimum_size = Vector2(88, 40)
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var lv: Dictionary = Summit.build(i) if mode == "summit" else Gauntlet.build(i)
		var g: PackedVector2Array = lv.ground
		var x1 := float(lv.finish_x)
		for p in g:
			if p.x >= -40.0 and p.x <= x1 + 40.0:
				pts.append(p)
				var pit := false
				for gp in lv.get("gaps", []):
					# Inside, or the pit floor's corners right under its edges.
					if p.x > float(gp[0]) - 0.5 and p.x < float(gp[1]) + 0.5 and p.y > float(gp[2]) + 20.0:
						pit = true
				in_pit.append(pit)

	func _draw() -> void:
		var th := Backdrop.theme(theme_index, time_mode, "clear")
		var sky: Array = th.sky
		var bh := ceilf(size.y / sky.size())
		for k in sky.size():
			draw_rect(Rect2(0, k * bh, size.x, bh + 1), sky[k])
		if pts.size() > 1:
			var x0 := pts[0].x
			var x1 := pts[pts.size() - 1].x
			var y0 := INF
			var y1 := -INF
			for k in pts.size():
				if not in_pit[k]:
					y0 = minf(y0, pts[k].y)
					y1 = maxf(y1, pts[k].y)
			# Keep the climb's real proportions where they fit; flat courses get some
			# height so their obstacles show.
			var sx := (size.x - 4.0) / maxf(1.0, x1 - x0)
			var sy := minf((size.y - 12.0) / maxf(1.0, y1 - y0), sx * 6.0)
			var base := size.y - 4.0
			var cols := Art.ground_colors(theme_index, time_mode)
			var poly := PackedVector2Array()
			for k in pts.size():
				var p := pts[k]
				poly.append(Vector2(2.0 + (p.x - x0) * sx, size.y + 2.0 if in_pit[k] else base - (y1 - p.y) * sy))
			for k in range(poly.size() - 1):
				var a := poly[k]
				var b := poly[k + 1]
				if b.x - a.x > 0.05 and maxf(a.y, b.y) < size.y:
					draw_colored_polygon(PackedVector2Array([a, b, Vector2(b.x, size.y), Vector2(a.x, size.y)]), cols[1])
				if not (in_pit[k] or in_pit[k + 1]):
					draw_line(a, b, cols[0], 1.0)
			var f := poly[poly.size() - 1]
			draw_line(f, f + Vector2(0, -7), Color("d8d0c0"), 1.0)
			draw_rect(Rect2(f.x - 4, f.y - 7, 4, 3), Color("d9453b"))
		if locked:
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.03, 0.08, 0.7))
			var c := size * 0.5
			draw_rect(Rect2(c.x - 6, c.y - 2, 12, 9), Color("c9d1d9"))
			draw_rect(Rect2(c.x - 4, c.y - 8, 2, 6), Color("c9d1d9"))
			draw_rect(Rect2(c.x + 2, c.y - 8, 2, 6), Color("c9d1d9"))
			draw_rect(Rect2(c.x - 4, c.y - 9, 8, 2), Color("c9d1d9"))
			draw_rect(Rect2(c.x - 1, c.y + 1, 2, 3), Color("2b2135"))
		draw_rect(Rect2(Vector2.ZERO, size), Color("5a4a6e"), false, 1.0)


# --- upgrade shop (SUMMIT) --------------------------------------------------------------

func _show_shop() -> void:
	if _shop:
		_shop.queue_free()
	var bike := GameState.equipped("bike")
	var names: Dictionary = UPGRADE_NAMES_E if Vehicles.is_electric(bike) else UPGRADE_NAMES
	var root := Kit.full_rect(Control.new())
	var dim := Kit.full_rect(ColorRect.new())
	dim.color = Color(0.04, 0.02, 0.07, 0.7)
	root.add_child(dim)
	var center := Kit.full_rect(CenterContainer.new())
	root.add_child(center)
	var panel := PanelContainer.new()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	v.add_child(Kit.label("UPGRADES: %s" % String(Catalog.item("bike", bike).get("name", bike)), 16, UITheme.GOLD))
	v.add_child(Kit.label("FOR SUMMIT. EACH BIKE KEEPS ITS OWN. WALLET %d" % GameState.money(), 8, UITheme.DIM))
	var u := Progress.upgrades(bike)
	for k in Vehicles.UPGRADES:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		var l := Kit.label(String(names[k]), 8, UITheme.CREAM, HORIZONTAL_ALIGNMENT_LEFT)
		l.custom_minimum_size = Vector2(90, 0)
		h.add_child(l)
		var pips := Kit.label("", 8, UITheme.GOLD, HORIZONTAL_ALIGNMENT_LEFT)
		var s := ""
		for n in Vehicles.MAX_LEVEL:
			s += "#" if n < int(u[k]) else "-"
		pips.text = s
		pips.custom_minimum_size = Vector2(56, 0)
		h.add_child(pips)
		var lvl := int(u[k])
		var b: Button
		if lvl >= Vehicles.MAX_LEVEL:
			b = Kit.button("MAX", 90, 22)
			b.disabled = true
		else:
			var cost := Vehicles.upgrade_cost(lvl)
			b = Kit.button("%d COINS" % cost, 90, 22, "")
			b.disabled = GameState.money() < cost
			b.pressed.connect(func():
				if Progress.buy_upgrade(bike, k):
					AudioDirector.play("purchase")
					_show_shop())
		h.add_child(b)
		v.add_child(h)
	var done := Kit.button("DONE", 90, 24)
	done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	done.pressed.connect(func():
		_shop.queue_free()
		_shop = null
		navigate.emit("drive_select", mode))
	v.add_child(done)
	panel.add_child(v)
	center.add_child(panel)
	add_child(root)
	_shop = root


func on_back() -> void:
	if _shop:
		_shop.queue_free()
		_shop = null
		return
	navigate.emit("title", "")
