# Trestle Run (working title)

One-button motorcycle runner for Android/iOS, built in **Godot 4.7** (GL Compatibility renderer, 2D pixel art drawn in code). Inspired by the mine-cart *mechanic*, with original names, art and characters throughout.

## Gameplay

- The bike rides automatically along canyon trestles. **Tap = short hop, hold = full jump** (variable height, with coyote time and jump buffering).
- **Branching routes:** upper decks you reach by jumping, and a hidden lower deck under some gaps that merges back up.
- **Enemies**
  - *Crawler* (orange shell): stomp it from above for a bounce and +2 coins; touching its side crashes you.
  - *Spiker* (spiked ball): can't be stomped, jump over it.
  - *Drone* (spiked top, hovering): can't be stomped, stay low and ride under it.
- **Pickups:** coins, money bags (+10), and 3 hidden **gears** per level (25 coins each, paid once).
- Checkpoints mid-level; crashes respawn you there. Coins only bank when you finish.
- **Payout** per clear = coins + conditions bonus + new gears + clear bonus + no-crash bonus.
- **Trails:** 4 levels, unlocked with coins.

### Garage

Mix and match three things, each bought with coins (`scripts/catalog.gd`):

- **Riders (8):** Dusty, Granny Grit (scarf), Bandit (raccoon), Bones (skeleton, hair on fire), Zorp (alien), Robo-7, Finn (land shark), Big Frosty (yeti). Scarves, tails and flames stream harder in wind and in the air.
- **Bikes (7):** scrambler, dirt bike, minibike, scooter, cafe racer, chopper, sportbike.
- **Paint (6):** colour schemes applied to whichever bike you ride.

All bikes and riders share one hitbox, so choices are cosmetic and every trail stays beatable with any combo.

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
- **Foley:** soft chimes tuned to the theme's key (coin streaks climb a pentatonic ladder), a soft whoosh on jumps, wooden thock on landings, splash in rain, plank-joint "ta-dak" while rolling, gentle crash with a falling two-note chime.
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
    bike_physics.gd      deterministic 60 Hz rider physics       <- feel knobs (gravity, jump, coyote)
    level_library.gd     chunk builders + level layouts          <- level design
    world.gd             one run: sim, pickups, checkpoints, camera, headlight, drawing
    backdrop.gd          parallax themes: day/dusk/night palettes per trail, weather skies
    weather_fx.gd        screen-space rain and wind layer
    bike_view.gd         bike models + riders drawn from primitives (paint = palette)
  screens/               title, trail select, garage, game (pause/results)
  ui/                    theme, HUD, widgets
  audio/audio_director.gd  autoload: buses, engine, ambience, SFX pool, theme
  dev/                   bot, verifier, screenshots, input test, Movie Maker demo (excluded from export)
tools/audio/             python: engine models, SFX, ambience loops, theme; build.py regenerates assets/audio
```

Levels are lists of chunks, e.g. `["gap", 56.0]`, `["branch_upper", 1]` (1 = put a gear on it). Adding a level means adding a layout in `level_library.gd` plus an entry in `catalog.gd`.

## Dev checks

```bash
godot --headless --path . -- --verify                                  # every trail x clear/rain/wind
godot --headless --path . -- --verify --level=rustyard --weather=wind  # one combo
godot --headless --path . -- --physics-report                          # jump distance + slide per weather
```

- `--headless` runs with no window or audio
- `--` ends Godot's own flags; what follows goes to the game
- `--verify` makes the bot play each trail in each weather; exit code = runs it couldn't clear without crashing
- `--level=` / `--weather=` narrow it to one trail / one weather

Current result: all 12 runs (4 trails x 3 weathers) cleared with 0 crashes and 3/3 gears each, so every route and gear is reachable in every weather.

## Not done yet

- In-app purchases and ads: Godot needs platform plugins for Google Play Billing, StoreKit and an ad network, plus consent handling. Next phase.
- Hand-drawn sprite art (current art is code-drawn placeholders that already read as pixel art)
- More enemy types, moving platforms, longer levels (current ones run 31–36 s)

Font: Press Start 2P, SIL Open Font License (`assets/fonts/OFL.txt`).
