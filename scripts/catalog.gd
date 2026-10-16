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


## ability: the bike's specialty (bike_physics). k: wheelie boost as a share of speed.
static func bikes() -> Array:
	if _bikes.is_empty():
		_bikes = [
			{"id": "scrambler", "name": "SCRAMBLER", "price": 0, "ability": "wheelie", "k": 0.10},
			{"id": "dirt", "name": "DIRT BIKE", "price": 150, "ability": "wheelie", "k": 0.14},
			{"id": "minibike", "name": "MINIBIKE", "price": 200, "ability": "hop"},
			{"id": "scooter", "name": "SCOOTER", "price": 250, "ability": "glide"},
			{"id": "cafe", "name": "CAFE RACER", "price": 350, "ability": "dash"},
			{"id": "chopper", "name": "CHOPPER", "price": 500, "ability": "tough"},
			{"id": "sport", "name": "SPORTBIKE", "price": 700, "ability": "wheelie", "k": 0.18},
		]
	return _bikes


## Specialty for physics: {"id", "k"}.
static func ability(bike_id: String) -> Dictionary:
	var b := item("bike", bike_id)
	return {"id": String(b.get("ability", "")), "k": float(b.get("k", 0.0))}


## [title, how-to] shown in the garage and the HUD.
static func ability_text(bike_id: String) -> Array:
	var b := item("bike", bike_id)
	match String(b.get("ability", "")):
		"wheelie":
			var pct := int(round(float(b.get("k", 0.1)) * 100.0))
			var title := "WHEELIE" if pct <= 10 else ("BIG WHEELIE" if pct <= 14 else "POWER WHEELIE")
			return ["%s +%d%%" % [title, pct], "KEEP HOLDING AS YOU LAND: FRONT WHEEL UP, SPEED BUILDS WHILE YOU HOLD"]
		"hop":
			return ["DOUBLE HOP", "TAP AGAIN IN THE AIR FOR ONE MORE HOP"]
		"glide":
			return ["UMBRELLA", "HOLD WHILE FALLING TO FLOAT DOWN SLOWLY"]
		"dash":
			return ["AIR DASH", "TAP IN THE AIR TO DASH FORWARD"]
		"tough":
			return ["IRON HIDE", "SMASH THROUGH ONE ENEMY PER CHECKPOINT"]
	return ["", ""]


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
## feature: the new thing this trail introduces (FEATURES).
static func levels() -> Array:
	if _levels.is_empty():
		_levels = [
			_lv("dusty_trail", "DUSTY TRAIL", 0, 118.0, 30, 0, "jump", ["trick"]),
			_lv("copper_canyon", "COPPER CANYON", 120, 122.0, 40, 1, "crawler", ["magnet"]),
			_lv("rustyard", "RUSTYARD", 220, 126.0, 50, 2, "spiker", ["switch"]),
			_lv("night_trestle", "NIGHT TRESTLE", 350, 130.0, 60, 3, "drone", ["hat"]),
			_lv("mesa_springs", "MESA SPRINGS", 500, 134.0, 70, 4, "spring"),
			_lv("lantern_mine", "LANTERN MINE", 650, 138.0, 80, 5, "tunnel"),
			_lv("hoodoo_loops", "HOODOO LOOPS", 820, 142.0, 90, 6, "loop"),
			_lv("hoist_yard", "HOIST YARD", 1000, 146.0, 100, 7, "lift"),
			_lv("skyline_pass", "SKYLINE PASS", 1250, 150.0, 120, 8, "zip"),
			_lv("quarry_cliffs", "QUARRY CLIFFS", 1500, 154.0, 130, 9, "sticky"),
			_lv("rocket_ridge", "ROCKET RIDGE", 1800, 156.0, 140, 10, "rocket"),
			_lv("last_trestle", "LAST TRESTLE", 2200, 158.0, 160, 11, "crumble", ["chase"]),
		]
	return _levels


static func _lv(id: String, name: String, price: int, speed: float, bonus: int, theme: int, feature: String,
		extra: Array = []) -> Dictionary:
	return {"id": id, "name": name, "price": price, "speed": speed, "bonus": bonus, "theme": theme, "feature": feature,
		"features": [feature] + extra, "music": MUSIC_BY_THEME[theme], "par": float(PARS.get(id, 0.0))}


## Gold-medal par times (seconds of riding): the dev bot's clean run plus a second,
## rounded up to the half second. Regenerate with --par after changing a layout.
const PARS := {
	"dusty_trail": 54.0,
	"copper_canyon": 53.0,
	"rustyard": 51.5,
	"night_trestle": 53.5,
	"mesa_springs": 61.0,
	"lantern_mine": 62.0,
	"hoodoo_loops": 66.5,
	"hoist_yard": 55.5,
	"skyline_pass": 77.5,
	"quarry_cliffs": 53.5,
	"rocket_ridge": 51.0,
	"last_trestle": 40.5,
}


## Music loop per trail: the theme, a slow minor one for dark trails, a quick one up high.
const MUSIC_BY_THEME := ["trestle_dreams", "trestle_dreams", "ridge_runner", "lantern_low", "trestle_dreams",
	"lantern_low", "trestle_dreams", "ridge_runner", "ridge_runner", "trestle_dreams", "ridge_runner", "ridge_runner"]


## Everything a trail introduces (main feature first), e.g. ["spiker", "switch"].
static func level_features(meta: Dictionary) -> Array:
	return meta.get("features", [meta.get("feature", "jump")])


## "SPIKERS + SWITCHES": short names of what a trail introduces.
static func feature_names(meta: Dictionary, sep := " + ") -> String:
	var out := []
	for f in level_features(meta):
		var e: Array = FEATURES.get(String(f), [""])
		out.append(String(e[3] if e.size() > 3 else e[0]))
	return sep.join(out)


## What each trail's new feature is and how to get past it (hint button).
const FEATURES := {
	"jump": ["JUMPING", "GAPS IN THE TRESTLE.",
		"TAP FOR A SHORT HOP, HOLD FOR A BIG JUMP. JUMP JUST BEFORE THE EDGE. COINS UP HIGH NEED A LONG HOLD."],
	"trick": ["TRICKS", "FLIPS FOR BONUS COINS ON BIG AIR: KICKERS, DROPS, SPRINGS, STOMPS.",
		"TAP IN THE AIR: RISING = BACKFLIP, FALLING = FRONT FLIP. IT ONLY FLIPS IF THERE'S AIR TO FINISH. TAP AGAIN MID-FLIP FOR ONE MORE, BUT LAND CROOKED AND YOU WOBBLE AND SLOW DOWN."],
	"switch": ["SWITCH TRACKS", "SIGNED RAMPS THAT SWING YOU ONTO A TRACK BEHIND OR IN FRONT.",
		"ROLL ONTO THE RAMP TO SWITCH, HOP OVER IT TO STAY. THE SIGN'S ARROW SHOWS WHERE IT GOES. THE STRIPED PLATE AT THE END MERGES YOU BACK.", "SWITCHES"],
	"magnet": ["COIN MAGNET", "A RED MAGNET THAT PULLS IN THE COINS AROUND YOU FOR 8 SECONDS.",
		"RIDE OR HOP THROUGH IT. COINS NEARBY FLY STRAIGHT TO YOU, EVEN ONES A JUMP AWAY. GEARS AND LETTERS YOU STILL HAVE TO GRAB.", "MAGNET"],
	"hat": ["HARD HAT", "A HELMET THAT TAKES ONE HIT FOR YOU.",
		"GRAB IT AND THE NEXT TIME YOU RUN INTO A CRITTER OR A SPIKER, THE HAT BREAKS INSTEAD OF YOU. IT WON'T SAVE YOU FROM A FALL.", "HARD HAT"],
	"sticky": ["STICKY TIRES", "GREEN GOO TIRES FOR 10 SECONDS: CLIMB STRAIGHT UP CLIFFS.",
		"GRAB THEM, THEN JUMP AT A CLIFF FACE WITH GREEN MARKS. YOU STICK AND DRIVE UP TO THE ROUTE ON TOP. NO TIRES? THE FACE BONKS YOU BACK: TAKE THE TUNNEL."],
	"rocket": ["ROCKET", "A 2.5 SECOND BURST OF SPEED THAT ALSO MAKES YOUR JUMPS HIGHER.",
		"GRAB IT BEFORE A STEEP RAMP. ROCKET + FULL JUMP AT THE LIP: TOP ROUTE. FULL JUMP ALONE: MIDDLE. A TAP OR NO JUMP: BOTTOM. EVERY ROUTE GETS YOU THROUGH."],
	"crumble": ["CRUMBLING PLANKS", "OLD GREY PLANKS THAT DROP AWAY A MOMENT AFTER YOUR WHEELS TOUCH THEM.",
		"SHORT ONES YOU CAN ROLL RIGHT ACROSS. LAND ON A LONG ONE AND HOP STRAIGHT OFF AGAIN BEFORE IT FALLS.", "CRUMBLE"],
	"chase": ["COLLAPSE", "THE WHOLE TRESTLE IS FALLING DOWN BEHIND YOU.",
		"KEEP YOUR SPEED UP. BONKS, SKETCHY LANDINGS AND HEADWIND LET THE COLLAPSE CATCH UP; CLEAN RIDING PULLS AWAY FROM IT.", "COLLAPSE"],
	"crawler": ["CRAWLERS", "SLOW CRITTERS PACING THE DECK: BEETLES, SCORPIONS, RUSTBOTS.",
		"LAND ON TOP TO STOMP ONE: YOU BOUNCE UP AND GET +2 COINS. HITTING ITS SIDE IS A CRASH. HOLD DURING THE BOUNCE TO GO HIGHER."],
	"spiker": ["SPIKERS", "CACTI, MINES AND CRYSTALS STUCK TO THE DECK. THEY CAN'T BE STOMPED.",
		"JUMP CLEAN OVER. A MEDIUM HOLD CLEARS ONE. FOR TWO IN A ROW, LAND BETWEEN THEM AND HOP AGAIN."],
	"drone": ["FLYERS", "VULTURES, DRONES AND BATS. THEY SWOOP IN FROM THE BACKGROUND: WATCH FOR THEIR SHADOW.",
		"STAY LOW AND RIDE UNDER. DON'T JUMP! OVER A GAP, USE A QUICK TAP SO YOU STAY BENEATH IT."],
	"spring": ["SPRINGS", "BOUNCE PADS THAT FLING YOU HIGH AND FAR.",
		"ROLL ONTO ONE TO REACH A HIGH DECK OR CLEAR A CANYON TOO WIDE TO JUMP. TO STAY LOW, HOP OVER THE PAD. LOOK UP FIRST: SOME HAVE DRONES ABOVE."],
	"tunnel": ["LOW CEILINGS", "MINE TUNNELS WITH A LOW ROOF.",
		"ONLY SHORT TAPS IN HERE. A BIG JUMP BONKS YOUR HEAD, SLOWS YOU DOWN AND DROPS YOU SHORT INTO THE PIT."],
	"loop": ["LOOP-THE-LOOP", "WOODEN LOOPS LINED WITH COINS.",
		"JUST KEEP ROLLING: THE LOOP CARRIES YOU ROUND. JUMPING RIGHT BEFORE IT SKIPS IT. GAP AT THE EXIT? PRESS AS YOU COME OUT."],
	"lift": ["LIFTS", "PLATFORMS BOBBING UP AND DOWN OVER A CHASM.",
		"WATCH THE RHYTHM. JUMP SO YOU COME DOWN ON THE NEXT LIFT, EASIEST WHILE IT'S LOW. DON'T ROLL OFF THE END: HOP ACROSS."],
	"zip": ["ZIPLINES", "CABLES STRUNG OVER CANYONS TOO WIDE TO JUMP.",
		"JUMP WITH A LONG HOLD TO GRAB THE CABLE AND KEEP HOLDING TO RIDE IT. LET GO OVER THE FAR DECK, OR RIDE TO THE END AND IT DROPS YOU OFF."],
}


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
