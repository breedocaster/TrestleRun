## Feeds real touch events through the input pipeline and checks the rider jumps,
## that a short tap hops lower than a long hold, and that the pause and "?" buttons don't jump.
extends Node

var main: Node


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mode="):
			mode = a.substr(7)
	print("INPUT mode=", mode)
	await get_tree().process_frame
	main.navigate("game", "dusty_trail")
	await get_tree().process_frame
	var gs = main.current
	var w = gs.world
	while w.phase != "ride":
		await get_tree().process_frame
	var tap := await _jump_peak(w, 2)
	await _wait_grounded(w)
	var hold := await _jump_peak(w, 30)
	await _wait_grounded(w)
	# Tap the pause button (top-right) and confirm no jump was queued.
	var vs := get_viewport().get_visible_rect().size
	_touch(Vector2(vs.x - 20, 16), true)
	await get_tree().process_frame
	_touch(Vector2(vs.x - 20, 16), false)
	await get_tree().process_frame
	var paused := get_tree().paused
	var queued: bool = w.press_queued
	gs.resume()
	await get_tree().process_frame
	# Same for the "?" hint button: opens the hint card, no jump.
	_touch(Vector2(vs.x - 55, 16), true)
	await get_tree().process_frame
	_touch(Vector2(vs.x - 55, 16), false)
	await get_tree().process_frame
	var hint_open: bool = get_tree().paused and gs._overlay != null
	var queued2: bool = w.press_queued
	print("INPUT tap_peak=%.1f hold_peak=%.1f pause_opened=%s hint_opened=%s jump_leaked=%s" % [tap, hold, paused, hint_open, queued or queued2])
	var ok := tap > 10.0 and hold > tap + 15.0 and paused and hint_open and not queued and not queued2
	print("INPUT_RESULT ", "PASS" if ok else "FAIL")
	get_tree().paused = false
	get_tree().quit(0 if ok else 1)


var mode := "touch"


## pos is in the 480x270-style viewport space; events arrive in window pixels.
func _touch(vp_pos: Vector2, pressed: bool) -> void:
	var pos: Vector2 = get_tree().root.get_final_transform() * vp_pos
	if mode == "touch":
		var ev := InputEventScreenTouch.new()
		ev.index = 0
		ev.position = pos
		ev.pressed = pressed
		Input.parse_input_event(ev)
	else:
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.position = pos
		mb.global_position = pos
		mb.pressed = pressed
		mb.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		if mode == "push":
			get_viewport().push_input(mb)
		else:
			Input.parse_input_event(mb)


func _jump_peak(w, frames: int) -> float:
	var vs := get_viewport().get_visible_rect().size
	var p := vs * Vector2(0.5, 0.6)
	var y0: float = w.state.y
	_touch(p, true)
	var peak := 0.0
	for i in 90:
		await get_tree().process_frame
		if i == frames:
			_touch(p, false)
		peak = maxf(peak, y0 - float(w.state.y))
		if i > frames and w.state.grounded:
			break
	return peak


func _wait_grounded(w) -> void:
	for i in 120:
		await get_tree().process_frame
		if w.state.grounded:
			return
