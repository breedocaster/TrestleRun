## Credits: required attributions (CC BY) plus courtesy credits for CC0 / public
## domain sources. Full details with links live in CREDITS.md.
extends Control

signal navigate(target: String, arg: String)

const Backdrop := preload("res://scripts/game/backdrop.gd")
const Kit := preload("res://scripts/ui/kit.gd")
const UITheme := preload("res://scripts/ui/ui_theme.gd")

const SECTIONS := [
	["MUSIC", [
		["TRESTLE DREAMS", "Original theme, composed and synthesized for this game"],
		["TRAIL LOOPS", "Lantern Low, Ridge Runner, Hayloft Shuffle, Coal Smoke, Windfall, County Fair, Saucer Stomp: the same band, original"],
	]],
	["ENGINES", [
		["ALL 7 BIKES", "Original physical models: real firing orders, synthesized"],
	]],
	["NATURE RECORDINGS", [
		["RAIN", "Rain recording by alex36917, freesound.org/s/524605, CC BY 4.0. Trimmed, looped, filtered"],
		["BIRDS", "kvgarlic, freesound.org/s/156826 (CC0)"],
		["CRICKETS", "Lisa Redfern, soundbible.com 2083 (public domain)"],
		["WIND", "felix.blume, freesound.org/s/217506 (CC0)"],
		["CREEK", "gluckose, freesound.org/s/333987 (CC0)"],
		["", "Edited versions via the Blanket app by Rafael Mardojai CM"],
	]],
	["SOUND EFFECTS", [
		["IMPACTS, UI CLICKS", "Kenney, kenney.nl (CC0)"],
		["CHIMES, WHOOSHES", "Original, synthesized for this game"],
		["TRAIN HORN, THUNDER", "Original, synthesized for this game"],
		["TRAIL BEDS", "Mine, yard, canyon, mountain wind, collapse, farm, orchard, speedway: original, synthesized"],
		["SPRINGS, BONKS, ZIPLINE, BIPLANE", "Original, synthesized for this game"],
	]],
	["FONT", [
		["PRESS START 2P", "CodeMan38, SIL Open Font License 1.1"],
	]],
]


func _ready() -> void:
	Kit.full_rect(self)
	theme = GameState.theme
	var bg := CanvasLayer.new()
	bg.layer = -10
	add_child(bg)
	var bd := Backdrop.new()
	bd.theme_index = 3
	bd.time_mode = "night"
	bd.cam = Vector2(2000, 0)
	bg.add_child(bd)
	var shade := Kit.full_rect(ColorRect.new())
	shade.color = Color(0.04, 0.02, 0.07, 0.55)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.add_child(Kit.top_bar("CREDITS", func(): navigate.emit("title", "")))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 3)
	for sec in SECTIONS:
		list.add_child(Kit.label(sec[0], 8, UITheme.GOLD, HORIZONTAL_ALIGNMENT_LEFT))
		for row in sec[1]:
			var h := HBoxContainer.new()
			var k := Kit.label(row[0], 8, UITheme.CREAM, HORIZONTAL_ALIGNMENT_LEFT)
			k.custom_minimum_size = Vector2(150, 0)
			k.vertical_alignment = VERTICAL_ALIGNMENT_TOP
			h.add_child(k)
			var v := Kit.label(row[1], 8, UITheme.DIM, HORIZONTAL_ALIGNMENT_LEFT)
			v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(v)
			list.add_child(h)
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, 4)
		list.add_child(gap)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.box(Color(UITheme.PANEL, 0.92), Color("5a4a6e"), 2, 6))
	panel.add_child(list)
	scroll.add_child(panel)
	Kit.pass_drags(panel)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)
	add_child(Kit.full_rect(Kit.margin(col, 8)))


func on_back() -> void:
	navigate.emit("title", "")
