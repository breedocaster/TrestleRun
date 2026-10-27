# Credits and audio licensing

Everything shipped in the game is cleared for commercial use, including a store release with in-app purchases and ads. Only one item (the rain bed) requires attribution, and the in-game **Credits** screen carries it.

## Original (made for this game)

| Asset | Files | Notes |
|---|---|---|
| Theme "Trestle Dreams" | `assets/audio/music/trestle_dreams.ogg` | Composed and rendered in code (`tools/audio/theme.py`). 78 BPM, D major, 32-bar seamless loop. No samples. |
| "Lantern Low", "Ridge Runner" | `assets/audio/music/lantern_low.ogg`, `ridge_runner.ogg` | Variants of the theme from the same code (`theme.py`, `VARIANTS`): B minor at 68 BPM, and E major at 96 BPM with a train beat. 32-bar seamless loops. No samples. |
| "Hayloft Shuffle", "Coal Smoke", "Windfall", "County Fair" | `assets/audio/music/{hayloft_shuffle,coal_smoke,windfall,county_fair}.ogg` | Story-area loops from the same code: C major swung two-beat at 92 BPM, E minor blues train beat at 104, F major brushes at 72, A mixolydian boogie at 120. 32-bar seamless loops. No samples. |
| "Saucer Stomp" | `assets/audio/music/saucer_stomp.ogg` | The boss loop: D minor at 116 BPM, theremin-style lead. 32-bar seamless loop. No samples. |
| Trail beds: mine, yard, canyon, alpine, collapse, farm, orchard, speedway | `assets/audio/ambience/{mine,yard,canyon,alpine,collapse,farm,orchard,speedway}.ogg` | Synthesized stereo loops (`tools/audio/ambience.py`, `synth_beds`, `story_beds`): filtered noise, modal metal clanks, drips and creaks, wind chimes, an owl, a crowd and passing bikes, through a synthetic reverb. No recordings. |
| Engines, 7 bikes x idle/cruise | `assets/audio/engines/*.ogg` | Physical models (`tools/audio/engines.py`): combustion pulses at each engine's real firing angles -> exhaust waveguide -> muffler/body EQ -> rasp and mechanicals. No recordings. |
| Electric drives, 7 battery bikes x idle/cruise | `assets/audio/engines/{zip,commuter,spark,boulder,mono,surge,goliath}_*.ogg` | Synthesized (`tools/audio/electric.py`): motor whine at the electrical frequency and its orders, inverter tone, e-bike gear whir and freewheel ticks, chain/belt and tyre noise. No recordings. |
| Chimes, whooshes, splash, deck roll, finish jingle, distant train horn (D6 chord), thunder | `assets/audio/sfx/*.ogg` | Synthesized (`tools/audio/sfx.py`), tuned to D major pentatonic to sit inside the theme. |
| Spring boing, head bonk, loop swoop, zipline clink and pulley loop, biplane engine loop, plane prize, air dash, wheelie whirr, switch-track clack, flip whoosh, trick chimes, power-up pickups (sticky squelch, rocket roar), climb grind, hard-hat clonk, plank crack, letter chimes | `assets/audio/sfx/*.ogg` | Synthesized (`tools/audio/sfx.py`). The chopper's "smash" layers the Kenney impact and break sounds below (CC0). |

Engine layouts: chopper 45-degree V-twin (fires 0/315), scrambler 270-degree parallel twin (0/270), dirt bike 4-stroke single, sportbike 180-degree inline-4 (0/180/360/540), cafe racer 240-degree inline triple (0/240/480), scooter 2-stroke single with expansion chamber, minibike OHV 212cc single. The analysis script (`tools/audio/check_engines.py`) recovers the firing intervals from the rendered audio (V-twin idle 55/71 ms, as the crank math predicts).

## Found recordings

| Used as | Author | License | Original | Retrieved from |
|---|---|---|---|---|
| Rain bed | alex36917 | **CC BY 4.0** (attribution required, in Credits screen) | https://freesound.org/people/alex36917/sounds/524605/ | Blanket app repo (edited by Porrumentzio) |
| Day birds | kvgarlic | CC0 1.0 | https://freesound.org/people/kvgarlic/sounds/156826/ | Blanket (edited by Porrumentzio) |
| Dusk/night crickets | Lisa Redfern | Public domain | https://soundbible.com/2083-Crickets-Chirping-At-Night.html | Blanket |
| Wind (volume follows the in-game gusts; rebuilt as a 42 s loop from random slices of the recording) | felix.blume | CC0 1.0 | https://freesound.org/people/felix.blume/sounds/217506/ | Blanket (edited by Porrumentzio) |
| Creek (Copper Canyon, Mesa Springs) | gluckose | CC0 1.0 | https://freesound.org/people/gluckose/sounds/333987/ | Blanket |
| Crash impact | Kenney | CC0 1.0 | Starter-Kit-Racing `audio/impact.ogg` | https://github.com/KenneyNL/Starter-Kit-Racing |
| Landing thump, crash debris | Kenney | CC0 1.0 | Starter-Kit-3D-Platformer `sounds/land.ogg`, `break.ogg` | https://github.com/KenneyNL/Starter-Kit-3D-Platformer |
| UI tap and toggle | Kenney | CC0 1.0 | Starter-Kit-City-Builder `sounds/placement-a.ogg`, `toggle.ogg` | https://github.com/KenneyNL/Starter-Kit-City-Builder |

How the licenses were checked:

- **Blanket sounds:** the repo's `SOUNDS_LICENSING.md` (https://github.com/rafaelmardojai/blanket) and Debian's ftp-master copyright review of the same files (https://metadata.ftp-master.debian.org/changelogs/main/b/blanket/stable_copyright) agree file by file.
- **Kenney kits:** each kit's README states that its sound effects are CC0, and the Racing kit names Landeplage's skid sound as CC0 too (that sound is not used).
- **Freesound pages:** these were not re-opened from this build environment.
- **All edits** (trim, loop, filter, level) are listed in `tools/audio/ambience.py` and `tools/audio/sfx.py`.

Rebuild everything: `python3 tools/audio/build.py <dir containing the cloned kits and blanket>`.

## Font

Press Start 2P, Copyright 2012 The Press Start 2P Project Authors (CodeMan38), SIL Open Font License 1.1, `assets/fonts/OFL.txt`.
