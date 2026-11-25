# Fore! Last Stand (working title)

One-thumb, portrait golf tower-defense. A virus has overrun the golf course with animals and you are the last person standing at the clubhouse. Swing real clubs at golf balls with your thumb while towers (placed only on the clubhouse grounds) back you up.

**Stack:** Flutter (3.47+, uses `material_ui`) + [Flame](https://flame-engine.org). iOS and Android, portrait only.

## Status

Playable MVP of the [feature spec](https://claude.ai/code/artifact/f2b2c67e-0ef5-49d5-abc2-055c1d0f03cb) (section 12 scope). Shapes stand in for art and text for the commentator's voice.

**Story Mode** (spec section 6a, MVP: Suburban Muni holes 1-9)

- **Structure:** holes in order, 3 rounds each (3/4/5 timed waves, then a mini-boss in rounds 1-2 and a final boss in round 3). Coins, towers and perks carry between the rounds of a hole; a new hole starts with 150 coins and an empty tee box. Beating hole 9 shows Course Complete. Beaten holes can be replayed for half XP and tokens.
- **Screens:** Main menu → course select (locked courses greyed) → hole map (Play, Bag, Pro Shop, Clubhouse, Caddies) → Prep (draft 1 of 3 perks, place towers, pick a caddie, optional ad boost, Tee Off) → round (8 s build breaks with Skip; pause: Resume, Settings, Concede, Main Menu) → Results.
- **Results:** nothing is applied until you leave Results; Concede voids the round (XP, tokens, reveals dropped; coins, towers and the perk pick back to Tee Off). If the app closes on Results it reopens there.
- **Layout:** a 390 x 844 canvas, letterboxed: HUD, fairway with hazards (water, fences, sand, trees), golfer at (195, 548), 4x4 tee box, club bar. Drag anywhere to aim (24-120 units maps to 35-100% power), shrinking Sweet Spot ring, per-club cooldowns, combo ladder, Fore! burst. Tap a tower to see its range, hold it to upgrade or sell.
- **Per-course rank and clubs:** rank 1-18 from XP; each rank-up reveals one club in the Pro Shop, bought and levelled (1-5) with that course's Club Tokens. 3-slot bag, one club per family (Iron, Fairway Wood, Driver, Wedge, Putter), 18 clubs including 6 Specials.
- **Content:** 8 enemies with abilities, 4 final bosses, all 8 towers (Sand Trap and Snack Shack are new), 20 perks, Big Earl and Dottie with ranks paid in Caddie Badges, Clubhouse wings. Ground enemies follow a flow field around hazards.
- **Data:** everything is JSON in `assets/courses/`; the number of playable holes is the length of `holes.json`. The save is one JSON file written to a temp file and renamed.
- **Rewarded ads:** revive and one boost per round. No ad SDK is wired up yet, so the buttons stay hidden; Settings → *Test ads* turns on a 3-second stand-in to try the flow.

**Arcade modes and shared systems**

- **Swing:** drag back anywhere, release on the timing ring's green zone for a Sweet Spot (+50% damage, +1 pierce, screen shake). Dotted preview of the first wall bounce, ~0.8 s cooldown, aim-assist slider.
- **Depth:** balls ricochet off walls and enemies but pass through your own towers; flags occasionally pop up on the course and sinking a ball in one overcharges every tower (tap a tower to upgrade or sell), combo ladder Bogey → Albatross (coin multiplier, Fore! meter), 3-second Fore! barrage.
- **Clubs:** Driver (pierce 3), Iron (2 bounces), Wedge (lob + blast), Putter (ground roll, unlocked in the Bag). 3-club bag, tap to swap.
- **Towers (6):** Range Ball Machine, Sprinkler, Tee-Tesla, Lawnmower Ripper, Cart Cannon, Caddie Sniper on a 4x4 plot grid (5x5/6x6 via Clubhouse). Build between holes, or live at double cost with 2 s slow-mo. Sell for 70%, free re-placement in the first 10 s. Sprinkler + Tee-Tesla pair bonus; 3 tower levels.
- **Enemies (8) + boss:** Goose (honk stuns towers), Gator (surfaces from water), Raccoon (steals coins), Crow (flier, dives towers), Boar (charges, ignores slows), Squirrel Bomber, Skunk (gas disables towers), Coyote Pack (leader buffs pups), Goose King boss (summons flocks).
- **Arcade holes:** generated per hole, breathers every third, a boss every ninth. Clubhouse has 3 flags; a fallen flag repairs 30% and grows swarms.
- **Arcade modes:** Sudden Death (endless, one flag), Daily Tournament (date seed + daily modifier, local best score). Quick Round and Full Round were replaced by Story Mode.
- **Run layer:** 20 Mulligan-card perks in 4 rarities and 3 sets (set bonus), 1 of 3 draft after every hole, one free reroll.
- **Caddies (2):** Big Earl (Fore! +40%, Big Drive), Dottie (+20% vs bosses, Mark & Snipe). First caddie free after the first round.
- **Meta (saved locally):** coins, Club Tokens, XP; club levels 1-20 with traits; Clubhouse upgrades (grid, starting coins, walls); bestiary; "three nearest unlocks" on results and home. Clubhouse unlocks after 2 rounds, Bag after 3.
- **First-time experience:** first round is scripted with hints; hidden adaptive difficulty (about 10% fewer enemies after 2 losses in a row).
- **Settings:** aim assist, Auto-Caddie (swings for you at 60% damage), left-handed layout, screen shake, Gore (Full Splat / Classic / Squeaky Clean).

**Not built yet** (needs a backend, store setup or art): a real rewarded-ad SDK, IAP (including Remove Ads), Season Pass, Gems shop, leaderboards, Weekly Invitational, notifications, share clips, voiced commentary, Tour Ranks/prestige, Story holes 10-18 and courses 2-3, real art and audio.

## Code layout

| Path | What |
|---|---|
| `lib/data/` | All content as plain data: clubs, enemies, towers, perks, caddies, courses/holes, modes, commentary |
| `lib/sim/` | Pure-Dart simulation (`Battle`), wave scheduling, combo, swing math. No Flame imports, fully unit-tested |
| `lib/game/fore_game.dart` | Flame game: runs the sim loop and draws it |
| `lib/meta/` | Profile, persistence (`shared_preferences`), rewards and upgrade rules |
| `lib/ui/` | Flutter screens: home, run HUD/draft/build sheet, results, Bag, Clubhouse, Caddies, Bestiary, Settings |
| `assets/courses/` | Story Mode content as JSON: shared `rules.json`, `enemies.json`, `bosses.json`, `towers.json`, `perks.json`, `caddies.json`, `club_families.json`, plus `<courseId>/clubs.json` and `holes.json` |
| `lib/story/` | Story Mode: content parsing, save model and store, progression rules (`progression.dart`), round sim and flow field (`sim/`), Flame renderer (`game/`), screens (`ui/`) |

New arcade content is usually a data entry in `lib/data/`. Story content is JSON: add a hole to `assets/courses/<courseId>/holes.json` and it becomes playable.

## Design summary

- **Pillars:** every swing matters; the base is the fortress; quirky carnage; one more hole.
- **Loop:** moment (2-10 s) → hole/wave (30-90 s) → round (3-15 min) → meta (clubs, caddies, clubhouse).
- **Swing:** drag back to aim/power, release on the timing ring for a Sweet Spot (+50% damage); ~0.8 s cooldown; Fore! burst when the meter is full.
- **Clubs:** Driver (pierce), Iron (bounces), Wedge (blast), Putter (ground roll).
- **Towers:** on a 4x4 plot grid around the clubhouse (grows to 6x6); pairs unlock bonuses.
- **Modes:** Story Mode, Sudden Death, Daily Tournament, Weekly Invitational.
- **Meta:** club/tower levels, caddies, clubhouse wings, bestiary, Tour Rank prestige.
- **Monetization:** F2P, opt-in rewarded ads, cosmetic-first IAP, no interstitials during a run.
- **MVP:** Story Mode on 1 course (holes 1-9), 8 towers, 8 enemies, 4 bosses, 18 clubs, 2 caddies, 20 perks, plus Sudden Death and the Daily Tournament.

## Develop

Platform folders (`android/`, `ios/`) are not committed; generate them once:

```sh
flutter create --platforms=android,ios --project-name fore_last_stand --org com.playground .
flutter pub get
flutter analyze
flutter test
flutter run
```

## CI build

`.github/workflows/fore-last-stand-build.yml` (at the repo root, as GitHub requires) runs analyze + test + build. Trigger it from the **Actions** tab → *fore-last-stand build* → *Run workflow*, choosing `apk`, `appbundle` or `ios`. It also runs automatically when a PR that touches `fore-last-stand/` is merged to `main`; open PRs don't trigger it. Android outputs are uploaded as artifacts; iOS is built with `--no-codesign`.
