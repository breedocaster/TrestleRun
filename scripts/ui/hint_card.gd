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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var meta := Catalog.level(level_id)
	var feat: Array = Catalog.FEATURES.get(String(meta.get("feature", "jump")), ["", "", ""])
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.add_child(Kit.label("NEW ON TRAIL %d: %s" % [Catalog.level_index(level_id) + 1, String(meta.get("name", ""))], 8, UITheme.DIM))
	v.add_child(Kit.label(String(feat[0]), 16, UITheme.GOLD))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var demo := DemoView.new(level_id, String(meta.get("feature", "jump")))
	row.add_child(demo)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 3)
	text.custom_minimum_size = Vector2(212, 0)
	text.add_child(_head("WHAT IT IS"))
	text.add_child(_body(String(feat[1])))
	text.add_child(_head("HOW TO GET PAST IT"))
	text.add_child(_body(String(feat[2])))
	row.add_child(text)
	v.add_child(row)
	var ok := Kit.button("GOT IT", 110, 24)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(func(): closed.emit())
	v.add_child(ok)
	add_child(v)


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
		# Minimal autopilot: it only jumps when it has to, so it rolls into springs and
		# loops instead of hopping around for coins.
		var ap = Autopilot.new(world.level)
		ap.collect = false
		world.bot = ap
		world.run_finished.connect(func(_r): _spawn.call_deferred())
		vp.add_child(world)

	func _process(_delta: float) -> void:
		if world and world.cam:
			backdrop.cam = world.cam.position
