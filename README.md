# Trestle Run (working title)

One-button motorcycle runner for Android/iOS, built in **Godot 4.7** (GL Compatibility renderer, 2D pixel art drawn in code). Inspired by the mine-cart *mechanic*, with original names, art and characters throughout.

Two ways to play from the title screen: **STORY** (win back the parts of Grandpa's motorcycle, area by area, boss by boss) and **FREE RIDE** (the twelve trails, any time and weather). Both share the garage, the wallet and the achievements.

## Gameplay

- The bike rides automatically along canyon trestles. **Tap = short hop, hold = full jump** (variable height, with coyote time and jump buffering).
- **Branching routes:** upper decks you reach by jumping (or a spring), and hidden lower decks that merge back up.
- **Switch tracks (2.5D):** some trails run parallel tracks behind and in front of the main one. Roll onto a signed switch ramp to swing onto the other track; hop over the ramp to stay. A wide striped plate at the end merges you back. Some switches are optional (coins, a gear, a way round hazards); on others the main deck breaks off and the switch is the way on. The track you're on is drawn at its depth (smaller and hazed behind, bigger in front), and any track in front of you fades so you can see yourself behind tunnels.
- **Tricks:** tap in the air for a flip. Rising = backflip, falling = front flip. A tap only starts a flip if you'll stay airborne long enough to finish one (0.38 s), so it's a big-air move: kickers, drops, springs, stomp bounces. On a short hop the tap is just a press, so tapping again and holding to wheelie on landing works. Tapping again mid-flip adds another flip, and that one isn't checked: land upright (within ~35 degrees) for coins, 2 per backflip and 3 per front flip, times the number of flips (a double backflip is 8); land mid-flip and it's a sketchy landing, a wobble and 28% of your speed lost, never a crash. Double hop and air dash take priority over flips, the scooter's press while falling is always its umbrella, and a press just above the deck still counts as a buffered jump. Results show tricks and their coins on their own row.
- **Enemies** (each trail has its own look for them, same hitboxes)
  - *Crawler* (beetle, scorpion, rustbot, mole, marmot): stomp it from above for a bounce and +2 coins; touching its side crashes you.
  - *Spiker* (cactus, mine, urchin, crystal, ice spike): can't be stomped, jump over it.
  - *Flyer* (vulture, drone, bat, owl): can't be stomped, stay low and ride under it.
- **Pickups:** coins, money bags (+10), and 3 hidden **gears** per trail (25 coins each, paid once).
- **Power-ups** (bubbles floating over the deck; ride or hop through one). The HUD shows a draining bar for each timed one:
  - *Sticky tires* (10 s): jump at a cliff face painted with green chevrons and you stick and drive straight up it to the route on top (coins, often a gear), then drop off the far end for big air. Without them the face bonks you back down onto the main deck, which runs through a tunnel under the cliff. A late jump right at the tunnel mouth also counts as the face (no crash).
  - *Rocket* (2.5 s): +75% speed and jumps take off 20% harder. Three-way ramps (a steep kicker): rocket + full jump at the lip reaches the top deck, a full jump alone the middle deck, a tap or no jump drops you to the bottom road. All three routes are safe and rejoin; the higher ones pay more.
  - *Coin magnet* (8 s): coins within 60 px fly to you. Gears and letters you still grab yourself.
  - *Hard hat* (one hit): the next crawler or spiker you hit breaks the hat instead of you. It doesn't help with falls.
- **T-R-E-S-T-L-E letters:** seven per trail, shown in the HUD as you find them. All seven in one run pays +50. They roll back with coins if you crash past a checkpoint.
- **Medals per trail:** bronze for a clear, silver for all seven letters in one run, gold for a run under par with no crashes (par is the dev bot's clean time + about a second; +18% in wind). Shown on the trail cards and the results screen.
- **Ghost:** your best-time run rides alongside you as a see-through rider. GHOST RUN on/off in Settings.
- Checkpoints mid-trail; crashes respawn you there about 1.6 s later, or tap once the wreck has played for 0.4 s ("TAP TO GO AGAIN") to come straight back. Coins only bank when you finish.
- **CONTINUE** on the title screen takes you straight into the trail you last rode, or the next one once that's cleared (Free Ride trails keep your last time and weather).
- **Settings** (title screen): GHOST RUN, CRASH HINTS and VIBRATION on/off; CRASH HINTS is in the pause menu too.
- **Payout** per clear = coins + conditions bonus + new gears + clear bonus + no-crash bonus. Results also show your time and best time.

### Story mode

Grandpa's old motorcycle sat in the barn for forty years, until a saucer beamed it up one night. Grandma got two shells of birdshot into it from the porch; the capture pod holding the bike got knocked about and spilled its parts across the county before the saucer limped off. A short comic tells it the first time you pick STORY (SKIP jumps straight to the map).

The county map has four areas so far, each with three trails and a boss: an alien machine sitting on one part. Beat it and the part drops; it goes back on the bike in the barn (the map shows the bike filling in, part by part). Clearing a trail opens the next; the boss opens after the area's third trail. Story trails are their own layouts (Free Ride's twelve are untouched), and each has a fixed time of day and weather that's part of its look.

| Area | Trail | Speed | New | Conditions |
|---|---|---|---|---|
| Grandma's Farm | Hayfield Run | 116 | Jumping, crawlers | day, clear |
| | Clothesline | 120 | Ziplines, spikers | day, clear |
| | Power Lines | 124 | Zipline tricks: cables that haul you up, chains, islands | dusk, clear |
| | **The Scooper** (boss) | 120 | Boss fight; wins the **headlight** | dusk, clear |
| The Rail Yard | Switchback Siding | 126 | Grind rails, flyers | dusk, clear |
| | Coal Chutes | 130 | Rail hops, switch tracks | dusk, rain |
| | Roundhouse | 134 | Springs, lifts | night, clear |
| | **Rail Hog** (boss) | 128 | wins the **kickstart** | night, clear |
| Old Orchard | Apple Row | 132 | Rope swings | dusk, clear |
| | Creek Crossing | 136 | Loops | night, clear |
| | Hollow Oak | 140 | Low ceilings | night, wind |
| | **The Harvester** (boss) | 134 | wins the **seat** | night, clear |
| County Speedway | Fairgrounds | 140 | Wall-rides | day, clear |
| | Wall of Death | 144 | Big walls and launch lips, coin magnet | dusk, wind |
| | Grandstand | 148 | Rocket, sticky tires | night, clear |
| | **The Spinner** (boss) | 142 | wins **both wheels** | night, clear |

The carburetor, top end, bottom end and frame are still out there (shown as "coming" on the map): four more areas to build.

**Story difficulty**, measured the same way as Free Ride's (`--difficulty --set=story`, each trail in its own weather; bosses aren't timed this way). A jump onto a cable, rail, rope or wall-ride is a press held until it catches, and counts as soon as it does, since once you've caught one, when you jumped hardly matters:

| Area | Trail | Speed | Weather | Tightest window | 10th percentile | Forced jumps per 10 s | Crashes |
|---|---|---|---|---|---|---|---|
| Farm | Hayfield Run | 116 | clear | 283 ms | 333 ms | 3.4 | 0 |
| Farm | Clothesline | 120 | clear | 266 ms | 333 ms | 3.7 | 0 |
| Farm | Power Lines | 124 | clear | 166 ms | 183 ms | 3.1 | 0 |
| Rail Yard | Switchback Siding | 126 | clear | 133 ms | 166 ms | 2.9 | 0 |
| Rail Yard | Coal Chutes | 130 | rain | 150 ms | 150 ms | 2.8 | 0 |
| Rail Yard | Roundhouse | 134 | clear | 133 ms | 250 ms | 2.8 | 0 |
| Orchard | Apple Row | 132 | clear | 166 ms | 183 ms | 3.9 | 0 |
| Orchard | Creek Crossing | 136 | clear | 133 ms | 166 ms | 3.3 | 0 |
| Orchard | Hollow Oak | 140 | wind | 166 ms | 166 ms | 4.0 | 0 |
| Speedway | Fairgrounds | 140 | clear | 133 ms | 166 ms | 4.0 | 0 |
| Speedway | Wall of Death | 144 | wind | 250 ms | 266 ms | 3.6 | 0 |
| Speedway | Grandstand | 148 | clear | 150 ms | 183 ms | 3.0 | 0 |

The story is gentler on timing than late Free Ride (its tightest spot anywhere is 133 ms, eight frames, and those are all ordinary hazards: a flyer over a gap, a spiker under a flyer; Free Ride's tightest is 83 ms). Its step up from area to area is the new hold move, plus speed. Measuring it turned up wall-rides that could only be caught by coming down onto the steep face, a one-frame window on the speedway; now holding as you rise into the face sticks you to it too, and no hold move is in the tightest spots any more.

### Hold moves

Ziplines were the one place the button meant "keep holding". Story trails add three more, and they only carry you **while you hold**: let go and you drop.

- **Grind rails:** steel rails over gaps. Jump onto one and keep holding; sparks and a grind sound while you're on it. Hold off the end and you pop up (onto the next rail in a chain); some rails run downhill or have a lower road under them for letting go early.
- **Rope swings:** ropes hanging from beams, branches and cranes. Jump and hold to catch one; you can catch it a long way down its length, and pressing up to 0.12 s after your hands go past it still catches it. Letting go any time it's swinging you forward flings you forward and a little up (early is a flatter fling), so the let-go window is about half a second. Hold too long and it swings you back; keep holding and it swings forward again.
- **Wall-rides:** curved board walls that arc up over a pit. Jump at the face and hold: you stick to it whether you come down onto it or are still rising into it (like catching a cable), so the timing is forgiving. Hold all the way round; a wall that ends going up (a lip) throws you into the air.
- **More zipline variants:** cables that haul you uphill, chains where you pop off one cable onto the next, and cables over little islands with a prize and a spring.

### Bosses

Each boss is an alien machine that moves between fixed spots in its arena: the Scooper (a flying saucer), the Rail Hog (a junk locomotive head that rides up out of the pit under the rails), the Harvester (a stilt-legged walker whose head pod hangs low on a cable) and the Spinner (a bigger saucer). Land on its glowing glass top three times; the arena's own cables, rails, ropes or walls are how you get above it. Each hit bounces you up (hold to ride the bounce higher). Miss them all and it circles round: you're carried back to the arena start with the hits you've landed kept, and crashes keep them too. When it goes down the part falls out, and the trail ends a couple of seconds later. Medals: bronze for the win, silver for a win without crashing, gold for a clean win under par.

### Crash hints

Wreck a few times in the same stretch of trail and your next try shows the way through it: a tip at the top of the screen for that kind of stretch, and a dotted line from the checkpoint to past the trouble, with **TAP**, **HOLD** and **LET GO** marks (the dots turn blue while the button should be down). The line is the real physics played forward from the exact spot you respawn at, ridden by the autopilot, with each plain jump moved to the middle of its timing window (where a person has the most room either side). It's worked out on a background thread while the crash plays, so the run never stutters. It disappears once you're through.

How many wrecks it takes rises as the game goes on: 2 on Free Ride trails 1-3 and on the farm, 3 on trails 4-6 and in the rail yard, 4 on trails 7-9 and in the orchard, 5 on trails 10-12 and at the speedway. Cables, rails, ropes, wall-rides and boss arenas always hint after 2, since those are the ones you can't solve by jumping harder. The count is per stretch and survives RESTART until you close the app. CRASH HINTS in Settings or the pause menu turns them off.

### Achievements

31 achievements, from finishing the first story trail to recovering each part, beating a boss without a scratch, gold medals, stomps, rail grinds and catching prize sacks. They unlock in the save, pop a toast, and show on the ACHIEVEMENTS screen (title screen) with progress for the counted ones. Progress from an older save counts. The game reports them to Google Play Games and Apple Game Center when those plugins are in the build; that part needs store accounts, and [ACHIEVEMENTS.md](ACHIEVEMENTS.md) is the step-by-step, with the store icons and import files already generated in `store/achievements/`.

### Free Ride trails

Twelve trails, each adding one new thing on top of the earlier ones. Speed, gap widths and hazard density climb from trail to trail.

| # | Trail | Speed | New feature | How to get past it |
|---|---|---|---|---|
| 1 | Dusty Trail | 118 | Jumping, tricks | Tap for a hop, hold for a big jump; tap again in the air to flip |
| 2 | Copper Canyon | 122 | Crawlers, coin magnet | Land on top to stomp; hold during the bounce to go higher |
| 3 | Rustyard | 126 | Spikers, switch tracks | Jump clean over; roll onto a switch ramp to change tracks |
| 4 | Night Trestle | 130 | Flyers, hard hat | Stay low; over a gap use a quick tap so you stay under |
| 5 | Mesa Springs | 134 | Springs | Roll onto the pad to fly high and far; hop over it to stay low |
| 6 | Lantern Mine | 138 | Low ceilings | Taps only: a big jump bonks your head and drops you short |
| 7 | Hoodoo Loops | 142 | Loop-the-loops | Keep rolling; press as you come out if there's a gap |
| 8 | Hoist Yard | 146 | Bobbing lifts | Time the jump to come down on the next lift |
| 9 | Skyline Pass | 150 | Ziplines | Long hold to grab the cable, keep holding, let go over the far deck |
| 10 | Quarry Cliffs | 154 | Sticky tires | Grab them, jump at the green face, ride the top; or take the tunnel |
| 11 | Rocket Ridge | 156 | Rocket | Rocket + full jump at a ramp's lip for the top route |
| 12 | Last Trestle | 158 | Crumbling planks, collapse | Hop straight off long grey planks; keep your speed up ahead of the collapse |

Trails 6–9 also carry bonus routes for the new power-ups: a sticky-tire cliff on Lantern Mine and Hoist Yard, a rocket three-way ramp on Hoodoo Loops and Skyline Pass. Magnets and hard hats turn up from Trail 2 on.

**Hints:** besides the crash hints above, the in-run **?** button (top right) pauses and opens a card explaining the trail's new feature, with a live demo of the autopilot riding it. Trails that introduce two things get two pages (NEXT / BACK). On a first visit the button pulses and a small "NEW: ..." tag shows for a few seconds; there is no splash screen. The trail picker has the same card behind **? TIPS**, and each trail card names its feature.

**Each trail has its own identity:**

| # | Trail | Track build | Critters (crawler / spiker / flyer) | Ambient | Sound bed | Music | Pacing |
|---|---|---|---|---|---|---|---|
| 1 | Dusty Trail | Wooden trestle | Beetle / cactus / vulture | Dust motes, dust devil | Birds / crickets | Trestle Dreams | Rolling dunes, two kickers for first flips |
| 2 | Copper Canyon | Stone arches | Scorpion / cactus / vulture | Copper glints, dust devils | Canyon wind, creek | Trestle Dreams | Long drops and climbs |
| 3 | Rustyard | Riveted girders | Rustbot / mine / drone | Welding sparks under the deck, smokestacks | Machine yard | Ridge Runner | Hazard clusters, two switch-track forks (one optional, one forced) |
| 4 | Night Trestle | Steel truss with lamps | Beetle / urchin / bat | Low fog banks | Crickets | Lantern Low | One long bridge; a forced rush along the foreground track |
| 5 | Mesa Springs | Adobe piers | Beetle / cactus / vulture | Steam from the springs, a geyser | Creek | Trestle Dreams | Bouncy: springs between hills |
| 6 | Lantern Mine | Mine cribbing and rail | Mole / crystal / bat | Water drips, lantern dust | Mine rumble and drips | Lantern Low | Tunnels, with side shafts in the back lane |
| 7 | Hoodoo Loops | Rock columns | Scorpion / cactus / vulture | Blowing red sand, dust devils | Canyon wind | Trestle Dreams | Flowing: loops linked by hills and a kicker |
| 8 | Hoist Yard | Catwalk with hazard stripe | Rustbot / mine / drone | Arc-weld sparks, vent steam, smokestacks | Machine yard | Ridge Runner | Stacked: lifts on a back gantry, a front catwalk rush |
| 9 | Skyline Pass | Log bridge, snow, rope rail | Marmot / ice / owl | Snow, spindrift off the peaks | Mountain wind | Ridge Runner | Mountain descent with big airs and ziplines |
| 10 | Quarry Cliffs | Timber scaffolding | Mole / dynamite / vulture | Grit trickling down, a blast plume on a far bench | Canyon wind, yard | Trestle Dreams | Five cliffs to climb, tunnels underneath |
| 11 | Rocket Ridge | White lattice towers, red and white grating | Rustbot / mine / drone | Exhaust haze, a test rocket climbing off a far pad | Yard, canyon wind | Ridge Runner | Four three-way ramps, lifts, a zipline |
| 12 | Last Trestle | Old grey timber over a gorge | Beetle / urchin / bat | Splinters and ash, dust where far bents give way | The collapse (rumble, snapping timbers) | Ridge Runner | The trestle falls away behind you; crumbling plank runs |

**Difficulty ramp**, measured by `--difficulty` (see Dev checks; these are the v0.7 numbers, and the Free Ride trails haven't changed since). For every jump a trail forces, it finds how long the window of frames is in which pressing still gets you past (pressing in the middle of the window, like a person would):

| # | Trail | Speed | Tightest window: clear / rain / wind | 10th percentile (clear) | Forced jumps per 10 s |
|---|---|---|---|---|---|
| 1 | Dusty Trail | 118 | 333 / 283 / 250 ms | 350 ms | 2.6 |
| 2 | Copper Canyon | 122 | 233 / 200 / 200 ms | 233 ms | 3.3 |
| 3 | Rustyard | 126 | 166 / 166 / 133 ms | 216 ms | 5.0 |
| 4 | Night Trestle | 130 | 183 / 183 / 150 ms | 200 ms | 2.7 |
| 5 | Mesa Springs | 134 | 133 / 166 / 133 ms | 150 ms | 2.5 |
| 6 | Lantern Mine | 138 | 166 / 150 / 100 ms | 200 ms | 2.8 |
| 7 | Hoodoo Loops | 142 | 150 / 100 / 83 ms | 166 ms | 3.5 |
| 8 | Hoist Yard | 146 | 150 / 150 / 100 ms | 183 ms | 4.2 |
| 9 | Skyline Pass | 150 | 166 / 83 / 133 ms | 183 ms | 3.7 |
| 10 | Quarry Cliffs | 154 | 150 / 166 / 166 ms | 233 ms | 2.1 |
| 11 | Rocket Ridge | 156 | 150 / 83 / 133 ms | 166 ms | 2.8 |
| 12 | Last Trestle | 158 | 200 / 150 / 150 ms | 200 ms | 4.6 |

Speed climbs every trail and each one adds a mechanic on top of the timing; the tightest windows shrink from a third of a second to around 0.1 s, and no spot needs frame-perfect timing in any weather (the tightest anywhere is 83 ms, five frames; v0.5's was 66 ms). Trails 10-12 keep their windows near Trails 7-9 on purpose: their step up is route choice (climb or tunnel, top/middle/low road) and, on Last Trestle, the collapse behind you. The careful rider's closest call with the collapse there is 55 px in clear, 80 in rain and 71 in wind (`--probe`); the collapse starts 80 px behind you and runs at 99% of the trail's speed (84% in wind, since gusts slow you in the air) with a small surge every 10 s, so losing speed (a bonk, a sketchy landing) is what lets it catch up. Tricks are never forced, so they don't count here. For comparison, the v0.4 trails measured the same way: Trail 2 (Copper Canyon at 136 px/s) had a 16 ms, one-frame spot at its split-deck section, and Trail 3 had a stretch the careful rider couldn't get through at all.

### Bike specialties

Every bike keeps the same one-button control and hitbox; each adds one move.

| Bike | Specialty | How |
|---|---|---|
| Scrambler | Wheelie +10% | Hold the button as you land: front wheel up, speed builds while you hold, then bleeds off |
| Dirt bike | Big wheelie +14% | Same, stronger |
| Sportbike | Power wheelie +18% | Same, strongest |
| Minibike | Double hop | Tap again in the air for one more hop |
| Scooter | Umbrella | Hold while falling to float down slowly |
| Cafe racer | Air dash | Tap in the air to dash forward |
| Chopper | Iron hide | Smash through one enemy per checkpoint (falls still count) |

Wheelie or jump again: on the wheelie bikes, a press in the air that you're still holding when the wheels touch is a wheelie, unless it came on the very last frame before touchdown or on touchdown itself (a "jump again as I land" press). A tap you let go of before touchdown still jumps again on landing, and a press after touchdown always jumps. (Before 0.8.1 any press in the last 0.12 s before touchdown jumped again, which is what kept turning wheelies into jumps.) An air press within a few pixels of landing still counts as a buffered jump rather than a specialty move. On story trails the scooter's umbrella stays shut when a rail, wall-ride or rope is just ahead: holding there means "grab", and a floating scooter would drift over the top of them. The garage shows each bike's specialty; the HUD names it bottom left and lights it while it's active.

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
  - *Rain:* jumps are ~5% shorter (weaker takeoff on a wet deck) and you slide forward ~13 px after landing before the tire grips again.
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
| Play plane | 1.0x | You, plus the switch tracks behind (smaller, hazed) and in front (bigger) on trails that have them. Flyers swoop in from the background (small, hazed, high) and settle into their real spot at least 190 px before you reach them, with a shadow on the deck marking where they'll be. |
| Foreground | 1.6x | Dark silhouettes per trail (saguaros, boulders, scrap, telegraph poles), grass tufts, fireflies at dusk/night, dust motes by day, tumbleweeds in wind. Kept to the bottom quarter, plus an occasional see-through post whipping past. |

The title screen runs the far and valley layers too, so rivals race behind the menu.

### Sound

- **Engines:** every bike model has its own engine, built from that engine's real firing order (V-twin chopper, 270-degree parallel twin, single, inline-4, inline-3, 2-stroke scooter, 212cc minibike). Idle at READY, launch to cruise at GO; pitch follows speed (rain slides, wind drag) and flares when the rear wheel is in the air. In the garage, picking a rider or a bike starts the engine and revs it (for a rider, the bike you have equipped), and tapping any bike tile, owned or not, lets you hear it before you buy.
- **Ambience:** birds by day; crickets at dusk and night. On top of that each trail has its own bed (table above): synthesized canyon wind, machine yard (hum, distant clanks in a shed, steam hiss), mine (rumble, echoing drips, timber creaks), mountain wind and, on Last Trestle, the collapse (low rumble, snapping timbers), plus the creek at Copper Canyon and Mesa Springs. The mine and the hoist yard drop the birds; Skyline Pass drops the crickets. Rain adds a rain bed. In wind, the wind recording's volume follows the same gust curve that pushes the bike.
- **Foley:** soft chimes tuned to the theme's key (coin streaks climb a pentatonic ladder), a soft whoosh on jumps, wooden thock on landings, splash in rain, plank-joint "ta-dak" while rolling, gentle crash with a falling two-note chime. Springs boing up a fifth, roof bonks knock, loops swoop, ziplines clink on and whine along the cable, and the bonus biplane drones in from behind with a Doppler drop as it passes.
- **Coins:** each coin is a short, dry chime (rings out in about 0.3 s, down from 1.1 s), and two coin voices alternate with each new coin damping the last, so a fast streak plays as separate notes.
- **Music:** three original loops from the same code-built band, crossfading when you enter a trail and back to the theme in menus (RETRY keeps the trail's loop going):
  - "Trestle Dreams", the theme: dreamy desert Americana in D, 78 BPM (tremolo guitar, pad, brushes, slide melody). Menus, Dusty Trail, Copper Canyon, Mesa Springs, Hoodoo Loops, Quarry Cliffs.
  - "Lantern Low": the same guitar turned dark and slow, B minor, 68 BPM, kick and a single brush. Night Trestle, Lantern Mine.
  - "Ridge Runner": up a tone in E, 96 BPM, driving train beat and walking bass. Rustyard, Hoist Yard, Skyline Pass, Rocket Ridge, Last Trestle.
- **Power-ups and letters:** a sparkle arpeggio for a pickup (a squelch for sticky tires, an ignition roar for the rocket), a tire-grip grind on the climb, a plastic clonk when the hard hat saves you, a dry crack as a plank gives way, two bright notes per letter and a seven-note run for the full word.
- **Tricks and tracks:** a quick whoosh per flip, rising chimes for a landed trick, a wobble knock for a sketchy one, and a rail clack when a switch ramp swings you across.
- **Story sounds:** grind rails clank as you land and then scrape and crackle for as long as you're on; wall-rides slap onto the boards with a boom under you; ropes creak as they take your weight. Bosses hum (a low wobbling drone that gets louder as you close in), each hit is a hollow metal bong with ringing glass and an alien yelp, a knockout is a crumpling bang and a falling alien warble, and getting a part back plays a bigger cousin of the gear chime. Achievements pop with three bright rising notes. Boss arenas have their own music loop, "Saucer Stomp" (the theme band at 116 BPM with a wobbling lead).
- **Settings:** MUSIC, SOUND and **ENGINE** sliders (0–100%, squared taper so 50% sounds about half as loud). ENGINE is the bike alone, so you can keep the music and chimes up and the engine down. Moving it revs your bike so you can hear the level (on the title screen's SETTINGS; in a paused run the engine is paused too). Music now starts at 50% (existing saves still at the old 100% default move to 50% once; any other level you set is kept) under SETTINGS on the title screen and in the pause menu. Sources and licenses: `CREDITS.md` and the in-game Credits screen.
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
  game_state.gd          autoload: wallet, unlocks, skins, story progress, save (user://save.json), input map, font/theme
  achievements.gd        autoload: the achievement list, unlocks, toasts, Play Games / Game Center bridge
  catalog.gd             riders, bikes, paint, Free Ride and story trails, story areas and parts, prices   <- economy knobs
  main.gd                screen switching, Android back button
  game/
    bike_physics.gd      deterministic 60 Hz physics, track features, bike specialties <- feel knobs
    level_library.gd     chunk builders (gaps, enemies, springs, tunnels, loops, lifts, ziplines)
    level_layouts.gd     the 12 Free Ride layouts, the 16 story layouts, hint-demo and test strips   <- level design
    autopilot.gd         lookahead bot: dev verify, the hint-card demos and the crash-hint line
    guide.gd             crash hints: wreck counting per stretch, tips, the hint line (worker thread)
    boss_art.gd          the four bosses
    story_art.gd         Grandpa's bike (filling in part by part), Grandma, the intro comic panels
    world.gd             one run: sim, pickups, checkpoints, bonus plane, camera, drawing
    feature_art.gd       pixel art for springs, tunnels, loops, lifts, ziplines, biplane
    backdrop.gd          parallax themes: day/dusk/night palettes per trail, weather skies
    weather_fx.gd        screen-space rain and wind layer, per-trail ambient particles
    letter_spots.gd      where each trail's T-R-E-S-T-L-E letters sit (generated, see Dev checks)
    world_art.gd         per-trail track builds and critter skins, switch-ramp signs
    bike_view.gd         bike models + riders drawn from primitives (paint = palette)
  screens/               title, trail select, story map and intro, achievements, garage, game (pause/results)
  ui/                    theme, HUD, widgets, hint card (live demo in a SubViewport), achievement badges
  audio/audio_director.gd  autoload: buses, engine, ambience, SFX pool, theme
  dev/                   bot, verifier, screenshots, input test, Movie Maker demo (excluded from export)
tools/audio/             python: engine models, SFX, ambience loops, theme; build.py regenerates assets/audio
tools/store/play_ids.py  Play Console achievement ids -> scripts/achievements.gd (see ACHIEVEMENTS.md)
store/achievements/      store icons and import files (not part of the game; .gdignore keeps it out of the APK)
```

Hold moves are chunks too: `["rail", 160.0]`, `["rail_chain", 3, 100.0]`, `["rope"]` (or `["rope", reach, length, count, spacing]`), `["wall", 180.0, 70.0]` (a fifth argument 1 makes it a launch lip), `["zip_up", ...]`, `["zip_chain", [160.0, 160.0]]`, `["zip_drops", ...]`. A boss arena is `["boss", kind, ...]`, then windows (`bw_low`, `bw_gap`, `bw_zip`, `bw_rail`, `bw_rope`, `bw_wall`, `bw_lip`: the stretch where the boss sits and the move that gets you above it), then `["boss_end"]`.

Levels are lists of chunks, e.g. `["gap", 56.0]`, `["branch_upper", 1]` (1 = put a gear on it), `["lifts", [[56, 18, 2.2, 0]], 48]`, `["zip", 300, 62, 30, 1]`, `["hills", 2, 14.0]`, `["kicker", 76.0, 40.0]`. A switch-track fork is `["fork", to_lane, [inner chunks], [main chunks], gear, forced]` with to_lane 1 = behind, -1 = in front; forced = 1 ends the main deck so the switch is the only way on. Adding a trail means a layout in `level_layouts.gd` plus an entry in `catalog.gd` (speed, price, theme, feature); new feature text goes in `Catalog.FEATURES`.

## Dev checks

```bash
godot --headless --path . -- --verify                                  # every trail x clear/rain/wind
godot --headless --path . -- --verify --level=rustyard --weather=wind  # one combo
godot --headless --path . -- --verify --bike=all                       # every bike's specialty too
godot --headless --path . -- --difficulty [--weather=rain] [--old]     # timing-window ramp
godot --headless --path . -- --physics-report                          # jump table, weather, specialties
godot --headless --path . -- --place-letters                           # regenerate letter_spots.gd after layout changes
godot --headless --path . -- --par                                     # par times for the gold medal
godot --headless --path . -- --probe                                   # collapse-chase margin on Last Trestle
godot --headless --path . -- --verify --set=story                      # just the story trails (or --set=free)
godot --headless --path . -- --verify --test=rail,rope:140             # the hold-move test strips (name[:speed])
godot --headless --path . -- --guide-test                              # crash-hint line from every checkpoint
xvfb-run -a godot --path . -- --ach-export=$PWD/store/achievements --ach-scale=2   # store icons + import files
```

- `--headless` runs with no window or audio
- `--` ends Godot's own flags; what follows goes to the game
- `--verify` makes the bot play each trail in each weather; exit code = runs it couldn't clear without crashing
- `--level=` / `--weather=` narrow it to one trail / one weather
- `--bike=` picks a bike (its specialty is active); `all` runs all seven
- `--difficulty` rides each trail like a careful person and prints the timing windows and forced jumps per 10 s; `--old` adds the v0.4 trails for comparison
- `--place-letters` runs the bot on every trail in clear and rain with no letters, then puts each letter on the most airborne coin it collected in both, one per seventh of the trail, and rewrites `scripts/game/letter_spots.gd`
- `--probe` rides Last Trestle in each weather and prints how close the collapse came
- `--par` prints each trail's par time (the bot's clean clear-weather time + 1 s, rounded up to the half second) for `Catalog.PARS`
- `--set=story|free` limits `--verify` to the story or Free Ride trails; `--test=` runs the short test strips in `level_layouts.gd` (`TESTS`) instead, each at the given speed
- `--guide-test` rides every trail in every weather and, at each checkpoint, works out the crash-hint line from there to the next checkpoint exactly as a wreck would; it reports any line that doesn't get through and how long the work took. Its other modes (listed at the top of `scripts/dev/guide_test.gd`): `--flow` (when hints switch on, and the crash skip), `--rope-windows` (catch and let-go windows per rope; add `--late` for a press after the hands pass), `--wheelie-probe`, `--pacing` (checkpoint stretches and quiet stretches), and probes for a single spot
- `--ach-export=` writes the store kit for achievements (needs a display, so `xvfb-run` on a server; see ACHIEVEMENTS.md)

Current result (v0.8.1):
- Plain bike: all 84 runs (12 Free Ride trails + 16 story trails, x 3 weathers) cleared with 0 crashes and 3/3 gears; every boss knocked out 3/3 without circling round, in every weather. Letters 7/7 in 67 of 72 trail runs (bosses have none); the misses are single letters except Hollow Oak in wind (two), all picked up by the bot in the other weathers.
- Every bike with its specialty active: all 588 runs cleared with 0 crashes, and no boss circles round on any bike. (In 0.8.0's first pass the scooter fell on rail-yard trails: holding to grind also opened its umbrella, which floated it over the rails. The umbrella now stays shut with a rail, wall-ride or rope just ahead.) Gears 3/3 in all but twelve runs, all of them the scooter floating past one. Letters 7/7 in 462 of 504 trail runs.
- `--guide-test`: from every checkpoint of every trail in every weather, the crash-hint line gets through to the next checkpoint (252 lines, 0 failures). Working it out took 2.0-4.2 ms per frame of line on this machine with another test running alongside (about 2.1-3.2 ms with a core to itself), against 16.7 ms per frame of riding, so the line runs well ahead of you on the worker thread.
- `--guide-test --rope-windows`: every rope that's caught from a deck has a let-go window of 416-500 ms (466 ms median), up from 266-383 ms before 0.8.1's fling. A press that comes 10 px after the hands pass the rope now catches it.
- `--guide-test --wheelie-probe`: on the scrambler, a press made 2 or more frames before touchdown and held through it wheelies; one in the last frame before, or after, jumps again.
- `--guide-test --pacing`: the longest stretch between checkpoints is now 24 s (Skyline Pass's middle one); 0.8.0 had 34, 28, 24 and 23 s final stretches on Skyline Pass, Hoodoo Loops, Rocket Ridge and Hoist Yard, which now have a third checkpoint.
- `--guide-test --flow` (nobody pressing): the hint comes on after the 2nd wreck at the first gap of Trail 1, the 3rd on Trail 4, the 5th on Trail 11, and the 2nd at a rail or wall-ride in any area.
- `--input-test`: taps and holds jump through the real touch pipeline; the pause and **?** buttons never leak a jump.
- `--demo=scroll` (add `--touch` to send screen-touch events instead of emulated mouse): finger drags that start anywhere on a trail card (panel, text, thumbnail, button) scroll the trail picker, a drag across a button doesn't press it, and a plain tap on RIDE still opens the picker. Same fix in the garage and credits lists.

## Not done yet

- Story areas 5-8 (carburetor, top end, bottom end, frame) and the ending where Grandpa's bike runs again.
- Achievements on the stores: the game side is done; the store accounts, plugins and Gradle build are the steps in [ACHIEVEMENTS.md](ACHIEVEMENTS.md).
- In-app purchases and ads: Godot needs platform plugins for Google Play Billing, StoreKit and an ad network, plus consent handling. Next phase.
- Hand-drawn sprite art (current art is code-drawn placeholders that already read as pixel art)
- More enemy types and trails; a best-time leaderboard

Font: Press Start 2P, SIL Open Font License (`assets/fonts/OFL.txt`).
