## Autoload: every sound goes through here. Owns the buses, the theme, the engine
## (idle/cruise crossfade with RPM pitch and a rev flare in the air), the deck roll,
## ambience layers for time of day / weather, and a pool of one-shot SFX players.
extends Node

const DIR := "res://assets/audio/"
const COIN_STEPS := [0, 2, 5, 7, 9, 12]  # D major pentatonic ladder from A5

# Bus levels (dB). The assets are loudness-normalised, so these set the mix.
# Measured in real gameplay captures (Movie Maker, each bus soloed) to land near:
# engine -24, theme -24, chimes/SFX -22, nature bed -32 LUFS; about -18 LUFS overall.
const MUSIC_MENU_DB := -3.0
const MUSIC_GAME_DB := -5.0
const ENGINE_DB := -6.0
const AMBIENCE_DB := 1.0
const SFX_MENU_DB := -2.0
const SFX_GAME_DB := -7.0

# time/weather -> {ambience file: dB}
const TIME_LAYERS := {
	"day": {"day_birds": 0.0},
	"dusk": {"night_crickets": -3.0, "day_birds": -12.0},
	"night": {"night_crickets": 0.0},
}
## Each trail's own bed on top of the time-of-day layer. -60 mutes a time layer there.
const LEVEL_LAYERS := {
	"copper_canyon": {"canyon": -3.0, "creek": -9.0},
	"rustyard": {"yard": -2.0, "day_birds": -14.0},
	"night_trestle": {"night_crickets": -1.0, "canyon": -12.0},
	"mesa_springs": {"creek": -4.0},
	"lantern_mine": {"mine": 0.0, "day_birds": -60.0, "night_crickets": -16.0},
	"hoodoo_loops": {"canyon": -4.0},
	"hoist_yard": {"yard": 0.0, "day_birds": -60.0},
	"skyline_pass": {"alpine": -2.0, "day_birds": -12.0, "night_crickets": -60.0},
	"quarry_cliffs": {"canyon": -6.0, "yard": -12.0},
	"rocket_ridge": {"yard": -9.0, "canyon": -9.0, "day_birds": -14.0},
	"last_trestle": {"collapse": -3.0, "canyon": -6.0, "day_birds": -60.0},
	# Story areas (v0.8.2): farm wind chimes and windmill, the rail yard, orchard leaves
	# and an owl, the speedway crowd.
	"s1_hayfield": {"farm": -2.0},
	"s1_clothesline": {"farm": -2.5},
	"s1_powerlines": {"farm": -2.5},
	"s1_boss": {"farm": -6.0},
	"s2_siding": {"yard": -2.0, "day_birds": -14.0},
	"s2_chutes": {"yard": -2.0},
	"s2_roundhouse": {"yard": 0.0, "night_crickets": -10.0},
	"s2_boss": {"yard": -5.0, "night_crickets": -14.0},
	"s3_apple_row": {"orchard": 0.0},
	"s3_creek": {"orchard": -3.0, "creek": -5.0},
	"s3_hollow_oak": {"orchard": -1.0},
	"s3_boss": {"orchard": -5.0},
	"s4_fairgrounds": {"speedway": 0.0, "day_birds": -10.0},
	"s4_drome": {"speedway": -1.0},
	"s4_grandstand": {"speedway": 0.0, "night_crickets": -12.0},
	"s4_boss": {"speedway": -4.0, "night_crickets": -14.0},
}

var music: AudioStreamPlayer
var _track := "trestle_dreams"
var _menu_req := 0
var eng_idle: AudioStreamPlayer
var eng_cruise: AudioStreamPlayer
var deck: AudioStreamPlayer
var zip: AudioStreamPlayer
var plane: AudioStreamPlayer
var grind: AudioStreamPlayer
var saucer: AudioStreamPlayer
var coin_voices: Array = []
var _coin_voice := 0
var amb := {}
var pool: Array = []
var _next := 0
var _cache := {}
var _tweens := {}

var _engine_on := false
var _riding := false
var _ride_mix := 0.0
var _air := 0.0
var _launch := 0.0
var _speed_ratio := 1.0
var _grounded := true
var _wind_layer := false
var _coin_step := -1
var _coin_time := -10.0
var _preview_t := -1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	music = _player("Music", Node.PROCESS_MODE_ALWAYS)
	music.stream = _stream("music/trestle_dreams.ogg", true)
	eng_idle = _player("Engine")
	eng_cruise = _player("Engine")
	deck = _player("SFX")
	deck.stream = _stream("sfx/deck_roll.ogg", true)
	zip = _player("SFX")
	zip.stream = _stream("sfx/zipline.ogg", true)
	plane = _player("SFX")
	plane.stream = _stream("sfx/plane.ogg", true)
	grind = _player("SFX")
	saucer = _player("SFX")
	saucer.stream = _stream("sfx/saucer.ogg", true)
	for i in 10:
		pool.append(_player("SFX"))
	for i in 2:
		var cp := _player("SFX")
		cp.stream = _stream("sfx/coin.ogg")
		coin_voices.append(cp)
	apply_settings()
	set_context("menu")
	if not _is_headless():
		music.play()


func _is_headless() -> bool:
	return DisplayServer.get_name() == "headless"


# --- setup ---------------------------------------------------------------------

## Bus tree: Music -> MusicVol -> Master; Engine -> EngineVol -> Master;
## Ambience/SFX -> SoundVol -> Master.
## The *Vol buses carry the player's sliders; the inner buses carry the mix.
func _setup_buses() -> void:
	for pair in [["MusicVol", "Master"], ["SoundVol", "Master"], ["EngineVol", "Master"], ["Music", "MusicVol"],
			["Engine", "EngineVol"], ["Ambience", "SoundVol"], ["SFX", "SoundVol"]]:
		if AudioServer.get_bus_index(pair[0]) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, pair[0])
		AudioServer.set_bus_send(AudioServer.get_bus_index(pair[0]), pair[1])
	var e := AudioServer.get_bus_index("Engine")
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = 5200.0
	AudioServer.add_bus_effect(e, lp)
	var rv := AudioEffectReverb.new()
	rv.room_size = 0.35
	rv.damping = 0.7
	rv.wet = 0.08
	AudioServer.add_bus_effect(e, rv)
	AudioServer.set_bus_volume_db(e, ENGINE_DB)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Ambience"), AMBIENCE_DB)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), SFX_MENU_DB)
	var lim := AudioEffectHardLimiter.new()
	lim.ceiling_db = -0.5
	AudioServer.add_bus_effect(0, lim)


func _player(bus: String, mode := Node.PROCESS_MODE_PAUSABLE) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	p.process_mode = mode
	add_child(p)
	return p


func _stream(rel: String, loop := false) -> AudioStream:
	if _cache.has(rel):
		return _cache[rel]
	var s: AudioStream = load(DIR + rel)
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = loop
	_cache[rel] = s
	return s


# --- settings / context --------------------------------------------------------

func apply_settings() -> void:
	_apply_volume("MusicVol", GameState.volume("music"))
	_apply_volume("SoundVol", GameState.volume("sound"))
	_apply_volume("EngineVol", GameState.volume("engine"))


## Slider 0..1 -> dB with a squared taper, so 50% sounds about half as loud.
static func slider_db(v: float) -> float:
	return linear_to_db(maxf(v * v, 0.00001))


func _apply_volume(bus_name: String, v: float) -> void:
	var i := AudioServer.get_bus_index(bus_name)
	AudioServer.set_bus_mute(i, v <= 0.001)
	AudioServer.set_bus_volume_db(i, slider_db(v))


## Crossfade to another music loop (each trail picks one; menus use the theme).
func set_track(track: String) -> void:
	_menu_req += 1  # cancels a pending switch back to the menu theme (retry keeps the trail's loop going)
	if track == _track or _is_headless():
		return
	_track = track
	var old := music
	music = _player("Music", Node.PROCESS_MODE_ALWAYS)
	music.stream = _stream("music/%s.ogg" % track, true)
	music.volume_db = -30.0
	music.play()
	_fade(music, 0.0, 1.6)
	_fade(old, -60.0, 1.4, true)
	get_tree().create_timer(1.6, true).timeout.connect(old.queue_free)


## "menu": theme up front. "game": theme tucked under the engine and ambience.
func set_context(ctx: String) -> void:
	if ctx == "menu" and is_inside_tree():
		# Wait a moment: on RETRY the next run asks for its track right away.
		_menu_req += 1
		var req := _menu_req
		get_tree().create_timer(0.3, true).timeout.connect(func():
			if req == _menu_req:
				set_track("trestle_dreams"))
	var target := MUSIC_GAME_DB if ctx == "game" else MUSIC_MENU_DB
	var bus := AudioServer.get_bus_index("Music")
	_tween_value("music_bus", AudioServer.get_bus_volume_db(bus), target, 1.2,
		func(v): AudioServer.set_bus_volume_db(bus, v))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), SFX_GAME_DB if ctx == "game" else SFX_MENU_DB)


func _tween_value(key: String, from: float, to: float, secs: float, setter: Callable) -> void:
	if _tweens.has(key) and _tweens[key].is_valid():
		_tweens[key].kill()
	var tw := create_tween()
	tw.tween_method(setter, from, to, secs)
	_tweens[key] = tw


func _kill_tween(p: Node) -> void:
	var key := str(p.get_instance_id())
	if _tweens.has(key) and _tweens[key].is_valid():
		_tweens[key].kill()
	_tweens.erase(key)


func _fade(p: AudioStreamPlayer, to_db: float, secs: float, stop_after := false) -> void:
	var key := str(p.get_instance_id())
	if _tweens.has(key) and _tweens[key].is_valid():
		_tweens[key].kill()
	var tw := create_tween()
	tw.tween_property(p, "volume_db", to_db, secs)
	if stop_after:
		tw.tween_callback(p.stop)
	_tweens[key] = tw


# --- one-shots -------------------------------------------------------------------

func play(sfx_name: String, pitch := 1.0, vol_db := 0.0) -> void:
	if _is_headless():
		return
	var p: AudioStreamPlayer = pool[_next]
	_next = (_next + 1) % pool.size()
	p.stream = _stream("sfx/%s.ogg" % sfx_name)
	p.pitch_scale = pitch
	p.volume_db = vol_db
	p.play()


## Coins inside a streak climb the pentatonic; a pause resets the ladder. Two
## dedicated voices alternate and each new coin damps the last one, so a fast
## streak stays a clear run of notes instead of smearing together.
func coin() -> void:
	if _is_headless():
		return
	var now := Time.get_ticks_msec() / 1000.0
	_coin_step = mini(_coin_step + 1, COIN_STEPS.size() - 1) if now - _coin_time < 0.75 else 0
	_coin_time = now
	var prev: AudioStreamPlayer = coin_voices[_coin_voice]
	if prev.playing:
		_fade(prev, -40.0, 0.06, true)
	_coin_voice = 1 - _coin_voice
	var p: AudioStreamPlayer = coin_voices[_coin_voice]
	_kill_tween(p)
	p.pitch_scale = pow(2.0, COIN_STEPS[_coin_step] / 12.0)
	p.volume_db = -4.0
	p.play()


## Bonus biplane drone. near: 0 (off-screen) .. 1 (overhead). behind: +1 while it is
## still catching up (pitch a touch high), -1 once it has passed (Doppler drop).
func plane_set(on: bool, near := 0.0, behind := 0.0) -> void:
	if _is_headless():
		return
	if not on:
		if plane.playing and not (_tweens.has(str(plane.get_instance_id())) and _tweens[str(plane.get_instance_id())].is_running()):
			_fade(plane, -60.0, 0.6, true)
		return
	if not plane.playing:
		_kill_tween(plane)
		plane.volume_db = -40.0
		plane.play()
	_kill_tween(plane)
	plane.volume_db = lerpf(-34.0, -9.0, clampf(near, 0.0, 1.0))
	plane.pitch_scale = 1.0 + 0.05 * clampf(behind, -1.0, 1.0)


## Pulley whine while hanging from a zipline.
func zip_on(on: bool) -> void:
	if _is_headless():
		return
	if on:
		_kill_tween(zip)
		zip.volume_db = -14.0
		zip.pitch_scale = 1.0
		if not zip.playing:
			zip.play()
		_fade(zip, -3.0, 0.15)
	elif zip.playing:
		_fade(zip, -60.0, 0.25, true)


## Grinding a rail (steel scrape) or riding a wall (the boards booming): a loop that
## runs while you're on it.
func grind_on(on: bool, kind := "rail") -> void:
	if _is_headless():
		return
	if on:
		_kill_tween(grind)
		grind.stream = _stream("sfx/grind.ogg" if kind == "rail" else "sfx/deck_roll.ogg", true)
		grind.pitch_scale = 1.0 if kind == "rail" else 0.7
		grind.volume_db = -8.0 if kind == "rail" else 0.0
		grind.play()
	elif grind.playing:
		_fade(grind, -60.0, 0.12, true)


## A boss's saucer hum. near: 0 (far) .. 1 (right there).
func saucer_set(on: bool, near := 0.0) -> void:
	if _is_headless():
		return
	if not on:
		if saucer.playing:
			_fade(saucer, -60.0, 0.6, true)
		return
	if not saucer.playing:
		_kill_tween(saucer)
		saucer.volume_db = -40.0
		saucer.play()
	_kill_tween(saucer)
	saucer.volume_db = lerpf(-30.0, -6.0, clampf(near, 0.0, 1.0))


# --- engine ----------------------------------------------------------------------

func engine_start(bike_id: String) -> void:
	if _is_headless():
		return
	eng_idle.stream = _stream("engines/%s_idle.ogg" % bike_id, true)
	eng_cruise.stream = _stream("engines/%s_cruise.ogg" % bike_id, true)
	for p in [eng_idle, eng_cruise, deck]:
		_kill_tween(p)  # a previous run's fade-out must not stop the new engine
	for p in [eng_idle, eng_cruise]:
		p.volume_db = -60.0
		p.play(randf() * 3.0)
	_engine_on = true
	_riding = false
	_ride_mix = 0.0
	_air = 0.0
	_preview_t = -1.0
	_fade(eng_idle, 0.0, 0.6)
	deck.volume_db = -60.0
	deck.play()


func engine_ride() -> void:
	_riding = true
	_launch = 1.0


func engine_coast() -> void:
	_riding = false


## Crash: the engine dies with the bike.
func engine_cut() -> void:
	_engine_on = false
	_riding = false
	_fade(eng_idle, -60.0, 0.12, true)
	_fade(eng_cruise, -60.0, 0.12, true)
	_fade(deck, -60.0, 0.1, true)


func engine_stop(secs := 0.6) -> void:
	_engine_on = false
	_riding = false
	_fade(eng_idle, -60.0, secs, true)
	_fade(eng_cruise, -60.0, secs, true)
	_fade(deck, -60.0, secs, true)
	for p in [zip, plane, grind, saucer]:
		if p.playing:
			_fade(p, -60.0, secs, true)


## Called every frame by the world while a run is live.
func engine_update(delta: float, grounded: bool, speed_ratio: float) -> void:
	if not _engine_on:
		return
	_grounded = grounded
	_speed_ratio = speed_ratio
	_ride_mix = move_toward(_ride_mix, 1.0 if _riding else 0.0, delta * (2.2 if _riding else 0.8))
	_air = move_toward(_air, 0.0 if grounded or not _riding else 1.0, delta * (7.0 if not grounded else 4.0))
	_launch = move_toward(_launch, 0.0, delta * 0.9)
	var g_idle := cos(_ride_mix * PI * 0.5)
	var g_cruise := sin(_ride_mix * PI * 0.5)
	eng_idle.volume_db = linear_to_db(maxf(g_idle, 0.001))
	eng_cruise.volume_db = linear_to_db(maxf(g_cruise, 0.001)) - 1.5 * _air
	eng_idle.pitch_scale = 1.0 + 0.3 * _ride_mix
	# Rear wheel unloads in the air -> revs flare; launch starts a little low.
	eng_cruise.pitch_scale = clampf(speed_ratio * (1.0 + 0.13 * _air) * (1.0 - 0.14 * _launch), 0.5, 2.0)
	var deck_on := grounded and _riding
	deck.volume_db = move_toward(deck.volume_db, -4.0 if deck_on else -60.0, delta * (40.0 if deck_on else 120.0))
	deck.pitch_scale = clampf(speed_ratio, 0.6, 1.6)


## Garage: start the bike and give it a rev (idle catches, the throttle opens onto
## the cruise loop and drops back, then it idles and fades out).
func preview_engine(bike_id: String) -> void:
	if _is_headless():
		return
	_engine_on = false
	for p in [eng_idle, eng_cruise]:
		_kill_tween(p)
	eng_idle.stream = _stream("engines/%s_idle.ogg" % bike_id, true)
	eng_cruise.stream = _stream("engines/%s_cruise.ogg" % bike_id, true)
	eng_idle.volume_db = -30.0
	eng_idle.pitch_scale = 0.7
	eng_idle.play(randf() * 3.0)
	eng_cruise.volume_db = -60.0
	eng_cruise.pitch_scale = 0.8
	eng_cruise.play(randf() * 3.0)
	_preview_t = 0.0


func _process(delta: float) -> void:
	if _preview_t >= 0.0:
		_preview_t += delta
		var t := _preview_t
		# 0-0.25 s: the engine catches (pitch and level come up from a crank).
		var start := clampf(t / 0.25, 0.0, 1.0)
		# 0.45-1.4 s: one rev, up fast and back down slower.
		var rev := clampf((t - 0.45) / 0.25, 0.0, 1.0) * clampf((1.4 - t) / 0.55, 0.0, 1.0)
		var fade := maxf(0.0, t - 2.0) * 40.0
		eng_idle.pitch_scale = lerpf(0.7, 1.0, start) + 0.35 * rev
		eng_idle.volume_db = lerpf(-30.0, -4.0, start) - 8.0 * rev - fade
		eng_cruise.pitch_scale = 0.8 + 0.5 * rev
		eng_cruise.volume_db = linear_to_db(maxf(rev, 0.001)) - 3.0 - fade
		if t > 2.6:
			eng_idle.stop()
			eng_cruise.stop()
			_preview_t = -1.0


# --- ambience ----------------------------------------------------------------------

func set_ambience(time_mode: String, weather: String, level_id: String) -> void:
	if _is_headless():
		return
	var want: Dictionary = (TIME_LAYERS.get(time_mode, {}) as Dictionary).duplicate()
	for k in LEVEL_LAYERS.get(level_id, {}):
		want[k] = LEVEL_LAYERS[level_id][k]
		if want[k] <= -60.0:
			want.erase(k)
	if weather == "rain":
		want["rain"] = -3.0
		if want.has("day_birds"):
			want["day_birds"] -= 9.0
	_wind_layer = weather == "wind"
	if _wind_layer:
		want["wind"] = -6.0
	for k in amb.keys():
		if not want.has(k):
			_fade(amb[k], -60.0, 1.2, true)
	for k in want:
		var p: AudioStreamPlayer = amb.get(k)
		if p == null:
			p = _player("Ambience", Node.PROCESS_MODE_ALWAYS)
			p.stream = _stream("ambience/%s.ogg" % k, true)
			amb[k] = p
		if not p.playing:
			p.volume_db = -60.0
			p.play(randf() * maxf(1.0, p.stream.get_length() - 1.0) if p.stream else 0.0)  # anywhere in the loop
		_fade(p, want[k], 1.5)


func clear_ambience() -> void:
	for k in amb.keys():
		_fade(amb[k], -60.0, 1.0, true)
	_wind_layer = false


## Wind volume follows the same gust curve that pushes the bike.
func wind_gust(gust: float) -> void:
	if _wind_layer and amb.has("wind"):
		var p: AudioStreamPlayer = amb["wind"]
		if not (_tweens.has(str(p.get_instance_id())) and _tweens[str(p.get_instance_id())].is_running()):
			p.volume_db = lerpf(-14.0, 1.0, clampf(gust, 0.0, 1.0))
