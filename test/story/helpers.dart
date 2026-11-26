import 'dart:io';

import 'package:fore_last_stand/story/content.dart';
import 'package:fore_last_stand/story/progression.dart';
import 'package:fore_last_stand/story/save.dart';
import 'package:fore_last_stand/story/sim/round_sim.dart';

/// Loads the real Story Mode JSON from `assets/courses/`.
Future<StoryContent> loadContent() => StoryContent.load((path) => File('${StoryContent.assetRoot}/$path').readAsString());

const String muni = 'suburban_muni';

/// A fresh save with the course created.
StorySave freshSave(StoryContent c) {
  final s = StorySave();
  grantStartingCaddies(c, s.player);
  courseSave(s, c, muni);
  return s;
}

/// A round sim for [hole]/[round] with the given bag club ids.
RoundSim sim(
  StoryContent c, {
  int hole = 1,
  int round = 1,
  int coins = 150,
  List<String?> bag = const ['iron_old', null, null],
  List<String> perks = const [],
  List<PlacedTower> towers = const [],
  String? caddie,
  String? boost,
  bool revive = false,
  int extraPlots = 0,
}) {
  final course = c.course(muni);
  return RoundSim(
    RoundSetup(
      content: c,
      courseId: muni,
      hole: course.hole(hole),
      round: round,
      coins: coins,
      towers: towers,
      perks: List.of(perks),
      bag: [for (final id in bag) id == null ? null : BagClub(course.club(id), 1)],
      unlockedTowers: c.towersUnlockedAt(9),
      caddieId: caddie,
      boost: boost,
      reviveAvailable: revive,
      extraPlots: extraPlots,
    ),
  );
}

/// Steps [s] until [cond] or [seconds] of sim time.
void runUntil(RoundSim s, bool Function() cond, {double seconds = 60}) {
  for (var t = 0.0; t < seconds && !cond(); t += 1 / 60) {
    s.update(1 / 60);
  }
}

/// Kills everything as it spawns until the round ends or [cond] holds.
void autoWin(RoundSim s, {bool Function()? cond, double seconds = 2000, bool skipBreaks = true}) {
  runUntil(s, () {
    for (final e in s.enemies) {
      if (e.alive) s.damageEnemy(e, 1e9);
    }
    if (s.finished || (cond?.call() ?? false)) return true;
    if (skipBreaks) s.skipBreak();
    return false;
  }, seconds: seconds);
}
