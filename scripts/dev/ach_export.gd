## Store kit for achievements (dev): renders every badge as a store icon and writes the
## files the stores take. Needs a display (run under xvfb-run, not --headless).
## Flags: --ach-export=<dir> [--ach-scale=1|2]
## Writes into <dir>:
##   play/<id>.png            512 x 512 icons (Play Console)
##   apple/<id>.png           1024 x 1024 icons (App Store Connect; opaque, circle-safe)
##   trestle-run-play-achievements.zip   Play Console > Achievements > Import achievements
##   game-center-achievements.csv        what to type into App Store Connect, one row each
##   achievements.csv                    the full list with ids, for your own records
extends Node

const AchList := preload("res://scripts/achievements.gd")
const Art := preload("res://scripts/ui/achievement_art.gd")

## Badges are drawn at their in-game pixel size (radius 10 per unit of scale) and blown
## up with hard edges, so the store icons look like the game.
var scale := 1
var out := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ach-export="):
			out = a.substr(13)
		elif a.begins_with("--ach-scale="):
			scale = int(a.substr(12))
	DirAccess.make_dir_recursive_absolute(out + "/play")
	DirAccess.make_dir_recursive_absolute(out + "/apple")
	var px := 20 * scale
	var vp := SubViewport.new()
	vp.size = Vector2i(px, px)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var canvas := Badge.new()
	canvas.r = 10.0 * scale
	vp.add_child(canvas)
	var meta_rows := PackedStringArray()
	var icon_rows := PackedStringArray()
	var gc_rows := PackedStringArray(["Achievement ID,Reference Name,Point Value,Hidden,Achievable More Than Once,Display Name,Pre-earned Description,Earned Description,Image"])
	var all_rows := PackedStringArray(["id,name,how,points,goal (0 = one step),play type,steps"])
	var order := 1
	for a in AchList.LIST:
		var id := String(a[0])
		canvas.id = id
		canvas.queue_redraw()
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)  # opaque: Apple rejects transparency
		var p := img.duplicate()
		p.resize(512, 512, Image.INTERPOLATE_NEAREST)
		p.save_png("%s/play/%s.png" % [out, id])
		var ap := img.duplicate()
		ap.resize(1024, 1024, Image.INTERPOLATE_NEAREST)
		ap.save_png("%s/apple/%s.png" % [out, id])
		var name := _title(String(a[1]))
		var how := _sentence(String(a[2]))
		var goal := int(a[4])
		# Play's import: no header row, no commas in names or descriptions.
		meta_rows.append("%s,%s,%s,%s,Revealed,%d,%d" % [name.replace(",", ""), how.replace(",", ""),
			"True" if goal > 0 else "False", str(goal) if goal > 0 else "", int(a[3]), order])
		icon_rows.append("%s,%s.png" % [name.replace(",", ""), id])
		gc_rows.append("%s%s,%s,%d,No,No,%s,%s,%s,apple/%s.png" % [AchList.GC_PREFIX, id, name, int(a[3]),
			_q(name), _q(how), _q(how), id])
		all_rows.append("%s,%s,%s,%d,%d,%s,%s" % [id, _q(name), _q(how), int(a[3]), goal,
			"incremental" if goal > 0 else "standard", str(goal) if goal > 0 else ""])
		order += 1
	_write(out + "/AchievementsMetadata.csv", meta_rows)
	_write(out + "/AchievementsIconMappings.csv", icon_rows)
	_write(out + "/game-center-achievements.csv", gc_rows)
	_write(out + "/achievements.csv", all_rows)
	var zip := ZIPPacker.new()
	zip.open(out + "/trestle-run-play-achievements.zip")
	for f in ["AchievementsMetadata.csv", "AchievementsIconMappings.csv"]:
		_zip_add(zip, f, FileAccess.get_file_as_bytes(out + "/" + f))
	for a in AchList.LIST:
		_zip_add(zip, String(a[0]) + ".png", FileAccess.get_file_as_bytes("%s/play/%s.png" % [out, a[0]]))
	zip.close()
	var total := 0
	for a in AchList.LIST:
		total += int(a[3])
	print("ACH_EXPORT %d achievements, %d points -> %s" % [AchList.LIST.size(), total, out])
	get_tree().quit()


func _zip_add(zip: ZIPPacker, name: String, bytes: PackedByteArray) -> void:
	zip.start_file(name)
	zip.write_file(bytes)
	zip.close_file()


func _write(path: String, rows: PackedStringArray) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("\n".join(rows) + "\n")
	f.close()


## The stores want normal capitals (Apple: "avoid all capitals"); the game's pixel font
## is caps only, so the list is written in caps.
static func _title(s: String) -> String:
	var small := ["A", "AN", "THE", "OF", "IN", "ON", "AT", "TO", "AND", "OR", "BY", "FOR"]
	var words := s.split(" ")
	for i in words.size():
		var w := words[i]
		if i > 0 and i < words.size() - 1 and w in small:
			words[i] = w.to_lower()
		else:
			words[i] = w.substr(0, 1) + w.substr(1).to_lower()
	return " ".join(words)


static func _sentence(s: String) -> String:
	var t := s.to_lower()
	t = t.substr(0, 1).to_upper() + t.substr(1)
	for k in ["grandpa", "t-r-e-s-t-l-e", "free ride", "last trestle", "golden spike"]:
		var cap := "T-R-E-S-T-L-E" if k == "t-r-e-s-t-l-e" else _title(k.to_upper())
		t = t.replace(k, cap)
	for k in ["scooper", "rail hog", "harvester", "spinner"]:
		t = t.replace("the " + k, "the " + _title(k.to_upper()))
	return t


static func _q(s: String) -> String:
	return "\"" + s.replace("\"", "\"\"") + "\""


class Badge extends Node2D:
	const ArtC := preload("res://scripts/ui/achievement_art.gd")
	const UIThemeC := preload("res://scripts/ui/ui_theme.gd")
	var id := ""
	var r := 10.0

	func _draw() -> void:
		draw_rect(Rect2(0, 0, r * 2.0, r * 2.0), UIThemeC.INK)
		ArtC.badge(self, Vector2(r, r), r, id, true, 0.0)
