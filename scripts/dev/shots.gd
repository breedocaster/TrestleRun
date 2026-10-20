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
		elif a.begins_with("--story="):
			# Story progress: the first n story trails cleared (and their bosses' parts).
			var n := int(a.substr(8))
			var sl := Catalog.story_levels()
			for i in mini(n, sl.size()):
				var rec: Dictionary = GameState.level_record(sl[i].id)
				rec.cleared = true
				rec.best_coins = 60 + i * 7
				rec.best_time = 40.0 + i
				rec.gold = i % 3 == 0
				if not sl[i].id in GameState.data.levels_unlocked:
					GameState.data.levels_unlocked.append(sl[i].id)
				if sl[i].has("part") and not sl[i].part in GameState.story_parts():
					GameState.story_parts().append(sl[i].part)
			if n < sl.size() and not sl[n].id in GameState.data.levels_unlocked:
				GameState.data.levels_unlocked.append(sl[n].id)
			GameState.story().intro_seen = true
		elif a.begins_with("--ach="):
			for id in a.substr(6).split(","):
				Achievements._store()[id] = 1
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
			var test := ""
			for a in args:
				if a.begins_with("--test="):
					test = a.substr(7)
			if test != "":
				var Lib = load("res://scripts/game/level_library.gd")
				var Lay = load("res://scripts/game/level_layouts.gd")
				var meta: Dictionary = Catalog.level(parts[1]).duplicate()
				meta.id = parts[1]
				w.replace_level(Lib.build_layout(Lay.TESTS[test], meta))
				w.bot = Bot.new(w.level)
			elif stage != "":
				var Demo = load("res://scripts/dev/demo.gd")
				w.replace_level(load("res://scripts/game/level_library.gd").build_layout(Demo.STAGES[stage], Catalog.level(parts[1])))
				var sh = Demo.Showoff.new()
				sh.bot = Bot.new(w.level)
				sh.mode = stage
				w.bot = sh
			elif test == "":
				w.bot = Bot.new(w.level)
			if "--ghost" in args:
				var Demo2 = load("res://scripts/dev/demo.gd")
				w.set_ghost(Demo2._bot_ghost(parts[1], 300.0, "sport"))
				Demo2._teleport(w, 300.0)
				print("GHOST frames=%d view=%s" % [(w.ghost.frames as PackedFloat32Array).size(), w._ghost_view])
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
				elif parts[2].begins_with("flip"):
					# Ride to the Nth flip, caught mid-spin.
					var n := int(parts[2].substr(4)) if parts[2].length() > 4 else 1
					var seen := 0
					var was := false
					while w.ticks < 60 * 400:
						w.tick()
						var on: bool = int(w.state.flip_dir) != 0 and float(w.state.flip_a) > 2.4
						if on and not was:
							seen += 1
							if seen >= n:
								break
						was = on
				elif parts[2] == "rope":
					# Ride until a rope is lit up as catchable (the cue at its brightest).
					var lit := false
					while not lit and w.ticks < 60 * 400:
						w.tick()
						for ri in w.level.get("ropes", []).size():
							lit = lit or w._rope_cue(ri, w.level.ropes[ri]) > 0.6
				elif parts[2].begins_with("x"):
					var tx := float(parts[2].substr(1))
					while w.state.x < tx and w.ticks < 60 * 400:
						w.tick()
				else:
					for i in int(parts[2]):
						w.tick()
				if parts.size() > 3 and parts[3] == "crash":
					# Mid-wreck, past the point where a tap skips it (the HUD says so).
					w.bot = null
					w.state.death = "hit"
					w._crash()
					for i in w.CRASH_SKIP_TICKS + 6:
						w.tick()
				elif parts.size() > 3 and parts[3] == "guidethread":
					# The real thing: wreck here (counted as the 99th time), then let the
					# game run on its own clock with the hint worked out on the worker.
					var G2 = load("res://scripts/game/guide.gd")
					G2.wrecks(w.level_id)[G2.section_at(w.level, float(w.state.x))] = 98
					w.bot = null
					w._air_x = float(w.state.x)
					w.state.death = "fall"
					w._crash()
				elif parts.size() > 3 and parts[3] == "guide":
					# Wreck here enough times for a hint, respawn, then ride the hint line
					# for N frames (game:<id>:x<x>:guide:<N>).
					var G = load("res://scripts/game/guide.gd")
					w._air_x = float(w.state.x)
					w.state.death = "fall"
					G.wrecks(w.level_id)[G.section_at(w.level, float(w.state.x))] = 99
					w.bot = null
					w.hint_sync = true
					G.Rider.debug = true
					w._hint_check()
					G.Rider.debug = false
					w.state = w._respawn_state(w.level)
					w.guide_since = w.ride_time
					var rp := GuideReplay.new()
					rp.g = w.guide
					w.bot = rp
					w.phase = "ride"
					for i in int(parts[4]) if parts.size() > 4 else 0:
						w.tick()
					print("GUIDE tip=%s ok=%s frames=%d marks=%s" % [w.guide_tip, not w.guide.is_empty(),
						(w.guide.get("pts", PackedVector2Array()) as PackedVector2Array).size(), str(w.guide.get("marks", []))])
				# Let the visuals catch up (_vis_t, camera smoothing) on the frozen frame.
				w._vis_t += 1.0
				if parts.size() > 3 and parts[3] == "pause":
					w.bot = null
					gs.pause()
				elif parts.size() > 3 and parts[3] == "hint":
					w.bot = null
					gs.show_hint()
				elif parts.size() > 3 and parts[3] == "guidethread":
					pass  # keeps running
				else:
					w._acc = -1.0e9  # freeze the sim; visuals keep drawing
		"garage":
			main.navigate("garage", "")
			await get_tree().process_frame
			if parts.size() > 1:
				main.current._tabs[parts[1]].button_pressed = true
				main.current._set_tab(parts[1])
		"settings":
			GameState.set_volume("sound", 0.8, false)
			GameState.set_volume("engine", 0.7, false)
			main.navigate("title", "")
			await get_tree().process_frame
			main.current._open_settings()
		"setup":
			main.navigate("levels", "")
			await get_tree().process_frame
			main.current._show_setup(parts[1])
		"story_intro":
			main.navigate("story_intro", "")
			await get_tree().process_frame
			if parts.size() > 1:
				main.current._show(int(parts[1]))
				main.current._t = 2.0
		"story_card":
			main.navigate("story", "")
			await get_tree().process_frame
			main.current._show_card(parts[1])
		"tips":
			main.navigate("levels", "")
			await get_tree().process_frame
			main.current._show_setup(parts[1])
			main.current._show_hint(parts[1])
			if parts.size() > 2:
				main.current._hint.get_child(1).get_child(0)._show_page(int(parts[2]))
		_:
			main.navigate(parts[0], "")
	var frames := 10
	for a in args:
		if a.begins_with("--frames="):
			frames = int(a.substr(9))
	for i in frames:
		await get_tree().process_frame
	if "--ghost" in args and main.current.get("world") != null:
		var gw = main.current.world
		print("GHOST at ride_time=%.2f rider_x=%.1f ghost_vis=%s pos=%s" % [gw.ride_time, gw.state.x, gw._ghost_view.visible, gw._ghost_view.position])
	var img := get_viewport().get_texture().get_image()
	img.save_png(out)
	print("SHOT saved ", out, " ", img.get_size())
	get_tree().quit()


## Plays a hint line's button presses back frame by frame (the sim is deterministic,
## so the bike follows the dots exactly).
class GuideReplay:
	var g: Dictionary
	var i := 0

	func decide(_s: Dictionary) -> Array:
		i += 1
		var hd: PackedByteArray = g.get("held", PackedByteArray())
		return [(g.get("taps", PackedInt32Array()) as PackedInt32Array).has(i), i < hd.size() and hd[i] == 1]
