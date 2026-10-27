## --nav-test: the keyboard / pad layer (scripts/ui/nav_input.gd). Opens the title,
## presses d-pad down and A like a pad would, and checks a button took focus, focus
## moves, A presses it, and B / Esc comes back; then that a run never holds focus.
extends Node

var main: Node
var fails := 0


func _key(code: Key) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = true
	Input.parse_input_event(e)
	await get_tree().process_frame
	e = e.duplicate()
	e.pressed = false
	Input.parse_input_event(e)
	await get_tree().process_frame


func _pad(b: JoyButton) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	e.pressed = true
	Input.parse_input_event(e)
	await get_tree().process_frame
	e = e.duplicate()
	e.pressed = false
	Input.parse_input_event(e)
	await get_tree().process_frame


func _focus() -> String:
	var f := get_viewport().gui_get_focus_owner()
	return f.text if f is Button else "-"


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _ready() -> void:
	main.navigate("title", "")
	for i in 5:
		await get_tree().process_frame
	_check(_focus() == "-", "nothing focused before a pad is used (%s)" % _focus())
	await _pad(JOY_BUTTON_DPAD_DOWN)
	var first := _focus()
	_check(first != "-", "d-pad gives a button focus: " + first)
	await _pad(JOY_BUTTON_DPAD_DOWN)
	var second := _focus()
	_check(second != "-" and second != first, "d-pad down moves focus: " + second)
	# Find FREE RIDE and press it with A.
	for i in 8:
		if _focus() == "FREE RIDE":
			break
		await _pad(JOY_BUTTON_DPAD_RIGHT if i % 2 == 0 else JOY_BUTTON_DPAD_DOWN)
	_check(_focus() == "FREE RIDE", "can reach FREE RIDE (at %s)" % _focus())
	await _pad(JOY_BUTTON_A)
	for i in 3:
		await get_tree().process_frame
	_check(main.current.get_script() == main.Levels, "A opens the trail picker")
	await _pad(JOY_BUTTON_DPAD_DOWN)
	_check(_focus() != "-", "the trail picker takes focus too: " + _focus())
	await _pad(JOY_BUTTON_B)
	for i in 3:
		await get_tree().process_frame
	_check(main.current.get_script() == main.Title, "B goes back to the title")
	await _key(KEY_ESCAPE)
	for i in 3:
		await get_tree().process_frame
	var quit_panel := false
	for c in main.current.get_children():
		if c is Control and c.get_child_count() > 0 and c.get_child(0) is ColorRect:
			quit_panel = true
	_check(quit_panel == GameState.is_desktop(), "Esc on the title asks to quit on a PC")
	await _key(KEY_ESCAPE)
	main.navigate("game", "dusty_trail")
	for i in 5:
		await get_tree().process_frame
	await _pad(JOY_BUTTON_DPAD_DOWN)
	_check(_focus() == "-", "no focus in a run, so A and Space jump (%s)" % _focus())
	# SUMMIT: the card's RIDE takes focus, A starts the climb, the pedals are the
	# triggers and keys, nothing holds focus while riding, B pauses and B resumes.
	main.navigate("drive_select", "summit")
	for i in 5:
		await get_tree().process_frame
	await _pad(JOY_BUTTON_DPAD_DOWN)
	_check(_focus() != "-", "the SUMMIT picker takes focus: " + _focus())
	for i in 6:
		if _focus() == "RIDE":
			break
		await _pad(JOY_BUTTON_DPAD_UP)
	_check(_focus() == "RIDE", "can reach RIDE (at %s)" % _focus())
	await _pad(JOY_BUTTON_A)
	for i in 5:
		await get_tree().process_frame
	_check(main.current.has_method("is_riding") and main.current.is_riding(), "A starts the climb")
	await _pad(JOY_BUTTON_DPAD_DOWN)
	_check(_focus() == "-", "no focus while riding (%s)" % _focus())
	var rt := InputEventJoypadMotion.new()
	rt.axis = JOY_AXIS_TRIGGER_RIGHT
	rt.axis_value = 1.0
	Input.parse_input_event(rt)
	for i in 30:
		await get_tree().process_frame
	_check(main.current.world.gas > 0.5 and main.current.world.sim.pos.x > 5.0,
		"the right trigger is gas (x=%.0f)" % main.current.world.sim.pos.x)
	rt = rt.duplicate()
	rt.axis_value = 0.0
	Input.parse_input_event(rt)
	await _pad(JOY_BUTTON_B)
	for i in 3:
		await get_tree().process_frame
	_check(get_tree().paused, "B pauses the climb")
	await _pad(JOY_BUTTON_B)
	for i in 3:
		await get_tree().process_frame
	_check(not get_tree().paused and main.current.is_riding(), "B again resumes")
	get_tree().paused = false
	print("NAV_TEST %s (%d failed)" % ["OK" if fails == 0 else "FAILED", fails])
	get_tree().quit(fails)
