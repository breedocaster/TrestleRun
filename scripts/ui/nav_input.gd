## Keyboard and gamepad on top of the touch UI (the Steam builds, and any pad on a
## phone). Lives beside the screens with PROCESS_MODE_ALWAYS so it also works over a
## paused run.
##   F11 or Alt+Enter: fullscreen on/off (desktop).
##   Esc or B on a pad: back (game screens handle their own pause).
##   Arrow keys, d-pad, stick or A on a pad: buttons take focus and can be stepped
##   through; until then they stay focus-free so a tap never leaves a ring behind.
extends Node

const GameScreen := preload("res://scripts/screens/game_screen.gd")
const StoryIntro := preload("res://scripts/screens/story_intro.gd")
const NAV := ["ui_up", "ui_down", "ui_left", "ui_right"]

var main: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_viewport().gui_focus_changed.connect(_on_focus)


## In a run (not paused, no results up): no menu focus, so Space and A always jump.
func _riding() -> bool:
	var cur: Node = main.current
	if cur == null or get_tree().paused:
		return false
	if cur.has_method("is_riding"):
		return cur.is_riding()
	if cur.get_script() != GameScreen:
		return false
	var w = cur.get("world")
	return w != null and (w.result as Dictionary).is_empty()


func _process(_delta: float) -> void:
	if _riding():
		var f := get_viewport().gui_get_focus_owner()
		if f != null:
			f.release_focus()


func _input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event is InputEventKey and (event.physical_keycode == KEY_F11 or
			(event.physical_keycode == KEY_ENTER and event.alt_pressed)):
		if GameState.is_desktop():
			GameState.set_flag("fullscreen", not GameState.flag("fullscreen"))
			GameState.apply_display()
			get_viewport().set_input_as_handled()
		return
	var cur: Node = main.current
	if cur == null or _riding() or cur.get_script() == StoryIntro:
		return
	var nav := false
	for a in NAV:
		nav = nav or event.is_action_pressed(a)
	var pad_a: bool = event is InputEventJoypadButton and event.button_index == JOY_BUTTON_A
	if not (nav or pad_a):
		return
	var top := _top_layer(cur)
	var f := get_viewport().gui_get_focus_owner()
	if f != null and f.is_visible_in_tree() and top != null and top.is_ancestor_of(f):
		# Already navigating in the right place: A presses (the GUI does that); a
		# direction moves to the nearest button that way. Godot's own search tends
		# to jump to a wide button above (CONTINUE) instead of the one alongside.
		if nav and f is Button:
			var dir := Vector2.ZERO
			if event.is_action_pressed("ui_up"):
				dir = Vector2.UP
			elif event.is_action_pressed("ui_down"):
				dir = Vector2.DOWN
			elif event.is_action_pressed("ui_left"):
				dir = Vector2.LEFT
			elif event.is_action_pressed("ui_right"):
				dir = Vector2.RIGHT
			var nxt := _neighbor(top, f, dir)
			if nxt != null:
				nxt.grab_focus()
			get_viewport().set_input_as_handled()
		return
	if top == null:
		return
	_focusable(top)
	var first := _first_button(top)
	if first != null:
		first.grab_focus()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	var cur: Node = main.current
	if cur == null or cur.get_script() == GameScreen:
		return  # the run has its own pause / resume
	if cur.has_method("on_back"):
		cur.on_back()
		get_viewport().set_input_as_handled()


## Where focus belongs: an open panel (a full-screen Control whose first child is the
## dimming ColorRect, added after the screen's own UI), or else the whole screen.
func _top_layer(cur: Node) -> Control:
	var kids := cur.get_children()
	for i in range(kids.size() - 1, -1, -1):
		var k = kids[i]
		if k is Control and k.is_visible_in_tree() and k.get_child_count() > 0 \
				and k.get_child(0) is ColorRect and _first_button(k) != null:
			return k
	return cur if cur is Control else null


func _focusable(root: Node) -> void:
	for c in root.get_children():
		if c is Button:
			c.focus_mode = Control.FOCUS_ALL
		_focusable(c)


## The button nearest the middle of the screen (CONTINUE / STORY on the title, RETRY on
## a results panel), not the little ones along the top.
func _first_button(root: Node) -> Button:
	var mid := get_viewport().get_visible_rect().size * 0.5
	var best: Button = null
	var bd := INF
	for b in _buttons(root):
		var d: float = (b.get_global_rect().get_center() - mid).length()
		if d < bd:
			bd = d
			best = b
	return best


## The button that way: ahead along the direction, scored by distance ahead plus
## three times the sideways offset, so one in line beats a nearer one off to the side.
func _neighbor(top: Node, from: Control, dir: Vector2) -> Button:
	var r0 := from.get_global_rect()
	var c0 := r0.get_center()
	var best: Button = null
	var bs := INF
	for b in _buttons(top):
		if b == from:
			continue
		var r: Rect2 = b.get_global_rect()
		var d: Vector2 = r.get_center() - c0
		var ahead := d.dot(dir)
		# Overlapping sideways counts as in line (a wide button above two narrow ones).
		var side: float
		if dir.x == 0.0:
			side = maxf(0.0, maxf(r.position.x - r0.end.x, r0.position.x - r.end.x))
			if r.end.y <= r0.position.y + 1.0 and dir.y < 0.0 or r.position.y >= r0.end.y - 1.0 and dir.y > 0.0:
				ahead = maxf(ahead, 1.0)
			else:
				continue
		else:
			side = maxf(0.0, maxf(r.position.y - r0.end.y, r0.position.y - r.end.y))
			if r.end.x <= r0.position.x + 1.0 and dir.x < 0.0 or r.position.x >= r0.end.x - 1.0 and dir.x > 0.0:
				ahead = maxf(ahead, 1.0)
			else:
				continue
		var score := ahead + 3.0 * side
		if score < bs:
			bs = score
			best = b
	return best


func _buttons(root: Node) -> Array:
	var out := []
	for c in root.get_children():
		if c is Button and c.is_visible_in_tree() and not c.disabled:
			out.append(c)
		out.append_array(_buttons(c))
	return out


## Keep the focused button on screen inside scrolling lists.
func _on_focus(c: Control) -> void:
	var p := c.get_parent()
	while p != null:
		if p is ScrollContainer:
			p.ensure_control_visible(c)
			return
		p = p.get_parent()
