## GAUNTLET: twelve obstacle courses against the clock. Each is a run of sections
## between checkpoints; a crash is a fault and puts you back at the last checkpoint.
## Courses are written as moves for course.gd, sized to what the vehicle sim can ride
## (--course-calibrate) and checked end to end by --drive-levels.
##
## Moves: ["f", len] flat; ["s", h] step up (h < 0: drop); ["sl", len, rise] slope;
## ["h", len, h] hump; ["w", n, len, h] whoops; ["k", len, h] kicker (ramp, then the lip
## drops back); ["p", w, land] pit (land: far side higher by); ["c", w, h, gap] crate;
## ["cs", [heights], w] crate steps; ["l", r, gap] log; ["st", n, rise, tread] stairs;
## ["t", h, len] table (sheer sides); ["m", h, up, top, down] ramped block (down 0 =
## sheer drop off the end); ["cp"] checkpoint; ["tip", "TEXT"] a how-to sign shown as
## you reach that point.
extends RefCounted

const Course := preload("res://scripts/drive/course.gd")

const LEVELS := [
	{"id": "ga_firstgear", "name": "FIRST GEAR", "theme": 12, "time": "day"},
	{"id": "ga_woodpile", "name": "WOODPILE", "theme": 8, "time": "day"},
	{"id": "ga_crates", "name": "CRATE ESCAPE", "theme": 2, "time": "day"},
	{"id": "ga_pipes", "name": "PIPE YARD", "theme": 13, "time": "dusk"},
	{"id": "ga_switchback", "name": "SWITCHBACK", "theme": 4, "time": "day"},
	{"id": "ga_gaps", "name": "MIND THE GAP", "theme": 1, "time": "day"},
	{"id": "ga_hoist", "name": "HOIST AND HAUL", "theme": 7, "time": "dusk"},
	{"id": "ga_quarry", "name": "QUARRY STEPS", "theme": 9, "time": "day"},
	{"id": "ga_lamplight", "name": "LAMPLIGHT", "theme": 5, "time": "night"},
	{"id": "ga_hoodoo", "name": "HOODOO HOPS", "theme": 6, "time": "dusk"},
	{"id": "ga_launch", "name": "LAUNCH PAD", "theme": 10, "time": "dusk"},
	{"id": "ga_final", "name": "THE GAUNTLET", "theme": 11, "time": "night"},
]

## Sizes come from --course-calibrate (search, beam 12), with 0.10.1's hop and face
## grip: the scrambler gets up an 8 px step or table (two wheel radii), a 6 px crate,
## over a log of radius 6, up stairs of 5-6 px given 30 px treads (it can't re-hop on a
## tread shorter than its wheelbase), across a 60 px pit off a 40 x 12 kicker, and down
## any drop. The dirt bike and the Mono unicycle manage 10 px steps; the scooter's
## little wheels 4. Holding gas gets over 4 px at most. A pit always needs a kicker or a
## ramp before it. So every course needs the hop, and the first ones keep it small.
const COURSES := [
	# 1 FIRST GEAR: humps, then the hop on small steps and a log, a block, a kicker, one
	# gap. Kept small enough for every bike in the garage (the scooter's 3 px wheels top
	# out at a 4 px step), so it teaches rather than sorts.
	[["f", 160], ["h", 70, 6], ["f", 60], ["tip", "BRAKE, THEN GAS QUICKLY: HOP!"], ["f", 70], ["s", 4], ["f", 60],
		["s", -4], ["f", 50], ["s", 4], ["f", 80], ["cp"],
		["f", 100], ["l", 4, 40], ["f", 60], ["w", 3, 60, 5], ["f", 40], ["k", 36, 8], ["f", 120], ["s", -12],
		["f", 60], ["cp"],
		["f", 50], ["sl", 80, 20], ["f", 50], ["t", 4, 40], ["f", 50], ["s", -10], ["f", 80], ["h", 90, 12], ["f", 60],
		["cp"],
		["f", 120], ["k", 40, 10], ["p", 20, 0], ["f", 120], ["s", 4], ["f", 60], ["s", -16], ["f", 60],
		["h", 90, 10], ["f", 30], ["h", 90, 10], ["f", 60]],
	# 2 WOODPILE: logs, bigger as it goes, in ones and threes; a ramped block; whoops.
	[["f", 140], ["l", 4, 40], ["f", 40], ["l", 5, 30], ["f", 60], ["tip", "BIG LOG? HOP INTO IT, THEN GAS"],
		["l", 6, 50], ["f", 60], ["cp"],
		["f", 30], ["l", 5, 40], ["l", 5, 40], ["l", 5, 40], ["f", 60], ["m", 16, 48, 40, 0], ["f", 60], ["cp"],
		["w", 4, 46, 9], ["f", 40], ["l", 6, 40], ["f", 50], ["k", 40, 12], ["f", 130], ["cp"],
		["sl", 60, 18], ["l", 4, 20], ["f", 30], ["sl", 50, -18], ["f", 60], ["l", 5, 40], ["f", 60]],
	# 3 CRATE ESCAPE: crates, crate rows, crate steps, a short gap.
	[["f", 140], ["c", 16, 4, 20], ["f", 40], ["c", 20, 6, 40], ["f", 60], ["c", 30, 6, 40], ["f", 60], ["cp"],
		["m", 14, 44, 30, 0], ["f", 50], ["c", 16, 6, 40], ["c", 16, 6, 40], ["f", 60], ["k", 40, 12], ["p", 20, 0],
		["f", 110], ["cp"],
		["cs", [6, 12, 6], 32], ["f", 60], ["sl", 50, 16], ["c", 14, 4, 30], ["f", 30], ["s", -16], ["f", 60], ["cp"],
		["c", 16, 6, 40], ["c", 16, 6, 40], ["f", 60], ["m", 18, 50, 30, 40], ["f", 40],
		["cs", [6, 12, 18, 12, 6], 32], ["f", 60]],
	# 4 PIPE YARD: tables, pipes, stairs, kicker gaps.
	[["f", 140], ["t", 6, 50], ["f", 50], ["k", 40, 12], ["p", 30, 0], ["f", 100], ["l", 5, 0], ["f", 60], ["cp"],
		["st", 4, 5, 32], ["f", 40], ["s", -20], ["f", 50], ["t", 8, 40], ["f", 80], ["l", 6, 40], ["f", 60], ["cp"],
		["m", 24, 60, 40, 0], ["f", 140], ["k", 44, 14], ["p", 40, 0], ["f", 100], ["st", 5, 5, 32], ["f", 30],
		["s", -25], ["f", 60], ["cp"],
		["f", 30], ["l", 5, 40], ["l", 5, 40], ["f", 60], ["t", 6, 30], ["f", 30], ["t", 8, 50], ["f", 60],
		["k", 40, 12], ["p", 36, 0], ["f", 80]],
	# 5 SWITCHBACK: steep climbs with a ledge at the top, steep drops.
	[["f", 140], ["sl", 60, 24], ["f", 40], ["s", 6], ["f", 40], ["sl", 60, -30], ["f", 50], ["sl", 50, 26], ["f", 30],
		["sl", 40, 20], ["f", 50], ["cp"],
		["sl", 70, -40], ["f", 60], ["sl", 40, 24], ["f", 30], ["s", 6], ["f", 30], ["s", -30], ["f", 60],
		["sl", 45, 30], ["f", 40], ["cp"],
		["sl", 50, -20], ["f", 60], ["sl", 50, 30], ["f", 30], ["s", 8], ["f", 30], ["sl", 60, -58], ["f", 60],
		["sl", 44, 34], ["f", 30], ["s", -34], ["f", 80], ["cp"],
		["sl", 60, -30], ["f", 40], ["sl", 50, 30], ["sl", 40, 20], ["f", 30], ["sl", 80, -50], ["f", 60],
		["sl", 48, 36], ["f", 40], ["s", -36], ["f", 60]],
	# 6 MIND THE GAP: kicker gaps, growing, some landing on a ledge; downhill run-ins.
	[["f", 160], ["k", 40, 10], ["p", 24, 0], ["f", 80], ["k", 40, 12], ["p", 36, 0], ["f", 90], ["cp"],
		["sl", 70, -20], ["f", 40], ["k", 40, 12], ["p", 40, 0], ["f", 120], ["k", 40, 12], ["p", 40, -12], ["f", 80],
		["cp"],
		["sl", 70, -20], ["f", 40], ["k", 44, 14], ["p", 52, 0], ["f", 80], ["s", 6], ["f", 40], ["k", 40, 12],
		["p", 40, 6], ["f", 80], ["cp"],
		["w", 3, 50, 10], ["sl", 80, -30], ["f", 40], ["k", 48, 16], ["p", 60, 0], ["f", 80], ["cp"],
		["sl", 80, -30], ["f", 40], ["k", 44, 14], ["p", 54, 0], ["f", 100], ["k", 40, 12], ["p", 44, -10], ["f", 80]],
	# 7 HOIST AND HAUL: blocks, stairs up, drops off.
	[["f", 140], ["m", 20, 50, 40, 0], ["f", 50], ["st", 4, 5, 32], ["f", 50], ["s", -20], ["f", 60], ["cp"],
		["m", 30, 70, 30, 0], ["f", 40], ["c", 16, 6, 40], ["f", 140], ["k", 40, 12], ["p", 44, 0], ["f", 70], ["cp"],
		["st", 4, 6, 32], ["f", 40], ["l", 5, 30], ["f", 30], ["s", -24], ["f", 70], ["cp"],
		["m", 36, 80, 30, 0], ["f", 80], ["t", 8, 40], ["f", 70]],
	# 8 QUARRY STEPS: big stairs and steep faces with ledges.
	[["f", 140], ["st", 4, 6, 32], ["f", 30], ["sl", 50, -24], ["f", 50], ["sl", 40, 28], ["f", 40], ["s", -28],
		["f", 60], ["cp"],
		["st", 5, 5, 30], ["f", 30], ["s", 8], ["f", 30], ["s", -33], ["f", 70], ["cp"],
		["sl", 60, -24], ["f", 50], ["k", 44, 14], ["p", 48, 4], ["f", 40], ["st", 3, 6, 32], ["f", 30],
		["sl", 60, -36], ["f", 60], ["cp"],
		["f", 60], ["sl", 50, 32], ["f", 30], ["s", 6], ["f", 30], ["c", 16, 6, 30], ["f", 40], ["s", -38], ["f", 70]],
	# 9 LAMPLIGHT: logs and crates in the dark mine.
	[["f", 140], ["l", 5, 30], ["l", 5, 40], ["f", 50], ["c", 18, 6, 40], ["f", 140], ["k", 40, 12], ["p", 40, 0],
		["f", 100], ["cp"],
		["cs", [6, 12, 6], 32], ["f", 50], ["l", 6, 40], ["f", 50], ["m", 20, 50, 30, 0], ["f", 60], ["cp"],
		["w", 4, 44, 10], ["l", 5, 30], ["sl", 70, -24], ["f", 40], ["k", 44, 14], ["p", 48, 0], ["f", 70], ["cp"],
		["c", 16, 6, 40], ["c", 16, 6, 40], ["f", 50], ["st", 4, 5, 32], ["f", 30], ["s", -20], ["f", 70]],
	# 10 HOODOO HOPS: whoops into gaps, humps into drops, ledges.
	[["f", 140], ["w", 4, 44, 12], ["sl", 70, -24], ["f", 50], ["k", 44, 14], ["p", 52, 0], ["f", 70], ["cp"],
		["h", 60, 18], ["s", -20], ["f", 40], ["s", 8], ["f", 50], ["h", 60, 18], ["s", -28], ["f", 140],
		["k", 40, 12], ["p", 36, 4], ["f", 60], ["cp"],
		["w", 5, 40, 12], ["f", 30], ["m", 26, 60, 30, 0], ["sl", 70, -24], ["f", 40], ["k", 48, 18], ["p", 60, 0],
		["f", 70], ["cp"],
		["sl", 50, 24], ["f", 40], ["k", 40, 12], ["p", 40, -24], ["f", 50], ["t", 8, 40], ["f", 40],
		["w", 3, 46, 14], ["f", 70]],
	# 11 LAUNCH PAD: drop-ins down to big kickers and long gaps; the course falls away.
	[["f", 120], ["sl", 100, -40], ["f", 30], ["k", 50, 18], ["p", 64, 0], ["f", 80], ["sl", 100, -40], ["f", 30],
		["k", 50, 20], ["p", 70, -10], ["f", 50], ["l", 6, 40], ["f", 60], ["cp"],
		["sl", 120, -54], ["f", 30], ["k", 48, 18], ["p", 60, 6], ["f", 60], ["sl", 100, -44], ["f", 30],
		["k", 54, 22], ["p", 76, -20], ["f", 70], ["cp"],
		["w", 3, 50, 12], ["sl", 120, -50], ["f", 30], ["k", 54, 22], ["p", 80, 0], ["f", 80], ["cp"],
		["st", 4, 5, 32], ["f", 20], ["sl", 100, -40], ["f", 30], ["k", 50, 18], ["p", 64, -16], ["f", 80], ["cp"],
		["sl", 100, -40], ["f", 30], ["k", 50, 18], ["p", 66, 0], ["f", 60], ["sl", 120, -50], ["f", 30],
		["k", 54, 22], ["p", 78, 0], ["f", 80]],
	# 12 THE GAUNTLET: a bit of everything, bigger.
	[["f", 160], ["l", 6, 40], ["c", 18, 6, 40], ["sl", 90, -30], ["f", 30], ["k", 48, 16], ["p", 60, 0], ["f", 70],
		["cp"],
		["st", 5, 6, 32], ["f", 30], ["s", -30], ["f", 50], ["cs", [6, 12, 6], 32], ["f", 50], ["cp"],
		["m", 30, 70, 30, 0], ["f", 40], ["sl", 50, -30], ["w", 4, 44, 12], ["sl", 90, -36], ["f", 30], ["k", 50, 18],
		["p", 64, 0], ["f", 70], ["cp"],
		["f", 50], ["sl", 50, 32], ["f", 20], ["s", 8], ["f", 30], ["l", 5, 20], ["f", 30], ["sl", 60, -40], ["f", 40],
		["t", 8, 40], ["f", 50], ["cp"],
		["sl", 110, -44], ["f", 30], ["k", 54, 22], ["p", 76, 0], ["f", 60], ["st", 4, 6, 32], ["f", 30], ["s", -24],
		["f", 30], ["l", 6, 40], ["f", 40], ["c", 16, 6, 40], ["c", 16, 6, 40], ["f", 80]],
]


static func count() -> int:
	return LEVELS.size()


static func meta(i: int) -> Dictionary:
	return LEVELS[clampi(i, 0, LEVELS.size() - 1)]


## The course as a level dict for drive_world.gd.
static func build(i: int, moves: Array = []) -> Dictionary:
	var c = Course.new()
	c.flat(300.0 + 120.0)    # from -300: a run-up before x = 0, where you start
	var marks := []   # [x where each move starts, the move] for the checker's reports
	for mv in (moves if not moves.is_empty() else COURSES[clampi(i, 0, COURSES.size() - 1)]):
		var a: Array = mv
		marks.append([c.x, a])
		match String(a[0]):
			"f":
				c.flat(float(a[1]))
			"s":
				c.step(float(a[1]))
			"sl":
				c.slope(float(a[1]), float(a[2]))
			"h":
				c.hump(float(a[1]), float(a[2]))
			"w":
				c.whoops(int(a[1]), float(a[2]), float(a[3]))
			"k":
				c.kicker(float(a[1]), float(a[2]))
			"p":
				c.pit(float(a[1]), float(a[2]))
			"c":
				c.crate(float(a[1]), float(a[2]), float(a[3]))
			"cs":
				c.crate_stairs(a[1], float(a[2]))
			"l":
				c.log_at(float(a[1]), float(a[2]))
			"st":
				c.stairs(int(a[1]), float(a[2]), float(a[3]))
			"t":
				c.table(float(a[1]), float(a[2]))
			"m":
				c.mesa(float(a[1]), float(a[2]), float(a[3]), float(a[4]))
			"cp":
				c.checkpoint()
			"tip":
				c.tips.append([c.x, String(a[1])])
	var m := meta(i).duplicate()
	m.erase("m")
	m.marks = marks
	return c.finish(m)
