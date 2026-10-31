# Trestle Run (working title)

One-button motorcycle runner for Android/iOS, built in **Godot 4.7** (GL Compatibility renderer, 2D pixel art drawn in code). Inspired by the mine-cart *mechanic*, with original names, art and characters throughout.

Five ways to play from the title screen: **STORY** (win back the parts of Grandpa's motorcycle, area by area, boss by boss), **FREE RIDE** (the twelve trails, any time and weather), **SUMMIT** (twelve physics hill climbs on one tank of fuel, with upgrades), **GAUNTLET** (twelve physics obstacle courses against the clock) and **CHALLENGES** (a new daily ride, daily missions, endless runs, a weekly league and a season pass). All share the garage, the wallet and the achievements. STORY, FREE RIDE and CHALLENGES are the one-button runner; SUMMIT and GAUNTLET are ridden with two pedals, gas and brake.

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
- **Settings** (title screen): GHOST RUN, CRASH HINTS, VIBRATION, SCREEN SHAKE and SHARP PIXELS on/off, and CHEATS (below); CRASH HINTS is in the pause menu too. SHARP PIXELS (on unless you turn it off) draws the game at a whole-number zoom so every pixel is the same size: on the Fold's inner screen that's 4x with a 552 x 460 view (a little more trail ahead and above you) instead of 480 x 399 stretched 4.6x, where some pixel columns come out wider than others and edges shimmer as the trail scrolls. The outer screen is already an exact 4x, so it looks the same either way. SCREEN SHAKE off keeps the camera still on bonks, crashes and boss hits.
- **Rope cue:** in the air with your hands at catch height and a rope just ahead (or a moment behind, for a late catch), the stretch of rope you can grab lights up gold; it brightens while you're holding.
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

### Challenges

CHALLENGES on the title screen (a gold dot on the button when today's ride is waiting or there's a reward to take). Everything here runs offline: days, weeks and seasons come from the phone's date, so every phone gets the same daily course and league line.

- **Daily ride:** a new course every day, stitched from stretches of all 24 trails (see Endless), with checkpoints and letters. It gets quicker through the week (118 px/s on Monday, 130 Tuesday-Wednesday, 142 Thursday-Friday, 154 at the weekend) and has the day's own weather, time of day and look. Clearing it pays 100 coins and 60 season XP once a day; no crashes and under par (the dev bot's time + 1 s) adds 40 XP. Your best run that day rides along as the ghost.
- **Event (since 0.11):** one at a time, ridden with SUMMIT's or GAUNTLET's physics on a course of its own, on stock bikes (no upgrades, so the tiers mean the same for everyone). Around holidays a themed one runs: FIREWORKS (1-7 January, a trick attack at night), SWEETHEART RUN (10-16 February, collect hearts), EGG HUNT (28 March-10 April, eggs), SPARKLER LEAP (1-7 July, a long jump), MOON HOP (16-24 July, low gravity), PUMPKIN PATCH (24 October-2 November, pumpkins at night) and SNOW DAY (18-31 December, a time attack with 70% grip). The rest of the year it's a new one each week, round five kinds, three courses each: LONG JUMP (one big ramp: how far you fly, if you ride it out), TIME ATTACK, TRICK ATTACK (60 seconds of kickers; air-trick points), LAST DROP (ten seconds of fuel on a long rolling road: how far you get, coasting included) and COLLECT (stars on a short climb). Bronze, silver and gold pay 100, 200 and 400 coins and 30, 60 and 100 season XP, once each per event. No tickets or limits: ride it as often as you like. `scripts/drive/events.gd`.
- **Missions:** three a day from eighteen kinds (land flips, stomp critters, grind rails, swing on ropes, ride ziplines, ride so far in one endless run, finish the daily ride, find T-R-E-S-T-L-E, land air tricks in SUMMIT or GAUNTLET, ride the event...). They count in every mode. +40 coins and +40 XP each, +50 and +60 more for all three.
- **Login streak:** the first time the title screen opens each day, the streak's reward: 25, 40, 60, 80, 100, 125, then 200 coins on day 7, round again. Miss a day and it starts over.
- **Endless:** one life, and the course never repeats: stretches of every Free Ride and story trail (cut at their checkpoints, bosses aside) one after another, joined by flat decks that bring the course back to level. The speed steps up every four stretches, about every kilometre, from 118 to 166 px/s (the quickest trail is 158). Distance in metres (8 px to the metre), your best on the card and the HUD, coins plus 1 per 10 m. It's in the current season's look, and the time of day follows your clock.
- **Weekly league:** the same endless line all week (Monday to Sunday) for everyone; your best distance that week counts. You're in a group of 20 with 19 computer rivals (there's no server yet), in five divisions: DIRT, GRAVEL, TIMBER, IRON, GOLDEN SPIKE. Top 5 move up, bottom 5 move down, and the week's place pays 600/350/150/50 coins and 300/200/100/50 XP (1st, 2nd-3rd, 4th-10th, the rest). The HUD shows the next rival to pass. Rivals are modelled on the line itself: each forced jump on it has the timing window the careful rider measured there, a rival fumbles it more often the narrower that window is (and more often in DIRT than in GOLDEN SPIKE), the line gets quicker the same way yours does, and they get one more run each day of the week. So an easier week's line means longer rival runs, the same as yours. Calibrated (`tools/endless/league_calibrate.py`) so a group's middle rider ends the week near 1.2 km in DIRT, 2.2 in GRAVEL, 3.5 in TIMBER, 5.5 in IRON and 8.5 in GOLDEN SPIKE; they start the week lower.
- **Season pass:** a season lasts three weeks and takes one trail's look (season 1 is Copper Canyon; they go round all sixteen). 30 tiers at 100 XP; XP comes from every run (10, plus up to 80 for distance), missions, the daily ride, the streak and the league. The free track pays coins and two season paints; the gold track three more paints (the last with flames) and more coins. The gold pass costs 1,500 coins for now: selling it for real money needs the store billing plugins and accounts, which are the next phase. Season paints show in the garage once you have them (and the current season's, marked SEASON PASS).

### SUMMIT and GAUNTLET (since 0.10)

Two physics modes with their own levels, ridden on any bike in the garage. Instead of the runner's one button there are two pedals: on a touch screen the right half of the screen is **GAS** and the left half **BRAKE** (both at once is fine); on a PC, Right/D/Up/W/Space is gas and Left/A/Down/S brake, and on a pad the right trigger (or A, or d-pad right) and the left trigger (or X, or d-pad left). The bike is a real little rigid body (`scripts/drive/vehicle_sim.gd`): wheels on sprung suspension, a motor with the bike's own torque curve (the battery bikes hold full torque nearly to top speed), brakes that dip the nose, tyre grip, and the rider's weight. The rider's head, chest or shoulders touching the ground (or a crate or log) is a crash, and so is the bike coming to rest upside down or stood on its tail (before 0.10.1 only the head counted, so a bike could lie on its back with the rider in the ground and carry on). Gas also leans you back and brake leans you forward: in the air that's how you rotate (and flip), on the ground how you lift or plant the front wheel. **SWAP LEAN** in the pause menu turns that round (gas tips the nose down).

- **SUMMIT:** twelve hill climbs (900 m to 2.1 km) to a summit flag, each on one tank of fuel, topped up by fuel cans along the way (charge points on the battery bikes). Bridges over valleys, kicker gaps over pits on the later ones, and from climb 2 short straight walls (33-34 degrees, 59-71 px high, one to four a climb) with a flat run-in and a shelf on top; the hills themselves stay under 26 degrees. Since 0.11 there are jump ramps too (one on climbs 2-4, two on 5-8, three after): a 25 px kicker with the ground falling away down a 32-degree landing, about half a second of air at speed, with coins in the air off the lip. Full gas on the flat lifts the front a little; up a climb of about 30 degrees or more it keeps lifting until you're over backwards, so you ease off up the walls and let momentum carry you (`--drive-hold`, below, checks that holding gas the whole way only gets to the top of climb 1). ENGINE upgrades add power at speed rather than shove off the line, and their extra push is capped short of what lifts the front, so an upgraded bike loops no more readily than a stock one. On the electric unicycles, asking the motor for more than it has, under gas, for a third of a second cuts it out and throws you; it has less the faster you're going (as a hub motor does), so charging a wall flat out cuts out: slow down and lean up it. (Since 0.11 they brake up to 1.8 times as hard as they drive, as a real wheel's regenerative braking can, so they get down the jump ramps' landings.) Coins on the way (5, and 25 for the big ones), +25 per flip landed. Run out of fuel and roll to a stop, or crash, and the ride ends with what you've collected. Coins buy **upgrades** for each bike separately (ENGINE/MOTOR, SUSPENSION, TIRES, TANK/BATTERY, five levels each, 120 to 1,250 coins a level), and the later climbs need some. A climb opens when the one before is reached. Reaching a summit the first time pays 100 coins (20 more for each climb further along); silver and gold, under the medal times, pay again.
- **GAUNTLET:** twelve obstacle courses (ramps, steps, crates, logs, stairs, blocks, whoops, kickers and gaps) with checkpoints. A crash is a **fault**: you're back at the last checkpoint with the clock still running. Bronze for finishing, silver under the silver time with at most 2 faults, gold under the gold time with none. Trials technique: the rider throws their weight hard (a tap of gas pops the front up), but only so far: past about 34 degrees nose-up from the slope ahead (never past 50 degrees) they hold the bike there, so holding gas gives a wheelie rather than a loop-out. **Hop:** brake (lean forward, the suspension dips) then gas within 0.3 s (pull back) and the bike springs about 8 px into the air; with the front up, that gets the front wheel onto a ledge, and the back tyre grips the face under gas and climbs it. So the scrambler gets up a step, block or table twice its wheel's height and over a log of radius 6, where holding gas stops at 4 px. Signs on the first two courses show it. Upgrades don't apply here.

- **Air tricks (since 0.11):** two quick taps in the air: BRAKE then GAS is a WHIP (the same flick that hops you on the ground), GAS GAS a NO-HANDER, GAS then BRAKE a HEEL CLICKER, BRAKE BRAKE a SUPERMAN (a tap is a press let go within 0.22 s, the second coming within 0.32 s; holding a pedal still just tips the bike). The trick starts on the second press but only counts once that's let go within 0.22 s too; held, it's called off with no harm done (so a dab of brake then gas held to steer isn't a whip). While a trick is on (0.16 to 0.34 s) the rider is off the seat and can't steer the bike in the air; 80% of it has to be done before the wheels touch, or you bail (a crash, or a fault). With the taps, a whip wants about a third of a second of air and a superman nearly half. Tricks and flips in a row make a combo, which carries on while you take off again within 0.8 s of landing; each one after the first adds x0.25 (to x3) and the same trick twice in one combo counts half. SUMMIT pays the combo in coins when it's banked (whip 10, no-hander 15, heel clicker 20, superman 30, flip 25), GAUNTLET counts points (x10) toward objectives and events; medal times are still just time. Lost if you crash. AIR TRICKS on/off in the pause panel, which also lists the taps. SUMMIT's climbs from 2 on have jump ramps for them (below), and signs on climbs 2-3 and before MIND THE GAP's big kicker say how.
- **Ghosts (since 0.11):** a see-through rider to race. GHOST: BEST (top of the level select) is your own best run on that level (the fastest finish, or before you've finished, the furthest you've got), and the GOLD LINE until you have one; GHOST: GOLD is always the gold line, the level checker's own winning ride on the scrambler (gold-tinted; on SUMMIT, on that climb's listed upgrades); GHOST: OFF. Rides are recorded as where the bike was drawn, 30 times a second, not as inputs, so they play back the same on any phone or PC. `scripts/drive/ghost.gd`; the gold lines are `assets/lines/*.bin`.
- **Objectives (since 0.11):** three a level beyond the medals, stars on the level cards, listed as the ride starts, in the pause panel and on the results; 60, 100 and 150 coins the first time. They're made from what the level checker's own ride did (`scripts/drive/extras_table.gd`, from `--drive-air`, below), so each one has been seen done: pick up so many coins, land so many air tricks or a particular one (only on jumps where the checker landed it and rode away), score so many trick points, top a climb with so much fuel left, a clean GAUNTLET run, so few hops, or finish on a battery bike or an electric unicycle (one the checker got through).

Levels are built from a seeded recipe (SUMMIT, `scripts/drive/summit_levels.gd`) or a list of moves (GAUNTLET, `scripts/drive/gauntlet_levels.gd`), so every device gets the same ones. Every level is checked by a beam search over the same sim (`--drive-levels`, below), which proves it can be ridden and sets the medal times. Not every bike suits every level (small wheels don't get up big steps, the electric unicycles can't wheelie); the level cards say **TOUGH ON THIS BIKE** when the checker didn't get your bike through.

### Cheats

GoldenEye-style: each one unlocks by beating a time on one trail in one weather (DK Mode was Runway on Agent in under 5:00). Any bike, any time of day; it's just the clock, so a crash usually costs too much. Each target is the dev bot's clean time there plus a second, and the bot doesn't wheelie, so a wheelie bike helps. Switch them on and off under SETTINGS > CHEATS. Cosmetic only.

| Cheat | What it does | Unlock |
|---|---|---|
| BIG HEAD | Every rider's head twice the size (in runs, the garage and the menus) | Dusty Trail in the rain in under 49.5 s |
| RAINBOW TRAIL | A rainbow streams behind you in the air | Copper Canyon in the wind in under 63.5 s |
| PAINTBALL | Landings and crashes splat your paint on the deck | Rustyard in the rain in under 48.5 s |

### Achievements

46 achievements, from finishing the first story trail to recovering each part, beating a boss without a scratch, gold medals, stomps, rail grinds and catching prize sacks, and (since 0.9.1) the calendar modes: 1 km and 5 km in one endless run, 7 daily rides, all three missions in a day, a 7-day streak, a league promotion, first place in a league week, the Golden Spike division, the last tier of a season pass, and all three cheats; and (since 0.10) SUMMIT and GAUNTLET: a summit, all twelve, a course, a course with no faults, all twelve. 1,000 points in all, Game Center's cap. They unlock in the save, pop a toast, and show on the ACHIEVEMENTS screen (title screen) with progress for the counted ones. Progress from an older save counts. The game reports them to Google Play Games and Apple Game Center when those plugins are in the build; that part needs store accounts, and [ACHIEVEMENTS.md](ACHIEVEMENTS.md) is the step-by-step, with the store icons and import files already generated in `store/achievements/`.

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

In the runner every bike keeps the same one-button control and hitbox; each adds one move. (In SUMMIT and GAUNTLET each bike instead rides with its own build: wheelbase, wheel size, power, grip, suspension, weight.)

| Bike | Specialty | How |
|---|---|---|
| Scrambler | Wheelie +10% | Hold the button as you land: front wheel up, speed builds while you hold, then bleeds off |
| Dirt bike | Big wheelie +14% | Same, stronger |
| Sportbike | Power wheelie +18% | Same, strongest |
| Minibike | Double hop | Tap again in the air for one more hop |
| Scooter | Umbrella | Hold while falling to float down slowly |
| Cafe racer | Air dash | Tap in the air to dash forward |
| Chopper | Iron hide | Smash through one enemy per checkpoint (falls still count) |
| Zip e-moped | Umbrella | As the scooter |
| Commuter e-bike | Double hop | As the minibike |
| Spark e-dirt | Wheelie +12% | As the scrambler |
| Boulder fat e-bike | Iron hide | As the chopper |
| Mono e-wheel | Double hop | As the minibike |
| Surge e-street | Air dash | As the cafe racer |
| Goliath e-wheel | Iron hide | As the chopper |

Wheelie or jump again: on the wheelie bikes, a press in the air that you're still holding when the wheels touch is a wheelie, unless it came on the very last frame before touchdown or on touchdown itself (a "jump again as I land" press). A tap you let go of before touchdown still jumps again on landing, and a press after touchdown always jumps. (Before 0.8.1 any press in the last 0.12 s before touchdown jumped again, which is what kept turning wheelies into jumps.) An air press within a few pixels of landing still counts as a buffered jump rather than a specialty move. On story trails the scooter's umbrella stays shut when a rail, wall-ride or rope is just ahead: holding there means "grab", and a floating scooter would drift over the top of them. The garage shows each bike's specialty; the HUD names it bottom left and lights it while it's active.

### Bonus plane

Every 22-38 s a biplane overtakes you with a prize sack on a rope (10 coins on Trail 1, +3 per trail). It is only sent when the stretch where it will catch up is calm (plain deck, nothing to jump or dodge), and its speed is set so the sack reaches you right there, hanging where a good long jump grabs it. You hear it coming from behind.

### Garage

Mix and match three things, each bought with coins (`scripts/catalog.gd`):

- **Riders (8):** Dusty, Granny Grit (scarf), Bandit (raccoon), Bones (skeleton, hair on fire), Zorp (alien), Robo-7, Finn (land shark), Big Frosty (yeti). Scarves, tails and flames stream harder in wind and in the air.
- **Bikes (14):** scrambler, dirt bike, minibike, scooter, cafe racer, chopper, sportbike, and (since 0.10) seven battery ones: the Zip e-moped, the Commuter e-bike, the Spark electric dirt bike, the Boulder fat-tyre e-bike, the Mono and Goliath electric unicycles (one wheel, the rider standing on the pedals and balancing it: lean forward to go, back to slow) and the Surge electric streetbike.
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

- **Engines:** every gas bike has its own engine, built from that engine's real firing order (V-twin chopper, 270-degree parallel twin, single, inline-4, inline-3, 2-stroke scooter, 212cc minibike). The battery bikes have electric drives instead (`tools/audio/electric.py`): the motor's whine at its electrical frequency and the orders a three-phase motor sings at, a faint inverter tone, the gear whir of a hub or mid-drive on the e-bikes (and their freewheel ticking at idle), chain or belt noise, and tyre roar with tread pulses on the knobby and fat tyres; idle is a quiet "ready" hum, and on the unicycles a wavering balance hum. Idle at READY, launch to cruise at GO; pitch follows speed (rain slides, wind drag) and flares when the rear wheel is in the air. In the garage, picking a rider or a bike starts the engine and revs it (for a rider, the bike you have equipped), and tapping any bike tile, owned or not, lets you hear it before you buy.
- **Ambience:** birds by day; crickets at dusk and night. On top of that each trail has its own bed (table above): synthesized canyon wind, machine yard (hum, distant clanks in a shed, steam hiss), mine (rumble, echoing drips, timber creaks), mountain wind and, on Last Trestle, the collapse (low rumble, snapping timbers), plus the creek at Copper Canyon and Mesa Springs. The mine and the hoist yard drop the birds; Skyline Pass drops the crickets. Rain adds a rain bed. In wind, the wind recording's volume follows the same gust curve that pushes the bike. Story areas have their own beds: Grandma's Farm a breeze over the hay, porch wind chimes (in the farm loop's key) and the windmill pump; the Rail Yard the machine yard; the Old Orchard rustling leaves, a distant owl and the odd apple dropping; the County Speedway the crowd in the stands, a cheer now and then and bikes buzzing round the far track. Everything is stereo at 44.1 kHz, and the loops are long: the recordings 40-96 s, the synthesized beds 48 s, the wind 42 s (rebuilt from slices of its 15 s recording so there's no seam).
- **Foley:** soft chimes tuned to the theme's key (coin streaks climb a pentatonic ladder), a soft whoosh on jumps, wooden thock on landings, splash in rain, plank-joint "ta-dak" while rolling, gentle crash with a falling two-note chime. Springs boing up a fifth, roof bonks knock, loops swoop, ziplines clink on and whine along the cable, and the bonus biplane drones in from behind with a Doppler drop as it passes.
- **Coins:** each coin is a short, dry chime (rings out in about 0.3 s, down from 1.1 s), and two coin voices alternate with each new coin damping the last, so a fast streak plays as separate notes.
- **Music:** eight original loops from the same code-built band, all 32 bars, crossfading when you enter a trail and back to the theme in menus (RETRY keeps the trail's loop going; the story map plays the loop of the area you're up to):
  - "Trestle Dreams", the theme: dreamy desert Americana in D, 78 BPM (tremolo guitar, pad, brushes, slide melody). Menus, Dusty Trail, Copper Canyon, Mesa Springs, Hoodoo Loops, Quarry Cliffs.
  - "Lantern Low": the same guitar turned dark and slow, B minor, 68 BPM, kick and a single brush. Night Trestle, Lantern Mine.
  - "Ridge Runner": up a tone in E, 96 BPM, driving train beat and walking bass. Rustyard, Hoist Yard, Skyline Pass, Rocket Ridge, Last Trestle.
  - "Hayloft Shuffle" (Grandma's Farm): C major, 92 BPM, a swung two-beat and a front-porch tune on the slide.
  - "Coal Smoke" (the Rail Yard): E minor blues on a train beat, 104 BPM.
  - "Windfall" (the Old Orchard): slow F major with brushes, 72 BPM.
  - "County Fair" (the Speedway): A mixolydian boogie, 120 BPM, kick on every beat and a walking bass.
  - "Saucer Stomp" (every boss): D minor, 116 BPM, train beat, the lead turned into a wobbly theremin.
- **Power-ups and letters:** a sparkle arpeggio for a pickup (a squelch for sticky tires, an ignition roar for the rocket), a tire-grip grind on the climb, a plastic clonk when the hard hat saves you, a dry crack as a plank gives way, two bright notes per letter and a seven-note run for the full word.
- **Tricks and tracks:** a quick whoosh per flip, rising chimes for a landed trick, a wobble knock for a sketchy one, and a rail clack when a switch ramp swings you across.
- **Story sounds:** grind rails clank as you land and then scrape and crackle for as long as you're on; wall-rides slap onto the boards with a boom under you; ropes creak as they take your weight. Bosses hum (a low wobbling drone that gets louder as you close in), each hit is a hollow metal bong with ringing glass and an alien yelp, a knockout is a crumpling bang and a falling alien warble, and getting a part back plays a bigger cousin of the gear chime. Achievements pop with three bright rising notes.
- **Settings:** MUSIC, SOUND and **ENGINE** sliders (0–100%, squared taper so 50% sounds about half as loud). ENGINE is the bike alone, so you can keep the music and chimes up and the engine down. Moving it revs your bike so you can hear the level (on the title screen's SETTINGS; in a paused run the engine is paused too). Music now starts at 50% (existing saves still at the old 100% default move to 50% once; any other level you set is kept) under SETTINGS on the title screen and in the pause menu. Sources and licenses: `CREDITS.md` and the in-game Credits screen.
- **Mix:** set from Movie Maker captures of real gameplay with each bus soloed: engine and theme near -24 LUFS, chimes -24, nature bed -33, about -19 LUFS overall.
- **Quality:** music and sound effects are Ogg Vorbis at q5 (about 160 kbps), ambience q4, engines q6, with 8 s engine loops. (Up to 0.8.1 these were squeezed to fit a 30 MB APK cap that's since been dropped: music at q0-q1 with 16-bar trail loops, beds mono at 22 kHz and 10-26 s long, sound effects at q2, 4 s engine loops, and the story areas borrowing Free Ride's music.)
- **Swapping sounds:** bring a bounce in with `tools/audio/import_audio.py` (see [ART_AND_AUDIO.md](ART_AND_AUDIO.md)). It cuts a seamless loop, matches the old file's loudness and channels, and marks it so `build.py` won't overwrite it. Real engine recordings go in as `<bike>_idle.ogg` / `<bike>_cruise.ogg`.

Debug builds only: tap the wallet on the title screen 5 times for +500 coins to test unlocks.

## Making art and music

[ART_AND_AUDIO.md](ART_AND_AUDIO.md) is the how-to. It covers:
- every piece of art the game would need by hand, with sizes, frames, the bike wheel points and the colours the game swaps;
- the store and app icon sizes for Play, Steam and iOS;
- the tools: Aseprite or the free Pixelorama for art, Pro Tools or the free Ardour for music;
- bouncing seamless loops and bringing them in with `tools/audio/import_audio.py`.

The art is all drawn in code today, so hand-made art needs a loader per group (not written yet). Audio drops straight in.

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

The package is `com.pre_release.Trestlerun`, the name registered to the app in Play Console; it can't change once a bundle is uploaded. A debug build sideloaded with `--install` can't replace a copy installed from Play (different signing key: `adb` says `INSTALL_FAILED_UPDATE_INCOMPATIBLE`), so on a phone that has the Play copy, test through Play's internal testing instead, or uninstall it first (which wipes its save).

## Build the app bundle for Play Console

Play takes Android App Bundles (`.aab`), not APKs. Godot writes one itself only from a Gradle build, which needs the Android build template and Google's Maven; `tools/android/make_aab.py` makes one from the release APK instead, with Google's `aapt2` and `bundletool`:

```bash
GODOT_ANDROID_KEYSTORE_RELEASE_PATH=~/.android/debug.keystore \
GODOT_ANDROID_KEYSTORE_RELEASE_USER=androiddebugkey \
GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=android \
  godot --headless --path . --export-release "Android" build/trestle-run-release.apk
TRESTLE_UPLOAD_PASSWORD='<from trestle-upload-key.txt>' \
  python3 tools/android/make_aab.py --apk build/trestle-run-release.apk --out build/trestle-run.aab \
    --aapt2 ~/Android/Sdk/build-tools/35.0.1/aapt2 --bundletool ~/bundletool-all-1.18.3.jar \
    --keystore ~/keys/trestle-upload.jks --alias upload --verify
```

- `GODOT_ANDROID_KEYSTORE_RELEASE_*`: the keystore Godot signs the APK with. Any key does (the bundle step drops that signature), so the debug key is fine here.
- `--export-release "Android"`: a release build from the preset named Android (no debugging, as Play requires).
- `TRESTLE_UPLOAD_PASSWORD`: the upload keystore's password, read from the environment so it stays out of your shell history's arguments (`--password-env` names a different variable).
- `--apk` / `--out`: the APK to convert and the bundle to write.
- `--aapt2`: Android's resource compiler, in the SDK's `build-tools` (`build-apk.sh` installs 35.0.1).
- `--bundletool`: Google's bundle tool, `bundletool-all-<version>.jar` from [its releases](https://github.com/google/bundletool/releases) (1.18.3 used here; SHA-256 `a099cfa1…028e29`).
- `--keystore` / `--alias`: the upload key every bundle for this app must be signed with (see below). Leave `--keystore` off for an unsigned bundle.
- `--verify`: have bundletool build the APKs Play would serve from the bundle and check them against the source APK (below).

What it does, in order: adds the `themed_icon.xml` that Godot's exporter leaves out while its resource table still lists it (an installed APK never notices; aapt2 and bundletool refuse); converts the manifest, resource table and XML resources to aapt2's protobuf format; lays the files out as the bundle's `base` module, with the baseline profile as bundle metadata, where Android's Gradle plugin puts it; writes a bundle config that keeps every file Godot stored uncompressed that way in Play's APKs, and stores native libraries uncompressed and 16 KB page aligned on devices that can load them so (Play has required 16 KB page support since November 2025; the engine's libraries are built for it); runs `bundletool validate`; signs with `jarsigner` (SHA-256 with RSA).

`--verify` checks the universal APK bundletool makes (what a device that takes everything gets) has every dex, native library, asset and resource file byte for byte as in the APK, the same manifest, XML resources and resource table (through `aapt2 dump`, allowing only the two `<meta-data>` tags and `res/xml/splits0.xml` bundletool adds to every APK it makes) and the same `aapt2 dump badging`; and that an arm64 Android 14 phone's split set gets both libraries uncompressed at 16 KB-aligned offsets, `extractNativeLibs=false` and the baseline profile.

**The upload key** (`trestle-upload.jks`, alias `upload`, RSA 4096, made with `keytool -genkeypair -keystore trestle-upload.jks -storetype PKCS12 -alias upload -keyalg RSA -keysize 4096 -validity 10000`) is how Play knows an upload is yours: the first bundle registers it, and later ones must match. Play App Signing keeps the key that signs what phones install. Keep the keystore and its password backed up and out of the project folder. Lost or leaked, it can be reset from Play Console's app signing page, but that's slow.

Every upload needs a higher `version/code` in the Android preset than the last one (0.9.0 was 12, 0.9.1 13, 0.10.0 14, 0.10.1 15, 0.11.0 is 16).

## Windows and Linux (Steam)

```bash
python3 tools/steam/make_steam_build.py --godot godot
```

- `--godot`: the Godot 4.7.2 binary. The Windows and Linux export templates must be installed (Editor > Manage Export Templates, or extract `windows_release_x86_64.exe` and `linux_release.x86_64` from the official `Godot_v4.7.2-stable_export_templates.tpz` into `~/.local/share/godot/export_templates/4.7.2.stable/`).
- `--no-export`: zip what's already in `build/windows` and `build/linux` instead of exporting again.
- `--app <id> --win-depot <id> --linux-depot <id>`: also write `build/steam/app_build_<id>.vdf` for SteamPipe (the three ids come from Steamworks once the app exists).

It exports the **Windows Desktop** and **Linux** presets (x86_64, release, PCK beside the executable; the Windows .exe gets the game icon and version info from `assets/icon/trestle-run.ico` and the preset) and zips each into `build/TrestleRun-<version>-windows.zip` / `-linux.zip` for trying outside Steam. Upload to Steam with Valve's `steamcmd`:

```bash
steamcmd +login <steam user> +run_app_build "$PWD/build/steam/app_build_<id>.vdf" +quit
```

- `+login <steam user>`: your Steamworks account (it asks for the password and Steam Guard code).
- `+run_app_build <file>`: upload both depots as described in that file (one depot per OS, each from its build folder).
- `+quit`: exit when done. The build then appears under SteamPipe > Builds, where you set it live on a branch.

In Steamworks, set the launch options to `TrestleRun.exe` (Windows) and `TrestleRun.x86_64` (Linux), and the Linux runtime to Steam Linux Runtime 3.0 (sniper).

On a PC the game starts fullscreen (**FULLSCREEN** in Settings, or F11 / Alt+Enter), Esc or B goes back, the title has **QUIT**, and the menus work with arrow keys or a pad: the first d-pad, stick or A press puts a focus ring on the button nearest the middle, then the d-pad moves it, A presses and B backs out (`scripts/ui/nav_input.gd`). In a run, nothing holds focus, so Space, click and A always jump. The save lives in `%APPDATA%\Godot\app_userdata\Trestle Run` (Windows) or `~/.local/share/godot/app_userdata/Trestle Run` (Linux).

## iOS

Godot exports iOS as an Xcode project, and that export has to run on **macOS with Xcode** ([source](https://github.com/godotengine/godot-docs/blob/4.7/tutorials/export/exporting_for_ios.rst)). On an Arch daily driver that means a borrowed Mac, a Mac mini, or a hosted macOS CI runner. The iOS preset is included; it needs your 10-character App Store Team ID.

## Project layout

```
scripts/
  game_state.gd          autoload: wallet, unlocks, skins, story progress, save (user://save.json), input map, font/theme
  achievements.gd        autoload: the achievement list, unlocks, toasts, Play Games / Game Center bridge
  challenges.gd          autoload: daily ride, missions, streak, endless records, weekly league and rivals, season pass, cheats
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
    endless.gd           endless/daily/league courses from trail stretches; endless_table.gd (generated) says which are safe at which speed
    feature_art.gd       pixel art for springs, tunnels, loops, lifts, ziplines, biplane
    backdrop.gd          parallax themes: day/dusk/night palettes per trail, weather skies
    weather_fx.gd        screen-space rain and wind layer, per-trail ambient particles
    letter_spots.gd      where each trail's T-R-E-S-T-L-E letters sit (generated, see Dev checks)
    world_art.gd         per-trail track builds and critter skins, switch-ramp signs
    bike_view.gd         bike models + riders drawn from primitives (paint = palette)
  drive/                 SUMMIT and GAUNTLET
    vehicle_sim.gd       the rigid-body bike: suspension, motor, brakes, grip, lean, unicycle balance  <- feel knobs
    vehicles.gd          each bike's build (wheel positions from its drawing, power, grip...) and the upgrades
    terrain.gd           collision segments, bucketed by x
    summit_levels.gd     the twelve hill climbs (seeded recipe) and their fuel, coins, bridges, gaps
    course.gd            GAUNTLET's move builder (steps, ramps, crates, logs, pits...), corners rounded
    gauntlet_levels.gd   the twelve courses as lists of moves
    drive_world.gd       one ride: sim at 60 Hz, input, fuel, checkpoints and faults, camera, drawing
    drive_hud.gd / drive_art.gd   pedals, gauges; ground, scenery, props
    drive_progress.gd    records, medals, payouts, upgrades (in the save)
    drive_search.gd      beam search over gas/coast/brake, for the level checker
    drive_table.gd       medal times and which bikes got through (generated by --drive-levels)
    tricks.gd            air tricks: the taps, the combo, what it pays
    ghost.gd             ghost rides: record, play back, the gold lines (assets/lines/, --drive-levels --lines)
    objectives.gd        the three objectives per level; extras_table.gd (generated by --drive-air) holds them
    events.gd            the events: calendar, courses, scoring; event_table.gd (generated by --event-check)
  screens/               title, trail select, story map and intro, achievements, garage, challenges, season pass, game (pause/results)
  ui/                    theme, HUD, widgets, hint card (live demo in a SubViewport), achievement badges
  audio/audio_director.gd  autoload: buses, engine, ambience, SFX pool, theme
  dev/                   bot, verifier, screenshots, input test, Movie Maker demo (excluded from export)
tools/audio/             python: engine models, SFX, ambience loops, theme; build.py regenerates assets/audio,
                         import_audio.py brings in DAW bounces (kept by build.py)
tools/store/play_ids.py  Play Console achievement ids -> scripts/achievements.gd (see ACHIEVEMENTS.md)
tools/endless/make_table.py  --endless-check output -> scripts/game/endless_table.gd
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
godot --headless --path . -- --ach-test                                # the calendar-mode achievements unlock on cue
xvfb-run -a godot --path . -- --nav-test --no-streak                    # keyboard / pad menu navigation
python3 tools/icons/make_launcher_icons.py                              # launcher icon layers + Play's 512 px icon
python3 tools/store/make_store_art.py --godot godot                     # Play feature graphic + 8 screenshots (needs xvfb-run)
godot --headless --path . -- --endless-check [--part=0/2]               # ride every trail stretch at every endless speed
python3 tools/endless/make_table.py check_*.log                          # ...and write scripts/game/endless_table.gd
godot --headless --path . -- --endless-ride=1-20 [--bike=all] [--mode=daily --weather=rain]  # whole built courses
godot --headless --path . -- --drive-physics [--bike=mono]               # each bike's sim: rest, launch, brake, climbs, drops
godot --headless --path . -- --course-calibrate [--bike=a,b --only=step_up]  # how big each GAUNTLET obstacle can be
godot --headless --path . -- --drive-levels --bikes=all --write          # ride every SUMMIT/GAUNTLET level, write drive_table.gd
godot --headless --path . -- --drive-hold [--mode=summit --bikes=a,b --up=req|max]  # gas held the whole way: how far it gets
godot --headless --path . -- --drive-levels --write --lines            # also save each level's gold line ghost
godot --headless --path . -- --drive-air --write                       # jumps with room for tricks; the objectives
godot --headless --path . -- --event-check --write                     # ride every event course, set its tiers
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
- `--endless-check` rides each stretch of each trail on its own (start, joint, the stretch, joint, finish) at 118, 130, 142, 154 and 166 px/s: the bot in clear weather at three arrival times 0.85 s apart (lifts and moving critters run on the clock, so a stretch has to work whenever you get there), once in rain and once in wind, then the careful rider in clear for its timing windows. A stretch is used at a speed only if all of that passes with no crash and the tightest window is at least 75 ms. `--part=k/n` splits the work over n processes (run them side by side). `make_table.py` collects the output into `endless_table.gd`; rerun both after changing a layout.
- `--endless-ride=a-b` builds the endless courses for seeds a..b and has the bot ride each to the end (one life; `--max-m=` stops early), on one bike or `--bike=all`; `--mode=daily` builds daily rides instead (with checkpoints), in `--weather=`. It prints where any crash happened and on which stretch.
- `--ach-export=` writes the store kit for achievements (needs a display, so `xvfb-run` on a server; see ACHIEVEMENTS.md)
- `--ach-test` feeds the challenge hooks made-up events (endless distances, seven days of daily rides, a streak with a gap, three missions, four winning league weeks, season XP, the three cheat runs) and checks each new achievement unlocks at the right step and not before; it works on a blank copy of the save and puts the real one back
- `make_store_art.py` renders Play Console's feature graphic (1024 x 500, the title scene with only the logo) and eight 1920 x 1080 screenshots (six gameplay moments picked from a sweep of the trails, plus CHALLENGES and the garage) into `store/play/`, each the game's own 480 x 270 frame blown up with hard edges. `--godot` is the Godot binary to run; `--sample` renders a row of positions on many trails instead, for picking new moments. It runs the game with a throwaway save (a temporary `override.cfg` points `user://` elsewhere), so your own progress and cheats stay out of the pictures.
- `--drive-physics` puts every bike's sim through fixed tests on made-up ground: how it settles at rest, 0-150 px/s and top speed on full gas, braking from 140, holding gas up 15-45 degree slopes, landing 40-140 px drops
- `--course-calibrate` builds a short track per GAUNTLET obstacle size (a step of 4 to 20 px, crates, logs, stairs, steep ramps, kicker gaps...), and SUMMIT's walls, and has the search try each on a few bikes, printing the time or how far it got ("/hold": holding gas gets over it too)
- `--drive-levels` rides levels with the search: GAUNTLET checkpoint to checkpoint (carrying the speed across), SUMMIT fuel can to fuel can on the upgrades listed for that climb, failing a leg longer than a tank. `--mode=summit|gauntlet`, `--only=0,3`, `--bikes=a,b` or `all` (default: the scrambler, which the medal times come from: gold is its time x 1.15, silver x 1.45), `--beam=n` (default 24); `--write` rewrites `scripts/drive/drive_table.gd` with the medal times and, with `--bikes=all`, the bikes that got through each level
- `--drive-levels --lines` also replays the scrambler's winning inputs from the start (one sim, legs run on from each other), checks the replay still gets to the finish, and saves it as the level's gold line (`assets/lines/<id>.bin`: the drawn bike every 1/30 s, plus the inputs, its upgrades and its jumps)
- `--drive-air` replays each level's gold line and, at every takeoff where it's in the air 0.25 s or more, tries each air trick from there as a quick thumb would (two 4-frame taps, 4 frames apart, from the moment taps count), run through `tricks.gd`, then has the search ride on to make sure the bike lands and rides away. With `--write` it writes `scripts/drive/extras_table.gd`: those jumps, what the ride did (coins picked up, fuel left, longest jump, hops) and the objectives made from them (the rules are in `_objectives`)
- `--event-check` rides every event course (each kind's three and the holiday ones) on a stock scrambler and sets its tiers: LONG JUMP the search's jump x 0.5 / 0.75 / 0.92; COLLECT what it picked up riding fuel can to fuel can x 0.4 / 0.7 / 0.9; TRICK ATTACK the points of one trick on each jump `--drive-air`'s check fits one on, x 0.25 / 0.5 / 0.8; TIME ATTACK and LOW GRAVITY its time x 1.6 / 1.3 / 1.1; LAST DROP how far it got in the tank's 10 s x 0.5 / 0.8 / 1.0 (you coast on after). `--only=<course ids>`; `--write` rewrites `scripts/drive/event_table.gd`
- `--shot=drive_trick:<mode>:<index>:<x>:<BG|GG|GB|BB>` (a bot rides to x and taps the trick out on the next jump) and `--shot=poses` (every trick pose on three rigs) for looking at the tricks
- `--drive-hold` rides levels through the real `drive_world.gd` with gas held the whole time and reports where it stopped (crash, pit, out of fuel, stuck), plus any time the bike sat upside down without a crash being called. `--up=req|max|none|e,s,t,f` picks SUMMIT upgrades, `--uni-lean=` and `--lean=` are tuning knobs
- `make_launcher_icons.py` redraws `icon.svg` as Android's adaptive icon layers (foreground, background, and the one-colour layer for themed icons) so a launcher's mask shows the whole picture instead of Godot's zoomed-in crop, plus `store/play_icon_512.png`

Current result (v0.11.0; the runner's riding is unchanged from 0.9.0, so the lines from `--endless-check` on are 0.9.0's results, and trail riding 0.8.1's):
- `--drive-levels --write --lines` on the scrambler: all 12 SUMMIT climbs reached on their listed upgrades (searched times 36-86 s, legs never longer than a tank), and all 12 GAUNTLET courses cleared without a fault (15-31 s), each section also from a standstill at its checkpoint; every one's winning ride replayed from the start to the finish and saved as its gold line. Medal times in `drive_table.gd`.
- `--drive-hold` (gas held from start to finish): on SUMMIT every one of the 14 bikes tops FOOTHILL FARM and none tops any later climb, on each climb's listed upgrades and fully upgraded alike (most go over backwards on the first wall); no bike sat upside down without a crash. On GAUNTLET it finished none of the 12 courses on the scrambler or the Mono; the dirt bike gets through LAUNCH PAD (with a fault), where the speed off the kickers carries it, and since 0.11's gentler FIRST GEAR, that one too.
- `--drive-levels --bikes=all --beam=12` (other bikes on SUMMIT fully upgraded; where a bike failed at beam 12 and one more try at beam 24 got it through, that counts): GAUNTLET courses cleared per bike: scrambler 12, dirt bike 11, sportbike 11, Surge 9, cafe racer 8, chopper 8, Spark 7, Boulder 5, minibike 2, Commuter 2, Mono 2, Goliath 2, scooter 1, Zip 1; FIRST GEAR by all 14, SWITCHBACK by 10, PIPE YARD by 2, THE GAUNTLET by 3. SUMMIT climbs reached: scrambler, dirt bike, cafe racer, Spark and Surge all 12, chopper and sportbike 10, Boulder and Mono 7, Goliath 6, scooter 4, Commuter 3, minibike and Zip 1. The walls are what stop the small ones: past about 28 degrees they haven't the push to climb at all, only to coast up on momentum. Lantern Haul and Night Ridge are the hardest (6 bikes each). The cards say TOUGH ON THIS BIKE for the rest.
- `--drive-air --write`: on the gold lines, every SUMMIT climb from 2 has a jump with room for at least a whip and a no-hander, and from 4 on all but HOODOO HUMPS one with room for a superman (longest jumps 0.38-0.8 s); on GAUNTLET, MIND THE GAP, HOODOO HOPS, LAUNCH PAD and THE GAUNTLET have a kicker with room for one (LAUNCH PAD seven), the rest none (their jumps are 0.27-0.38 s, and the taps take about 0.2 s of that). Each trick was landed and the search rode away after it. Objectives written from these and the checker's ride.
- `--event-check --write`: all 22 event courses (the weekly kinds' three each and the seven holiday ones) ridden on a stock scrambler; tiers in `event_table.gd`.
- `--course-calibrate` (beam 12, with the hop): the scrambler gets up an 8 px step or table, a 6 px crate and over a log of radius 6, where holding gas stops at 4 px; the dirt bike and the Mono 10 px steps, the Goliath 12 px and logs of 10; the Boulder 8 px steps; the minibike, Zip and Commuter 6 px steps and 5-6 px logs; the scooter 4 px steps and 5 px logs. Stairs need treads of about 30 px, and steps of crates 32 px wide. GAUNTLET's courses are sized from these. SUMMIT walls (`--only=wall`, 64 px high, stock): the scrambler gets up 32 degrees (34 at beam 24), the dirt bike 34, the Spark and the Mono 36; holding gas gets the dirt bike up 30 and 32 degrees, and none of the four up 34.
- `--verify --bike=<each of the 7 new bikes> --weather=clear`: every Free Ride and story trail cleared with no crashes on each (196 runs); they reuse the existing specialties, so the 0.9.0 results below for those cover the other weathers.
- `--ach-test`: 31 checks, all pass (the 22 calendar-mode ones, plus SUMMIT and GAUNTLET: nothing for a failed ride, a failed climb still banks its coins, first finish, a clean course, all twelve of each, the next course opening).
- `--nav-test`: also on SUMMIT: the picker takes focus, A starts a climb, nothing holds focus while riding, the right trigger is gas, B pauses and B resumes. (It caught 0.11's GHOST button, first at the right of the top bar, standing between GARAGE and the cards' RIDE for a pad; it sits beside BACK now.)
- `make_aab.py --verify` on the 0.9.1 bundle: OK (351 files in the universal APK, 319 byte for byte, 29 XML files and the resource table matching; arm64 splits with both libraries uncompressed and 16 KB aligned).
- `--endless-check`: 76 stretches x 5 speeds. Used in clear weather (bot clean at all three arrival times, tightest window 75 ms or more): 66 at 118 px/s, 73 at 130, 142 and 154, 70 at 166; in all three weathers 64, 72, 73, 72, 69. The ones left out are mostly a tightest window of one to four frames at that speed, and five where the bot itself crashed at 118 (too slow to clear a gap the trail was built for at its own speed). Across everything that's used, the careful rider's timing windows have a median of 366 ms and a tenth of them under 166 ms.
- `--endless-ride`: 8 endless courses x 7 bikes to 7 km each (all five speeds), and 36 daily rides (12 each in clear, rain and wind, at all five speeds): no crashes. Two things this caught on the way: a stretch that opened straight into a jump right after a joint's slope, and stretches built at a different height from where the checker rode them (a marginal rail mount went the other way). Joints now end in a full second of flat deck, and bring every stretch back to the height it was checked at.
- Plain bike: all 84 runs (12 Free Ride trails + 16 story trails, x 3 weathers) cleared with 0 crashes and 3/3 gears; every boss knocked out 3/3 without circling round, in every weather. Letters 7/7 in 68 of 72 trail runs (bosses have none); the misses are single letters except Hollow Oak in wind (two), all picked up by the bot in the other weathers.
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
- SUMMIT and GAUNTLET difficulty is set by the checks above (a search that rides in 0.1 s blocks, and held gas), not by people playing it yet: the wall angle, the hop's timing window and the obstacle sizes are the knobs if they feel too hard or too easy on a phone.

Font: Press Start 2P, SIL Open Font License (`assets/fonts/OFL.txt`).
