## One run of one level: fixed-step simulation, pickups, checkpoints, crash/respawn,
## camera and world drawing. Set `bot` to drive it automatically (dev/verify).
extends Node2D

signal run_finished(result: Dictionary)

const Phys := preload("res://scripts/game/bike_physics.gd")
const Library := preload("res://scripts/game/level_library.gd")
const BikeView := preload("res://scripts/game/bike_view.gd")
const Backdrop := preload("res://scripts/game/backdrop.gd")
const Icons := preload("res://scripts/game/icons.gd")
const Catalog := preload("res://scripts/catalog.gd")
const Art := preload("res://scripts/game/feature_art.gd")
const WorldArt := preload("res://scripts/game/world_art.gd")
const BossArt := preload("res://scripts/game/boss_art.gd")
const Guide := preload("res://scripts/game/guide.gd")
const Endless := preload("res://scripts/game/endless.gd")

const SWOOP_SETTLE := 190.0
const SWOOP_RANGE := 170.0
const READY_TICKS := 54
const RESPAWN_TICKS := 30
const CRASH_TICKS := 66
## A tap this long into a crash skips the rest of it (back to the checkpoint now).
const CRASH_SKIP_TICKS := 24
const FINISH_TICKS := 60
# Bonus biplane: overtakes from behind with a prize sack you can jump for.
const PLANE_REL := 75.0      # px/s faster than the trail's cruise speed
const PLANE_PRIZE_H := 68.0  # sack height above the deck where it meets you
const PLANE_ROPE := 22.0
# Rear wheel x per bike model (wheelies pivot here).
const REAR_WHEEL := {"scrambler": -8.0, "dirt": -9.0, "minibike": -6.0, "scooter": -7.0,
	"cafe": -8.0, "chopper": -11.0, "sport": -8.0}

var level: Dictionary
var level_id := ""
## "" (Free Ride and story), "endless", "daily" or "league". Endless and league runs
## have one life: a crash ends the run and the distance counts.
var mode := ""
var one_life := false
var _zone := 0
## Cosmetic cheats (Challenges): a rainbow behind you in the air; paint splats.
var cheat_rainbow := false
var cheat_paint := false
var _splats: Array = []
const MAX_SPLATS := 80
const RAINBOW := [Color("ff4a4a"), Color("ffa040"), Color("ffe85a"), Color("6ae06a"), Color("5ab0ff"), Color("b07aff")]
var state: Dictionary
var loadout: Dictionary = {}
var ability: Dictionary = {}
var cond: Dictionary = {"time": "dusk", "weather": "clear"}
var theme: Dictionary
var bot = null
var headless := false

var phase := "ready"
var phase_ticks := 0
var first_ready := true
var ticks := 0
var press_queued := false
var held := false

var run_coins := 0
var gears: Array = []
var known_gears: Array = []
var crashes := 0
var stomps := 0
var smashes := 0
var loops_done := 0
var quiet := false
## Bonus planes fly over now and then (off in dev runs and hint demos).
var bonus_planes := true
var planes_seen := 0
var planes_caught := 0
var ride_time := 0.0
## Button state the sim used this tick (player or autopilot).
var held_now := false
var plane: Dictionary = {}
var _next_plane_t := 0.0
var _rng := RandomNumberGenerator.new()
var death_log: Array = []
var result: Dictionary = {}
var _cp: Dictionary = {}
var _next_cp := 0
var _acc := 0.0

var cam: Camera2D
var bike: Node2D
var _angle := 0.0
var _wheel := 0.0
var _squash := 0.0
var _shake := 0.0
## SCREEN SHAKE setting: off keeps the camera still on bonks, crashes and boss hits.
var shake_on := true
var _focus_y := 0.0
var _particles: Array = []
var _floaters: Array = []
var _wreck: Dictionary = {}
var _vis_t := 0.0
var _wheelie_a := 0.0
var _umbrella := 0.0
var _trail: Array = []
var _layers: Dictionary = {}
## Per lane, the node the bike is ordered against: the LaneLayer itself, or the
## CanvasGroup wrapping it when the trail has more than one lane (so a lane in front
## of the rider can fade out as one flat image instead of see-through pieces).
var _slots: Dictionary = {}
var _fx: Node2D
var _bike_layer := -99
var _bike_haze: ShaderMaterial
var _style: Dictionary = {}
var tricks_landed := 0
var trick_coins := 0
## T-R-E-S-T-L-E letters picked up this run (bit i = letter i).
var letters := 0
var letters_paid := false
## Ghost: this run's recording ([x, y, rot, lane_z] every 2 ticks of riding), and the
## best run to race ({"rig", "time", "frames"}) if there is one.
var ghost_rec := PackedFloat32Array()
var ghost: Dictionary = {}
var _ghost_view: Node2D
var _tips_shown := {}
## Rope swings: the camera eases along instead of following every sway (0..1).
var _cam_ease := 0.0
## Boss trails: where the boss is drawn (it flies between its windows), its hit flash,
## and the part it drops when it goes down.
var boss_vis: Dictionary = {}
var boss_down_tick := -1
var boss_part := ""
var _zips_in_air := 0
## Crash hints (see guide.gd): off for the dev bot, hint demos and the tour.
var hints := true
## Dev: work the hint line out on the spot instead of on a worker thread.
var hint_sync := false
## The hint showing now: its tip, and once worked out, the line to follow
## ({"pts", "z", "held", "marks"}, see Guide.compute).
var guide_on := false
var guide_tip := ""
var guide: Dictionary = {}
var guide_end := 0.0
## ride_time when you came back with a hint showing (the HUD shortens it after a bit).
var guide_since := 0.0
var _guide_job = null
var _guide_serial := -1
## [Thread, Guide.Job] for every worker still running (a newer wreck cancels older ones).
var _guide_jobs: Array = []
## Where the wheels last touched a deck (a fall is blamed on the stretch you left).
var _air_x := 0.0
const BOSS_FINISH_TICKS := 120
const LETTER_BONUS := 50
const MAGNET_R := 60.0
const POWER_NAMES := {
	"sticky": ["STICKY TIRES!", "JUMP AT A GREEN WALL"], "rocket": ["ROCKET!", "JUMP OFF THE RAMP"],
	"magnet": ["COIN MAGNET!", ""], "hat": ["HARD HAT!", "TAKES ONE HIT"],
}


## loadout: {"rider", "bike", "paint"} ids. conditions: {"time", "weather"}.
func setup(id: String, rig: Dictionary, known: Array, conditions: Dictionary = {}, custom: Dictionary = {}) -> void:
	level_id = id
	level = Library.build(id) if custom.is_empty() else custom
	loadout = rig
	ability = Catalog.ability(String(rig.get("bike", "scrambler")))
	if rig.has("ability"):
		ability = rig.ability
	if not conditions.is_empty():
		cond = conditions
	Phys.apply_weather(level, String(cond.weather))
	theme = Backdrop.theme(level.theme, String(cond.time), String(cond.weather))
	_style = WorldArt.style(int(level.theme))
	gears = []
	known_gears = []
	for i in level.gear_total:
		gears.append(false)
		known_gears.append(i < known.size() and known[i])
	state = Phys.new_state(level, level.start_x, level.start_track, 0.0, ability)
	if level.has("boss"):
		var b: Dictionary = level.boss
		boss_vis = {"pos": Vector2(float(b.x0) + 300.0, float(b.y0) - 130.0), "hurt": 0.0, "drop": {}, "flee": 0.0}
		boss_part = meta_part(id)
	_rng.seed = hash(id) ^ Time.get_ticks_usec()
	_next_plane_t = _rng.randf_range(9.0, 16.0)
	_focus_y = state.y
	_snapshot(level.start_x, level.start_track)


## The part a story boss is holding (from the catalog), or "".
static func meta_part(id: String) -> String:
	return String(Catalog.level(id).get("part", ""))


## Dev/demo: swap in a custom level after the world is in the tree.
func replace_level(lv: Dictionary, x := 40.0) -> void:
	level = lv
	_win = {}
	Phys.apply_weather(level, String(cond.weather))
	boss_vis = {}
	if level.has("boss"):
		var b: Dictionary = level.boss
		boss_vis = {"pos": Vector2(float(b.x0) + 300.0, float(b.y0) - 130.0), "hurt": 0.0, "drop": {}, "flee": 0.0}
		if boss_part == "":
			boss_part = {"scooper": "headlight", "hog": "kickstart", "harvester": "seat", "spinner": "wheels"}.get(String(b.kind), "")
	gears = []
	known_gears = []
	for i in level.gear_total:
		gears.append(false)
		known_gears.append(false)
	for ti in Phys.tracks_near(level, x, 0):
		var tr: Dictionary = level.tracks[ti]
		if x >= tr.x0 and x <= tr.x1 and not tr.side:
			state = Phys.new_state(level, x, ti, 0.0, ability)
			_snapshot(x, ti)
			break
	_focus_y = state.y
	if cam:
		for l in _slots.values():
			l.queue_free()
		_layers.clear()
		_slots.clear()
		_bike_layer = -99
		_build_layers()
		move_child(_fx, get_child_count() - 1)
		cam.position = _cam_target()


func _ready() -> void:
	if headless:
		return
	cam = Camera2D.new()
	add_child(cam)
	cam.make_current()
	_build_layers()
	if not ghost.is_empty():
		_ghost_view = BikeView.new()
		_ghost_view.rig = ghost.get("rig", loadout)
		_ghost_view.modulate = Color(0.75, 0.9, 1.0, 0.38)
		add_child(_ghost_view)
	bike = BikeView.new()
	bike.rig = loadout
	add_child(bike)
	_fx = FxLayer.new()
	_fx.world = self
	add_child(_fx)
	cam.position = _cam_target()


func _unhandled_input(event: InputEvent) -> void:
	if bot != null:
		return
	if event.is_action_pressed("jump"):
		press_queued = true
		held = true
		if phase == "crash" and phase_ticks >= CRASH_SKIP_TICKS:
			_crash_over()  # impatient: straight back to the checkpoint (or to the results)
		if is_inside_tree():
			get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if event.is_action_released("jump"):
		held = false


func _process(delta: float) -> void:
	if headless:
		return
	_acc += minf(delta, 0.1)
	while _acc >= Phys.DT:
		_acc -= Phys.DT
		tick()
	_vis_t += delta
	if not _guide_jobs.is_empty():
		_poll_guides()
	_sync_visuals()
	if phase == "ride" or phase == "done" or phase == "ready":
		if _audio_on():
			var wheels_down: bool = (state.grounded or int(state.loop) >= 0) and int(state.zip) < 0
			AudioDirector.engine_update(delta, wheels_down, float(state.vx) / float(level.speed))
	if _audio_on() and boss_vis.size() > 0 and cam:
		var bd := (boss_vis.pos as Vector2).distance_to(cam.position)
		AudioDirector.saucer_set(phase != "crash" and float(boss_vis.flee) < 2.0, 1.0 - clampf((bd - 60.0) / 320.0, 0.0, 1.0))
	if _audio_on():
		if plane.is_empty() or cam == null:
			AudioDirector.plane_set(false)
		else:
			var dx: float = float(plane.x) - cam.position.x
			var half := get_viewport_rect().size.x * 0.5
			AudioDirector.plane_set(true, 1.0 - clampf((absf(dx) - 30.0) / (half + 140.0), 0.0, 1.0), clampf(-dx / 80.0, -1.0, 1.0))
	for l in _layers.values():
		l.queue_redraw()
	if _fx:
		_fx.queue_redraw()


func tick() -> void:
	ticks += 1
	match phase:
		"ready":
			phase_ticks += 1
			press_queued = false
			if phase_ticks >= (READY_TICKS if first_ready else RESPAWN_TICKS):
				phase = "ride"
				phase_ticks = 0
				first_ready = false
				if _audio_on():
					AudioDirector.engine_ride()
		"ride":
			ride_time += Phys.DT
			_ride_tick()
			if not headless and ticks % 2 == 0 and bike:
				ghost_rec.append_array(PackedFloat32Array([state.x, state.y, bike.rotation, state.lane_z]))
		"crash":
			phase_ticks += 1
			if not headless:
				_wreck.vel.y += 900.0 * Phys.DT
				_wreck.pos += _wreck.vel * Phys.DT
				_wreck.rot += _wreck.spin * Phys.DT
			if phase_ticks >= CRASH_TICKS:
				_crash_over()
		"done":
			phase_ticks += 1
			if state.alive:
				Phys.step(level, state, false, false)
			if phase_ticks == FINISH_TICKS:
				_emit_result(true)
	if not headless:
		_tick_visuals()


func _emit_result(finished: bool) -> void:
	result = {"level_id": level_id, "coins": run_coins, "gears": gears.duplicate(),
					"crashes": crashes, "stomps": stomps, "conditions": cond.duplicate(),
					"time": snappedf(ride_time, 0.1), "planes": planes_caught, "planes_seen": planes_seen,
					"tricks": tricks_landed, "trick_coins": trick_coins,
					"letters": letter_count(), "letters_all": letter_count() >= Library.LETTERS.length(),
					"letter_bonus": LETTER_BONUS if letters_paid else 0, "ghost": ghost_rec,
					"rig": loadout.duplicate(),
					"bike": String(loadout.get("bike", "")),
					"boss": level.has("boss"), "boss_down": boss_down_tick >= 0, "part": boss_part,
					"boss_loops": int(state.boss_loops), "had_ghost": not ghost.is_empty(),
					"mode": mode, "metres": metres(), "finished": finished, "par": float(level.get("par", 0.0))}
	run_finished.emit(result)


func _ride_tick() -> void:
	var pressed := press_queued
	var h := held
	press_queued = false
	if bot != null:
		var d: Array = bot.decide(state)
		pressed = d[0]
		h = d[1]
	held_now = h
	if level.has("zones"):
		_zone_tick()
	var ev := Phys.step(level, state, pressed, h)
	if state.grounded:
		_air_x = float(state.x)
	if guide_on and float(state.x) > guide_end:
		guide_on = false  # through it: the hint's done its job
	if ev & Phys.EV_JUMP:
		_puff(Vector2(state.x - 6, state.y), 5, Color(theme.deck_hi, 0.9))
		_sfx("jump", randf_range(0.94, 1.06))
	if ev & Phys.EV_LAND:
		_squash = 1.0
		_puff(Vector2(state.x, state.y), 6, Color(theme.deck_hi, 0.9))
		if cheat_paint:
			_splat(Vector2(state.x, state.y), 1.0)
		_sfx("land", randf_range(0.92, 1.05))
		if level.rain:
			_splash(Vector2(state.x, state.y))
			_sfx("splash", randf_range(0.9, 1.1), -2.0)
	if ev & Phys.EV_STOMP:
		_on_stomp()
	if ev & Phys.EV_SMASH:
		_on_smash()
	_feature_events(ev)
	if level.has("boss"):
		_boss_events(ev)
	if ev & Phys.EV_DEAD:
		_crash()
		return
	_collect()
	if bonus_planes and not headless:
		_plane_tick()
	while _next_cp < level.checkpoints.size() and state.x >= level.checkpoints[_next_cp].x:
		var c: Dictionary = level.checkpoints[_next_cp]
		_snapshot(c.x, c.track)
		_next_cp += 1
		_float(Vector2(c.x, state.y - 34), "CHECKPOINT", Color("8ff0a4"))
		_sfx("checkpoint")
	if state.x >= level.finish_x or (boss_down_tick >= 0 and ticks - boss_down_tick >= BOSS_FINISH_TICKS):
		phase = "done"
		phase_ticks = 0
		_float(Vector2(state.x + 20, state.y - 40), "FINISH!" if boss_down_tick < 0 else "PART RECOVERED!", Color("fff1a8"))
		_vibrate(40)
		_sfx("finish")
		if _audio_on():
			AudioDirector.engine_coast()


## Endless courses change speed stretch by stretch; it eases over on the joint.
func _zone_tick() -> void:
	var zones: Array = level.zones
	while _zone + 1 < zones.size() and float(state.x) >= float(zones[_zone + 1][0]):
		_zone += 1
	level.speed = move_toward(float(level.speed), float(zones[_zone][1]), Endless.SPEED_RAMP * Phys.DT)


## Metres ridden (endless and league).
func metres() -> int:
	return Endless.metres(level, float(state.x))


func _on_stomp() -> void:
	var ei: int = state.last_stomp
	var e: Dictionary = level.enemies[ei]
	e.alive = false
	e.squash_pos = Phys.enemy_pos(level, e, state.t)
	e.squash_t = _vis_t
	stomps += 1
	_ach("stomps")
	run_coins += Catalog.STOMP_COINS
	_float(e.squash_pos + Vector2(0, -16), "+%d" % Catalog.STOMP_COINS, Icons.GOLD)
	_puff(e.squash_pos, 8, Color("fff1a8"))
	_vibrate(25)
	_sfx("stomp", randf_range(0.95, 1.05))


func _on_smash() -> void:
	var ei: int = state.last_smash
	var e: Dictionary = level.enemies[ei]
	if not e.alive:
		return
	e.alive = false
	e.squash_pos = Phys.enemy_pos(level, e, state.t)
	e.squash_t = _vis_t
	e.smashed = true
	smashes += 1
	_float(e.squash_pos + Vector2(0, -18), "SMASH!", Color("ffb347"))
	_puff(e.squash_pos, 12, Color("ffb347"))
	_puff(e.squash_pos, 6, Color("e8e2d0"))
	_shake = 3.0
	_vibrate(45)
	_sfx("smash", randf_range(0.95, 1.05))


## Sounds and effects for springs, tunnels, loops, ziplines and specialties.
func _feature_events(ev: int) -> void:
	if ev & Phys.EV_SPRING:
		_squash = 1.0
		_puff(Vector2(state.x, state.y), 6, Color("fff1a8"))
		_sfx("spring", randf_range(0.97, 1.03))
		var sp: Dictionary = level.springs[state.spring]
		sp.fired = _vis_t
	if ev & Phys.EV_BONK:
		_shake = 2.5
		_puff(Vector2(state.x, state.y - Phys.HEIGHT), 6, Color("c9b28a"))
		_float(Vector2(state.x, state.y - 30), "BONK!", Color("ffd27a"))
		_sfx("bonk", randf_range(0.95, 1.05))
		_vibrate(30)
	if ev & Phys.EV_LOOP:
		_sfx("loop")
		loops_done += 1
	if ev & Phys.EV_ZIP:
		_sfx("zip_grab")
		_ach("zips")
		if _audio_on():
			AudioDirector.zip_on(true)
	if ev & Phys.EV_UNZIP:
		if _audio_on():
			AudioDirector.zip_on(false)
	if ev & Phys.EV_AIR:
		_puff(Vector2(state.x - 4, state.y), 6, Color("e8e2d0"))
		_sfx("jump", 1.25 if state.ab == "hop" else 0.8, 1.0)
		if state.ab == "dash":
			_sfx("dash")
	if ev & Phys.EV_WHEELIE:
		_sfx("wheelie", randf_range(0.97, 1.03), -3.0)
	if ev & Phys.EV_ARMOR:
		_float(Vector2(state.x, state.y - 30), "HIDE READY", Color("cfd6e0"))
	if ev & Phys.EV_FLIP:
		_sfx("flip", randf_range(0.95, 1.08))
	if ev & Phys.EV_TRICK:
		var coins: int = state.trick_coins
		run_coins += coins
		trick_coins += coins
		tricks_landed += 1
		if _ach_on():
			Achievements.unlock("flip")
			if int(state.trick_n) >= 2:
				Achievements.unlock("double_flip")
		_ach("flips", maxi(1, int(state.trick_n)))
		_float(Vector2(state.x, state.y - 36), "%s +%d" % [String(state.trick_name), coins], Color("8fe3ff"))
		_puff(Vector2(state.x, state.y), 10, Color("8fe3ff"))
		_sfx("trick")
		_vibrate(25)
	if ev & Phys.EV_SKETCHY:
		_float(Vector2(state.x, state.y - 32), "SKETCHY!", Color("ff9a6a"))
		_shake = 2.0
		_sfx("bonk", 0.8, -4.0)
		_vibrate(40)
	if ev & Phys.EV_SWITCH:
		_sfx("switch", 1.0 if float(level.switches[state.sw].to_lane) > float(level.switches[state.sw].lane) else 1.12)
	if ev & Phys.EV_POWER:
		_ach("powerups")
		var kind := String(state.last_power)
		var names: Array = POWER_NAMES.get(kind, [kind.to_upper(), ""])
		_float(Vector2(state.x, state.y - 34), String(names[0]), Color("9fffd0"))
		if String(names[1]) != "" and not _tips_shown.has(kind):
			_tips_shown[kind] = true
			_float(Vector2(state.x + 10, state.y - 46), String(names[1]), Color("cfe8ff"))
		_puff(Vector2(state.x, state.y - 10), 10, Color("9fffd0"))
		_sfx("power_" + kind if kind in ["rocket", "sticky"] else "power")
		_vibrate(30)
	if ev & Phys.EV_CLIMB:
		_sfx("climb")
		_squash = 0.6
		_puff(Vector2(state.x, state.y), 6, Color("7dff5a"))
	if ev & Phys.EV_CLIMB_OUT:
		_puff(Vector2(state.x, state.y), 6, Color(theme.deck_hi, 0.9))
		_sfx("land", 1.1)
	if ev & Phys.EV_WALL and not _tips_shown.has("wall"):
		_tips_shown["wall"] = true
		_float(Vector2(state.x - 10, state.y - 46), "STICKY TIRES CLIMB THIS", Color("9fffd0"))
	if ev & Phys.EV_HAT:
		_float(Vector2(state.x, state.y - 34), "HARD HAT SAVED YOU!", Color("f0c040"))
		_sfx("hat")
		_shake = 3.0
	if ev & Phys.EV_CRUMBLE:
		_sfx("crumble", randf_range(0.9, 1.15), -6.0)
	if ev & Phys.EV_LAND:
		_zips_in_air = 0
	if ev & Phys.EV_ZIP:
		_zips_in_air += 1
		if _zips_in_air >= 3 and _ach_on():
			Achievements.unlock("zip_chain")
	if ev & Phys.EV_GRIND:
		var hk := String(level.tracks[state.track].get("hold", "rail")) if int(state.track) >= 0 else "rail"
		_ach("rails" if hk == "rail" else "walls")
		_sfx("grind_on" if hk == "rail" else "wall_on", randf_range(0.95, 1.05))
		if _audio_on():
			AudioDirector.grind_on(true, hk)
		if not _tips_shown.has(hk):
			_tips_shown[hk] = true
			_float(Vector2(state.x, state.y - 36), "KEEP HOLDING!", Color("9fe8ff"))
	if ev & Phys.EV_GRIND_OFF:
		if _audio_on():
			AudioDirector.grind_on(false)
	if ev & Phys.EV_ROPE:
		_ach("ropes")
		_sfx("rope_grab", randf_range(0.95, 1.05))
		_squash = 0.4
	if ev & Phys.EV_ROPE_OFF:
		_sfx("jump", 1.15, -2.0)
		_cam_ease = 1.0


## Boss hits, the loop back to the arena start, and the part it drops when it goes down.
func _boss_events(ev: int) -> void:
	if ev & Phys.EV_BOSS_HIT:
		boss_vis.hurt = 1.0
		_shake = 4.5
		_vibrate(60)
		var left := int(state.boss_hp)
		_float(Vector2(state.x, state.y - 34), "HIT! %d TO GO" % left if left > 0 else "KNOCKED OUT!", Color("ff9a6a"))
		_puff(Vector2(state.x, state.y), 14, Color("9fffd0"))
		_puff(Vector2(state.x, state.y), 8, Color("fff1a8"))
		_sfx("boss_hit")
		if left <= 0:
			boss_down_tick = ticks
			var p: Vector2 = boss_vis.pos
			boss_vis.drop = {"p": p + Vector2(0, 8), "v": Vector2(float(state.vx) * 0.9, -150.0), "got": false}
			_sfx("boss_down")
	if ev & Phys.EV_BOSS_LOOP:
		_focus_y = state.y
		_next_cp = 0
		while _next_cp < level.checkpoints.size() and state.x >= level.checkpoints[_next_cp].x:
			_next_cp += 1
		if cam:
			cam.position = _cam_target()
		_float(Vector2(state.x + 40, state.y - 50), "IT'S COMING ROUND AGAIN!", Color("ffb347"))
		_sfx("boss_loop")


func letter_count() -> int:
	var n := 0
	for i in Library.LETTERS.length():
		if letters & (1 << i):
			n += 1
	return n


func _collect() -> void:
	var br := Phys.bike_rect(state, level).grow(2.0)
	var magnet := float(state.magnet_t) > 0.0
	var near: Array = Array(Phys.pickups_near(level, state.x, int(state.lane)))
	if magnet:
		for dx in [-MAGNET_R, MAGNET_R]:
			for pi in Phys.pickups_near(level, state.x + dx, int(state.lane)):
				if not pi in near:
					near.append(pi)
	var centre := Phys.bike_center(level, state)
	for pi in near:
		var p: Dictionary = level.pickups[pi]
		if not p.alive:
			continue
		var r := 4.0
		match int(p.type):
			Library.P_BAG:
				r = 6.0
			Library.P_GEAR, Library.P_LETTER:
				r = 7.0
		var pulled := magnet and int(p.type) in [Library.P_COIN, Library.P_BAG] and centre.distance_to(p.pos) < MAGNET_R
		if not pulled and not br.grow(r).has_point(p.pos):
			continue
		p.alive = false
		if pulled and not headless:
			# A streak of sparkles from the coin into the bike.
			for k in 4:
				_particles.append({"p": _view(p.pos.lerp(centre, k * 0.25)), "v": Vector2.ZERO, "life": 8 + k * 2,
					"max": 14, "c": Icons.GOLD_LIGHT, "s": 1.0, "g": 0.0})
		match int(p.type):
			Library.P_COIN:
				run_coins += 1
				_puff(p.pos, 3, Icons.GOLD_LIGHT)
				if _audio_on():
					AudioDirector.coin()
			Library.P_BAG:
				run_coins += int(p.value)
				_float(p.pos + Vector2(0, -10), "+%d" % int(p.value), Icons.GOLD)
				_puff(p.pos, 8, Icons.GOLD)
				_sfx("bag")
			Library.P_GEAR:
				gears[int(p.gear)] = true
				_float(p.pos + Vector2(0, -12), "GEAR!", Icons.BRASS)
				_puff(p.pos, 10, Icons.BRASS)
				_vibrate(30)
				_sfx("gear")
			Library.P_LETTER:
				letters |= 1 << int(p.letter)
				var word := ""
				for i in Library.LETTERS.length():
					word += Library.LETTERS[i] if letters & (1 << i) else "_"
				_puff(p.pos, 10, Icons.GOLD)
				_vibrate(25)
				if letter_count() >= Library.LETTERS.length() and not letters_paid:
					letters_paid = true
					run_coins += LETTER_BONUS
					_float(p.pos + Vector2(0, -14), "T-R-E-S-T-L-E! +%d" % LETTER_BONUS, Icons.GOLD)
					_sfx("letters_all")
				else:
					_float(p.pos + Vector2(0, -14), "%s!" % Library.LETTERS[int(p.letter)], Icons.GOLD_LIGHT)
					_sfx("letter", 1.0 + 0.06 * letter_count())


func _snapshot(x: float, track: int) -> void:
	var dead_p := {}
	for i in level.pickups.size():
		if not level.pickups[i].alive:
			dead_p[i] = true
	var dead_e := {}
	for i in level.enemies.size():
		if not level.enemies[i].alive:
			dead_e[i] = true
	_cp = {"x": x, "track": track, "coins": run_coins, "gears": gears.duplicate(),
		"stomps": stomps, "dead_p": dead_p, "dead_e": dead_e, "letters": letters, "paid": letters_paid}


func _crash() -> void:
	phase = "crash"
	phase_ticks = 0
	crashes += 1
	death_log.append({"x": snappedf(state.x, 0.1), "cause": state.death})
	_hint_check()
	if headless:
		return
	var up := -170.0 if state.death == "hit" else -20.0
	_wreck = {"pos": Vector2(state.x, state.y), "vel": Vector2(float(state.vx) * 0.4, up),
		"rot": _angle, "spin": 10.0, "z": float(state.lane_z)}
	_shake = 5.0
	if cheat_paint:
		_splat(Vector2(state.x, _ground_y_or(state.x, INF, int(state.lane))), 2.2)
	_puff(Vector2(state.x, state.y - 8), 14, Color("ffb347"))
	_puff(Vector2(state.x, state.y - 8), 8, Color("e8e2d0"))
	_vibrate(70)
	_sfx("crash")
	if _audio_on():
		AudioDirector.engine_cut()
		AudioDirector.zip_on(false)
		AudioDirector.grind_on(false)
	plane = {}


## The wreck has played: back to the checkpoint, or with one life, the run is over.
func _crash_over() -> void:
	if one_life:
		if phase == "crash":
			phase = "over"
			phase_ticks = 0
			_emit_result(false)
		return
	_respawn()


func _respawn() -> void:
	run_coins = _cp.coins
	gears = _cp.gears.duplicate()
	stomps = _cp.stomps
	letters = int(_cp.letters)
	letters_paid = bool(_cp.paid)
	for i in level.pickups.size():
		level.pickups[i].alive = not _cp.dead_p.has(i)
	for i in level.enemies.size():
		var e: Dictionary = level.enemies[i]
		e.alive = not _cp.dead_e.has(i)
		if e.alive:
			e.erase("squash_t")
	state = _respawn_state(level)
	_focus_y = state.y
	guide_since = ride_time
	phase = "ready"
	phase_ticks = 0
	if _audio_on():
		AudioDirector.engine_start(String(loadout.get("bike", "scrambler")))


## The state you come back in at the last checkpoint (the clock carries on).
func _respawn_state(lv: Dictionary) -> Dictionary:
	var s := Phys.new_state(lv, _cp.x, _cp.track, state.t, ability)
	if lv.has("boss"):
		s.boss_hp = int(state.boss_hp)  # hits stick: you don't have to start the fight over
		s.boss_hits = int(state.boss_hits)
	return s


# --- crash hints -------------------------------------------------------------

## Count the wreck against its stretch of trail; enough of them and the next try
## shows the way through (worked out on a worker thread while the crash plays).
func _hint_check() -> void:
	guide_on = false
	guide = {}
	_guide_job = null
	for j in _guide_jobs:
		j[1].cancel()
	if not hints or (bot != null and not hint_sync):
		return
	var x := _air_x if String(state.death) == "fall" else float(state.x)
	var sec := Guide.section_at(level, x)
	var counts: Dictionary = Guide.wrecks(level_id)
	counts[sec] = int(counts.get(sec, 0)) + 1
	var sname := Guide.section_name(level, sec)
	if int(counts[sec]) < Guide.threshold(level_id, sname):
		return
	guide_on = true
	guide_tip = Guide.tip(sname, String(state.death))
	guide_end = maxf(Guide.section_end(level, sec), x + 100.0) + 40.0
	var lv: Dictionary = level.duplicate(true)
	for i in lv.enemies.size():
		lv.enemies[i].alive = not _cp.dead_e.has(i)
		lv.enemies[i].erase("squash_t")
	var inp := {"level": lv, "s0": _respawn_state(lv), "end_x": guide_end, "collect": level.has("boss")}
	if hint_sync or headless:
		var g := Guide.compute(inp)
		if bool(g.ok):
			guide = g
		return
	var job := Guide.Job.new()
	var th := Thread.new()
	th.start(Callable(Guide, "compute").bind(inp, job))  # normal priority: low can mean a slow core
	_guide_jobs.append([th, job])
	_guide_job = job
	_guide_serial = -1


## Take the newest piece of the hint line, and tidy up finished workers.
func _poll_guides() -> void:
	if _guide_job != null and guide_on:
		var g: Dictionary = _guide_job.take(_guide_serial)
		if not g.is_empty():
			_guide_serial = int(g.serial)
			if bool(g.done) and not bool(g.ok):
				guide = {}  # no clean way through found from here: just the tip
				_guide_job = null
			else:
				g.marks = Guide.marks_for(g.held, g.taps, g.att)
				guide = g
	for j in _guide_jobs.duplicate():
		var th: Thread = j[0]
		if not th.is_alive():
			th.wait_to_finish()
			_guide_jobs.erase(j)


func _exit_tree() -> void:
	for j in _guide_jobs:
		j[1].cancel()
	for j in _guide_jobs:
		(j[0] as Thread).wait_to_finish()
	_guide_jobs.clear()


func _audio_on() -> bool:
	return not headless and not quiet


## Achievements only count real rides (not the dev bot, hint demos or the tour).
func _ach_on() -> bool:
	return bot == null and not headless and not quiet


func _ach(stat: String, n := 1) -> void:
	if _ach_on():
		Achievements.add(stat, n)
		Challenges.on_stat(stat, n)


func _sfx(sfx_name: String, pitch := 1.0, vol_db := 0.0) -> void:
	if _audio_on():
		AudioDirector.play(sfx_name, pitch, vol_db)


func _vibrate(ms: int) -> void:
	if not headless and OS.has_feature("mobile") and GameState.flag("vibrate"):
		Input.vibrate_handheld(ms)


# --- bonus plane -------------------------------------------------------------

## Every so often a biplane overtakes you trailing a prize sack. It is only sent
## when the stretch where it will catch up with you is calm (plain deck, nothing
## to dodge), and the sack hangs at a height a good long jump reaches.
func _plane_tick() -> void:
	if plane.is_empty():
		if state.t < _next_plane_t or not state.grounded or int(state.zip) >= 0 or int(state.lane) != 0:
			return
		var vs := get_viewport_rect().size
		var lead: float = vs.x * 0.28 + 40.0
		var v: float = level.speed
		# Pick where it catches up with you: the first calm stretch ahead (240-500 px).
		# Its speed is set so the sack arrives right there.
		var meet_x := -1.0
		var d := 240.0
		var d_max := lead * v / 45.0  # slowest overtake we allow
		while d <= d_max:
			if _calm(state.x + d - 60.0, state.x + d + 130.0):
				meet_x = state.x + d
				break
			d += 30.0
		if meet_x < 0.0:
			_next_plane_t = state.t + 0.5
			return
		var rel := clampf(lead * v / (meet_x - state.x), 45.0, 130.0)
		var gy := _ground_y(meet_x)
		plane = {"x": state.x - lead, "y": gy - PLANE_PRIZE_H - PLANE_ROPE - 2.0, "v": v + rel,
			"prize": true, "value": 10 + 3 * maxi(0, Catalog.level_index(level_id)), "waggle": 0.0}
		planes_seen += 1
		_next_plane_t = state.t + _rng.randf_range(22.0, 38.0)
		return
	plane.x += float(plane.v) * Phys.DT
	plane.waggle = maxf(0.0, float(plane.waggle) - Phys.DT)
	if plane.prize and phase == "ride" and int(state.lane) == 0:
		var sack := prize_pos()
		if Phys.bike_rect(state, level).grow(7.0).has_point(sack):
			plane.prize = false
			plane.waggle = 1.2
			planes_caught += 1
			_ach("planes")
			run_coins += int(plane.value)
			_float(sack + Vector2(0, -12), "+%d BONUS!" % int(plane.value), Icons.GOLD, 0.0)
			_puff(sack, 14, Icons.GOLD, 0.0)
			_vibrate(40)
			_sfx("prize")
	if float(plane.x) > state.x + get_viewport_rect().size.x + 120.0:
		plane = {}


func prize_pos() -> Vector2:
	return Vector2(float(plane.x) - 6.0, float(plane.y) + 4.0 + PLANE_ROPE + 6.0)


## Plain main deck from xa to xb: level, unbroken, nothing to jump or dodge.
func _calm(xa: float, xb: float) -> bool:
	if xb > float(level.finish_x) - 40.0 or xa < float(level.start_x) + 200.0:
		return false
	var last := INF
	var px := xa
	while px <= xb:
		var gy := INF
		for ti in Phys.tracks_near(level, px, 0):
			var tr: Dictionary = level.tracks[ti]
			if px < tr.x0 or px > tr.x1:
				continue
			if tr.side or tr.has("lift"):
				return false
			gy = Phys.height_at(tr, px)
		if gy == INF or (last != INF and absf(gy - last) > 2.0):
			return false
		last = gy
		px += 8.0
	for e in level.enemies:
		var lo: float = float(e.x0) - 24.0 - float(e.get("drift", 0.0))
		var hi: float = float(e.get("x1", e.x0)) + 24.0
		if hi > xa and lo < xb:
			return false
	for sp in level.springs:
		if sp.x > xa - 30.0 and sp.x < xb + 30.0:
			return false
	for L in level.loops:
		if float(L.x) + float(L.shift) + float(L.r) > xa and float(L.x) - float(L.r) < xb:
			return false
	for c in level.ceils:
		if c.x1 > xa - 30.0 and c.x0 < xb + 30.0:
			return false
	for z in level.zips:
		if z.x1 > xa and z.x0 < xb:
			return false
	for w in level.switches:
		if float(w.x) + float(w.len) + 40.0 > xa and float(w.x) - 60.0 < xb:
			return false
	return true


# --- visuals ---------------------------------------------------------------

## Lanes are drawn as layers: background (1), main (0), foreground (-1). A lane at
## depth z is scaled by lane_scale(z) about the camera and shifted by lane_oy(z),
## so the background is smaller, higher and scrolls slower.
static func lane_scale(z: float) -> float:
	return pow(0.72, z) if z >= 0.0 else pow(1.35, -z)


static func lane_oy(z: float) -> float:
	return -50.0 * z if z >= 0.0 else -44.0 * z


## Lane coordinates at depth z -> main-lane (camera) coordinates.
func _view(p: Vector2, z := INF) -> Vector2:
	if cam == null:
		return p
	if z == INF:
		z = float(state.lane_z)
	var c := cam.position
	return c + (p - c) * lane_scale(z) + Vector2(0, lane_oy(z))


func _lane_origin(z: float) -> Vector2:
	var s := lane_scale(z)
	return cam.position * (1.0 - s) + Vector2(0, lane_oy(z))


## The view layer the rider sits in front of.
func _rider_layer() -> int:
	var z: float = state.lane_z
	if z > 0.5 and _layers.has(1):
		return 1
	if z < -0.5 and _layers.has(-1):
		return -1
	return 0


class LaneLayer extends Node2D:
	var world
	var lane := 0

	func _draw() -> void:
		world.draw_lane(self, lane)


class FxLayer extends Node2D:
	var world

	func _draw() -> void:
		world.draw_fx(self)


const HAZE_SHADER := """
shader_type canvas_item;
uniform vec4 haze : source_color = vec4(0.5, 0.5, 0.6, 1.0);
uniform float amount = 0.0;
void fragment() {
	COLOR.rgb = mix(COLOR.rgb, haze.rgb, amount);
}
"""


func _build_layers() -> void:
	var lanes := {0: true}
	for tr in level.tracks:
		lanes[int(tr.get("lane", 0))] = true
	var shader := Shader.new()
	shader.code = HAZE_SHADER
	var haze_col: Color = (theme.far as Color).lerp(theme.sky[3], 0.45)
	for ln in [1, 0, -1]:
		if not lanes.has(ln):
			continue
		var layer := LaneLayer.new()
		var slot: Node2D = layer
		if lanes.size() > 1:
			slot = CanvasGroup.new()
			slot.add_child(layer)
		layer.world = self
		layer.lane = ln
		if ln == 1:
			var m := ShaderMaterial.new()
			m.shader = shader
			m.set_shader_parameter("haze", haze_col)
			m.set_shader_parameter("amount", 0.38)
			layer.material = m
		add_child(slot)
		_layers[ln] = layer
		_slots[ln] = slot
	_bike_haze = ShaderMaterial.new()
	_bike_haze.shader = shader
	_bike_haze.set_shader_parameter("haze", haze_col)


func _tick_visuals() -> void:
	if cheat_rainbow and phase == "ride" and not state.grounded and int(state.zip) < 0 and int(state.rope) < 0:
		# RAINBOW TRAIL: a band of colour streaming off the back of the bike.
		var back := Vector2(state.x - 12.0, state.y - 6.0)
		for i in RAINBOW.size():
			_particles.append({"p": _view(back + Vector2(0, (i - 2.5) * 1.6)), "v": Vector2(-12.0, 0.0),
				"life": 26, "max": 26, "c": RAINBOW[i], "s": 2.0, "g": 0.0})
	if phase == "ride" or phase == "done":
		_wheel += float(state.vx) * Phys.DT / 4.0
		var target := atan(state.slope) if state.grounded else clampf(state.vy * 0.0011, -0.42, 0.5)
		if int(state.loop) >= 0:
			target = Phys.loop_angle(level.loops[state.loop], state.loop_a)
			_angle = target
		elif int(state.zip) >= 0:
			target = atan(state.slope) + sin(_vis_t * 5.0) * 0.06
		elif int(state.sw) >= 0:
			target = 0.0
		elif int(state.climb) >= 0:
			target = -PI * 0.5
		elif int(state.rope) >= 0:
			target = -float(state.rope_a)
			_angle = target
		_angle = lerp_angle(_angle, target, 0.45 if int(state.climb) >= 0 else 0.3)
		var hold_kind := Phys.attachment(level, state)
		if hold_kind == "rail" and ticks % 2 == 0:
			# Sparks off the grinding pegs.
			for k in 2:
				_particles.append({"p": _view(Vector2(state.x - 4, state.y)), "v": Vector2(randf_range(-90, -30), randf_range(-70, -20)),
					"life": 12, "max": 12, "c": Color(1.0, 0.75 + randf() * 0.25, 0.3, 1.0), "s": 1.0, "g": 300.0})
		elif hold_kind == "wall" and ticks % 4 == 0:
			_particles.append({"p": _view(Vector2(state.x - 8, state.y)), "v": Vector2(randf_range(-40, -10), randf_range(-20, 5)),
				"life": 16, "max": 16, "c": Color(theme.deck_hi, 0.7), "s": 1.0, "g": 60.0})
		if boss_vis.size() > 0:
			_boss_tick()
		_wheelie_a = lerpf(_wheelie_a, -0.34 if state.wheelie else 0.0, 0.2)
		var flipping: bool = int(state.flip_dir) != 0
		_umbrella = move_toward(_umbrella, 1.0 if (state.ab == "glide" and held_now and not state.grounded and not flipping
			and float(state.vy) > 0.0 and int(state.zip) < 0 and Phys.attachment(level, state) == ""
			and Phys.umbrella_ok(level, state)) else 0.0, 0.18)
		var fast: bool = float(state.dash_t) > 0.0 or (state.ab == "wheelie" and float(state.boost) > float(level.speed) * 0.05) \
			or float(state.rocket_t) > 0.0
		if float(state.rocket_t) > 0.0 and ticks % 2 == 0:
			var ex := Vector2(state.x, state.y) + Vector2(-16, -7).rotated(_angle)
			_particles.append({"p": _view(ex), "v": Vector2(randf_range(-90, -50), randf_range(-15, 15)),
				"life": 14, "max": 14, "c": Color(1.0, 0.6 + randf() * 0.35, 0.25, 0.9), "s": 2.0, "g": -20.0})
		if float(state.sticky_t) > 0.0 and state.grounded and ticks % 6 == 0:
			_particles.append({"p": _view(Vector2(state.x - 9, state.y - 1)), "v": Vector2(-10, 4),
				"life": 30, "max": 30, "c": Color(0.45, 1.0, 0.35, 0.8), "s": 1.0, "g": 40.0})
		if float(state.chase_x) > -INF and ticks % 3 == 0:
			# The collapse behind you: planks and posts tumbling into the dust.
			var fx := float(state.chase_x)
			var gy := _ground_y_or(fx + 4.0, float(state.y), 0)
			_particles.append({"p": _view(Vector2(fx + randf_range(-4, 10), gy + randf_range(-4, 4)), 0.0),
				"v": Vector2(randf_range(-30, 10), randf_range(-60, 0)), "life": 40, "max": 40,
				"c": (theme.deck as Color) if randf() < 0.6 else (theme.beam as Color), "s": 2.0 + float(randi() % 3), "g": 420.0})
		if fast and ticks % 2 == 0:
			_trail.append({"p": Vector2(state.x, state.y), "a": _angle + _wheelie_a, "life": 10, "lane": int(state.lane)})
		for tp in _trail:
			tp.life -= 1
		_trail = _trail.filter(func(tp): return tp.life > 0)
		if state.wheelie and ticks % 3 == 0:
			_particles.append({"p": _view(Vector2(state.x + float(REAR_WHEEL.get(String(loadout.get("bike", "scrambler")), -8.0)) - 2, state.y - 1)),
				"v": Vector2(randf_range(-60, -30), randf_range(-30, -10)), "life": 16, "max": 16,
				"c": Color(theme.deck_hi, 0.7), "s": 1.0, "g": 80.0})
		if int(state.loop) >= 0 or int(state.zip) >= 0 or int(state.rope) >= 0:
			pass
		elif state.grounded or int(state.sw) >= 0 or int(state.climb) >= 0:
			_focus_y = lerpf(_focus_y, state.y, 0.15)
			var sliding: bool = level.rain and float(state.vx) > float(level.speed) + 4.0
			if sliding and ticks % 2 == 0:
				# Rooster tail of spray while the tire skids on the wet deck.
				_particles.append({"p": _view(Vector2(state.x - 10, state.y - 1)),
					"v": Vector2(randf_range(-70, -30), randf_range(-60, -25)),
					"life": 16, "max": 16, "c": Color(0.75, 0.88, 1.0, 0.85), "s": 1.0, "g": 260.0})
			elif ticks % 5 == 0:
				_particles.append({"p": _view(Vector2(state.x - 11, state.y - 1)), "v": Vector2(-30, -12),
					"life": 18, "max": 18, "c": Color(theme.deck_hi, 0.6), "s": 1.0, "g": 0.0})
		else:
			_focus_y = lerpf(_focus_y, state.y, 0.04)
	_squash = maxf(0.0, _squash - 0.12)
	_shake = maxf(0.0, _shake - 0.35)
	for p in _particles:
		p.v.y += p.g * Phys.DT
		p.p += p.v * Phys.DT
		p.life -= 1
	_particles = _particles.filter(func(p): return p.life > 0)
	for f in _floaters:
		f.p.y -= 0.4
		f.life -= 1
	_floaters = _floaters.filter(func(f): return f.life > 0)
	if cam and phase != "crash":
		var tgt := _cam_target()
		if int(state.rope) >= 0:
			_cam_ease = 1.0
			# Follow the rope's anchor (plus a lead), not every swing back and forth.
			var rp: Dictionary = level.ropes[state.rope]
			tgt.x = float(rp.ax) + 20.0 + get_viewport_rect().size.x * 0.22
		if _cam_ease > 0.0:
			cam.position.x = lerpf(cam.position.x, tgt.x, 0.12)
			if absf(cam.position.x - tgt.x) < 1.0 and int(state.rope) < 0:
				_cam_ease = 0.0
		else:
			cam.position.x = tgt.x
		cam.position.y = lerpf(cam.position.y, tgt.y, 0.1)


## Camera centre that puts the rider at the usual spot on screen, whatever lane
## (depth) they're in: solves view(rider) - centre = (-0.22 w, +0.08 h).
func _cam_target() -> Vector2:
	var vs := get_viewport_rect().size
	var z: float = state.lane_z
	var s := lane_scale(z)
	return Vector2(state.x + vs.x * 0.22 / s, _focus_y - (vs.y * 0.08 - lane_oy(z)) / s)


func _sync_visuals() -> void:
	if bike == null:
		return
	var z: float = state.lane_z
	var s := lane_scale(z)
	if phase == "crash":
		bike.position = _view(_wreck.pos, float(_wreck.z))
		bike.rotation = _wreck.rot
	else:
		var base := Vector2(state.x, state.y)
		var rot := _angle
		if int(state.rope) >= 0:
			# Hanging from the rope by the hands: the bike swings round the grip.
			var rp: Dictionary = level.ropes[state.rope]
			var a := float(state.rope_a)
			var hand := Vector2(rp.ax, rp.ay) + float(state.rope_r) * Vector2(sin(a), cos(a))
			base = hand + Vector2(-4.0, Phys.HEIGHT + 2.0).rotated(-a)
			rot = -a
		if absf(_wheelie_a) > 0.01:
			# Pivot round the rear wheel so it stays planted on the deck.
			var rear := Vector2(float(REAR_WHEEL.get(String(loadout.get("bike", "scrambler")), -8.0)), 0.0)
			base += rear.rotated(_angle) - rear.rotated(_angle + _wheelie_a)
			rot += _wheelie_a
		var fl: float = state.flip_a
		if int(state.flip_dir) != 0 and fl > 0.0:
			# Flip round the middle of the bike (backflip = nose up and over).
			var spin := -fl if int(state.flip_dir) < 0 else fl
			var mid := Vector2(0, -9).rotated(rot)
			base += mid - mid.rotated(spin)
			rot += spin
		bike.position = _view(base)
		bike.rotation = rot
	bike.scale = Vector2(s, s)
	var layer: int = _rider_layer()
	if layer != _bike_layer and _slots.has(layer):
		move_child(bike, _slots[layer].get_index() + 1)
		_bike_layer = layer
	# Lanes in front of the rider fade so you can see yourself behind tunnels and decks.
	for ln in _slots:
		var g: Node2D = _slots[ln]
		if g is CanvasGroup:
			var a := 0.42 if float(ln) < z - 0.3 else 1.0
			g.self_modulate.a = move_toward(g.self_modulate.a, a, 0.05)
	if z > 0.01:
		_bike_haze.set_shader_parameter("amount", 0.38 * minf(1.0, z))
		bike.material = _bike_haze
	else:
		bike.material = null
	bike.visible = not (phase == "ready" and not first_ready and int(_vis_t * 10.0) % 2 == 0)
	bike.wheel_angle = _wheel
	bike.squash = _squash
	bike.lean = clampf(-state.vy * 0.006, -1.0, 2.0) if not state.grounded else 0.0
	if int(state.loop) >= 0 or int(state.zip) >= 0 or int(state.sw) >= 0 or int(state.rope) >= 0:
		bike.lean = 0.0
	var gust := Phys.wind_at(level, state.t) / Phys.WIND_PEAK
	bike.flutter = clampf(0.35 + gust * 0.65 + (0.15 if not state.grounded else 0.0), 0.0, 1.0)
	if gust > 0.0 and not state.grounded:
		bike.lean += gust * 1.5
	bike.umbrella = _umbrella
	bike.hanging = int(state.zip) >= 0 or int(state.rope) >= 0
	bike.sticky = float(state.sticky_t) > 0.0 and (float(state.sticky_t) > 2.0 or int(_vis_t * 8.0) % 2 == 0)
	bike.rocket = clampf(float(state.rocket_t) / 0.3, 0.0, 1.0)
	bike.hat = int(state.hat) > 0
	bike.anim_t = _vis_t
	bike.queue_redraw()
	_sync_ghost()
	if cam:
		cam.offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake)) if _shake > 0.3 and shake_on else Vector2.ZERO


## 0..1: how strongly to light up a rope you could catch right now: in the air, hands
## at catch height (Phys.ROPE_REACH_*), the rope just ahead or a moment behind (the
## late catch). Brighter while you're holding.
func _rope_cue(ri: int, rp: Dictionary) -> float:
	if phase != "ride" or state.grounded or int(state.rope) >= 0 or ri == int(state.rope_last) \
			or int(rp.lane) != int(state.lane):
		return 0.0
	var hy := float(state.y) - Phys.HEIGHT - 2.0
	if hy < float(rp.ay) + float(rp.len) * Phys.ROPE_REACH_TOP or hy > float(rp.ay) + float(rp.len) + Phys.ROPE_REACH_LOW:
		return 0.0
	var dx := float(rp.ax) - (float(state.x) + 4.0)
	if dx > 72.0 or dx < -Phys.ROPE_LATE_DX:
		return 0.0
	return clampf(1.0 - maxf(dx, 0.0) / 72.0, 0.3, 1.0) * (1.0 if held_now else 0.65)


## Swap in a ghost after the world is in the tree (dev/demo).
func set_ghost(g: Dictionary) -> void:
	ghost = g
	if _ghost_view == null and bike:
		_ghost_view = BikeView.new()
		_ghost_view.modulate = Color(0.75, 0.9, 1.0, 0.38)
		add_child(_ghost_view)
		move_child(_ghost_view, bike.get_index())
	if _ghost_view:
		_ghost_view.rig = g.get("rig", loadout)


## The best run's ghost, at the same riding time as you.
func _sync_ghost() -> void:
	if _ghost_view == null:
		return
	var fr: PackedFloat32Array = ghost.frames
	var n := fr.size() / 4
	var i := int(ride_time * 30.0)
	if n == 0 or i >= n or phase == "ready" and ride_time <= 0.0:
		_ghost_view.visible = false
		return
	var gx := fr[i * 4]
	var gz := fr[i * 4 + 3]
	var s := lane_scale(gz)
	_ghost_view.visible = Vector2(gx, fr[i * 4 + 1]).distance_to(Vector2(state.x, state.y)) > 5.0 or phase != "ride"
	_ghost_view.position = _view(Vector2(gx, fr[i * 4 + 1]), gz)
	_ghost_view.rotation = fr[i * 4 + 2]
	_ghost_view.scale = Vector2(s, s)
	_ghost_view.wheel_angle = gx / 4.0
	_ghost_view.anim_t = _vis_t
	_ghost_view.queue_redraw()


func _puff(at: Vector2, n: int, c: Color, z := INF) -> void:
	if headless:
		return
	var v := _view(at, z)
	for i in n:
		var a := randf() * TAU
		var sp := randf_range(20.0, 70.0)
		_particles.append({"p": v, "v": Vector2(cos(a), sin(a)) * sp + Vector2(0, -20),
			"life": 22, "max": 22, "c": c, "s": 1.0 + float(randi() % 2), "g": 160.0})


## PAINTBALL: a splat of your paint on the deck (kept, oldest first to go).
func _splat(at: Vector2, size: float) -> void:
	if headless or at.y == INF:
		return
	var paint := Catalog.paint(String(loadout.get("paint", "stock")))
	_splats.append({"p": at, "lane": int(state.lane), "s": size, "seed": randi(),
		"c": paint.body if randf() < 0.6 else paint.accent})
	if _splats.size() > MAX_SPLATS:
		_splats.pop_front()


func _draw_splats(ci: CanvasItem, lane: int, left: float, right: float) -> void:
	for sp in _splats:
		var p: Vector2 = sp.p
		if int(sp.lane) != lane or p.x < left - 30.0 or p.x > right + 30.0:
			continue
		var r := RandomNumberGenerator.new()
		r.seed = int(sp.seed)
		var k := float(sp.s)
		var c: Color = sp.c
		ci.draw_rect(Rect2(p.x - 6.0 * k, p.y - 1, 12.0 * k, 2), c)
		for i in int(5 * k):
			var dx := r.randf_range(-11.0, 11.0) * k
			var w := r.randf_range(1.0, 3.0)
			ci.draw_rect(Rect2(floorf(p.x + dx), p.y - 1 - floorf(r.randf_range(0.0, 2.0)), w, 1 + floorf(r.randf_range(0.0, 2.0))), c.darkened(r.randf_range(0.0, 0.25)))


func _splash(at: Vector2) -> void:
	if headless:
		return
	var v := _view(at)
	for i in 10:
		var dir := -1.0 if i % 2 == 0 else 1.0
		_particles.append({"p": v + Vector2(dir * 3, -1),
			"v": Vector2(dir * randf_range(20, 70), randf_range(-90, -40)),
			"life": 20, "max": 20, "c": Color(0.75, 0.88, 1.0, 0.9), "s": 1.0, "g": 320.0})


func _float(at: Vector2, text: String, c: Color, z := INF) -> void:
	if headless:
		return
	_floaters.append({"p": _view(at, z), "text": text, "c": c, "life": 50, "max": 50})


## What's near the view, so drawing doesn't walk every item of a long course each
## frame: indices per kind within win_half px of where the camera was when it was last
## worked out (again whenever the camera has moved WIN_MOVE px).
var win_half := 1200.0  # dev: --no-window sets it huge to compare against drawing everything
const WIN_MOVE := 400.0
var _win := {}
var _win_x := INF


func _update_window() -> void:
	var cx := cam.position.x
	if absf(cx - _win_x) < WIN_MOVE and not _win.is_empty():
		return
	_win_x = cx
	var lo := cx - win_half
	var hi := cx + win_half
	var w := {}
	for key in ["tracks", "ceils", "loops", "springs", "switches", "zips", "ropes", "pickups", "powerups", "enemies"]:
		var out := []
		var arr: Array = level.get(key, [])
		for i in arr.size():
			var it: Dictionary = arr[i]
			var a := 0.0
			var b := 0.0
			match key:
				"tracks", "ceils", "zips":
					a = float(it.x0)
					b = float(it.x1)
				"loops":
					a = float(it.x) - 120.0
					b = float(it.x) + float(it.get("shift", 0.0)) + 160.0
				"springs":
					a = float(it.x)
					b = a
				"switches":
					a = float(it.x) - float(it.w) - 80.0
					b = float(it.x) + float(it.len) + float(it.w) + 80.0
				"ropes":
					a = float(it.ax) - float(it.len) * 1.4 - 140.0
					b = float(it.ax) + float(it.len) * 1.4 + 140.0
				"pickups", "powerups":
					a = it.pos.x
					b = a
				"enemies":
					var drift := float(it.get("drift", 0.0))
					a = float(it.x0) - drift - 60.0
					b = float(it.get("x1", it.x0)) + drift + 60.0
			if b >= lo and a <= hi:
				out.append(i)
		w[key] = out
	_win = w


## Everything in one lane, drawn in that lane's own coordinates.
func draw_lane(ci: CanvasItem, lane: int) -> void:
	if cam == null:
		return
	_update_window()
	var z := float(lane)
	var s := lane_scale(z)
	var oy := lane_oy(z)
	var vs := get_viewport_rect().size
	var c := cam.position
	# Switch ramps that swing between this lane and a farther one sit behind it.
	_draw_switch_ramps(ci, lane)
	ci.draw_set_transform(_lane_origin(z), 0.0, Vector2(s, s))
	var left := c.x - (vs.x * 0.5 + 48.0) / s
	var right := c.x + (vs.x * 0.5 + 48.0) / s
	var top := c.y + (-vs.y * 0.5 - 8.0 - oy) / s
	var bottom := c.y + (vs.y * 0.5 + 8.0 - oy) / s
	var night: bool = theme.time == "night"
	# Collapse chase: everything behind the front has fallen into the canyon.
	var cut := float(state.chase_x) if float(state.chase_x) > -INF else -INF
	var tl := maxf(left, cut)
	for wi in _win.ceils:
		var cl: Dictionary = level.ceils[wi]
		if int(cl.lane) == lane and cl.x1 > tl and cl.x0 < right:
			Art.tunnel_back(ci, cl, theme, bottom, _vis_t, night)
	WorldArt.draw_tracks(ci, level.tracks, lane, tl, right, bottom, theme, _style, _vis_t, state.t, night, _win.tracks)
	_draw_crumble(ci, lane, tl, right, bottom, night)
	if not _splats.is_empty():
		_draw_splats(ci, lane, tl, right)
	for wi in _win.loops:
		var L: Dictionary = level.loops[wi]
		if int(L.lane) == lane and float(L.x) + 90.0 > left and float(L.x) - 60.0 < right:
			Art.loop(ci, L, theme, bottom)
	for wi in _win.ceils:
		var cl: Dictionary = level.ceils[wi]
		if int(cl.lane) == lane and cl.x1 > tl - 40.0 and cl.x0 < right + 40.0:
			Art.tunnel_front(ci, cl, theme, top, _vis_t)
	if cut > left:
		_draw_collapse(ci, cut, top, bottom)
	for wi in _win.springs:
		var sp: Dictionary = level.springs[wi]
		if int(sp.lane) == lane and sp.x > left and sp.x < right:
			Art.spring(ci, sp.x, Phys.height_at(level.tracks[sp.track], sp.x), _vis_t - float(sp.get("fired", -10.0)))
	for wi in _win.switches:
		var w: Dictionary = level.switches[wi]
		if int(w.lane) == lane and w.x > left - 40.0 and w.x < right + 40.0:
			WorldArt.switch_plate(ci, w.x, Phys.height_at(level.tracks[w.track], w.x),
				float(w.to_lane) - float(w.lane), float(w.w), _vis_t)
	for wi in _win.zips:
		var zz: Dictionary = level.zips[wi]
		if int(zz.lane) == lane and zz.x1 > left and zz.x0 < right:
			Art.zip(ci, zz, _ground_y_or(zz.x0, bottom, lane), _ground_y_or(zz.x1, bottom, lane), theme)
	var on_hold := int(state.track) if state.grounded and Phys.attachment(level, state) in ["rail", "wall"] else -1
	WorldArt.draw_holds(ci, level.tracks, lane, tl, right, bottom, theme, _style, _vis_t, on_hold, _win.tracks)
	for ri in _win.ropes:
		var rp: Dictionary = level.ropes[ri]
		if int(rp.lane) != lane or float(rp.ax) + 120.0 < left or float(rp.ax) - 120.0 > right:
			continue
		var end := Vector2.INF
		if int(state.rope) == ri:
			var a := float(state.rope_a)
			end = Vector2(rp.ax, rp.ay) + float(state.rope_r) * Vector2(sin(a), cos(a))
		Art.rope(ci, rp, end, _vis_t, theme, String(_style.get("rope", "beam")), _rope_cue(ri, rp))
	_draw_markers(ci, lane, left, right)
	_draw_pickups(ci, lane, left, right)
	for i in _win.powerups:
		var pu: Dictionary = level.powerups[i]
		if int(pu.lane) == lane and not (state.got as Dictionary).has(i) and pu.pos.x > left and pu.pos.x < right:
			Icons.power(ci, (pu.pos + Vector2(0, sin(_vis_t * 3.0 + pu.pos.x) * 2.0)).floor(), String(pu.kind), _vis_t)
	_draw_enemies(ci, lane, left, right)
	if lane == 0 and boss_vis.size() > 0:
		_draw_boss(ci)
	if lane == 0 and not plane.is_empty():
		if plane.prize:
			var sack := prize_pos()
			ci.draw_circle(Vector2(sack.x, _ground_y(sack.x, 0) - 1), 4.0, Color(0, 0, 0, 0.22))
		Art.plane(ci, Vector2(plane.x, plane.y), _vis_t, PLANE_ROPE, plane.prize, sin(float(plane.waggle) * 14.0) * float(plane.waggle) * 3.0)
	if lane == int(state.lane) and phase != "crash":
		for tp in _trail:
			if int(tp.lane) != lane:
				continue
			var k: float = float(tp.life) / 10.0
			ci.draw_set_transform(_lane_origin(z) + tp.p * s, tp.a, Vector2(s, s))
			ci.draw_rect(Rect2(-12, -14, 22, 10), Color(1.0, 0.95, 0.8, 0.12 * k))
		ci.draw_set_transform(_lane_origin(z), 0.0, Vector2(s, s))
		if int(state.zip) >= 0:
			var zp: Dictionary = level.zips[state.zip]
			var grip := Vector2(state.x + 4.0, state.y - Phys.HEIGHT - 1.0)
			Art.trolley(ci, Vector2(state.x + 4.0, Phys.cable_y(zp, state.x + 4.0)), grip)
		if float(state.magnet_t) > 0.0 and phase == "ride":
			var mc := Phys.bike_center(level, state)
			var pulse := fmod(_vis_t * 1.6, 1.0)
			ci.draw_arc(mc, MAGNET_R * (1.0 - pulse), 0.0, TAU, 32, Color(1.0, 0.45, 0.4, 0.35 * pulse), -1.0)
			ci.draw_arc(mc, 12.0, 0.0, TAU, 16, Color(1.0, 0.45, 0.4, 0.25), -1.0)
		if state.ab == "tough" and int(state.armor) > 0 and phase == "ride":
			var sp2 := Vector2(state.x - 2, state.y - 26).floor()
			ci.draw_arc(sp2, 3.0, 0.0, TAU, 10, Color(0.85, 0.9, 1.0, 0.55 + 0.25 * sin(_vis_t * 4.0)), -1.0)
		if night:
			_draw_headlight(ci)
	ci.draw_set_transform(Vector2.ZERO)


## The boss flies to its next window (the weak spot is a fixed place in the world) and
## hovers ahead of you between windows. Knocked out, it drops its part and limps off.
func _boss_tick() -> void:
	var b: Dictionary = level.boss
	var tgt := Vector2.INF
	if int(state.boss_hp) > 0:
		for wi in b.windows.size():
			var w: Dictionary = b.windows[wi]
			if (state.boss_used as Dictionary).has(wi) or float(w.x) < float(state.x) - 30.0:
				continue
			if float(w.x) - float(state.x) < 420.0:
				tgt = BossArt.anchor(String(b.kind), Phys.boss_rects(level, wi, state.t)[0])
			break
		if tgt == Vector2.INF:
			tgt = Vector2(float(state.x) + 230.0, _focus_y - 110.0 + sin(_vis_t * 1.3) * 8.0)
		boss_vis.pos = (boss_vis.pos as Vector2).lerp(tgt, 0.07 if (boss_vis.pos as Vector2).distance_to(tgt) > 6.0 else 0.3)
	else:
		boss_vis.flee = float(boss_vis.flee) + Phys.DT
		boss_vis.pos = (boss_vis.pos as Vector2) + Vector2(60.0, -70.0 - 120.0 * float(boss_vis.flee)) * Phys.DT
		if ticks % 3 == 0:
			_particles.append({"p": _view(boss_vis.pos), "v": Vector2(randf_range(-40, 10), randf_range(-20, 20)),
				"life": 24, "max": 24, "c": Color(0.4, 0.4, 0.45, 0.8), "s": 2.0, "g": -30.0})
	boss_vis.hurt = maxf(0.0, float(boss_vis.hurt) - 0.04)
	var d: Dictionary = boss_vis.drop
	if not d.is_empty() and not d.got:
		d.v.y += 500.0 * Phys.DT
		var np: Vector2 = d.p + d.v * Phys.DT
		var gy := _ground_y_or(np.x, INF, 0)
		if gy < INF and np.y > gy - 6.0 and d.p.y <= gy - 6.0:
			np.y = gy - 6.0
			d.v = Vector2(d.v.x * 0.4, -d.v.y * 0.3)
		d.p = np
		if Phys.bike_rect(state, level).grow(10.0).has_point(d.p) or float(state.x) > d.p.x + 30.0:
			d.got = true
			_float(d.p + Vector2(0, -16), "%s!" % BossArt.part_name(boss_part), Icons.GOLD, 0.0)
			_puff(d.p, 16, Icons.GOLD)
			_sfx("part_get")
			_vibrate(50)


func _draw_boss(ci: CanvasItem) -> void:
	var b: Dictionary = level.boss
	var p: Vector2 = boss_vis.pos
	var has_part := int(state.boss_hp) > 0
	BossArt.draw(ci, String(b.kind), p.floor(), _vis_t, float(boss_vis.hurt), int(state.boss_hp), boss_part if has_part else "",
		_focus_y + 120.0)
	var d: Dictionary = boss_vis.drop
	if not d.is_empty() and not d.got:
		ci.draw_circle(d.p, 10.0, Color(Icons.GOLD, 0.2 + 0.1 * sin(_vis_t * 8.0)))
		Icons.part(ci, d.p.floor(), boss_part, 1.0)


## Planks that swing between two lanes, drawn in camera space (each plank at its
## own depth). Drawn by the nearer of the two lanes, before its own things.
func _draw_switch_ramps(ci: CanvasItem, lane: int) -> void:
	var vs := get_viewport_rect().size
	_update_window()
	for wi in _win.switches:
		var w: Dictionary = level.switches[wi]
		var la := int(w.lane)
		var lb := int(w.to_lane)
		if mini(la, lb) != lane:
			continue
		var x0: float = w.x - float(w.w)
		var x1: float = x0 + float(w.len) + float(w.w)
		var cx := cam.position.x
		if _view(Vector2(x1, 0), float(la)).x < cx - vs.x or _view(Vector2(x0, 0), float(la)).x > cx + vs.x:
			continue
		var from: Dictionary = level.tracks[w.track]
		var to: Dictionary = level.tracks[w.to_track]
		var n := 16
		var prev_top := Vector2.INF
		var prev_bot := Vector2.INF
		for i in n + 1:
			var u := float(i) / float(n)
			var k := smoothstep(0.0, 1.0, u)
			var x := lerpf(x0 + float(w.w), x1, u)
			var zz := lerpf(float(la), float(lb), k)
			var y := lerpf(Phys.height_at(from, x), Phys.height_at(to, x), k)
			var top := _view(Vector2(x, y), zz)
			var bot := _view(Vector2(x, y + 5.0), zz)
			if prev_top != Vector2.INF:
				ci.draw_colored_polygon(PackedVector2Array([prev_top, top, bot, prev_bot]), theme.deck)
				ci.draw_line(prev_top, top, theme.deck_hi, -1.0)
				ci.draw_line(prev_bot, bot, theme.beam_dark, -1.0)
			if i % 4 == 2:
				var foot := _view(Vector2(x, y + 60.0), zz)
				ci.draw_line(bot, foot, Color(theme.beam, 0.8), -1.0)
			prev_top = top
			prev_bot = bot


## Particles and floating text, already in camera space.
func draw_fx(ci: CanvasItem) -> void:
	if guide_on and not guide.is_empty() and phase != "crash":
		_draw_guide(ci)
	for p in _particles:
		ci.draw_rect(Rect2(floorf(p.p.x), floorf(p.p.y), p.s, p.s), Color(p.c, p.c.a * float(p.life) / p.max))
	var font: Font = GameState.font
	for f in _floaters:
		var a := clampf(float(f.life) / 15.0, 0.0, 1.0)
		var tw: float = ceilf(maxf(140.0, font.get_string_size(f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 8.0) * 0.5) * 2.0
		ci.draw_string(font, Vector2(f.p.x - tw * 0.5 + 1, f.p.y + 1), f.text, HORIZONTAL_ALIGNMENT_CENTER, tw, 8, Color(0, 0, 0, a))
		ci.draw_string(font, Vector2(f.p.x - tw * 0.5, f.p.y), f.text, HORIZONTAL_ALIGNMENT_CENTER, tw, 8, Color(f.c, a))


## The hint line: a dot every few frames ahead of the bike (blue while the button
## should be down), with TAP / HOLD / LET GO tags where the button changes.
func _draw_guide(ci: CanvasItem) -> void:
	var pts: PackedVector2Array = guide.pts
	var zs: PackedFloat32Array = guide.z
	var hd: PackedByteArray = guide.held
	var bx := float(state.x) - 2.0
	var font: Font = GameState.font
	for i in range(0, pts.size(), 3):
		var p: Vector2 = pts[i]
		if p.x < bx:
			continue
		var v := _view(p + Vector2(0, -7), zs[i]).floor()
		var on := hd[i] == 1
		var w := 0.6 + 0.4 * sin(_vis_t * 7.0 - i * 0.18)
		var sz := 3.0 if on else 2.0
		ci.draw_rect(Rect2(v - Vector2(sz, sz) * 0.5 + Vector2(1, 1), Vector2(sz, sz)), Color(0, 0, 0, 0.45 * w))
		ci.draw_rect(Rect2(v - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), Color(Color("7fe0ff") if on else Color("fff4d0"), 0.95 * w))
	for m in guide.marks:
		var i := int(m[0])
		if i >= pts.size() or pts[i].x < bx - 30.0:
			continue
		var label := String(m[1])
		var c := Icons.GOLD if label == "TAP" else (Color("7fe0ff") if label == "HOLD" else Color("ff9a6a"))
		var v := _view(pts[i] + Vector2(0, -7), zs[i]).floor()
		var bob := floorf(2.0 * sin(_vis_t * 5.0))
		var top := v + Vector2(0, -22 + bob)
		ci.draw_line(top + Vector2(0, 4), v + Vector2(0, -4), Color(c, 0.8), 1.0)
		ci.draw_colored_polygon(PackedVector2Array([v + Vector2(-3, -6), v + Vector2(3, -6), v + Vector2(0, -3)]), c)
		var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		ci.draw_rect(Rect2(top.x - tw * 0.5 - 3, top.y - 8, tw + 6, 11), Color(0.05, 0.04, 0.08, 0.8))
		ci.draw_string(font, Vector2(top.x - tw * 0.5, top.y + 1), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, c)


func _ground_y_or(px: float, fallback: float, lane := 0) -> float:
	for ti in Phys.tracks_near(level, px, lane):
		var tr: Dictionary = level.tracks[ti]
		if px >= tr.x0 and px <= tr.x1 and not tr.side:
			return Phys.height_at(tr, px)
	return fallback


func _ground_y(px: float, lane := 0) -> float:
	return _ground_y_or(px, state.y, lane)


func _draw_markers(ci: CanvasItem, lane: int, left: float, right: float) -> void:
	for i in level.checkpoints.size():
		var c: Dictionary = level.checkpoints[i]
		if c.x < left or c.x > right or int(level.tracks[c.track].get("lane", 0)) != lane:
			continue
		var ty := Phys.height_at(level.tracks[c.track], c.x)
		var reached: bool = i < _next_cp
		ci.draw_line(Vector2(c.x, ty), Vector2(c.x, ty - 28), Color("d8d8d8"), -1.0)
		var wave := sin(_vis_t * 6.0) * 1.5
		var col := Color("5bd16a") if reached else Color("e04848")
		ci.draw_colored_polygon(PackedVector2Array([Vector2(c.x + 1, ty - 28), Vector2(c.x + 12, ty - 24 + wave),
			Vector2(c.x + 1, ty - 20)]), col)
	var fx: float = level.finish_x
	if lane == 0 and fx > left - 40 and fx < right + 40:
		var tr_y := _ground_y(fx, 0)
		for sx in [fx - 22.0, fx + 22.0]:
			ci.draw_rect(Rect2(sx - 1, tr_y - 46, 3, 46), Color("d8d8d8"))
		for i in 22:
			for j in 4:
				var col := Color("f4f4f4") if (i + j) % 2 == 0 else Color("1a1a1a")
				ci.draw_rect(Rect2(fx - 22 + i * 2, tr_y - 50 + j * 2, 2, 2), col)


func _draw_pickups(ci: CanvasItem, lane: int, left: float, right: float) -> void:
	for wi in _win.pickups:
		var p: Dictionary = level.pickups[wi]
		if not p.alive or int(p.lane) != lane or p.pos.x < left or p.pos.x > right:
			continue
		var pos: Vector2 = p.pos
		match int(p.type):
			Library.P_COIN:
				Icons.coin(ci, pos.floor(), cos(_vis_t * 5.0 + pos.x * 0.05))
			Library.P_BAG:
				Icons.bag(ci, pos.floor() + Vector2(0, sin(_vis_t * 3.0) * 1.5).floor())
			Library.P_LETTER:
				var bob2 := Vector2(0, roundf(sin(_vis_t * 2.2 + pos.x) * 2.0))
				ci.draw_circle(pos + bob2, 9.0, Color(Icons.GOLD, 0.15 + 0.08 * sin(_vis_t * 5.0)))
				Icons.letter(ci, pos + bob2, Library.LETTERS[int(p.letter)])
			Library.P_GEAR:
				var ghost: bool = known_gears[int(p.gear)]
				var bob := Vector2(0, roundf(sin(_vis_t * 2.5) * 2.0))
				if not ghost:
					ci.draw_circle(pos + bob, 10.0, Color(Icons.BRASS, 0.18 + 0.08 * sin(_vis_t * 4.0)))
				Icons.gear(ci, pos + bob, 6.0, _vis_t * 1.5, true, 0.4 if ghost else 1.0)


func _draw_enemies(ci: CanvasItem, lane: int, left: float, right: float) -> void:
	var night: bool = theme.time == "night"
	for wi in _win.enemies:
		var e: Dictionary = level.enemies[wi]
		if int(e.lane) != lane:
			continue
		if not e.alive:
			if e.has("squash_t") and _vis_t - e.squash_t < 0.5:
				var sp: Vector2 = e.squash_pos
				ci.draw_rect(Rect2(sp.x - 8, sp.y - 3, 16, 3), Color("7a3a16"))
				ci.draw_rect(Rect2(sp.x - 7, sp.y - 4, 14, 1), Color("c8692a"))
			continue
		var p := Phys.enemy_pos(level, e, state.t)
		if p.x < left or p.x > right:
			continue
		var glow := Vector2.INF
		match int(e.type):
			Phys.CRAWLER:
				var ahead := Phys.enemy_pos(level, e, state.t + 0.05)
				var face := -1.0 if ahead.x <= p.x else 1.0
				glow = WorldArt.crawler(ci, p.floor(), face, _style.crawler, _vis_t)
			Phys.SPIKER:
				glow = WorldArt.spiker(ci, p.floor(), _style.spiker, _vis_t)
			Phys.DRONE:
				# Drones fly in from the background and settle into their real spot
				# >= SWOOP_SETTLE px before the rider reaches them; a shadow marks it.
				var dx: float = p.x - float(state.x)
				var k := smoothstep(0.0, 1.0, clampf((dx - SWOOP_SETTLE) / SWOOP_RANGE, 0.0, 1.0))
				if k > 0.0:
					var gy := _ground_y(p.x, lane)
					ci.draw_circle(Vector2(p.x, gy - 1), 6.0 - 3.0 * k, Color(0, 0, 0, 0.25 * (1.0 - k)))
					var vp := (p + Vector2(18.0 * k, -42.0 * k)).floor()
					var s := lane_scale(float(lane))
					ci.draw_set_transform(_lane_origin(float(lane)) + vp * s, 0.0, Vector2.ONE * s * (1.0 - 0.5 * k))
					WorldArt.drone(ci, Vector2.ZERO, _style.drone, _vis_t, k * 0.6, theme.mid)
					ci.draw_set_transform(_lane_origin(float(lane)), 0.0, Vector2(s, s))
				else:
					glow = WorldArt.drone(ci, p.floor(), _style.drone, _vis_t)
		if night and glow != Vector2.INF:
			ci.draw_circle(glow, 4.0, Color(1.0, 0.35, 0.25, 0.22 + 0.08 * sin(_vis_t * 6.0)))


## Crumbling planks: whole until touched, then they shake and drop away.
func _draw_crumble(ci: CanvasItem, lane: int, left: float, right: float, bottom: float, night: bool) -> void:
	var z := float(lane)
	var s := lane_scale(z)
	var crumb: Dictionary = state.crumb
	for ti in _win.tracks:
		var tr: Dictionary = level.tracks[ti]
		if not tr.has("crumble") or int(tr.lane) != lane or tr.x1 < left or tr.x0 > right:
			continue
		var off := Vector2.ZERO
		var rot := 0.0
		if crumb.has(ti):
			var dt := float(state.t) - float(crumb[ti])
			var hold := float(tr.crumble)
			if dt < hold:
				off.x = sin(dt * 90.0) * 1.0
				off.y = dt / hold * 2.0
			else:
				var f := dt - hold
				off.y = 2.0 + 0.5 * 900.0 * f * f
				rot = f * 1.4 * (1.0 if ti % 2 == 0 else -1.0)
				if off.y > 400.0:
					continue
		var mid := Vector2((tr.x0 + tr.x1) * 0.5, Phys.height_at(tr, (tr.x0 + tr.x1) * 0.5))
		ci.draw_set_transform(_lane_origin(z) + (mid + off) * s, rot, Vector2(s, s))
		var w: float = tr.x1 - tr.x0 - 1.0  # a hairline gap between the old planks
		var old := (theme.deck as Color).lerp(Color("8a8478"), 0.45)
		ci.draw_rect(Rect2(-w * 0.5, 0, w, 4), old)
		ci.draw_rect(Rect2(-w * 0.5, 0, w, 1), (theme.deck_hi as Color).lerp(Color("b8b0a0"), 0.4))
		ci.draw_rect(Rect2(-w * 0.5, 4, w, 1), theme.beam_dark)
		# Cracks mark the old planks.
		var k := -w * 0.5 + 6.0
		while k < w * 0.5 - 4.0:
			ci.draw_line(Vector2(k, 0), Vector2(k + 3, 3), Color(theme.beam_dark, 0.9), -1.0)
			k += 11.0
		for px in [-w * 0.5 + 4.0, w * 0.5 - 6.0]:
			ci.draw_rect(Rect2(px, 5, 3, minf(70.0, bottom - mid.y)), Color(theme.beam, 0.9))
		if night:
			ci.draw_rect(Rect2(-w * 0.5, 0, w, 5), Color(0, 0, 0, 0.2))
	ci.draw_set_transform(_lane_origin(z), 0.0, Vector2(s, s))


## The collapse front: a churning wall of dust where the trestle is falling away.
func _draw_collapse(ci: CanvasItem, fx: float, top: float, bottom: float) -> void:
	var dust := (theme.mid as Color).lerp(theme.deck_hi, 0.35)
	var gy := _ground_y_or(fx + 6.0, float(state.y), 0)
	for i in 9:
		var hgt := gy - 10.0 - i * 13.0
		var wob := sin(_vis_t * 3.0 + i * 1.7) * 5.0
		ci.draw_circle(Vector2(fx - 8.0 + wob, hgt), 14.0 + (i % 3) * 4.0, Color(dust, 0.55 - i * 0.04))
	ci.draw_rect(Rect2(fx - 600.0, top, 592.0, bottom - top), Color(dust.darkened(0.3), 0.18))


## Night: a warm cone from the headlight.
func _draw_headlight(ci: CanvasItem) -> void:
	var o := Vector2(state.x, state.y)
	var rot := Transform2D(_angle, Vector2.ZERO)
	var src := o + rot * Vector2(8, -12)
	var fwd := rot * Vector2(1, 0)
	var side := rot * Vector2(0, 1)
	var far := src + fwd * 130.0
	ci.draw_colored_polygon(PackedVector2Array([src - side * 2.0, far - side * 22.0, far + side * 30.0, src + side * 2.0]),
		Color(1.0, 0.93, 0.65, 0.07))
	var mid := src + fwd * 70.0
	ci.draw_colored_polygon(PackedVector2Array([src - side * 1.5, mid - side * 9.0, mid + side * 14.0, src + side * 1.5]),
		Color(1.0, 0.93, 0.65, 0.09))
