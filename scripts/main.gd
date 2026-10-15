## Root: swaps screens and handles the Android back button.
## Dev flags (after `--`): --verify, --shot=<spec> --out=<png>.
extends Node

const Title := preload("res://scripts/screens/title_screen.gd")
const Levels := preload("res://scripts/screens/level_select.gd")
const Garage := preload("res://scripts/screens/garage.gd")
const GameScreen := preload("res://scripts/screens/game_screen.gd")
const Credits := preload("res://scripts/screens/credits.gd")

var current: Node


func _ready() -> void:
	get_tree().set_quit_on_go_back(false)
	var args := OS.get_cmdline_user_args()
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
