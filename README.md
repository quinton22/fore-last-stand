# Fore! Last Stand (working title)

One-thumb, portrait golf tower-defense. A virus has overrun the golf course with animals and you are the last person standing at the clubhouse. Swing real clubs at golf balls with your thumb while towers (placed only on the clubhouse grounds) back you up.

**Stack:** Flutter (3.47+, uses `material_ui`) + [Flame](https://flame-engine.org). iOS and Android, portrait only.

## Status

Playable MVP of the [feature spec](https://claude.ai/code/artifact/f2b2c67e-0ef5-49d5-abc2-055c1d0f03cb) (section 12 scope). Shapes stand in for art and text for the commentator's voice.

**Story Mode** (spec section 6a, MVP: Suburban Muni holes 1-9)

- **Structure:** holes in order, 3 rounds each (3/4/5 timed waves, then a mini-boss in rounds 1-2 and a final boss in round 3). Coins, towers and perks carry between the rounds of a hole; a new hole starts with 150 coins and an empty build zone. Beating hole 9 shows Course Complete. Beaten holes can be replayed for half XP and tokens.
- **Screens:** Main menu → course select (locked courses greyed) → hole map (Play, Bag, Pro Shop, Clubhouse, Caddies) → Prep (draft 1 of 3 perks, place towers, pick a caddie, optional ad boost, Tee Off) → round (8 s build breaks with Skip; pause: Resume, Settings, Concede, Main Menu) → Results.
- **Saving:** a round is saved the moment it ends; Results then offers Continue (Next Round, Next Hole, Retry Round or Finish Course) or the Story Menu. Concede is only in the pause menu during a round: it voids the round and puts coins, towers and the perk pick back to Tee Off.
- **Layout:** a 390 x 844 canvas, letterboxed: HUD, fairway with hazards (water, fences, sand, trees), the 4x4 build zone, then the golfer and ball near the bottom at (195, 768), then the club bar. Drag anywhere to aim (24-120 units maps to 35-100% power), shrinking Sweet Spot ring, per-club cooldowns, combo ladder, Fore! burst.
- **Combat:** enemies follow a flow field around hazards toward the ball. Ground enemies stop to attack any tower in their way until it is destroyed; anything that reaches the ball stays there attacking it (bosses too). Towers have health: upgrading repairs them, a destroyed tower is lost. Losing all flags loses the round.
- **Building:** towers cost the same in Prep, build breaks and mid-wave. Tapping a plot or a tower opens its sheet and pauses the round until it closes; dragging from a plot still aims.
- **Per-course rank and clubs:** rank 1-18 from XP; each rank-up reveals one club in the Pro Shop, bought and levelled (1-5) with that course's Club Tokens. 3-slot bag, one club per family (Iron, Fairway Wood, Driver, Wedge, Putter), 18 clubs including 6 Specials.
- **Content:** 8 enemies with abilities, 4 final bosses, 8 towers, 20 perks, Big Earl and Dottie with ranks paid in Caddie Badges, Clubhouse wings.
- **Data:** everything is JSON in `assets/courses/`; the number of playable holes is the length of `holes.json`. The save is one JSON file written to a temp file and renamed.
- **Rewarded ads:** revive and one boost per round. No ad SDK is wired up yet, so the buttons stay hidden; Settings → *Test ads* turns on a 3-second stand-in to try the flow.

**Arcade modes** (same engine, layout, enemies and towers as Story; they use your Story bag and caddie)

- **Sudden Death:** endless waves on a random Suburban Muni layout with one flag. A new enemy type joins each wave, a mini-boss every 5 waves, a final boss every 10, a perk draft every 3. Best wave count is saved.
- **Daily Tournament:** everyone gets the same hole, seed and modifier for the day (windy, big balls, stampede, cheap seats, glass tee): 5 waves then a final boss. Best score of the day is saved.
- **Driving Range:** a guided tutorial on the Story engine, then free practice with one club of each family, free coins, practice targets and Range tools (spawn targets or live animals, put up a flag, try perks).

**Shared:** bestiary of every animal and boss, settings (aim assist, Auto-Caddie, left-handed layout, screen shake, gore level, test ads).

**Not built yet** (needs a backend, store setup or art): a real rewarded-ad SDK, IAP (including Remove Ads), Season Pass, Gems shop, leaderboards, Weekly Invitational, notifications, share clips, voiced commentary, Tour Ranks/prestige, Story holes 10-18 and courses 2-3, real art and audio.

## Code layout

| Path | What |
|---|---|
| `lib/sim/` | Small shared math: vectors and aim assist |
| `lib/meta/` | Profile (settings, bestiary, arcade records) and its persistence (`shared_preferences`) |
| `lib/ui/` | Main menu, Bestiary, Settings |
| `assets/courses/` | Story Mode content as JSON: shared `rules.json`, `enemies.json`, `bosses.json`, `towers.json`, `perks.json`, `caddies.json`, `club_families.json`, plus `<courseId>/clubs.json` and `holes.json` |
| `lib/story/` | The game: content parsing, Story save and store, progression rules (`progression.dart`), arcade setups (`arcade.dart`), Driving Range lessons, round sim and flow field (`sim/`), Flame renderer (`game/`), screens (`ui/`) |

All content is JSON: add a hole to `assets/courses/<courseId>/holes.json` and it becomes playable in Story and the arcade modes.

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
