import '../sim/vec.dart';

/// Where a spawn group enters the board.
enum SpawnEdge { top, left, right, sides, any, water }

class SpawnGroup {
  const SpawnGroup(this.enemyId, this.count, {this.interval = 1.2, this.delay = 0, this.edge = SpawnEdge.top});

  final String enemyId;
  final int count;

  /// Seconds between spawns inside this group.
  final double interval;

  /// Seconds after the hole starts before the first spawn.
  final double delay;
  final SpawnEdge edge;
}

class HoleSpec {
  const HoleSpec({required this.groups, required this.par, this.breather = false, this.coinBonus = 0, this.bossScale = 1});

  final List<SpawnGroup> groups;

  /// Target seconds to clear the hole (spec 2).
  final double par;

  /// Calmer hole with a coin bonus (spec 5: every third hole).
  final bool breather;
  final int coinBonus;

  /// Health multiplier for any boss in this hole (mini-boss < 1).
  final double bossScale;

  int get enemyCount => groups.fold(0, (n, g) => n + g.count);
  bool get hasBoss => groups.any((g) => g.enemyId == 'goose_king');
}

/// The arcade board (Sudden Death, Daily Tournament, Driving Range). Holes are
/// generated; Story Mode courses are JSON in `assets/courses/`.
class CourseSpec {
  const CourseSpec({required this.id, required this.name, required this.water, required this.description});

  final String id;
  final String name;
  final String description;

  /// Water hazards: gators surface from these.
  final List<Box> water;
}

const suburbanMuni = CourseSpec(
  id: 'suburban_muni',
  name: 'Suburban Muni',
  description: 'Water hazards everywhere. Gators surface from the ponds.',
  water: [Box(14, 130, 104, 180), Box(250, 210, 346, 258)],
);
