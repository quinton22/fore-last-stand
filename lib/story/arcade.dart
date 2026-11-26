import 'dart:math' as math;

import '../meta/profile.dart';
import 'content.dart';
import 'sim/round_sim.dart';
import 'story_store.dart';

/// Sudden Death, the Daily Tournament and the Driving Range run on the Story
/// engine with the player's Story bag and caddie.

/// Seed shared by everyone on a given (UTC) day.
int dailySeed(DateTime day) {
  final d = day.toUtc();
  return d.year * 10000 + d.month * 100 + d.day;
}

DailyModifier dailyModifier(int seed) {
  final options = DailyModifier.values.where((m) => m != DailyModifier.none).toList();
  return options[seed % options.length];
}

/// The course whose bag, clubs and layouts the arcade modes use: the latest
/// unlocked course with content.
String arcadeCourse(StoryStore story) =>
    story.save.unlockedCourses.lastWhere((id) => story.content.courseContent.containsKey(id), orElse: () => story.content.courseContent.keys.first);

/// The hole layout for a seeded arcade run.
StoryHole arcadeHole(StoryContent content, String courseId, int seed) {
  final holes = content.course(courseId).holes;
  return holes[seed % holes.length];
}

/// A flat practice hole for the Driving Range.
const StoryHole rangeHole = StoryHole(number: 1, name: 'Driving Range', featured: 'goose', hazards: Hazards());

/// One starter club of each family, for trying them all on the range.
List<BagClub?> rangeBag(CourseContent course) {
  final seen = <String>{};
  return [
    for (final c in course.clubs)
      if (seen.add(c.family.id)) BagClub(c, 1),
  ];
}

RoundSetup arcadeSetup(StoryStore story, Settings settings, RoundMode mode, {required int seed, bool reviveAvailable = false}) {
  final content = story.content;
  final courseId = arcadeCourse(story);
  final course = content.course(courseId);
  final cs = story.course(courseId);
  final player = story.save.player;
  final caddie = player.equippedCaddie;
  final bag = mode == RoundMode.range ? rangeBag(course) : [for (final id in cs.bag) id == null ? null : BagClub(course.club(id), cs.ownedClubs[id] ?? 1)];
  return RoundSetup(
    content: content,
    courseId: courseId,
    hole: mode == RoundMode.range ? rangeHole : arcadeHole(content, courseId, seed),
    // The Daily Tournament plays like a round 3: five waves, then a final boss.
    round: mode == RoundMode.daily ? content.rules.roundsPerHole : 1,
    coins: mode == RoundMode.range ? 9999 : content.rules.i('arcade.startCoins'),
    towers: const [],
    perks: const [],
    bag: bag,
    unlockedTowers: content.towers,
    caddieId: caddie,
    caddieRank: caddie == null ? 1 : player.caddies[caddie] ?? 1,
    aimAssist: settings.aimAssist,
    autoCaddie: settings.autoCaddie && mode != RoundMode.range,
    reviveAvailable: reviveAvailable && mode != RoundMode.range,
    mode: mode,
    modifier: mode == RoundMode.daily ? dailyModifier(seed) : DailyModifier.none,
    seed: seed,
  );
}

/// Seeded perk offer for arcade drafts (Daily at Prep, Sudden Death every few waves).
List<StoryPerk> arcadePerkOffer(StoryContent content, int seed, List<String> held, {int draft = 0}) {
  final rng = math.Random(seed * 31 + draft * 7 + held.length * 101);
  final pool = content.perks.where((p) => !held.contains(p.id)).toList();
  final out = <StoryPerk>[];
  for (var i = 0; i < math.min(content.rules.i('perks.choices'), pool.length); i++) {
    out.add(pool.removeAt(rng.nextInt(pool.length)));
  }
  return out;
}

class ArcadeResult {
  const ArcadeResult({required this.mode, required this.waves, required this.kills, required this.score, required this.best, required this.newBest});

  final RoundMode mode;
  final int waves;
  final int kills;
  final int score;
  final int best;
  final bool newBest;
}

/// Records a finished arcade run: best scores and the bestiary.
ArcadeResult recordArcade(Profile p, RoundSim sim, {required int seed}) {
  p.runsPlayed++;
  addKills(p, sim.killsById);
  if (sim.mode == RoundMode.endless) {
    final best = p.bestSuddenDeath;
    p.bestSuddenDeath = math.max(best, sim.wavesCleared);
    return ArcadeResult(mode: sim.mode, waves: sim.wavesCleared, kills: sim.kills, score: sim.score, best: p.bestSuddenDeath, newBest: sim.wavesCleared > best);
  }
  if (p.lastDailySeed != seed) p.bestDailyScore = 0;
  p.lastDailySeed = seed;
  final best = p.bestDailyScore;
  p.bestDailyScore = math.max(best, sim.score);
  return ArcadeResult(mode: sim.mode, waves: sim.wavesCleared, kills: sim.kills, score: sim.score, best: p.bestDailyScore, newBest: sim.score > best);
}

/// Adds kills to the bestiary (coyote followers count toward the Coyote).
void addKills(Profile p, Map<String, int> kills) {
  for (final e in kills.entries) {
    final id = e.key == 'coyote_pup' ? 'coyote' : e.key;
    p.bestiary[id] = (p.bestiary[id] ?? 0) + e.value;
  }
}
