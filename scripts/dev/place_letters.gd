## Dev: choose each trail's letter spots from coins the bot really collects, and write
## scripts/game/letter_spots.gd.  godot --headless --path . -- --place-letters
extends Node

const World := preload("res://scripts/game/world.gd")
const Bot := preload("res://scripts/game/autopilot.gd")
const Catalog := preload("res://scripts/catalog.gd")
const Library := preload("res://scripts/game/level_library.gd")


func _ready() -> void:
	var lines := []
	for meta in Catalog.levels():
		Library.no_letters = true
		var got := {}
		for weather in ["clear", "rain"]:
			var w = World.new()
			w.headless = true
			w.setup(meta.id, {"bike": "scrambler", "ability": {}}, [], {"time": "dusk", "weather": weather})
			w.bot = Bot.new(w.level)
			while w.result.is_empty() and w.ticks < 60 * 400 and w.crashes < 3:
				w.tick()
			for i in w.level.pickups.size():
				if not w.level.pickups[i].alive:
					got[i] = got.get(i, 0) + 1
			w.free()
		# Coins collected in both weathers.
		var both := []
		for i in got:
			if int(got[i]) >= 2:
				both.append(i)
		var b = load("res://scripts/game/level_library.gd").new()
		b.level_id = String(meta.id)
		for chunk in Library.Layouts.LAYOUTS[meta.id]:
			b.marks.append([String(chunk[0]), snappedf(b.x, 1.0)])
			b.callv("c_" + String(chunk[0]), chunk.slice(1))
		var picks: Array = b.choose_letters(both)
		Library.no_letters = false
		var spots := []
		for e in picks:
			var p: Vector2 = b.pickups[e[0]].pos
			spots.append("[%s, %s]" % [str(p.x), str(p.y)])
		print("LETTERS %s %d spots from %d reliable coins" % [meta.id, spots.size(), both.size()])
		lines.append('\t"%s": [%s],' % [meta.id, ", ".join(spots)])
	var src := FileAccess.get_file_as_string("res://scripts/game/letter_spots.gd")
	var head := src.substr(0, src.find("const SPOTS"))
	var f := FileAccess.open("res://scripts/game/letter_spots.gd", FileAccess.WRITE)
	f.store_string(head + "const SPOTS := {\n" + "\n".join(lines) + "\n}\n")
	f.close()
	print("LETTERS_DONE")
	get_tree().quit()
