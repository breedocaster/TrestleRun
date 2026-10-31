# Making art and music

How to make hand-made art and music for Trestle Run: what's needed, at what size, and how to get it into the game.

**Where things stand:**
- **Art:** every picture in the game is drawn in code with Godot's `draw_*` calls. No image files are loaded at runtime, apart from the app icon layers.
- **Sound:** the sound is code-built or recorded audio, kept as Ogg files in `assets/audio/`.

So the two halves work differently:

- **Audio drops straight in.** Replace a file and the game uses it. `tools/audio/import_audio.py` cuts the loop and matches the loudness for you.
- **Art needs wiring.** Each group of art needs a small loader (it reads the PNG, and falls back to the code drawing while there isn't one). That loader isn't written yet. Make the art to the specs below, put it under `assets/art/`, and the loader goes in group by group as the art arrives.
- **Store art is separate.** It doesn't touch the game at all, so it can be made now.

---

## Art

### The grid

- **Base resolution:** the game draws at **480 × 270** and scales up to the screen with nearest-neighbour filtering (`project.godot`: viewport 480 × 270, `default_texture_filter=0`).
- **Art pixels:** one art pixel is one game pixel. Draw everything at **1×**, never pre-scaled.
- **Wider screens:** on wider screens the view gets wider (stretch aspect `expand`). It's about 600 px at 20:9 and taller on the Fold's inner screen. So background layers must tile sideways, and the sky stays a code gradient.
- **The same art at other sizes:** it's shown at 0.55× (valley rivals), 0.72× and 1.35× (back and front lanes), 1.5× (SUMMIT), 2× (GAUNTLET) and up to 3× (garage). It should still read at 2×.
- **Look:** flat fills, a 1 px light edge on top and a 1 px dark edge underneath, no black outlines. That's the current look; keep it unless you're restyling everything.
- **Facing:** everything faces right. The game mirrors whatever needs to face left.

### Tools

| Tool | Cost | Notes |
|---|---|---|
| **Aseprite** | paid (source-available, proprietary EULA) | The standard pixel-art editor. Export with **File > Export Sprite Sheet**, frames in one horizontal row. |
| **Pixelorama** | free, MIT licensed, Windows/Linux/macOS/web | Built with Godot itself. Exports PNG, spritesheets and GIF. |

Either one works. Use the same file rules in both:
- PNG with transparency.
- One row of equal-size frames per sheet, no spacing.
- No anti-aliasing, no blur, no soft brushes.

For store art, which is much bigger, draw at the reduced size given in the store table, then scale up by a whole number:

```bash
magick in.png -filter point -resize 400% out.png
```

- `magick`: ImageMagick 7 (`sudo pacman -S imagemagick` on Arch).
- `-filter point`: nearest-neighbour, so each pixel becomes a hard-edged block with no smoothing.
- `-resize 400%`: ×4. Use `200%` for the ×2 rows.

Some stores reject transparency. For those, add `-background '#1b1424' -alpha remove -alpha off` before the output name:
- `-alpha remove` flattens the image onto that background colour (the game's dark ink).
- `-alpha off` drops the alpha channel.

### Colours the game swaps

- **Bike paint:** draw a bike's paint in the stock colours: body `#c8323c`, body shadow `#7a1c2a`, accent `#f2d16b`. The game swaps exactly those three for the paint you've picked. There are 86 paints: 6 in the shop and 80 in the season pass (`catalog.gd paints()`). Every other colour on the bike stays as you drew it. Electric bikes keep their green charge light `#5bf08a`.
- **Backgrounds:** draw each layer as a silhouette in white `#ffffff` with shading in two greys, `#b0b0b0` and `#606060`. The game multiplies it by that trail's colour for the time of day and weather (`backdrop.gd _t()`), so one drawing covers day, dusk, night, rain and wind.
- **UI:** ink `#1b1424`, cream `#f4ead5`, gold `#f2c14e`. Track hazard stripes are `#f0c040` and steel is `#4a4f5c`.

### What to make, in order

The order is my suggestion: store art first (it's needed to publish and doesn't wait on code), then whatever is on screen most.

**1. Logo and store art.** The title is currently just text in Press Start 2P. A logo image is used on the title screen, as Steam's library logo, and on the feature graphic and capsules. Sizes are in the store table below.

**2. Bikes** (`bike_view.gd`). Make one PNG per bike:
- **Canvas:** 48 × 32. The ground is the line under the bottom row, and the bike's origin is x = 24.
- **Wheels:** leave them off the bike (they spin) and make them as a separate wheel sheet.
- **Physics points:** SUMMIT and GAUNTLET use these points for physics (`scripts/drive/vehicles.gd GEO`), so wheel centres and the seat point must land on them. Coordinates are canvas pixels from the top-left.

| Bike | Game id | Rear wheel centre, radius | Front wheel centre, radius | Seat (hip) |
|---|---|---|---|---|
| SCRAMBLER | `scrambler` | 16,28 r4 | 32,28 r4 | 19,18 |
| DIRT BIKE | `dirt` | 15,27 r5 | 33,27 r5 | 18,14 |
| MINIBIKE | `minibike` | 18,29 r3 | 30,29 r3 | 20,21 |
| SCOOTER | `scooter` | 17,29 r3 | 32,29 r3 | 18,19 |
| CAFE RACER | `cafe` | 16,28 r4 | 32,28 r4 | 18,17 |
| CHOPPER | `chopper` | 13,27 r5 | 38,29 r3 | 18,19 |
| SPORTBIKE | `sport` | 16,28 r4 | 33,28 r4 | 20,17 |
| ZIP E-MOPED | `zip` | 18,29 r3 | 31,29 r3 | 19,20 |
| COMMUTER E-BIKE | `commuter` | 16,27 r5 | 32,27 r5 | 20,16 |
| SPARK E-DIRT | `spark` | 16,28 r4 | 32,28 r4 | 19,17 |
| BOULDER FAT E-BIKE | `boulder` | 16,27 r5 | 32,27 r5 | 20,16 |
| SURGE E-STREET | `surge` | 16,28 r4 | 33,28 r4 | 20,17 |
| MONO E-WHEEL | `mono` | 24,27 r5 (one wheel) | | 24,16 |
| GOLIATH E-WHEEL | `goliath` | 24,25 r7 (one wheel) | | 24,13 |

- **Wheel sheets:** one sheet per wheel type, 4 frames, each turned a further 22.5°. The wheel's symmetry makes 4 frames a full loop.

| Wheel | Frame size |
|---|---|
| r3 | 7 × 7 |
| r4 | 9 × 9 |
| r5 plain, knobby, spoked | 11 × 11 |
| r7 knobby | 15 × 15 |

- **Extras:**
  - the flames decal for the scrambler, cafe racer and chopper, as an overlay layer;
  - the scooter and e-moped umbrella, closed and open (6 → 24 px wide);
  - the rocket, 7 × 4 body, with a 2-frame flame.

**3. Riders** (`bike_view.gd draw_rider`). There are 8 riders, and the game builds each one on whichever bike it's riding, using the seat, peg and grip points. So make the parts, not 112 rider-and-bike combinations:

- **Heads:** about 8 × 8 each, one frame. A few have extra animated bits, listed in the table.
- **Torso:** about 3 × 7.
- **Limbs:** these are 2–3 px wide, so the game can keep drawing them as lines in the rider's colours.
- **Landing squash:** the game squashes the whole rig on landing in code, so heads don't need a squashed frame.

| Rider | What makes it distinct |
|---|---|
| DUSTY | helmet and visor |
| GRANNY GRIT | grey bun, scarf (7 trailing segments) |
| BANDIT | ears, mask, striped tail (6 segments) |
| BONES | skull, 3-frame flame hair |
| ZORP | antenna, glass bubble about 11 px across |
| ROBO-7 | antenna and chest light (2-frame blink), scanning visor |
| FINN | shark head with a dorsal fin |
| BIG FROSTY | bigger build (head about 10 px), horns |

- **Trick poses:** these only exist in SUMMIT and GAUNTLET: whip, no-hander, heel clicker and superman. For each pose the code moves the hip, feet and hands and tilts the torso (all the way to flat for the superman). Drawn heads and torsos ride along on those points, with the torso rotated, so the poses need nothing extra drawn.

**4. Trail looks** (`backdrop.gd`, `depth.gd`, `world_art.gd`). There are 16 looks. For each one, make these pieces as white-and-grey silhouettes (see "Colours the game swaps"):

| Piece | Size | Notes |
|---|---|---|
| Far ridge | 512 × 80 strip, tiles sideways | scrolls at 0.12× |
| Mid ridge | 512 × 64 strip, tiles sideways | scrolls at 0.3× |
| Near props | single sprites, 16–60 px tall | 3–6 per look |
| Foreground props | single sprites, up to 140 px tall | dark silhouettes, scroll at 1.6× |
| Deck surface | 32 × 6 tile that repeats along slopes, plus left and right end caps 3 × 6 | |
| Supports | top piece plus a 16–96 px wide segment that tiles downward | runs to the bottom of the screen |

| # | Look | Near props | Deck style |
|---|---|---|---|
| 0 | Dusty Trail | cactus | wood |
| 1 | Copper Canyon | rocks | stone |
| 2 | Rustyard | junk | girder |
| 3 | Night Trestle | poles | truss (guard rail, lamp posts) |
| 4 | Mesa Springs | mesa | adobe |
| 5 | Lantern Mine | headframe | mine (sleepers and rail) |
| 6 | Hoodoo Loops | hoodoos | rock |
| 7 | Hoist Yard | crane | catwalk (hazard stripes) |
| 8 | Skyline Pass | pines | log (snow, rope rail) |
| 9 | Quarry Cliffs | quarry | scaffold |
| 10 | Rocket Ridge | gantry | launch (red and white) |
| 11 | Last Trestle | ruin | wood |
| 12 | Grandma's Farm | farm | farm (white fence) |
| 13 | Rail Yard | railyard | railbed (two rails) |
| 14 | Old Orchard | orchard | stump |
| 15 | County Speedway | fair | bleacher |

Shared pieces that every look uses:

| Piece | Size |
|---|---|
| Far trestle with train | engine 14 × 6, cars 11 × 5, lit and unlit windows |
| Hot-air balloon | about 12 px |
| Hawk, bats | small sheets of 2–4 frames |
| Tumbleweed | small and large |
| Firefly, dust mote | 1–2 px; leave these in code |

**5. Enemies** (`world_art.gd`). Draw them facing right; the game mirrors them.

| Type | Skins (which trails use which: `world_art.STYLES`) | Frames |
|---|---|---|
| Crawler, about 14–17 × 9–14 | beetle, scorpion, rustbot, mole, marmot, gloop | walk 2 frames; one squashed 16 × 4 |
| Spiker, 12–17 × 11–17 | cactus, mine, crystal, tnt, thistle, spore, ice, urchin | 1 frame; 2–4 for the ones that blink, spin or pulse |
| Flyer, 16–20 × 10–12 | bat, vulture, owl, probe, drone | flap or spin, 2–4 frames |

**6. Pickups, power-ups and the HUD** (`icons.gd`, `hud.gd`).

| Item | Size and frames |
|---|---|
| Coin | 8 × 8, 3 spin frames (8, 6 and 4 px wide) |
| Money bag | 10 × 12 |
| Gear | 13 × 13, 3 states: found, not found (outline), ghost (already found) |
| Letter tiles | 12 × 12 for T R E S T L E, lit and unlit; 10 × 11 mini versions for the HUD |
| Power bubble | 18 × 18 ring |
| Power-up icons | sticky tires 10 × 12, rocket 11 × 10, magnet 10 × 10, hard hat 10 × 6 |
| Medals | 10 × 14: bronze, silver, gold, unearned |
| Biplane | about 34 × 19, 2 propeller frames |
| Spring | 14 × 13 |
| Checkpoint flag | 11 × 8, red and green |
| Finish banner | 44 × 8 checker |
| HUD buttons | 30 × 26 ("II", "?") |
| Panels and buttons | 9-slice frames: 2 px border, no rounding (`ui_theme.gd`) |

**7. SUMMIT and GAUNTLET** (`drive_art.gd`). Remember these are shown at 1.5× and 2× zoom.

| Item | Size and notes |
|---|---|
| Ground | 32 × 32 soil tile with a 3 px lip strip on top, one set per ground palette (16: `drive_art.GROUND`) |
| Crate | 9-slice, 8 × 8 corners |
| Log end | r3–6 |
| Fuel can | 8 × 12 |
| Charge point | 8 × 13 |
| Event items | pumpkin 9 × 9, heart 8 × 7, egg 7 × 10, star 10 × 10 |
| Markers | summit flag 16 × 12 checker, 3 waving frames; distance post 16 tall |
| Decor | trees, pines, bushes, cactus, sage, lamp post, scrap, boulders |

**8. Bosses** (`boss_art.gd`). Draw them as separate parts so the code can keep animating them:

| Boss | Size and parts |
|---|---|
| The Scooper | saucer 40 × 21, tractor beam 24 × 18 |
| Spinner | saucer 52 × 22, 6 orbiting fins |
| Rail Hog | head 34 wide; its body runs to the ground, so make a segment that tiles downward |
| Harvester | about 180 × 160: pod 28 × 7 plus dome, hub, and 3 stilt legs as tiling segments with a separate foot |

All four share the same green alien pilot under glass, a weak spot, and a white flash frame for hits.

**9. Story** (`story_art.gd`).

| Item | Size and notes |
|---|---|
| Grandpa's bike | 94 × 52, with each of the 8 parts on its own layer, plus a dim silhouette of each |
| Grandma | about 14 × 35, three poses: idle, aiming/firing (with a muzzle flash), waving |
| Intro panels | six full-screen panels at 480 × 270: barn, abduction, porch "BLAM!", pod cracking, county map, sunrise |

**10. Achievement badges** (`achievement_art.gd`). There are 46 badges, each **20 × 20**, plus a grey locked rim. `dev/ach_export.gd` scales them up to Play's 512 and Apple's 1024 sizes, so draw them at 20 × 20 only. The ids and what each badge is for are in `ACHIEVEMENTS.md`.

### Store and app icons

None of these go in the game. The Play screenshots and feature graphic are currently rendered from the game by `tools/store/make_store_art.py`, so they'll pick up new in-game art by themselves. Steam has no art yet. "Draw at" is the reduced size to draw; "×" is the whole-number scale-up to the final size.

| Asset | Final size | Draw at | × | Notes |
|---|---|---|---|---|
| Play app icon | 512 × 512 | 128 × 128 | 4 | 32-bit PNG with alpha, max 1024 KB |
| Play feature graphic | 1024 × 500 | 256 × 125 | 4 | JPEG or 24-bit PNG, **no alpha** |
| Play screenshots | 1920 × 1080 | 480 × 270 | 4 | at least 3 landscape for games; made by `make_store_art.py` |
| Android adaptive icon layers | 432 × 432 each (foreground, background, monochrome) | 48 × 48 | 9 | keep the important part inside the middle 32 × 32 (the 72 dp safe zone); the current ones are in `assets/icon/` |
| Steam header capsule (also library header) | 920 × 430 | 460 × 215 | 2 | logo and key art only |
| Steam small capsule | 462 × 174 | 231 × 87 | 2 | logo and key art only |
| Steam main capsule | 1232 × 706 | 616 × 353 | 2 | logo and key art only |
| Steam vertical capsule | 748 × 896 | 187 × 224 | 4 | logo and key art only |
| Steam library capsule | 600 × 900 | 150 × 225 | 4 | logo and key art only |
| Steam library hero | 3840 × 1240 | 960 × 310 | 4 | art only, **no logo** |
| Steam library logo | 1280 wide and/or 720 tall | 320 × 180 | 4 | transparent PNG, sits on the hero |
| Steam page background (optional) | 1438 × 810 | 719 × 405 | 2 | subtle, not bright |
| Steam screenshots | 1920 × 1080 or more, 16:9 | 480 × 270 | 4 | the same game frames |
| Steam shortcut icon | 256 × 256 | 64 × 64 | 4 | .png or .ico |
| Steam app icon | 184 × 184 | 46 × 46 | 4 | .jpg |
| App Store icon (iOS, later) | 1024 × 1024 | 128 × 128 | 8 | **opaque**; check Apple's current spec when iOS is set up |

Sources:
- Steamworks Documentation, *Graphical Assets*: https://partner.steamgames.com/doc/store/assets
- Play Console Help, *Add preview assets*: https://support.google.com/googleplay/android-developer/answer/9866151
- App Store icon: https://learn.microsoft.com/en-gb/previous-versions/xamarin/ios/app-fundamentals/images-icons/app-store-icon

### Getting art into the game

Files go in `assets/art/<group>/`, one folder per section above:
- `bikes/`
- `riders/`
- `trails/<look>/`
- `enemies/`
- `pickups/`
- `ui/`
- `drive/`
- `bosses/`
- `story/`
- `badges/`

Name each file after its game id, for example `bikes/scrambler.png`, `bikes/wheel_r4.png`, `enemies/beetle_walk.png`, `trails/rustyard/far.png`. Godot imports PNGs with nearest filtering already, because that's the project default.

Each group needs a loader before the game uses it (not written yet). The loader draws the PNG when one exists and keeps the code drawing when it doesn't, so art can come in one piece at a time and the game always runs.

Start with **one bike and its wheel sheet**. That's the smallest piece that tests the whole path: canvas, origin, wheel centres, paint swap and the SUMMIT physics points.

---

## Music and sound

### What's there

Everything is in `assets/audio/`. `assets/audio/manifest.json` lists each file's length, loudness (LUFS), peak, and whether it loops.

**Music:** 8 loops, each 32 bars of 4/4, stereo. A loop's length is 32 × 4 × 60 ÷ BPM seconds.

| File | Where it plays | Key, tempo | Length |
|---|---|---|---|
| `music/trestle_dreams.ogg` | menus, Dusty Trail, Copper Canyon, Mesa Springs, Hoodoo Loops, Quarry Cliffs; SUMMIT and GAUNTLET keep it too | D, 78 BPM | 98.462 s |
| `music/lantern_low.ogg` | Night Trestle, Lantern Mine | B minor, 68 | 112.941 s |
| `music/ridge_runner.ogg` | Rustyard, Hoist Yard, Skyline Pass, Rocket Ridge, Last Trestle | E, 96 | 80.000 s |
| `music/hayloft_shuffle.ogg` | Grandma's Farm | C, 92 | 83.478 s |
| `music/coal_smoke.ogg` | the Rail Yard | E minor, 104 | 73.846 s |
| `music/windfall.ogg` | the Old Orchard | F, 72 | 106.667 s |
| `music/county_fair.ogg` | the Speedway | A mixolydian, 120 | 64.000 s |
| `music/saucer_stomp.ogg` | every boss | D minor, 116 | 66.207 s |

- **Changing the key, tempo or length:** keep whole bars and the importer handles it, with one exception. Coin chimes climb a D major pentatonic ladder (`audio_director.gd COIN_STEPS`). That only matters for the theme, which is in D.
- **New tracks:** SUMMIT and GAUNTLET have no track of their own yet. A new loop for them needs one line of code.

**Engines:** 14 bikes × 2 loops (`engines/<id>_idle.ogg`, `engines/<id>_cruise.ogg`), each 8 s, **mono**.
- The game crossfades idle into cruise and pitches cruise with speed (about 0.5×–1.8×). So record cruise at a steady RPM near the one below.
- The electric bikes' numbers are the motor's base pitch in Hz, not RPM.

| Bike | Idle RPM | Cruise RPM |
|---|---|---|
| scrambler | 1150 | 4300 |
| dirt | 1750 | 6400 |
| minibike | 1800 | 4200 |
| scooter | 1900 | 7400 |
| cafe | 1150 | 5600 |
| chopper | 950 | 2500 |
| sport | 1300 | 7600 |
| zip | 520 Hz | |
| commuter | 230 Hz | |
| spark | 290 Hz | |
| boulder | 200 Hz | |
| surge | 380 Hz | |
| mono | 460 Hz | |
| goliath | 340 Hz | |

**Ambience:** 13 stereo loops of 40–96 s. They're layered per trail and per time of day (`audio_director.gd TIME_LAYERS`, `LEVEL_LAYERS`).
- **Recordings:** `day_birds`, `night_crickets`, `rain`, `wind`, `creek`.
- **Synthesized beds:** `canyon`, `yard`, `mine`, `alpine`, `collapse`, `farm`, `orchard`, `speedway`.

**Sound effects:** 49 in `sfx/`, mostly stereo one-shots.
- **Loops:** `deck_roll`, `zipline`, `plane`, `grind` and `saucer` are loops; the importer treats them like music.
- **Full list:** achievement, bag, bonk, boss_down, boss_hit, boss_loop, checkpoint, climb, coin, crash, crumble, dash, deck_roll, deny, finish, flip, gear, grind, grind_on, hat, jump, land, letter, letters_all, loop, page, part_get, plane, power, power_rocket, power_sticky, prize, purchase, rope_grab, saucer, smash, splash, spring, stomp, switch, tap, thunder, toggle, train_horn, trick, wall_on, wheelie, zip_grab, zipline.
- **Timing:** trim silence off the front of one-shots, because the game plays them on the frame things happen.

### The spec for anything you bounce

- **Format:** WAV (or AIFF), **44.1 kHz, 24-bit**, interleaved stereo (engines can be mono or stereo; the importer makes them mono).
- **Peaks:** keep them at or below -1 dBFS. A limiter on the master at -1 dB is enough.
- **Loudness:** don't chase a level. The importer sets the new file to the same LUFS as the one it replaces, so the mix doesn't change.
- **Seamless loops:** bounce the loop **three times back to back**, starting exactly on bar 1. The importer keeps the middle copy, which already carries the reverb and delay tails of the copy before it. So the seam is clean with no crossfade, and the length is exact to the sample.

### Pro Tools

1. **New session:** 44.1 kHz, 24-bit, WAV.
2. **Tempo and grid:** set the tempo and 4/4 meter in the rulers, and work on the Bars|Beats grid.
3. **Write the loop:** 32 bars to replace a track, or any whole number of bars for a new one.
4. **Make three copies:** select bars 1–33 on all tracks and duplicate twice, so the loop plays three times in a row (bars 1–97).
5. **Select the range:** select from 1|1|000 to the end of the third copy, in Grid mode so it lands exactly on the bar.
6. **Bounce:** File > Bounce Mix. Set File Type to **WAV**, Format to **Interleaved**, Bit Depth to **24**, Sample Rate to **44.1 kHz**, and turn **Offline** on (faster than real time).

Pro Tools runs on Windows and macOS. Copy the WAV to the machine with the project and run the importer there.

Source: Avid, *Bouncing a Final Mix*: https://www.avid.com/pro-tools/user-guide/bouncing-final-mix

### Ardour (free and open source)

- **What it is:** a full multitrack DAW licensed under the GPL, and the closest free match to Pro Tools.
- **Installing on Arch:** it's in the official `extra` repo at no cost.

  ```bash
  sudo pacman -S ardour
  ```

  `-S` installs the package and its dependencies from the repos.
- **Windows and macOS:** ready-to-run builds come from ardour.org on a pay-what-you-want basis from US$1. The free demo build goes silent after 10 minutes.

Steps:

1. **New session:** 44.1 kHz sample rate. Set tempo and meter on the tempo and meter rulers, and set the grid to Bar.
2. **Write the loop:** whole bars, as above.
3. **Make three copies:** duplicate the regions twice so the loop plays three times.
4. **Mark the range:** make a range from bar 1 to the end of the third copy, with the Range tool, snapped to the grid.
5. **Export:** Session > Export > Export to Audio File(s).
   - **File Format:** WAV, 24-bit, 44.1 kHz, with normalizing **off** (the importer sets loudness).
   - **Time Span:** pick that range instead of "session".

Sources:
- Ardour manual, *Export Dialog*: https://manual.ardour.org/exporting/export-dialog/
- Ardour manual, *Export Format Profiles*: https://manual.ardour.org/exporting/edit-export-format-profile/
- Arch package: https://www.archlinux.org/packages/extra/x86_64/ardour
- Ardour FAQ (pricing, distro packages): https://ardour.org/faq.html

### Importing into the game

Run this from the project folder:

```bash
python3 tools/audio/import_audio.py ~/bounces/windfall.wav music/windfall.ogg --copies=3
```

- `~/bounces/windfall.wav`: the bounce.
- `music/windfall.ogg`: the file in `assets/audio/` it replaces (or a new name).
- `--copies=3`: the bounce holds the loop three times; keep the middle one. For music the length comes from the BPM and bars in the manifest. For anything else, add `--seconds=S`.
- `--crossfade=S --seconds=S --start=S`: use these instead of `--copies` for one long recording, such as ambience or an engine held at steady RPM. They cut a loop `--seconds` long, starting at `--start`, and blend its last `--crossfade` seconds into its head. For example: `--start=5 --seconds=8 --crossfade=0.5`.
- Neither option: a one-shot effect, used as it is.
- `--lufs=X`: override the loudness instead of matching the old file.
- `--dry-run`: print what it would do without writing anything.

What it does:
1. Converts to 44.1 kHz.
2. Matches the old file's channel count and loudness.
3. Pulls the level down if a peak would pass -1 dBFS (it warns you, and you should limit harder in the DAW).
4. Encodes Ogg Vorbis at the same quality as the rest: music and effects q5, engines q6, ambience q4.
5. Marks the file `"imported"` in the manifest. `tools/audio/build.py` never overwrites imported files, so rebuilding the code-made audio leaves yours alone.

It needs Python 3, numpy, scipy, pyloudnorm and ffmpeg. On Arch:

```bash
sudo pacman -S --needed python-numpy python-scipy ffmpeg
python -m venv --system-site-packages ~/.venvs/trestle
~/.venvs/trestle/bin/pip install pyloudnorm
~/.venvs/trestle/bin/python tools/audio/import_audio.py ...
```

- `--needed`: skips packages that are already installed.
- `python -m venv ~/.venvs/trestle`: makes a private Python environment there, because Arch blocks `pip install` into the system Python.
- `--system-site-packages`: lets that environment use the numpy and scipy pacman installed.
- `bin/pip install pyloudnorm`: the one library pacman doesn't have.

Then reimport and listen:

```bash
godot --headless --path . --import
```

- `--headless`: no window.
- `--path .`: this project.
- `--import`: re-import changed assets, then quit.

Open the trail, or the garage for engines, and listen across the loop point.

### Credits

When your music replaces the code-made tracks:
- update the MUSIC section of `CREDITS.md`;
- update the in-game Credits screen (`scripts/screens/credits.gd`, the `"MUSIC"` list).

Recordings that aren't yours need their license and attribution added in both places, the same way the rain recording's CC BY 4.0 credit is.
