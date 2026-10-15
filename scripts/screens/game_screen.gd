## Hosts one run: backdrop, world, HUD, pause and results overlays.
extends Node

signal navigate(target: String, arg: String)

const World := preload("res://scripts/game/world.gd")
const Backdrop := preload("res://scripts/game/backdrop.gd")
const Hud := preload("res://scripts/ui/hud.gd")
const Kit := preload("res://scripts/ui/kit.gd")
const UITheme := preload("res://scripts/ui/ui_theme.gd")
const Widgets := preload("res://scripts/ui/widgets.gd")
const Catalog := preload("res://scripts/catalog.gd")
const WeatherFX := preload("res://scripts/game/weather_fx.gd")
const Phys := preload("res://scripts/game/bike_physics.gd")
const Depth := preload("res://scripts/game/depth.gd")
const HintCard := preload("res://scripts/ui/hint_card.gd")

var level_id := ""
var world: Node2D
var backdrop: Node2D
var depth: Node
var hud: Control
var _overlay_layer: CanvasLayer
var _overlay: Control


func setup(id: String) -> void:
	level_id = id


func _ready() -> void:
	var bg := CanvasLayer.new()
	bg.layer = -10
	add_child(bg)
	backdrop = Backdrop.new()
	bg.add_child(backdrop)

	var cond: Dictionary = GameState.conditions().duplicate()
	world = World.new()
	world.setup(level_id, GameState.loadout(), GameState.level_record(level_id).gears, cond)
	world.run_finished.connect(_on_finished)
	add_child(world)
	backdrop.theme_index = world.level.theme
	backdrop.time_mode = String(cond.time)
	backdrop.weather = String(cond.weather)
	AudioDirector.set_context("game")
	AudioDirector.set_ambience(String(cond.time), String(cond.weather), level_id)
	AudioDirector.engine_start(GameState.equipped("bike"))

	depth = Depth.new()
	depth.theme_index = world.level.theme
	depth.time_mode = String(cond.time)
	depth.weather = String(cond.weather)
	depth.level_id = level_id
	add_child(depth)
	depth.attach(self, backdrop)

	var fl := CanvasLayer.new()
	fl.layer = 2
	add_child(fl)
	var fx := WeatherFX.new()
	fx.world = world
	fx.weather = String(cond.weather)
	fx.time_mode = String(cond.time)
	fl.add_child(fx)

	var hl := CanvasLayer.new()
	hl.layer = 5
	add_child(hl)
	hud = Hud.new()
	hud.world = world
	hud.show_hint = Catalog.level_index(level_id) == 0 and not GameState.level_record(level_id).cleared
	hud.pause_pressed.connect(pause)
	hud.hint_pressed.connect(show_hint)
	var meta := Catalog.level(level_id)
	hud.feature = String((Catalog.FEATURES.get(String(meta.get("feature", "")), [""]) as Array)[0])
	hud.feature_new = not GameState.level_record(level_id).cleared
	hud.ability_title = String(Catalog.ability_text(GameState.equipped("bike"))[0])
	hl.add_child(hud)
	hud.theme = GameState.theme

	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = 10
	_overlay_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_overlay_layer)


func _process(_delta: float) -> void:
	if world.cam:
		backdrop.cam = world.cam.position
	if world.cam:
		depth.cam = world.cam.position
	depth.speed = float(world.state.vx) if world.phase == "ride" or world.phase == "done" else 0.0
	if world.level.get("wind", 0.0) > 0.0:
		var gust: float = Phys.wind_at(world.level, world.state.t) / Phys.WIND_PEAK
		depth.gust = gust
		AudioDirector.wind_gust(gust)


func _exit_tree() -> void:
	AudioDirector.engine_stop(0.4)
	AudioDirector.clear_ambience()
	AudioDirector.set_context("menu")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if _overlay == null:
			pause()
		elif get_tree().paused:
			resume()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if world and world.phase == "ride" and _overlay == null:
			pause()


func on_back() -> void:
	if _overlay == null:
		pause()
	elif get_tree().paused:
		resume()


func pause() -> void:
	if _overlay != null or world.phase == "done":
		return
	get_tree().paused = true
	var col := VBoxContainer.new()
	col.add_child(Kit.label("PAUSED", 16, UITheme.GOLD))
	col.add_child(Kit.label(world.level.name, 8, UITheme.DIM))
	var r := Kit.button("RESUME", 150)
	r.pressed.connect(resume)
	var rs := Kit.button("RESTART", 150)
	rs.pressed.connect(func(): _go("game", level_id))
	var q := Kit.button("QUIT TO TRAILS", 150)
	q.pressed.connect(func(): _go("levels", ""))
	for b in [r, rs, q]:
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(b)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 2)
	col.add_child(gap)
	col.add_child(Widgets.audio_sliders())
	_show_overlay(col)


## The trail's new feature explained, with a live demo. Pauses the run.
func show_hint() -> void:
	if _overlay != null or world.phase == "done":
		return
	get_tree().paused = true
	var card := HintCard.new(level_id)
	card.closed.connect(resume)
	_show_overlay(card, false)


func resume() -> void:
	_clear_overlay()
	get_tree().paused = false


func _on_finished(r: Dictionary) -> void:
	var pay := GameState.record_result(r)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	col.add_child(Kit.label("TRAIL CLEAR!", 16, UITheme.GOLD))
	col.add_child(Widgets.GearRow.new(GameState.level_record(level_id).gears))
	var rows := [
		["COINS", pay.coins],
		["CONDITIONS +%d%%" % pay.cond_pct, pay.cond_pay],
		["NEW GEARS x%d" % pay.new_gears, pay.gear_pay],
		["CLEAR BONUS", pay.bonus],
		["NO-CRASH BONUS", pay.perfect],
	]
	if pay.cond_pct == 0:
		rows.remove_at(1)
	for row in rows:
		col.add_child(_row(row[0], "+%d" % row[1], UITheme.CREAM if row[1] > 0 else UITheme.DIM))
	var line := ColorRect.new()
	line.color = Color("5a4a6e")
	line.custom_minimum_size = Vector2(0, 1)
	col.add_child(line)
	col.add_child(_row("TOTAL", "+%d" % pay.total, UITheme.GOLD))
	col.add_child(_row("WALLET", str(GameState.money()), UITheme.DIM))
	var extras := []
	var best := float(GameState.level_record(level_id).get("best_time", 0.0))
	var tag := ""
	if pay.get("new_best", false):
		tag = "  NEW BEST!"
	elif not pay.get("first_clear", false) and best > 0.0:
		tag = "  BEST %.1fs" % best
	extras.append("TIME %.1fs%s" % [float(r.get("time", 0.0)), tag])
	if int(r.get("planes_seen", 0)) > 0:
		extras.append("BONUS PLANES %d/%d" % [int(r.get("planes", 0)), int(r.get("planes_seen", 0))])
	if r.crashes > 0:
		extras.append("CRASHES %d" % r.crashes)
	col.add_child(Kit.label("   ".join(extras), 8, UITheme.DIM))

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	var retry := Kit.button("RETRY", 70)
	retry.pressed.connect(func(): _go("game", level_id))
	var trails := Kit.button("TRAILS", 70)
	trails.pressed.connect(func(): _go("levels", ""))
	buttons.add_child(retry)
	buttons.add_child(trails)
	var nxt := GameState.next_level_id(level_id)
	if nxt != "" and GameState.level_unlocked(nxt):
		var nb := Kit.button("NEXT >", 70)
		nb.pressed.connect(func(): _go("game", nxt))
		buttons.add_child(nb)
	col.add_child(buttons)
	_show_overlay(col)


func _row(left: String, right: String, c: Color) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.custom_minimum_size = Vector2(190, 12)
	h.add_child(Kit.label(left, 8, c, HORIZONTAL_ALIGNMENT_LEFT))
	h.add_child(Kit.spacer())
	h.add_child(Kit.label(right, 8, c, HORIZONTAL_ALIGNMENT_RIGHT))
	return h


func _show_overlay(content: Control, wrap := true) -> void:
	_clear_overlay()
	var root := Kit.full_rect(Control.new())
	root.theme = GameState.theme
	var dim := Kit.full_rect(ColorRect.new())
	dim.color = Color(0.04, 0.02, 0.07, 0.6)
	root.add_child(dim)
	var center := Kit.full_rect(CenterContainer.new())
	root.add_child(center)
	if wrap:
		var panel := PanelContainer.new()
		panel.add_child(content)
		center.add_child(panel)
	else:
		center.add_child(content)
	_overlay_layer.add_child(root)
	_overlay = root


func _clear_overlay() -> void:
	if _overlay:
		_overlay.queue_free()
		_overlay = null


func _go(target: String, arg: String) -> void:
	get_tree().paused = false
	navigate.emit(target, arg)
