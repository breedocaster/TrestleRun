## Level layouts: lists of [chunk, args...] built by level_library.gd.
## Each trail adds one new feature (Catalog.FEATURES) on top of the earlier ones, and
## speed, gap widths and hazard density climb from trail to trail.
extends RefCounted

const LAYOUTS := {
	# 1: jumping only. Small gaps, hop rows, coins up high to teach the long hold.
	"dusty_trail": [
		["start"], ["flat", 120.0], ["gap", 30.0], ["flat", 100.0], ["gap", 36.0], ["high_coins"],
		["hops", 2, 26.0], ["flat", 90.0], ["branch_upper", 1, "g"],
		["checkpoint"],
		["gap", 40.0], ["stairs_down", 2], ["high_coins", 180.0, 54.0], ["climb", 18.0], ["flat", 100.0],
		["secret_low", 1],
		["checkpoint"],
		["hops", 3, 28.0], ["gap", 44.0], ["perch", 1], ["flat", 80.0], ["gap", 46.0], ["finish"],
	],
	# 2: crawlers to stomp.
	"copper_canyon": [
		["start"], ["flat", 120.0], ["crawler", 170.0], ["gap", 38.0], ["flat", 80.0], ["crawler", 200.0],
		["hops", 2, 30.0], ["branch_upper", 1, "c"],
		["checkpoint"],
		["crawler", 220.0, 2], ["stairs_down", 3], ["gap", 44.0], ["crawler_chain", 2, 100.0], ["high_coins"],
		["secret_low", 1],
		["checkpoint"],
		["crawler", 170.0], ["climb", 20.0], ["perch", 1], ["gap", 48.0], ["crawler_chain", 3, 100.0],
		["flat", 80.0], ["finish"],
	],
	# 3: spikers you can't stomp.
	"rustyard": [
		["start"], ["flat", 100.0], ["spiker"], ["gap", 44.0], ["crawler", 170.0], ["spiker"],
		["hops", 2, 32.0], ["branch_upper", 1, "s"],
		["checkpoint"],
		["double_spiker", 110.0], ["stairs_up", 2], ["gap", 50.0], ["crawler_chain", 3, 92.0], ["spiker"],
		["secret_low", 1],
		["checkpoint"],
		["ramp", 76.0], ["flat", 40.0], ["spiker"], ["crawler", 220.0, 2], ["perch", 1], ["double_spiker", 100.0],
		["flat", 40.0], ["gap", 52.0], ["finish"],
	],
	# 4: drones: stay low.
	"night_trestle": [
		["start"], ["flat", 100.0], ["drone"], ["gap", 46.0], ["spiker"], ["drone"], ["crawler", 170.0],
		["drone_row", 2], ["branch_upper", 1, "d"],
		["checkpoint"],
		["drone_gap", 46.0, 66.0], ["stairs_down", 3], ["spiker_drone"], ["double_spiker", 96.0], ["gap", 54.0],
		["split", 1],
		["checkpoint"],
		["drone_row", 3], ["crawler_chain", 3, 84.0], ["drone_gap", 48.0, 66.0], ["perch", 1], ["spiker_drone"],
		["gap", 56.0], ["finish"],
	],
	# 5: springs.
	"mesa_springs": [
		["start"], ["flat", 100.0], ["spring_up", 0, ""], ["gap", 56.0], ["spiker"], ["spring_gap", 84.0],
		["crawler", 170.0], ["gap", 58.0], ["spring_up", 1, "s"],
		["checkpoint"],
		["drone"], ["spring_trap"], ["gap", 58.0], ["spring_chain", 78.0], ["flat", 40.0],
		["double_spiker", 90.0], ["drone_gap", 50.0, 64.0], ["secret_low", 1],
		["checkpoint"],
		["crawler_chain", 3, 78.0], ["spring_gap", 84.0], ["drone_gap", 52.0, 64.0], ["flat", 80.0],
		["spring_up", 1, "cd"], ["spiker_drone"], ["stairs_down", 3], ["gap", 60.0], ["finish"],
	],
	# 6: low ceilings in mine tunnels: tap, don't hold.
	"lantern_mine": [
		["start"], ["flat", 100.0], ["tunnel", ["flat", "gap", "flat"]], ["crawler", 170.0], ["gap", 58.0],
		["tunnel", ["spiker", "gap", "bag"]], ["spring_up", 1, "s"],
		["checkpoint"],
		["drone_row", 2], ["tunnel", ["gap", "crawler", "gap"]], ["double_spiker", 88.0], ["stairs_down", 3],
		["secret_low", 1],
		["checkpoint"],
		["tunnel", ["spiker", "gap", "spiker", "gap"]], ["drone_gap", 56.0, 60.0], ["perch", 1],
		["spring_gap", 86.0], ["tunnel", ["gap", "gap", "bag"]], ["finish"],
	],
	# 7: loop-the-loops.
	"hoodoo_loops": [
		["start"], ["flat", 100.0], ["loop"], ["gap", 58.0], ["crawler", 170.0], ["loop", 38.0, "gap", 50.0],
		["spiker_drone"], ["double_spiker", 86.0], ["branch_upper", 1, "sc"],
		["checkpoint"],
		["tunnel", ["gap", "spiker", "gap"]], ["loop", 40.0, "gap", 56.0], ["drone_gap", 56.0, 60.0],
		["spring_up", 1, "d"], ["double_spiker", 86.0], ["secret_low", 1],
		["checkpoint"],
		["drone_gap", 56.0, 60.0], ["loop", 38.0, "gap", 58.0], ["flat", 60.0], ["crawler_chain", 3, 72.0], ["perch", 0],
		["stairs_up", 3], ["loop"], ["gap", 62.0], ["spiker_drone"], ["finish"],
	],
	# 8: bobbing lifts.
	"hoist_yard": [
		["start"], ["flat", 100.0], ["lifts", [[64.0, 14.0, 2.6, 0.0]], 46.0], ["crawler", 170.0], ["gap", 64.0],
		["lifts", [[56.0, 18.0, 2.2, 0.0], [56.0, 18.0, 2.2, PI]], 50.0], ["spiker_drone"],
		["loop", 38.0, "gap", 54.0],
		["checkpoint"],
		["lifts", [[52.0, 20.0, 2.0, 0.0], [52.0, 20.0, 2.0, 2.1], [52.0, 20.0, 2.0, 4.2]], 50.0, 1],
		["tunnel", ["gap", "spiker", "gap"]], ["spring_up", 1, "s"], ["double_spiker", 80.0],
		["drone_gap", 58.0, 58.0],
		["checkpoint"],
		["drone_row", 3], ["lifts", [[50.0, 22.0, 1.8, 0.0], [50.0, 22.0, 1.8, PI], [50.0, 22.0, 1.8, 0.0]], 52.0],
		["loop", 40.0, "gap", 58.0], ["flat", 50.0], ["perch", 1], ["crawler_chain", 3, 84.0], ["spring_gap", 88.0],
		["gap", 66.0], ["finish"],
	],
	# 9: ziplines, plus everything before.
	"skyline_pass": [
		["start"], ["flat", 100.0], ["zip", 260.0, 60.0, 24.0], ["crawler", 170.0], ["gap", 64.0],
		["loop", 40.0, "gap", 56.0], ["spiker_drone"], ["double_spiker", 78.0], ["zip", 300.0, 62.0, 30.0, 1],
		["checkpoint"],
		["lifts", [[54.0, 20.0, 2.0, 0.0], [54.0, 20.0, 2.0, 2.6]], 50.0],
		["tunnel", ["gap", "spiker", "gap", "spiker"], 60.0, 46.0], ["spring_gap", 92.0], ["drone_row", 3],
		["zip", 320.0, 62.0, 34.0, 0, "s"],
		["checkpoint"],
		["double_spiker", 94.0], ["crawler_chain", 3, 74.0], ["loop", 40.0, "gap", 60.0],
		["branch_upper", 1, "sc"], ["drone_gap", 58.0, 60.0], ["spring_trap"], ["perch", 1],
		["zip", 280.0, 60.0, 26.0], ["stairs_down", 3], ["gap", 70.0], ["finish"],
	],
}

## Short loops of one feature for the hint card's live demo (the bot rides them).
const DEMOS := {
	"jump": [["start", 120.0], ["gap", 36.0], ["flat", 60.0], ["hops", 2, 28.0], ["high_coins"], ["gap", 44.0], ["finish"]],
	"crawler": [["start", 120.0], ["crawler", 170.0], ["flat", 40.0], ["crawler_chain", 2], ["finish"]],
	"spiker": [["start", 120.0], ["spiker"], ["flat", 40.0], ["double_spiker", 100.0], ["finish"]],
	"drone": [["start", 120.0], ["drone"], ["drone_gap", 50.0], ["drone_row", 2], ["finish"]],
	"spring": [["start", 120.0], ["spring_up", 0, "s"], ["flat", 40.0], ["spring_gap", 84.0], ["finish"]],
	"tunnel": [["start", 120.0], ["tunnel", ["gap", "spiker", "gap"]], ["finish"]],
	"loop": [["start", 120.0], ["loop"], ["flat", 40.0], ["loop", 38.0, "gap", 46.0], ["finish"]],
	"lift": [["start", 120.0], ["lifts", [[60.0, 16.0, 2.4, 0.0], [60.0, 16.0, 2.4, PI]], 46.0], ["finish"]],
	"zip": [["start", 120.0], ["zip", 260.0, 60.0, 24.0], ["finish"]],
}
