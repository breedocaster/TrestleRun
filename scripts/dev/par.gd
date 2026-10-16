## Dev: par time per trail = the bot's clean clear-weather riding time + 1 s, rounded
## up to the half second. Prints a PARS block for catalog.gd.  -- --par
extends Node

const World := preload("res://scripts/game/world.gd")
const Bot := preload("res://scripts/game/autopilot.gd")
const Catalog := preload("res://scripts/catalog.gd")


func _ready() -> void:
	var lines := []
	for meta in Catalog.levels():
		var w = World.new()
		w.headless = true
		w.setup(meta.id, {"bike": "scrambler", "ability": {}}, [], {"time": "dusk", "weather": "clear"})
		w.bot = Bot.new(w.level)
		while w.result.is_empty() and w.ticks < 60 * 400:
			w.tick()
		var t: float = w.result.get("time", 0.0)
		var par := ceilf((t + 1.0) * 2.0) / 2.0
		print("PAR %s ride=%.1f crashes=%d par=%.1f" % [meta.id, t, w.crashes, par])
		lines.append('\t"%s": %.1f,' % [meta.id, par])
		w.free()
	print("PARS_BLOCK\nconst PARS := {\n" + "\n".join(lines) + "\n}")
	get_tree().quit()
