## Achievement badges: a round medallion with a little picture for each one. Drawn the
## same way in the toast, on the ACHIEVEMENTS screen, and (big) for the store icons.
extends RefCounted

const Icons := preload("res://scripts/game/icons.gd")
const WorldArt := preload("res://scripts/game/world_art.gd")
const FeatureArt := preload("res://scripts/game/feature_art.gd")

const RIM := Color("b7791f")
const FACE := Color("2a2236")
const FACE_ON := Color("3a2e52")


## c = centre, r = radius (10 in the HUD, 240 for a 512 px store icon).
static func badge(ci: CanvasItem, c: Vector2, r: float, id: String, unlocked: bool, t := 0.0) -> void:
	var k := r / 10.0
	ci.draw_circle(c, r, RIM if unlocked else Color(0.35, 0.32, 0.42))
	ci.draw_circle(c, r * 0.86, FACE_ON if unlocked else FACE)
	if unlocked:
		ci.draw_arc(c, r * 0.78, PI * 1.1, PI * 1.6, 12, Color(1, 1, 1, 0.25), maxf(1.0, k * 0.8))
	ci.draw_set_transform(c, 0.0, Vector2(k, k))
	_symbol(ci, id, t)
	ci.draw_set_transform(Vector2.ZERO)
	if not unlocked:
		ci.draw_circle(c, r * 0.86, Color(0.08, 0.06, 0.1, 0.55))


## A little flying saucer (the bosses), round o.
static func _saucer(ci: CanvasItem, o: Vector2, t: float) -> void:
	ci.draw_circle(o + Vector2(0, -1.5), 3.6, Color(0.6, 0.95, 0.75, 0.9))
	ci.draw_circle(o + Vector2(0, -1.2), 1.5, Color("5bd16a"))
	ci.draw_colored_polygon(PackedVector2Array([o + Vector2(-7, 1), o + Vector2(-4, -0.5), o + Vector2(4, -0.5),
		o + Vector2(7, 1), o + Vector2(4, 2.8), o + Vector2(-4, 2.8)]), Color("b8bec8"))
	ci.draw_rect(Rect2(o + Vector2(-5, 1.6), Vector2(10, 1.2)), Color("6a7280"))
	for i in 3:
		var on := int(t * 4.0 + i) % 3 == 0
		ci.draw_rect(Rect2(o + Vector2(-4 + i * 3.5, 0.4), Vector2(1, 1)), Color("ffe08a") if on else Color("d9453b"))


static func _box(c: Vector2, half: Vector2, a: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)]:
		out.append(c + (p as Vector2).rotated(a))
	return out


## The picture, drawn round (0, 0) in a 16 px square.
static func _symbol(ci: CanvasItem, id: String, t: float) -> void:
	if id.begins_with("part_"):
		Icons.part(ci, Vector2.ZERO, id.substr(5), 0.9)
		return
	match id:
		"story_start":
			ci.draw_line(Vector2(-3, 6), Vector2(-3, -6), Color("d8d8d8"), -1.0)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-3, -6), Vector2(5, -3), Vector2(-3, 0)]), Color("5bd16a"))
		"parts_4":
			Icons.part(ci, Vector2(-3, -2), "headlight", 0.6)
			Icons.part(ci, Vector2(3, 3), "wheels", 0.55)
		"boss_flawless", "boss_quick":
			_saucer(ci, Vector2(1 if id == "boss_quick" else 0, 1), t)
			if id == "boss_quick":
				for i in 3:
					ci.draw_rect(Rect2(-8, -2 + i * 2.5, 3 - i % 2, 1), Color("ffe08a"))
			else:
				var sp := Vector2(5, -5)
				ci.draw_colored_polygon(PackedVector2Array([sp + Vector2(0, -2.5), sp + Vector2(0.8, -0.8), sp + Vector2(2.5, 0),
					sp + Vector2(0.8, 0.8), sp + Vector2(0, 2.5), sp + Vector2(-0.8, 0.8), sp + Vector2(-2.5, 0),
					sp + Vector2(-0.8, -0.8)]), Icons.GOLD_LIGHT)
		"first_clear", "free_all":
			for i in 4:
				for j in 3:
					ci.draw_rect(Rect2(-4 + i * 2, -5 + j * 2, 2, 2), Color("f4f4f4") if (i + j) % 2 == 0 else Color("1a1a1a"))
			ci.draw_line(Vector2(-4, -5), Vector2(-4, 6), Color("d8d8d8"), -1.0)
			if id == "free_all":
				ci.draw_rect(Rect2(-6, 4, 12, 2), Icons.GOLD)
		"no_crash":
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-5, -5), Vector2(5, -5), Vector2(5, 0), Vector2(0, 6), Vector2(-5, 0)]),
				Color("4a7ad0"))
			ci.draw_line(Vector2(-2, 0), Vector2(0, 2), Color.WHITE, -1.0)
			ci.draw_line(Vector2(0, 2), Vector2(3, -2), Color.WHITE, -1.0)
		"outrun":
			# Planks dropping away behind, an arrow pulling ahead.
			for i in 3:
				var pc := Vector2(-5 + i * 2.2, 1 + i * 2.0)
				ci.draw_colored_polygon(_box(pc, Vector2(3, 1.2), 0.5 + i * 0.4), Color("8a5a32"))
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-1, -4), Vector2(3, -4), Vector2(3, -6), Vector2(7, -2.5),
				Vector2(3, 1), Vector2(3, -1), Vector2(-1, -1)]), Color("5bd16a"))
		"gold_first", "gold_ten":
			Icons.medal(ci, Vector2(0, 2), 2, true)
			if id == "gold_ten":
				Icons.medal(ci, Vector2(4, 4), 2, true)
		"letters_first":
			Icons.letter(ci, Vector2.ZERO, "T")
		"gears_all":
			Icons.gear(ci, Vector2.ZERO, 5.0, t, true)
		"flip", "double_flip", "tricks_run":
			ci.draw_arc(Vector2.ZERO, 5.0, PI * 0.2, PI * 1.8, 14, Color("8fe3ff"), 2.0)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(4, 4), Vector2(1, 6), Vector2(5, 7)]), Color("8fe3ff"))
			if id == "double_flip":
				ci.draw_arc(Vector2.ZERO, 2.5, PI * 0.2, PI * 1.8, 10, Color("8fe3ff"), -1.0)
			elif id == "tricks_run":
				for sp in [Vector2(-6, -6), Vector2(6, -5), Vector2(-6, 5)]:
					ci.draw_rect(Rect2(sp + Vector2(-0.5, -2), Vector2(1, 4)), Icons.GOLD_LIGHT)
					ci.draw_rect(Rect2(sp + Vector2(-2, -0.5), Vector2(4, 1)), Icons.GOLD_LIGHT)
		"stomp_100":
			WorldArt.crawler(ci, Vector2(0, 5), 1.0, "beetle", t)
		"zip_chain":
			ci.draw_line(Vector2(-7, -4), Vector2(7, 0), Color("c9d1d9"), -1.0)
			FeatureArt.trolley(ci, Vector2(0, -2), Vector2(0, 4))
		"rails_25":
			ci.draw_line(Vector2(-7, 1), Vector2(7, 1), Color("c9d1d9"), 2.0)
			for i in 4:
				ci.draw_rect(Rect2(-3 + i * 2, -1 - i, 1, 1), Color("ffcf6a"))
		"ropes_25":
			ci.draw_rect(Rect2(-6, -6, 12, 2), Color("7a4a2a"))
			ci.draw_line(Vector2(0, -5), Vector2(3, 6), Color("c9a46a"), 2.0)
		"walls_25":
			ci.draw_arc(Vector2(0, 5), 6.0, PI, TAU, 12, Color("c08a4a"), 3.0)
		"planes_10":
			ci.draw_rect(Rect2(-5, -1, 10, 3), Color("e8e2d0"))
			ci.draw_rect(Rect2(-2, -4, 3, 9), Color("d9453b"))
			Icons.bag(ci, Vector2(1, 6))
		"any_weather":
			ci.draw_circle(Vector2(-2, -2), 3.5, Color("c9d1d9"))
			ci.draw_circle(Vector2(2, -1), 3.0, Color("c9d1d9"))
			ci.draw_line(Vector2(-2, 3), Vector2(-3, 6), Color("8fc7ff"), -1.0)
			ci.draw_line(Vector2(2, 3), Vector2(1, 6), Color("8fc7ff"), -1.0)
		"night_5":
			ci.draw_circle(Vector2.ZERO, 5.0, Color("e8edf7"))
			ci.draw_circle(Vector2(2, -1), 4.0, FACE_ON)
		"garage_bikes":
			# A shed with its door up and a wheel peeking out.
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-7, -1), Vector2(0, -7), Vector2(7, -1)]), Color("b0473a"))
			ci.draw_rect(Rect2(-6, -1, 12, 7), Color("c9a46a"))
			ci.draw_rect(Rect2(-4, 1, 8, 5), Color("2a2236"))
			ci.draw_circle(Vector2(1, 4), 2.4, Color("1a1a1a"))
			ci.draw_circle(Vector2(1, 4), 1.0, Color("c9d1d9"))
		"garage_riders":
			ci.draw_circle(Vector2(0, 0), 5.0, Color("c8323c"))
			ci.draw_rect(Rect2(-1, -2, 5, 3), Color("7fd0ff"))
		"rich":
			for i in 3:
				Icons.coin(ci, Vector2(0, 4 - i * 4), 1.0)
		"ghost_beat":
			ci.draw_circle(Vector2(-3, 3), 3.0, Color(0.75, 0.9, 1.0, 0.6))
			ci.draw_circle(Vector2(3, 3), 3.0, Color(0.75, 0.9, 1.0, 0.6))
			ci.draw_line(Vector2(-3, 3), Vector2(1, -3), Color(0.75, 0.9, 1.0, 0.8), 2.0)
		_:
			Icons.medal(ci, Vector2.ZERO, 0, true)
