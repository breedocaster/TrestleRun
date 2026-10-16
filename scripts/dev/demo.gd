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
	"flips": [["start", 160.0], ["spring_gap", 84.0], ["flat", 220.0, 0], ["spring_up", 0, ""], ["flat", 260.0, 0],
		["spring_gap", 84.0], ["flat", 200.0, 0], ["stairs_down", 3], ["flat", 200.0], ["finish"]],
	"lanes": [["start"], ["flat", 100.0], ["fork", 1, [["crawler", 170.0], ["gap", 40.0], ["flat", 100.0]], [["spiker"], ["flat", 120.0]], 1],
		["flat", 150.0], ["fork", -1, [["gap", 50.0], ["crawler", 170.0]], [], 0, 1], ["flat", 200.0], ["finish"]],
	"sticky": [["start"], ["flat", 100.0], ["cliff", 300.0, 110.0, 1], ["flat", 200.0], ["cliff", 300.0, 110.0, 0, 0], ["flat", 200.0], ["finish"]],
	"rocket": [["start"], ["flat", 100.0], ["tri_ramp", 1, "c"], ["flat", 200.0], ["finish"]],
	"crumble": [["start"], ["flat", 100.0], ["crumble"], ["flat", 100.0], ["crumble", [44.0, 76.0, 44.0, 96.0, 44.0, 44.0, 88.0]], ["flat", 200.0], ["finish"]],
	"chase": [["chase"], ["start"], ["flat", 100.0], ["gap", 40.0], ["hops", 3, 28.0], ["crumble"], ["loop"], ["gap", 50.0], ["flat", 300.0], ["finish"]],
	"magnet": [["start"], ["flat", 60.0], ["power", "magnet"], ["high_coins"], ["hops", 2, 28.0], ["power", "hat"], ["crawler", 170.0], ["spiker"], ["flat", 200.0], ["finish"]],
	"hat": [["start", 160.0], ["power", "hat", 120.0], ["flat", 60.0], ["spiker"], ["flat", 300.0], ["finish"]],
	"tough": [["start", 160.0], ["spiker"], ["checkpoint", 60.0], ["crawler", 170.0], ["checkpoint", 60.0], ["spiker"], ["flat", 300.0], ["finish"]],
}
const Library := preload("res://scripts/game/level_library.gd")

## "@screen" entries show a menu screen instead of a ride.
const TOUR := [
	["@story_intro", 0.0, 9.0, "", "", "", "NEW: STORY MODE - WIN BACK GRANDPA'S BIKE", ""],
	["@story", 0.0, 4.5, "", "", "", "FOUR AREAS, THREE TRAILS AND A BOSS EACH", ""],
	["s2_siding", 470.0, 8.0, "scrambler", "", "", "NEW: GRIND RAILS - THEY ONLY HOLD YOU WHILE YOU HOLD", ""],
	["s3_apple_row", 430.0, 7.5, "scrambler", "", "", "NEW: ROPE SWINGS - LET GO ON THE UPSWING", ""],
	["s4_fairgrounds", 430.0, 7.5, "scrambler", "", "", "NEW: WALL-RIDES - HOLD ALL THE WAY ROUND", ""],
	["s1_powerlines", 1280.0, 7.0, "scrambler", "", "", "MORE ZIPLINES: CHAINS, UPHILL CABLES, ISLANDS", ""],
	["s1_boss", 250.0, 26.0, "scrambler", "", "", "BOSSES: LAND ON THE GLASS TOP THREE TIMES", "boss"],
	["dusty_trail", 2340.0, 9.0, "scrambler", "day", "clear", "WRECK A FEW TIMES? A HINT SHOWS THE WAY", "guide"],
	["@garage", 0.0, 6.0, "", "", "", "PICK A RIDER OR BIKE TO HEAR ITS ENGINE", ""],
	["@settings", 0.0, 3.5, "", "", "", "NEW: ENGINE VOLUME SLIDER", ""],
	["@achievements", 0.0, 5.0, "", "", "", "31 ACHIEVEMENTS, READY FOR PLAY GAMES + GAME CENTER", ""],
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
		bot.tricks = mode == "flips"
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
	# A fresh mix for the capture, whatever this machine's save has (not saved).
	GameState.set_volume("music", 0.5, false)
	GameState.set_volume("sound", 0.85, false)
	GameState.set_volume("engine", 0.8, false)
	var cap_layer := CanvasLayer.new()
	cap_layer.layer = 50
	add_child(cap_layer)
	var cap := Kit.label("", 8, UITheme.GOLD)
	cap.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	cap.offset_top = -24
	cap.offset_bottom = -12
	cap_layer.add_child(cap)
	for sg in TOUR:
		cap.text = sg[6]
		if String(sg[0]).begins_with("@"):
			await _tour_screen(String(sg[0]).substr(1), float(sg[2]))
			continue
		if sg[4] != "":
			GameState.data.conditions = {"time": sg[4], "weather": sg[5]}
		GameState.data.bike = sg[3]
		main.navigate("game", sg[0])
		await get_tree().process_frame
		var gs = main.current
		var w = gs.world
		if STAGES.has(sg[7]):
			var meta: Dictionary = Catalog.level(sg[0]).duplicate()
			w.replace_level(Library.build_layout(STAGES[sg[7]], meta))
		var ap = Bot.new(w.level)
		ap.tricks = sg[7] == "tricks"
		if sg[7] in ["wheelie", "glide", "hop", "dash", "tough", "flips", "hat"]:
			var sh := Showoff.new()
			sh.bot = ap
			sh.mode = "tough" if sg[7] == "hat" else sg[7]
			w.bot = sh
		else:
			w.bot = ap
		_teleport(w, float(sg[1]))
		if sg[7] == "norocket":
			for i in w.level.powerups.size():
				w.state.got[i] = true
		if sg[7] == "ghost":
			w.set_ghost(_bot_ghost(sg[0], float(sg[1]), "sport"))
		if sg[7] == "plane":
			w._next_plane_t = 0.0
		if sg[7] == "guide":
			# Wreck at the gap past this checkpoint as if for the 99th time, then ride
			# the hint line exactly (the sim is deterministic).
			var G = load("res://scripts/game/guide.gd")
			G.wrecks(w.level_id)[G.section_at(w.level, 2950.0)] = 98
			w.bot = null
			w.hint_sync = true
			w._air_x = 2950.0
			w.state.death = "fall"
			w._crash()
			var rp := GuideReplay.new()
			rp.g = w.guide
			w.bot = rp
		if sg[7] == "hint":
			await get_tree().create_timer(1.6).timeout
			gs.show_hint()
			await get_tree().create_timer(3.4).timeout
			var cards: Array = gs.find_children("*", "PanelContainer", true, false).filter(func(n): return n.has_method("_show_page"))
			if not cards.is_empty():
				cards[0]._show_page(1)
			await get_tree().create_timer(float(sg[2]) - 5.0).timeout
			gs.resume()
		else:
			await get_tree().create_timer(float(sg[2])).timeout


## Menu screens for the tour.
func _tour_screen(target: String, secs: float) -> void:
	match target:
		"story_intro":
			main.navigate("story_intro", "")
			await get_tree().process_frame
			var pages := 6
			for i in pages:
				main.current._show(i)
				await get_tree().create_timer(secs / pages).timeout
		"story":
			main.navigate("story", "")
			await get_tree().create_timer(secs).timeout
		"garage":
			main.navigate("garage", "")
			await get_tree().process_frame
			var g = main.current
			g._tabs["rider"].button_pressed = true
			g._set_tab("rider")
			await get_tree().create_timer(0.6).timeout
			g._equip(GameState.equipped("rider"))  # picking a rider starts your bike
			await get_tree().create_timer(1.8).timeout
			g._tabs["bike"].button_pressed = true
			g._set_tab("bike")
			for b in ["chopper", "sport", "scooter"]:
				AudioDirector.preview_engine(b)  # same as tapping the bike's tile
				await get_tree().create_timer((secs - 2.4) / 3.0).timeout
		"settings":
			main.navigate("title", "")
			await get_tree().process_frame
			main.current._open_settings()
			await get_tree().create_timer(0.8).timeout
			AudioDirector.preview_engine(GameState.equipped("bike"))
			await get_tree().create_timer(secs - 0.8).timeout
		"achievements":
			main.navigate("achievements", "")
			await get_tree().create_timer(0.8).timeout
			Achievements._toasts.append("part_headlight")
			await get_tree().create_timer(secs - 0.8).timeout


## Plays a hint line's presses back frame by frame.
class GuideReplay:
	var g: Dictionary
	var i := 0

	func decide(_s: Dictionary) -> Array:
		i += 1
		var hd: PackedByteArray = g.get("held", PackedByteArray())
		return [(g.get("taps", PackedInt32Array()) as PackedInt32Array).has(i), i < hd.size() and hd[i] == 1]


## A ghost recorded from a headless bot run on another bike (for showing ghosts).
static func _bot_ghost(level_id: String, x: float, bike: String) -> Dictionary:
	var World = load("res://scripts/game/world.gd")
	var w = World.new()
	w.headless = true
	w.setup(level_id, {"bike": bike}, [], {"time": "day", "weather": "clear"})
	var sh := Showoff.new()
	sh.bot = Bot.new(w.level)
	sh.mode = "wheelie"
	w.bot = sh
	_teleport(w, x)
	w.phase = "ride"
	var fr := PackedFloat32Array()
	for i in 60 * 20:
		w.tick()
		if i % 2 == 0:
			var rot: float = atan(float(w.state.slope)) if w.state.grounded else clampf(float(w.state.vy) * 0.0011, -0.42, 0.5)
			fr.append_array(PackedFloat32Array([w.state.x, w.state.y, rot, w.state.lane_z]))
	w.free()
	return {"rig": {"rider": "zorp", "bike": bike, "paint": "stock"}, "frames": fr}


## Start the run at x on the main deck (as if respawning there).
static func _teleport(w, x: float) -> void:
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
	if p[0] == "scroll":  # can a finger drag the trail picker sideways from each part of a card?
		main.navigate("levels", "")
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		var ls = main.current
		Input.emulate_touch_from_mouse = true  # desktop: makes DisplayServer report a touchscreen, as on the phone
		print("SCROLL touchscreen=%s" % DisplayServer.is_touchscreen_available())
		var got := {"n": 0}
		ls._scroll.gui_input.connect(func(e): got.n += 1)
		ls._scroll.scroll_started.connect(func(): print("SCROLL started"))
		var xf: Transform2D = get_tree().root.get_final_transform()
		var card: Control = ls._row.get_child(1)
		var chain := []
		var nn: Node = card.find_children("*", "Label", true, false)[0]
		while nn != null and nn != main:
			if nn is Control:
				chain.append("%s:%s" % [nn.get_class(), ["STOP", "PASS", "IGNORE"][nn.mouse_filter]])
			nn = nn.get_parent()
		print("SCROLL chain ", chain)
		# Measure the card where the drags will start: scrolled back to the start (the
		# picker opens scrolled to your current trail).
		ls._scroll.scroll_horizontal = 0
		await get_tree().process_frame
		await get_tree().process_frame
		var spots := {}
		for n in card.find_children("*", "Control", true, false):
			var nm := "%s(%s)" % [n.get_class(), ["STOP", "PASS", "IGNORE"][n.mouse_filter]]
			if n is Button:
				nm = "Button:" + n.text
			if not spots.has(nm) and n.size.x > 10 and n.size.y > 6:
				spots[nm] = n.get_global_rect().get_center()
		for nm in spots:
			ls._scroll.scroll_horizontal = 0
			await get_tree().process_frame
			var a: Vector2 = spots[nm]
			var touch := "--touch" in OS.get_cmdline_user_args()
			if touch:
				_touch(xf * a, true, 0)
			else:
				_mouse(xf * a, true)
			await get_tree().process_frame
			for k in 8:
				if touch:
					var dv := InputEventScreenDrag.new()
					dv.index = 0
					dv.position = xf * (a - Vector2(12.0 * (k + 1), 0))
					dv.relative = xf.basis_xform(Vector2(-12, 0))
					Input.parse_input_event(dv)
				else:
					_mouse_move(xf * (a - Vector2(12.0 * (k + 1), 0)), xf.basis_xform(Vector2(-12, 0)))
				await get_tree().process_frame
			if touch:
				_touch(xf * (a - Vector2(96, 0)), false, 0)
			else:
				_mouse(xf * (a - Vector2(96, 0)), false)
			await get_tree().process_frame
			await get_tree().process_frame
			print("SCROLL from %-28s -> scroll_x=%d  events_at_scroll=%d confirm=\"%s\"" % [nm, ls._scroll.scroll_horizontal, got.n, ls._confirm])
			got.n = 0
			if main.current != ls:
				main.navigate("levels", "")
				await get_tree().process_frame
				await get_tree().process_frame
				ls = main.current
			if ls._setup != null:
				ls._setup.queue_free()
				ls._setup = null
		print("SCROLL max=%d viewport=%s" % [ls._scroll.get_h_scroll_bar().max_value - ls._scroll.size.x, get_viewport().get_visible_rect().size])
		# A plain tap on trail 1's RIDE must still open the conditions picker.
		ls._scroll.scroll_horizontal = 0
		await get_tree().process_frame
		var ride: Button = ls._row.get_child(0).find_children("*", "Button", true, false)[-1]
		var rp := ride.get_global_rect().get_center()
		_mouse(xf * rp, true)
		await get_tree().process_frame
		_mouse(xf * rp, false)
		await get_tree().process_frame
		print("SCROLL tap %s -> setup_open=%s" % [ride.text, ls._setup != null])
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
		main.navigate("game", "rustyard")
		await get_tree().create_timer(2.5).timeout
		var first_player = AudioDirector.music
		main.navigate("game", "rustyard")
		await get_tree().create_timer(3.0).timeout
		print("RETRY track=%s same_player=%s pos=%.1fs" % [AudioDirector._track, AudioDirector.music == first_player,
			AudioDirector.music.get_playback_position()])
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
		print("TITLE engine=%s ambience=%s music_bus=%.1fdB track=%s" % [ad.eng_cruise.playing or ad.eng_idle.playing, live,
			AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")), ad._track])
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


func _mouse(pos: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.position = pos
	ev.global_position = pos
	ev.pressed = pressed
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(ev)


func _mouse_move(pos: Vector2, rel: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	ev.relative = rel
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(ev)


func _drag(pos: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = 0
	ev.position = pos
	Input.parse_input_event(ev)

