## Static game content: riders, bike models, paints, levels, ride conditions.
## Prices and bonuses are the main economy knobs.
extends RefCounted

const GEAR_VALUE := 25
const PERFECT_BONUS := 20
const STOMP_COINS := 2

## Garage categories. Save keys: "<kind>_owned" (list) and "<kind>" (equipped id).
const KINDS := ["rider", "bike", "paint"]

## Extra % on run coins for harder conditions.
const TIME_BONUS := {"day": 0, "dusk": 0, "night": 10}
const WEATHER_BONUS := {"clear": 0, "rain": 25, "wind": 25}

static var _riders: Array = []
static var _bikes: Array = []
static var _paints: Array = []
static var _levels: Array = []


static func riders() -> Array:
	if _riders.is_empty():
		_riders = [
			{"id": "dusty", "name": "DUSTY", "price": 0, "blurb": "Trail regular"},
			{"id": "granny", "name": "GRANNY GRIT", "price": 150, "blurb": "Scarf of fury"},
			{"id": "bandit", "name": "BANDIT", "price": 250, "blurb": "Masked raccoon"},
			{"id": "bones", "name": "BONES", "price": 300, "blurb": "Hair on fire"},
			{"id": "zorp", "name": "ZORP", "price": 400, "blurb": "Not from here"},
			{"id": "robo", "name": "ROBO-7", "price": 450, "blurb": "Factory reset"},
			{"id": "finn", "name": "FINN", "price": 600, "blurb": "Land shark"},
			{"id": "frosty", "name": "BIG FROSTY", "price": 800, "blurb": "Mountain yeti"},
		]
	return _riders


static func bikes() -> Array:
	if _bikes.is_empty():
		_bikes = [
			{"id": "scrambler", "name": "SCRAMBLER", "price": 0},
			{"id": "dirt", "name": "DIRT BIKE", "price": 150},
			{"id": "minibike", "name": "MINIBIKE", "price": 200},
			{"id": "scooter", "name": "SCOOTER", "price": 250},
			{"id": "cafe", "name": "CAFE RACER", "price": 350},
			{"id": "chopper", "name": "CHOPPER", "price": 500},
			{"id": "sport", "name": "SPORTBIKE", "price": 700},
		]
	return _bikes


static func paints() -> Array:
	if _paints.is_empty():
		_paints = [
			_paint("stock", "STOCK RED", 0, "c8323c", "7a1c2a", "f2d16b"),
			_paint("tan", "DESERT TAN", 120, "c9a26b", "7d5a36", "5a3a22"),
			_paint("midnight", "MIDNIGHT", 200, "2a2d3e", "15161f", "8fd3ff"),
			_paint("chrome", "CHROME", 300, "c9d1d9", "7f8a96", "ff6b4a"),
			_paint("swamp", "SWAMP GREEN", 400, "4e7a3a", "2c4722", "e3c25b"),
			_paint("flame", "HOT ROD", 600, "1e1a1f", "0d0b0e", "ff8a1f", true),
		]
	return _paints


static func items(kind: String) -> Array:
	match kind:
		"rider":
			return riders()
		"bike":
			return bikes()
	return paints()


static func item(kind: String, id: String) -> Dictionary:
	var list := items(kind)
	for it in list:
		if it.id == id:
			return it
	return list[0]


static func paint(id: String) -> Dictionary:
	return item("paint", id)


static func _paint(id: String, name: String, price: int, body: String, body_dark: String,
		accent: String, flames := false) -> Dictionary:
	return {
		"id": id, "name": name, "price": price, "flames": flames,
		"body": Color.html(body), "body_dark": Color.html(body_dark), "accent": Color.html(accent),
		"seat": Color.html("2a1e1e"), "frame": Color.html("3a3440"), "chrome": Color.html("c9d1d9"),
		"tire": Color.html("17121a"), "rim": Color.html("9aa3ad"), "engine": Color.html("6b6f78"),
	}


## speed: px/s. bonus: coins paid on every clear. theme: index into Backdrop themes.
static func levels() -> Array:
	if _levels.is_empty():
		_levels = [
			{"id": "dusty_trail", "name": "DUSTY TRAIL", "price": 0, "speed": 128.0, "bonus": 40, "theme": 0},
			{"id": "copper_canyon", "name": "COPPER CANYON", "price": 200, "speed": 136.0, "bonus": 60, "theme": 1},
			{"id": "rustyard", "name": "RUSTYARD", "price": 350, "speed": 144.0, "bonus": 80, "theme": 2},
			{"id": "night_trestle", "name": "NIGHT TRESTLE", "price": 550, "speed": 150.0, "bonus": 100, "theme": 3},
		]
	return _levels


static func level(id: String) -> Dictionary:
	for l in levels():
		if l.id == id:
			return l
	return {}


static func level_index(id: String) -> int:
	var ls := levels()
	for i in ls.size():
		if ls[i].id == id:
			return i
	return -1


static func condition_bonus(cond: Dictionary) -> int:
	return int(TIME_BONUS.get(cond.get("time", "dusk"), 0)) + int(WEATHER_BONUS.get(cond.get("weather", "clear"), 0))
