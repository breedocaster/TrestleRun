## Air tricks for SUMMIT and GAUNTLET, done with the two pedals: two quick taps in the
## air pick one (a tap is a press let go within TAP, the second press coming within GAP
## of letting go of the first). The trick starts on the second press, but only counts
## once that pedal is let go within TAP too: hold it (a dab of brake, then gas held to
## steer the bike) and it's called off, no harm done. Starting it on the release
## instead cost so much air that no GAUNTLET jump had room for one.
##   brake, gas     WHIP           (the same flick that hops you on the ground)
##   gas, gas       NO-HANDER
##   gas, brake     HEEL CLICKER
##   brake, brake   SUPERMAN
## A held pedal still just tips the bike. While a trick is on, the rider is off the seat
## and can't steer the bike (vehicle_sim.gd air_lock); it has to be finished (80% of the
## way) before the wheels touch, or you bail. Tricks and flips in a row make a combo,
## which keeps going while you take off again within CHAIN_T of landing; it's banked
## then (SUMMIT pays coins, GAUNTLET counts points), and lost if you crash.
extends RefCounted

const TAP := 0.22
const GAP := 0.32
const CHAIN_T := 0.8
## A trick has to be this far through when the wheels touch.
const LAND_K := 0.8
## Air before taps count: the push off a kicker or the hop's own gas isn't a trick.
const MIN_AIR := 0.06

## pose: the rider's pose id (bike_view.gd); t: how long it takes (s).
## (Two quick taps take about 0.2 s of the jump, so a WHIP needs about 0.32 s of air, a
## SUPERMAN 0.45. The checker's rides off GAUNTLET's kickers are in the air 0.3-0.5 s,
## off SUMMIT's jump ramps 0.45-0.7.)
const TRICKS := {
	"BG": {"id": "whip", "name": "WHIP", "pose": 1, "t": 0.16, "coins": 10, "pts": 100},
	"GG": {"id": "nohander", "name": "NO-HANDER", "pose": 2, "t": 0.20, "coins": 15, "pts": 150},
	"GB": {"id": "heel", "name": "HEEL CLICKER", "pose": 3, "t": 0.26, "coins": 20, "pts": 200},
	"BB": {"id": "superman", "name": "SUPERMAN", "pose": 4, "t": 0.34, "coins": 30, "pts": 300},
}
const FLIP := {"id": "flip", "name": "FLIP", "coins": 25, "pts": 250}
## Each thing after the first in a combo adds this to the multiplier, up to MULT_MAX.
const MULT_STEP := 0.25
const MULT_MAX := 3.0

var enabled := true
var active: Dictionary = {}     # the trick in progress ({} = none)
var t := 0.0                    # s into it
var pending := false            # its second tap not let go yet (held past TAP: called off)
var _pend_key := ""
var combo: Array = []           # [id, name] of each trick or flip in the running combo
var ground_t := 0.0             # s on the ground since the combo's last landing
## Results of this ride.
var landed := 0                 # tricks landed
var kinds := {}                 # id -> true for each kind of trick landed
var best_combo := 0             # most things in one combo
var banked_coins := 0
var banked_pts := 0
var events: Array = []          # filled by update(): ["start"|"done"|"bail"|"bank"|"lost", ...]

var _clock := 0.0
var _taps: Array = []           # [key, press time, release time (-1 while held)]
var _g := false
var _b := false


func reset() -> void:
	active = {}
	pending = false
	t = 0.0
	combo = []
	ground_t = 0.0
	_taps = []


## One frame. grounded: any wheel down; airtime: s since leaving the ground.
func update(dt: float, gas_on: bool, brake_on: bool, grounded: bool, airtime: float) -> void:
	events = []
	_clock += dt
	if not active.is_empty() and pending:
		t += dt
		var held := gas_on if _pend_key == "G" else brake_on
		if grounded or (held and t > TAP):
			# Held, not tapped (or still down as the wheels touch): not a trick.
			active = {}
			pending = false
			events.append(["cancel"])
		elif not held:
			pending = false
			events.append(["start", active.name])
	elif not active.is_empty():
		t += dt
		if grounded:
			if t >= float(active.t) * LAND_K:
				_done()
			else:
				events.append(["bail", active.name])
				active = {}
				combo = []
		elif t >= float(active.t):
			_done()
	# Pedal edges.
	for key in ["G", "B"]:
		var on := gas_on if key == "G" else brake_on
		var was := _g if key == "G" else _b
		if on and not was:
			_press(key, grounded, airtime)
		elif was and not on:
			for tp in _taps:
				if tp[0] == key and float(tp[2]) < 0.0:
					tp[2] = _clock
			_release()
	_g = gas_on
	_b = brake_on
	if grounded:
		_taps = []
		if not combo.is_empty() and active.is_empty():
			ground_t += dt
			if ground_t >= CHAIN_T:
				bank()
	else:
		ground_t = 0.0


func _press(key: String, grounded: bool, airtime: float) -> void:
	if not enabled or grounded or airtime < MIN_AIR or not active.is_empty():
		return
	# The one before a tap let go just now: this press makes the pair.
	if not _taps.is_empty():
		var p: Array = _taps[_taps.size() - 1]
		var rel := float(p[2])
		if rel >= 0.0 and rel - float(p[1]) <= TAP and _clock - rel <= GAP:
			var spec: Dictionary = TRICKS.get(String(p[0]) + key, {})
			if not spec.is_empty():
				active = spec
				t = 0.0
				pending = true
				_pend_key = key
				_taps = []
				return
	_taps = [[key, _clock, -1.0]]


func _release() -> void:
	pass


func _done() -> void:
	combo.append([String(active.id), String(active.name)])
	landed += 1
	kinds[String(active.id)] = true
	events.append(["done", active.name])
	active = {}


## Flips counted at a landing (drive_world.gd) join the combo.
func add_flips(n: int) -> void:
	for k in n:
		combo.append([FLIP.id, FLIP.name])
	if n > 0:
		ground_t = 0.0


## The rider's pose for drawing: id + how far into it (0..0.99), 0 when riding.
func pose() -> float:
	if active.is_empty():
		return 0.0
	if pending:
		# Just a twitch toward it until the tap's let go.
		return float(active.pose) + clampf(t / float(active.t), 0.0, 0.3)
	var u := clampf(t / float(active.t), 0.0, 1.0)
	# Out to the full pose over the first quarter, back over the last quarter.
	var k := minf(u / 0.25, 1.0) * minf((1.0 - u) / 0.25, 1.0)
	return float(active.pose) + clampf(k, 0.0, 0.99)


func multiplier(n: int) -> float:
	return minf(MULT_MAX, 1.0 + MULT_STEP * float(maxi(n - 1, 0)))


## What the running combo is worth: [coins, points]. The same trick again in one combo
## counts half.
func value() -> Array:
	var seen := {}
	var c := 0.0
	var p := 0.0
	for e in combo:
		var spec: Dictionary = FLIP
		for k in TRICKS:
			if TRICKS[k].id == e[0]:
				spec = TRICKS[k]
		var half := 0.5 if seen.has(e[0]) and e[0] != "flip" else 1.0
		seen[e[0]] = true
		c += float(spec.coins) * half
		p += float(spec.pts) * half
	var m := multiplier(combo.size())
	return [int(roundf(c * m)), int(roundf(p * m))]


## Pay out the running combo (also at the end of a ride).
func bank() -> void:
	if combo.is_empty():
		return
	var v := value()
	best_combo = maxi(best_combo, combo.size())
	banked_coins += int(v[0])
	banked_pts += int(v[1])
	events.append(["bank", combo.size(), v[0], v[1], combo.map(func(e): return e[1])])
	combo = []
	ground_t = 0.0


## A crash: the combo in hand is gone.
func lose() -> void:
	if not combo.is_empty():
		events.append(["lost", combo.size()])
	combo = []
	active = {}
