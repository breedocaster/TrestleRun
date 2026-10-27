## A rider for the checkers and screenshots: full gas, easing off or braking to keep
## the nose from coming up too far, and in the air pitching to match the ground it's
## about to land on. Good enough to show a course can be done; GAUNTLET's checker
## searches inputs instead (drive_search.gd).
extends RefCounted

var careful := 0.55   # rad of nose-up it allows on the ground before backing off


func control(w) -> Vector2:
	var s = w.sim
	var t = w.level.terrain
	var x: float = s.pos.x
	# Slope of the ground just ahead (rad, negative = climbing to the right).
	var a := atan2(t.top_at(x + 14.0) - t.top_at(x - 6.0), 20.0)
	if t.top_at(x + 14.0) == INF or t.top_at(x - 6.0) == INF:
		a = 0.0
	var rel: float = s.ang - a   # nose up relative to the ground is negative
	if s.grounded:
		if rel < -careful - 0.25:
			return Vector2(0.0, 1.0)
		if rel < -careful:
			return Vector2(0.0, 0.0)
		return Vector2(1.0, 0.0)
	# Airborne: line up with what's below. Gas tips the nose up, brake down.
	var below := atan2(t.top_at(x + 30.0) - t.top_at(x - 10.0), 40.0)
	if t.top_at(x + 30.0) == INF:
		below = 0.0
	var d: float = s.ang - below
	if d < -0.18:
		return Vector2(0.0, 1.0)
	if d > 0.18:
		return Vector2(1.0, 0.0)
	return Vector2(0.4, 0.0)
