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
const LEVEL_LAYERS := {"copper_canyon": {"creek": -2.0}}

var music: AudioStreamPlayer
var eng_idle: AudioStreamPlayer
var eng_cruise: AudioStreamPlayer
var deck: AudioStreamPlayer
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
	for i in 10:
		pool.append(_player("SFX"))
	apply_settings()
	set_context("menu")
	if not _is_headless():
		music.play()


func _is_headless() -> bool:
	return DisplayServer.get_name() == "headless"


# --- setup ---------------------------------------------------------------------

## Bus tree: Music -> MusicVol -> Master; Engine/Ambience/SFX -> SoundVol -> Master.
## The *Vol buses carry the player's sliders; the inner buses carry the mix.
func _setup_buses() -> void:
	for pair in [["MusicVol", "Master"], ["SoundVol", "Master"], ["Music", "MusicVol"],
			["Engine", "SoundVol"], ["Ambience", "SoundVol"], ["SFX", "SoundVol"]]:
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


## Slider 0..1 -> dB with a squared taper, so 50% sounds about half as loud.
static func slider_db(v: float) -> float:
	return linear_to_db(maxf(v * v, 0.00001))


func _apply_volume(bus_name: String, v: float) -> void:
	var i := AudioServer.get_bus_index(bus_name)
	AudioServer.set_bus_mute(i, v <= 0.001)
	AudioServer.set_bus_volume_db(i, slider_db(v))


## "menu": theme up front. "game": theme tucked under the engine and ambience.
func set_context(ctx: String) -> void:
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


## Coins inside a streak climb the pentatonic; a pause resets the ladder.
func coin() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	_coin_step = mini(_coin_step + 1, COIN_STEPS.size() - 1) if now - _coin_time < 0.75 else 0
	_coin_time = now
	play("coin", pow(2.0, COIN_STEPS[_coin_step] / 12.0), -4.0)


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


## Garage: a short blip of the throttle on the bike you just picked.
func preview_engine(bike_id: String) -> void:
	if _is_headless():
		return
	_engine_on = false
	_kill_tween(eng_idle)
	_kill_tween(eng_cruise)
	eng_cruise.stop()
	eng_idle.stream = _stream("engines/%s_idle.ogg" % bike_id, true)
	eng_idle.volume_db = -4.0
	eng_idle.pitch_scale = 1.0
	eng_idle.play(randf() * 3.0)
	_preview_t = 0.0


func _process(delta: float) -> void:
	if _preview_t >= 0.0:
		_preview_t += delta
		var t := _preview_t
		# blip: 0.35s up, hold, settle back, then fade out
		var rev := clampf(t / 0.35, 0.0, 1.0) * clampf((1.3 - t) / 0.5, 0.0, 1.0)
		eng_idle.pitch_scale = 1.0 + 0.9 * rev
		eng_idle.volume_db = -4.0 + 3.0 * rev - maxf(0.0, t - 1.6) * 30.0
		if t > 2.3:
			eng_idle.stop()
			_preview_t = -1.0


# --- ambience ----------------------------------------------------------------------

func set_ambience(time_mode: String, weather: String, level_id: String) -> void:
	if _is_headless():
		return
	var want: Dictionary = (TIME_LAYERS.get(time_mode, {}) as Dictionary).duplicate()
	for k in LEVEL_LAYERS.get(level_id, {}):
		want[k] = LEVEL_LAYERS[level_id][k]
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
			p.play(randf() * 8.0)
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
