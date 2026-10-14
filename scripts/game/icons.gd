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
