## Lookahead autopilot: proves levels are beatable (dev verify) and rides the hint demos.
## Each frame it can jump it compares "keep riding" against a few hold lengths, rolling
## each forward with the real physics. A jump only counts as safe if, after landing,
## there is still some way to continue (ride on, or jump again at some later frame).
## On a zipline it keeps holding, and lets go early only when dropping off is safe
## and scores better (e.g. a gear on a lower deck).
extends RefCounted

const Phys := preload("res://scripts/game/bike_physics.gd")
const P_GEAR := 2

const HOLDS := [3, 7, 12, 30]
const CONT_HOLDS := [4, 8, 14, 30]
const GRACE := 10

var level: Dictionary
var horizon := 66
var eval_every := 3
var collect := true
var trace := Vector2(-1, -1)
## Dev stats: every press the bot was forced to make (riding on would crash).
var forced: Array = []
var _hold_left := 0
var _was_air := false
var _tick := 0


func _init(lvl: Dictionary) -> void:
	level = lvl


func decide(s: Dictionary) -> Array:
	_tick += 1
	if int(s.zip) >= 0:
		_hold_left = 0
		return [false, not _release_better(s)]
	if _hold_left > 0 and s.grounded and _was_air:
		_hold_left = 0  # touched down: the jump's done, plan afresh (as the sims assume)
	_was_air = not s.grounded
	if _hold_left > 0:
		_hold_left -= 1
		return [false, true]
	if not s.grounded and s.coyote <= 0.0:
		return [false, false]
	var base := _ride(s, horizon)
	if not base.safe and base.has("loop_exit"):
		# Trouble only after a loop: ride the loop and jump on the way out.
		var after := _continue(base.loop_exit, 2)
		if after.safe:
			base = {"safe": true, "score": float(base.score) + float(after.score)}
	if base.safe and (not collect or _tick % eval_every != 0):
		return [false, false]
	var best_opt := 0 if base.safe else -1
	var best_score: float = base.score if base.safe else -INF
	var log := []
	for h in (HOLDS + [70] if s.ab == "glide" else HOLDS):
		var r := _jump(s, h, 2)
		log.append([h, r.safe])
		if r.safe and r.score - 0.25 > best_score:
			best_score = r.score - 0.25
			best_opt = h
	if s.x >= trace.x and s.x <= trace.y:
		print("TRACE x=%.1f g=%s base=%s pick=%d %s" % [s.x, s.grounded, base.safe, best_opt, log])
	if best_opt > 0:
		if not base.safe:
			forced.append({"x": s.x, "t": s.t, "hold": best_opt})
		_hold_left = best_opt - 1
		return [true, true]
	return [false, false]


func _copy(s0: Dictionary) -> Dictionary:
	var s := s0.duplicate()
	s.stomped = (s0.stomped as Dictionary).duplicate()
	return s


## On a cable: is letting go now safe and better than riding it to the end?
func _release_better(s0: Dictionary) -> bool:
	var drop := _fly(s0, false)
	if not drop.safe:
		return false
	var stay := _fly(s0, true)
	return not stay.safe or drop.score > stay.score + 1.0


## From a cable: hang on to the end (hang=true) or let go now, fly until the wheels
## touch down, then look for a way on (riding or follow-up jumps).
func _fly(s0: Dictionary, hang: bool) -> Dictionary:
	var s := _copy(s0)
	var got := {}
	var score := 0.0
	for i in 900:
		var was_air: bool = not s.grounded
		Phys.step(level, s, false, hang and int(s.zip) >= 0)
		if not s.alive:
			return {"safe": false, "score": score}
		if s.x >= level.finish_x:
			return {"safe": true, "score": score + 5.0}
		score += _collect(s, got)
		if was_air and s.grounded:
			var c := _continue(s, 1)
			return {"safe": c.safe, "score": score + c.score}
	return {"safe": false, "score": score}


## Ride with no input for n frames (extending to finish any flight).
func _ride(s0: Dictionary, n: int) -> Dictionary:
	var s := _copy(s0)
	var got := {}
	var score := 0.0
	var i := 0
	var limit := n
	var loop_exit = null
	while i < limit:
		var ev := Phys.step(level, s, false, false)
		i += 1
		if ev & Phys.EV_LOOP_OUT and loop_exit == null:
			loop_exit = _copy(s)
		if not s.alive:
			var r := {"safe": false, "score": score, "frames": i}
			if loop_exit != null:
				r.loop_exit = loop_exit
			return r
		if s.x >= level.finish_x:
			return {"safe": true, "score": score + 5.0, "frames": i}
		score += _collect(s, got)
		if i == limit and (not s.grounded or int(s.loop) >= 0) and limit < n + 200:
			limit += 1
	return {"safe": true, "score": score, "frames": i}


## Press now and hold for `hold` frames (and for as long as you hang on a cable),
## then judge the landing.
func _jump(s0: Dictionary, hold: int, depth: int) -> Dictionary:
	var s := _copy(s0)
	var got := {}
	var score := 0.0
	var i := 0
	var limit := horizon + 90
	while i < limit:
		var was_air: bool = not s.grounded
		var hanging := int(s.zip) >= 0
		if hanging:
			hold = 0  # decide() drops its hold counter on the cable, so mirror that
		var ev := Phys.step(level, s, i == 0, i < hold or hanging)
		if ev & Phys.EV_BONK:
			score -= 4.0  # a bonk is survivable but sloppy: prefer a clean tap
		if hanging and limit < 900:
			limit += 1
		if not s.alive:
			return {"safe": false, "score": score}
		if s.x >= level.finish_x:
			return {"safe": true, "score": score + 5.0}
		score += _collect(s, got)
		if i > 1 and was_air and s.grounded:
			if depth <= 1:
				var g := _ride(s, GRACE)
				return {"safe": g.safe, "score": score + g.score}
			var c := _continue(s, depth - 1)
			return {"safe": c.safe, "score": score + c.score}
		i += 1
	return {"safe": false, "score": score}


## From a landing: is there any way on? Ride on if that survives; otherwise look for a
## frame (latest first) where jumping again works.
func _continue(s0: Dictionary, depth: int) -> Dictionary:
	var ride := _ride(s0, horizon)
	if ride.safe:
		return ride
	var states := []
	var s := _copy(s0)
	for i in int(ride.frames) - 1:
		states.append(_copy(s))
		Phys.step(level, s, false, false)
		if not s.alive:
			break
	var k := states.size() - 1
	while k >= 0:
		var sk: Dictionary = states[k]
		if sk.grounded or sk.coyote > 0.0:
			for h in CONT_HOLDS:
				var r := _jump(sk, h, depth)
				if r.safe:
					return r
		k -= 2
	return {"safe": false, "score": 0.0}


func _collect(s: Dictionary, got: Dictionary) -> float:
	if not collect:
		return 0.0
	var br := Phys.bike_rect(s, level).grow(8.0)
	var sc := 0.0
	for pi in Phys.pickups_near(level, s.x):
		if got.has(pi):
			continue
		var p: Dictionary = level.pickups[pi]
		if p.alive and br.has_point(p.pos):
			got[pi] = true
			sc += 60.0 if int(p.type) == P_GEAR else float(p.value)
	return sc
