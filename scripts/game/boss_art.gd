## Story bosses: alien machines, each clutching one part of Grandpa's bike. Drawn at
## the weak spot's base (bottom middle of its glowing top), which is where the physics
## puts the hitbox, so what you see is what you land on.
extends RefCounted

const Icons := preload("res://scripts/game/icons.gd")

const STEEL := Color("4a4f5c")
const STEEL_HI := Color("9aa3ad")
const GLASS := Color(0.55, 1.0, 0.72, 0.6)
const ALIEN := Color("7ad85a")

const NAMES := {
	"scooper": "THE SCOOPER", "hog": "RAIL HOG", "harvester": "THE HARVESTER", "spinner": "THE SPINNER",
}
const PART_NAMES := {
	"headlight": "HEADLIGHT", "kickstart": "KICKSTART", "seat": "SEAT", "wheels": "WHEELS",
	"carb": "CARBURETOR", "top_end": "TOP END", "bottom_end": "BOTTOM END", "frame": "FRAME",
}


static func boss_name(kind: String) -> String:
	return String(NAMES.get(kind, kind.to_upper()))


static func part_name(part: String) -> String:
	return String(PART_NAMES.get(part, part.to_upper()))


## Where to draw a boss whose weak spot is `spot` this frame.
static func anchor(_kind: String, spot: Rect2) -> Vector2:
	return Vector2(spot.position.x + spot.size.x * 0.5, spot.end.y)


## hurt: 1 just hit, fading to 0. part: what it's still holding ("" once dropped).
## ground: a y below the play area, for things that reach the ground (legs, beams).
static func draw(ci: CanvasItem, kind: String, o: Vector2, t: float, hurt: float, hp: int, part: String,
		ground: float) -> void:
	if hurt > 0.0:
		o += Vector2(sin(t * 60.0) * 2.0 * hurt, 0.0)
	match kind:
		"hog":
			_hog(ci, o, t, hurt, hp, part, ground)
		"harvester":
			_harvester(ci, o, t, hurt, hp, part, ground)
		"spinner":
			_saucer(ci, o, t, hurt, hp, part, true)
		_:
			_saucer(ci, o, t, hurt, hp, part, false)


static func _flash(c: Color, hurt: float, t: float) -> Color:
	if hurt > 0.4 and int(t * 24.0) % 2 == 0:
		return c.lerp(Color.WHITE, 0.75)
	return c


## Weak-spot shimmer: a pulsing ring so it reads as "land here".
static func _spot_glow(ci: CanvasItem, c: Vector2, r: float, t: float, hp: int) -> void:
	if hp <= 0:
		return
	var a := 0.35 + 0.3 * sin(t * 7.0)
	ci.draw_arc(c, r + 2.0, PI, TAU, 14, Color(0.7, 1.0, 0.75, a), -1.0)
	for i in 3:
		var sx := c.x - r + 4.0 + i * (r - 4.0)
		var sy := c.y - r * 0.6 - 4.0 - fposmod(t * 10.0 + i * 3.0, 6.0)
		ci.draw_rect(Rect2(sx, sy, 1, 2), Color(0.8, 1.0, 0.8, a))


## Flying saucer. o = base of the glass dome (the weak spot). big: the Spinner.
static func _saucer(ci: CanvasItem, o: Vector2, t: float, hurt: float, hp: int, part: String, big: bool) -> void:
	var w := 26.0 if big else 20.0
	var hull := _flash(Color("a8b0bc") if not big else Color("c8a0d8"), hurt, t)
	var hull_dark := _flash(Color("4a4f5c") if not big else Color("5a3a6a"), hurt, t)
	# Tractor beam underneath, holding the part.
	if part != "":
		var beam := Color(0.6, 1.0, 0.7, 0.10 + 0.04 * sin(t * 9.0))
		ci.draw_colored_polygon(PackedVector2Array([o + Vector2(-6, 8), o + Vector2(6, 8), o + Vector2(12, 26), o + Vector2(-12, 26)]), beam)
		Icons.part(ci, (o + Vector2(0, 20 + sin(t * 3.0))).floor(), part, 1.0)
	# The hull: a wide disc with a lip, a darker belly, and running lights.
	ci.draw_colored_polygon(PackedVector2Array([o + Vector2(-w, 2), o + Vector2(-w + 4, -1), o + Vector2(w - 4, -1), o + Vector2(w, 2),
		o + Vector2(w - 3, 6), o + Vector2(-w + 3, 6)]), hull)
	ci.draw_rect(Rect2(o.x - w + 4, o.y - 1, w * 2 - 8, 1), hull.lightened(0.35))
	ci.draw_colored_polygon(PackedVector2Array([o + Vector2(-w + 3, 6), o + Vector2(w - 3, 6), o + Vector2(w - 9, 9), o + Vector2(-w + 9, 9)]), hull_dark)
	ci.draw_rect(Rect2(o.x - 4, o.y + 8, 8, 2), Color(0.6, 1.0, 0.7, 0.8))
	var n := 7 if big else 5
	for i in n:
		var lx := o.x - w + 5 + i * (w * 2.0 - 10.0) / float(n - 1)
		var lit := int(t * (10.0 if big else 6.0) + i) % 3 == 0
		ci.draw_rect(Rect2(lx - 1, o.y + 2, 2, 2), Color("fff1a8") if lit else Color("e04848"))
	if big:
		# The Spinner's ring of fins turns round the hull.
		for i in 6:
			var a := t * 4.0 + i * TAU / 6.0
			var fx := o.x + cos(a) * (w + 3.0)
			if sin(a) > 0.0:
				ci.draw_rect(Rect2(fx - 1, o.y + 1, 3, 4), hull_dark)
	# Glass dome with the pilot inside.
	var r := 11.0 if not big else 12.0
	var dome := PackedVector2Array()
	for i in 13:
		var a := PI + PI * float(i) / 12.0
		dome.append(o + Vector2(cos(a) * r, sin(a) * r))
	ci.draw_colored_polygon(dome, GLASS)
	ci.draw_circle(o + Vector2(0, -4), 4.0, ALIEN)
	ci.draw_rect(Rect2(o.x - 3, o.y - 5, 2, 2), Color.BLACK)
	ci.draw_rect(Rect2(o.x + 1, o.y - 5, 2, 2), Color.BLACK)
	ci.draw_line(o + Vector2(-2, -8), o + Vector2(-4, -11), ALIEN, -1.0)
	ci.draw_line(o + Vector2(2, -8), o + Vector2(4, -11), ALIEN, -1.0)
	ci.draw_arc(o, r, PI, TAU, 13, Color(0.85, 1.0, 0.9, 0.9), -1.0)
	ci.draw_line(o + Vector2(-6, -8), o + Vector2(-3, -10), Color(1, 1, 1, 0.8), -1.0)
	_spot_glow(ci, o, r, t, hp)


## Rail Hog: a junk locomotive head with a glass hatch on top (the weak spot). It
## rides up out of the pit under the rails; its body goes down out of sight.
static func _hog(ci: CanvasItem, o: Vector2, t: float, hurt: float, hp: int, part: String, ground: float) -> void:
	var rust := _flash(Color("8a5a3a"), hurt, t)
	var rust_d := _flash(Color("5a3424"), hurt, t)
	var bottom := maxf(o.y + 60.0, ground)
	ci.draw_rect(Rect2(o.x - 17, o.y, 34, bottom - o.y), rust_d)
	ci.draw_rect(Rect2(o.x - 16, o.y, 32, bottom - o.y), rust)
	ci.draw_rect(Rect2(o.x - 16, o.y, 32, 2), rust.lightened(0.25))
	# Rivet rows.
	for yy in [o.y + 6.0, o.y + 34.0]:
		for i in 6:
			ci.draw_rect(Rect2(o.x - 13 + i * 5, yy, 1, 1), Color("c89a6a"))
	# Face toward the rider (left): lamp eyes and a grille of teeth.
	var blink := 0.7 + 0.3 * sin(t * 5.0)
	ci.draw_rect(Rect2(o.x - 14, o.y + 9, 5, 4), Color(1.0, 0.3, 0.2, blink))
	ci.draw_rect(Rect2(o.x - 6, o.y + 9, 5, 4), Color(1.0, 0.3, 0.2, blink))
	ci.draw_rect(Rect2(o.x - 15, o.y + 18, 18, 9), Color("2a2a30"))
	for i in 5:
		ci.draw_colored_polygon(PackedVector2Array([Vector2(o.x - 14 + i * 3.5, o.y + 18), Vector2(o.x - 12.5 + i * 3.5, o.y + 22),
			Vector2(o.x - 11 + i * 3.5, o.y + 18)]), Color("d8d8d8"))
	if part != "":
		Icons.part(ci, (o + Vector2(-18, 24)).floor(), part, 1.0)
	# Smokestack puffing.
	ci.draw_rect(Rect2(o.x + 8, o.y - 9, 5, 9), Color("3a3440"))
	ci.draw_rect(Rect2(o.x + 7, o.y - 10, 7, 2), Color("2a2a30"))
	for i in 3:
		var k := fposmod(t * 1.2 + i * 0.33, 1.0)
		ci.draw_circle(Vector2(o.x + 10 + k * 8.0, o.y - 12 - k * 20.0), 2.0 + k * 3.0, Color(0.5, 0.5, 0.55, 0.5 * (1.0 - k)))
	# Glass hatch on top with the driver.
	var dome := PackedVector2Array()
	for i in 13:
		var a := PI + PI * float(i) / 12.0
		dome.append(o + Vector2(cos(a) * 11.0, sin(a) * 9.0))
	ci.draw_colored_polygon(dome, GLASS)
	ci.draw_circle(o + Vector2(0, -3), 3.5, ALIEN)
	ci.draw_rect(Rect2(o.x - 2, o.y - 4, 1, 2), Color.BLACK)
	ci.draw_rect(Rect2(o.x + 1, o.y - 4, 1, 2), Color.BLACK)
	ci.draw_rect(Rect2(o.x - 12, o.y - 1, 24, 2), STEEL)
	_spot_glow(ci, o, 10.0, t, hp)


## The Harvester: a stilt-legged walker towering over the orchard; its head pod hangs
## low on a cable (the weak spot is the pod's glass top).
static func _harvester(ci: CanvasItem, o: Vector2, t: float, hurt: float, hp: int, part: String, ground: float) -> void:
	var hub := o + Vector2(18, -150)
	var leg := Color(0.22, 0.2, 0.26, 0.85)
	var step := sin(t * 1.4) * 10.0
	for spec in [[-70.0, 0.0], [10.0, 1.0], [90.0, 2.0]]:
		var foot := Vector2(o.x + float(spec[0]) + step * (1.0 if int(spec[1]) % 2 == 0 else -1.0), ground)
		var knee := hub.lerp(foot, 0.45) + Vector2(float(spec[0]) * 0.25, -30.0)
		ci.draw_line(hub, knee, leg, 3.0)
		ci.draw_line(knee, foot, leg, 2.0)
		ci.draw_circle(knee, 2.5, leg)
	ci.draw_circle(hub, 12.0, Color(0.25, 0.22, 0.3, 0.9))
	ci.draw_rect(Rect2(hub.x - 6, hub.y - 2, 4, 3), Color(1.0, 0.3, 0.2, 0.8))
	ci.draw_rect(Rect2(hub.x + 2, hub.y - 2, 4, 3), Color(1.0, 0.3, 0.2, 0.8))
	ci.draw_line(hub, o + Vector2(0, -10), Color("2a2d36"), 2.0)
	# The pod.
	var shell := _flash(Color("6a5a80"), hurt, t)
	ci.draw_colored_polygon(PackedVector2Array([o + Vector2(-14, 0), o + Vector2(14, 0), o + Vector2(11, 7), o + Vector2(-11, 7)]), shell)
	ci.draw_rect(Rect2(o.x - 14, o.y, 28, 1), shell.lightened(0.3))
	for i in 3:
		ci.draw_rect(Rect2(o.x - 7 + i * 6, o.y + 3, 2, 2), Color("fff1a8") if int(t * 5.0 + i) % 2 == 0 else Color("e04848"))
	var dome := PackedVector2Array()
	for i in 13:
		var a := PI + PI * float(i) / 12.0
		dome.append(o + Vector2(cos(a) * 12.0, sin(a) * 9.0))
	ci.draw_colored_polygon(dome, GLASS)
	ci.draw_circle(o + Vector2(0, -3), 3.5, ALIEN)
	ci.draw_rect(Rect2(o.x - 2, o.y - 4, 1, 2), Color.BLACK)
	ci.draw_rect(Rect2(o.x + 1, o.y - 4, 1, 2), Color.BLACK)
	# Claw holding the part, off to one side.
	if part != "":
		var cl := o + Vector2(20, 4)
		ci.draw_line(o + Vector2(12, 3), cl, STEEL_HI, -1.0)
		ci.draw_line(cl, cl + Vector2(-3, 6), STEEL_HI, -1.0)
		ci.draw_line(cl, cl + Vector2(3, 6), STEEL_HI, -1.0)
		Icons.part(ci, (cl + Vector2(0, 10)).floor(), part, 1.0)
	_spot_glow(ci, o, 11.0, t, hp)
