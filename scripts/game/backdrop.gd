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
	]


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

	_ridge(ci, vs, cam.x * 0.12, horizon - 8.0 + vy * 0.08, 46.0, 70.0, th.far, 3.0, 6.0)
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
		scale: float, col: Color, seed: float, quant: float) -> void:
	var step := 4.0
	var sx := -fposmod(off, step)
	while sx < vs.x + step:
		var h := _noise((sx + off) / scale + seed) * amp
		h = roundf(h / quant) * quant
		var top := floorf(base - h)
		ci.draw_rect(Rect2(sx, top, step, vs.y - top), col)
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
