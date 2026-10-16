## Pixel art for track features (springs, tunnels, loops, lifts, ziplines) and the
## bonus biplane. Static helpers that draw into the world's canvas.
extends RefCounted

const Phys := preload("res://scripts/game/bike_physics.gd")
const Icons := preload("res://scripts/game/icons.gd")

const STEEL := Color("4a4f5c")
const STEEL_HI := Color("9aa3ad")
const PAD := Color("d9453b")
const PAD_HI := Color("ffcf6a")
const HAZARD := Color("f0c040")


## Spring pad on the deck at (x, y). fired_ago: seconds since it last launched someone.
static func spring(ci: CanvasItem, x: float, y: float, fired_ago: float) -> void:
	var h := 8.0
	if fired_ago < 0.6:
		# Squash on launch, then a wobbly overshoot back to rest.
		h = 8.0 + 5.0 * sin(fired_ago * 26.0) * exp(-fired_ago * 7.0) - (3.0 if fired_ago < 0.05 else 0.0)
	x = floorf(x)
	ci.draw_rect(Rect2(x - 7, y - 2, 14, 2), STEEL)
	var top := y - 2.0 - h
	var turns := 3
	var prev := Vector2(x - 5, y - 2)
	for i in turns * 2:
		var py := y - 2.0 - h * float(i + 1) / float(turns * 2)
		var nx := x + (5.0 if i % 2 == 0 else -5.0)
		var q := Vector2(nx, py)
		ci.draw_line(prev, q, STEEL_HI, -1.0)
		prev = q
	ci.draw_rect(Rect2(x - 7, top - 3, 14, 3), PAD)
	ci.draw_rect(Rect2(x - 6, top - 3, 12, 1), PAD_HI)
	ci.draw_rect(Rect2(x - 1, top - 2, 2, 1), Color.WHITE)


## Tunnel interior (drawn before the tracks): the dark rock wall, strata and lanterns.
static func tunnel_back(ci: CanvasItem, c: Dictionary, th: Dictionary, bottom: float, t: float, night: bool) -> void:
	var x0: float = c.x0
	var x1: float = c.x1
	var cy: float = float(c.deck) - float(c.h)
	var wall: Color = (th.near as Color).darkened(0.55)
	ci.draw_rect(Rect2(x0, cy, x1 - x0, bottom - cy), wall)
	var strata: Color = wall.lightened(0.08)
	var yy := cy + 9.0
	while yy < bottom:
		var off := fposmod(yy * 7.3, 37.0)
		var sx := x0 + off
		while sx < x1 - 8:
			ci.draw_rect(Rect2(sx, yy, 14 + fposmod(sx * 3.1, 18.0), 1), strata)
			sx += 46.0
		yy += 11.0
	# Lanterns hung on the wall.
	var lx := x0 + 40.0
	while lx < x1 - 20.0:
		var flick := 0.85 + 0.15 * sin(t * 9.0 + lx)
		ci.draw_circle(Vector2(lx, cy + 15), 14.0, Color(1.0, 0.75, 0.35, 0.10 * flick))
		ci.draw_circle(Vector2(lx, cy + 15), 7.0, Color(1.0, 0.8, 0.45, 0.16 * flick))
		ci.draw_line(Vector2(lx, cy + 4), Vector2(lx, cy + 12), STEEL, -1.0)
		ci.draw_rect(Rect2(lx - 2, cy + 12, 4, 5), Color("6a4a2a"))
		ci.draw_rect(Rect2(lx - 1, cy + 13, 2, 3), Color(1.0, 0.85, 0.5, flick))
		lx += 112.0
	if night:
		ci.draw_rect(Rect2(x0, cy, x1 - x0, bottom - cy), Color(0, 0, 0, 0.25))


## Tunnel roof and portals (drawn after the tracks, still behind the bike).
static func tunnel_front(ci: CanvasItem, c: Dictionary, th: Dictionary, top: float, t := 0.0) -> void:
	var x0: float = c.x0
	var x1: float = c.x1
	var deck: float = c.deck
	var cy: float = deck - float(c.h)
	var rock: Color = (th.mid as Color).darkened(0.25)
	var rock_hi: Color = (th.mid as Color).lightened(0.08)
	var cliff_top := float(c.get("top", -INF))
	if cliff_top > -INF:
		_cliff(ci, x0, x1, cliff_top, cy, rock, rock_hi, t)
	else:
		# Mesa mass over the tunnel with sloped shoulders at both ends.
		var poly := PackedVector2Array([
			Vector2(x0 - 14, cy), Vector2(x0 - 6, cy - 40), Vector2(x0 + 18, cy - 70), Vector2(x0 + 30, top),
			Vector2(x1 - 30, top), Vector2(x1 - 18, cy - 70), Vector2(x1 + 6, cy - 40), Vector2(x1 + 14, cy)])
		ci.draw_colored_polygon(poly, rock)
		ci.draw_line(Vector2(x0 - 6, cy - 40), Vector2(x0 + 18, cy - 70), rock_hi, -1.0)
		ci.draw_line(Vector2(x1 - 18, cy - 70), Vector2(x1 + 6, cy - 40), rock_hi, -1.0)
	# Roof timbers: a lintel along the ceiling and posts every 48 px.
	var timber: Color = th.beam
	var dark: Color = th.beam_dark
	ci.draw_rect(Rect2(x0 - 4, cy - 4, x1 - x0 + 8, 4), timber)
	ci.draw_rect(Rect2(x0 - 4, cy - 1, x1 - x0 + 8, 1), dark)
	var px := x0
	while px <= x1:
		ci.draw_rect(Rect2(px - 1, cy, 3, float(c.h) * 0.35), Color(timber, 0.85))
		px += 48.0
	# Portal frames.
	for ex in [x0, x1]:
		ci.draw_rect(Rect2(ex - 5, cy - 6, 4, float(c.h) + 6), timber)
		ci.draw_rect(Rect2(ex - 7, cy - 8, 8, 3), dark)


## A sheer cliff over a tunnel: flat top (a deck rides on it), a vertical face at x0
## painted with green chevrons (sticky tires climb here), and a rougher back slope.
static func _cliff(ci: CanvasItem, x0: float, x1: float, top: float, cy: float, rock: Color,
		rock_hi: Color, t: float) -> void:
	var body := PackedVector2Array([Vector2(x0, top + 5), Vector2(x1, top + 5), Vector2(x1 + 4, top + 20),
		Vector2(x1 + 12, cy), Vector2(x0, cy)])
	ci.draw_colored_polygon(body, rock)
	ci.draw_rect(Rect2(x0, top + 5, 2, cy - top - 5), rock_hi)
	# Strata.
	var yy := top + 14.0
	while yy < cy - 4.0:
		var sx := x0 + 6.0 + fposmod(yy * 5.3, 30.0)
		while sx < x1 - 10.0:
			ci.draw_rect(Rect2(sx, yy, 12 + fposmod(sx * 2.7, 16.0), 1), rock.darkened(0.15))
			sx += 40.0
		yy += 10.0
	# Climbing marks on the face.
	var g := Color(0.45, 1.0, 0.35, 0.65 + 0.3 * sin(t * 4.0))
	var my := cy - 8.0
	while my > top + 12.0:
		ci.draw_line(Vector2(x0 + 1, my), Vector2(x0 + 4, my - 4), g, 2.0)
		ci.draw_line(Vector2(x0 + 4, my - 4), Vector2(x0 + 7, my), g, 2.0)
		my -= 14.0


## Loop-the-loop ring with plank ticks and a scaffold underneath.
static func loop(ci: CanvasItem, L: Dictionary, th: Dictionary, bottom: float) -> void:
	var deck: Color = th.deck
	var hi: Color = th.deck_hi
	var beam: Color = th.beam
	var brace: Color = th.beam_dark
	var r: float = L.r
	var cx: float = float(L.x) + float(L.shift) * 0.5
	var cy: float = float(L.y) - r
	# Scaffold: posts from the ring's sides and centre down to the ground.
	for sx in [cx - r - 2.0, cx - r * 0.5, cx + r * 0.5, cx + r + 2.0]:
		ci.draw_rect(Rect2(sx - 1, cy, 3, bottom - cy), Color(beam, 0.9))
	ci.draw_line(Vector2(cx - r, cy + 6), Vector2(cx + r, cy + r), brace, -1.0)
	ci.draw_line(Vector2(cx + r, cy + 6), Vector2(cx - r, cy + r), brace, -1.0)
	var n := 48
	var prev := Phys.loop_pos(L, 0.0)
	for i in range(1, n + 1):
		var a := TAU * float(i) / float(n)
		var p := Phys.loop_pos(L, a)
		var am := TAU * (float(i) - 0.5) / float(n)
		var out := Vector2(sin(am), cos(am))
		ci.draw_colored_polygon(PackedVector2Array([prev, p, p + out * 5.0, prev + out * 5.0]), deck)
		ci.draw_line(prev, p, hi, -1.0)
		ci.draw_line(prev + out * 5.0, p + out * 5.0, brace, -1.0)
		if i % 3 == 0:
			ci.draw_rect(Rect2((p + out * 2.0).floor(), Vector2.ONE), brace)
		prev = p


## A bobbing lift platform: hydraulic ram underneath and hazard-striped edges.
static func lift(ci: CanvasItem, tr: Dictionary, dy: float, th: Dictionary, bottom: float, t: float) -> void:
	var x0: float = tr.x0
	var x1: float = tr.x1
	var y: float = Phys.height_at(tr, x0) + dy
	var mid := (x0 + x1) * 0.5
	ci.draw_rect(Rect2(mid - 5, y + 9, 10, bottom - y), STEEL)
	ci.draw_rect(Rect2(mid - 3, y + 5, 6, bottom - y), STEEL_HI)
	ci.draw_rect(Rect2(mid - 2, y + 5, 1, bottom - y), Color.WHITE.lerp(STEEL_HI, 0.5))
	ci.draw_rect(Rect2(x0, y, x1 - x0, 5), th.deck)
	ci.draw_line(Vector2(x0, y), Vector2(x1, y), th.deck_hi, -1.0)
	var sx := x0
	var k := 0
	while sx < x1:
		ci.draw_rect(Rect2(sx, y + 5, minf(6.0, x1 - sx), 3), HAZARD if k % 2 == 0 else Color("1e1a1f"))
		sx += 6.0
		k += 1
	var blink := 1.0 if int(t * 2.0) % 2 == 0 else 0.35
	ci.draw_rect(Rect2(x0 + 1, y + 6, 2, 1), Color(1.0, 0.3, 0.2, blink))
	ci.draw_rect(Rect2(x1 - 3, y + 6, 2, 1), Color(1.0, 0.3, 0.2, blink))


## Zipline: two towers and the cable between them.
static func zip(ci: CanvasItem, z: Dictionary, g0: float, g1: float, th: Dictionary) -> void:
	var a := Vector2(z.x0, z.y0)
	var b := Vector2(z.x1, z.y1)
	for e in [[a, g0], [b, g1]]:
		var p: Vector2 = e[0]
		var gy: float = e[1]
		ci.draw_rect(Rect2(p.x - 2, p.y - 8, 4, gy - p.y + 8), th.beam)
		ci.draw_rect(Rect2(p.x - 6, p.y - 9, 12, 3), th.beam_dark)
		ci.draw_circle(p, 2.5, STEEL)
		ci.draw_circle(p, 1.0, STEEL_HI)
	ci.draw_line(a + Vector2(0, 1), b + Vector2(0, 1), Color(0, 0, 0, 0.25), -1.0)
	ci.draw_line(a, b, Color("2a2d36"), -1.0)


## A rope swing: the anchor (a beam, branch or crane arm) and the rope, taut down to
## the rider's hands (end) or hanging loose with a little sway.
static func rope(ci: CanvasItem, r: Dictionary, end: Vector2, t: float, th: Dictionary, kind: String) -> void:
	var a := Vector2(r.ax, r.ay)
	var length := float(r.len)
	match kind:
		"branch":
			# A thick tree limb reaching in from the left, a knot at the rope.
			var bark: Color = Color("5a3e2a")
			ci.draw_line(a + Vector2(-60, -14), a + Vector2(6, 0), bark, 5.0)
			ci.draw_line(a + Vector2(-40, -10), a + Vector2(-48, -26), bark, 3.0)
			ci.draw_circle(a + Vector2(-20, -16), 9.0, Color("3f7a3a"))
			ci.draw_circle(a + Vector2(-34, -22), 8.0, Color("4e8a3a"))
			ci.draw_circle(a + Vector2(-6, -12), 7.0, Color("4e8a3a"))
		"crane":
			ci.draw_rect(Rect2(a.x - 40, a.y - 4, 50, 4), STEEL)
			ci.draw_rect(Rect2(a.x - 40, a.y - 4, 50, 1), STEEL_HI)
			ci.draw_rect(Rect2(a.x - 3, a.y - 1, 6, 4), HAZARD)
		_:
			# A timber beam on a post (a hay-loft hoist).
			ci.draw_rect(Rect2(a.x - 46, a.y - 4, 54, 5), th.beam)
			ci.draw_rect(Rect2(a.x - 46, a.y - 4, 54, 1), (th.beam as Color).lightened(0.2))
			ci.draw_rect(Rect2(a.x - 44, a.y, 4, 160), th.beam)
			ci.draw_line(a + Vector2(-40, 20), a + Vector2(-16, 0), th.beam_dark, 2.0)
	var tip := end
	if tip == Vector2.INF:
		var sway := 0.07 * sin(t * 1.7 + float(r.ax) * 0.07)
		tip = a + length * Vector2(sin(sway), cos(sway))
	var rope_c := Color("c9a46a")
	ci.draw_line(a, tip, Color("6b5a44"), 2.0)
	ci.draw_line(a, tip, rope_c, -1.0)
	# Knots along it, and a handle at the bottom.
	for k in [0.4, 0.7]:
		var kp := a.lerp(tip, k)
		ci.draw_rect(Rect2(kp.x - 1, kp.y - 1, 3, 2), Color("8a6a40"))
	if end == Vector2.INF:
		ci.draw_rect(Rect2(tip.x - 3, tip.y - 1, 6, 3), Color("8a6a40"))
		ci.draw_circle(tip + Vector2(0, -6), 5.0, Color(1.0, 0.95, 0.7, 0.12 + 0.08 * sin(t * 5.0)))


## The trolley a rider hangs from: wheels on the cable, a bar down to the hands.
static func trolley(ci: CanvasItem, on_cable: Vector2, grip: Vector2) -> void:
	ci.draw_line(on_cable + Vector2(-2, 2), grip + Vector2(-2, 0), STEEL_HI, -1.0)
	ci.draw_line(on_cable + Vector2(2, 2), grip + Vector2(2, 0), STEEL_HI, -1.0)
	ci.draw_rect(Rect2(grip.x - 4, grip.y - 1, 8, 2), STEEL)
	ci.draw_rect(Rect2(on_cable.x - 4, on_cable.y - 2, 8, 4), Color("c8323c"))
	ci.draw_circle(on_cable + Vector2(-2, -1), 1.5, STEEL)
	ci.draw_circle(on_cable + Vector2(2, -1), 1.5, STEEL)


## Bonus biplane flying right at p (the prize hangs `rope` px below). t animates the prop.
static func plane(ci: CanvasItem, p: Vector2, t: float, rope: float, has_prize: bool, waggle: float) -> void:
	p = p.floor()
	var tilt := sin(t * 2.3) * 1.0 + waggle
	var body := Color("e8e2d0")
	var trim := Color("c8323c")
	var wing := Color("d9453b")
	var dark := Color("3a3440")
	# Rope and prize first, so they hang behind the plane.
	if has_prize:
		var hook := p + Vector2(-2, 4)
		var end := hook + Vector2(-4 + sin(t * 3.1) * 2.0, rope)
		ci.draw_line(hook, end, Color("6b5a44"), -1.0)
		Icons.bag(ci, (end + Vector2(0, 6)).floor())
		ci.draw_circle(end + Vector2(0, 6), 11.0, Color(1.0, 0.9, 0.4, 0.12 + 0.06 * sin(t * 6.0)))
	# Tail.
	ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-16, -1), p + Vector2(-21, -8 + tilt * 0.3), p + Vector2(-18, -8 + tilt * 0.3), p + Vector2(-12, -1)]), trim)
	ci.draw_rect(Rect2(p.x - 20, p.y - 1 + tilt * 0.2, 7, 2), wing)
	# Fuselage.
	ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-17, -1), p + Vector2(4, -4), p + Vector2(10, -3), p + Vector2(10, 2), p + Vector2(4, 3), p + Vector2(-17, 1)]), body)
	ci.draw_line(p + Vector2(-15, 0), p + Vector2(8, 0), trim, -1.0)
	# Pilot: head, goggles, scarf.
	ci.draw_circle(p + Vector2(-2, -5), 2.2, Color("8a5a3a"))
	ci.draw_rect(Rect2(p.x - 2, p.y - 6, 3, 1), Color("7fd0ff"))
	ci.draw_line(p + Vector2(-4, -4), p + Vector2(-9, -5 + sin(t * 12.0)), Color("f0f4f8"), -1.0)
	# Wings (side view: upper and lower planes with struts).
	ci.draw_rect(Rect2(p.x - 6, p.y - 9 + tilt * 0.1, 14, 2), wing)
	ci.draw_rect(Rect2(p.x - 5, p.y + 3 - tilt * 0.1, 13, 2), wing)
	ci.draw_line(p + Vector2(-4, -7), p + Vector2(-4, 3), dark, -1.0)
	ci.draw_line(p + Vector2(6, -7), p + Vector2(6, 3), dark, -1.0)
	# Wheels.
	ci.draw_line(p + Vector2(2, 3), p + Vector2(1, 7), dark, -1.0)
	ci.draw_circle(p + Vector2(1, 8), 1.5, dark)
	# Propeller blur.
	var blade := absf(sin(t * 40.0)) * 7.0
	ci.draw_rect(Rect2(p.x + 10, p.y - 1, 2, 2), dark)
	ci.draw_rect(Rect2(p.x + 12, p.y - blade, 1, blade * 2.0), Color(0.9, 0.9, 0.95, 0.6))
