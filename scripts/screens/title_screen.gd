## Title: scrolling canyon, idling bike, RIDE / GARAGE.
extends Control

signal navigate(target: String, arg: String)

const Backdrop := preload("res://scripts/game/backdrop.gd")
const BikeView := preload("res://scripts/game/bike_view.gd")
const Kit := preload("res://scripts/ui/kit.gd")
const UITheme := preload("res://scripts/ui/ui_theme.gd")
const MoneyBadge := preload("res://scripts/ui/money_badge.gd")
const Widgets := preload("res://scripts/ui/widgets.gd")
const Catalog := preload("res://scripts/catalog.gd")


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
	gap.custom_minimum_size = Vector2(0, 2)
	col.add_child(gap)
	# Straight back into the trail you were on (or the next one, once it's cleared).
	var cont_id := GameState.continue_target()
	if cont_id != "":
		var cont := Kit.button("CONTINUE: %s >" % Catalog.level_label(cont_id), 150, 22)
		cont.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cont.pressed.connect(func(): navigate.emit("game", cont_id))
		col.add_child(cont)
	# With CONTINUE showing, the rest get a little slimmer so the title still clears the top bar.
	var bh := 22 if cont_id != "" else 26
	if cont_id != "":
		col.add_theme_constant_override("separation", 4)
	var story := Kit.button("STORY", 120, bh)
	story.pressed.connect(func(): navigate.emit("story" if GameState.story().intro_seen else "story_intro", ""))
	var ride := Kit.button("FREE RIDE", 120, bh)
	ride.pressed.connect(func(): navigate.emit("levels", ""))
	var chal := Kit.button("CHALLENGES", 120, bh)
	chal.pressed.connect(func(): navigate.emit("challenges", ""))
	var summit := Kit.button("SUMMIT", 120, bh)
	summit.pressed.connect(func(): navigate.emit("drive_select", "summit"))
	var gauntlet := Kit.button("GAUNTLET", 120, bh)
	gauntlet.pressed.connect(func(): navigate.emit("drive_select", "gauntlet"))
	var garage := Kit.button("GARAGE", 120, bh)
	garage.pressed.connect(func(): navigate.emit("garage", ""))
	# Something waiting in CHALLENGES (today's ride, rewards to take): a gold dot.
	if not bool(Challenges.daily_record().cleared) or Challenges.claimable() > 0:
		var dot := Dot.new()
		dot.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		dot.offset_left = -7
		dot.offset_top = 1
		dot.offset_right = -1
		dot.offset_bottom = 7
		chal.add_child(dot)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 4)
	for b in [story, ride, summit, gauntlet, chal, garage]:
		grid.add_child(b)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(grid)
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
	if GameState.is_desktop():
		var quit := Kit.button("QUIT", 0, 22)
		quit.pressed.connect(_confirm_quit)
		opts.add_child(quit)
	add_child(opts)

	var mb := MoneyBadge.new()
	mb.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	mb.offset_left = -96
	mb.offset_right = -8
	mb.offset_top = 6
	mb.offset_bottom = 30
	add_child(mb)
	var day := Challenges.check_in()
	if day > 0 and not "--no-streak" in OS.get_cmdline_user_args():
		_streak_popup.call_deferred(day)
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


class Dot extends Control:
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		draw_circle(size * 0.5, 3.0, Color("f2c14e").lerp(Color.WHITE, 0.3 + 0.3 * sin(_t * 4.0)))


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
	# On/off settings, two to a row (a lone last one sits in the middle).
	var flags := VBoxContainer.new()
	flags.add_theme_constant_override("separation", 4)
	var buttons := [Widgets.flag_button("GHOST RUN", "ghost", 150), Widgets.flag_button("CRASH HINTS", "hints", 150),
		Widgets.flag_button("FULLSCREEN", "fullscreen", 150, func(_v): GameState.apply_display()) if GameState.is_desktop()
			else Widgets.flag_button("VIBRATION", "vibrate", 150),
		Widgets.flag_button("SCREEN SHAKE", "shake", 150),
		Widgets.flag_button("SHARP PIXELS", "sharp", 150, func(_v): GameState.apply_display())]
	var cheats := Kit.button("CHEATS", 150, 22)
	cheats.pressed.connect(_open_cheats)
	buttons.append(cheats)
	for i in range(0, buttons.size(), 2):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		for b in buttons.slice(i, i + 2):
			row.add_child(b)
		flags.add_child(row)
	flags.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(flags)
	var done := Kit.button("DONE", 100, 26)
	done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	done.pressed.connect(_close_settings)
	v.add_child(done)
	panel.add_child(v)
	center.add_child(panel)
	add_child(root)
	_settings = root


func _close_settings() -> void:
	if _cheats:
		_cheats.queue_free()
		_cheats = null
	if _settings:
		_settings.queue_free()
		_settings = null


var _cheats: Control


## GoldenEye-style cheats: each unlocks by beating a time on one trail in one weather.
func _open_cheats() -> void:
	if _cheats:
		_cheats.queue_free()
	var root := Kit.full_rect(Control.new())
	var dim := Kit.full_rect(ColorRect.new())
	dim.color = Color(0.04, 0.02, 0.07, 0.7)
	root.add_child(dim)
	var center := Kit.full_rect(CenterContainer.new())
	root.add_child(center)
	var panel := PanelContainer.new()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.add_child(Kit.label("CHEATS", 16, UITheme.GOLD))
	for c in Catalog.CHEATS:
		var id := String(c[0])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var info := VBoxContainer.new()
		info.add_theme_constant_override("separation", 1)
		info.custom_minimum_size = Vector2(250, 0)
		info.add_child(Kit.label(String(c[1]), 8, UITheme.CREAM, HORIZONTAL_ALIGNMENT_LEFT))
		var how := "%s" % String(c[2]) if Challenges.cheat_unlocked(id) else "UNLOCK: %s IN THE %s IN UNDER %.1fs" % [
			String(Catalog.level(String(c[3])).name), String(c[4]).to_upper(), float(c[5])]
		var hl := Kit.label(how, 8, UITheme.DIM if Challenges.cheat_unlocked(id) else UITheme.GOLD, HORIZONTAL_ALIGNMENT_LEFT)
		hl.autowrap_mode = TextServer.AUTOWRAP_WORD
		hl.custom_minimum_size = Vector2(250, 0)
		info.add_child(hl)
		row.add_child(info)
		var b: Button
		if Challenges.cheat_unlocked(id):
			b = Kit.button("ON" if Challenges.cheat_on(id) else "OFF", 50, 22)
			b.pressed.connect(func():
				Challenges.set_cheat(id, not Challenges.cheat_on(id))
				_open_cheats())
		else:
			b = Kit.button("LOCKED", 50, 22)
			b.disabled = true
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(b)
		v.add_child(row)
	var done := Kit.button("DONE", 100, 22)
	done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	done.pressed.connect(func():
		_cheats.queue_free()
		_cheats = null)
	v.add_child(done)
	panel.add_child(v)
	center.add_child(panel)
	add_child(root)
	_cheats = root


## Once a day: the login streak's reward (seven days, then round again).
func _streak_popup(day: int) -> void:
	var root := Kit.full_rect(Control.new())
	var dim := Kit.full_rect(ColorRect.new())
	dim.color = Color(0.04, 0.02, 0.07, 0.65)
	root.add_child(dim)
	var center := Kit.full_rect(CenterContainer.new())
	root.add_child(center)
	var panel := PanelContainer.new()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.add_child(Kit.label("DAY %d IN A ROW!" % day if day > 1 else "WELCOME BACK!", 16, UITheme.GOLD))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	var cycle := posmod(day - 1, 7)
	for i in 7:
		var box := PanelContainer.new()
		box.add_theme_stylebox_override("panel", UITheme.box(Color(UITheme.PANEL, 0.96),
			UITheme.GOLD if i == cycle else Color("5a4a6e"), 2 if i == cycle else 1, 3))
		var bv := VBoxContainer.new()
		bv.custom_minimum_size = Vector2(36, 0)
		bv.add_child(Kit.label("DAY %d" % (i + 1), 8, UITheme.GOLD if i == cycle else UITheme.DIM))
		bv.add_child(Kit.label(str(Challenges.streak_coins(i + 1)), 8, UITheme.CREAM if i >= cycle else UITheme.DIM))
		box.add_child(bv)
		row.add_child(box)
	v.add_child(row)
	v.add_child(Kit.label("COME BACK TOMORROW FOR MORE. MISS A DAY AND IT STARTS OVER.", 8, UITheme.DIM))
	var b := Kit.button("TAKE %d COINS" % Challenges.streak_coins(day), 140, 24)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func():
		Challenges.claim_streak()
		AudioDirector.play("bag")
		root.queue_free())
	v.add_child(b)
	panel.add_child(v)
	center.add_child(panel)
	add_child(root)


func _dev_tap() -> void:
	_taps += 1
	if _taps >= 5:
		_taps = 0
		GameState.add_money(500)


func on_back() -> void:
	if _cheats:
		_cheats.queue_free()
		_cheats = null
		return
	if _settings:
		_close_settings()
		return
	if _quit_box:
		_quit_box.queue_free()
		_quit_box = null
		return
	# Android's back button leaves the app; on a PC (Esc, or B on a pad) ask first.
	if GameState.is_desktop():
		_confirm_quit()
	else:
		get_tree().quit()


var _quit_box: Control


func _confirm_quit() -> void:
	if _quit_box:
		return
	var root := Kit.full_rect(Control.new())
	var dim := Kit.full_rect(ColorRect.new())
	dim.color = Color(0.04, 0.02, 0.07, 0.65)
	root.add_child(dim)
	var center := Kit.full_rect(CenterContainer.new())
	root.add_child(center)
	var panel := PanelContainer.new()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.add_child(Kit.label("QUIT TRESTLE RUN?", 16, UITheme.GOLD))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var stay := Kit.button("KEEP RIDING", 110, 26)
	stay.pressed.connect(func():
		root.queue_free()
		_quit_box = null)
	var go := Kit.button("QUIT", 110, 26)
	go.pressed.connect(func(): get_tree().quit())
	row.add_child(stay)
	row.add_child(go)
	v.add_child(row)
	panel.add_child(v)
	center.add_child(panel)
	add_child(root)
	_quit_box = root
