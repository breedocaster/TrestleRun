## Ghost runs for SUMMIT and GAUNTLET: a ride recorded as where the bike was drawn, 30
## times a second, so it plays back the same on any device (replaying the inputs through
## the physics would drift apart between processors over a minute and a half of a climb).
## Two kinds: your own best run on a level (user://, via GameState.save_ghost), and the
## GOLD LINE, the level checker's own winning ride on the scrambler, shipped with the
## game in assets/lines/ (written by --drive-levels --lines, README Dev checks).
extends RefCounted

## Record every RATE-th 1/60 s frame.
const RATE := 2
## Per frame: drawing origin x, y, angle, front wheel spin, trick pose (id + 0..0.99 of
## how far into it the rider is; 0 = riding).
const STRIDE := 5
const LINE_DIR := "res://assets/lines/"
## The gold line's rig (the checker rides the scrambler, the plain rider and paint).
const LINE_RIG := {"bike": "scrambler", "rider": "dusty", "paint": "stock"}


## One frame of a ride, appended to frames.
static func add_frame(frames: PackedFloat32Array, sim, pose := 0.0) -> void:
	var o: Vector2 = sim.world(sim.art)
	frames.append_array(PackedFloat32Array([o.x, o.y, float(sim.ang), float((sim.wheels[0] as Object).spin), pose]))


## The frame at time t (s), blended between the two recorded either side:
## {"pos", "ang", "spin", "pose"}, or {} past the end.
static func at(frames: PackedFloat32Array, t: float) -> Dictionary:
	var n := frames.size() / STRIDE
	if n == 0:
		return {}
	var f := t * 60.0 / RATE
	var i := int(f)
	if i >= n - 1:
		var k := (n - 1) * STRIDE
		return {"pos": Vector2(frames[k], frames[k + 1]), "ang": frames[k + 2], "spin": frames[k + 3],
			"pose": frames[k + 4], "end": true}
	var u := f - float(i)
	var a := i * STRIDE
	var b := a + STRIDE
	var pa := Vector2(frames[a], frames[a + 1])
	var pb := Vector2(frames[b], frames[b + 1])
	# A jump of more than a few px between frames is a respawn (GAUNTLET): don't slide.
	var pos := pb if pa.distance_to(pb) > 40.0 else pa.lerp(pb, u)
	return {"pos": pos, "ang": lerp_angle(frames[a + 2], frames[b + 2], u), "spin": frames[b + 3],
		"pose": frames[b + 4] if u > 0.5 else frames[a + 4]}


static func line_path(id: String) -> String:
	return LINE_DIR + id + ".bin"


## The gold line for a level: {"frames", "time", "rig", "up", "path", "hops"}, or {}.
static func load_line(id: String) -> Dictionary:
	var p := line_path(id)
	if not FileAccess.file_exists(p):
		return {}
	var f := FileAccess.open_compressed(p, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if f == null:
		return {}
	var v = f.get_var()
	return v if v is Dictionary and (v as Dictionary).has("frames") else {}


static func save_line(id: String, d: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(LINE_DIR))
	var f := FileAccess.open_compressed(line_path(id), FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if f:
		f.store_var(d)


## Your own best run on a level (user://ghost_drive_<id>.dat).
static func own_id(level_id: String) -> String:
	return "drive_" + level_id
