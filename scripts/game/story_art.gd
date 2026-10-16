## Story mode art: Grandpa's old bike (drawn part by part, so the ones still missing
## show as dim silhouettes), Grandma, and the intro comic's panels.
extends RefCounted

const BossArt := preload("res://scripts/game/boss_art.gd")
const Backdrop := preload("res://scripts/game/backdrop.gd")
const BikeView := preload("res://scripts/game/bike_view.gd")

const PAINT := Color("2e5a8a")
const PAINT_HI := Color("5a8ac8")
const CREAM := Color("ece0c0")
const CHROME := Color("d8dee6")
const CHROME_D := Color("7f8a96")
const TIRE := Color("1e1a1f")
const LEATHER := Color("6b3f2a")
const GHOST := Color(0.55, 0.52, 0.66, 0.32)


# --- Grandpa's bike -------------------------------------------------------------

## A 1950s single-cylinder roadster, facing right. o = ground under the bike's middle,
## k = scale. parts: the ones recovered (Catalog.PARTS ids); all = draw it whole.
static func grandpa_bike(ci: CanvasItem, o: Vector2, k: float, parts: Array, all := false, t := 0.0) -> void:
	var has := func(p: String) -> bool: return all or p in parts
	var P := func(x: float, y: float) -> Vector2: return o + Vector2(x, y) * k
	var frame_on: bool = has.call("frame")
	var fc := PAINT if frame_on else GHOST
	var cc := CHROME if frame_on else GHOST
	# Wheels.
	for wc in [Vector2(-31, -14), Vector2(32, -14)]:
		var c: Vector2 = P.call(wc.x, wc.y)
		if has.call("wheels"):
			ci.draw_circle(c, 14.0 * k, TIRE)
			ci.draw_circle(c, 11.5 * k, CHROME_D)
			ci.draw_circle(c, 10.5 * k, Color("2a2430"))
			for i in 12:
				var a := i * TAU / 12.0 + t * 2.0
				ci.draw_line(c, c + Vector2(cos(a), sin(a)) * 10.5 * k, Color(CHROME, 0.8), -1.0)
			ci.draw_circle(c, 2.0 * k, CHROME)
		else:
			ci.draw_arc(c, 13.0 * k, 0.0, TAU, 24, GHOST, 3.0 * k)
	# Frame: tubes, fork, fenders, tank, bars, exhaust.
	var head: Vector2 = P.call(23, -42)
	var seat_n: Vector2 = P.call(-13, -38)
	var crank: Vector2 = P.call(1, -13)
	var rear: Vector2 = P.call(-31, -14)
	var front: Vector2 = P.call(32, -14)
	var w := 2.5 * k
	ci.draw_line(head, crank, fc, w)
	ci.draw_line(head, seat_n, fc, w)
	ci.draw_line(seat_n, crank, fc, w)
	ci.draw_line(seat_n, rear, fc, w * 0.8)
	ci.draw_line(crank, rear, fc, w * 0.8)
	ci.draw_line(head, front, cc, w * 0.9)
	ci.draw_arc(P.call(-31, -14), 16.0 * k, PI * 1.05, PI * 1.75, 10, fc, 2.0 * k)
	ci.draw_arc(P.call(32, -14), 16.0 * k, PI * 1.2, PI * 1.85, 10, fc, 2.0 * k)
	var tank := PackedVector2Array([P.call(-6, -41), P.call(-3, -47), P.call(16, -47), P.call(22, -42), P.call(16, -38), P.call(-4, -38)])
	ci.draw_colored_polygon(tank, CREAM if frame_on else GHOST)
	if frame_on:
		ci.draw_line(P.call(-3, -43), P.call(18, -43), PAINT, 2.0 * k)
		ci.draw_line(P.call(-2, -46), P.call(14, -46), Color(1, 1, 1, 0.7), -1.0)
	ci.draw_line(head, P.call(20, -50), cc, 2.0 * k)
	ci.draw_line(P.call(17, -51), P.call(26, -50), cc, 2.0 * k)
	ci.draw_line(P.call(4, -24), P.call(-6, -12), cc, 2.0 * k)
	ci.draw_line(P.call(-6, -12), P.call(-36, -10), cc, 2.0 * k)
	# Engine: bottom end (crankcase) and top end (finned barrel and head).
	if has.call("bottom_end"):
		ci.draw_circle(crank, 8.0 * k, CHROME_D)
		ci.draw_circle(crank, 6.0 * k, CHROME)
		ci.draw_circle(crank, 2.0 * k, CHROME_D)
	else:
		ci.draw_circle(crank, 8.0 * k, GHOST)
	var cyl := Rect2(P.call(-3, -33), Vector2(10, 18) * k)
	if has.call("top_end"):
		ci.draw_rect(cyl, CHROME_D)
		for i in 5:
			ci.draw_rect(Rect2(P.call(-5, -32 + i * 3.6), Vector2(14, 1.6) * k), CHROME)
		ci.draw_rect(Rect2(P.call(-4, -36), Vector2(12, 3) * k), CHROME)
	else:
		ci.draw_rect(Rect2(P.call(-5, -36), Vector2(14, 21) * k), GHOST)
	# Carburettor tucked behind the barrel.
	if has.call("carb"):
		ci.draw_rect(Rect2(P.call(-11, -29), Vector2(6, 6) * k), CHROME)
		ci.draw_rect(Rect2(P.call(-15, -28), Vector2(4, 4) * k), CHROME_D)
	else:
		ci.draw_rect(Rect2(P.call(-15, -29), Vector2(10, 6) * k), GHOST)
	# Kickstart lever.
	var kc := CHROME if has.call("kickstart") else GHOST
	ci.draw_line(P.call(-3, -13), P.call(-11, -4), kc, 2.0 * k)
	ci.draw_rect(Rect2(P.call(-14, -5), Vector2(6, 2) * k), Color("2a2a30") if has.call("kickstart") else GHOST)
	# Sprung solo saddle.
	if has.call("seat"):
		ci.draw_colored_polygon(PackedVector2Array([P.call(-24, -41), P.call(-20, -45), P.call(-7, -45), P.call(-4, -42), P.call(-8, -40),
			P.call(-22, -39)]), LEATHER)
		ci.draw_line(P.call(-20, -45), P.call(-7, -45), LEATHER.lightened(0.3), -1.0)
		for sx in [-20.0, -15.0]:
			ci.draw_line(P.call(sx, -39), P.call(sx + 1, -35), CHROME, -1.0)
	else:
		ci.draw_colored_polygon(PackedVector2Array([P.call(-24, -41), P.call(-20, -45), P.call(-7, -45), P.call(-4, -42), P.call(-22, -39)]), GHOST)
	# Headlight bucket.
	var hl: Vector2 = P.call(30, -44)
	if has.call("headlight"):
		ci.draw_circle(hl, 5.5 * k, CHROME_D)
		ci.draw_circle(hl, 4.5 * k, CHROME)
		ci.draw_circle(hl + Vector2(1.5, 0) * k, 3.0 * k, Color("fff4c0"))
	else:
		ci.draw_circle(hl, 5.5 * k, GHOST)


# --- Grandma ------------------------------------------------------------------------

## Grandma, about 30 px tall. o = feet. aim: shotgun up at the sky (fire: muzzle flash).
static func grandma(ci: CanvasItem, o: Vector2, t: float, aim := false, fire := 0.0, wave := false) -> void:
	var skin := Color("e8b896")
	var hair := Color("d8d8e0")
	var skirt := Color("4a2a5a")
	var cardi := Color("9a7ac0")
	var apron := Color("f0ece0")
	ci.draw_rect(Rect2(o.x - 5, o.y - 2, 4, 2), Color("2a1a14"))
	ci.draw_rect(Rect2(o.x + 1, o.y - 2, 4, 2), Color("2a1a14"))
	ci.draw_colored_polygon(PackedVector2Array([o + Vector2(-7, -2), o + Vector2(-4, -14), o + Vector2(4, -14), o + Vector2(7, -2)]), skirt)
	ci.draw_rect(Rect2(o.x - 3, o.y - 13, 6, 9), apron)
	ci.draw_rect(Rect2(o.x - 5, o.y - 22, 10, 9), cardi)
	# Head, bun, glasses.
	ci.draw_circle(o + Vector2(0, -26), 4.5, skin)
	ci.draw_circle(o + Vector2(-1, -30), 4.0, hair)
	ci.draw_circle(o + Vector2(-4, -31), 2.5, hair)
	ci.draw_arc(o + Vector2(1.5, -26), 1.5, 0.0, TAU, 8, Color("3a3440"), -1.0)
	ci.draw_arc(o + Vector2(4.5, -26), 1.5, 0.0, TAU, 8, Color("3a3440"), -1.0)
	if aim:
		# Shotgun shouldered, pointing up and right.
		var stock := o + Vector2(-2, -19)
		var muzzle := o + Vector2(20, -38)
		ci.draw_line(stock, stock + (muzzle - stock) * 0.35, Color("7a4a2a"), 3.0)
		ci.draw_line(stock + (muzzle - stock) * 0.3, muzzle, Color("3a3a42"), 2.0)
		ci.draw_line(o + Vector2(3, -20), stock + (muzzle - stock) * 0.45, cardi, 2.0)
		if fire > 0.0:
			var f := fire
			ci.draw_circle(muzzle + Vector2(3, -3), 6.0 * f, Color(1.0, 0.9, 0.4, 0.9 * f))
			ci.draw_circle(muzzle + Vector2(3, -3), 3.0 * f, Color(1, 1, 1, f))
			for i in 6:
				var a := -0.8 + i * 0.12
				ci.draw_line(muzzle + Vector2(cos(a), sin(a)) * 8.0, muzzle + Vector2(cos(a), sin(a)) * (14.0 + 10.0 * f),
					Color(1.0, 0.8, 0.3, f), -1.0)
	elif wave:
		var hand := o + Vector2(9, -30 + sin(t * 8.0) * 2.0)
		ci.draw_line(o + Vector2(4, -20), hand, cardi, 2.0)
		ci.draw_circle(hand, 1.5, skin)
	else:
		ci.draw_line(o + Vector2(-5, -20), o + Vector2(-7, -13), cardi, 2.0)
		ci.draw_line(o + Vector2(5, -20), o + Vector2(7, -13), cardi, 2.0)


# --- intro comic --------------------------------------------------------------------

const CAPTIONS := [
	"GRANDPA'S OLD BIKE. HE RODE IT OVER EVERY TRESTLE IN THE COUNTY, AND GRANDMA KEPT IT SHINY IN THE BARN.",
	"THEN ONE NIGHT, A SAUCER CAME FOR IT.",
	"GRANDMA WASN'T HAVING IT.",
	"PEPPERED WITH BIRDSHOT, THE SAUCER'S CAPTURE POD SHOOK LOOSE...",
	"...AND THE BIKE CAME APART ALL OVER THE COUNTY. ALIEN MACHINES GRABBED EVERY PIECE.",
	"RIDE OUT AND BRING GRANDPA'S BIKE HOME, ONE PART AT A TIME.",
]


static func panel(ci: CanvasItem, i: int, vs: Vector2, t: float) -> void:
	match i:
		0:
			_barn(ci, vs, t)
		1:
			_abduction(ci, vs, t)
		2:
			_porch(ci, vs, t)
		3:
			_pod(ci, vs, t)
		4:
			_county(ci, vs, t)
		_:
			_sunrise(ci, vs, t)


static func _night_sky(ci: CanvasItem, vs: Vector2, t: float) -> void:
	Backdrop.draw_scene(ci, vs, Vector2(400 + t * 8.0, 0), Backdrop.theme(12, "night"), t)


static func _barn_shape(ci: CanvasItem, base: Vector2, w: float, h: float, col: Color, trim: Color) -> void:
	ci.draw_rect(Rect2(base.x, base.y - h, w, h), col)
	ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-6, -h), base + Vector2(w * 0.5, -h - w * 0.45), base + Vector2(w + 6, -h)]), col.darkened(0.15))
	ci.draw_line(base + Vector2(-6, -h), base + Vector2(w * 0.5, -h - w * 0.45), trim, 2.0)
	ci.draw_line(base + Vector2(w * 0.5, -h - w * 0.45), base + Vector2(w + 6, -h), trim, 2.0)
	var dx := base.x + w * 0.5 - 16.0
	ci.draw_rect(Rect2(dx, base.y - 34, 32, 34), col.darkened(0.25))
	ci.draw_line(Vector2(dx, base.y - 34), Vector2(dx + 32, base.y), trim, 2.0)
	ci.draw_line(Vector2(dx + 32, base.y - 34), Vector2(dx, base.y), trim, 2.0)
	ci.draw_rect(Rect2(dx, base.y - 34, 32, 34), trim, false, 2.0)


static func _barn(ci: CanvasItem, vs: Vector2, t: float) -> void:
	# Inside the barn: boards, a hanging lantern, the bike gleaming on its stand.
	ci.draw_rect(Rect2(Vector2.ZERO, vs), Color("3a2418"))
	var x := 0.0
	while x < vs.x:
		ci.draw_rect(Rect2(x, 0, 1, vs.y), Color("2a1a10"))
		x += 18.0
	ci.draw_rect(Rect2(0, vs.y * 0.78, vs.x, vs.y), Color("5a3a22"))
	for i in 20:
		ci.draw_line(Vector2(i * 30.0 + 10, vs.y * 0.8 + (i % 3) * 6), Vector2(i * 30.0 + 22, vs.y * 0.8 + (i % 3) * 6 - 3), Color("c8a050"), -1.0)
	var lamp := Vector2(vs.x * 0.5, 40)
	ci.draw_line(Vector2(lamp.x, 0), lamp, Color("1a1008"), -1.0)
	var flick := 0.9 + 0.1 * sin(t * 9.0)
	ci.draw_circle(lamp + Vector2(0, 8), 120.0, Color(1.0, 0.8, 0.45, 0.10 * flick))
	ci.draw_circle(lamp + Vector2(0, 8), 60.0, Color(1.0, 0.85, 0.5, 0.12 * flick))
	ci.draw_rect(Rect2(lamp.x - 4, lamp.y, 8, 10), Color("6a4a2a"))
	ci.draw_rect(Rect2(lamp.x - 2, lamp.y + 2, 4, 6), Color(1.0, 0.9, 0.55, flick))
	grandpa_bike(ci, Vector2(vs.x * 0.5, vs.y * 0.8), 2.0, [], true)
	# A sparkle on the chrome.
	var sp := Vector2(vs.x * 0.5 + 60, vs.y * 0.8 - 88)
	var a := 0.5 + 0.5 * sin(t * 4.0)
	ci.draw_line(sp + Vector2(-4, 0), sp + Vector2(4, 0), Color(1, 1, 1, a), -1.0)
	ci.draw_line(sp + Vector2(0, -4), sp + Vector2(0, 4), Color(1, 1, 1, a), -1.0)


static func _abduction(ci: CanvasItem, vs: Vector2, t: float) -> void:
	_night_sky(ci, vs, t)
	var ground := vs.y * 0.82
	ci.draw_rect(Rect2(0, ground, vs.x, vs.y), Color("142014"))
	_barn_shape(ci, Vector2(vs.x * 0.18, ground), 110, 60, Color("6a1a1a"), Color("d8d0c0"))
	var sx := vs.x * 0.62
	var sy := 70.0 + sin(t * 1.5) * 4.0
	# Beam down to the field, the bike rising in a glass pod.
	var beam := Color(0.6, 1.0, 0.7, 0.14 + 0.05 * sin(t * 8.0))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(sx - 10, sy + 10), Vector2(sx + 10, sy + 10), Vector2(sx + 50, ground),
		Vector2(sx - 50, ground)]), beam)
	var rise := fposmod(t * 0.25, 1.0)
	var pod_c := Vector2(sx, lerpf(ground - 40.0, sy + 50.0, rise))
	ci.draw_circle(pod_c, 34.0, Color(0.55, 1.0, 0.72, 0.18))
	ci.draw_arc(pod_c, 34.0, 0.0, TAU, 32, Color(0.8, 1.0, 0.85, 0.7), -1.0)
	grandpa_bike(ci, pod_c + Vector2(0, 20), 0.8, [], true)
	ci.draw_set_transform(Vector2(sx, sy), 0.0, Vector2(2.4, 2.4))
	BossArt.draw(ci, "scooper", Vector2.ZERO, t, 0.0, 3, "", 0.0)
	ci.draw_set_transform(Vector2.ZERO)


static func _porch(ci: CanvasItem, vs: Vector2, t: float) -> void:
	_night_sky(ci, vs, t)
	var ground := vs.y * 0.84
	ci.draw_rect(Rect2(0, ground, vs.x, vs.y), Color("142014"))
	# The farmhouse porch: steps, posts, a lit window.
	var hx := vs.x * 0.06
	ci.draw_rect(Rect2(hx, ground - 110, 200, 110), Color("4a3a5a"))
	ci.draw_rect(Rect2(hx + 20, ground - 90, 34, 30), Color("ffd27a"))
	ci.draw_rect(Rect2(hx + 36, ground - 90, 2, 30), Color("4a3a5a"))
	ci.draw_rect(Rect2(hx, ground - 46, 220, 6), Color("8a6a4a"))
	ci.draw_rect(Rect2(hx - 6, ground - 120, 232, 8), Color("2a1e30"))
	for px in [hx + 70.0, hx + 140.0, hx + 214.0]:
		ci.draw_rect(Rect2(px, ground - 112, 4, 66), Color("d8d0c0"))
	ci.draw_rect(Rect2(hx, ground - 40, 230, 40), Color("6a4a32"))
	var cycle := fmod(t, 1.6)
	var fire := maxf(0.0, 1.0 - cycle / 0.25) if cycle < 0.25 else 0.0
	ci.draw_set_transform(Vector2(hx + 170, ground - 40), 0.0, Vector2(3.0, 3.0))
	grandma(ci, Vector2.ZERO, t, true, fire)
	ci.draw_set_transform(Vector2.ZERO)
	# The saucer up in the sky, birdshot sparks pinging off it.
	var sx := vs.x * 0.8
	var sy := 50.0 + sin(t * 2.0) * 3.0
	ci.draw_set_transform(Vector2(sx, sy), sin(t * 9.0) * 0.06 if fire > 0.0 else 0.0, Vector2(1.6, 1.6))
	BossArt.draw(ci, "scooper", Vector2.ZERO, t, fire, 3, "", 0.0)
	ci.draw_set_transform(Vector2.ZERO)
	if fire > 0.0:
		for i in 8:
			var a := i * TAU / 8.0 + t
			ci.draw_rect(Rect2(sx + cos(a) * 30.0 * (1.0 - fire), sy + sin(a) * 14.0, 2, 2), Color("fff1a8"))
		var font: Font = GameState.font
		ci.draw_string(font, Vector2(vs.x * 0.52, 70), "BLAM!", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1.0, 0.85, 0.3, fire))


static func _pod(ci: CanvasItem, vs: Vector2, t: float) -> void:
	_night_sky(ci, vs, t)
	var c := Vector2(vs.x * 0.5, vs.y * 0.42)
	var shake := Vector2(sin(t * 40.0), cos(t * 33.0)) * 3.0
	ci.draw_set_transform(c + Vector2(0, -60) + shake * 0.5, sin(t * 7.0) * 0.12, Vector2(2.0, 2.0))
	BossArt.draw(ci, "scooper", Vector2.ZERO, t, 0.8, 3, "", 0.0)
	ci.draw_set_transform(Vector2.ZERO)
	# The pod cracking: jagged lines and parts tumbling out.
	var pc := c + Vector2(0, 30) + shake
	ci.draw_circle(pc, 40.0, Color(0.55, 1.0, 0.72, 0.15))
	ci.draw_arc(pc, 40.0, 0.0, TAU, 32, Color(0.8, 1.0, 0.85, 0.6), -1.0)
	for i in 5:
		var a := i * 1.3 + 0.4
		var p0 := pc + Vector2(cos(a), sin(a)) * 40.0
		ci.draw_line(p0, p0 + Vector2(cos(a + 0.6), sin(a + 0.6)) * 12.0, Color.WHITE, -1.0)
	var parts := ["headlight", "kickstart", "seat", "wheels", "carb", "top_end", "bottom_end", "frame"]
	var Icons := preload("res://scripts/game/icons.gd")
	for i in parts.size():
		var a := -PI * 0.9 + i * PI * 0.8 / 7.0
		var k := fposmod(t * 0.4 + i * 0.13, 1.0)
		var p := pc + Vector2(cos(a), sin(a) + 0.4) * (30.0 + 140.0 * k) + Vector2(0, 120.0 * k * k)
		Icons.part(ci, p.floor(), parts[i], 2.0)


static func _county(ci: CanvasItem, vs: Vector2, t: float) -> void:
	# A painted map of the county with the four areas and parts landing in each.
	ci.draw_rect(Rect2(Vector2.ZERO, vs), Color("6a9a4a"))
	for i in 40:
		var x := fposmod(i * 73.0, vs.x)
		var y := fposmod(i * 41.0, vs.y)
		ci.draw_circle(Vector2(x, y), 6.0 + fposmod(i * 3.7, 6.0), Color("5a8a3e"))
	# Roads and the old railway.
	ci.draw_line(Vector2(0, vs.y * 0.6), Vector2(vs.x, vs.y * 0.45), Color("c8b088"), 4.0)
	ci.draw_line(Vector2(vs.x * 0.3, 0), Vector2(vs.x * 0.45, vs.y), Color("c8b088"), 3.0)
	var y0 := vs.y * 0.3
	var x := 0.0
	while x < vs.x:
		ci.draw_rect(Rect2(x, y0 + x * 0.05, 3, 6), Color("5a4030"))
		x += 8.0
	ci.draw_line(Vector2(0, y0 + 1), Vector2(vs.x, y0 + vs.x * 0.05 + 1), Color("8a8a90"), -1.0)
	ci.draw_line(Vector2(0, y0 + 5), Vector2(vs.x, y0 + vs.x * 0.05 + 5), Color("8a8a90"), -1.0)
	var spots := [[Vector2(vs.x * 0.2, vs.y * 0.52), "GRANDMA'S FARM", "headlight"],
		[Vector2(vs.x * 0.56, vs.y * 0.3), "RAIL YARD", "kickstart"],
		[Vector2(vs.x * 0.28, vs.y * 0.16), "ORCHARD", "seat"],
		[Vector2(vs.x * 0.78, vs.y * 0.56), "SPEEDWAY", "wheels"]]
	var font: Font = GameState.font
	var Icons := preload("res://scripts/game/icons.gd")
	for i in spots.size():
		var p: Vector2 = spots[i][0]
		ci.draw_circle(p, 14.0, Color(0, 0, 0, 0.2))
		var k := fposmod(t * 0.5 + i * 0.25, 1.0)
		var drop := p + Vector2(-60.0 * (1.0 - k), -100.0 * (1.0 - k) * (1.0 - k))
		Icons.part(ci, drop.floor(), String(spots[i][2]), 2.0)
		if k > 0.85:
			for s in 6:
				var a := s * TAU / 6.0
				ci.draw_rect(Rect2(p.x + cos(a) * 12.0, p.y + sin(a) * 8.0, 2, 2), Color("fff1a8"))
		ci.draw_string(font, p + Vector2(-70, 26), String(spots[i][1]), HORIZONTAL_ALIGNMENT_CENTER, 140, 8, Color("2a1e14"))
	# Four more question marks, for the parts still to come.
	for i in 4:
		var q := Vector2(vs.x * (0.66 + i * 0.07), vs.y * 0.16)
		ci.draw_string(font, q, "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.2, 0.15, 0.1, 0.5 + 0.3 * sin(t * 3.0 + i)))


static func _sunrise(ci: CanvasItem, vs: Vector2, t: float) -> void:
	Backdrop.draw_scene(ci, vs, Vector2(900 + t * 20.0, 0), Backdrop.theme(12, "dusk"), t)
	var ground := vs.y * 0.82
	ci.draw_rect(Rect2(0, ground, vs.x, vs.y), Color("3e5a2a"))
	ci.draw_rect(Rect2(0, ground, vs.x, 3), Color("6a8a4a"))
	ci.draw_set_transform(Vector2(vs.x * 0.66, ground), 0.0, Vector2(3.0, 3.0))
	grandma(ci, Vector2.ZERO, t, false, 0.0, true)
	ci.draw_set_transform(Vector2(vs.x * 0.36, ground), 0.0, Vector2(3.0, 3.0))
	var rig := GameState.loadout()
	BikeView.draw_rig(ci, Vector2.ZERO, rig, t * 6.0, t, 0.0, 0.5)
	ci.draw_set_transform(Vector2.ZERO)
