## Level layouts: lists of [chunk, args...] built by level_library.gd.
## Each trail adds one new feature (Catalog.FEATURES) on top of the earlier ones, and
## speed, gap widths and hazard density climb from trail to trail.
extends RefCounted

const LAYOUTS := {
	# 1: rolling dunes. Jumping only, small gaps, hop rows; crests and two kickers for first flips.
	"dusty_trail": [
		["start"], ["flat", 100.0], ["hills", 2, 12.0], ["gap", 30.0], ["flat", 60.0], ["hills", 1, 16.0],
		["gap", 36.0], ["high_coins"], ["hops", 2, 26.0], ["flat", 90.0], ["branch_upper", 1, "g"],
		["checkpoint"],
		["hills", 3, 14.0], ["gap", 40.0], ["stairs_down", 2], ["kicker", 52.0, 34.0], ["high_coins", 180.0, 54.0],
		["climb", 18.0], ["flat", 80.0], ["secret_low", 1],
		["checkpoint"],
		["hills", 2, 16.0], ["hops", 3, 28.0], ["gap", 44.0], ["perch", 1], ["flat", 60.0], ["kicker", 56.0, 36.0],
		["hills", 1, 14.0], ["gap", 46.0], ["finish"],
	],
	# 2: canyon drops and climbs, crawlers to stomp.
	"copper_canyon": [
		["start"], ["flat", 120.0], ["crawler", 170.0], ["power", "magnet"], ["descent", 2, 18.0], ["gap", 38.0], ["flat", 80.0],
		["crawler", 200.0], ["hops", 2, 30.0], ["rise", 2, 14.0], ["branch_upper", 1, "c"],
		["checkpoint"],
		["crawler", 220.0, 2], ["stairs_down", 3], ["gap", 44.0], ["crawler_chain", 2, 100.0], ["kicker", 72.0, 40.0],
		["high_coins"], ["secret_low", 1],
		["checkpoint"],
		["crawler", 170.0], ["climb", 20.0], ["power", "magnet"], ["rise", 2, 12.0], ["perch", 1], ["descent", 3, 16.0], ["gap", 48.0],
		["crawler_chain", 3, 100.0], ["flat", 80.0], ["finish"],
	],
	# 3: scrapyard clusters, spikers you can't stomp, and switch tracks into the back yard.
	"rustyard": [
		["start"], ["flat", 100.0], ["spiker"], ["gap", 44.0], ["crawler", 170.0], ["spiker"],
		["fork", 1, [["flat", 60.0], ["crawler", 170.0], ["flat", 60.0]], [["double_spiker", 100.0], ["flat", 60.0]]],
		["hops", 2, 32.0], ["branch_upper", 1, "s"],
		["checkpoint"],
		["double_spiker", 110.0], ["stairs_up", 2], ["gap", 50.0], ["crawler_chain", 3, 92.0], ["spiker"],
		["fork", 1, [["spiker"], ["gap", 40.0], ["flat", 80.0]], [], 1, 1],
		["checkpoint"],
		["ramp", 76.0], ["flat", 40.0], ["spiker"], ["crawler", 220.0, 2], ["perch", 1], ["double_spiker", 100.0],
		["flat", 40.0], ["gap", 52.0], ["finish"],
	],
	# 4: one long night bridge, flyers overhead, and a rush along the foreground track.
	"night_trestle": [
		["start"], ["flat", 100.0], ["power", "hat"], ["drone"], ["flat", 120.0], ["gap", 46.0], ["spiker"], ["drone"], ["crawler", 170.0],
		["drone_row", 2], ["branch_upper", 1, "d"],
		["checkpoint"],
		["fork", -1, [["drone_row", 2, 70.0], ["crawler", 170.0]], [], 0, 1],
		["drone_gap", 46.0, 66.0], ["stairs_down", 3], ["spiker_drone"], ["double_spiker", 96.0], ["gap", 54.0],
		["split", 1],
		["checkpoint"],
		["power", "hat"], ["drone_row", 3], ["crawler_chain", 3, 84.0], ["flat", 60.0], ["drone_gap", 48.0, 66.0], ["flat", 40.0], ["perch", 1],
		["spiker_drone"], ["gap", 56.0], ["finish"],
	],
	# 5: bouncy: springs between rolling hills.
	"mesa_springs": [
		["start"], ["flat", 100.0], ["hills", 1, 14.0], ["spring_up", 0, ""], ["gap", 56.0], ["spiker"],
		["spring_gap", 84.0], ["hills", 2, 12.0], ["crawler", 170.0], ["gap", 58.0], ["spring_up", 1, "s"],
		["checkpoint"],
		["drone"], ["spring_trap"], ["gap", 58.0], ["spring_chain", 78.0], ["power", "magnet"], ["hills", 2, 14.0],
		["double_spiker", 90.0], ["drone_gap", 50.0, 64.0], ["secret_low", 1],
		["checkpoint"],
		["crawler_chain", 3, 78.0], ["spring_gap", 84.0], ["drone_gap", 52.0, 64.0], ["flat", 80.0],
		["spring_up", 1, "cd"], ["spiker_drone"], ["stairs_down", 3], ["kicker", 76.0, 40.0], ["gap", 60.0], ["finish"],
	],
	# 6: low mine tunnels, with side shafts in the back.
	"lantern_mine": [
		["start"], ["flat", 100.0], ["tunnel", ["flat", "gap", "flat"]], ["crawler", 170.0], ["gap", 58.0],
		["fork", 1, [["tunnel", ["gap", "crawler", "gap"]], ["flat", 40.0]], [["tunnel", ["spiker", "gap", "bag"]]], 1],
		["checkpoint"],
		["drone_row", 2], ["power", "hat"], ["tunnel", ["gap", "crawler", "gap"]], ["double_spiker", 88.0], ["descent", 2, 16.0],
		["stairs_down", 2], ["cliff", 280.0, 100.0, 0, 1], ["secret_low", 1],
		["checkpoint"],
		["tunnel", ["spiker", "gap", "spiker", "gap"]], ["flat", 70.0], ["drone_gap", 50.0, 64.0], ["perch", 1],
		["fork", 1, [["tunnel", ["gap", "gap", "bag"]]], [], 0, 1],
		["spring_gap", 86.0], ["finish"],
	],
	# 7: flowing: loops linked by hills and kickers.
	"hoodoo_loops": [
		["start"], ["flat", 100.0], ["hills", 1, 14.0], ["loop"], ["power", "magnet"], ["gap", 58.0], ["crawler", 170.0],
		["loop", 38.0, "gap", 50.0], ["hills", 2, 14.0], ["spiker_drone"], ["double_spiker", 86.0],
		["branch_upper", 1, "sc"],
		["checkpoint"],
		["tunnel", ["gap", "spiker", "gap"]], ["loop", 40.0, "gap", 56.0], ["kicker", 76.0, 40.0],
		["flat", 40.0], ["drone_gap", 56.0, 60.0], ["spring_up", 1, "d"], ["double_spiker", 86.0], ["secret_low", 1],
		["checkpoint"],
		["drone_gap", 56.0, 60.0], ["loop", 38.0, "gap", 58.0], ["tri_ramp", 0, "c"], ["hills", 2, 16.0], ["crawler_chain", 3, 72.0],
		["perch", 0], ["stairs_up", 3], ["loop"], ["gap", 62.0], ["spiker_drone"], ["finish"],
	],
	# 8: stacked yard: lifts, gantries in the back, catwalk in front.
	"hoist_yard": [
		["start"], ["flat", 100.0], ["lifts", [[64.0, 14.0, 2.6, 0.0]], 46.0], ["crawler", 170.0], ["gap", 64.0],
		["lifts", [[56.0, 18.0, 2.2, 0.0], [56.0, 18.0, 2.2, PI]], 50.0], ["spiker_drone"],
		["loop", 38.0, "gap", 54.0],
		["checkpoint"],
		["fork", 1, [["lifts", [[52.0, 20.0, 2.0, 0.0], [52.0, 20.0, 2.0, 2.1]], 50.0], ["flat", 40.0]],
			[["tunnel", ["gap", "spiker", "gap"]]], 1],
		["spring_up", 1, "s"], ["double_spiker", 80.0], ["cliff", 300.0, 110.0, 0, 1, 58.0, ["spiker"]], ["flat", 40.0], ["drone_gap", 56.0, 62.0],
		["checkpoint"],
		["power", "hat"], ["drone_row", 3], ["lifts", [[50.0, 22.0, 1.8, 0.0], [50.0, 22.0, 1.8, PI], [50.0, 22.0, 1.8, 0.0]], 52.0],
		["fork", -1, [["crawler_chain", 3, 84.0]], [], 0, 1],
		["loop", 40.0, "gap", 58.0], ["flat", 50.0], ["perch", 1], ["spring_gap", 88.0],
		["gap", 66.0], ["finish"],
	],
	# 9: mountain descent with big airs, ziplines, and everything before.
	"skyline_pass": [
		["start"], ["flat", 100.0], ["zip", 260.0, 60.0, 24.0], ["descent", 3, 16.0], ["crawler", 170.0],
		["kicker", 80.0, 44.0], ["loop", 40.0, "gap", 56.0], ["spiker_drone"], ["double_spiker", 78.0],
		["zip", 300.0, 62.0, 30.0, 1],
		["checkpoint"],
		["descent", 2, 18.0], ["lifts", [[54.0, 20.0, 2.0, 0.0], [54.0, 20.0, 2.0, 2.6]], 50.0],
		["tunnel", ["gap", "spiker", "gap", "spiker"], 60.0, 46.0], ["spring_gap", 92.0], ["drone_row", 3],
		["fork", 1, [["zip", 280.0, 60.0, 26.0]], [["kicker", 80.0, 40.0], ["flat", 60.0]]],
		["zip", 320.0, 62.0, 34.0, 0, "s"],
		["checkpoint"],
		["double_spiker", 94.0], ["descent", 3, 16.0], ["tri_ramp", 0, "c"], ["flat", 80.0], ["crawler_chain", 3, 74.0], ["loop", 40.0, "gap", 60.0],
		["branch_upper", 1, "sc"], ["flat", 50.0], ["drone_gap", 58.0, 60.0], ["kicker", 84.0, 48.0], ["spring_trap"], ["perch", 1],
		["zip", 280.0, 60.0, 26.0], ["descent", 2, 18.0], ["stairs_down", 3], ["gap", 70.0], ["finish"],
	],
	# 10: quarry cliffs. Sticky tires climb the faces to the routes on top; tunnels below.
	"quarry_cliffs": [
		["start"], ["flat", 100.0], ["cliff", 300.0, 110.0, 1], ["gap", 56.0], ["crawler", 170.0], ["descent", 2, 16.0],
		["cliff", 260.0, 100.0, 0, 1, 58.0, ["spiker"]], ["flat", 60.0], ["spiker_drone"],
		["checkpoint"],
		["drone_gap", 56.0, 62.0], ["power", "hat"], ["double_spiker", 106.0], ["kicker", 80.0, 44.0], ["flat", 80.0],
		["cliff", 340.0, 120.0, 1, 1, 58.0, ["crawler"]], ["stairs_down", 3], ["spring_gap", 88.0],
		["checkpoint"],
		["cliff", 300.0, 110.0, 0, 1, 58.0, ["crawler"]], ["drone_row", 2], ["secret_low", 1], ["loop", 40.0, "gap", 56.0],
		["rise", 2, 14.0], ["cliff", 280.0, 100.0, 0, 1], ["gap", 62.0], ["finish"],
	],
	# 11: rocket ridge. Three-way ramps: rocket to the top, a full jump to the middle, a tap to the bottom.
	"rocket_ridge": [
		["start"], ["flat", 100.0], ["tri_ramp", 1, "c"], ["gap", 60.0], ["spiker_drone"], ["hills", 2, 14.0],
		["checkpoint"],
		["power", "magnet"], ["tri_ramp", 0, "c"], ["drone_gap", 56.0, 62.0],
		["lifts", [[60.0, 18.0, 2.0, 0.0], [60.0, 18.0, 2.0, 2.6]], 48.0], ["crawler_chain", 3, 80.0],
		["checkpoint"],
		["kicker", 84.0, 46.0], ["flat", 100.0], ["tri_ramp", 1, "d"], ["spring_gap", 90.0], ["power", "hat"], ["double_spiker", 106.0],
		["perch", 1], ["flat", 60.0], ["tri_ramp", 0, ""], ["zip", 300.0, 62.0, 30.0], ["gap", 64.0], ["finish"],
	],
	# 12: the last trestle, collapsing behind you, its old planks crumbling underfoot.
	"last_trestle": [
		["chase"], ["start"], ["flat", 100.0], ["crumble"], ["gap", 50.0], ["crawler", 170.0],
		["crumble", [44.0, 44.0, 88.0, 44.0, 44.0, 96.0, 44.0]], ["branch_upper", 1, "s"],
		["checkpoint"],
		["power", "hat"], ["spiker_drone"], ["crumble", [44.0, 96.0, 44.0, 96.0, 44.0, 44.0]], ["loop"], ["gap", 50.0],
		["drone_gap", 56.0, 62.0], ["crumble", [88.0, 44.0, 88.0, 44.0]], ["secret_low", 1],
		["checkpoint"],
		["kicker", 80.0, 44.0], ["crumble", [44.0, 44.0, 44.0, 44.0, 44.0, 44.0]], ["double_spiker", 92.0],
		["power", "rocket"], ["crumble", [96.0, 44.0, 96.0]], ["perch", 1], ["stairs_down", 3], ["gap", 66.0], ["finish"],
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
	"trick": [["start", 120.0], ["spring_gap", 84.0], ["flat", 100.0, 0], ["stairs_down", 2], ["flat", 60.0], ["gap", 44.0], ["finish"]],
	"switch": [["start", 100.0], ["fork", 1, [["flat", 100.0]], [["spiker"], ["flat", 80.0]]], ["flat", 40.0],
		["fork", -1, [["flat", 80.0]], [], 0, 1], ["finish"]],
	"magnet": [["start", 100.0], ["power", "magnet", 120.0], ["high_coins"], ["flat", 60.0], ["high_coins", 180.0, 54.0], ["finish"]],
	"hat": [["start", 100.0], ["power", "hat", 120.0], ["flat", 40.0], ["spiker"], ["flat", 60.0], ["finish"]],
	"sticky": [["start", 80.0], ["cliff", 240.0, 100.0, 0, 1], ["finish"]],
	"rocket": [["start", 40.0], ["tri_ramp", 0, ""], ["finish"]],
	"crumble": [["start", 120.0], ["crumble", [44.0, 44.0, 88.0, 44.0]], ["flat", 60.0], ["crumble", [44.0, 96.0, 44.0]], ["finish"]],
	"chase": [["chase"], ["start", 120.0], ["flat", 160.0], ["gap", 40.0], ["flat", 160.0], ["finish"]],
}
