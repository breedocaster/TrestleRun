## Screenshot helper.
## --shot=title|levels|garage[:rider|bike|paint]|setup:<id>|tips:<id>|results:<id>
##        game:<id>:<ticks or x<pos>>[:pause|:hint|:hold]
## --out=<file.png> [--money=N] [--cond=<time>:<weather>] [--rig=<rider>:<bike>:<paint>]
## --own-all  (marks every garage item owned, for previews)  --plane (send a bonus plane now)
## --unlock-all  --clear=<n> (mark the first n trails cleared)
extends Node

const Bot := preload("res://scripts/game/autopilot.gd")
const Catalog := preload("res://scripts/catalog.gd")

var main: Node
var args: PackedStringArray


func _ready() -> void:
	var spec := ""
	var out := "shot.png"
	for a in args:
		if a.begins_with("--shot="):
			spec = a.substr(7)
		elif a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--money="):
			GameState.data.money = int(a.substr(8))
		elif a.begins_with("--cond="):
			var c := a.substr(7).split(":")
			GameState.data.conditions = {"time": c[0], "weather": c[1]}
		elif a.begins_with("--rig="):
			var r := a.substr(6).split(":")
			for i in Catalog.KINDS.size():
				var kind: String = Catalog.KINDS[i]
				if not r[i] in GameState.data[kind + "_owned"]:
					GameState.data[kind + "_owned"].append(r[i])
				GameState.data[kind] = r[i]
		elif a == "--unlock-all":
			for l in Catalog.levels():
				if not l.id in GameState.data.levels_unlocked:
					GameState.data.levels_unlocked.append(l.id)
		elif a.begins_with("--clear="):
			for i in int(a.substr(8)):
				var rec: Dictionary = GameState.level_record(Catalog.levels()[i].id)
				rec.cleared = true
				rec.gears = [true, i % 2 == 0, true]
				rec.best_coins = 80 + i * 9
		elif a == "--own-all":
			for kind in Catalog.KINDS:
				for it in Catalog.items(kind):
					if not it.id in GameState.data[kind + "_owned"]:
						GameState.data[kind + "_owned"].append(it.id)
	await get_tree().process_frame
	var parts := spec.split(":")
	match parts[0]:
		"game", "results":
			main.navigate("game", parts[1])
			await get_tree().process_frame
			var gs = main.current
			var w = gs.world
			var stage := ""
			for a in args:
				if a.begins_with("--stage="):
					stage = a.substr(8)
			if stage != "":
				var Demo = load("res://scripts/dev/demo.gd")
				w.level = load("res://scripts/game/level_library.gd").build_layout(Demo.STAGES[stage], Catalog.level(parts[1]))
				load("res://scripts/game/bike_physics.gd").apply_weather(w.level, String(w.cond.weather))
				w.state = load("res://scripts/game/bike_physics.gd").new_state(w.level, 40.0, 0, 0.0, w.ability)
				var sh = Demo.Showoff.new()
				sh.bot = Bot.new(w.level)
				sh.mode = stage
				w.bot = sh
			else:
				w.bot = Bot.new(w.level)
			if parts[0] == "results":
				while w.result.is_empty() and w.ticks < 60 * 400:
					w.tick()
			else:
				if "--plane" in args:
					w._next_plane_t = 0.0
				if "--plane" in args:
					# Ride until the plane's prize sack is just behind the rider.
					while (w.plane.is_empty() or w.prize_pos().x < w.state.x - 60.0) and w.ticks < 60 * 400:
						w.tick()
				elif parts[2].begins_with("x"):
					var tx := float(parts[2].substr(1))
					while w.state.x < tx and w.ticks < 60 * 400:
						w.tick()
				else:
					for i in int(parts[2]):
						w.tick()
				# Let the visuals catch up (_vis_t, camera smoothing) on the frozen frame.
				w._vis_t += 1.0
				if parts.size() > 3 and parts[3] == "pause":
					w.bot = null
					gs.pause()
				elif parts.size() > 3 and parts[3] == "hint":
					w.bot = null
					gs.show_hint()
				else:
					w._acc = -1.0e9  # freeze the sim; visuals keep drawing
		"garage":
			main.navigate("garage", "")
			await get_tree().process_frame
			if parts.size() > 1:
				main.current._tabs[parts[1]].button_pressed = true
				main.current._set_tab(parts[1])
		"settings":
			main.navigate("title", "")
			await get_tree().process_frame
			main.current._open_settings()
		"setup":
			main.navigate("levels", "")
			await get_tree().process_frame
			main.current._show_setup(parts[1])
		"tips":
			main.navigate("levels", "")
			await get_tree().process_frame
			main.current._show_setup(parts[1])
			main.current._show_hint(parts[1])
		_:
			main.navigate(parts[0], "")
	var frames := 10
	for a in args:
		if a.begins_with("--frames="):
			frames = int(a.substr(9))
	for i in frames:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(out)
	print("SHOT saved ", out, " ", img.get_size())
	get_tree().quit()
