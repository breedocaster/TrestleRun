# Achievements: in the game now, on the stores later

Trestle Run has 46 achievements. They already work in the game with no accounts:
they unlock in your save, pop a toast at the top of the screen, and show on
**ACHIEVEMENTS** (title screen) with progress bars for the counted ones. Progress you
made before v0.8 counts: anything you'd already earned unlocks quietly the first time
v0.8 starts.

Putting them on **Google Play Games** (Android) and **Game Center** (iOS) needs store
accounts I can't make for you, and a build step each. The game side is already
written: `scripts/achievements.gd` reports to either store when its plugin is in the
build, and stays quiet when it isn't. This file is the checklist for the parts only
you can do.

## The list

| # | ID | Name | How to get it | Points | Type |
|---|---|---|---|---|---|
| 1 | `story_start` | Off You Go | Finish the first story trail. | 5 | one step |
| 2 | `part_headlight` | Lights On | Get Grandpa's headlight back from the Scooper. | 35 | one step |
| 3 | `part_kickstart` | Kicked Off | Get the kickstart back from the Rail Hog. | 35 | one step |
| 4 | `part_seat` | Take a Seat | Get the seat back from the Harvester. | 35 | one step |
| 5 | `part_wheels` | Rolling Again | Get both wheels back from the Spinner. | 35 | one step |
| 6 | `parts_4` | Halfway Home | Recover four parts of Grandpa's bike. | 25 | counted (4) |
| 7 | `boss_flawless` | Not a Scratch | Beat a boss without crashing. | 25 | one step |
| 8 | `boss_quick` | Short Work | Knock out a boss before it circles round. | 25 | one step |
| 9 | `first_clear` | Trail Blazer | Clear your first Free Ride trail. | 5 | one step |
| 10 | `free_all` | Every Trestle | Clear all 12 Free Ride trails. | 60 | counted (12) |
| 11 | `no_crash` | Clean Run | Clear a trail without crashing. | 10 | one step |
| 12 | `gold_first` | Gold Rush | Win a gold medal. | 15 | one step |
| 13 | `gold_ten` | Golden Touch | Win 10 gold medals. | 40 | counted (10) |
| 14 | `letters_first` | Spell It Out | Find all of T-R-E-S-T-L-E in one run. | 15 | one step |
| 15 | `gears_all` | Gear Head | Find all 36 gears in Free Ride. | 50 | counted (36) |
| 16 | `flip` | Head Over Wheels | Land a flip. | 5 | one step |
| 17 | `double_flip` | Double Trouble | Land a double flip. | 20 | one step |
| 18 | `tricks_run` | Showboat | Land 10 tricks in one run. | 20 | one step |
| 19 | `stomp_100` | Stomper | Stomp 100 critters. | 25 | counted (100) |
| 20 | `zip_chain` | Cable Hopper | Ride three cables in a row without touching down. | 15 | one step |
| 21 | `rails_25` | Spark Show | Grind 25 rails. | 20 | counted (25) |
| 22 | `ropes_25` | Rope Trick | Swing on 25 ropes. | 20 | counted (25) |
| 23 | `walls_25` | Wall of Death | Ride 25 walls. | 20 | counted (25) |
| 24 | `planes_10` | Air Mail | Catch 10 prize sacks from the bonus plane. | 20 | counted (10) |
| 25 | `any_weather` | Any Weather | Clear a trail in the rain and one in the wind. | 15 | one step |
| 26 | `night_5` | After Dark | Clear 5 trails at night. | 20 | counted (5) |
| 27 | `garage_bikes` | Full Garage | Own all 14 bikes. | 35 | counted (14) |
| 28 | `garage_riders` | The Whole Gang | Own all 8 riders. | 35 | counted (8) |
| 29 | `rich` | Savings Jar | Have 2,000 coins at once. | 15 | one step |
| 30 | `ghost_beat` | Beat Your Ghost | Set a new best time while your ghost rides. | 15 | one step |
| 31 | `outrun` | Outrun It | Finish Last Trestle without crashing. | 30 | one step |
| 32 | `endless_1k` | First Milepost | Ride 1,000 m in one endless run. | 10 | counted (1,000) |
| 33 | `endless_5k` | Long Haul | Ride 5,000 m in one endless run. | 30 | counted (5,000) |
| 34 | `daily_7` | Daily Grind | Clear 7 daily rides. | 20 | counted (7) |
| 35 | `missions_all` | Hat Trick | Finish all three daily missions in one day. | 15 | one step |
| 36 | `streak_7` | Seven Straight | Play 7 days in a row. | 20 | counted (7) |
| 37 | `league_up` | Moving Up | Get promoted in the weekly league. | 15 | one step |
| 38 | `league_win` | Top of the Table | Finish a league week first in your group. | 20 | one step |
| 39 | `league_top` | Golden Spike | Reach the Golden Spike division. | 30 | counted (4) |
| 40 | `season_30` | Top of the Pass | Reach tier 30 on a season pass. | 25 | one step |
| 41 | `cheats_all` | Cheat Codes | Unlock all 3 cheats. | 20 | counted (3) |
| 42 | `summit_first` | Hilltop | Reach the top of a SUMMIT climb. | 5 | one step |
| 43 | `summit_all` | Top of the World | Reach the top of all 12 SUMMIT climbs. | 15 | counted (12) |
| 44 | `gauntlet_first` | Run the Gauntlet | Clear a GAUNTLET course. | 5 | one step |
| 45 | `gauntlet_clean` | No Faults | Clear a GAUNTLET course without a fault. | 10 | one step |
| 46 | `gauntlet_all` | The Full Gauntlet | Clear all 12 GAUNTLET courses. | 15 | counted (12) |

Total: 1,000 points. Both stores take that: Play allows 5 to 200 per achievement and
2,000 in all; Game Center allows up to 100 per achievement and 1,000 in all, so this
is Game Center's ceiling: a new achievement now has to take its points from an old
one. 0.9.1 added 32-41 (endless, daily rides and missions, the streak, the league,
the season pass, cheats); 0.10 added 42-46 (SUMMIT and GAUNTLET) and raised FULL
GARAGE from 7 bikes to 14. Points and goals can still change freely: nothing is on a
store yet.
Counted ones are "incremental" on Play (it tracks the steps) and percent-complete on
Game Center.

## The store kit (already made)

`store/achievements/` has everything the stores ask for, generated from the game's
own badge art:

| File | For |
|---|---|
| `trestle-run-play-achievements.zip` | Play Console's **Import achievements** (all 46 at once, with icons) |
| `play/<id>.png` | 512 x 512 icons (Play) |
| `apple/<id>.png` | 1024 x 1024 opaque icons (App Store Connect) |
| `game-center-achievements.csv` | what to type into App Store Connect, one row per achievement |
| `achievements.csv` | the whole list with ids, for your records |

The folder has a `.gdignore`, so none of it goes into the APK. To rebuild it after
changing the list (needs a display, hence `xvfb-run` on a server):

```
xvfb-run -a godot --path . -- --ach-export=$PWD/store/achievements --ach-scale=2
```

- `--ach-export=<dir>`: where to write the kit (absolute path).
- `--ach-scale=2`: draw each badge at twice its in-game pixel size before blowing it
  up with hard edges (1 looks blockier; 2 matches the ACHIEVEMENTS screen best).

## Android: Google Play Games

What you need first:

- A Google Play developer account (one-time fee).
- **The package name**: `com.pre_release.Trestlerun`, the one registered to the app
  in Play Console (it's in the Android preset's **Package > Unique Name**). Builds
  before 0.9.0's bundle were `com.example.trestlerun`; Android treats those as a
  different app, so they install side by side and keep separate saves.

Steps:

1. **Play Console**: create the app (type: Game) with the new package name.
2. **Play Games Services**: Grow > Play Games Services > Setup and management >
   Configuration > create a new Play Games Services project.
3. **Credentials**: add an Android credential. It asks for the package name and the
   SHA-1 of the key the APK is signed with. For the sideload builds that's the debug
   key:

   ```
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android
   ```

   - `-list -v`: print the key's details, including its fingerprints.
   - `-keystore`: the keystore file the builds are signed with.
   - `-alias androiddebugkey`, `-storepass android`: the standard name and password
     of Android's debug key.

   Use the `SHA1` line it prints (every machine's debug key is different).
   For copies installed from Play (internal testing onwards), add two more Android
   credentials: the upload key's SHA-1 (kept with the keystore,
   in `trestle-upload-key.txt`) and the app-signing key's SHA-1, which Play Console
   shows on the app's app signing page once the first bundle is uploaded. Play
   re-signs what it serves with the app-signing key, so that's the one a phone sees.
4. **Achievements**: Setup and management > Achievements > **Import achievements** >
   upload `store/achievements/trestle-run-play-achievements.zip` > Save as draft.
   Once published an achievement can't be deleted, and its type (one step or counted)
   can't change.
5. **Testers**: while the Play Games setup isn't published, only listed testers can
   sign in. Add your Google account under Setup and management > Testers.
6. **Ids into the game**: Achievements > **Get resources** gives an Android XML with an
   id per achievement and the Game ID. Save it as `games-ids.xml`, then:

   ```
   python3 tools/store/play_ids.py games-ids.xml --write
   ```

   - `--write`: put the ids into `PLAY_IDS` in `scripts/achievements.gd` (without
     it, the script just prints them). It also prints the Game ID for step 8.

   The script matches resource names like `achievement_off_you_go` to the names
   above. I wrote it from how that XML is usually laid out and tested it on a sample,
   not on a real Play Console export; if yours looks different, paste the ids into
   `PLAY_IDS` by hand (`"story_start": "CgkI...",` etc.).
7. **Plugin**: download GodotPlayGameServices **v3.4.0** (Godot Asset Store or the
   GitHub releases), put it at `addons/GodotPlayGameServices/`, then **Project >
   Project Settings > Plugins** and enable it.
8. **Export preset**: Project > Install Android Build Template, then in the Android
   preset turn on **Gradle Build > Use Gradle Build** (the plugin needs it) and enter
   the Game ID in **godot_play_game_services/game_id**. With Gradle on, Godot can
   write the Play bundle itself (**Gradle Build > Export Format: Export AAB**, signed
   with the upload key in the preset's release keystore fields), so
   `tools/android/make_aab.py` is only needed for builds without Gradle.
9. Export, install, start the game. Play Games signs in by itself if it can; if not,
   ACHIEVEMENTS shows **SIGN IN: GOOGLE PLAY GAMES**. After signing in, everything
   you'd already unlocked is sent up, and the button opens Play's own list.

**Size.** A Gradle build pulls in Google Play services libraries, so the APK will grow
past 0.8.1's 29.8 MiB. That's fine: there's no size cap on this project, and Google
Play allows up to 4 GB for an app bundle's install download.

## iOS: Game Center

What you need first: the Apple Developer Program (yearly fee) and a Mac with Xcode
(Godot exports iOS as an Xcode project; it can't be built on Linux).

1. **Bundle id**: the iOS preset uses `com.calm.trestlerun` (Apple doesn't allow the
   underscore in Android's `com.pre_release.Trestlerun`). Register it, or your own,
   under your team (Certificates, Identifiers & Profiles) with the **Game Center**
   capability, and set it in the iOS preset (**Application > Bundle Identifier**) along
   with your **App Store Team ID**.
2. **App Store Connect**: create the app, then Features (or Services) > Game Center >
   add each achievement from `game-center-achievements.csv`:
   - **Achievement ID** `trestlerun.<id>` (e.g. `trestlerun.part_headlight`): the
     game sends exactly these, and they can't be edited later.
   - **Point Value**, **Hidden: No**, **Achievable More Than Once: No**.
   - English localization: **Display Name**, **Pre-earned** and **Earned
     Description**, and the image from `apple/<id>.png` (1024 x 1024, RGB).

   App Store Connect has no spreadsheet import, so it's 46 forms (or the App Store
   Connect API if you'd rather script it).
3. **Plugin**: download **GameCenterKit 1.0.1** (`gamecenter-addon.zip` from its
   GitHub release or the Godot Asset Store), extract it so it sits at
   `addons/gamecenter/`, and enable **Game Center Export** under Project Settings >
   Plugins.
4. **Export preset**: in the iOS preset turn on **Entitlements > Game Center**
   (`entitlements/game_center=true`).
5. Export the Xcode project, sign it with a profile that includes Game Center, and test
   on a real device with a sandbox account. The game signs in at start and sends what
   you've unlocked; ACHIEVEMENTS opens Apple's own panel.

## How the game talks to the stores

All in `scripts/achievements.gd`, and only when the plugin's singleton exists (so
the same build runs without either):

| | Google Play Games (singleton `GodotPlayGameServices`) | Game Center (singleton `GameCenterKit`) |
|---|---|---|
| start | `initialize()`, then `isAuthenticated()` (answer: signal `userAuthenticated`) | `authenticate()` (answer: signal `authenticated`) |
| unlock | `unlockAchievement(play_id)` | `report_achievement("trestlerun." + id, 100.0)` |
| counted | `setAchievementSteps(play_id, steps)` | `report_achievement(id, percent)` |
| list | `showAchievements()` | `show_achievements()` |
| sign in | `signIn()` | `authenticate()` |

I checked those names against both plugins' source (GodotPlayGameServices 3.4.0,
July 2026; GameCenterKit 1.0.1, September 2026). Neither has been run on a phone
here, since that needs the store accounts above. Unlocks made while signed out are
kept and re-sent on the next sign-in; both stores ignore repeats.

Sources:
[Play Games achievements](https://developer.android.com/games/pgs/achievements),
[Play Console achievement import](https://support.google.com/googleplay/android-developer/answer/2990418),
[GodotPlayGameServices](https://github.com/godot-sdk-integrations/godot-play-game-services),
[App Store Connect achievement fields](https://developer.apple.com/help/app-store-connect/reference/achievements),
[Game Center achievement art](https://developer.apple.com/design/human-interface-guidelines/technologies/game-center/achievements),
[GameCenterKit](https://github.com/keremvatandas/godot-ios-gamecenter),
[com.example restriction](https://forum.ionicframework.com/t/error-deploying-app-to-google-play-store/90882).
