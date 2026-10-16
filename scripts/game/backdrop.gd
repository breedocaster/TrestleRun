## Screen-space parallax background. Lives in a CanvasLayer behind the world and
## reads the camera position each frame. Each trail has day/dusk/night palettes;
## weather tints them and adds cloud cover.
extends Node2D

const TIMES := ["day", "dusk", "night"]

var theme_index := 0
var time_mode := "dusk"
var weather := "clear"
var cam := Vector2.ZERO
## Optional depth director: draw_far() runs between the far and mid ridges and
## draw_mid() between the mid ridge and the near band, so things sit in depth.
var hooks: Object = null

static var _base: Array = []


## Palette for trail `i` at a time of day, tinted for weather.
static func theme(i: int, time: String = "dusk", wx: String = "clear") -> Dictionary:
	if _base.is_empty():
		_build()
	var variants: Dictionary = _base[clampi(i, 0, _base.size() - 1)]
	var th: Dictionary = (variants.get(time, variants.dusk) as Dictionary).duplicate(true)
	th.time = time
	th.weather = wx
	match wx:
		"rain":
			var grey := Color.html("1a1f28") if time == "night" else Color.html("5b6370")
			var sky: Array = []
			for c in th.sky:
				sky.append((c as Color).lerp(grey, 0.55).darkened(0.12))
			th.sky = sky
			for k in ["far", "mid", "near"]:
				th[k] = (th[k] as Color).lerp(grey, 0.25).darkened(0.08)
			th.deck_hi = (th.deck_hi as Color).lerp(Color.html("cfe0f0"), 0.4)
			th.sun_visible = false
			th.clouds = 1.0
		"wind":
			if time != "night":
				var dust := Color.html("d9b98c")
				var sky2: Array = []
				for c in th.sky:
					sky2.append((c as Color).lerp(dust, 0.14))
				th.sky = sky2
			th.clouds = 0.45
	return th


static func _build() -> void:
	_base = [
		{ # Dusty Trail: desert trestles
			"day": _t(["3b7dd8", "5795e2", "78afea", "a3caf1", "d3e8f7"], "fffbe6", 13.0, 0.2,
				"d9925f", "b8673f", "7e3b2b", "cactus", false, "c08a4a", "f0c27a", "6b3f2a", "4a2a1e"),
			"dusk": _t(["2b1b3d", "5a2a52", "a8445a", "e27a50", "f4b866"], "fff1c1", 18.0, 0.42,
				"8a4a5a", "5e2f45", "3a1c2e", "cactus", false, "c08a4a", "f0c27a", "6b3f2a", "4a2a1e"),
			"night": _t(["03040c", "070a1c", "0d1330", "161f45", "222c5c"], "e8edf7", 10.0, 0.25,
				"3a2a44", "261c33", "140f1e", "cactus", true, "6e5440", "a88a68", "34262a", "1f171a"),
		},
		{ # Copper Canyon: red rock
			"day": _t(["2f6fc4", "4d8ad5", "70a6e1", "9cc3ec", "cde2f5"], "fffbe6", 13.0, 0.2,
				"cf6a40", "a3462f", "5e2a22", "rocks", false, "a8673e", "e3a26a", "5a3324", "3a2018"),
			"dusk": _t(["1d1430", "3b1d40", "7a2f45", "c2553f", "e88b4b"], "ffd9a0", 14.0, 0.42,
				"9a3f2e", "6e2a24", "3a161a", "rocks", false, "a8673e", "e3a26a", "5a3324", "3a2018"),
			"night": _t(["04030c", "0b0820", "161036", "22194d", "302566"], "e8edf7", 10.0, 0.25,
				"3d2235", "2a1826", "160c16", "rocks", true, "5e4034", "93705a", "2e1d1a", "1c110f"),
		},
		{ # Rustyard: scrapyard flats
			"day": _t(["5d87ad", "789fbf", "97b6cd", "b8cdd9", "dae5e6"], "fffbe6", 14.0, 0.22,
				"74857a", "56655d", "36403b", "junk", false, "9a5f3a", "d08a52", "4c3a30", "2e231d"),
			"dusk": _t(["15202a", "24363c", "3f5a52", "7f8e6a", "c9b77a"], "e8d9a0", 22.0, 0.42,
				"3c4a46", "2a3532", "1a2120", "junk", false, "9a5f3a", "d08a52", "4c3a30", "2e231d"),
			"night": _t(["030507", "080e12", "0f191d", "182628", "213335"], "e8edf7", 10.0, 0.25,
				"1f2a27", "151d1b", "0b100f", "junk", true, "4e382a", "7d5a40", "261d18", "17110e"),
		},
		{ # Night Trestle: steel bridge over the plains
			"day": _t(["2a5fb0", "4479c4", "6596d4", "8fb4e2", "c3d8ef"], "fffbe6", 13.0, 0.2,
				"5c70a3", "425380", "283253", "poles", false, "8a90a8", "c9d1e6", "4a5070", "2e3350"),
			"dusk": _t(["15102c", "2b1c4c", "4b2c66", "7d4677", "b5687a"], "ffd9a0", 14.0, 0.42,
				"3b2f5e", "292046", "16122c", "poles", false, "6a6f8a", "a9b4d6", "2e3350", "1c2036"),
			"night": _t(["05060f", "0b1230", "16214a", "263266", "3a4680"], "e8edf7", 11.0, 0.25,
				"1f2752", "141a3a", "0a0e20", "poles", true, "6a6f8a", "a9b4d6", "2e3350", "1c2036"),
		},
		{ # Mesa Springs: pink flat-top buttes and hot springs
			"day": _t(["4a8fd6", "68a6e0", "8cbfe8", "b5d8f0", "e2f0f5"], "fffbe6", 13.0, 0.2,
				"e0a080", "c97a63", "8e4a46", "mesa", false, "b88454", "f0c48a", "6b4030", "48281e"),
			"dusk": _t(["241838", "4a2450", "8e3a63", "d9665a", "f5a96a"], "ffe0a8", 16.0, 0.4,
				"9a5068", "6e3450", "3e1e33", "mesa", false, "b88454", "f0c48a", "6b4030", "48281e"),
			"night": _t(["040410", "0a0a24", "141640", "1e2458", "2c3470"], "e8edf7", 10.0, 0.25,
				"3a2c4c", "281e38", "140f20", "mesa", true, "6a5040", "a08468", "34262a", "1f171a"),
		},
		{ # Lantern Mine: ochre hills, mine headframes
			"day": _t(["4f7fb8", "6c96c6", "8fb0d4", "b4c9de", "d9e2e8"], "fffbe6", 14.0, 0.22,
				"a89a80", "857560", "4e4232", "headframe", false, "8a6a48", "c9a070", "4a3a2c", "2e241c"),
			"dusk": _t(["1a1428", "33203a", "5e3444", "a0583e", "d9934c"], "ffd9a0", 15.0, 0.42,
				"6a4a48", "4a3438", "261a1e", "headframe", false, "8a6a48", "c9a070", "4a3a2c", "2e241c"),
			"night": _t(["030308", "080812", "10121e", "1a1e2e", "262c40"], "e8edf7", 10.0, 0.25,
				"2c2a30", "1e1c22", "100e12", "headframe", true, "5a4636", "8a6e54", "2c221c", "1a1410"),
		},
		{ # Hoodoo Loops: red rock spires
			"day": _t(["2d6cc0", "4a86d0", "6ea2dc", "9dc0e8", "d0e2f2"], "fffbe6", 13.0, 0.2,
				"e08a50", "c2603a", "7a3220", "hoodoo", false, "b0703e", "eaa868", "5e3420", "3e2216"),
			"dusk": _t(["2a1230", "55203e", "9a3442", "e0603a", "f8a048"], "ffe0a0", 16.0, 0.42,
				"a8483a", "7a2e2e", "3e161a", "hoodoo", false, "b0703e", "eaa868", "5e3420", "3e2216"),
			"night": _t(["05030a", "0e0818", "1a1030", "281a48", "382660"], "e8edf7", 10.0, 0.25,
				"43263a", "2e1a2a", "180c16", "hoodoo", true, "6a4436", "9a6e56", "32201a", "1e1410"),
		},
		{ # Hoist Yard: gantry cranes over the freight yard
			"day": _t(["6a8fb0", "86a6c2", "a4bed2", "c4d4e0", "e2e8ec"], "fffbe6", 14.0, 0.22,
				"8c96a0", "6c7680", "3c444c", "crane", false, "9a6a46", "d29a66", "4a4048", "2e2a30"),
			"dusk": _t(["161c2c", "262e44", "464a5e", "8a6a62", "d0906a"], "e8d9a0", 18.0, 0.42,
				"4a4c5e", "34364a", "1c1e2a", "crane", false, "9a6a46", "d29a66", "4a4048", "2e2a30"),
			"night": _t(["020306", "06080e", "0c1018", "141a26", "1e2636"], "e8edf7", 10.0, 0.25,
				"22262e", "181a22", "0c0e14", "crane", true, "5a4034", "8a6650", "2a262c", "18161a"),
		},
		{ # Skyline Pass: alpine pines under snowy peaks
			"day": _t(["2f6ad0", "4c85dc", "70a2e6", "9cc2ee", "d4e6f6"], "fffbe6", 12.0, 0.18,
				"8fa8c8", "4e7a5e", "2a4a36", "pines", false, "a07a50", "dcb07a", "50402e", "32281e"),
			"dusk": _t(["1c1838", "342a5a", "5a3a72", "a05a78", "e8907a"], "ffd9b0", 15.0, 0.42,
				"5a5a8a", "34465a", "1a2630", "pines", false, "a07a50", "dcb07a", "50402e", "32281e"),
			"night": _t(["03040c", "070c20", "0e1838", "182650", "243468"], "e8edf7", 10.0, 0.25,
				"2e3a5a", "1a2a34", "0c161c", "pines", true, "5e4a38", "8e745a", "2e261e", "1c1812"),
		},
	]
	_base.append({ # Quarry Cliffs: pale sandstone benches cut into the hills
		"day": _t(["3f86d8", "5c9ae0", "80b2e8", "a8cbef", "d6e8f6"], "fffbe6", 13.0, 0.2,
			"c8b090", "a88e6c", "6e5a44", "quarry", false, "b89a6a", "ecd2a0", "5e4a36", "3c2e22"),
		"dusk": _t(["241a34", "4a2a48", "8a4a50", "d07a50", "f0b070"], "ffe0a8", 16.0, 0.42,
			"8a6a60", "684c48", "3a2a28", "quarry", false, "b89a6a", "ecd2a0", "5e4a36", "3c2e22"),
		"night": _t(["040410", "0a0c22", "141a3a", "1e2a52", "2c3a6a"], "e8edf7", 10.0, 0.25,
			"3a3440", "28242e", "141218", "quarry", true, "6a5a46", "9a8668", "2e261e", "1c1812"),
	})
	_base.append({ # Rocket Ridge: red desert test range, launch towers on the skyline
		"day": _t(["2a6ad0", "4a86dc", "70a4e6", "9cc4ee", "d8e8f8"], "fffbe6", 12.0, 0.2,
			"d07848", "a84a34", "5a2a22", "gantry", false, "c8ccd4", "f4f6f8", "9a3a30", "5a221c"),
		"dusk": _t(["1a1030", "3a1848", "7a2850", "c84a48", "f09a58"], "ffd0a0", 15.0, 0.42,
			"8a3a40", "602836", "301420", "gantry", false, "c8ccd4", "f4f6f8", "9a3a30", "5a221c"),
		"night": _t(["020208", "060818", "0c1230", "141c48", "1e2860"], "e8edf7", 10.0, 0.25,
			"302438", "201a2a", "100c16", "gantry", true, "7a7e88", "b0b4bc", "5a2620", "341612"),
	})
	_base.append({ # Last Trestle: the old line over the gorge, broken bents in the distance
		"day": _t(["4a5a70", "62728a", "7c8ca2", "9aa8ba", "c0c8d2"], "f4f0e0", 12.0, 0.22,
			"6a7280", "4a5260", "282c34", "ruin", false, "8a7a62", "bcae94", "4a3e30", "2c241c"),
		"dusk": _t(["160c18", "34142a", "6a2030", "b23a2a", "e8783a"], "ffb070", 18.0, 0.45,
			"5a2a2e", "3c1c24", "1c0e12", "ruin", false, "8a7a62", "bcae94", "4a3e30", "2c241c"),
		"night": _t(["020204", "06060e", "0c0c1a", "141426", "1e1e36"], "e8edf7", 10.0, 0.25,
			"2a2430", "1c1822", "0e0c12", "ruin", true, "5a5044", "8a7e6c", "2e261e", "1a1612"),
	})
	for i in [8]:
		for k in TIMES:
			_base[i][k].snow = true


static func _t(sky: Array, sun: String, sun_r: float, sun_y: float, far: String, mid: String,
		near: String, props: String, stars: bool, deck: String, deck_hi: String, beam: String,
		beam_dark: String) -> Dictionary:
	var sky_c: Array = []
	for s in sky:
		sky_c.append(Color.html(s))
	return {
		"sky": sky_c, "sun": Color.html(sun), "sun_r": sun_r, "sun_y": sun_y, "sun_visible": true,
		"far": Color.html(far), "mid": Color.html(mid), "near": Color.html(near),
		"props": props, "stars": stars, "clouds": 0.0,
		"deck": Color.html(deck), "deck_hi": Color.html(deck_hi),
		"beam": Color.html(beam), "beam_dark": Color.html(beam_dark),
	}


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	draw_scene(self, get_viewport_rect().size, cam, theme(theme_index, time_mode, weather),
		Time.get_ticks_msec() / 1000.0, hooks)


## Also used for level-select thumbnails, so it draws into any CanvasItem.
static func draw_scene(ci: CanvasItem, vs: Vector2, cam: Vector2, th: Dictionary, t: float, hooks: Object = null) -> void:
	var sky: Array = th.sky
	var horizon := vs.y * 0.7
	var bh := ceilf(horizon / sky.size())
	for i in sky.size():
		ci.draw_rect(Rect2(0, i * bh, vs.x, bh + 1), sky[i])
	ci.draw_rect(Rect2(0, sky.size() * bh, vs.x, vs.y), sky[sky.size() - 1])
	# Checker dither on band edges for that pixel-art gradient look.
	for i in range(1, sky.size()):
		var yy := i * bh
		var xx := 0.0
		while xx < vs.x:
			ci.draw_rect(Rect2(xx, yy - 1, 1, 1), sky[i])
			ci.draw_rect(Rect2(xx + 1, yy, 1, 1), sky[i - 1])
			xx += 2.0

	var vy := clampf(-cam.y, -120.0, 120.0)
	if th.stars and th.weather != "rain":
		for i in 48:
			var sx := fposmod(_hash(i * 3.1) * 997.0 - cam.x * 0.02, vs.x)
			var sy := _hash(i * 7.7) * horizon * 0.9
			var tw := 0.55 + 0.45 * sin(t * 2.0 + i)
			ci.draw_rect(Rect2(floorf(sx), floorf(sy), 1, 1), Color(1, 1, 1, tw))

	if th.sun_visible:
		var sun_p := Vector2(vs.x * 0.74, horizon * float(th.sun_y) + vy * 0.03)
		ci.draw_circle(sun_p, th.sun_r + 3.0, Color(th.sun, 0.25))
		ci.draw_circle(sun_p, th.sun_r, th.sun)
		if th.time == "night":
			ci.draw_circle(sun_p + Vector2(3, -2), th.sun_r * 0.25, Color(th.sky[2], 0.35))
			ci.draw_circle(sun_p + Vector2(-4, 3), th.sun_r * 0.18, Color(th.sky[2], 0.3))

	if float(th.clouds) > 0.0:
		_clouds(ci, vs, cam.x * 0.05 + t * (14.0 if th.weather == "wind" else 4.0), horizon, th)

	_ridge(ci, vs, cam.x * 0.12, horizon - 8.0 + vy * 0.08, 46.0, 70.0, th.far, 3.0, 6.0,
		(th.far as Color).lerp(Color.WHITE, 0.55) if th.get("snow", false) else Color(0, 0, 0, 0))
	if hooks:
		hooks.draw_far(ci, vs, cam, th, horizon, vy)
	_ridge(ci, vs, cam.x * 0.3, horizon + 26.0 + vy * 0.18, 34.0, 44.0, th.mid, 11.0, 2.0)
	if hooks:
		hooks.draw_mid(ci, vs, cam, th, horizon, vy)
	_props(ci, vs, cam.x * 0.55, horizon + 58.0 + vy * 0.3, th)


static func _clouds(ci: CanvasItem, vs: Vector2, off: float, horizon: float, th: Dictionary) -> void:
	var heavy: bool = th.weather == "rain"
	var base_c: Color = (th.sky[1] as Color).lerp(Color.WHITE, 0.25 if th.time == "day" else 0.08)
	if heavy:
		base_c = (th.sky[0] as Color).darkened(0.15)
		ci.draw_rect(Rect2(0, 0, vs.x, horizon * 0.18), base_c)
	var cell := 70.0
	var c0 := int(floor(off / cell)) - 1
	var c1 := int(ceil((off + vs.x) / cell)) + 1
	for c in range(c0, c1):
		if not heavy and _hash(c * 4.7) < 1.0 - float(th.clouds) * 0.8:
			continue
		var cx := floorf(c * cell + _hash(c * 1.9) * 30.0 - off)
		var cy := floorf(horizon * (0.08 + _hash(c * 2.3) * (0.18 if heavy else 0.3)))
		var w := floorf(34.0 + _hash(c * 6.1) * 40.0)
		var col := base_c if not heavy else base_c.lightened(_hash(c * 3.3) * 0.12)
		ci.draw_rect(Rect2(cx, cy, w, 6), col)
		ci.draw_rect(Rect2(cx + 6, cy - 4, w - 16, 4), col)
		ci.draw_rect(Rect2(cx + 12, cy - 7, w * 0.35, 3), col)
		if heavy:
			ci.draw_rect(Rect2(cx - 4, cy + 6, w + 8, 4), col.darkened(0.1))


static func _ridge(ci: CanvasItem, vs: Vector2, off: float, base: float, amp: float,
		scale: float, col: Color, seed: float, quant: float, cap := Color(0, 0, 0, 0)) -> void:
	var step := 4.0
	var sx := -fposmod(off, step)
	while sx < vs.x + step:
		var h := _noise((sx + off) / scale + seed) * amp
		h = roundf(h / quant) * quant
		var top := floorf(base - h)
		ci.draw_rect(Rect2(sx, top, step, vs.y - top), col)
		if cap.a > 0.0 and h > amp * 0.55:
			ci.draw_rect(Rect2(sx, top, step, floorf((h - amp * 0.55) * 0.5) + 2.0), cap)
		sx += step


static func _props(ci: CanvasItem, vs: Vector2, off: float, base: float, th: Dictionary) -> void:
	var col: Color = th.near
	ci.draw_rect(Rect2(0, base, vs.x, vs.y - base), col)
	var cell := 96.0
	var c0 := int(floor(off / cell)) - 1
	var c1 := int(ceil((off + vs.x) / cell)) + 1
	for c in range(c0, c1):
		if _hash(c * 1.37) < 0.35:
			continue
		var px := floorf(c * cell + _hash(c * 2.11) * 50.0 - off)
		var sz := 0.7 + _hash(c * 5.3) * 0.6
		match th.props:
			"cactus":
				var h := floorf(16.0 * sz + 6.0)
				ci.draw_rect(Rect2(px, base - h, 4, h), col)
				ci.draw_rect(Rect2(px - 5, base - h * 0.6, 3, 6), col)
				ci.draw_rect(Rect2(px - 5, base - h * 0.6 + 4, 6, 2), col)
				ci.draw_rect(Rect2(px + 6, base - h * 0.75, 3, 5), col)
				ci.draw_rect(Rect2(px + 3, base - h * 0.75 + 3, 6, 2), col)
			"rocks":
				var w := floorf(18.0 * sz)
				ci.draw_rect(Rect2(px, base - 8 * sz, w, 8 * sz + 1), col)
				ci.draw_rect(Rect2(px + 3, base - 14 * sz, w - 8, 6 * sz + 1), col)
			"junk":
				ci.draw_rect(Rect2(px, base - 10, 22, 10), col)
				ci.draw_rect(Rect2(px + 4, base - 16, 12, 6), col)
				ci.draw_rect(Rect2(px + 18, base - 26 * sz, 2, 26 * sz), col)
				ci.draw_rect(Rect2(px + 12, base - 26 * sz, 14, 2), col)
			"mesa":
				var w := floorf(46.0 * sz)
				var h := floorf(16.0 * sz + 6.0)
				ci.draw_colored_polygon(PackedVector2Array([Vector2(px, base), Vector2(px + 6, base - h),
					Vector2(px + w - 6, base - h), Vector2(px + w, base)]), col)
				ci.draw_rect(Rect2(px + 4, base - h - 2, w - 8, 2), col)
			"headframe":
				if _hash(c * 3.7) < 0.5:
					var h := floorf(30.0 * sz + 8.0)
					ci.draw_line(Vector2(px, base), Vector2(px + 8, base - h), col, 2.0)
					ci.draw_line(Vector2(px + 16, base), Vector2(px + 8, base - h), col, 2.0)
					ci.draw_line(Vector2(px + 3, base - h * 0.5), Vector2(px + 13, base - h * 0.5), col, -1.0)
					ci.draw_arc(Vector2(px + 8, base - h), 4.0, 0.0, TAU, 10, col, 1.0)
					ci.draw_rect(Rect2(px + 18, base - 10, 14, 10), col)
				else:
					ci.draw_rect(Rect2(px, base - 8 * sz, 20 * sz, 8 * sz + 1), col)
			"hoodoo":
				var h := floorf(26.0 * sz + 10.0)
				ci.draw_rect(Rect2(px + 2, base - h, 6, h), col)
				ci.draw_rect(Rect2(px, base - h * 0.45, 10, h * 0.45), col)
				ci.draw_rect(Rect2(px - 1, base - h - 3, 12, 4), col)
				if _hash(c * 8.1) < 0.5:
					ci.draw_rect(Rect2(px + 16, base - h * 0.6, 5, h * 0.6), col)
					ci.draw_rect(Rect2(px + 15, base - h * 0.6 - 2, 7, 3), col)
			"crane":
				if _hash(c * 3.7) < 0.55:
					var h := floorf(34.0 * sz + 6.0)
					ci.draw_rect(Rect2(px, base - h, 3, h), col)
					ci.draw_rect(Rect2(px - 10, base - h, 34, 2), col)
					ci.draw_line(Vector2(px + 1, base - h - 6), Vector2(px + 24, base - h), col, -1.0)
					ci.draw_line(Vector2(px + 1, base - h - 6), Vector2(px - 10, base - h), col, -1.0)
					ci.draw_line(Vector2(px + 18, base - h), Vector2(px + 18, base - h * 0.45), col, -1.0)
					ci.draw_rect(Rect2(px + 15, base - h * 0.45, 7, 4), col)
				else:
					ci.draw_rect(Rect2(px, base - 9, 26, 9), col)
					ci.draw_rect(Rect2(px + 28, base - 9, 22, 9), col)
			"pines":
				for k in 3:
					var tx := px + k * 9.0 * sz
					var h := floorf((18.0 + 8.0 * _hash(c * 2.0 + k)) * sz)
					ci.draw_colored_polygon(PackedVector2Array([Vector2(tx - 5, base), Vector2(tx, base - h), Vector2(tx + 5, base)]), col)
			"quarry":
				# Stepped benches cut into the rock, sometimes a derrick.
				var w := floorf(40.0 * sz)
				for k in 3:
					ci.draw_rect(Rect2(px + k * 6, base - 8 - k * 7, w - k * 12, 8 + k * 7), col)
				if _hash(c * 6.6) < 0.4:
					var h := floorf(30.0 * sz + 6.0)
					ci.draw_line(Vector2(px + w, base), Vector2(px + w, base - h), col, 2.0)
					ci.draw_line(Vector2(px + w, base - h), Vector2(px + w - 22, base - h * 0.55), col, -1.0)
					ci.draw_line(Vector2(px + w - 18, base - h * 0.6), Vector2(px + w - 18, base - h * 0.3), col, -1.0)
			"gantry":
				if _hash(c * 3.7) < 0.5:
					# Launch tower with a rocket beside it; a red light blinks on top.
					var h := floorf(40.0 * sz + 10.0)
					ci.draw_rect(Rect2(px, base - h, 6, h), col)
					ci.draw_rect(Rect2(px + 9, base - h * 0.8, 5, h * 0.8), col)
					ci.draw_colored_polygon(PackedVector2Array([Vector2(px + 9, base - h * 0.8), Vector2(px + 11.5, base - h * 0.8 - 6),
						Vector2(px + 14, base - h * 0.8)]), col)
					if int(Time.get_ticks_msec() / 600) % 2 == 0:
						ci.draw_rect(Rect2(px + 2, base - h - 2, 2, 2), Color("ff5040"))
				else:
					ci.draw_rect(Rect2(px, base - 6, 30 * sz, 6), col)
					ci.draw_rect(Rect2(px + 4, base - 12, 10, 6), col)
			"ruin":
				# Broken trestle bents: legs that end in splinters, one leaning.
				var h := floorf(30.0 * sz + 10.0)
				ci.draw_line(Vector2(px, base), Vector2(px + 6, base - h), col, 2.0)
				ci.draw_line(Vector2(px + 16, base), Vector2(px + 10, base - h * 0.7), col, 2.0)
				ci.draw_line(Vector2(px + 2, base - h * 0.4), Vector2(px + 14, base - h * 0.45), col, -1.0)
				if _hash(c * 2.9) < 0.5:
					ci.draw_line(Vector2(px + 26, base), Vector2(px + 40, base - h * 0.8), col, 2.0)
			"poles":
				ci.draw_rect(Rect2(px, base - 34, 2, 34), col)
				ci.draw_rect(Rect2(px - 5, base - 32, 12, 2), col)
				ci.draw_line(Vector2(px + 6, base - 31), Vector2(px + cell + 6, base - 31), Color(col, 0.7), -1.0)
				if th.time == "night":
					ci.draw_rect(Rect2(px - 5, base - 33, 1, 1), Color("ffcf6a"))


static func _hash(n: float) -> float:
	var s := sin(n * 12.9898) * 43758.5453
	return s - floorf(s)


static func _noise(x: float) -> float:
	var i := floorf(x)
	var f := x - i
	var u := f * f * (3.0 - 2.0 * f)
	return lerpf(_hash(i), _hash(i + 1.0), u)
