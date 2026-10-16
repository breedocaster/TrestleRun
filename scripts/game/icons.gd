## Small pixel icons shared by the world, HUD and menus.
extends RefCounted

const GOLD := Color("f7c948")
const GOLD_DARK := Color("b7791f")
const GOLD_LIGHT := Color("fff1a8")
const BRASS := Color("e0b84a")
const BRASS_DARK := Color("8a6420")


static func coin(ci: CanvasItem, p: Vector2, spin := 1.0) -> void:
	var w := maxf(1.0, roundf(3.0 * absf(spin)))
	ci.draw_rect(Rect2(p.x - w - 1, p.y - 3, w * 2 + 2, 6), GOLD_DARK)
	ci.draw_rect(Rect2(p.x - w, p.y - 4, w * 2, 8), GOLD_DARK)
	ci.draw_rect(Rect2(p.x - w, p.y - 3, w * 2, 6), GOLD)
	if w >= 2.0:
		ci.draw_rect(Rect2(p.x - w + 1, p.y - 2, 1, 2), GOLD_LIGHT)


static func gear(ci: CanvasItem, p: Vector2, r: float, rot: float, filled := true, alpha := 1.0) -> void:
	var body := Color(BRASS, alpha)
	var dark := Color(BRASS_DARK, alpha)
	if not filled:
		body = Color(0.2, 0.18, 0.24, 0.85 * alpha)
		dark = Color(0.45, 0.42, 0.5, alpha)
	for i in 8:
		var a := rot + i * TAU / 8.0
		ci.draw_circle(p + Vector2(cos(a), sin(a)) * r, maxf(1.0, r * 0.32), dark)
	ci.draw_circle(p, r * 0.8, dark)
	ci.draw_circle(p, r * 0.62, body)
	ci.draw_circle(p, maxf(1.0, r * 0.25), dark)


static func bag(ci: CanvasItem, p: Vector2) -> void:
	ci.draw_circle(p + Vector2(0, 1), 5.0, Color("6b4423"))
	ci.draw_circle(p + Vector2(0, 1), 4.0, Color("9a6634"))
	ci.draw_rect(Rect2(p.x - 2, p.y - 6, 4, 3), Color("6b4423"))
	ci.draw_rect(Rect2(p.x - 3, p.y - 4, 6, 1), GOLD)
	ci.draw_rect(Rect2(p.x - 1, p.y - 1, 2, 5), GOLD)
	ci.draw_rect(Rect2(p.x - 2, p.y, 4, 1), GOLD)
	ci.draw_rect(Rect2(p.x - 2, p.y + 2, 4, 1), GOLD)


## Power-up icons: "sticky" (green tire), "rocket", "magnet", "hat" (hard hat).
## bubble: draw the floating pickup bubble around it (HUD icons skip it).
static func power(ci: CanvasItem, p: Vector2, kind: String, t: float, bubble := true) -> void:
	if bubble:
		var glow := 0.25 + 0.12 * sin(t * 5.0)
		ci.draw_circle(p, 9.0, Color(1, 1, 1, glow * 0.5))
		ci.draw_arc(p, 8.0, 0.0, TAU, 18, Color(1, 1, 1, 0.75), -1.0)
		ci.draw_rect(Rect2(p.x - 5, p.y - 6, 2, 2), Color(1, 1, 1, 0.7))
	match kind:
		"sticky":
			ci.draw_circle(p, 5.0, Color("2a4a1c"))
			ci.draw_circle(p, 4.0, Color("7dff5a"))
			ci.draw_circle(p, 2.0, Color("2a4a1c"))
			ci.draw_rect(Rect2(p.x - 1, p.y + 4, 2, 2 + int(t * 3.0) % 2), Color("7dff5a"))
			ci.draw_rect(Rect2(p.x + 3, p.y + 3, 1, 2), Color("7dff5a"))
		"rocket":
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(5, 0), p + Vector2(2, -3), p + Vector2(-4, -3),
				p + Vector2(-4, 3), p + Vector2(2, 3)]), Color("e8e2d0"))
			ci.draw_rect(Rect2(p.x + 1, p.y - 3, 2, 6), Color("e04848"))
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-4, -3), p + Vector2(-6, -5), p + Vector2(-6, -2)]), Color("e04848"))
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-4, 3), p + Vector2(-6, 5), p + Vector2(-6, 2)]), Color("e04848"))
			var f := 2.0 + float(int(t * 12.0) % 2)
			ci.draw_rect(Rect2(p.x - 5 - f, p.y - 1, f, 2), Color("ffb347"))
		"magnet":
			var c := Color("e04848")
			ci.draw_rect(Rect2(p.x - 5, p.y - 4, 3, 7), c)
			ci.draw_rect(Rect2(p.x + 2, p.y - 4, 3, 7), c)
			ci.draw_rect(Rect2(p.x - 5, p.y + 2, 10, 3), c)
			ci.draw_rect(Rect2(p.x - 5, p.y - 5, 3, 2), Color("e8e2d0"))
			ci.draw_rect(Rect2(p.x + 2, p.y - 5, 3, 2), Color("e8e2d0"))
		"hat":
			hard_hat(ci, p + Vector2(0, 2))


static func hard_hat(ci: CanvasItem, p: Vector2) -> void:
	ci.draw_rect(Rect2(p.x - 5, p.y, 10, 2), Color("c99a1a"))
	ci.draw_circle(p + Vector2(0, -0.5), 3.5, Color("f0c040"))
	ci.draw_rect(Rect2(p.x - 4, p.y - 1, 8, 1), Color("f0c040"))
	ci.draw_rect(Rect2(p.x - 1, p.y - 4, 2, 4), Color("ffe08a"))


## Medal: kind 0 bronze, 1 silver, 2 gold; dim outline if not earned.
static func medal(ci: CanvasItem, p: Vector2, kind: int, earned: bool) -> void:
	var cols := [Color("c8803a"), Color("c8d0dc"), Color("f7c948")]
	var dark := [Color("7a4a1e"), Color("6e7684"), Color("b7791f")]
	if not earned:
		ci.draw_circle(p, 5.0, Color(0.2, 0.18, 0.24, 0.85))
		ci.draw_arc(p, 5.0, 0.0, TAU, 14, Color(0.45, 0.42, 0.5), -1.0)
		return
	ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-4, -9), p + Vector2(-1, -9), p + Vector2(1, -4), p + Vector2(-2, -4)]), Color("4a7ad0"))
	ci.draw_colored_polygon(PackedVector2Array([p + Vector2(4, -9), p + Vector2(1, -9), p + Vector2(-1, -4), p + Vector2(2, -4)]), Color("d04a4a"))
	ci.draw_circle(p, 5.0, dark[kind])
	ci.draw_circle(p, 4.0, cols[kind])
	ci.draw_rect(Rect2(p.x - 2, p.y - 3, 1, 2), Color(1, 1, 1, 0.6))


## A T-R-E-S-T-L-E letter tile. lit = collected (HUD) / shown in the world.
static func letter(ci: CanvasItem, p: Vector2, ch: String, lit := true, t := 0.0) -> void:
	var font: Font = GameState.font
	var body := GOLD if lit else Color(0.2, 0.18, 0.24, 0.85)
	var edge := GOLD_DARK if lit else Color(0.45, 0.42, 0.5)
	ci.draw_rect(Rect2(p.x - 6, p.y - 6, 12, 12), edge)
	ci.draw_rect(Rect2(p.x - 5, p.y - 5, 10, 10), body)
	if lit:
		ci.draw_rect(Rect2(p.x - 5, p.y - 5, 10, 1), GOLD_LIGHT)
	ci.draw_string(font, Vector2(p.x - 4, p.y + 4), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 8,
		Color("4a2a10") if lit else Color(0.6, 0.56, 0.66))


## Parts of Grandpa's bike (story mode). p = centre; s = scale (1 = HUD/world size).
static func part(ci: CanvasItem, p: Vector2, kind: String, s := 1.0, dim := false) -> void:
	var chrome := Color("d8dee6") if not dim else Color(0.35, 0.32, 0.42)
	var chrome_d := Color("7f8a96") if not dim else Color(0.25, 0.22, 0.3)
	var leather := Color("6b3f2a") if not dim else Color(0.3, 0.27, 0.36)
	var tire := Color("1e1a1f") if not dim else Color(0.2, 0.18, 0.26)
	var paint := Color("2e5a8a") if not dim else Color(0.3, 0.27, 0.36)
	var k := s
	match kind:
		"headlight":
			ci.draw_circle(p, 6.0 * k, chrome_d)
			ci.draw_circle(p, 5.0 * k, chrome)
			ci.draw_circle(p + Vector2(1, 0) * k, 3.5 * k, Color("fff4c0") if not dim else chrome_d)
			ci.draw_rect(Rect2(p.x - 7 * k, p.y - 1 * k, 2 * k, 2 * k), chrome_d)
		"kickstart":
			ci.draw_line(p + Vector2(-5, -5) * k, p + Vector2(3, 4) * k, chrome, 2.0 * k)
			ci.draw_rect(Rect2(p.x + 1 * k, p.y + 3 * k, 6 * k, 2 * k), Color("2a2a30") if not dim else chrome_d)
			ci.draw_circle(p + Vector2(-5, -5) * k, 2.0 * k, chrome_d)
		"seat":
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-7, -1) * k, p + Vector2(-4, -4) * k, p + Vector2(5, -4) * k,
				p + Vector2(7, -1) * k, p + Vector2(5, 1) * k, p + Vector2(-6, 1) * k]), leather)
			ci.draw_line(p + Vector2(-4, -4) * k, p + Vector2(5, -4) * k, leather.lightened(0.3), -1.0)
			for sx in [-3.0, 3.0]:
				ci.draw_line(p + Vector2(sx, 1) * k, p + Vector2(sx, 5) * k, chrome, -1.0)
				ci.draw_line(p + Vector2(sx - 1, 3) * k, p + Vector2(sx + 1, 3) * k, chrome_d, -1.0)
		"wheels":
			ci.draw_circle(p, 6.5 * k, tire)
			ci.draw_circle(p, 4.5 * k, chrome_d)
			ci.draw_circle(p, 3.5 * k, Color(0, 0, 0, 0.0) if dim else Color("2a2430"))
			for i in 8:
				var a := i * TAU / 8.0
				ci.draw_line(p, p + Vector2(cos(a), sin(a)) * 4.5 * k, chrome, -1.0)
			ci.draw_circle(p, 1.5 * k, chrome)
		"carb":
			ci.draw_rect(Rect2(p.x - 4 * k, p.y - 4 * k, 8 * k, 6 * k), chrome)
			ci.draw_rect(Rect2(p.x - 6 * k, p.y - 2 * k, 2 * k, 3 * k), chrome_d)
			ci.draw_rect(Rect2(p.x + 4 * k, p.y - 2 * k, 2 * k, 3 * k), chrome_d)
			ci.draw_rect(Rect2(p.x - 3 * k, p.y + 2 * k, 6 * k, 3 * k), chrome_d)
			ci.draw_rect(Rect2(p.x - 1 * k, p.y - 7 * k, 2 * k, 3 * k), chrome)
		"top_end":
			for i in 4:
				ci.draw_rect(Rect2(p.x - 6 * k, p.y - 6 * k + i * 3 * k, 12 * k, 2 * k), chrome)
			ci.draw_rect(Rect2(p.x - 4 * k, p.y - 7 * k, 8 * k, 12 * k), chrome_d)
			ci.draw_rect(Rect2(p.x - 3 * k, p.y - 9 * k, 6 * k, 2 * k), chrome)
		"bottom_end":
			ci.draw_circle(p + Vector2(0, 1) * k, 6.0 * k, chrome_d)
			ci.draw_circle(p + Vector2(0, 1) * k, 4.5 * k, chrome)
			ci.draw_rect(Rect2(p.x - 7 * k, p.y - 6 * k, 14 * k, 4 * k), chrome_d)
			ci.draw_circle(p + Vector2(0, 1) * k, 1.5 * k, chrome_d)
		"frame":
			var c := paint
			ci.draw_line(p + Vector2(-7, -4) * k, p + Vector2(5, -4) * k, c, 2.0 * k)
			ci.draw_line(p + Vector2(-7, -4) * k, p + Vector2(-3, 5) * k, c, 2.0 * k)
			ci.draw_line(p + Vector2(5, -4) * k, p + Vector2(-3, 5) * k, c, 2.0 * k)
			ci.draw_line(p + Vector2(5, -4) * k, p + Vector2(8, 5) * k, c, 2.0 * k)
			ci.draw_line(p + Vector2(-7, -4) * k, p + Vector2(-9, 4) * k, c, 2.0 * k)
