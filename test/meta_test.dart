import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fore_last_stand/meta/profile.dart';
import 'package:fore_last_stand/story/arcade.dart';
import 'package:fore_last_stand/story/content.dart';
import 'package:fore_last_stand/story/sim/round_sim.dart';
import 'package:fore_last_stand/story/story_store.dart';

import 'story/helpers.dart';

void main() {
  late StoryContent c;
  setUpAll(() async => c = await loadContent());

  test('profile survives a JSON round trip', () {
    final p = Profile(runsPlayed: 3, bestSuddenDeath: 12, lastDailySeed: 20261126, bestDailyScore: 900)
      ..bestiary['goose'] = 12
      ..settings.gore = GoreLevel.squeakyClean
      ..settings.leftHanded = true
      ..settings.testAds = true;
    final back = Profile.fromJson((jsonDecode(jsonEncode(p.toJson())) as Map).cast<String, Object?>());
    expect(back.bestSuddenDeath, 12);
    expect(back.bestDailyScore, 900);
    expect(back.bestiary['goose'], 12);
    expect(back.settings.gore, GoreLevel.squeakyClean);
    expect(back.settings.leftHanded, isTrue);
    expect(back.settings.testAds, isTrue);
  });

  test('an old v1 profile keeps settings and the bestiary but drops arcade records', () {
    final old = {
      'coins': 50,
      'bestSuddenDeath': 9,
      'bestiary': {'goose': 3},
      'settings': {'leftHanded': true},
    };
    final p = Profile.fromJson(old);
    expect(p.bestSuddenDeath, 0);
    expect(p.bestiary['goose'], 3);
    expect(p.settings.leftHanded, isTrue);
  });

  test('daily seed and modifier depend only on the date', () {
    final seed = dailySeed(DateTime.utc(2026, 11, 26));
    expect(seed, 20261126);
    expect(dailyModifier(seed), isNot(DailyModifier.none));
    expect(dailyModifier(seed), dailyModifier(dailySeed(DateTime.utc(2026, 11, 26, 23))));
  });

  test('arcade runs use the Story bag, course layouts and engine', () {
    final story = StoryStore(c, freshSave(c), MemorySaveBackend());
    final s = arcadeSetup(story, Settings(), RoundMode.daily, seed: 20261126);
    expect(s.mode, RoundMode.daily);
    expect(s.round, 3, reason: 'five waves, then a final boss');
    expect(s.bag.whereType<BagClub>().map((b) => b.club.id), ['iron_old']);
    expect(c.course(muni).holes, contains(s.hole));
    expect(s.modifier, dailyModifier(20261126));
    final range = arcadeSetup(story, Settings(), RoundMode.range, seed: 1);
    expect(range.bag.whereType<BagClub>().map((b) => b.club.family.id).toSet(), {'iron', 'wood', 'driver', 'wedge', 'putter'});
  });

  test('Sudden Death records the most waves; the daily best resets each day', () {
    final story = StoryStore(c, freshSave(c), MemorySaveBackend());
    final p = Profile();
    final sd = RoundSim(arcadeSetup(story, Settings(), RoundMode.endless, seed: 5))..teeOff();
    sd.wavesCleared = 7;
    sd.endRun();
    final r = recordArcade(p, sd, seed: 5);
    expect(r.newBest, isTrue);
    expect(p.bestSuddenDeath, 7);
    final d1 = RoundSim(arcadeSetup(story, Settings(), RoundMode.daily, seed: 1))..teeOff();
    d1.kills = 50;
    recordArcade(p, d1, seed: 1);
    expect(p.bestDailyScore, greaterThan(0));
    final d2 = RoundSim(arcadeSetup(story, Settings(), RoundMode.daily, seed: 2))..teeOff();
    recordArcade(p, d2, seed: 2);
    expect(p.bestDailyScore, d2.score, reason: 'a new day resets the best');
  });

  test('pups count toward the Coyote bestiary entry', () {
    final p = Profile();
    addKills(p, {'goose': 3, 'coyote_pup': 2, 'coyote': 1});
    expect(p.bestiary['goose'], 3);
    expect(p.bestiary['coyote'], 3);
  });
}
