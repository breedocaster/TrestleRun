## Root: swaps screens and handles the Android back button.
## Dev flags (after `--`): --verify, --shot=<spec> --out=<png>.
extends Node

const Title := preload("res://scripts/screens/title_screen.gd")
const Levels := preload("res://scripts/screens/level_select.gd")
const Garage := preload("res://scripts/screens/garage.gd")
const GameScreen := preload("res://scripts/screens/game_screen.gd")
const Credits := preload("res://scripts/screens/credits.gd")
const StoryMap := preload("res://scripts/screens/story_map.gd")
const StoryIntro := preload("res://scripts/screens/story_intro.gd")
const AchievementsScreen := preload("res://scripts/screens/achievements_screen.gd")
const ChallengesScreen := preload("res://scripts/screens/challenges_screen.gd")
const SeasonScreen := preload("res://scripts/screens/season_screen.gd")

var current: Node


func _ready() -> void:
	get_tree().set_quit_on_go_back(false)
	var nav = load("res://scripts/ui/nav_input.gd").new()
	nav.main = self
	add_child(nav)
	var args := OS.get_cmdline_user_args()
	# Dev runs: if any game script fails to compile, quit instead of hanging headless.
	if args.size() > 0 and args[0].begins_with("--") and args[0] != "--input-test":
		for path in ["res://scripts/game/world.gd", "res://scripts/game/bike_physics.gd", "res://scripts/game/level_library.gd",
				"res://scripts/game/autopilot.gd", "res://scripts/dev/demo.gd", "res://scripts/dev/probe.gd"]:
			var sc = load(path)
			if sc == null or not sc.can_instantiate():
				push_error("DEV: script failed to load: " + path)
				get_tree().quit(3)
				return
	for a in args:
		if a == "--verify":
			add_child(load("res://scripts/dev/verify.gd").new())
			return
		if a.begins_with("--demo="):
			var d = load("res://scripts/dev/demo.gd").new()
			d.main = self
			d.spec = a.substr(7)
			add_child(d)
			return
		if a == "--difficulty":
			add_child(load("res://scripts/dev/difficulty.gd").new())
			return
		if a == "--par":
			add_child(load("res://scripts/dev/par.gd").new())
			return
		if a == "--place-letters":
			add_child(load("res://scripts/dev/place_letters.gd").new())
			return
		if a == "--parse":
			# Load every script (with the autoloads up) and list the ones that fail.
			var bad := 0
			var stack := ["res://scripts"]
			while not stack.is_empty():
				var dir: String = stack.pop_back()
				var da := DirAccess.open(dir)
				for sub in da.get_directories():
					stack.append(dir + "/" + sub)
				for f in da.get_files():
					if f.ends_with(".gd"):
						var sc = load(dir + "/" + f)
						if sc == null or not sc.can_instantiate():
							print("PARSE FAILED ", dir + "/" + f)
							bad += 1
			print("PARSE %d failed" % bad)
			get_tree().quit(bad)
			return
		if a == "--course-calibrate":
			add_child(load("res://scripts/dev/course_calibrate.gd").new())
			return
		if a == "--drive-levels":
			add_child(load("res://scripts/dev/drive_levels.gd").new())
			return
		if a == "--drive-physics":
			add_child(load("res://scripts/dev/drive_check.gd").new())
			return
		if a == "--nav-test":
			var nt = load("res://scripts/dev/nav_test.gd").new()
			nt.main = self
			add_child(nt)
			return
		if a == "--ach-test":
			add_child(load("res://scripts/dev/ach_test.gd").new())
			return
		if a.begins_with("--ach-export="):
			add_child(load("res://scripts/dev/ach_export.gd").new())
			return
		if a == "--endless-check" or a == "--endless-stats" or a.begins_with("--endless-ride=") or a.begins_with("--pair="):
			add_child(load("res://scripts/dev/endless_check.gd").new())
			return
		if a == "--guide-test":
			add_child(load("res://scripts/dev/guide_test.gd").new())
			return
		if a == "--probe":
			add_child(load("res://scripts/dev/probe.gd").new())
			return
		if a == "--physics-report":
			add_child(load("res://scripts/dev/physics_report.gd").new())
			return
		if a == "--input-test":
			var it = load("res://scripts/dev/input_test.gd").new()
			it.main = self
			add_child(it)
			return
		if a.begins_with("--shot="):
			var shots = load("res://scripts/dev/shots.gd").new()
			shots.main = self
			shots.args = args
			add_child(shots)
			return
	navigate("title", "")


func navigate(target: String, arg: String) -> void:
	get_tree().paused = false
	var n: Node
	match target:
		"levels":
			n = Levels.new()
		"garage":
			n = Garage.new()
		"game":
			n = GameScreen.new()
			n.setup(arg)
		"credits":
			n = Credits.new()
		"story":
			n = StoryMap.new()
		"story_intro":
			n = StoryIntro.new()
		"achievements":
			n = AchievementsScreen.new()
		"challenges":
			n = ChallengesScreen.new()
			n.focus = arg
		"season":
			n = SeasonScreen.new()
		"drive_select":
			n = load("res://scripts/screens/drive_select.gd").new()
			n.setup(arg)
		"drive":
			n = load("res://scripts/screens/drive_screen.gd").new()
			n.setup(arg)
		_:
			n = Title.new()
	if current:
		# Detach first so the old screen's _exit_tree (audio cleanup) runs before
		# the new screen's _ready, e.g. on RETRY / NEXT.
		remove_child(current)
		current.queue_free()
	current = n
	n.navigate.connect(navigate)
	add_child(n)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if current and current.has_method("on_back"):
			current.on_back()
		else:
			get_tree().quit()
