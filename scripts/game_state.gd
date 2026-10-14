## Autoload: save data, wallet, unlocks, input map, shared font/theme.
extends Node

signal money_changed(amount: int)

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 2
const FONT_PATH := "res://assets/fonts/PressStart2P-Regular.woff"
const Catalog := preload("res://scripts/catalog.gd")
const UITheme := preload("res://scripts/ui/ui_theme.gd")

var data: Dictionary = {}
var font: Font
var theme: Theme


func _ready() -> void:
	_setup_input()
	font = _load_font()
	theme = UITheme.build(font)
	load_game()


# --- wallet ----------------------------------------------------------------

func money() -> int:
	return int(data.money)


func add_money(amount: int) -> void:
	data.money = money() + amount
	save_game()
	money_changed.emit(money())


func spend(amount: int) -> bool:
	if amount > money():
		return false
	data.money = money() - amount
	save_game()
	money_changed.emit(money())
	return true


# --- garage: riders, bikes, paint ------------------------------------------

func owns(kind: String, id: String) -> bool:
	return id in data[kind + "_owned"]


func equipped(kind: String) -> String:
	return String(data[kind])


func buy(kind: String, id: String) -> bool:
	if owns(kind, id):
		return true
	if not spend(int(Catalog.item(kind, id).price)):
		return false
	data[kind + "_owned"].append(id)
	data[kind] = id
	save_game()
	return true


func equip(kind: String, id: String) -> void:
	if owns(kind, id):
		data[kind] = id
		save_game()


## {"rider", "bike", "paint"} ids for BikeView.
func loadout() -> Dictionary:
	return {"rider": equipped("rider"), "bike": equipped("bike"), "paint": equipped("paint")}


# --- ride conditions -------------------------------------------------------

func conditions() -> Dictionary:
	return data.conditions


func set_condition(key: String, value: String) -> void:
	data.conditions[key] = value
	save_game()


# --- levels ----------------------------------------------------------------

func level_unlocked(id: String) -> bool:
	return id in data.levels_unlocked


func buy_level(id: String) -> bool:
	if level_unlocked(id):
		return true
	if not spend(int(Catalog.level(id).price)):
		return false
	data.levels_unlocked.append(id)
	save_game()
	return true


func level_record(id: String) -> Dictionary:
	if not data.levels.has(id):
		data.levels[id] = {"cleared": false, "gears": [false, false, false], "best_coins": 0}
	return data.levels[id]


## Pays out a finished run. Coins only bank on a clear; gears pay once each.
## Harder conditions (night, rain, wind) add a % on top of run coins.
func record_result(r: Dictionary) -> Dictionary:
	var id: String = r.level_id
	var rec := level_record(id)
	var meta := Catalog.level(id)
	var new_gears := 0
	var run_gears: Array = r.gears
	for i in run_gears.size():
		if run_gears[i] and not rec.gears[i]:
			rec.gears[i] = true
			new_gears += 1
	var first_clear := not bool(rec.cleared)
	rec.cleared = true
	rec.best_coins = maxi(int(rec.best_coins), int(r.coins))
	var pct := Catalog.condition_bonus(r.get("conditions", {}))
	var payout := {
		"coins": int(r.coins),
		"cond_pct": pct,
		"cond_pay": int(round(int(r.coins) * pct / 100.0)),
		"gear_pay": new_gears * Catalog.GEAR_VALUE,
		"new_gears": new_gears,
		"bonus": int(meta.bonus),
		"perfect": Catalog.PERFECT_BONUS if int(r.crashes) == 0 else 0,
		"first_clear": first_clear,
	}
	payout.total = payout.coins + payout.cond_pay + payout.gear_pay + payout.bonus + payout.perfect
	add_money(payout.total)
	return payout


func next_level_id(id: String) -> String:
	var i := Catalog.level_index(id)
	var ls := Catalog.levels()
	if i >= 0 and i + 1 < ls.size():
		return ls[i + 1].id
	return ""


# --- persistence -----------------------------------------------------------

func _defaults() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"money": 0,
		"rider_owned": ["dusty"],
		"rider": "dusty",
		"bike_owned": ["scrambler"],
		"bike": "scrambler",
		"paint_owned": ["stock"],
		"paint": "stock",
		"levels_unlocked": [Catalog.levels()[0].id],
		"levels": {},
		"conditions": {"time": "dusk", "weather": "clear"},
	}


func load_game() -> void:
	data = _defaults()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Save file unreadable; starting fresh.")
		return
	for k in parsed:
		data[k] = parsed[k]
	# v1 saves called paint "skin".
	if parsed.has("skins_owned"):
		data.paint_owned = parsed.skins_owned
		data.paint = parsed.get("skin", "stock")
		data.erase("skins_owned")
		data.erase("skin")
	data.version = SAVE_VERSION
	data.money = int(data.money)


func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Could not write save: %s" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify(data, "  "))


func reset_save() -> void:
	data = _defaults()
	save_game()
	money_changed.emit(money())


# --- setup -----------------------------------------------------------------

## Mapping events use device -1 (all devices); a default device of 0 would not match
## the mouse clicks Android synthesizes from touches (device -1), so taps wouldn't jump.
func _setup_input() -> void:
	if not InputMap.has_action("jump"):
		InputMap.add_action("jump", 0.3)
		for k in [KEY_SPACE, KEY_UP, KEY_W, KEY_Z]:
			var ev := InputEventKey.new()
			ev.device = -1
			ev.physical_keycode = k
			InputMap.action_add_event("jump", ev)
		var mb := InputEventMouseButton.new()
		mb.device = -1
		mb.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("jump", mb)
		var jb := InputEventJoypadButton.new()
		jb.device = -1
		jb.button_index = JOY_BUTTON_A
		InputMap.action_add_event("jump", jb)
	if not InputMap.has_action("pause"):
		InputMap.add_action("pause")
		for k in [KEY_ESCAPE, KEY_P]:
			var ev := InputEventKey.new()
			ev.device = -1
			ev.physical_keycode = k
			InputMap.action_add_event("pause", ev)
		var js := InputEventJoypadButton.new()
		js.device = -1
		js.button_index = JOY_BUTTON_START
		InputMap.action_add_event("pause", js)


func _load_font() -> Font:
	var f: FontFile = null
	if ResourceLoader.exists(FONT_PATH):
		f = load(FONT_PATH) as FontFile
	if f == null and FileAccess.file_exists(FONT_PATH):
		f = FontFile.new()
		if f.load_dynamic_font(FONT_PATH) != OK:
			f = null
	if f == null:
		push_warning("Pixel font missing; using engine fallback.")
		return ThemeDB.fallback_font
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	f.generate_mipmaps = false
	return f
