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
const BossArt := preload("res://scripts/game/boss_art.gd")
const Endless := preload("res://scripts/game/endless.gd")
const MODES := ["endless", "daily", "league"]

var level_id := ""
## "endless", "daily" or "league" (built courses, see endless.gd), or "" for a trail.
var mode := ""
var _course: Dictionary = {}
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

	mode = level_id if level_id in MODES else ""
	var cond: Dictionary
	world = World.new()
	var look_id := level_id  # whose sound beds and scenery details to use
	if mode != "":
		_course = _build_course()
		cond = _course.cond
		world.setup(level_id, GameState.loadout(), [], cond, _course.level)
		world.mode = mode
		world.one_life = mode != "daily"
		world.hints = mode == "daily" and GameState.flag("hints")
		look_id = Catalog.theme_level(int(_course.level.theme))
		if GameState.flag("ghost") and _course.ghost_id != "":
			world.ghost = GameState.load_ghost(String(_course.ghost_id))
	else:
		var meta0 := Catalog.level(level_id)
		# Story trails always ride in their own time and weather.
		cond = (meta0.cond as Dictionary).duplicate() if meta0.has("cond") else GameState.conditions().duplicate()
		world.setup(level_id, GameState.loadout(), GameState.level_record(level_id).gears, cond)
		world.hints = GameState.flag("hints")
		GameState.set_last_level(level_id)
		if GameState.flag("ghost"):
			world.ghost = GameState.load_ghost(level_id)
	world.shake_on = GameState.flag("shake")
	world.cheat_rainbow = Challenges.cheat_on("rainbow")
	world.cheat_paint = Challenges.cheat_on("paintball")
	world.run_finished.connect(_on_finished)
	add_child(world)
	backdrop.theme_index = world.level.theme
	backdrop.time_mode = String(cond.time)
	backdrop.weather = String(cond.weather)
	AudioDirector.set_context("game")
	var track := String(Catalog.MUSIC_BY_THEME[int(world.level.theme)]) if mode != "" \
		else String(Catalog.level(level_id).get("music", "trestle_dreams"))
	AudioDirector.set_track(track)
	AudioDirector.set_ambience(String(cond.time), String(cond.weather), look_id)
	AudioDirector.engine_start(GameState.equipped("bike"))

	depth = Depth.new()
	depth.theme_index = world.level.theme
	depth.time_mode = String(cond.time)
	depth.weather = String(cond.weather)
	depth.level_id = look_id
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
	hud.pause_pressed.connect(pause)
	hud.hint_pressed.connect(show_hint)
	if mode == "":
		hud.show_hint = (Catalog.level_index(level_id) == 0 or level_id == String(Catalog.story_levels()[0].id)) \
			and not GameState.level_record(level_id).cleared
		var meta := Catalog.level(level_id)
		hud.feature = Catalog.feature_names(meta)
		hud.feature_new = not GameState.level_record(level_id).cleared
	else:
		hud.no_help = true
		if mode == "endless":
			hud.best_m = Challenges.endless_best()
		elif mode == "league":
			hud.best_m = int(Challenges.data().league.get("best_m", 0))
			var riv := []
			for r in Challenges.standings():
				if not bool(r.you):
					riv.append([String(r.name), int(r.m)])
			riv.sort_custom(func(a, b): return int(a[1]) < int(b[1]))
			hud.rivals = riv
	hud.ability_title = String(Catalog.ability_text(GameState.equipped("bike"))[0])
	hl.add_child(hud)
	hud.theme = GameState.theme

	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = 10
	_overlay_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_overlay_layer)


## Endless, the daily ride or the league line: {"level", "cond", "ghost_id", ...}.
func _build_course() -> Dictionary:
	var theme := Challenges.season_theme()
	var plan: Array
	var cond := {"time": "day", "weather": "clear"}
	var name := "ENDLESS"
	var ghost_id := ""
	var opts := {}
	match mode:
		"endless":
			var h := int(Time.get_time_dict_from_system().hour)
			cond.time = "day" if h >= 6 and h < 17 else ("dusk" if h >= 17 and h < 20 else "night")
			plan = Endless.endless_plan(randi())
		"league":
			Challenges.roll_week()
			var c := Challenges.league_course()
			plan = c.plan
			cond.time = String(c.time)
			theme = int(c.theme)
			name = "WEEKLY LEAGUE"
			ghost_id = "league_%d" % int(c.week)
		"daily":
			var d := Challenges.daily()
			plan = d.plan
			cond = {"time": String(d.time), "weather": String(d.weather)}
			theme = int(d.theme)
			name = String(d.name)
			ghost_id = "daily_%d" % int(d.day)
			opts = {"checkpoints": true, "letters": true}
	var meta := {"id": mode, "name": name, "theme": theme, "speed": Endless.TIERS[0]}
	var lv := Endless.build(plan, meta, opts)
	if mode == "daily":
		lv.par = Endless.par(plan, lv, String(cond.weather))
	return {"level": lv, "cond": cond, "ghost_id": ghost_id, "plan": plan}


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
	if _overlay != null or world.phase == "done" or world.phase == "over":
		return
	get_tree().paused = true
	var col := VBoxContainer.new()
	col.add_child(Kit.label("PAUSED", 16, UITheme.GOLD))
	col.add_child(Kit.label(world.level.name, 8, UITheme.DIM))
	var r := Kit.button("RESUME", 150)
	r.pressed.connect(resume)
	var rs := Kit.button("RESTART", 150)
	rs.pressed.connect(func(): _go("game", level_id))
	var q := Kit.button("QUIT" if mode != "" else ("QUIT TO MAP" if Catalog.is_story(level_id) else "QUIT TO TRAILS"), 150)
	q.pressed.connect(func(): _go(_menu_target(), ""))
	for b in [r, rs, q]:
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(b)
	col.add_child(Widgets.flag_button("CRASH HINTS", "hints", 150, func(on: bool):
		world.hints = on
		if not on:
			world.guide_on = false))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 2)
	col.add_child(gap)
	col.add_child(Widgets.audio_sliders(false))
	_show_overlay(col)


## The trail's new feature explained, with a live demo. Pauses the run.
func show_hint() -> void:
	if _overlay != null or world.phase == "done" or mode != "":
		return
	get_tree().paused = true
	var card := HintCard.new(level_id)
	card.closed.connect(resume)
	_show_overlay(card, false)


func resume() -> void:
	_clear_overlay()
	get_tree().paused = false


func _menu_target() -> String:
	if mode != "":
		return "challenges"
	return "story" if Catalog.is_story(level_id) else "levels"


func _on_finished(r: Dictionary) -> void:
	if mode != "":
		_mode_finished(r)
		return
	var pay := GameState.record_result(r)
	var extra := Challenges.on_run(r, "")
	Achievements.on_run(r, pay)
	if (pay.new_best or pay.first_clear) and r.has("ghost") and (r.ghost as PackedFloat32Array).size() > 0:
		GameState.save_ghost(level_id, r.get("rig", {}), r.ghost, float(r.get("time", 0.0)))
	if pay.has("new_part"):
		_part_recovered(r, pay)
		return
	var meta := Catalog.level(level_id)
	var is_boss: bool = meta.get("boss", false)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	col.add_child(Kit.label("BOSS BEATEN!" if is_boss else "TRAIL CLEAR!", 16, UITheme.GOLD))
	if not is_boss:
		col.add_child(Widgets.GearRow.new(GameState.level_record(level_id).gears))
	var tc := int(r.get("trick_coins", 0))
	var lb := int(r.get("letter_bonus", 0))
	var rows := [
		["COINS", pay.coins - tc - lb],
		["TRICKS x%d" % int(r.get("tricks", 0)), tc],
		["T-R-E-S-T-L-E", lb],
		["CONDITIONS +%d%%" % pay.cond_pct, pay.cond_pay],
		["NEW GEARS x%d" % pay.new_gears, pay.gear_pay],
		["CLEAR BONUS", pay.bonus],
		["NO-CRASH BONUS", pay.perfect],
	]
	if pay.cond_pct == 0:
		rows.remove_at(3)
	if lb == 0:
		rows.remove_at(2)
	if tc == 0:
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
	for ln in extra:
		if String(ln[0]).ends_with("SEASON XP"):
			extras.append(String(ln[0]).replace(" SEASON", ""))
	col.add_child(Kit.label("   ".join(extras), 8, UITheme.DIM))
	for ln in extra:
		if String(ln[0]).begins_with("CHEAT"):
			col.add_child(Kit.label(String(ln[0]), 8, ln[1]))
	col.add_child(Widgets.MedalRow.new(pay.medals, pay.new_medals, float(pay.par), int(r.get("letters", 0)), false, is_boss))

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	var retry := Kit.button("RETRY", 70)
	retry.pressed.connect(func(): _go("game", level_id))
	var trails := Kit.button("MAP" if Catalog.is_story(level_id) else "TRAILS", 70)
	trails.pressed.connect(func(): _go(_menu_target(), ""))
	buttons.add_child(retry)
	buttons.add_child(trails)
	var nxt := GameState.next_level_id(level_id)
	if nxt != "" and GameState.level_unlocked(nxt):
		var nb := Kit.button("NEXT >", 70)
		nb.pressed.connect(func(): _go("game", nxt))
		buttons.add_child(nb)
	col.add_child(buttons)
	_show_overlay(col)


## Endless, league or daily ride over: distance (or time), coins, what it counted for.
func _mode_finished(r: Dictionary) -> void:
	var coins := int(r.coins)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	var rows := []
	var title := ""
	var paid_elsewhere := 0  # the daily bonus is paid by Challenges.on_run
	if mode == "daily":
		title = "DAILY RIDE CLEAR!"
		var pct := Catalog.condition_bonus(r.conditions)
		rows = [["COINS", coins], ["CONDITIONS +%d%%" % pct, int(round(coins * pct / 100.0))]]
		if pct == 0:
			rows.remove_at(1)
		if not bool(Challenges.daily_record().cleared):
			rows.append(["TODAY'S FIRST CLEAR", Challenges.DAILY_COINS])
			paid_elsewhere = Challenges.DAILY_COINS
	else:
		title = "END OF THE LINE!" if bool(r.finished) else "WIPEOUT!"
		rows = [["COINS", coins], ["DISTANCE BONUS", int(r.metres) / 10]]
	var total := 0
	for row in rows:
		total += int(row[1])
	GameState.add_money(total - paid_elsewhere)
	var prev_best := Challenges.endless_best() if mode == "endless" else int(Challenges.data().league.get("best_m", 0))
	var lines := Challenges.on_run(r, mode)
	Achievements.on_wallet()
	if mode != "endless" and r.has("ghost") and (r.ghost as PackedFloat32Array).size() > 0:
		var better := false
		if mode == "league":
			better = int(r.metres) > prev_best
		else:
			var dr := Challenges.daily_record()
			better = float(r.time) <= float(dr.best) + 0.001
		if better:
			GameState.save_ghost(String(_course.ghost_id), r.get("rig", {}), r.ghost, float(r.get("time", 0.0)))
	col.add_child(Kit.label(title, 16, UITheme.GOLD))
	if mode != "daily":
		col.add_child(Kit.label("%d M" % int(r.metres), 16, UITheme.CREAM))
		var best := Challenges.endless_best() if mode == "endless" else int(Challenges.data().league.get("best_m", 0))
		col.add_child(Kit.label(("BEST %d M" % best) if int(r.metres) < best or best == 0 else "", 8, UITheme.DIM))
	for row in rows:
		col.add_child(_row(row[0], "+%d" % row[1], UITheme.CREAM if row[1] > 0 else UITheme.DIM))
	var line := ColorRect.new()
	line.color = Color("5a4a6e")
	line.custom_minimum_size = Vector2(0, 1)
	col.add_child(line)
	col.add_child(_row("TOTAL", "+%d" % total, UITheme.GOLD))
	col.add_child(_row("WALLET", str(GameState.money()), UITheme.DIM))
	if mode == "daily":
		var par := float(r.get("par", 0.0))
		col.add_child(Kit.label("TIME %.1fs   PAR %.1fs   CRASHES %d" % [float(r.time), par, int(r.crashes)], 8, UITheme.DIM))
	elif mode == "league":
		var rank := Challenges.league_rank()
		col.add_child(Kit.label("%s DIVISION: %s OF %d" % [Challenges.DIVISIONS[Challenges.division()],
			_ordinal(rank), Challenges.GROUP], 8, UITheme.GOLD if rank <= Challenges.PROMOTE else UITheme.CREAM))
	for ln in lines:
		col.add_child(Kit.label(String(ln[0]), 8, ln[1]))
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	var again := Kit.button("RIDE AGAIN" if mode != "daily" else "RETRY", 90)
	again.pressed.connect(func(): _go("game", level_id))
	buttons.add_child(again)
	var hub := Kit.button("CHALLENGES", 90)
	hub.pressed.connect(func(): _go("challenges", mode))
	buttons.add_child(hub)
	col.add_child(buttons)
	_show_overlay(col)


static func _ordinal(n: int) -> String:
	var suf := "TH"
	if n % 100 < 11 or n % 100 > 13:
		suf = ["TH", "ST", "ND", "RD", "TH", "TH", "TH", "TH", "TH", "TH"][n % 10]
	return "%d%s" % [n, suf]


## A boss went down: its part of Grandpa's bike comes home.
func _part_recovered(r: Dictionary, pay: Dictionary) -> void:
	var part := String(pay.new_part)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	var meta := Catalog.level(level_id)
	col.add_child(Kit.label("%s IS DOWN!" % String(meta.name), 8, UITheme.DIM))
	col.add_child(Kit.label("%s RECOVERED!" % BossArt.part_name(part), 16, UITheme.GOLD))
	var parts := GameState.story_parts()
	var bike := Widgets.GrandpaBikeView.new(parts, 1.6, part)
	bike.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(bike)
	col.add_child(Kit.label("GRANDPA'S BIKE: %d/%d PARTS" % [parts.size(), Catalog.PARTS.size()], 8, UITheme.CREAM))
	var nxt := GameState.next_level_id(level_id)
	var msg := ""
	if nxt != "":
		msg = "%s IS OPEN!" % String(Catalog.STORY_AREAS[int(Catalog.level(nxt).story)].name)
	else:
		msg = "MORE OF THE COUNTY IS COMING SOON."
	col.add_child(Kit.label(msg, 8, UITheme.GOLD if nxt != "" else UITheme.DIM))
	col.add_child(_row("TOTAL", "+%d" % pay.total, UITheme.GOLD))
	col.add_child(Widgets.MedalRow.new(pay.medals, pay.new_medals, float(pay.par), 0, false, true))
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	var mapb := Kit.button("MAP", 70)
	mapb.pressed.connect(func(): _go("story", ""))
	buttons.add_child(mapb)
	if nxt != "":
		var nb := Kit.button("NEXT >", 70)
		nb.pressed.connect(func(): _go("game", nxt))
		buttons.add_child(nb)
	col.add_child(buttons)
	AudioDirector.play("part_get")
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
