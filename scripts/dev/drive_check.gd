## --drive-physics: the vehicle sim on test ground, for every bike. Prints how each
## one sits still, gets going, climbs, lands a drop, brakes and (unicycles) balances,
## so tuning changes show up as numbers.
##   --bike=<id> one bike only   --frames  dump a few positions per test
extends Node

const Terrain := preload("res://scripts/drive/terrain.gd")
const Vehicles := preload("res://scripts/drive/vehicles.gd")
const Catalog := preload("res://scripts/catalog.gd")


func _flat(len := 6000.0) -> RefCounted:
	var t = Terrain.new()
	t.add_polyline(PackedVector2Array([Vector2(-200, 0), Vector2(len, 0)]))
	return t


## Flat run-up, then a slope of `deg` degrees for `rise` px up, then flat.
func _slope(deg: float, rise := 260.0) -> RefCounted:
	var t = Terrain.new()
	var run := rise / tan(deg_to_rad(deg))
	t.add_polyline(PackedVector2Array([Vector2(-200, 0), Vector2(300, 0), Vector2(300 + run, -rise),
		Vector2(300 + run + 2000, -rise)]))
	return t


## A ledge: flat at -h, drops to 0 at x=400.
func _ledge(h: float) -> RefCounted:
	var t = Terrain.new()
	t.add_polyline(PackedVector2Array([Vector2(-200, -h), Vector2(400, -h), Vector2(400, 0), Vector2(3000, 0)]))
	return t


func _run(s, frames: int, gas: float, brake: float) -> Dictionary:
	var maxv := 0.0
	var max_pitch := 0.0
	var min_pitch := 0.0
	var crashed_at := -1
	var hard := 0.0
	for f in frames:
		s.gas = gas
		s.brake = brake
		s.step()
		maxv = maxf(maxv, s.speed())
		max_pitch = maxf(max_pitch, s.ang)
		min_pitch = minf(min_pitch, s.ang)
		hard = maxf(hard, s.landed_hard)
		if s.crashed and crashed_at < 0:
			crashed_at = f
	return {"maxv": maxv, "nose_up": -min_pitch, "nose_down": max_pitch, "crash": crashed_at, "x": s.pos.x,
		"y": s.pos.y, "v": s.speed(), "hard": hard}


func _ready() -> void:
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--bike="):
			only = a.substr(7)
	var ids := []
	for b in Catalog.bikes():
		ids.append(String(b.id))
	for id in Vehicles.SPEC:
		if not id in ids:
			ids.append(id)
	for id in ids:
		if only != "" and id != only:
			continue
		var line := "%-10s" % id
		# Rest: 3 s, no input. How far did it sink / roll, is it still upright?
		var s = Vehicles.build(id, _flat())
		s.place(Vector2(0, 0))
		var r := _run(s, 180, 0.0, 0.0)
		var sink: float = s.world(s.art).y   # the art origin should sit at ground level
		line += " rest: sink %.2f ang %.3f v %.1f%s" % [sink, s.ang, s.vel.length(), " CRASH" if r.crash >= 0 else ""]
		# Full gas on the flat for 5 s.
		s = Vehicles.build(id, _flat())
		s.place(Vector2(0, 0))
		var t150 := -1.0
		for f in 300:
			s.gas = 1.0
			s.step()
			if t150 < 0.0 and s.speed() >= 150.0:
				t150 = f / 60.0
			if s.crashed:
				break
		r = _run(s, 1, 1.0, 0.0)
		line += " | gas: 0-150 %.2fs top %.0f%s" % [t150, r.maxv, " CRASH" if s.crashed else ""]
		# Wheelie check: full gas from a standstill, how far does the nose come up?
		s = Vehicles.build(id, _flat())
		s.place(Vector2(0, 0))
		r = _run(s, 120, 1.0, 0.0)
		line += " nose %.0f°%s" % [rad_to_deg(r.nose_up), " FLIP" if r.crash >= 0 else ""]
		# Brake from speed.
		s = Vehicles.build(id, _flat())
		s.place(Vector2(0, 0))
		_run(s, 150, 1.0, 0.0)
		var x0: float = s.pos.x
		var v0: float = s.speed()
		var stop_f := -1
		var nd := 0.0
		for f in 240:
			s.gas = 0.0
			s.brake = 1.0
			s.step()
			nd = maxf(nd, s.ang)
			if s.speed() < 2.0:
				stop_f = f
				break
		line += " | brake %.0f->0 in %.0fpx nose-down %.0f°%s" % [v0, s.pos.x - x0, rad_to_deg(nd), " CRASH" if s.crashed else ""]
		print(line)
		# Climbs.
		var cl := "%-10s climb:" % ""
		for deg in [15.0, 25.0, 35.0, 45.0]:
			s = Vehicles.build(id, _slope(deg))
			s.place(Vector2(0, 0))
			r = _run(s, 600, 1.0, 0.0)
			var top: bool = s.pos.y < -240.0
			cl += " %d°:%s" % [int(deg), ("ok" if top else "stuck@%.0f" % (-s.pos.y)) + ("/crash" if r.crash >= 0 else "")]
		# Drop off a ledge at speed, gas held.
		for h in [40.0, 80.0, 140.0]:
			s = Vehicles.build(id, _ledge(h))
			s.place(Vector2(0, -h))
			r = _run(s, 360, 1.0, 0.0)
			cl += " drop%d:%s(%.0f)" % [int(h), "crash" if r.crash >= 0 else "ok", r.hard]
		print(cl)
	print("DRIVE_PHYSICS done")
	get_tree().quit()
