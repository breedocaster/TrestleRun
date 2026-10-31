## HUD for SUMMIT and GAUNTLET: coins, the fuel / charge gauge (SUMMIT), the time and
## faults (GAUNTLET), a progress bar to the finish, the pause button, and the pedals:
## on a touch screen the left half of the screen is BRAKE and the right half GAS (both
## at once is fine); keys and pads go straight to the world.
extends Control

signal pause_pressed

const Kit := preload("res://scripts/ui/kit.gd")
const UITheme := preload("res://scripts/ui/ui_theme.gd")
const Icons := preload("res://scripts/game/icons.gd")

var world: Node2D
var _touches := {}       # touch index -> "gas" / "brake"
var _pause: Button
var _t := 0.0
var show_pedals := true


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	theme = GameState.theme
	_pause = Kit.button("II", 26, 22)
	_pause.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_pause.offset_left = -32
	_pause.offset_right = -6
	_pause.offset_top = 6
	_pause.offset_bottom = 28
	_pause.pressed.connect(func(): pause_pressed.emit())
	add_child(_pause)
	show_pedals = DisplayServer.is_touchscreen_available() or not GameState.is_desktop()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _input(e: InputEvent) -> void:
	if world == null:
		return
	var idx := -100
	var pos := Vector2.ZERO
	var down := false
	if e is InputEventScreenTouch:
		idx = e.index
		pos = e.position
		down = e.pressed
	elif e is InputEventScreenDrag:
		idx = e.index
		pos = e.position
		down = true
	elif e is InputEventMouseButton and e.device != InputEvent.DEVICE_ID_EMULATION and e.button_index == MOUSE_BUTTON_LEFT:
		idx = -1
		pos = e.position
		down = e.pressed
	elif e is InputEventMouseMotion and e.device != InputEvent.DEVICE_ID_EMULATION and _touches.has(-1):
		idx = -1
		pos = e.position
		down = true
	else:
		return
	if down and _pause.get_global_rect().grow(6.0).has_point(pos) and not _touches.has(idx):
		return
	if down:
		_touches[idx] = "gas" if pos.x >= size.x * 0.5 else "brake"
	else:
		_touches.erase(idx)
	world.touch_gas = _touches.values().has("gas")
	world.touch_brake = _touches.values().has("brake")


func release_all() -> void:
	_touches.clear()
	if world:
		world.touch_gas = false
		world.touch_brake = false


func _text(p: Vector2, s: String, c := UITheme.CREAM, sz := 8) -> void:
	var f: Font = GameState.font
	draw_string(f, p + Vector2(1, 1), s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(0, 0, 0, 0.6))
	draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, c)


func _center(y: float, s: String, c := UITheme.CREAM, sz := 8) -> void:
	var w := GameState.font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	_text(Vector2(floorf((size.x - w) * 0.5), y), s, c, sz)


func _draw() -> void:
	if world == null or world.sim == null:
		return
	var lv: Dictionary = world.level
	# Coins.
	draw_rect(Rect2(6, 6, 58, 16), Color(UITheme.INK, 0.75))
	Icons.coin(self, Vector2(15, 14), 1.0)
	_text(Vector2(23, 18), "%04d" % world.coins, UITheme.GOLD)
	# Progress to the finish.
	var bw := minf(220.0, size.x - 180.0)
	var bx := floorf((size.x - bw) * 0.5)
	var p := clampf(float(world.sim.pos.x) / float(lv.finish_x), 0.0, 1.0)
	draw_rect(Rect2(bx - 1, 9, bw + 2, 5), Color(UITheme.INK, 0.8))
	draw_rect(Rect2(bx, 10, bw * p, 3), UITheme.GOLD)
	for c in lv.get("checkpoints", []):
		var cx := bx + bw * clampf(float(c) / float(lv.finish_x), 0.0, 1.0)
		draw_rect(Rect2(floorf(cx), 8, 1, 7), Color("5bd16a"))
	draw_rect(Rect2(bx + bw - 1, 7, 2, 9), Color("f4f4f4"))
	var ek := String(world.ev.get("kind", ""))
	if ek == "long_jump":
		_center(26, "JUMP %.1f M" % world.jump_m if world.jump_m >= 0.0 else "HIT THE RAMP FLAT OUT!",
			UITheme.GOLD if world.jump_m >= 0.0 else UITheme.CREAM)
	elif ek == "fuel_saver":
		_center(26, "%d M" % int(world.best_x / 8.0))
		_fuel_gauge()
	elif world.mode == "summit":
		_center(26, "%d M / %d M" % [int(world.best_x / 8.0), int(float(lv.finish_x) / 8.0)])
		_fuel_gauge()
	elif ek == "trick_attack":
		var left := maxf(0.0, float(world.ev.get("time_limit", 60.0)) - world.ride_time)
		_center(26, "%d:%02d LEFT" % [int(left / 60.0), int(left) % 60], Color("ff6a5a") if left < 10.0 else UITheme.CREAM)
	else:
		var t: float = world.ride_time
		_center(26, "%d:%04.1f" % [int(t / 60.0), fmod(t, 60.0)], UITheme.CREAM, 8)
	if ek == "collect":
		var n: int = (lv.get("items", []) as Array).size()
		const Art := preload("res://scripts/drive/drive_art.gd")
		Art.item(self, Vector2(size.x - 52, 40), String(world.ev.get("item", "star")), 0.0)
		_text(Vector2(size.x - 44, 44), "%d/%d" % [world.items_got, n], UITheme.GOLD)
	if world.mode == "gauntlet":
		var fc := Color("ff6a5a") if world.faults > 0 else UITheme.DIM
		_text(Vector2(6, 38), "FAULTS %d" % world.faults, fc)
		if world.trick_pts > 0:
			_text(Vector2(6, 50), "TRICKS %d" % world.trick_pts, UITheme.GOLD)
	if world.phase == "crash" and world.mode == "summit":
		var why := "OUT OF FUEL" if world.result.get("reason", "") == "fuel" else "WIPEOUT!"
		_center(size.y * 0.4, why, Color("ff6a5a"), 16)
	elif world.phase == "crash":
		_center(size.y * 0.4, "FAULT!", Color("ff6a5a"), 16)
	if world.tip_t > 0.0 and world.tip_text != "":
		var a := clampf(world.tip_t, 0.0, 1.0)
		var w := GameState.font.get_string_size(world.tip_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var r := Rect2(floorf((size.x - w) * 0.5) - 6, 46, w + 12, 16)
		draw_rect(r, Color(UITheme.INK, 0.8 * a))
		draw_rect(r, Color(UITheme.GOLD, a), false, 1.0)
		_center(58, world.tip_text, Color(UITheme.CREAM, a))
	_combo(70.0 if world.tip_t > 0.0 else 48.0)
	# The level's objectives as the ride starts.
	if world.ride_time < 4.0 and world.phase == "ride" and not world.objectives.is_empty():
		var a := clampf(4.0 - world.ride_time, 0.0, 1.0)
		var y: float = 92.0
		for o in world.objectives:
			_center(y, String(o), Color(UITheme.CREAM, a))
			y += 11.0
	if show_pedals:
		_pedal(Rect2(6, size.y - 50, 56, 44), "BRAKE", world.brake > 0.5, false)
		_pedal(Rect2(size.x - 62, size.y - 50, 56, 44), "GAS", world.gas > 0.5, true)
	elif world.ride_time < 6.0 and world.mode != "":
		_center(size.y - 12, "GAS: RIGHT / D / RT     BRAKE: LEFT / A / LT", Color(UITheme.CREAM, 0.7))


## The air-trick combo as it builds (tricks.gd): the last few names, the multiplier,
## and what it's worth if you land it.
func _combo(y: float) -> void:
	var tk = world.tricks
	if tk.combo.is_empty() and tk.active.is_empty():
		return
	var names: Array = tk.combo.map(func(e): return String(e[1]))
	if not tk.active.is_empty():
		names.append(String(tk.active.name) + "!")
	if names.size() > 3:
		names = ["..."] + names.slice(names.size() - 3)
	_center(y, " + ".join(names), UITheme.GOLD)
	if tk.combo.size() > 0:
		var v: Array = tk.value()
		var worth := "+%d COINS" % int(v[0]) if world.mode == "summit" else "+%d" % int(v[1])
		var m: float = tk.multiplier(tk.combo.size())
		_center(y + 11.0, ("X%s  " % String.num(m, 2).trim_suffix("0").trim_suffix(".") if m > 1.0 else "") + worth, UITheme.CREAM)


func _fuel_gauge() -> void:
	var f: float = world.fuel / maxf(world.tank, 0.01)
	var x := 6.0
	var y := 26.0
	draw_rect(Rect2(x, y, 58, 12), Color(UITheme.INK, 0.75))
	var low := f < 0.25
	var col := Color("4ad06a") if world.electric else Color("f0c040")
	if low:
		col = Color("ff5a4a") if int(_t * 4.0) % 2 == 0 else Color("8a2a24")
	if world.electric:
		draw_rect(Rect2(x + 3, y + 3, 9, 6), Color("2a2f3a"))
		draw_rect(Rect2(x + 12, y + 5, 1, 2), Color("2a2f3a"))
		draw_rect(Rect2(x + 4, y + 4, 7.0 * f, 4), col)
	else:
		draw_rect(Rect2(x + 3, y + 2, 7, 8), Color("c8323c"))
		draw_rect(Rect2(x + 7, y + 1, 3, 2), Color("2a2a2e"))
	draw_rect(Rect2(x + 16, y + 4, 38, 4), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(x + 16, y + 4, 38.0 * f, 4), col)
	if low:
		_text(Vector2(x, y + 22), "LOW CHARGE" if world.electric else "LOW FUEL", col)


func _pedal(r: Rect2, label: String, on: bool, right: bool) -> void:
	draw_rect(r, Color(UITheme.INK, 0.45 if not on else 0.7))
	var edge := UITheme.GOLD if on else Color(UITheme.CREAM, 0.35)
	draw_rect(r, edge, false, 1.0)
	var c := r.get_center() + Vector2(0, -5)
	var d := 1.0 if right else -1.0
	draw_colored_polygon(PackedVector2Array([c + Vector2(-6 * d, -7), c + Vector2(8 * d, 0), c + Vector2(-6 * d, 7)]),
		edge)
	var w := GameState.font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	_text(Vector2(floorf(r.get_center().x - w * 0.5), r.end.y - 5), label, edge)
