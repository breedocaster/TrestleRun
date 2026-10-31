## Hosts one SUMMIT or GAUNTLET ride: the world, its HUD, the pause panel and the
## results. arg = "<mode>:<level index>", or "event" for this week's event (events.gd).
extends Node

signal navigate(target: String, arg: String)

const World := preload("res://scripts/drive/drive_world.gd")
const Hud := preload("res://scripts/drive/drive_hud.gd")
const Summit := preload("res://scripts/drive/summit_levels.gd")
const Gauntlet := preload("res://scripts/drive/gauntlet_levels.gd")
const Progress := preload("res://scripts/drive/drive_progress.gd")
const Kit := preload("res://scripts/ui/kit.gd")
const UITheme := preload("res://scripts/ui/ui_theme.gd")
const Widgets := preload("res://scripts/ui/widgets.gd")
const Objectives := preload("res://scripts/drive/objectives.gd")
const Events := preload("res://scripts/drive/events.gd")

## How the air tricks go (tricks.gd), on the pause panel.
const TRICK_HELP := "TRICKS: TAP TWICE IN THE AIR. BRAKE+GAS WHIP, GAS+GAS NO-HANDER, GAS+BRAKE HEEL CLICKER, BRAKE+BRAKE SUPERMAN. FINISH BEFORE YOU LAND. CHAIN THEM WITH FLIPS FOR A COMBO."

var mode := "summit"
var index := 0
var ev: Dictionary = {}     # the event being ridden (mode "event")
var world: Node2D
var hud: Control
var _layer: CanvasLayer
var _overlay: Control


func setup(arg: String) -> void:
	var p := arg.split(":")
	mode = p[0] if p.size() > 0 and p[0] != "" else "summit"
	index = int(p[1]) if p.size() > 1 else 0
	if mode == "event":
		ev = Events.current()


func _ready() -> void:
	var lv: Dictionary
	world = World.new()
	var rig := GameState.loadout()
	if mode == "event":
		# Events are ridden on stock bikes, so the tiers mean the same for everyone.
		lv = Events.build(ev)
		world.setup(Events.physics(ev), lv, rig, {})
		world.objectives = [String(Events.KINDS[ev.kind].how)]
	else:
		lv = Summit.build(index) if mode == "summit" else Gauntlet.build(index)
		world.setup(mode, lv, rig, Progress.upgrades(String(rig.bike)))
		world.ghost = Progress.ghost_for(String(lv.id))
		var done: Array = Progress.record(String(lv.id)).obj
		var ol := Objectives.of(String(lv.id))
		for k in mini(ol.size(), 3):
			if not bool(done[k]):
				world.objectives.append("* " + Objectives.text(ol[k], world.electric))
	add_child(world)
	world.done.connect(_on_done)
	var hl := CanvasLayer.new()
	hl.layer = 5
	add_child(hl)
	hud = Hud.new()
	hud.world = world
	hud.pause_pressed.connect(pause)
	hl.add_child(hud)
	_layer = CanvasLayer.new()
	_layer.layer = 10
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_layer)
	AudioDirector.set_context("ride")


func _exit_tree() -> void:
	get_tree().paused = false
	AudioDirector.engine_stop(0.3)


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("pause"):
		if _overlay and get_tree().paused:
			resume()
		elif _overlay == null and world.phase != "done":
			pause()
		get_viewport().set_input_as_handled()


## Switching away (another app, a call, the window losing focus) pauses the ride.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_inside_tree() and is_riding():
			pause()


func is_riding() -> bool:
	return _overlay == null and world != null and world.phase != "done"


func pause() -> void:
	if _overlay:
		return
	hud.release_all()
	get_tree().paused = true
	var v := _panel("PAUSED")
	if mode == "event":
		v.add_child(Kit.label("%s: %s" % [String(ev.name), String(Events.KINDS[ev.kind].name)], 8, UITheme.DIM))
		var how := Kit.label(String(Events.KINDS[ev.kind].how), 8, UITheme.CREAM)
		how.autowrap_mode = TextServer.AUTOWRAP_WORD
		how.custom_minimum_size = Vector2(300, 0)
		v.add_child(how)
	else:
		var meta: Dictionary = Progress.levels(mode)[index]
		v.add_child(Kit.label(String(meta.name), 8, UITheme.DIM))
		_objective_rows(v, Progress.record(String(meta.id)).obj, [false, false, false])
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var res := Kit.button("RESUME", 80, 26)
	res.pressed.connect(resume)
	var again := Kit.button("RESTART", 80, 26)
	again.pressed.connect(func(): navigate.emit("drive", _again_arg()))
	var out := Kit.button("EVENTS" if mode == "event" else "LEVELS", 80, 26)
	out.pressed.connect(_leave)
	row.add_child(res)
	row.add_child(again)
	row.add_child(out)
	v.add_child(row)
	v.add_child(Widgets.flag_button("SWAP LEAN", "lean_swap", 160, func(on): world.lean_swap = on, false))
	v.add_child(Widgets.flag_button("AIR TRICKS", "tricks", 160, func(on): world.tricks.enabled = on, true))
	var how := Kit.label(TRICK_HELP, 8, UITheme.DIM)
	how.autowrap_mode = TextServer.AUTOWRAP_WORD
	how.custom_minimum_size = Vector2(300, 0)
	v.add_child(how)


func _again_arg() -> String:
	return "event" if mode == "event" else "%s:%d" % [mode, index]


func _leave() -> void:
	if mode == "event":
		navigate.emit("challenges", "")
	else:
		navigate.emit("drive_select", mode)


func resume() -> void:
	if _overlay:
		_overlay.queue_free()
		_overlay = null
	get_tree().paused = false


## A dimmed full-screen panel; returns its VBox.
func _panel(title: String) -> VBoxContainer:
	var root := Kit.full_rect(Control.new())
	root.theme = GameState.theme
	var dim := Kit.full_rect(ColorRect.new())
	dim.color = Color(0.04, 0.02, 0.07, 0.6)
	root.add_child(dim)
	var center := Kit.full_rect(CenterContainer.new())
	root.add_child(center)
	var panel := PanelContainer.new()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.add_child(Kit.label(title, 16, UITheme.GOLD))
	panel.add_child(v)
	center.add_child(panel)
	_layer.add_child(root)
	_overlay = root
	return v


func _on_done(r: Dictionary) -> void:
	hud.release_all()
	if int(r.get("tricks", 0)) > 0:
		Challenges.on_stat("air_tricks", int(r.tricks))
	if mode == "event":
		Challenges.on_stat("event_ride")
		var ep := Events.record_result(ev, r)
		await get_tree().create_timer(0.7).timeout
		if is_inside_tree():
			_event_results(r, ep)
		return
	var paid: Dictionary = Progress.record_result(r, index)
	Progress.keep_ghost(r, paid, world.rig)
	await get_tree().create_timer(0.7).timeout
	if not is_inside_tree():
		return
	_results(r, paid)


func _event_results(r: Dictionary, ep: Dictionary) -> void:
	var sc = ep.score
	var title := "WIPEOUT!" if sc == null else ("NEW BEST!" if bool(ep.new_best) else "NICE!")
	var v := _panel(title)
	v.add_child(Kit.label("%s: %s" % [String(ev.name), String(Events.KINDS[ev.kind].name)], 8, UITheme.DIM))
	var rec := Events.record(ev)
	var t := Events.tiers(ev)
	var have := [false, false, false]
	var fresh := [false, false, false]
	var tier := Events.tier_of(ev, float(rec.best)) if rec.best != null else 0
	for k in 3:
		have[k] = k < tier
		fresh[k] = k < tier and k >= tier - int(ep.new_tiers)
	var mr := Widgets.MedalRow.new(have, fresh)
	mr.names = t.map(func(x): return Events.fmt(ev, float(x))) if t.size() == 3 else ["BRONZE", "SILVER", "GOLD"]
	v.add_child(mr)
	var lines := []
	lines.append(["THIS RIDE", Events.fmt(ev, float(sc)) if sc != null else ("NO JUMP" if ev.kind == "long_jump" else "DIDN'T FINISH")])
	if rec.best != null:
		lines.append(["BEST", Events.fmt(ev, float(rec.best))])
	if int(ep.coins) > 0:
		lines.append(["TIER REWARD", "+%d" % int(ep.coins)])
	lines.append(["ENDS IN", "%d DAY%s" % [int(ev.days_left), "" if int(ev.days_left) == 1 else "S"]])
	lines.append(["WALLET", str(GameState.money())])
	for ln in lines:
		var h := HBoxContainer.new()
		var a := Kit.label(String(ln[0]), 8, UITheme.DIM, HORIZONTAL_ALIGNMENT_LEFT)
		a.custom_minimum_size = Vector2(110, 0)
		h.add_child(a)
		h.add_child(Kit.label(String(ln[1]), 8, UITheme.CREAM, HORIZONTAL_ALIGNMENT_RIGHT))
		v.add_child(h)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var again := Kit.button("RETRY", 76, 26)
	again.pressed.connect(func(): navigate.emit("drive", "event"))
	row.add_child(again)
	var out := Kit.button("EVENTS", 76, 26)
	out.pressed.connect(_leave)
	row.add_child(out)
	v.add_child(row)
	if int(ep.new_tiers) > 0:
		AudioDirector.play("finish")


func _results(r: Dictionary, paid: Dictionary) -> void:
	var ok := bool(r.ok)
	var title := ""
	if mode == "summit":
		title = "SUMMIT!" if ok else ("OUT OF CHARGE" if r.reason == "fuel" and world.electric else
			("OUT OF FUEL" if r.reason == "fuel" else "WIPEOUT!"))
	else:
		title = "CLEAR!" if ok else "WIPEOUT!"
	var v := _panel(title)
	var meta: Dictionary = Progress.levels(mode)[index]
	v.add_child(Kit.label(String(meta.name), 8, UITheme.DIM))
	var medal_row := Widgets.MedalRow.new(paid.medals, paid.new_medals)
	medal_row.names = ["FINISH", "SILVER TIME", "GOLD TIME"] if mode == "summit" else ["FINISH", "SILVER", "GOLD, NO FAULTS"]
	v.add_child(medal_row)
	var lines := []
	if mode == "summit":
		lines.append(["DISTANCE", "%d / %d M" % [int(r.distance_m), int(r.length_m)]])
		lines.append(["COINS", "+%d" % int(r.coins)])
	else:
		lines.append(["FAULTS", str(r.faults)])
	if int(r.tricks) > 0 or int(r.flips) > 0:
		var tl := "%d" % int(r.tricks)
		if int(r.flips) > 0:
			tl += " + %d FLIP%s" % [int(r.flips), "" if int(r.flips) == 1 else "S"]
		if int(r.best_combo) > 1:
			tl += ", COMBO X%d" % int(r.best_combo)
		lines.append(["TRICKS", tl])
	if mode == "gauntlet" and int(r.trick_pts) > 0:
		lines.append(["TRICK POINTS", str(r.trick_pts)])
	if ok:
		var pars: Array = Progress.pars(mode, index)
		lines.append(["TIME", "%.2fs%s" % [float(r.time), "  NEW BEST!" if paid.new_best else ""]])
		lines.append(["GOLD / SILVER", "%.0fs / %.0fs" % [float(pars[0]), float(pars[1])]])
	_objective_rows(v, paid.obj, paid.new_obj)
	var extra := int(paid.pay) - (int(r.coins) if mode == "summit" else 0)
	if extra > 0:
		lines.append(["BONUS", "+%d" % extra])
	lines.append(["WALLET", str(GameState.money())])
	for ln in lines:
		var h := HBoxContainer.new()
		var a := Kit.label(String(ln[0]), 8, UITheme.DIM, HORIZONTAL_ALIGNMENT_LEFT)
		a.custom_minimum_size = Vector2(110, 0)
		h.add_child(a)
		h.add_child(Kit.label(String(ln[1]), 8, UITheme.CREAM, HORIZONTAL_ALIGNMENT_RIGHT))
		v.add_child(h)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var again := Kit.button("RETRY", 76, 26)
	again.pressed.connect(func(): navigate.emit("drive", "%s:%d" % [mode, index]))
	row.add_child(again)
	if mode == "summit":
		var upg := Kit.button("UPGRADES", 86, 26)
		upg.pressed.connect(func(): navigate.emit("drive_select", "summit:upgrades"))
		row.add_child(upg)
	if ok and index + 1 < Progress.levels(mode).size():
		var nxt := Kit.button("NEXT >", 76, 26)
		nxt.pressed.connect(func(): navigate.emit("drive", "%s:%d" % [mode, index + 1]))
		row.add_child(nxt)
	var out := Kit.button("LEVELS", 76, 26)
	out.pressed.connect(func(): navigate.emit("drive_select", mode))
	row.add_child(out)
	v.add_child(row)


## The level's three objectives, a star and a line each (done ones in green, new ones
## in gold with what they paid).
func _objective_rows(v: VBoxContainer, done: Array, fresh: Array) -> void:
	var list := Objectives.of(String(Progress.levels(mode)[index].id))
	for k in mini(list.size(), 3):
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 4)
		var flags := [bool(done[k])]
		h.add_child(Widgets.StarRow.new(flags, [bool(fresh[k])], 1))
		var c := UITheme.GOLD if bool(fresh[k]) else (UITheme.GREEN if bool(done[k]) else UITheme.CREAM)
		var t := Objectives.text(list[k], world.electric)
		if bool(fresh[k]):
			t += "  +%d" % int(Objectives.PAY[k])
		h.add_child(Kit.label(t, 8, c, HORIZONTAL_ALIGNMENT_LEFT))
		v.add_child(h)


func on_back() -> void:
	if _overlay and get_tree().paused:
		resume()
	elif _overlay:
		_leave()
	else:
		pause()
