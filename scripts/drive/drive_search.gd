## Proves a stretch of a course can be ridden: a beam search over gas / coast / brake
## (held for 0.1 s at a time) from a start point to a target x, with the same sim the
## game uses. Keeps the states that got furthest (a few per 3 px, so the beam doesn't
## collapse onto one line) plus some slower ones, since some obstacles need a careful
## approach. Returns the inputs, so a winning run can be replayed or drawn.
extends RefCounted

const Vehicles := preload("res://scripts/drive/vehicles.gd")

const BLOCK := 6
const ACTIONS := [Vector2(1, 0), Vector2(0, 0), Vector2(0, 1)]


static func fell(level: Dictionary, s) -> bool:
	# Below the level's kill line (drive_world.gd ends the ride there too): without
	# this, a bike that dropped through a pit's floor kept "riding" in free fall.
	if s.pos.y > float(level.get("kill_y", 3000.0)):
		return true
	# Well under the ground surface: it went through something.
	var top: float = level.terrain.top_at(s.pos.x)
	if is_finite(top) and s.pos.y > top + 60.0:
		return true
	for g in level.get("gaps", []):
		if s.pos.x > float(g[0]) and s.pos.x < float(g[1]) and s.pos.y > float(g[2]) + 70.0:
			return true
	return false


static func start_sim(level: Dictionary, bike: String, x: float, up := {}, lean_k := 1.0):
	var t = level.terrain
	var s = Vehicles.build(bike, t, up, String(level.get("mode", "summit")))
	s.lean_ground *= lean_k
	var a := atan2(t.top_at(x + 8.0) - t.top_at(x - 8.0), 16.0)
	s.place(Vector2(x, t.top_at(x)), a)
	return s


## {"ok", "frames" (to reach target), "best_x", "path" (action per block), "end" (the
## sim's saved state at the target, to carry on from)}. from: a saved state to start
## from instead of standing at x0 (chaining a course's sections).
static func solve(level: Dictionary, bike: String, x0: float, target: float, beam := 24,
		max_s := 40.0, up := {}, lean_k := 1.0, from = null) -> Dictionary:
	var s = start_sim(level, bike, x0, up, lean_k)
	if from != null:
		s.load_state(from)
	var nodes := [{"s": s.save(), "x": s.pos.x, "v": 0.0, "path": PackedByteArray()}]
	var best_x: float = s.pos.x
	var steps := int(max_s * 60.0 / BLOCK)
	for st in steps:
		var kids := []
		for n in nodes:
			for ai in ACTIONS.size():
				s.load_state(n.s)
				var ok := true
				var act: Vector2 = ACTIONS[ai]
				for f in BLOCK:
					s.gas = act.x
					s.brake = act.y
					s.step()
					if s.crashed or fell(level, s):
						ok = false
						break
				if not ok:
					continue
				var path: PackedByteArray = (n.path as PackedByteArray).duplicate()
				path.append(ai)
				best_x = maxf(best_x, s.pos.x)
				if s.pos.x >= target and s.grounded:
					return {"ok": true, "frames": (st + 1) * BLOCK, "best_x": s.pos.x, "path": path, "end": s.save()}
				kids.append({"s": s.save(), "x": s.pos.x, "v": s.speed(), "path": path})
		if kids.is_empty():
			return {"ok": false, "frames": st * BLOCK, "best_x": best_x, "path": PackedByteArray()}
		nodes = _select(kids, beam)
	return {"ok": false, "frames": steps * BLOCK, "best_x": best_x, "path": PackedByteArray()}


## Ranks by where each state will be a moment from now (x + 0.35 s of its speed), not
## where it is: a unicycle has to roll back a touch to lean forward before it goes, so
## ranking by x alone pruned every gas start.
static func _select(kids: Array, beam: int) -> Array:
	for k in kids:
		k.score = float(k.x) + 0.35 * float(k.v)
	kids.sort_custom(func(a, b): return float(a.score) > float(b.score))
	var out := []
	var bins := {}
	var fast := int(beam * 0.7)
	for k in kids:
		var b := int(float(k.score) / 3.0)
		if int(bins.get(b, 0)) >= 2:
			continue
		bins[b] = int(bins.get(b, 0)) + 1
		out.append(k)
		if out.size() >= fast:
			break
	# A few slower ones from near the front, for obstacles that want a careful run-in.
	var front := float(kids[0].x)
	var slow := kids.filter(func(k): return float(k.x) > front - 80.0 and not out.has(k))
	slow.sort_custom(func(a, b): return absf(float(a.v)) < absf(float(b.v)))
	for k in slow:
		if out.size() >= beam:
			break
		out.append(k)
	return out


## Replay a path from x0 (for drawing a ghost or checking a stored solution).
static func replay(level: Dictionary, bike: String, x0: float, path: PackedByteArray, up := {}) -> Array:
	var s = start_sim(level, bike, x0, up)
	var trace := []
	for ai in path:
		var act: Vector2 = ACTIONS[ai]
		for f in BLOCK:
			s.gas = act.x
			s.brake = act.y
			s.step()
			trace.append([s.pos, s.ang])
	return trace
