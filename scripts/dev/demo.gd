## Scripted demo for Movie Maker capture (audio + video):
##   --demo=ride:<level>:<time>:<weather>:<rider>:<bike>:<paint>:<seconds>
##   --demo=garage   (equips each bike in turn so every engine blips)
extends Node

const Bot := preload("res://scripts/game/autopilot.gd")
const Catalog := preload("res://scripts/catalog.gd")
const Phys := preload("res://scripts/game/bike_physics.gd")
const Kit := preload("res://scripts/ui/kit.gd")
const UITheme := preload("res://scripts/ui/ui_theme.gd")

## Tour of the new features for a showcase capture: [level, start x, seconds, bike,
## time, weather, caption, extra]
## Purpose-built stretches for showing off specialties.
const STAGES := {
	"wheelie": [["start", 160.0], ["gap", 34.0], ["flat", 900.0, 0], ["finish"]],
	"glide": [["start", 160.0], ["gap", 96.0], ["flat", 120.0, 0], ["gap", 110.0], ["flat", 120.0, 0], ["gap", 104.0], ["flat", 300.0], ["finish"]],
	"hop": [["start", 160.0], ["gap", 66.0], ["flat", 240.0, 0], ["gap", 70.0], ["flat", 240.0, 0], ["gap", 72.0], ["flat", 300.0], ["finish"]],
	"dash": [["start", 160.0], ["gap", 66.0], ["flat", 240.0, 0], ["gap", 70.0], ["flat", 240.0, 0], ["gap", 72.0], ["flat", 300.0], ["finish"]],
	"tough": [["start", 160.0], ["spiker"], ["checkpoint", 60.0], ["crawler", 170.0], ["checkpoint", 60.0], ["spiker"], ["flat", 300.0], ["finish"]],
}
const Library := preload("res://scripts/game/level_library.gd")

const TOUR := [
	["hoodoo_loops", 250.0, 6.5, "scrambler", "day", "clear", "TRAIL 7: LOOP-THE-LOOP", ""],
	["mesa_springs", 250.0, 6.0, "scrambler", "day", "clear", "TRAIL 5: SPRINGS", ""],
	["lantern_mine", 280.0, 7.0, "scrambler", "dusk", "clear", "TRAIL 6: LOW CEILINGS", ""],
	["hoist_yard", 230.0, 6.0, "dirt", "day", "clear", "TRAIL 8: LIFTS", ""],
	["skyline_pass", 220.0, 7.5, "scrambler", "dusk", "clear", "TRAIL 9: ZIPLINES", ""],
	["dusty_trail", 300.0, 8.0, "scrambler", "day", "clear", "BONUS PLANE", "plane"],
	["dusty_trail", 60.0, 6.5, "sport", "day", "clear", "SPORTBIKE: POWER WHEELIE", "wheelie"],
	["dusty_trail", 60.0, 7.0, "scooter", "dusk", "clear", "SCOOTER: UMBRELLA", "glide"],
	["copper_canyon", 60.0, 6.0, "minibike", "day", "clear", "MINIBIKE: DOUBLE HOP", "hop"],
	["rustyard", 60.0, 6.0, "cafe", "day", "clear", "CAFE RACER: AIR DASH", "dash"],
	["night_trestle", 60.0, 6.5, "chopper", "night", "clear", "CHOPPER: IRON HIDE", "tough"],
	["mesa_springs", 250.0, 6.5, "scrambler", "dusk", "clear", "? HINT CARD (LIVE DEMO)", "hint"],
]


## Wraps the autopilot to show off a specialty: a second press near the top of a jump
## (double hop / air dash), holding through landings (wheelie) or while falling
## (umbrella). It only does so when a quick simulation says the landing that follows
## is still safe, so the showing off never throws the autopilot's plan.
class Showoff:
	var bot
	var mode := ""

	func decide(s: Dictionary) -> Array:
		if mode == "tough":
			return [false, false]  # ride straight through: the armour takes the hits
		var d: Array = bot.decide(s)
		if (mode == "hop" or mode == "dash") and not s.grounded and not bool(s.air_used) \
				and absf(float(s.vy)) < 40.0 and float(s.coyote) <= 0.0 and int(s.zip) < 0:
			if _safe_with(s, true, false):
				return [true, true]
		if mode == "wheelie" and (s.grounded or float(s.vy) > 0.0) and not d[0]:
			d[1] = true
		if mode == "glide" and not s.grounded and float(s.vy) > 0.0 and not d[1]:
			if _safe_with(s, false, true):
				d[1] = true
		return d

	## Fly on from s with this input (press now / keep holding while falling) and
	## check the autopilot still has a safe way on after touching down.
	func _safe_with(s0: Dictionary, press: bool, hold_falling: bool) -> bool:
		var Phys = load("res://scripts/game/bike_physics.gd")
		var s: Dictionary = bot._copy(s0)
		for i in 400:
			var held: bool = hold_falling and not s.grounded and float(s.vy) > 0.0
			Phys.step(bot.level, s, press and i == 0, held)
			if not s.alive:
				return false
			if s.grounded:
				return bot._continue(s, 2).safe
		return false


func _tour() -> void:
	var cap_layer := CanvasLayer.new()
	cap_layer.layer = 50
	add_child(cap_layer)
	var cap := Kit.label("", 8, UITheme.GOLD)
	cap.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	cap.offset_top = -24
	cap.offset_bottom = -12
	cap_layer.add_child(cap)
	for sg in TOUR:
		GameState.data.conditions = {"time": sg[4], "weather": sg[5]}
		GameState.data.bike = sg[3]
		main.navigate("game", sg[0])
		await get_tree().process_frame
		var gs = main.current
		var w = gs.world
		if STAGES.has(sg[7]):
			var meta: Dictionary = Catalog.level(sg[0]).duplicate()
			w.level = Library.build_layout(STAGES[sg[7]], meta)
			Phys.apply_weather(w.level, String(sg[5]))
		var ap = Bot.new(w.level)
		if sg[7] in ["wheelie", "glide", "hop", "dash", "tough"]:
			var sh := Showoff.new()
			sh.bot = ap
			sh.mode = sg[7]
			w.bot = sh
		else:
			w.bot = ap
		_teleport(w, float(sg[1]))
		if sg[7] == "plane":
			w._next_plane_t = 0.0
		cap.text = sg[6]
		if sg[7] == "hint":
			await get_tree().create_timer(1.6).timeout
			gs.show_hint()
			await get_tree().create_timer(float(sg[2]) - 1.6).timeout
			gs.resume()
		else:
			await get_tree().create_timer(float(sg[2])).timeout


## Start the run at x on the main deck (as if respawning there).
func _teleport(w, x: float) -> void:
	for ti in Phys.tracks_near(w.level, x):
		var tr: Dictionary = w.level.tracks[ti]
		if x >= tr.x0 and x <= tr.x1 and not tr.side:
			w.state = Phys.new_state(w.level, x, ti, 0.0, w.ability)
			w._focus_y = w.state.y
			w._snapshot(x, ti)
			if w.cam:
				w.cam.position = w._cam_target()
			return

var main: Node
var spec := ""


func _ready() -> void:
	var p := spec.split(":")
	for kind in Catalog.KINDS:
		for it in Catalog.items(kind):
			if not it.id in GameState.data[kind + "_owned"]:
				GameState.data[kind + "_owned"].append(it.id)
	await get_tree().process_frame
	if p[0] == "sliders":  # drag the sliders with real touch events
		main.navigate("title", "")
		await get_tree().process_frame
		main.current._open_settings()
		await get_tree().process_frame
		await get_tree().process_frame
		var sliders := []
		for n in main.current._settings.find_children("*", "Control", true, false):
			if n.has_method("_track"):
				sliders.append(n)
		var xf: Transform2D = get_tree().root.get_final_transform()
		for i in 2:
			var sl: Control = sliders[i]
			var t: Rect2 = sl._track()
			var y := sl.global_position.y + sl.size.y * 0.5
			var x0 := sl.global_position.x + t.end.x - 2
			var x1 := sl.global_position.x + t.position.x + t.size.x * (0.5 if i == 0 else -0.2)
			_touch(xf * Vector2(x0, y), true, 0)
			await get_tree().process_frame
			for k in 6:
				_drag(xf * Vector2(lerpf(x0, x1, (k + 1) / 6.0), y))
				await get_tree().process_frame
			_touch(xf * Vector2(x1, y), false, 0)
			await get_tree().process_frame
		var mv := AudioServer.get_bus_index("MusicVol")
		var sv := AudioServer.get_bus_index("SoundVol")
		print("SLIDERS music=%.2f (bus %.1f dB, mute %s) sound=%.2f (mute %s)" % [GameState.volume("music"),
			AudioServer.get_bus_volume_db(mv), AudioServer.is_bus_mute(mv), GameState.volume("sound"), AudioServer.is_bus_mute(sv)])
		var f := FileAccess.open("user://save.json", FileAccess.READ)
		print("SAVED settings=", (JSON.parse_string(f.get_as_text()) as Dictionary).get("settings"))
		get_tree().quit()
		return
	if p[0] == "crash":  # engine dies on crash, comes back on respawn
		main.navigate("game", "dusty_trail")
		await get_tree().create_timer(2.5).timeout
		var w = main.current.world
		w.state.death = "hit"
		w._crash()
		await get_tree().create_timer(0.5).timeout
		print("CRASHED engine=%s/%s" % [AudioDirector.eng_idle.playing, AudioDirector.eng_cruise.playing])
		await get_tree().create_timer(3.0).timeout
		print("RESPAWNED phase=%s engine_idle=%s(%.0fdB) engine_cruise=%s(%.0fdB)" % [w.phase,
			AudioDirector.eng_idle.playing, AudioDirector.eng_idle.volume_db,
			AudioDirector.eng_cruise.playing, AudioDirector.eng_cruise.volume_db])
		get_tree().quit()
		return
	if p[0] == "retry":  # RETRY path must keep the new run's audio alive
		GameState.data.conditions = {"time": "dusk", "weather": "wind"}
		main.navigate("game", "dusty_trail")
		await get_tree().create_timer(2.5).timeout
		main.navigate("game", "dusty_trail")
		await get_tree().create_timer(3.0).timeout
		var ad = AudioDirector
		var live := []
		for k in ad.amb:
			if ad.amb[k].playing:
				live.append("%s@%.0fdB" % [k, ad.amb[k].volume_db])
		print("RETRY engine_idle=%s(%.0fdB) engine_cruise=%s(%.0fdB) ambience=%s music=%s music_bus=%.1fdB" % [
			ad.eng_idle.playing, ad.eng_idle.volume_db, ad.eng_cruise.playing, ad.eng_cruise.volume_db, live,
			ad.music.playing, AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))])
		main.navigate("title", "")
		await get_tree().create_timer(1.5).timeout
		live = []
		for k in ad.amb:
			if ad.amb[k].playing:
				live.append(k)
		print("TITLE engine=%s ambience=%s music_bus=%.1fdB" % [ad.eng_cruise.playing or ad.eng_idle.playing, live,
			AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))])
		get_tree().quit()
		return
	if p[0] == "tour":
		await _tour()
		get_tree().quit()
		return
	if p[0] == "garage":
		main.navigate("garage", "")
		await get_tree().process_frame
		var g = main.current
		g._tabs["bike"].button_pressed = true
		g._set_tab("bike")
		await get_tree().create_timer(1.0).timeout
		for b in Catalog.bikes():
			g._equip(b.id)
			await get_tree().create_timer(2.6).timeout
		get_tree().quit()
		return
	GameState.data.conditions = {"time": p[2], "weather": p[3]}
	GameState.data.rider = p[4]
	GameState.data.bike = p[5]
	GameState.data.paint = p[6]
	main.navigate("game", p[1])
	await get_tree().process_frame
	if p.size() > 8 and p[8] != "":  # solo one bus to measure it in the real mix
		for bus in ["Music", "Engine", "Ambience", "SFX"]:
			AudioServer.set_bus_mute(AudioServer.get_bus_index(bus), bus != p[8])
	var w = main.current.world
	w.bot = Bot.new(w.level)
	if p.size() > 9 and p[9] == "train":  # bring the train on early for captures
		main.current.depth._next_train = 1.0
		main.current.depth.train_dir = -1.0
	await get_tree().create_timer(float(p[7])).timeout
	get_tree().quit()


func _touch(pos: Vector2, pressed: bool, idx: int) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = idx
	ev.position = pos
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _drag(pos: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = 0
	ev.position = pos
	Input.parse_input_event(ev)

