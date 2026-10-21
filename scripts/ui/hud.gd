## In-run HUD: coins, gears, progress, pause. Taps anywhere else fall through as jumps.
extends Control

signal pause_pressed
signal hint_pressed

const Icons := preload("res://scripts/game/icons.gd")
const UITheme := preload("res://scripts/ui/ui_theme.gd")
const Kit := preload("res://scripts/ui/kit.gd")
const Phys := preload("res://scripts/game/bike_physics.gd")
const BossArt := preload("res://scripts/game/boss_art.gd")

var world: Node2D
var show_hint := false
## Built courses (endless, daily, league): no "?" card, there's no one feature to explain.
var no_help := false
## This trail's new feature; on a first visit the "?" button pulses for a while.
var feature := ""
var feature_new := false
var ability_title := ""
var _t := 0.0
var _hint_btn: Button
var _has_letters := -1
## Endless and league: your best to beat, and (league) the rivals' distances
## [[name, metres], ...] best last, for the "next up" readout.
var best_m := 0
var rivals: Array = []


func _ready() -> void:
	Kit.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pb := Kit.button("II", 30, 26)
	pb.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pb.offset_left = -36
	pb.offset_top = 4
	pb.offset_right = -6
	pb.offset_bottom = 30
	pb.pressed.connect(func(): pause_pressed.emit())
	add_child(pb)
	var hb := Kit.button("?", 30, 26)
	hb.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	hb.offset_left = -70
	hb.offset_top = 4
	hb.offset_right = -40
	hb.offset_bottom = 30
	hb.pressed.connect(func(): hint_pressed.emit())
	add_child(hb)
	_hint_btn = hb
	hb.visible = not no_help


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if world == null:
		return
	var font: Font = GameState.font
	# Coins.
	draw_rect(Rect2(4, 4, 58, 18), Color(UITheme.INK, 0.75))
	Icons.coin(self, Vector2(13, 13), cos(_t * 4.0))
	_text(font, Vector2(22, 17), "%03d" % world.run_coins, UITheme.CREAM)
	# Gears: bright = this run, dim outline = found on an earlier run.
	var n: int = world.gears.size()
	draw_rect(Rect2(66, 4, n * 14 + 6, 18), Color(UITheme.INK, 0.75))
	for i in n:
		var p := Vector2(76 + i * 14, 13)
		if world.gears[i]:
			Icons.gear(self, p, 4.5, _t * 2.0, true)
		else:
			Icons.gear(self, p, 4.5, 0.0, false, 1.0 if world.known_gears[i] else 0.55)
	# Conditions: rain drop / live wind gauge.
	var wx: String = world.cond.weather
	if wx != "clear":
		var bx := 66.0 + n * 14 + 10.0
		draw_rect(Rect2(bx, 4, 30, 18), Color(UITheme.INK, 0.75))
		if wx == "rain":
			for i in 3:
				var dx := bx + 6 + i * 8
				var dy := 8.0 + fmod(_t * 14.0 + i * 3.0, 8.0)
				draw_rect(Rect2(dx, dy, 2, 3), Color("8fc7ff"))
		else:
			var gust: float = Phys.wind_at(world.level, world.state.t) / Phys.WIND_PEAK
			draw_line(Vector2(bx + 4, 10), Vector2(bx + 14, 10), UITheme.CREAM, -1.0)
			draw_colored_polygon(PackedVector2Array([Vector2(bx + 3, 10), Vector2(bx + 6, 7), Vector2(bx + 6, 13)]), UITheme.CREAM)
			for i in 4:
				var on := gust > (i + 0.5) / 4.0
				draw_rect(Rect2(bx + 17 + i * 3, 15 - i * 2, 2, 3 + i * 2), UITheme.GOLD if on else Color("4a4058"))
	# T-R-E-S-T-L-E letters found this run.
	var word := "TRESTLE"
	if _has_letters < 0:
		_has_letters = 1 if world.level.pickups.any(func(p): return int(p.type) == 3) else 0
	if _has_letters == 1:
		draw_rect(Rect2(4, 25, 7 * 12 + 4, 14), Color(UITheme.INK, 0.6))
		for i in word.length():
			var lit: bool = world.letters & (1 << i)
			_mini_letter(font, Vector2(6 + i * 12, 26), word[i], lit)
	# Power-ups: an icon and a draining bar for each one running; the hard hat waits.
	var st: Dictionary = world.state
	var py := 46.0
	for k in [["sticky", "sticky_t", Phys.STICKY_T], ["rocket", "rocket_t", Phys.ROCKET_T], ["magnet", "magnet_t", Phys.MAGNET_T]]:
		var left := float(st[k[1]])
		if left <= 0.0:
			continue
		var frac := left / float(k[2])
		var blink := left > 1.5 or int(_t * 8.0) % 2 == 0
		draw_rect(Rect2(4, py - 7, 52, 14), Color(UITheme.INK, 0.6))
		if blink:
			Icons.power(self, Vector2(12, py), String(k[0]), _t, false)
		draw_rect(Rect2(21, py - 2, 32, 4), Color("2a2434"))
		draw_rect(Rect2(21, py - 2, 32 * frac, 4), Color("9fffd0") if String(k[0]) != "rocket" else Color("ffb347"))
		py += 16.0
	if int(st.hat) > 0:
		draw_rect(Rect2(4, py - 7, 18, 14), Color(UITheme.INK, 0.6))
		Icons.hard_hat(self, Vector2(13, py + 2))
	# Progress strip (endless: the distance instead).
	var lv: Dictionary = world.level
	var x0 := maxf(size.x * 0.36, 160.0)
	var x1 := size.x - 82.0
	var y := 12.0
	if world.one_life:
		_distance(font, x0, x1)
	else:
		_progress(lv, x0, x1, y)

	# Boss: its name and a pip per hit still to land.
	_boss(font, lv, x0, x1)
	_overlays(font, lv)


func _distance(font: Font, x0: float, x1: float) -> void:
	var m: int = world.metres()
	var txt := "%d M" % m
	var cx := floorf((x0 + x1) * 0.5)
	var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	draw_rect(Rect2(cx - tw * 0.5 - 6, 4, tw + 12, 20), Color(UITheme.INK, 0.75))
	_text(font, Vector2(cx - tw * 0.5, 21), txt, UITheme.GOLD, 16)
	var sub := ""
	var beat := best_m > 0 and m > best_m
	for r in rivals:
		if int(r[1]) > m:
			sub = "NEXT: %s %d M" % [String(r[0]), int(r[1])]
			break
	if sub == "" and best_m > 0:
		sub = "BEST %d M" % best_m if not beat else "NEW BEST!"
	if sub != "":
		var sw := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		draw_rect(Rect2(cx - sw * 0.5 - 4, 26, sw + 8, 12), Color(UITheme.INK, 0.6))
		_text(font, Vector2(cx - sw * 0.5, 35), sub, UITheme.GOLD if beat else UITheme.CREAM)


func _progress(lv: Dictionary, x0: float, x1: float, y: float) -> void:
	draw_rect(Rect2(x0, y, x1 - x0, 3), Color(UITheme.INK, 0.8))
	var span: float = lv.finish_x - lv.start_x
	var frac := clampf((world.state.x - lv.start_x) / span, 0.0, 1.0)
	draw_rect(Rect2(x0, y, (x1 - x0) * frac, 3), UITheme.GOLD)
	for c in lv.checkpoints:
		var cx: float = x0 + (x1 - x0) * clampf((c.x - lv.start_x) / span, 0.0, 1.0)
		draw_rect(Rect2(cx - 1, y - 2, 2, 7), UITheme.GREEN)
	draw_rect(Rect2(x1 - 1, y - 3, 3, 9), UITheme.CREAM)
	draw_rect(Rect2(x0 + (x1 - x0) * frac - 2, y - 2, 4, 7), UITheme.CREAM)


func _boss(font: Font, lv: Dictionary, x0: float, x1: float) -> void:
	if lv.has("boss"):
		var bname := BossArt.boss_name(String(lv.boss.kind))
		var hp := int(world.state.boss_hp)
		var total := int(lv.boss.hp)
		var bw := font.get_string_size(bname, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + total * 10.0 + 14.0
		var bx := floorf((x0 + x1) * 0.5 - bw * 0.5)
		draw_rect(Rect2(bx, 19, bw, 13), Color(UITheme.INK, 0.75))
		_text(font, Vector2(bx + 4, 29), bname, Color("ff9a6a") if hp > 0 else UITheme.DIM)
		for i in total:
			var px := bx + bw - 6.0 - (total - i) * 10.0 + 4.0
			var on := i < hp
			draw_rect(Rect2(px, 22, 7, 7), Color("5a2030") if on else Color("2a2434"))
			if on:
				draw_rect(Rect2(px + 1, 23, 5, 5), Color("ff5a5a") if int(_t * 6.0) % 4 != 0 or hp > 1 else Color("ffd0d0"))


func _overlays(font: Font, lv: Dictionary) -> void:
	# Crash hint: after a few wrecks in one stretch, a tip (and the dotted line in the world).
	if world.guide_on and world.guide_tip != "" and world.phase != "crash":
		_hint_banner(font)
	if world.phase == "crash" and world.bot == null and world.phase_ticks >= world.CRASH_SKIP_TICKS:
		var a := 0.55 + 0.45 * sin(_t * 6.0)
		_center_text(font, size.y - 22.0, "TAP FOR RESULTS" if world.one_life else "TAP TO GO AGAIN", 8, Color(UITheme.CREAM, a))
	if world.phase == "ready" and world.first_ready:
		var msg := "READY" if world.phase_ticks < 36 else "GO!"
		_center_text(font, size.y * 0.38, msg, 16, UITheme.GOLD)
	# First visit: the "?" pulses and a small tag names what's new on this trail.
	if feature_new and _t < 7.0 and not world.guide_on:
		var pulse := 0.5 + 0.5 * sin(_t * 6.0)
		var r := _hint_btn.get_rect().grow(2.0 + 2.0 * pulse)
		draw_rect(r, Color(UITheme.GOLD, 0.35 + 0.5 * pulse), false, 1.0)
		var tag := "NEW: %s - TAP ? FOR TIPS" % feature
		var tw := font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var tx := size.x - tw - 8.0
		var fade := clampf((7.0 - _t) / 1.5, 0.0, 1.0)
		draw_rect(Rect2(tx - 4, 33, tw + 8, 13), Color(UITheme.INK, 0.8 * fade))
		_text(font, Vector2(tx, 43), tag, Color(UITheme.GOLD, fade))
	# Bike specialty indicator, bright while it's doing its thing.
	if ability_title != "":
		var on := _ability_active()
		_text(font, Vector2(6, size.y - 8.0), ability_title, UITheme.GOLD if on else Color(UITheme.DIM, 0.8))
	if show_hint and world.state.x < lv.start_x + 520.0:
		var a := 0.6 + 0.4 * sin(_t * 4.0)
		_center_text(font, size.y - 22.0, "TAP TO JUMP - HOLD TO JUMP HIGHER", 8, Color(UITheme.CREAM, a))


func _hint_banner(font: Font) -> void:
	var lines := []
	# The full tip for the first few seconds back, then just the reminder.
	if world.ride_time - world.guide_since < 6.0 or (world.guide as Dictionary).is_empty():
		lines = _wrap(font, "HINT: " + String(world.guide_tip), size.x - 40.0)
	if not (world.guide as Dictionary).is_empty():
		lines.append("FOLLOW THE DOTS. BLUE = KEEP HOLDING.")
	var w := 0.0
	for l in lines:
		w = maxf(w, font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x)
	var y0 := 36.0
	var bx := floorf(size.x * 0.5 - w * 0.5) - 6.0
	draw_rect(Rect2(bx, y0, w + 12.0, lines.size() * 11.0 + 6.0), Color(UITheme.INK, 0.82))
	draw_rect(Rect2(bx, y0, w + 12.0, lines.size() * 11.0 + 6.0), Color(UITheme.GOLD, 0.6), false, 1.0)
	for i in lines.size():
		var legend: bool = i == lines.size() - 1 and not (world.guide as Dictionary).is_empty()
		var c := Color("7fe0ff") if legend else (UITheme.GOLD if i == 0 else UITheme.CREAM)
		_text(font, Vector2(bx + 6.0, y0 + 12.0 + i * 11.0), String(lines[i]), c)


func _wrap(font: Font, text: String, max_w: float) -> Array:
	var out := [""]
	for word in text.split(" "):
		var trial: String = (out[out.size() - 1] + " " + word).strip_edges()
		if font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x > max_w and out[out.size() - 1] != "":
			out.append(word)
		else:
			out[out.size() - 1] = trial
	return out


func _mini_letter(font: Font, p: Vector2, ch: String, lit: bool) -> void:
	draw_rect(Rect2(p.x, p.y, 10, 11), Icons.GOLD_DARK if lit else Color(0.35, 0.32, 0.4, 0.9))
	draw_rect(Rect2(p.x + 1, p.y + 1, 8, 9), Icons.GOLD if lit else Color(0.16, 0.14, 0.2, 0.9))
	draw_string(font, Vector2(p.x + 1, p.y + 9), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 8,
		Color("4a2a10") if lit else Color(0.55, 0.5, 0.62))


func _ability_active() -> bool:
	var st: Dictionary = world.state
	match String(st.ab):
		"wheelie":
			return bool(st.wheelie) or float(st.boost) > 2.0
		"hop", "dash":
			return not st.grounded and not bool(st.air_used) and int(st.zip) < 0 and int(st.loop) < 0
		"glide":
			return not st.grounded and float(st.vy) > 0.0 and world.held_now and Phys.umbrella_ok(world.level, st)
		"tough":
			return int(st.armor) > 0
	return false


func _text(font: Font, p: Vector2, s: String, c: Color, sz := 8) -> void:
	draw_string(font, p + Vector2(1, 1), s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(0, 0, 0, 0.8))
	draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, c)


func _center_text(font: Font, y: float, s: String, sz: int, c: Color) -> void:
	draw_string(font, Vector2(1, y + 1), s, HORIZONTAL_ALIGNMENT_CENTER, size.x, sz, Color(0, 0, 0, c.a * 0.8))
	draw_string(font, Vector2(0, y), s, HORIZONTAL_ALIGNMENT_CENTER, size.x, sz, c)
