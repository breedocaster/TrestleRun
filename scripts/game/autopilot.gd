## Lookahead autopilot: proves levels are beatable (dev verify) and rides the hint demos.
## Each frame it can jump it compares "keep riding" against a few hold lengths, rolling
## each forward with the real physics. A jump only counts as safe if, after landing,
## there is still some way to continue (ride on, or jump again at some later frame).
## On a zipline it keeps holding, and lets go early only when dropping off is safe
## and scores better (e.g. a gear on a lower deck).
extends RefCounted

const Phys := preload("res://scripts/game/bike_physics.gd")
const P_GEAR := 2
const P_LETTER := 3

const HOLDS := [3, 7, 12, 30]
const CONT_HOLDS := [4, 8, 14, 30]
const GRACE := 10

var level: Dictionary
var horizon := 66
var eval_every := 3
var collect := true
## Show off: tap for a flip in the air whenever it will land clean (hint demo, tour).
var tricks := false
var trace := Vector2(-1, -1)
## Dev stats: every press the bot was forced to make (riding on would crash).
var forced: Array = []
var _hold_left := 0
var _was_air := false
var _tick := 0
## Rope / rail / wall-ride: on grabbing one, plan when to let go (frames from the grab).
var _plan_key := ""
var _plan_i := 0
var _plan_k := 0


func _init(lvl: Dictionary) -> void:
	level = lvl


func decide(s: Dictionary) -> Array:
	_tick += 1
	if int(s.zip) >= 0:
		_hold_left = 0
		return [false, not _release_better(s)]
	var att := Phys.attachment(level, s)
	if att != "":
		_hold_left = 0
		return [false, _plan_hold(s, att)]
	_plan_key = ""
	if _hold_left > 0 and s.grounded and _was_air:
		_hold_left = 0  # touched down: the jump's done, plan afresh (as the sims assume)
	_was_air = not s.grounded
	if tricks and not s.grounded and int(s.flip_dir) == 0 and float(s.coyote) <= 0.0 \
			and _tick % 2 == 0 and _clean_flip(s):
		var h := _hold_left > 0
		if h:
			_hold_left -= 1  # this frame is part of the planned hold, as _clean_flip assumed
		return [true, h]
	if _hold_left > 0:
		_hold_left -= 1
		return [false, true]
	if not s.grounded and s.coyote <= 0.0:
		return [false, Phys.auto_hold(level, s)]
	var route := _route_hint(s)
	if route == 1:
		_hold_left = 29  # full jump: off a three-way ramp's lip, or at a climbable face
		return [true, true]
	var base := _ride(s, horizon)
	if route == -1 and (base.safe or _wait_then_jump(s)):
		return [false, Phys.auto_hold(level, s)]  # hold off: a ramp or a cliff face is coming up
	if not base.safe and base.has("loop_exit"):
		# Trouble only after a loop: ride the loop and jump on the way out.
		var after := _continue(base.loop_exit, 2)
		if after.safe:
			base = {"safe": true, "score": float(base.score) + float(after.score)}
	if base.safe and (not collect or _tick % eval_every != 0):
		return [false, Phys.auto_hold(level, s)]  # (as _ride assumed: e.g. coyote frames off a wall)
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
		print("TRACE x=%.1f y=%.1f tr=%d g=%s base=%s pick=%d %s" % [s.x, s.y, int(s.track), s.grounded, base.safe, best_opt, log])
	if best_opt > 0:
		if not base.safe:
			forced.append({"x": s.x, "t": s.t, "hold": best_opt})
		_hold_left = best_opt - 1
		return [true, true]
	return [false, Phys.auto_hold(level, s)]


## Would a tap now start a flip that lands clean, with a safe way on afterwards?
func _clean_flip(s0: Dictionary) -> bool:
	var s := _copy(s0)
	var held := _hold_left > 0
	for i in 400:
		var ev: int = Phys.step(level, s, i == 0, (held and i < _hold_left) or Phys.auto_hold(level, s))
		if not s.alive or (ev & Phys.EV_SKETCHY):
			return false
		if i == 0 and not (ev & Phys.EV_FLIP):
			return false
		if s.grounded:
			return (ev & Phys.EV_TRICK) != 0 and _continue(s, 2).safe
	return false


## Riding on to the route-hint spot and jumping there works out (a hazard after the
## ramp or inside the cliff tunnel makes plain riding look unsafe, but we won't ride).
func _wait_then_jump(s0: Dictionary) -> bool:
	var s := _copy(s0)
	for i in 120:
		if (s.grounded or float(s.coyote) > 0.0) and _route_hint(s) == 1:
			return _jump(s, 30, 2).safe
		Phys.step(level, s, false, Phys.auto_hold(level, s))
		if not s.alive:
			return false
	return false


## Dev-bot route sense the lookahead can't see on its own: with the rocket lit, ride
## to the lip of a three-way ramp and jump there (1); with sticky tires, don't hop
## around in the run-up to a climbable face (-1) so the climb jump is still possible.
func _route_hint(s: Dictionary) -> int:
	if not collect:
		return 0
	if float(s.rocket_t) > 0.0:
		for r in level.get("ramps", []):
			if int(r.lane) != int(s.lane):
				continue
			var d: float = float(r.x) - float(s.x)
			if d >= 0.0 and d <= 16.0:
				return 1
			if d > 12.0 and d < 320.0:
				return -1
	# A spring pad just ahead is a high road: ride onto it (if that's safe).
	for sp in level.get("springs", []):
		var ds: float = float(sp.x) - float(s.x)
		if int(sp.lane) == int(s.lane) and int(sp.track) == int(s.track) and ds > 0.0 and ds < 120.0:
			return -1
	if float(s.sticky_t) > 0.0:
		for w in level.get("walls", []):
			var d: float = float(w.x) - float(s.x)
			if int(w.lane) != int(s.lane):
				continue
			if d >= 50.0 and d <= 62.0:
				return 1  # full jump from here meets the face mid-height
			if d > 62.0 and d < 260.0:
				return -1
	return 0


func _copy(s0: Dictionary) -> Dictionary:
	return Phys.copy_state(s0)


## A fresh "already collected" record for a simulation starting from s0.
func _got0(s0: Dictionary) -> Dictionary:
	return {"bh": int(s0.boss_hits)}


## On a rope, rail or wall-ride: keep holding until the planned release frame.
func _plan_hold(s: Dictionary, att: String) -> bool:
	var key := "%s:%d" % [att, int(s.rope) if att == "rope" else int(s.track)]
	if key != _plan_key:
		_plan_key = key
		_plan_i = 0
		_plan_k = _make_plan(s, att)
	_plan_i += 1
	return _plan_i <= _plan_k


## Try letting go every few frames (and, on a rail or wall, holding to the end); keep
## the best one that lands safely with a way on. Ropes have no "hold forever".
func _make_plan(s0: Dictionary, att: String) -> int:
	var hold_end := -1
	var kmax := 110
	if att != "rope":
		var tr: Dictionary = level.tracks[s0.track]
		hold_end = int(ceil((float(tr.x1) - float(s0.x)) / maxf(float(s0.vx), 1.0) / Phys.DT)) + 2
		kmax = hold_end
	var dflt := hold_end if hold_end >= 0 else _rope_default(s0)
	var best_k := dflt
	var best_score := -INF
	var ks := []
	var k := 0
	while k < kmax:
		ks.append(k)
		k += 4
	ks.append(dflt)
	for kk in ks:
		var r := _release_at(s0, int(kk))
		if not r.safe:
			continue
		var sc := float(r.score) + (1.0 if int(kk) == dflt else 0.0)
		if sc > best_score:
			best_score = sc
			best_k = int(kk)
	if s0.x >= trace.x and s0.x <= trace.y:
		print("TRACE plan %s at x=%.1f -> release at %d (score %.1f)" % [att, s0.x, best_k, best_score])
	return best_k


## Frames until the simulation's rope rule (forward swing past ROPE_REL) lets go.
func _rope_default(s0: Dictionary) -> int:
	var s := _copy(s0)
	for i in 160:
		if not Phys.auto_hold(level, s):
			return i
		Phys.step(level, s, false, true)
		if int(s.rope) < 0:
			return i
	return 160


## Hold for k frames, then let go and play it out until the wheels are on a plain deck.
func _release_at(s0: Dictionary, k: int) -> Dictionary:
	var s := _copy(s0)
	var got := _got0(s0)
	var score := 0.0
	for i in 700:
		var h: bool = true if i < k else Phys.auto_hold(level, s)
		if i == k:
			h = false
		Phys.step(level, s, false, h)
		if not s.alive:
			return {"safe": false, "score": score}
		if s.x >= level.finish_x:
			return {"safe": true, "score": score + 5.0}
		score += _collect(s, got)
		if i >= k and s.grounded and Phys.attachment(level, s) == "":
			if float(s.x) < float(s0.x) + 20.0:
				return {"safe": false, "score": score}  # swung back to where we came from: no progress
			var c := _continue(s, 1)
			return {"safe": c.safe, "score": score + c.score}
	return {"safe": false, "score": score}


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
	var got := _got0(s0)
	var score := 0.0
	for i in 900:
		var was_air: bool = not s.grounded or Phys.attachment(level, s) != ""
		Phys.step(level, s, false, (hang and int(s.zip) >= 0) or (int(s.zip) < 0 and Phys.auto_hold(level, s)))
		if not s.alive:
			return {"safe": false, "score": score}
		if s.x >= level.finish_x:
			return {"safe": true, "score": score + 5.0}
		score += _collect(s, got)
		if was_air and s.grounded and Phys.attachment(level, s) == "":
			var c := _continue(s, 1)
			return {"safe": c.safe, "score": score + c.score}
	return {"safe": false, "score": score}


## Ride with no input for n frames (extending to finish any flight).
func _ride(s0: Dictionary, n: int) -> Dictionary:
	var s := _copy(s0)
	var got := _got0(s0)
	var score := 0.0
	var i := 0
	var limit := n
	var loop_exit = null
	while i < limit:
		var ev := Phys.step(level, s, false, Phys.auto_hold(level, s))
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
		if i == limit and (not s.grounded or int(s.loop) >= 0 or Phys.attachment(level, s) != "") and limit < n + 200:
			limit += 1
	return {"safe": true, "score": score, "frames": i}


## Press now and hold for `hold` frames (and for as long as you hang on a cable),
## then judge the landing.
func _jump(s0: Dictionary, hold: int, depth: int) -> Dictionary:
	var s := _copy(s0)
	var got := _got0(s0)
	var score := 0.0
	var i := 0
	var limit := horizon + 90
	var flew := false
	while i < limit:
		var hanging := int(s.zip) >= 0
		var att := Phys.attachment(level, s)
		if not s.grounded or att != "":
			flew = true
		if hanging or att != "":
			hold = 0  # decide() drops its hold counter on a cable/rope/rail, so mirror that
		var ev := Phys.step(level, s, i == 0, i < hold or hanging or Phys.auto_hold(level, s))
		if ev & Phys.EV_BONK:
			score -= 4.0  # a bonk is survivable but sloppy: prefer a clean tap
		if (hanging or att != "") and limit < 900:
			limit += 1
		if not s.alive:
			return {"safe": false, "score": score}
		if s.x >= level.finish_x:
			return {"safe": true, "score": score + 5.0}
		score += _collect(s, got)
		if i > 1 and flew and s.grounded and Phys.attachment(level, s) == "":
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
		Phys.step(level, s, false, Phys.auto_hold(level, s))
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
	for pi in Phys.pickups_near(level, s.x, int(s.lane)):
		if got.has(pi):
			continue
		var p: Dictionary = level.pickups[pi]
		if p.alive and br.has_point(p.pos):
			got[pi] = true
			match int(p.type):
				P_GEAR:
					sc += 60.0
				P_LETTER:
					sc += 40.0
				_:
					sc += float(p.value)
	# Power-ups picked up on the way (the physics records them in s.got).
	for k in s.got:
		if not got.has(-1 - int(k)):
			got[-1 - int(k)] = true
			sc += 12.0
	# Boss hits are what the arena is for.
	if got.has("bh") and int(s.boss_hits) > int(got.bh):
		sc += 90.0 * float(int(s.boss_hits) - int(got.bh))
		got["bh"] = int(s.boss_hits)
	return sc
