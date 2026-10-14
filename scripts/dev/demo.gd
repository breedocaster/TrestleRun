## Scripted demo for Movie Maker capture (audio + video):
##   --demo=ride:<level>:<time>:<weather>:<rider>:<bike>:<paint>:<seconds>
##   --demo=garage   (equips each bike in turn so every engine blips)
extends Node

const Bot := preload("res://scripts/dev/bot.gd")
const Catalog := preload("res://scripts/catalog.gd")

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

