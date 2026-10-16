extends Node
const World := preload("res://scripts/game/world.gd")
const Bot := preload("res://scripts/game/autopilot.gd")

## Collapse chase on Last Trestle: the bot's closest call, and a sloppy rider
## (a tap every 1.5 s at random) for comparison.
class Sloppy:
	var bot
	var n := 0
	func decide(s: Dictionary) -> Array:
		n += 1
		var d: Array = bot.decide(s)
		if n % 90 == 0 and s.grounded and not d[0]:
			return [true, false]
		return d

func _ready() -> void:
	for mode in ["bot", "sloppy"]:
		for wx in ["clear", "rain", "wind"]:
			var w = World.new()
			w.headless = true
			w.setup("last_trestle", {"bike": "scrambler", "ability": {}}, [], {"time": "dusk", "weather": wx})
			var b = Bot.new(w.level)
			if mode == "sloppy":
				var sl := Sloppy.new()
				sl.bot = b
				w.bot = sl
			else:
				w.bot = b
			var m := INF
			while w.result.is_empty() and w.ticks < 60 * 200 and w.crashes < 8:
				w.tick()
				if w.phase == "ride":
					m = minf(m, float(w.state.x) - float(w.state.chase_x))
			print("PROBE %-6s %-5s finished=%s crashes=%d deaths=%s closest=%.0f px" % [mode, wx, not w.result.is_empty(), w.crashes, w.death_log.map(func(d): return d.cause), m])
			w.free()
	get_tree().quit()
