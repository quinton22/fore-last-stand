import 'dart:math' as math;

import '../content.dart';
import '../progression.dart';

/// Wave budget (6a.7): `10 * (1 + 0.12*(hole-1)) * (1 + 0.15*(round-1)) * (1 + 0.10*(wave-1))`,
/// plus 15% per flag lost earlier in the round.
double waveBudget(Rules r, {required int hole, required int round, required int wave, int flagsLost = 0}) =>
    r.n('waves.budgetBase') *
    (1 + r.n('waves.perHole') * (hole - 1)) *
    (1 + r.n('waves.perRound') * (round - 1)) *
    (1 + r.n('waves.perWave') * (wave - 1)) *
    (1 + r.n('teeBox.budgetPerLostFlag') * flagsLost);

/// Spawnable enemies unlocked by [hole].
List<StoryEnemy> unlockedEnemies(StoryContent c, int hole) =>
    c.enemies.values.where((e) => e.spawnable && e.firstHole <= hole).toList()..sort((a, b) => a.firstHole.compareTo(b.firstHole));

/// The hole's newest enemy: always in wave 1.
StoryEnemy newestEnemy(StoryContent c, int hole) => unlockedEnemies(c, hole).last;

/// Enemy ids for a normal [wave] (1-based), in spawn order. Seeded by course,
/// hole, round and wave so a retry plays the same.
List<String> waveRoster(StoryContent c, String courseId, {required int hole, required int round, required int wave, int flagsLost = 0}) {
  final rng = math.Random(roundSeed(courseId, hole, round, 'wave$wave'));
  var budget = waveBudget(c.rules, hole: hole, round: round, wave: wave, flagsLost: flagsLost);
  final pool = unlockedEnemies(c, hole);
  final out = <String>[];
  if (wave == 1) {
    final newest = pool.last;
    out.add(newest.id);
    budget -= newest.cost;
  }
  while (true) {
    final affordable = pool.where((e) => e.cost <= budget + 1e-9).toList();
    if (affordable.isEmpty) break;
    final e = affordable[rng.nextInt(affordable.length)];
    out.add(e.id);
    budget -= e.cost;
  }
  return out;
}

/// Total waves in a round: the normal waves plus the boss wave.
int totalWaves(Rules r, int round) => r.rounds[round - 1].waves + 1;
