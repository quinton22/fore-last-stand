import 'package:material_ui/material_ui.dart';

import '../data/clubs.dart';
import '../data/enemies.dart';
import '../data/towers.dart';
import '../meta/profile.dart';
import '../sim/battle.dart';
import '../sim/combo.dart';

/// One screen of a tutorial dialog.
class TutorialPage {
  const TutorialPage(this.emoji, this.title, this.body, {this.bullets = const []});

  final String emoji;
  final String title;
  final String body;
  final List<String> bullets;
}

const _introId = 'intro';
const _buildId = 'build';
const _draftId = 'draft';
const _enemyPrefix = 'enemy:';

/// The next unseen tutorial topic for the current moment of a run, or null.
///
/// Topic ids: `intro` (start of the first run), `enemy:<id>` (first time that
/// enemy is on the board), `build` (first build phase), `draft` (first perk draft).
String? pendingTutorialTopic(Battle battle, Profile profile) {
  final seen = profile.tutorialSeen;
  if (battle.finished) return null;
  if (!seen.contains(_introId)) return _introId;
  for (final e in battle.enemies) {
    final id = _enemyKey(e.spec);
    if (!e.removed && e.hp > 0 && !seen.contains(id)) return id;
  }
  if (battle.phase == Phase.building && !seen.contains(_buildId)) return _buildId;
  if (battle.phase == Phase.drafting && !seen.contains(_draftId)) return _draftId;
  return null;
}

/// Pups are explained as part of the Coyote Pack.
String _enemyKey(EnemySpec s) => '$_enemyPrefix${s.ability == EnemyAbility.pack ? 'coyote' : s.id}';

/// Shows the dialog for [topic] (an id from [pendingTutorialTopic]).
Future<void> showTutorialTopic(BuildContext context, String topic) {
  if (topic == _introId) return showHowToPlay(context);
  if (topic == _buildId) return _showPages(context, _buildPages());
  if (topic == _draftId) return _showPages(context, _draftPages());
  if (topic.startsWith(_enemyPrefix)) {
    return showEnemyIntro(context, enemyById(topic.substring(_enemyPrefix.length)));
  }
  return Future.value();
}

/// The full "how to play" walkthrough (also reachable from Home and the pause menu).
Future<void> showHowToPlay(BuildContext context) => _showPages(context, howToPlayPages());

/// Explains a single enemy the first time it shows up.
Future<void> showEnemyIntro(BuildContext context, EnemySpec e) => _showPages(context, [enemyPage(e)], enemy: e);

Future<void> _showPages(BuildContext context, List<TutorialPage> pages, {EnemySpec? enemy}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => TutorialDialog(pages: pages, enemy: enemy),
  );
}

// ------------------------------------------------------------------ content

List<TutorialPage> howToPlayPages() => [
      const TutorialPage(
        '⛳',
        'Defend the clubhouse',
        'A virus has turned the course\'s animals into zombies and you are the last person standing. '
            'They march toward your clubhouse; every one that arrives hurts it.',
        bullets: [
          'The 🚩 flags and green bar at the top are the clubhouse\'s health. Lose it all and the round is over.',
          'Clear every enemy on a hole to move on. Beat the last hole to win the round.',
          'Kills drop 🪙 coins, which you spend on towers.',
        ],
      ),
      const TutorialPage(
        '🏌️',
        'Swinging',
        'You hit golf balls at the animals with one thumb.',
        bullets: [
          'Drag back anywhere on the course, like pulling a slingshot. The ball flies the opposite way.',
          'A dotted line previews the first wall bounce. Drag further for a harder hit.',
          'Release when the timing ring is in the green zone for a Sweet Spot: +50% damage, +1 pierce and a screen shake.',
          'You can swing about every 0.8 seconds, so make each one count.',
        ],
      ),
      TutorialPage(
        '🎒',
        'Your clubs',
        'You carry three clubs. Tap the club buttons at the bottom to swap. Each one behaves differently.',
        bullets: [for (final c in clubs) '${c.name}: ${_clubText(c)}'],
      ),
      TutorialPage(
        '🔥',
        'Combos and Fore!',
        'Chain hits without missing to climb the combo ladder: ${ComboLadder.rungNames.join(' → ')}.',
        bullets: [
          'Higher rungs multiply the coins you earn.',
          'Fill the Fore! meter, then tap FORE! for a 3-second barrage of balls.',
          'Balls ricochet off walls and enemies, but pass straight through your own towers.',
          'Tap a tower to select it. Your Sweet Spot hits and Fore! bursts then overcharge it. Tap again to deselect.',
        ],
      ),
      TutorialPage(
        '🏗️',
        'Towers',
        'Towers shoot for you, but only from the glowing plots around the clubhouse.',
        bullets: [
          'Between holes, tap a plot to build, then press Tee Off to start the next hole.',
          'Building mid-hole costs double and briefly slows time.',
          'Long-press a tower to upgrade it (3 levels) or sell it for 70% back. You get free re-placement for the first 10 seconds.',
          'Sprinkler + Tee-Tesla next to each other unlock a pair bonus.',
          for (final t in towers) '${t.name} (🪙${t.cost}): ${t.role}',
        ],
      ),
      const TutorialPage(
        '🃏',
        'Mulligan cards',
        'After every hole you pick 1 of 3 Mulligan cards. These are your power-ups for the rest of the round.',
        bullets: [
          'Cards come in four rarities: common, rare, epic and legendary.',
          'They boost your balls, your towers, your coins or your clubhouse.',
          'Collect 3 cards from the same set (Ballistics, Groundskeeping, Showman) for a +15% ball damage set bonus.',
          'You get one free reroll per draft.',
        ],
      ),
      const TutorialPage(
        '🦆',
        'Meet the enemies',
        'New animals are explained the first time they appear, and the Bestiary keeps a record of everything you have met.',
        bullets: [
          'Some enemies stun towers, steal coins or fly. Pick the right club and tower for the job.',
          'You can reopen this guide any time from Home or the pause menu.',
        ],
      ),
    ];

String _clubText(ClubSpec c) {
  final detail = switch (c.kind) {
    ClubKind.driver => 'fast and straight. Pierces through ${c.pierce} enemies and hits fliers.',
    ClubKind.iron => 'bounces ${c.bounces} times off walls and enemies, and hits fliers.',
    ClubKind.wedge => 'a lob that flies over everything and lands as an area blast. Cannot be blocked.',
    ClubKind.putter => 'a slow ground roll that bowls through ${c.pierce} enemies. Cannot hit fliers. Unlocked in the Bag.',
  };
  return '$detail Best against: ${c.bestAgainst.toLowerCase()}.';
}

List<TutorialPage> _buildPages() => [
      TutorialPage(
        '🏗️',
        'Build phase',
        'Between holes the action stops so you can set up.',
        bullets: [
          'Tap a glowing plot to place a tower. Coins are shown at the top.',
          'Long-press a built tower to upgrade or sell it. A plain tap selects it for overcharging.',
          'Press Tee Off when you are ready for the next hole.',
          for (final t in towers) '${t.name} (🪙${t.cost}): ${t.role}. ${t.synergy}',
        ],
      ),
    ];

List<TutorialPage> _draftPages() => const [
      TutorialPage(
        '🃏',
        'Pick a Mulligan card',
        'Hole cleared! Choose one of three cards. Each is a permanent power-up for this round.',
        bullets: [
          'Rarer cards are stronger. Legendary ones change how your balls behave.',
          'Cards from the same set stack toward a +15% damage set bonus at 3.',
          'Not happy with the choices? Use the free reroll.',
        ],
      ),
    ];

String _speedWord(double s) => s >= 70 ? 'Fast' : (s >= 45 ? 'Medium' : 'Slow');

/// Longer, plain-language explanation of what an enemy ability does.
String _abilityText(EnemySpec e) => switch (e.ability) {
      EnemyAbility.honk => 'Its honk stuns every tower nearby for 2 seconds. Take geese down before they reach your towers.',
      EnemyAbility.thief => 'If it reaches the clubhouse it steals some of your coins and runs off. Kill it before it escapes.',
      EnemyAbility.diveTowers => 'It flies over the course and dives at your towers. Only the Driver and Iron (and some towers) can hit fliers.',
      EnemyAbility.charge => 'It charges in a straight line and ignores slowing effects. Use damage, not slows.',
      EnemyAbility.bomber => 'It runs at a tower and explodes. Shoot it from a distance before it gets close.',
      EnemyAbility.gas => 'It releases a gas cloud that disables towers inside it. Kill it from range, then reposition.',
      EnemyAbility.packLeader => 'It arrives with a pack of pups. While the leader lives, the pups are buffed. Focus the leader.',
      EnemyAbility.pack => 'A pack member. Kill the leader to weaken it.',
      EnemyAbility.summonFlock => 'The boss. It is huge and slow, and keeps summoning flocks of geese. Use Fore! bursts and sniper marks.',
      EnemyAbility.none => 'A slow, heavy tank. It soaks up damage. Use area damage like the Wedge.',
    };

TutorialPage enemyPage(EnemySpec e) => TutorialPage(
      e.boss ? '👑' : '🐾',
      e.ability == EnemyAbility.pack ? 'Coyote Pack' : e.name,
      _abilityText(e),
      bullets: [
        'Health ${e.health.round()}  ·  ${_speedWord(e.speed)}  ·  ${e.baseDamage.round()} damage to the clubhouse',
        if (e.flier) 'Flies: the Putter cannot hit it.',
        if (e.behavior.isNotEmpty) e.behavior,
        if (e.counter.isNotEmpty) 'Good against it: ${e.counter}',
        'Drops 🪙${e.coins}',
      ],
    );

// ------------------------------------------------------------------- dialog

class TutorialDialog extends StatefulWidget {
  const TutorialDialog({super.key, required this.pages, this.enemy});

  final List<TutorialPage> pages;
  final EnemySpec? enemy;

  @override
  State<TutorialDialog> createState() => _TutorialDialogState();
}

class _TutorialDialogState extends State<TutorialDialog> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    final page = widget.pages[_i];
    final last = _i == widget.pages.length - 1;
    final enemy = widget.enemy;
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (enemy != null)
                    CircleAvatar(radius: 16, backgroundColor: Color(enemy.colorValue))
                  else
                    Text(page.emoji, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      enemy != null ? 'New enemy: ${page.title}' : page.title,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(page.body),
                      for (final b in page.bullets)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('•  '),
                              Expanded(child: Text(b)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (widget.pages.length > 1) Text('${_i + 1}/${widget.pages.length}'),
                  const Spacer(),
                  if (_i > 0) TextButton(onPressed: () => setState(() => _i--), child: const Text('Back')),
                  if (!last && widget.pages.length > 1)
                    TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Skip')),
                  FilledButton(
                    onPressed: last ? () => Navigator.of(context).pop() : () => setState(() => _i++),
                    child: Text(last ? (enemy != null ? 'Got it' : 'Let\'s play') : 'Next'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
