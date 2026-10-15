# Trestle Run (working title)

One-button motorcycle runner for Android/iOS, built in **Godot 4.7** (GL Compatibility renderer, 2D pixel art drawn in code). Inspired by the mine-cart *mechanic*, with original names, art and characters throughout.

## Gameplay

- The bike rides automatically along canyon trestles. **Tap = short hop, hold = full jump** (variable height, with coyote time and jump buffering).
- **Branching routes:** upper decks you reach by jumping (or a spring), and hidden lower decks that merge back up.
- **Enemies**
  - *Crawler* (orange shell): stomp it from above for a bounce and +2 coins; touching its side crashes you.
  - *Spiker* (spiked ball): can't be stomped, jump over it.
  - *Drone* (spiked top, hovering): can't be stomped, stay low and ride under it.
- **Pickups:** coins, money bags (+10), and 3 hidden **gears** per trail (25 coins each, paid once).
- Checkpoints mid-trail; crashes respawn you there. Coins only bank when you finish.
- **Payout** per clear = coins + conditions bonus + new gears + clear bonus + no-crash bonus. Results also show your time and best time.

### Trails

Nine trails, each adding one new thing on top of the earlier ones. Speed, gap widths and hazard density climb from trail to trail.

| # | Trail | Speed | New feature | How to get past it |
|---|---|---|---|---|
| 1 | Dusty Trail | 118 | Jumping | Tap for a hop, hold for a big jump |
| 2 | Copper Canyon | 122 | Crawlers | Land on top to stomp; hold during the bounce to go higher |
| 3 | Rustyard | 126 | Spikers | Jump clean over; land between pairs and hop again |
| 4 | Night Trestle | 130 | Drones | Stay low; over a gap use a quick tap so you stay under |
| 5 | Mesa Springs | 134 | Springs | Roll onto the pad to fly high and far; hop over it to stay low |
| 6 | Lantern Mine | 138 | Low ceilings | Taps only: a big jump bonks your head and drops you short |
| 7 | Hoodoo Loops | 142 | Loop-the-loops | Keep rolling; press as you come out if there's a gap |
| 8 | Hoist Yard | 146 | Bobbing lifts | Time the jump to come down on the next lift |
| 9 | Skyline Pass | 150 | Ziplines | Long hold to grab the cable, keep holding, let go over the far deck |

**Hints:** the in-run **?** button (top right) pauses and opens a card explaining the trail's new feature, with a live demo of the autopilot riding it. On a first visit the button pulses and a small "NEW: ..." tag shows for a few seconds; there is no splash screen. The trail picker has the same card behind **? TIPS**, and each trail card names its feature.

**Difficulty ramp**, measured by `--difficulty` (see Dev checks). For every jump a trail forces, it finds how long the window of frames is in which pressing still gets you past (pressing in the middle of the window, like a person would):

| # | Trail | Speed | Tightest window: clear / rain / wind | 10th percentile (clear) | Forced jumps per 10 s |
|---|---|---|---|---|---|
| 1 | Dusty Trail | 118 | 333 / 283 / 233 ms | 350 ms | 3.4 |
| 2 | Copper Canyon | 122 | 183 / 183 / 166 ms | 233 ms | 4.4 |
| 3 | Rustyard | 126 | 183 / 166 / 133 ms | 216 ms | 5.8 |
| 4 | Night Trestle | 130 | 166 / 183 / 133 ms | 183 ms | 3.6 |
| 5 | Mesa Springs | 134 | 166 / 166 / 83 ms | 183 ms | 2.6 |
| 6 | Lantern Mine | 138 | 116 / 83 / 83 ms | 166 ms | 3.5 |
| 7 | Hoodoo Loops | 142 | 100 / 133 / 133 ms | 150 ms | 4.1 |
| 8 | Hoist Yard | 146 | 116 / 100 / 66 ms | 166 ms | 5.7 |
| 9 | Skyline Pass | 150 | 166 / 83 / 83 ms | 166 ms | 4.6 |

Speed climbs every trail and each one adds a mechanic on top of the timing; the tightest windows shrink from a third of a second to around 0.1 s, and no spot needs frame-perfect timing in any weather (the tightest anywhere is 66 ms, Hoist Yard in wind). For comparison, the v0.4 trails measured the same way: Trail 2 (Copper Canyon at 136 px/s) had a 16 ms, one-frame spot at its split-deck section, and Trail 3 had a stretch the careful rider couldn't get through at all.

### Bike specialties

Every bike keeps the same one-button control and hitbox; each adds one move.

| Bike | Specialty | How |
|---|---|---|
| Scrambler | Wheelie +10% | Keep holding as you land: front wheel up, speed builds while you hold, then bleeds off |
| Dirt bike | Big wheelie +14% | Same, stronger |
| Sportbike | Power wheelie +18% | Same, strongest |
| Minibike | Double hop | Tap again in the air for one more hop |
| Scooter | Umbrella | Hold while falling to float down slowly |
| Cafe racer | Air dash | Tap in the air to dash forward |
| Chopper | Iron hide | Smash through one enemy per checkpoint (falls still count) |

An air press within a few pixels of landing still counts as a buffered jump rather than a specialty move. The garage shows each bike's specialty; the HUD names it bottom left and lights it while it's active.

### Bonus plane

Every 22-38 s a biplane overtakes you with a prize sack on a rope (10 coins on Trail 1, +3 per trail). It is only sent when the stretch where it will catch up is calm (plain deck, nothing to jump or dodge), and its speed is set so the sack reaches you right there, hanging where a good long jump grabs it. You hear it coming from behind.

### Garage

Mix and match three things, each bought with coins (`scripts/catalog.gd`):

- **Riders (8):** Dusty, Granny Grit (scarf), Bandit (raccoon), Bones (skeleton, hair on fire), Zorp (alien), Robo-7, Finn (land shark), Big Frosty (yeti). Scarves, tails and flames stream harder in wind and in the air.
- **Bikes (7):** scrambler, dirt bike, minibike, scooter, cafe racer, chopper, sportbike.
- **Paint (6):** colour schemes applied to whichever bike you ride.

All bikes and riders share one hitbox and every trail is beatable on any bike; bikes differ by specialty (below).

### Ride conditions

Tapping RIDE opens a picker; the choice is remembered.

- **Time:** day, dusk, night. Each trail has its own palette for all three. At night your headlight lights the deck ahead and enemy eyes glow.
- **Weather:**
  - *Clear*
  - *Rain:* jumps are ~5% shorter (weaker takeoff on a wet deck) and you slide forward ~13 px after landing before the tyre grips again.
  - *Wind:* gusty headwind slows you only while airborne; full jumps come up 8–15% short depending on the gust. The HUD gauge shows the current gust.
- **Coin bonus:** night +10%, rain +25%, wind +25% on run coins.

Tuning lives at the top of `scripts/game/bike_physics.gd` (`RAIN_TAKEOFF`, `RAIN_SLIDE`, `GRIP_WET`, `WIND_PEAK`, `WIND_DRAG`).

### Depth (2.5D parallax)

Layers in front of and behind the play plane scroll at their own rates, and things happen in them (`scripts/game/depth.gd`). All of it is visual only and never touches the physics.

| Layer | Scroll | What happens |
|---|---|---|
| Far | 0.18x | A high trestle bridge across the far valley. Every 30–55 s a train crosses it (lit windows at dusk/night, smoke by day), with a soft distant horn in the theme's key. Hot-air balloon and a circling hawk by day. |
| Mid | 0.35x | Bats at dusk. In rain: lightning forks behind the hills, the sky flashes, thunder rolls in 1–2 s later. |
| Valley lane | 0.6x | A lower trestle in the valley. Two rival riders (other garage characters, hazed by distance) race you, drifting ahead and behind, jumping its gaps and sometimes backflipping. |
| Play plane | 1.0x | You. Drones now swoop in from the background (small, hazed, high) and settle into their real spot at least 190 px before you reach them, with a shadow on the deck marking where they'll be. |
| Foreground | 1.6x | Dark silhouettes per trail (saguaros, boulders, scrap, telegraph poles), grass tufts, fireflies at dusk/night, dust motes by day, tumbleweeds in wind. Kept to the bottom quarter, plus an occasional see-through post whipping past. |

The title screen runs the far and valley layers too, so rivals race behind the menu.

### Sound

- **Engines:** every bike model has its own engine, built from that engine's real firing order (V-twin chopper, 270-degree parallel twin, single, inline-4, inline-3, 2-stroke scooter, 212cc minibike). Idle at READY, launch to cruise at GO; pitch follows speed (rain slides, wind drag) and flares when the rear wheel is in the air. Equipping a bike in the garage blips its throttle.
- **Ambience:** birds by day; crickets at dusk and night; a creek under Copper Canyon. Rain adds a rain bed. In wind, the wind recording's volume follows the same gust curve that pushes the bike.
- **Foley:** soft chimes tuned to the theme's key (coin streaks climb a pentatonic ladder), a soft whoosh on jumps, wooden thock on landings, splash in rain, plank-joint "ta-dak" while rolling, gentle crash with a falling two-note chime. Springs boing up a fifth, roof bonks knock, loops swoop, ziplines clink on and whine along the cable, and the bonus biplane drones in from behind with a Doppler drop as it passes.
- **Coins:** each coin is a short, dry chime (rings out in about 0.3 s, down from 1.1 s), and two coin voices alternate with each new coin damping the last, so a fast streak plays as separate notes.
- **Theme:** "Trestle Dreams", an original dreamy desert-Americana loop (tremolo guitar, pad, brushes, slide melody).
- **Settings:** MUSIC and SOUND sliders (0–100%, squared taper so 50% sounds about half as loud) under SETTINGS on the title screen and in the pause menu. Sources and licenses: `CREDITS.md` and the in-game Credits screen.
- **Mix:** set from Movie Maker captures of real gameplay with each bus soloed: engine and theme near -24 LUFS, chimes -24, nature bed -33, about -19 LUFS overall.
- **Swapping sounds:** replace any file in `assets/audio/` with one of the same name. Engine files should loop cleanly. To use real engine recordings later, drop in `<bike>_idle.ogg` / `<bike>_cruise.ogg`.

Debug builds only: tap the wallet on the title screen 5 times for +500 coins to test unlocks.

## Run it on Arch

```bash
sudo pacman -S godot          # Godot 4.x editor
godot --path ~/trestle-run    # open the project, then F5 to play
```

`--path` points Godot at the project folder; with no other flags it opens the editor.

## Build an APK for the Pixel Fold

```bash
cd ~/trestle-run
./build-apk.sh --install
```

- `--install` installs to the phone over USB with `adb install -r` after building (`-r` replaces an existing install and keeps its save data). Leave it off to just build `build/trestle-run.apk`.

What the script does (each step is skipped if already done):

1. `pacman -S --needed` godot, jdk17-openjdk, unzip, curl (`--needed` skips what's already installed).
2. Downloads the official export templates that exactly match your Godot version and extracts only the Android ones into `~/.local/share/godot/export_templates/<version>/`. The first run is a large download.
3. Installs Google's command-line tools into `~/Android/Sdk` (Godot's default SDK path on Linux), then `platform-tools` and `build-tools;35.0.1`. For a prebuilt-template export, Godot only checks for `adb` and `apksigner`, so the NDK/CMake from the docs' full list aren't needed.
4. Creates `~/.android/debug.keystore` if missing and passes it via `GODOT_ANDROID_KEYSTORE_DEBUG_*` env vars.
5. Imports the project, pins the JDK/SDK paths in Godot's editor settings, and runs `godot --headless --export-debug "Android" build/trestle-run.apk`.

For `--install`: enable *Developer options → USB debugging* on the phone and accept the prompt when you plug it in. Without USB, copy the APK to the phone and open it (Android will ask to allow installs from that app).

Requirements per the Godot 4.7 docs ([source](https://github.com/godotengine/godot-docs/blob/4.7/tutorials/export/exporting_for_android.rst)): OpenJDK 17 plus the Android SDK. The docs warn against distro-packaged SDKs, so the script pulls Google's.

Change `package/unique_name` (`com.example.trestlerun`) to your own reverse-domain ID before any store upload; it can't change after release.

## iOS

Godot exports iOS as an Xcode project, and that export has to run on **macOS with Xcode** ([source](https://github.com/godotengine/godot-docs/blob/4.7/tutorials/export/exporting_for_ios.rst)). On an Arch daily driver that means a borrowed Mac, a Mac mini, or a hosted macOS CI runner. The iOS preset is included; it needs your 10-character App Store Team ID.

## Project layout

```
scripts/
  game_state.gd          autoload: wallet, unlocks, skins, save (user://save.json), input map, font/theme
  catalog.gd             riders, bikes, paint, levels, prices, condition bonuses   <- economy knobs
  main.gd                screen switching, Android back button
  game/
    bike_physics.gd      deterministic 60 Hz physics, track features, bike specialties <- feel knobs
    level_library.gd     chunk builders (gaps, enemies, springs, tunnels, loops, lifts, ziplines)
    level_layouts.gd     the 9 trail layouts + short hint-demo layouts   <- level design
    autopilot.gd         lookahead bot: dev verify and the hint-card demos
    world.gd             one run: sim, pickups, checkpoints, bonus plane, camera, drawing
    feature_art.gd       pixel art for springs, tunnels, loops, lifts, ziplines, biplane
    backdrop.gd          parallax themes: day/dusk/night palettes per trail, weather skies
    weather_fx.gd        screen-space rain and wind layer
    bike_view.gd         bike models + riders drawn from primitives (paint = palette)
  screens/               title, trail select, garage, game (pause/results)
  ui/                    theme, HUD, widgets, hint card (live demo in a SubViewport)
  audio/audio_director.gd  autoload: buses, engine, ambience, SFX pool, theme
  dev/                   bot, verifier, screenshots, input test, Movie Maker demo (excluded from export)
tools/audio/             python: engine models, SFX, ambience loops, theme; build.py regenerates assets/audio
```

Levels are lists of chunks, e.g. `["gap", 56.0]`, `["branch_upper", 1]` (1 = put a gear on it), `["lifts", [[56, 18, 2.2, 0]], 48]`, `["zip", 300, 62, 30, 1]`. Adding a trail means a layout in `level_layouts.gd` plus an entry in `catalog.gd` (speed, price, theme, feature); new feature text goes in `Catalog.FEATURES`.

## Dev checks

```bash
godot --headless --path . -- --verify                                  # every trail x clear/rain/wind
godot --headless --path . -- --verify --level=rustyard --weather=wind  # one combo
godot --headless --path . -- --verify --bike=all                       # every bike's specialty too
godot --headless --path . -- --difficulty [--weather=rain] [--old]     # timing-window ramp
godot --headless --path . -- --physics-report                          # jump table, weather, specialties
```

- `--headless` runs with no window or audio
- `--` ends Godot's own flags; what follows goes to the game
- `--verify` makes the bot play each trail in each weather; exit code = runs it couldn't clear without crashing
- `--level=` / `--weather=` narrow it to one trail / one weather
- `--bike=` picks a bike (its specialty is active); `all` runs all seven
- `--difficulty` rides each trail like a careful person and prints the timing windows and forced jumps per 10 s; `--old` adds the v0.4 trails for comparison

Current result (v0.5.0):
- Plain bike: all 27 runs (9 trails x 3 weathers) cleared with 0 crashes and 3/3 gears each, so every route and gear is reachable in every weather.
- Every bike with its specialty active: all 189 runs cleared with 0 crashes (in 3 of them the specialty carries the bot past one gear).
- `--input-test`: taps and holds jump through the real touch pipeline; the pause and **?** buttons never leak a jump.

## Not done yet

- In-app purchases and ads: Godot needs platform plugins for Google Play Billing, StoreKit and an ad network, plus consent handling. Next phase.
- Hand-drawn sprite art (current art is code-drawn placeholders that already read as pixel art)
- More enemy types and trails; a best-time leaderboard

Font: Press Start 2P, SIL Open Font License (`assets/fonts/OFL.txt`).
