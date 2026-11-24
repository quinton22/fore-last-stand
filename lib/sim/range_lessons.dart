import '../data/clubs.dart';
import '../data/towers.dart';
import 'battle.dart';

/// One step of the Driving Range tutorial.
class RangeLesson {
  const RangeLesson({required this.title, required this.body, this.tips = const [], this.goal, this.done, this.spawn});

  final String title;
  final String body;
  final List<String> tips;

  /// What the player should do, shown with a check when [done] is true.
  final String? goal;

  /// Null for read-only lessons.
  final bool Function(Battle b)? done;

  /// Target to put on the range when the lesson starts.
  final String? spawn;

  bool isDone(Battle b) => done == null || done!(b);
}

final List<RangeLesson> rangeLessons = [
  const RangeLesson(
    title: 'Welcome to the Driving Range',
    body: 'A virus has turned the course\'s animals into zombies and you are the last person standing at the clubhouse. '
        'This range is where you learn to fight back. Nothing here can hurt you, and you can leave any time.',
    tips: [
      'Your clubhouse (the 🚩 flags) is at the bottom. Enemies walk toward it; each one that arrives damages it.',
      'Clear every enemy on a hole to move on. Beat the last hole to win the round.',
      'Orange dummies are practice targets. They never move and they come back when destroyed.',
    ],
  ),
  RangeLesson(
    title: 'Swing',
    body: 'You play with one thumb. Put your finger anywhere on the course and drag back like a slingshot, then let go. The ball flies the opposite way.',
    tips: const [
      'A dotted line previews the first wall bounce. Drag further for a harder hit.',
      'You can swing about every 0.8 seconds, so make each one count.',
    ],
    goal: 'Hit a target',
    done: (b) => b.rangeDamage > 0,
  ),
  RangeLesson(
    title: 'Sweet Spot',
    body: 'While you drag, a timing ring fills. Release when it is in the green zone for a Sweet Spot.',
    tips: const ['A Sweet Spot deals +50% damage and pierces one more enemy, with a screen shake.'],
    goal: 'Land a Sweet Spot',
    done: (b) => b.sweetSwings >= 1,
  ),
  RangeLesson(
    title: 'Clubs',
    body: 'You carry a bag of clubs. Tap a club button at the bottom to switch. Each plays differently.',
    tips: [
      for (final c in clubs) '${c.name}: ${_clubText(c)}',
      'Your real bag holds three clubs. The Putter is unlocked in the Bag after three rounds, but it is free here.',
    ],
    goal: 'Swing every club once',
    done: (b) => b.clubsSwung.length >= b.config.bag.length,
  ),
  RangeLesson(
    title: 'Fliers',
    body: 'Some animals fly. Crows dive at your towers, and the Putter rolls along the ground so it cannot touch them.',
    tips: const ['Use the Driver or Iron on blue fliers. Try the Putter on one to see it pass underneath.'],
    goal: 'Shoot down the flying target',
    spawn: 'dummy_air',
    done: (b) => (b.killsById['dummy_air'] ?? 0) >= 1,
  ),
  RangeLesson(
    title: 'Heavy hitters',
    body: 'Tanks like the Gator soak up damage. Area damage works best: the Wedge lobs over everything and lands as a blast.',
    tips: const ['Aim a Wedge lob by how far you drag back: a longer drag lands further away.'],
    goal: 'Destroy the heavy target',
    spawn: 'dummy_tank',
    done: (b) => (b.killsById['dummy_tank'] ?? 0) >= 1,
  ),
  RangeLesson(
    title: 'Fore!',
    body: 'Hitting enemies builds your combo ladder (Bogey up to Albatross), and higher rungs multiply your coins. Fighting also fills the Fore! meter.',
    tips: const ['Tap FORE! when it is full for a 3-second barrage of balls. On the range the meter is always full.'],
    goal: 'Tap FORE!',
    done: (b) => b.foreBursts >= 1,
  ),
  RangeLesson(
    title: 'Towers',
    body: 'Towers shoot for you, but only from the glowing plots around the clubhouse. Tap an empty plot to build. Coins are free on the range.',
    tips: [
      'In a real round, build between holes. Building mid-hole costs double.',
      'Tap a tower to upgrade it (3 levels) or sell it for 70% back.',
      for (final t in towers) '${t.name}: ${t.role}. ${t.synergy}.',
    ],
    goal: 'Build a tower',
    done: (b) => b.towers.any((t) => !t.removed),
  ),
  RangeLesson(
    title: 'Overcharge',
    body: 'Your balls pass straight through your own towers. Instead, flags pop up on the course every so often. Sink a ball in one and every tower is overcharged.',
    tips: const ['Flags blink just before they vanish, so aim quickly. Build a tower first: flags only appear once you have one.'],
    goal: 'Sink a ball in a flag',
    done: (b) => b.towerCharges >= 1,
  ),
  RangeLesson(
    title: 'Mulligan cards',
    body: 'In a real round you pick 1 of 3 Mulligan cards after every hole. These power-ups improve your balls, towers, coins or clubhouse.',
    tips: const [
      'Cards come in four rarities: common, rare, epic and legendary.',
      'Hold 3 from the same set for a +15% ball damage bonus.',
      'Open the Range tools button (top right) to try any card here.',
    ],
    goal: 'Try a card from Range tools',
    done: (b) => b.perksTaken.isNotEmpty,
  ),
  const RangeLesson(
    title: 'Meet the animals',
    body: 'Every animal has a trick: geese stun towers, raccoons steal coins, skunks gas your towers, boars ignore slows. '
        'Open the Bestiary from the Home screen to read about each one and what counters it.',
    tips: ['That is everything. From here the range is yours: spawn targets, try cards and test your clubs and towers.'],
  ),
];

String _clubText(ClubSpec c) {
  final detail = switch (c.kind) {
    ClubKind.driver => 'fast and straight. Pierces ${c.pierce} enemies and hits fliers.',
    ClubKind.iron => 'bounces ${c.bounces} times off walls and enemies, and hits fliers.',
    ClubKind.wedge => 'a lob that flies over everything and lands as an area blast.',
    ClubKind.putter => 'a slow ground roll that bowls through ${c.pierce} enemies. Cannot hit fliers.',
  };
  return '$detail Best against ${c.bestAgainst.toLowerCase()}.';
}
