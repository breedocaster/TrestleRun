## Hint card for a trail's new feature: what it is, how to get past it, and a live
## demo of the autopilot riding a short loop of it. Opened from the "?" button.
extends PanelContainer

signal closed

const Catalog := preload("res://scripts/catalog.gd")
const Kit := preload("res://scripts/ui/kit.gd")
const UITheme := preload("res://scripts/ui/ui_theme.gd")
const Library := preload("res://scripts/game/level_library.gd")
const Layouts := preload("res://scripts/game/level_layouts.gd")
const World := preload("res://scripts/game/world.gd")
const Autopilot := preload("res://scripts/game/autopilot.gd")
const Backdrop := preload("res://scripts/game/backdrop.gd")

var level_id := ""


func _init(id: String) -> void:
	level_id = id


var _page := 0
var _box: VBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 4)
	add_child(_box)
	_show_page(0)


## One page per thing this trail introduces (main feature first).
func _show_page(i: int) -> void:
	_page = i
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()
	var meta := Catalog.level(level_id)
	var feats := Catalog.level_features(meta)
	var key := String(feats[i])
	var feat: Array = Catalog.FEATURES.get(key, ["", "", ""])
	var head := "NEW ON %s: %s" % [Catalog.level_label(level_id), String(meta.get("name", ""))]
	if feats.size() > 1:
		head += "  (%d/%d)" % [i + 1, feats.size()]
	_box.add_child(Kit.label(head, 8, UITheme.DIM))
	_box.add_child(Kit.label(String(feat[0]), 16, UITheme.GOLD))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(DemoView.new(level_id, key))
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 3)
	text.custom_minimum_size = Vector2(212, 0)
	text.add_child(_head("WHAT IT IS"))
	text.add_child(_body(String(feat[1])))
	var how := "HOW TO GET PAST IT"
	if key in ["trick", "switch"]:
		how = "HOW TO DO IT"
	elif key in ["magnet", "hat", "sticky", "rocket"]:
		how = "HOW TO USE IT"
	elif key == "chase":
		how = "HOW TO STAY AHEAD"
	elif key == "boss":
		how = "HOW TO BEAT IT"
	text.add_child(_head(how))
	text.add_child(_body(String(feat[2])))
	row.add_child(text)
	_box.add_child(row)
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 8)
	if i > 0:
		var back := Kit.button("< BACK", 80, 24)
		back.pressed.connect(func(): _show_page(i - 1))
		btns.add_child(back)
	if i < feats.size() - 1:
		var nxt := Kit.button("NEXT: %s >" % String(Catalog.FEATURES.get(String(feats[i + 1]), [""])[0]), 0, 24)
		nxt.pressed.connect(func(): _show_page(i + 1))
		btns.add_child(nxt)
	else:
		var ok := Kit.button("GOT IT", 110, 24)
		ok.pressed.connect(func(): closed.emit())
		btns.add_child(ok)
	_box.add_child(btns)


func _head(s: String) -> Label:
	return Kit.label(s, 8, UITheme.GOLD, HORIZONTAL_ALIGNMENT_LEFT)


func _body(s: String) -> Label:
	var l := Kit.label(s, 8, UITheme.CREAM, HORIZONTAL_ALIGNMENT_LEFT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(212, 0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	return l


## A small window onto a demo run: the autopilot rides the feature, then it restarts.
class DemoView extends SubViewportContainer:
	var level_id := ""
	var feature := ""
	var vp: SubViewport
	var world: Node2D
	var backdrop: Node2D

	func _init(id: String, feat: String) -> void:
		level_id = id
		feature = feat
		custom_minimum_size = Vector2(200, 116)
		stretch = true
		process_mode = Node.PROCESS_MODE_ALWAYS
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void:
		vp = SubViewport.new()
		vp.size = Vector2i(200, 116)
		vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		vp.snap_2d_transforms_to_pixel = true
		vp.snap_2d_vertices_to_pixel = true
		vp.handle_input_locally = false
		vp.gui_disable_input = true
		add_child(vp)
		var meta := Catalog.level(level_id)
		var bg := CanvasLayer.new()
		bg.layer = -10
		vp.add_child(bg)
		backdrop = Backdrop.new()
		backdrop.theme_index = int(meta.get("theme", 0))
		backdrop.time_mode = String(GameState.conditions().get("time", "dusk"))
		bg.add_child(backdrop)
		_spawn()

	func _spawn() -> void:
		if world:
			world.queue_free()
		var meta := Catalog.level(level_id)
		var lv: Dictionary = Library.build_layout(Layouts.DEMOS.get(feature, Layouts.DEMOS.jump),
			{"id": "demo", "name": "", "speed": meta.get("speed", 128.0), "theme": meta.get("theme", 0)})
		world = World.new()
		world.quiet = true
		world.bonus_planes = false
		var rig := GameState.loadout()
		rig["ability"] = {}
		world.setup("demo", rig, [], {"time": backdrop.time_mode, "weather": "clear"}, lv)
		if feature == "boss":
			world.boss_part = "headlight"
		# Minimal autopilot: it only jumps when it has to, so it rolls into springs and
		# loops instead of hopping around for coins.
		var ap = Autopilot.new(world.level)
		ap.collect = feature in ["sticky", "rocket", "magnet", "boss"]
		ap.tricks = feature == "trick"
		world.bot = ap
		if feature == "hat":
			world.bot = RideStraight.new()  # runs into the spiker so the hat can save it
		world.run_finished.connect(func(_r): _spawn.call_deferred())
		vp.add_child(world)

	func _process(_delta: float) -> void:
		if world and world.cam:
			backdrop.cam = world.cam.position


## Demo rider that never presses (shows the hard hat taking a hit).
class RideStraight extends RefCounted:
	func decide(_s: Dictionary) -> Array:
		return [false, false]
