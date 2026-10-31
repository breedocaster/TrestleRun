## Three extra objectives per SUMMIT and GAUNTLET level, beyond finishing and the medal
## times: shown as stars on the level cards, listed when a ride starts, in the pause
## panel and on the results. Each pays once, the first time. The objectives themselves
## come from the level checker's data (extras_table.gd, written by --drive-air --write),
## so each is one it has seen done: coins its own ride picked up, the jumps where it
## landed a trick and rode away, the fuel it had left, bikes it got through.
##   [type, n]:
##   coins n     pick up n coins in one ride (not counting trick and flip pay)
##   tricks n    land n air tricks in one ride
##   trick id    land that trick (tricks.gd id)
##   points n    GAUNTLET: n trick points in one ride
##   air s       s seconds in the air in one jump
##   fuel n      SUMMIT: reach the top with n% of the tank left
##   clean       GAUNTLET: finish with no faults
##   hops n      GAUNTLET: finish in n hops or fewer
##   bike kind   finish on a battery bike ("electric") or an electric unicycle ("unicycle")
extends RefCounted

const Table := preload("res://scripts/drive/extras_table.gd")
const Tricks := preload("res://scripts/drive/tricks.gd")
const Vehicles := preload("res://scripts/drive/vehicles.gd")

## Coins for each objective, by its place in the list (the lists go easy to hard).
const PAY := [60, 100, 150]
## Types that need you to finish the level; the rest count in any ride.
const AT_FINISH := ["fuel", "clean", "hops", "bike"]


static func of(id: String) -> Array:
	return Table.OBJECTIVES.get(id, [])


static func text(o: Array, electric := false) -> String:
	match String(o[0]):
		"coins":
			return "PICK UP %d COINS" % int(o[1])
		"tricks":
			return "LAND %d AIR TRICK%s" % [int(o[1]), "" if int(o[1]) == 1 else "S"]
		"trick":
			for k in Tricks.TRICKS:
				if Tricks.TRICKS[k].id == String(o[1]):
					return "LAND A %s (%s)" % [Tricks.TRICKS[k].name, _keys(String(k))]
			return "LAND A TRICK"
		"points":
			return "SCORE %d TRICK POINTS" % int(o[1])
		"air":
			return "%.1fS IN THE AIR IN ONE JUMP" % float(o[1])
		"fuel":
			return "TOP WITH %d%% %s LEFT" % [int(o[1]), "CHARGE" if electric else "FUEL"]
		"clean":
			return "FINISH WITH NO FAULTS"
		"hops":
			return "FINISH IN %d HOPS OR FEWER" % int(o[1])
		"bike":
			return "FINISH ON AN ELECTRIC UNICYCLE" if String(o[1]) == "unicycle" else "FINISH ON A BATTERY BIKE"
	return String(o[0]).to_upper()


static func _keys(k: String) -> String:
	return " + ".join(Array(k.split("")).map(func(c): return "GAS" if c == "G" else "BRAKE"))


## Did this ride do it?
static func met(o: Array, r: Dictionary) -> bool:
	var t := String(o[0])
	if t in AT_FINISH and not bool(r.get("ok", false)):
		return false
	match t:
		"coins":
			return int(r.get("pickup_coins", 0)) >= int(o[1])
		"tricks":
			return int(r.get("tricks", 0)) >= int(o[1])
		"trick":
			return (r.get("trick_kinds", []) as Array).has(String(o[1]))
		"points":
			return int(r.get("trick_pts", 0)) >= int(o[1])
		"air":
			return float(r.get("max_air", 0.0)) >= float(o[1]) - 0.005
		"fuel":
			return float(r.get("fuel_left", 0.0)) * 100.0 >= float(o[1])
		"clean":
			return int(r.get("faults", 0)) == 0
		"hops":
			return int(r.get("hops", 0)) <= int(o[1])
		"bike":
			var b := String(r.get("bike", ""))
			if String(o[1]) == "unicycle":
				return bool(Vehicles.spec(b).get("unicycle", false))
			return Vehicles.is_electric(b)
	return false
