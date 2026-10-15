## v0.4 trail layouts (dev only), kept to compare difficulty with the new ramp.
extends RefCounted

const OLD := [
	["dusty_trail", 128.0, [
		["start"], ["flat", 140.0], ["gap", 40.0], ["flat", 120.0], ["crawler", 170.0],
		["gap", 52.0], ["spiker"], ["flat", 100.0], ["branch_upper", 1],
		["checkpoint"],
		["drone"], ["gap", 56.0], ["drop", 24.0], ["flat", 110.0], ["crawler", 180.0],
		["secret_low", 1],
		["checkpoint"],
		["spiker"], ["gap", 60.0], ["perch", 1], ["climb", 22.0], ["flat", 110.0],
		["spiker_drone"], ["flat", 100.0], ["finish"],
	]],
	["copper_canyon", 136.0, [
		["start"], ["flat", 120.0], ["gap", 56.0], ["stairs_down", 3], ["spiker"],
		["crawler", 220.0, 2], ["ramp"], ["branch_upper", 1],
		["checkpoint"],
		["drone"], ["double_spiker", 96.0], ["stairs_up", 3], ["gap", 64.0, 24.0],
		["split", 1],
		["checkpoint"],
		["spiker_drone"], ["drone_gap", 52.0], ["flat", 90.0], ["perch", 1],
		["gap", 60.0], ["crawler", 170.0], ["finish"],
	]],
	["rustyard", 144.0, [
		["start"], ["crawler_chain", 3], ["gap", 60.0], ["drone_gap", 56.0], ["spiker"],
		["checkpoint"],
		["secret_low", 1], ["stairs_up", 3], ["double_spiker", 90.0], ["ramp"],
		["checkpoint"],
		["split", 1], ["crawler_chain", 4], ["gap", 64.0], ["drone"], ["perch", 1],
		["spiker_drone"], ["flat", 90.0], ["finish"],
	]],
	["night_trestle", 150.0, [
		["start"], ["gap", 60.0], ["spiker_drone"], ["stairs_down", 3], ["crawler_chain", 3],
		["drone_gap", 58.0],
		["checkpoint"],
		["branch_upper", 1], ["double_spiker", 82.0], ["ramp"], ["gap", 70.0, 20.0],
		["checkpoint"],
		["secret_low", 1], ["stairs_up", 3], ["crawler_chain", 4], ["split", 1],
		["drone_gap", 60.0], ["double_spiker", 78.0], ["flat", 80.0], ["finish"],
	]],
]
