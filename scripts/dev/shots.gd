## Screenshot helper.
## --shot=title|levels|garage[:rider|bike|paint]|setup:<id>|game:<id>:<ticks>[:pause]|results:<id>
## --out=<file.png> [--money=N] [--cond=<time>:<weather>] [--rig=<rider>:<bike>:<paint>]
## --own-all  (marks every garage item owned, for previews)
extends Node

const Bot := preload("res://scripts/dev/bot.gd")
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
			w.bot = Bot.new(w.level)
			if parts[0] == "results":
				while w.result.is_empty() and w.ticks < 60 * 400:
					w.tick()
			else:
				for i in int(parts[2]):
					w.tick()
				if parts.size() > 3 and parts[3] == "pause":
					w.bot = null
					gs.pause()
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
		_:
			main.navigate(parts[0], "")
	for i in 10:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(out)
	print("SHOT saved ", out, " ", img.get_size())
	get_tree().quit()
