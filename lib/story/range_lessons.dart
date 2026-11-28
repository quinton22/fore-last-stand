import 'sim/round_sim.dart';

/// One step of the Driving Range tutorial.
class RangeLesson {
  const RangeLesson({required this.title, required this.body, this.tips = const [], this.goal, this.done, this.spawn});

  final String title;
  final String body;
  final List<String> tips;

  /// What the player should do, shown with a check when [done] is true.
  final String? goal;

  /// Null for read-only lessons.
  final bool Function(RoundSim s)? done;

  /// Target to put on the range when the lesson starts.
  final String? spawn;

  bool isDone(RoundSim s) => done == null || done!(s);
}

final List<RangeLesson> rangeLessons = [
  const RangeLesson(
    title: 'Welcome to the Driving Range',
    body:
        'A virus has turned the course\'s animals into zombies and you are the last golfer standing. '
        'This range teaches you to fight back. Nothing here can hurt you, and you can leave any time.',
    tips: [
      'You and your ball are at the bottom. Animals come down the fairway, attack any tower in their way, then attack the ball.',
      'The 🚩 flags and the bar in the top bar are your health. Lose all the flags and the round is lost.',
      'Orange dummies are practice targets. They never move and they come back when destroyed.',
    ],
  ),
  RangeLesson(
    title: 'Swing',
    body: 'Put your finger anywhere on the course and drag back like a slingshot, then let go. The ball flies the opposite way.',
    tips: const [
      'A dotted line previews the shot. Drag further for more power; a very short drag cancels.',
      'Each club has its own cooldown, shown around the golfer.',
    ],
    goal: 'Hit a target',
    done: (s) => s.damageDealt > 0,
  ),
  RangeLesson(
    title: 'Sweet Spot',
    body: 'While you aim, a ring shrinks around the golfer. Release while it is inside the green band for a Sweet Spot.',
    tips: const ['A Sweet Spot deals +50% damage and pierces one more enemy.'],
    goal: 'Land a Sweet Spot',
    done: (s) => s.sweetSwings >= 1,
  ),
  RangeLesson(
    title: 'Clubs',
    body: 'Tap Bag at the bottom to pick a club from the list. Each family plays differently, and each club keeps its own cooldown.',
    tips: const [
      'Iron: bounces twice and hits fliers.',
      'Fairway Wood: pierces one enemy and bounces once.',
      'Driver: fast and straight, pierces three, hits fliers.',
      'Wedge: lobs over everything and lands as a blast.',
      'Putter: a ground roll that hits up to 10 enemies but misses fliers.',
      'In Story Mode your bag holds 3 clubs, one per family. On the range every club on the course is in the Bag, Specials included.',
    ],
    goal: 'Swing a club from every family',
    done: (s) => s.familiesSwung.length >= s.bag.whereType<BagClub>().map((b) => b.club.family.id).toSet().length,
  ),
  RangeLesson(
    title: 'Fliers',
    body: 'Crows fly over hazards and dive at your towers. The Putter rolls underneath them and the Wedge blast cannot reach them.',
    tips: const ['Use the Iron, Wood or Driver on blue fliers.'],
    goal: 'Shoot down the flying target',
    spawn: 'dummy_air',
    done: (s) => (s.killsById['dummy_air'] ?? 0) >= 1,
  ),
  RangeLesson(
    title: 'Heavy hitters',
    body: 'Tanks like the Gator soak up damage. The Wedge lobs over everything and lands as a blast.',
    tips: const ['A longer drag lands the lob further away.'],
    goal: 'Destroy the heavy target',
    spawn: 'dummy_tank',
    done: (s) => (s.killsById['dummy_tank'] ?? 0) >= 1,
  ),
  RangeLesson(
    title: 'Fore!',
    body: 'Hits build your combo (Bogey up to Albatross), which multiplies coins, and fill the Fore! meter.',
    tips: const ['Tap FORE! when it is full for a 3-second barrage of 20 balls. On the range the meter is always full.'],
    goal: 'Tap FORE!',
    done: (s) => s.foreBursts >= 1,
  ),
  RangeLesson(
    title: 'Towers',
    body: 'Towers fight for you from the build zone in front of the ball. Tap an empty plot to build. Coins are free on the range.',
    tips: const [
      'Tapping a plot or a tower pauses the game while you choose, even in the middle of a wave.',
      'Building costs the same any time. Tap a tower to upgrade it (3 levels) or sell it for 70% back.',
      'Enemies attack towers in their way. Watch the green health bar; upgrading repairs a tower.',
    ],
    goal: 'Build a tower',
    done: (s) => s.towersBuilt >= 1,
  ),
  RangeLesson(
    title: 'Overcharge',
    body: 'Flags pop up on the fairway now and then. Sink a ball in one and every tower is overcharged for a few seconds.',
    tips: const ['Open Range tools to put a flag on the course.'],
    goal: 'Overcharge your towers',
    done: (s) => s.overcharges >= 1,
  ),
  RangeLesson(
    title: 'Perks',
    body: 'Before each Story round you draft 1 of 3 perks. They last for the rest of the hole.',
    tips: const ['Open Range tools to try any perk here.'],
    goal: 'Try a perk from Range tools',
    done: (s) => s.perks.isNotEmpty,
  ),
  const RangeLesson(
    title: 'Meet the animals',
    body:
        'Every animal has a trick: geese stun towers, raccoons steal coins, squirrels blow up towers, boars charge. '
        'Open the Bestiary from the main menu, or spawn live animals from Range tools to practise.',
    tips: ['That is everything. From here the range is yours.'],
  ),
];
