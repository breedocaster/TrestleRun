## Crash hints. Wreck a few times in the same stretch of trail and the next try shows
## a way through it: a dotted line from the checkpoint to past the trouble, marked
## with where to TAP, where to HOLD (the line turns blue while the button is down) and
## where to LET GO, plus a one-line tip for that kind of stretch.
##
## The line is the real physics played forward from the exact state you respawn in,
## ridden by the autopilot. The autopilot jumps as soon as it sees trouble coming,
## which is early for a person, so each plain jump it's forced into is re-timed: of a
## few hold lengths, the one with the widest run of frames in which a single press
## still clears the trouble (the timing window), pressed in the middle of that run.
## If a re-timed jump leads somewhere hopeless, the line falls back to the autopilot's
## own presses. All of it runs on a worker thread while the crash plays out, on a copy
## of the trail; it never touches the live run.
##
## How many wrecks it takes: 2 on the first three trails (and the first story area),
## then 3, 4 and 5 as the trails go on. Cables, rails, ropes, wall-rides and boss
## arenas always hint after 2: they're the ones you can't work out by jumping harder.
extends RefCounted

const Phys := preload("res://scripts/game/bike_physics.gd")
const Bot := preload("res://scripts/game/autopilot.gd")
const Catalog := preload("res://scripts/catalog.gd")

const MAX_FRAMES := 4800  # 80 s; the longest stretch between checkpoints takes about 35 s
## A hold shorter than this many frames is drawn as a TAP.
const TAP_FRAMES := 8

## Stretches that always hint after two wrecks.
const SPECIAL := ["zip", "zip_up", "zip_chain", "zip_drops", "rail", "rail_chain", "rope", "wall",
	"boss", "boss_end", "bw_low", "bw_gap", "bw_zip", "bw_rail", "bw_rope", "bw_wall", "bw_lip"]

const TIPS := {
	"gap": "JUMP RIGHT AT THE EDGE. HOLD LONGER TO JUMP FARTHER.",
	"hops": "SHORT TAPS: ONE HOP PER GAP, AS YOU REACH IT.",
	"high_coins": "JUMP AT THE EDGE. HOLD LONGER TO JUMP FARTHER.",
	"drop": "ROLL OFF THE DROP. GET READY TO JUMP AS YOU LAND.",
	"descent": "LET IT ROLL DOWNHILL. JUMP ONLY AT THE GAPS.",
	"stairs_down": "ROLL OFF EACH STEP. JUMP ONLY AT THE GAPS.",
	"climb": "HOLD FOR A BIG JUMP UP ONTO THE HIGH DECK.",
	"stairs_up": "A MEDIUM HOLD FOR EACH STEP UP.",
	"rise": "HOLD FOR A BIG JUMP UP ONTO THE HIGH DECK.",
	"hills": "LET THE HILLS CARRY YOU. JUMP ONLY AT THE GAPS.",
	"crawler": "JUMP OVER THE CRITTER, OR COME DOWN ON ITS BACK.",
	"crawler_chain": "LAND ON EACH CRITTER'S BACK AND BOUNCE TO THE NEXT.",
	"spiker": "SPIKERS CAN'T BE STOMPED. JUMP CLEAN OVER.",
	"double_spiker": "HOP THE FIRST, LAND BETWEEN, HOP THE SECOND.",
	"drone": "DON'T JUMP UNDER A FLYER. STAY LOW AND RIDE UNDER.",
	"drone_row": "STAY ON THE DECK UNDER THE FLYERS. NO JUMPING.",
	"spiker_drone": "A SHORT HOP: OVER THE SPIKER, UNDER THE FLYER.",
	"drone_gap": "A QUICK TAP OVER THE GAP KEEPS YOU UNDER THE FLYER.",
	"kicker": "RIDE UP THE KICKER. JUMP AT THE LIP FOR BIG AIR.",
	"ramp": "RIDE UP THE RAMP. JUMP AT THE LIP FOR BIG AIR.",
	"tri_ramp": "EVERY ROUTE GOES THROUGH. A FULL HOLD AT THE LIP GOES HIGH.",
	"branch_upper": "PICK A ROAD AND COMMIT. WATCH WHERE IT COMES DOWN.",
	"split": "PICK A ROAD AND COMMIT. WATCH WHERE IT COMES DOWN.",
	"secret_low": "PICK A ROAD AND COMMIT. WATCH WHERE IT COMES DOWN.",
	"perch": "PICK A ROAD AND COMMIT. WATCH WHERE IT COMES DOWN.",
	"fork": "PICK A ROAD AND COMMIT. WATCH WHERE IT COMES DOWN.",
	"spring_up": "ROLL ONTO THE SPRING. DON'T JUMP JUST BEFORE IT.",
	"spring_gap": "ROLL ONTO THE SPRING: IT CLEARS THE CANYON FOR YOU.",
	"spring_trap": "HOP OVER THIS SPRING: SOMETHING WAITS UP ABOVE.",
	"spring_chain": "ROLL ONTO EACH SPRING. DON'T PRESS IN BETWEEN.",
	"tunnel": "ONLY SHORT TAPS UNDER THE LOW ROOF.",
	"loop": "KEEP ROLLING THROUGH THE LOOP. PRESS AS YOU COME OUT.",
	"lifts": "WATCH THE LIFTS BOB. JUMP SO YOU LAND ON THE NEXT ONE.",
	"zip": "JUMP AND KEEP HOLDING TO CATCH THE CABLE. LET GO OVER THE DECK.",
	"zip_up": "KEEP HOLDING ALL THE WAY UP THE CABLE.",
	"zip_chain": "DON'T LET GO: OFF THE END YOU CATCH THE NEXT CABLE.",
	"zip_drops": "LET GO OVER AN ISLAND, OR KEEP HOLDING TO RIDE ON.",
	"rail": "LAND ON THE RAIL AND KEEP HOLDING ALL THE WAY ACROSS.",
	"rail_chain": "KEEP HOLDING OFF THE END OF EACH RAIL ONTO THE NEXT.",
	"rope": "HOLD TO CATCH THE ROPE. LET GO WHILE IT SWINGS YOU FORWARD.",
	"wall": "HOLD ALL THE WAY ROUND THE WALL. LET GO AND YOU FALL.",
	"crumble": "DON'T STOP ON GREY PLANKS. HOP STRAIGHT OFF THEM.",
	"chase": "KEEP MOVING: CLEAN LANDINGS OUTRUN THE COLLAPSE.",
	"cliff": "NO STICKY TIRES? RIDE INTO THE TUNNEL UNDER THE CLIFF.",
	"power": "JUMP AT THE EDGE. HOLD LONGER TO JUMP FARTHER.",
	"boss": "GET UP HIGH, THEN COME DOWN ON THE SAUCER'S GLASS TOP.",
}
const BOSS_TIP := "GET ABOVE THE SAUCER, THEN COME DOWN ON ITS GLASS TOP."
const DEFAULT_TIP := "FOLLOW THE DOTS: TAP AND HOLD WHERE THEY SAY."


## Wrecks per stretch of each trail, kept while the app is open so RESTART doesn't
## wipe the slate. Main thread only.
static var _wrecks := {}


static func wrecks(level_id: String) -> Dictionary:
	if not _wrecks.has(level_id):
		_wrecks[level_id] = {}
	return _wrecks[level_id]


## Wrecks in one stretch before it starts hinting.
static func threshold(level_id: String, chunk: String) -> int:
	if chunk in SPECIAL:
		return 2
	var i := Catalog.level_index(level_id)
	if i >= 0:
		return 2 if i < 3 else mini(5, 3 + (i - 3) / 3)
	var st := Catalog.story_levels()
	for k in st.size():
		if String(st[k].id) == level_id:
			return 2 if k < 3 else mini(5, 2 + k / 4)
	return 2


static func tip(chunk: String, death: String) -> String:
	if death == "collapse":
		return String(TIPS.chase)
	if chunk.begins_with("bw_") or chunk == "boss_end":
		return BOSS_TIP
	return String(TIPS.get(chunk, DEFAULT_TIP))


## Index into level.marks of the stretch (chunk) at x.
static func section_at(level: Dictionary, x: float) -> int:
	var marks: Array = level.get("marks", [])
	var at := 0
	for i in marks.size():
		if float(marks[i][1]) <= x:
			at = i
	return at


static func section_name(level: Dictionary, i: int) -> String:
	var marks: Array = level.get("marks", [])
	return String(marks[i][0]) if i >= 0 and i < marks.size() else ""


static func section_end(level: Dictionary, i: int) -> float:
	var marks: Array = level.get("marks", [])
	return float(marks[i + 1][1]) if i + 1 < marks.size() else float(level.finish_x)


## Worker-thread entry. inp: {"level" (a private deep copy), "s0" (the respawn
## state), "end_x", "collect"}. Returns {"ok", "pts", "z", "held", "marks"}, where
## marks are [frame, "TAP"|"HOLD"|"LET GO"] (LET GO only after riding a cable,
## rail, rope or wall: on a plain jump the blue dots already show how long). With a Job, the line so far is handed
## over every few frames (so the start of it shows up straight away) and the work
## stops if the job is cancelled.
static func compute(inp: Dictionary, job: Job = null) -> Dictionary:
	var g := _attempt(inp, job, true)
	if not bool(g.ok) and (job == null or not job.cancelled()):
		g = _attempt(inp, job, false)  # a moved press led somewhere hopeless: plain bot
	return g


static func _attempt(inp: Dictionary, job: Job, centre: bool) -> Dictionary:
	var level: Dictionary = inp.level
	var s: Dictionary = Phys.copy_state(inp.s0)
	var end_x := float(inp.end_x)
	var bot = Bot.new(level)
	bot.collect = bool(inp.collect)
	var r := Rider.new()
	r.level = level
	r.bot = bot
	r.centre = centre
	var pts := PackedVector2Array()
	var zs := PackedFloat32Array()
	var held := PackedByteArray()
	var taps := PackedInt32Array()
	var attached := PackedByteArray()
	pts.append(_pos(level, s))
	zs.append(float(s.lane_z))
	held.append(0)
	attached.append(0)
	var ok := false
	for i in MAX_FRAMES:
		var d: Array = r.decide(s)
		var px := float(s.x)
		var ev := Phys.step(level, s, d[0], d[1])
		if not s.alive:
			break
		if float(s.x) < px - 80.0:
			ok = true  # a boss arena looped you back to its start: one pass is enough
			break
		pts.append(_pos(level, s))
		zs.append(float(s.lane_z))
		held.append(1 if d[1] else 0)
		attached.append(1 if Phys.attachment(level, s) != "" else 0)
		if d[0]:
			taps.append(pts.size() - 1)
		if (ev & Phys.EV_BOSS_DOWN) or float(s.x) >= float(level.finish_x):
			ok = true
			break
		if float(s.x) >= end_x and s.grounded:
			ok = true
			break
		if job != null and i % 12 == 11:
			if job.cancelled():
				return {"ok": false}
			job.publish(pts, zs, held, taps, attached, false, false)
	if job != null and (ok or not centre):
		job.publish(pts, zs, held, taps, attached, true, ok)
	return {"ok": ok, "pts": pts, "z": zs, "held": held, "taps": taps, "marks": marks_for(held, taps, attached)}


## A hint line being worked out on a worker thread: the thread publishes what it has
## so far, the game takes a copy each frame it changed.
class Job:
	var _m := Mutex.new()
	var _pts := PackedVector2Array()
	var _z := PackedFloat32Array()
	var _held := PackedByteArray()
	var _taps := PackedInt32Array()
	var _att := PackedByteArray()
	var _done := false
	var _ok := false
	var _cancel := false
	var _serial := 0

	func publish(pts, z, held, taps, att, done: bool, ok: bool) -> void:
		_m.lock()
		_pts = pts.duplicate()
		_z = z.duplicate()
		_held = held.duplicate()
		_taps = taps.duplicate()
		_att = att.duplicate()
		_done = done
		_ok = ok
		_serial += 1
		_m.unlock()

	func cancel() -> void:
		_m.lock()
		_cancel = true
		_m.unlock()

	func cancelled() -> bool:
		_m.lock()
		var c := _cancel
		_m.unlock()
		return c

	## {} if nothing new since `serial`, else the line so far with "done", "ok", "serial".
	func take(serial: int) -> Dictionary:
		_m.lock()
		var out := {}
		if _serial != serial:
			out = {"pts": _pts, "z": _z, "held": _held, "taps": _taps, "att": _att,
				"done": _done, "ok": _ok, "serial": _serial}
		_m.unlock()
		return out


## Jumping onto a hold move, a person presses and keeps holding until it's caught:
## a hold this long stands for that.
const CATCH_HOLD := 90


## Press now and hold for h frames (CATCH_HOLD: until it's caught): 0 = it catches
## nothing, 1 = it catches a cable, rail, rope or wall-ride and riding that out the
## default way (hold the whole rail or wall, let a rope go on the upswing, ride a cable
## to its end) gets back onto a deck, -1 = it catches one and comes to grief. Used to
## time jumps onto hold moves: once you've caught one, when you jumped hardly matters.
static func catches(level: Dictionary, s0: Dictionary, h: int) -> int:
	var s := Phys.copy_state(s0)
	var caught := false
	for i in 900:
		if int(s.zip) >= 0 or Phys.attachment(level, s) != "":
			caught = true
		elif i > 1 and s.grounded:
			return 1 if caught else 0
		Phys.step(level, s, i == 0, i < h or int(s.zip) >= 0 or Phys.auto_hold(level, s))
		if not s.alive:
			return -1 if caught else 0
	return 1 if caught else 0


## Where the bike is drawn (hanging from a rope, that's below the rider's hands).
static func _pos(level: Dictionary, s: Dictionary) -> Vector2:
	if int(s.rope) >= 0:
		var rp: Dictionary = level.ropes[s.rope]
		var a := float(s.rope_a)
		var hand := Vector2(rp.ax, rp.ay) + float(s.rope_r) * Vector2(sin(a), cos(a))
		return hand + Vector2(-4.0, Phys.HEIGHT + 2.0).rotated(-a)
	return Vector2(float(s.x), float(s.y))


## One press and everything held after it is one hold: a gap in the button of a few
## frames while airborne still reads as "keep holding" to a person.
static func marks_for(held: PackedByteArray, taps: PackedInt32Array, attached: PackedByteArray) -> Array:
	var out := []
	for t in taps:
		var end := t
		var gap := 0
		var rode := false
		var k := t
		while k < held.size():
			if held[k]:
				end = k
				gap = 0
				if attached[k]:
					rode = true
			else:
				gap += 1
				if gap > 20:
					break
			k += 1
		var n := end - t + 1
		out.append([t, "TAP" if n < TAP_FRAMES and not rode else "HOLD"])
		if rode and end + 1 < held.size():
			out.append([end + 1, "LET GO"])
	return out


## The autopilot, with plain jumps moved to the middle of their timing window.
class Rider:
	const PhysC := preload("res://scripts/game/bike_physics.gd")
	var GuideC = load("res://scripts/game/guide.gd")
	const HOLDS := [5, 9, 14, 22, 30, 90]  # 90 = CATCH_HOLD
	var level: Dictionary
	var bot
	## Off: just the bot's own presses (the fallback if a moved press leads nowhere).
	var centre := true
	static var debug := false
	var _plan_in := -1
	var _plan_hold := 0
	var _hold_left := 0

	func decide(s: Dictionary) -> Array:
		if int(s.zip) >= 0 or PhysC.attachment(level, s) != "":
			_hold_left = 0
			_plan_in = -1
			return bot.decide(s)
		if _hold_left > 0 and s.grounded and _plan_hold - _hold_left > 3:
			_hold_left = 0  # a long hold for a catch that came down on a deck instead
		if _hold_left > 0:
			_hold_left -= 1
			return [false, true]
		if _plan_in > 0:
			_plan_in -= 1
			return [false, false]
		if _plan_in == 0:
			_plan_in = -1
			_hold_left = _plan_hold - 1
			return [true, true]
		var nf: int = bot.forced.size()
		var d: Array = bot.decide(s)
		if centre and d[0] and bot.forced.size() > nf and s.grounded:
			var h: int = int(bot._hold_left) + 1
			var c := _centre(s, h)
			if debug:
				print("RIDER x=%.0f bot hold %d -> wait %d hold %d" % [s.x, h, c[0], c[1]])
			if int(c[0]) > 0 or int(c[1]) != h:
				bot._hold_left = 0
				_plan_hold = int(c[1])
				if int(c[0]) == 0:
					_hold_left = _plan_hold - 1
					return [true, true]
				_plan_in = int(c[0]) - 1
				return [false, false]
		return d

	## A person's version of the bot's press: among a few hold lengths, the one whose
	## timing window (frames in which a single jump clears the trouble) is widest, and
	## its middle. Returns [frames to wait, hold]; [0, h] keeps the bot's own press.
	func _centre(s0: Dictionary, h: int) -> Array:
		# Where riding on comes to grief (a fall counts from where the wheels left).
		var dx := PhysC.copy_state(s0)
		var leave_x := float(dx.x)
		for i in 240:
			var ev := PhysC.step(level, dx, false, false)
			if ev & PhysC.EV_LEAVE:
				leave_x = float(dx.x)
			if not dx.alive:
				break
		if dx.alive:
			return [0, h]
		var death_x := leave_x if String(dx.death) == "fall" else float(dx.x)
		# The riding-on states, every other frame, while a press could still jump.
		var st := PhysC.copy_state(s0)
		var states := []
		for k in 64:
			if not st.alive or not st.grounded or int(st.loop) >= 0 or PhysC.attachment(level, st) != "":
				break
			if k % 2 == 0:
				states.append([k, PhysC.copy_state(st)])
			PhysC.step(level, st, false, false)
		var best := [0, h]
		var best_n := 0
		var holds := [h]
		for hh in HOLDS:
			if hh != h:
				holds.append(hh)
		for hh in holds:
			var first := -1
			var last := -1
			for e in states:
				if _works(e[1], hh, death_x):
					if first < 0:
						first = int(e[0])
					last = int(e[0])
				elif first >= 0:
					break
			if first < 0:
				continue
			var n := last - first + 2
			if n > best_n + (2 if hh != h else 0):  # the bot's own hold wins ties
				best_n = n
				best = [first + ((last - first) / 4) * 2, hh]
		return best

	## A jump from here with this hold clears the trouble (lands beyond where riding
	## on would come to grief, or catches something to hang on to) and leaves a way on
	## (the bot's own landing test).
	func _works(st: Dictionary, h: int, death_x: float) -> bool:
		if h >= GuideC.CATCH_HOLD:
			return GuideC.catches(level, st, h) > 0  # onto a cable, rail, rope or wall-ride
		var s := PhysC.copy_state(st)
		for i in 400:
			PhysC.step(level, s, i == 0, i < h)
			if not s.alive or int(s.zip) >= 0 or PhysC.attachment(level, s) != "":
				return false  # (catching something is the long hold's job)
			if i > 1 and s.grounded:
				if float(s.x) < death_x + 4.0:
					return false
				break
		return bool(bot._jump(st, h, 1).safe)
