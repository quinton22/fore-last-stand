import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fore_last_stand/story/content.dart';
import 'package:fore_last_stand/story/progression.dart';
import 'package:fore_last_stand/story/save.dart';

import 'helpers.dart';

/// Plays a won round through finishRound + commitResult.
CommitOutcome winRound(StorySave s, StoryContent c, {bool replay = false, int endCoins = 200, List<PlacedTower> towers = const []}) {
  finishRound(
    s,
    c,
    muni,
    replay: replay,
    outcome: RoundOutcome(won: true, wavesCleared: 4, totalWaves: 4, flagsLeft: 3, endCoins: endCoins, endTowers: towers),
  );
  return commitResult(s, c, muni);
}

void main() {
  late StoryContent c;
  setUpAll(() async => c = await loadContent());

  test('a new save starts with one iron and two empty slots', () {
    final s = freshSave(c);
    final cs = s.courses[muni]!;
    expect(cs.bag, ['iron_old', null, null]);
    expect(cs.ownedClubs, {'iron_old': 1});
    expect(cs.rank, 1);
    expect(cs.current.hole, 1);
    expect(cs.current.round, 1);
    expect(cs.current.coins, 150);
    expect(s.player.caddies, {'big_earl': 1});
    expect(s.player.equippedCaddie, 'big_earl');
  });

  test('XP curve, round rewards and the totals in 6a.5 and 6a.6', () {
    final r = c.rules;
    expect(xpToNext(r, 1), 100);
    expect(xpToNext(r, 2), 160);
    var rank18 = 0;
    for (var k = 1; k < 18; k++) {
      rank18 += xpToNext(r, k);
    }
    expect(rank18, 9860);
    var xp9 = 0, tokens9 = 0;
    for (var h = 1; h <= 9; h++) {
      final w = roundReward(r, hole: h, won: true, wavesCleared: 4, totalWaves: 4);
      xp9 += 3 * w.xp;
      tokens9 += 3 * w.tokens;
    }
    expect(xp9, 4050);
    expect(tokens9, 1215);
    var rank11 = 0;
    for (var k = 1; k < 11; k++) {
      rank11 += xpToNext(r, k);
    }
    expect(rank11, 3700);
    final lost = roundReward(r, hole: 4, won: false, wavesCleared: 2, totalWaves: 4);
    expect(lost.xp, (140 * 0.25 * 0.5).floor());
    expect(lost.tokens, (40 * 0.25 * 0.5).floor());
    final replay = roundReward(r, hole: 4, won: true, wavesCleared: 5, totalWaves: 5, replay: true);
    expect(replay.xp, 70);
    expect(replay.tokens, 20);
  });

  test('the bag cannot hold two clubs of one family and keeps at least one club', () {
    final s = freshSave(c);
    final cs = s.courses[muni]!;
    final course = c.course(muni);
    cs.rank = 11;
    cs.tokens = 5000;
    expect(equipClub(course, cs, 'driver_used'), isFalse, reason: 'revealed but not bought');
    expect(buyClub(c.rules, course, cs, 'driver_used'), isTrue);
    expect(equipClub(course, cs, 'driver_used'), isTrue);
    expect(cs.bag, ['iron_old', 'driver_used', null]);
    expect(buyClub(c.rules, course, cs, 'iron_used'), isTrue);
    expect(equipClub(course, cs, 'iron_used'), isTrue);
    expect(cs.bag, ['iron_used', 'driver_used', null], reason: 'same family replaces');
    expect(buyClub(c.rules, course, cs, 'wood_old'), isTrue);
    expect(buyClub(c.rules, course, cs, 'wedge_old'), isTrue);
    expect(equipClub(course, cs, 'wood_old'), isTrue);
    expect(equipClub(course, cs, 'wedge_old'), isFalse, reason: 'full, no slot given');
    expect(equipClub(course, cs, 'wedge_old', slot: 2), isTrue);
    expect(cs.bag, ['iron_used', 'driver_used', 'wedge_old']);
    expect(bagIsValid(course, cs), isTrue);
    expect(unequipSlot(cs, 0), isTrue);
    expect(unequipSlot(cs, 1), isTrue);
    expect(unequipSlot(cs, 2), isFalse, reason: 'at least 1 club');
    expect(buyClub(c.rules, course, cs, 'thunder_stick'), isFalse, reason: 'rank 18 not reached');
  });

  test('clubs level 1-5 with the listed costs', () {
    final s = freshSave(c);
    final cs = s.courses[muni]!;
    cs.tokens = 240;
    for (final expected in [2, 3, 4, 5]) {
      expect(levelUpClub(c.rules, cs, 'iron_old'), isTrue);
      expect(cs.ownedClubs['iron_old'], expected);
    }
    expect(cs.tokens, 0);
    cs.tokens = 999;
    expect(levelUpClub(c.rules, cs, 'iron_old'), isFalse, reason: 'max level 5');
  });

  test('winning rounds carries coins and towers, then a new hole resets them', () {
    final s = freshSave(c);
    final cs = s.courses[muni]!;
    final tower = PlacedTower(type: 'range', col: 1, row: 0);
    teeOff(s, muni, replay: false, coins: 100, towers: [tower], perk: 'extra_bounce');
    winRound(s, c, endCoins: 180, towers: [tower]);
    expect(cs.current.round, 2);
    expect(cs.current.coins, 180);
    expect(cs.current.towers, [tower]);
    expect(cs.current.perks, ['extra_bounce']);
    expect(cs.current.roundPerk, isNull);
    winRound(s, c);
    final out = winRound(s, c);
    expect(out.holeBeaten, isTrue);
    expect(cs.highestHoleBeaten, 1);
    expect(cs.current.hole, 2);
    expect(cs.current.round, 1);
    expect(cs.current.coins, 150);
    expect(cs.current.towers, isEmpty);
    expect(cs.current.perks, isEmpty);
    expect(s.player.caddieBadges, 1);
  });

  test('a rank-up reveals exactly one club', () {
    final s = freshSave(c);
    final cs = s.courses[muni]!;
    final out = winRound(s, c); // 110 XP
    expect(out.rankUps, [2]);
    expect(out.revealed.map((x) => x.id), ['wood_old']);
    expect(cs.xp, 10);
    expect(cs.tokens, 25);
    expect(buyClub(c.rules, c.course(muni), cs, 'wood_old'), isTrue, reason: "Granddad's 3-Wood is affordable after round 1");
  });

  test('concede leaves everything exactly as it was at Tee Off', () {
    final s = freshSave(c);
    final cs = s.courses[muni]!;
    final tower = PlacedTower(type: 'range', col: 0, row: 0);
    teeOff(s, muni, replay: false, coins: 90, towers: [tower], perk: 'coin_gain');
    cs.current.bankedBoost = 'coins';
    final before = jsonEncode(cs.toJson());
    finishRound(
      s,
      c,
      muni,
      replay: false,
      outcome: RoundOutcome(
        won: true,
        wavesCleared: 4,
        totalWaves: 4,
        flagsLeft: 3,
        endCoins: 400,
        endTowers: [
          tower,
          PlacedTower(type: 'range', col: 1, row: 0),
        ],
      ),
    );
    expect(cs.pendingResult, isNotNull);
    concede(s, muni, replay: false);
    expect(cs.pendingResult, isNull);
    expect(cs.rank, 1);
    expect(cs.xp, 0);
    expect(cs.tokens, 0);
    expect(cs.current.coins, 90);
    expect(cs.current.towers, [tower]);
    expect(cs.current.round, 1);
    expect(cs.current.hole, 1);
    expect(cs.current.perks, isEmpty, reason: "a conceded round's pick is removed");
    expect(cs.current.bankedBoost, 'coins', reason: 'a watched boost is kept on concede');
    // Apart from the pick, the course is byte-for-byte the Tee Off snapshot.
    final after = (jsonDecode(before) as Map).cast<String, Object?>();
    final cur = (after['current'] as Map)
      ..['perks'] = []
      ..['roundPerk'] = null;
    after['current'] = cur;
    expect(jsonEncode(cs.toJson()), jsonEncode(after));
  });

  test('conceding a won round 3 does not beat the hole', () {
    final s = freshSave(c);
    final cs = s.courses[muni]!;
    winRound(s, c);
    winRound(s, c);
    finishRound(s, c, muni, replay: false, outcome: const RoundOutcome(won: true, wavesCleared: 6, totalWaves: 6, flagsLeft: 3, endCoins: 0, endTowers: []));
    concede(s, muni, replay: false);
    expect(cs.highestHoleBeaten, 0);
    expect(cs.current.hole, 1);
    expect(cs.current.round, 3);
  });

  test('a lost round keeps the Tee Off snapshot and uses up the boost', () {
    final s = freshSave(c);
    final cs = s.courses[muni]!;
    teeOff(
      s,
      muni,
      replay: false,
      coins: 70,
      towers: [PlacedTower(type: 'range', col: 0, row: 0)],
      perk: 'tower_cost',
    );
    cs.current.bankedBoost = 'full_fore';
    finishRound(s, c, muni, replay: false, outcome: const RoundOutcome(won: false, wavesCleared: 2, totalWaves: 4, flagsLeft: 0, endCoins: 5, endTowers: []));
    commitResult(s, c, muni);
    expect(cs.current.coins, 70);
    expect(cs.current.towers, hasLength(1));
    expect(cs.current.round, 1);
    expect(cs.current.bankedBoost, isNull);
    expect(cs.current.roundPerk, 'tower_cost', reason: 'the retry keeps the drafted perk');
    expect(cs.xp, (110 * 0.25 * 0.5).floor());
  });

  test('holes unlock strictly in order and hole 9 completes the MVP course', () {
    final s = freshSave(c);
    final cs = s.courses[muni]!;
    CommitOutcome? last;
    for (var h = 1; h <= 9; h++) {
      expect(cs.current.hole, h);
      for (var r = 1; r <= 3; r++) {
        expect(cs.current.round, r);
        last = winRound(s, c);
      }
    }
    expect(last!.courseComplete, isTrue);
    expect(courseFinished(cs, c.course(muni)), isTrue);
    expect(cs.rank, 11, reason: 'holes 1-9 give enough XP for rank 11');
    expect(cs.tokens, 1215 - 0);
    expect(s.player.caddieBadges, 9);
    expect(s.player.caddies.keys, containsAll(['big_earl', 'dottie']));
    expect(s.unlockedCourses, ['suburban_muni'], reason: 'course 2 has no content yet');
  });

  test('dottie unlocks on beating hole 3; caddie ranks cost badges', () {
    final s = freshSave(c);
    for (var i = 0; i < 9; i++) {
      final out = winRound(s, c);
      if (i == 8) expect(out.newCaddies, ['dottie']);
    }
    expect(s.player.caddieBadges, 3);
    expect(rankUpCaddie(c.rules, s.player, 'big_earl'), isTrue);
    expect(rankUpCaddie(c.rules, s.player, 'big_earl'), isTrue);
    expect(s.player.caddies['big_earl'], 3);
    expect(s.player.caddieBadges, 0);
    expect(rankUpCaddie(c.rules, s.player, 'dottie'), isFalse);
    expect(caddieScale(c.rules, 3), closeTo(1.2, 1e-9));
  });

  test('clubhouse wings: snack bar coins, locker room rerolls', () {
    final s = freshSave(c);
    final cs = s.courses[muni]!;
    cs.tokens = 1000;
    expect(buyWing(c.rules, cs, 'snackBar'), isTrue);
    expect(buyWing(c.rules, cs, 'snackBar'), isTrue);
    expect(cs.tokens, 1000 - 40 - 80);
    expect(holeStartCoins(c.rules, cs), 200);
    expect(rerollsLeft(c.rules, cs, cs.current, usedThisDraft: 0), 1);
    buyWing(c.rules, cs, 'lockerRoom');
    expect(rerollsLeft(c.rules, cs, cs.current, usedThisDraft: 0), 2);
    expect(rerollsLeft(c.rules, cs, cs.current, usedThisDraft: 2), 0);
    for (var i = 0; i < 5; i++) {
      buyWing(c.rules, cs, 'greenskeeping');
    }
    expect(cs.wingTier('greenskeeping'), 3);
    cs.tokens = 10000;
    for (var i = 0; i < 10; i++) {
      buyWing(c.rules, cs, 'grounds');
    }
    expect(cs.wingTier('grounds'), 6, reason: 'Grounds Crew opens the 6 front-row plots one at a time');
  });

  test('perk offers are seeded and never repeat a perk on the hole', () {
    final s = freshSave(c);
    final run = s.courses[muni]!.current;
    final a = perkOffer(c, muni, run);
    expect(a, hasLength(3));
    expect(perkOffer(c, muni, run).map((p) => p.id), a.map((p) => p.id));
    expect(perkOffer(c, muni, run, draft: 1).map((p) => p.id), isNot(a.map((p) => p.id)));
    run.perks.add(a.first.id);
    run.round = 2;
    for (var d = 0; d < 20; d++) {
      expect(perkOffer(c, muni, run, draft: d).map((p) => p.id), isNot(contains(a.first.id)));
    }
  });

  test('clubs, rank and tokens belong to one course; caddies travel', () {
    final s = freshSave(c);
    final cs = s.courses[muni]!;
    cs.tokens = 77;
    cs.rank = 5;
    final other = CourseSave.fresh(starterClub: 'iron_old', startCoins: 150);
    s.courses['course_2'] = other;
    expect(other.rank, 1);
    expect(other.tokens, 0);
    expect(other.ownedClubs.keys, ['iron_old']);
    expect(other.clubhouse.values.every((v) => v == 0), isTrue);
    s.player.caddieBadges = 4;
    final back = StorySave.fromJson((jsonDecode(jsonEncode(s.toJson())) as Map).cast<String, Object?>());
    expect(back.courses[muni]!.tokens, 77);
    expect(back.courses['course_2']!.tokens, 0);
    expect(back.player.caddieBadges, 4);
  });

  test('replays pay half, start with 150 coins and leave story progress alone', () {
    final s = freshSave(c);
    final cs = s.courses[muni]!;
    for (var i = 0; i < 3; i++) {
      winRound(s, c);
    }
    final current = jsonEncode(cs.current.toJson());
    final run = startReplay(s, c, muni, 1);
    expect(run.coins, 150);
    expect(run.towers, isEmpty);
    final tokens = cs.tokens;
    winRound(s, c, replay: true);
    expect(cs.tokens - tokens, 12);
    winRound(s, c, replay: true);
    final out = winRound(s, c, replay: true);
    expect(out.replayFinished, isTrue);
    expect(cs.replayRun, isNull);
    expect(jsonEncode(cs.current.toJson()), current);
    expect(s.player.caddieBadges, 1, reason: 'no badge for a replay');
  });

  test('save JSON matches the 6a.13 shape', () {
    final s = freshSave(c);
    final j = s.toJson();
    expect(j['version'], 1);
    expect(j['unlockedCourses'], ['suburban_muni']);
    final course = (j['courses'] as Map)[muni] as Map;
    for (final k in ['rank', 'xp', 'tokens', 'ownedClubs', 'clubhouse', 'bag', 'highestHoleBeaten', 'current', 'pendingResult']) {
      expect(course.containsKey(k), isTrue, reason: k);
    }
    expect((course['current'] as Map).keys, containsAll(['hole', 'round', 'coins', 'perks', 'bankedBoost', 'towers']));
  });
}
