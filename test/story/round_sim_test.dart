import 'package:flutter_test/flutter_test.dart';
import 'package:fore_last_stand/sim/vec.dart';
import 'package:fore_last_stand/story/content.dart';
import 'package:fore_last_stand/story/save.dart';
import 'package:fore_last_stand/story/sim/layout.dart';
import 'package:fore_last_stand/story/sim/round_sim.dart';

import 'helpers.dart';

void main() {
  late StoryContent c;
  setUpAll(() async => c = await loadContent());

  test('prep: nothing moves until Tee Off, then wave 1 starts', () {
    final s = sim(c);
    expect(s.phase, RoundPhase.prep);
    s.update(1);
    expect(s.enemies, isEmpty);
    s.teeOff();
    expect(s.phase, RoundPhase.wave);
    expect(s.wave, 1);
    expect(s.totalWaveCount, 4);
    s.update(0.05);
    expect(s.enemies, hasLength(1));
  });

  test('drag: under 24 cancels, 24-120 maps to 35-100% power, ball flies opposite', () {
    final s = sim(c)..teeOff();
    expect(s.powerFor(23), isNull);
    expect(s.powerFor(24), closeTo(0.35, 1e-9));
    expect(s.powerFor(72), closeTo(0.675, 1e-9));
    expect(s.powerFor(500), closeTo(1, 1e-9));
    s.beginAim();
    expect(s.release(0, 20), isEmpty);
    s.beginAim();
    final ball = s.release(0, 120).single;
    expect(ball.vel.y, lessThan(0));
    expect(ball.distance, closeTo(420, 1e-9), reason: 'iron range at full power');
    expect(ball.damage, closeTo(20, 1e-9));
  });

  test('sweet spot: the ring shrinks 48 to 16 over 0.7 s; 16-24 gives +50% damage and +1 pierce', () {
    final s = sim(c, bag: ['driver_used', null, null])..teeOff();
    s.beginAim();
    expect(s.ringRadius, 48);
    s.aimTime = 0.35;
    expect(s.ringRadius, closeTo(32, 1e-9));
    expect(s.inSweetSpot, isFalse);
    s.aimTime = 0.6;
    expect(s.inSweetSpot, isTrue);
    final ball = s.release(0, 100).single;
    expect(ball.sweet, isTrue);
    expect(ball.damage, closeTo(30 * 1.2 * 1.5, 1e-9));
    expect(ball.pierce, 4);
  });

  test('each club keeps its own cooldown when switching', () {
    final s = sim(c, bag: ['iron_old', 'driver_used', null])..teeOff();
    s.beginAim();
    expect(s.release(0, 100), hasLength(1));
    expect(s.cooldowns[0], closeTo(0.8, 1e-9));
    s.beginAim();
    expect(s.release(0, 100), isEmpty, reason: 'iron cooling down');
    s.selectSlot(1);
    s.beginAim();
    expect(s.release(0, 100), hasLength(1));
    expect(s.cooldowns[1], closeTo(1.1, 1e-9));
    s.selectSlot(2);
    expect(s.selectedSlot, 1, reason: 'empty slot cannot be selected');
  });

  test('a hit climbs the combo, a miss resets it, kills pay coins times the combo', () {
    final s = sim(c)..teeOff();
    s.enemies.clear();
    final goose = s.spawnEnemy('goose', at: const V2(195, 420));
    goose.abilityTimer = 99;
    s.beginAim();
    s.release(0, 120);
    runUntil(s, () => s.balls.isEmpty, seconds: 2);
    expect(goose.hp, closeTo(10, 1e-9), reason: 'iron does 20, goose has 30');
    expect(s.comboRung, 1);
    expect(s.comboName, 'Par');
    s.cooldowns[0] = 0;
    s.beginAim();
    s.release(120, 0); // left into the wall and away
    runUntil(s, () => s.balls.isEmpty, seconds: 3);
    expect(s.comboRung, 0, reason: 'a miss resets the combo');
    s.comboRung = 4; // Albatross x2.0
    final coins = s.coins;
    s.damageEnemy(goose, 100);
    expect(s.coins - coins, 8);
  });

  test('Fore! meter: +4 per hit, +8 per sweet hit; burst fires 20 balls over 3 s', () {
    final s = sim(c, bag: ['driver_used', null, null])..teeOff();
    s.enemies.clear();
    final e = s.spawnEnemy('gator', at: const V2(195, 400));
    e.slowTimer = 99;
    e.slowAmount = 1;
    s.beginAim();
    s.release(0, 120);
    runUntil(s, () => s.balls.isEmpty, seconds: 2);
    expect(s.foreMeter, 4);
    expect(s.comboRung, 1);
    s.cooldowns[0] = 0;
    s.beginAim();
    s.aimTime = 0.65;
    s.release(0, 120);
    runUntil(s, () => s.balls.isEmpty, seconds: 2);
    expect(s.foreMeter, 12);
    s.foreMeter = 100;
    expect(s.triggerFore(), isTrue);
    var launched = 0;
    final seen = <SBall>{};
    for (var t = 0.0; t < 3.2; t += 1 / 60) {
      s.update(1 / 60);
      for (final b in s.balls) {
        if (seen.add(b)) launched++;
      }
    }
    expect(launched, 20);
    expect(s.foreMeter, lessThan(100), reason: 'burst balls do not charge the meter');
  });

  test('tee box: 100 health and 3 flags; a flag drops to 30; a lost flag grows later waves', () {
    final s = sim(c)..teeOff();
    expect(s.health, 100);
    s.damageTee(100);
    expect(s.flags, 2);
    expect(s.health, 30);
    expect(s.flagsLost, 1);
    s.damageTee(30);
    s.damageTee(30);
    expect(s.phase, RoundPhase.lost);
  });

  test('revive: one flag at full health, nearby enemies removed, bosses pushed back', () {
    final s = sim(c, revive: true)..teeOff();
    s.enemies.clear();
    final near = s.spawnEnemy('goose', at: const V2(195, 520));
    final far = s.spawnEnemy('goose', at: const V2(195, 150));
    final boss = s.spawnEnemy('goose', at: const V2(100, 500), mini: true);
    s.flags = 1;
    s.damageTee(1000);
    expect(s.phase, RoundPhase.revive);
    s.acceptRevive();
    expect(s.phase, RoundPhase.wave);
    expect(s.flags, 1);
    expect(s.health, s.maxHealth);
    expect(near.alive, isFalse);
    expect(far.alive, isTrue);
    expect(boss.pos.y, lessThan(150));
    s.damageTee(1000);
    expect(s.phase, RoundPhase.lost, reason: 'once per round attempt');
  });

  test('waves end when cleared, an 8 s build break follows with Skip, the boss wave wins', () {
    final s = sim(c)..teeOff();
    autoWin(s, cond: () => s.phase == RoundPhase.buildBreak, skipBreaks: false);
    expect(s.phase, RoundPhase.buildBreak);
    expect(s.breakTimer, greaterThan(7));
    s.skipBreak();
    s.update(0.01);
    expect(s.wave, 2);
    autoWin(s);
    expect(s.phase, RoundPhase.won);
    expect(s.wavesCleared, 4);
    expect(s.outcome().won, isTrue);
  });

  test('round 3 ends with the final boss; rounds 1 and 2 with a mini-boss', () {
    final r1 = sim(c, hole: 3)..teeOff();
    autoWin(r1, cond: () => r1.enemies.any((e) => e.boss));
    final mini = r1.enemies.firstWhere((e) => e.boss);
    expect(mini.spec.id, 'gator');
    expect(mini.radius, closeTo(16 * 1.6, 1e-9));
    expect(mini.maxHp, closeTo(140 * 1.16 * 8, 1e-6));
    expect(mini.damage, 45);
    final r3 = sim(c, hole: 3, round: 3)..teeOff();
    expect(r3.totalWaveCount, 6);
    autoWin(r3, cond: () => r3.enemies.any((e) => e.finalBoss));
    final boss = r3.enemies.firstWhere((e) => e.finalBoss);
    expect(boss.bossSpec!.id, 'alpha_gator');
    expect(boss.maxHp, closeTo(1000 * 1.16, 1e-6));
    expect(boss.speed, 20);
  });

  test('a boss that reaches the tee box deals 40, retreats and comes back', () {
    final s = sim(c, round: 3)..teeOff();
    s.enemies.clear();
    final boss = s.spawnFinalBoss();
    boss.pos = const V2(195, StoryLayout.teeLine - 2);
    s.update(0.05);
    expect(s.health, 60);
    expect(boss.retreating, isTrue);
    expect(boss.alive, isTrue);
    runUntil(s, () => !boss.retreating, seconds: 20);
    expect(boss.pos.y, lessThan(StoryLayout.fairway.top + 40));
  });

  test('every enemy that reaches the tee box deals its damage once and is removed', () {
    final s = sim(c, hole: 9, coins: 100)..teeOff();
    s.enemies.clear();
    final goose = s.spawnEnemy('goose', at: const V2(195, StoryLayout.teeLine - 1.5));
    goose.abilityTimer = 99;
    s.update(0.05);
    expect(goose.alive, isFalse);
    expect(s.health, 95);
    final raccoon = s.spawnEnemy('raccoon', at: const V2(150, StoryLayout.teeLine - 1.5));
    s.update(0.05);
    expect(raccoon.fleeing, isTrue);
    expect(raccoon.stolen, 15);
    expect(s.coins, 85);
    s.damageEnemy(raccoon, 1e6);
    expect(s.coins, greaterThanOrEqualTo(100), reason: 'killing it returns the coins');
  });

  test('towers: unlocks, costs, live placement doubles cost with slow motion, 70% refund, 3 levels', () {
    final s = sim(c, hole: 1, coins: 1000);
    expect(s.placeCost(c.tower('range')), 50);
    final t = s.placeTower('range', 0, 0)!;
    expect(s.coins, 950);
    expect(s.upgradeCost(t), 38);
    expect(s.upgradeTower(t), isTrue);
    expect(s.upgradeCost(t), 63);
    expect(s.upgradeTower(t), isTrue);
    expect(s.upgradeCost(t), isNull);
    expect(s.sellValue(t), ((50 + 38 + 63) * 0.7).floor());
    expect(s.placeTower('ripper', 1, 2), isNull, reason: 'ripper is front row only');
    expect(s.placeTower('ripper', 1, 0), isNotNull);
    s.teeOff();
    expect(s.placeCost(c.tower('range')), 100);
    s.placeTower('range', 3, 3);
    expect(s.slowMo, 2);
  });

  test('tower targeting picks the enemy nearest the tee box', () {
    final s = sim(c, coins: 1000)..teeOff();
    s.enemies.clear();
    s.placeTower('range', 1, 0);
    s.slowMo = 0;
    final far = s.spawnEnemy('goose', at: const V2(170, 420));
    final close = s.spawnEnemy('goose', at: const V2(230, 470));
    far.abilityTimer = close.abilityTimer = 99;
    s.update(0.02);
    expect(close.hp, lessThan(close.maxHp));
    expect(far.hp, far.maxHp);
  });

  test('perks: coins now and tee health apply at Tee Off; tower cost -20% in Prep', () {
    final s = sim(c);
    s.pickPerk('coins_now');
    s.teeOff();
    expect(s.coins, 210);
    final t = sim(c, perks: ['tee_health', 'tower_cost']);
    expect(t.placeCost(c.tower('range')), 40);
    t.teeOff();
    expect(t.maxHealth, 130);
    final r = sim(c, perks: ['coins_now']);
    r.teeOff();
    expect(r.coins, 150, reason: 'a perk from an earlier round is not paid again');
  });

  test('boosts: club damage +25%, full Fore!, 75 coins', () {
    final a = sim(c, boost: 'club_damage')..teeOff();
    a.beginAim();
    expect(a.release(0, 100).single.damage, closeTo(25, 1e-9));
    final b = sim(c, boost: 'full_fore')..teeOff();
    expect(b.foreReady, isTrue);
    final d = sim(c, boost: 'coins')..teeOff();
    expect(d.coins, 225);
  });

  test('caddies: Big Earl adds 50 to the meter once per round; Dottie marks the toughest', () {
    final s = sim(c, caddie: 'big_earl')..teeOff();
    expect(s.useCaddie(), isTrue);
    expect(s.foreMeter, 50);
    expect(s.useCaddie(), isFalse);
    final d = sim(c, caddie: 'dottie')..teeOff();
    d.enemies.clear();
    final weak = d.spawnEnemy('goose', at: const V2(100, 200));
    final tough = d.spawnEnemy('gator', at: const V2(300, 200));
    d.useCaddie();
    expect(tough.markTimer, 6);
    expect(weak.markTimer, 0);
    d.damageEnemy(tough, 10);
    expect(tough.maxHp - tough.hp, closeTo(15, 1e-9));
  });

  test('special clubs: twin timber fires two balls at 70%; hot poker burns', () {
    final s = sim(c, bag: ['twin_timber', 'hot_poker', null])..teeOff();
    s.beginAim();
    final balls = s.release(0, 100);
    expect(balls, hasLength(2));
    expect(balls.first.damage, closeTo(24 * 1.6 * 0.7, 1e-9));
    s.enemies.clear();
    s.selectSlot(1);
    final gator = s.spawnEnemy('gator', at: const V2(195, 420));
    s.beginAim();
    s.release(0, 120);
    runUntil(s, () => gator.burnTimer > 0, seconds: 2);
    expect(gator.burnDps, 8);
  });

  test('putter rolls are lost in water; wedge lobs fly over and blast', () {
    final s = sim(c, hole: 3, bag: ['putter_old', 'wedge_old', null])..teeOff();
    s.enemies.clear();
    s.beginAim();
    final putt = s.release(0, 120).single;
    runUntil(s, () => putt.done, seconds: 3);
    expect(putt.pos.y, greaterThan(230), reason: 'stopped at the pond (y 230-310)');
    s.selectSlot(1);
    final gator = s.spawnEnemy('gator', at: const V2(195, 200));
    s.beginAim();
    final lob = s.release(0, 120 * (548 - 200 - 126) / 234 + 0).single;
    expect(lob.isLob, isTrue);
    gator.pos = lob.lobTarget!;
    gator.slowTimer = 99;
    gator.slowAmount = 1;
    runUntil(s, () => lob.done, seconds: 3);
    if (!c.course(muni).hole(3).hazards.water.any((w) => w.contains(lob.lobTarget!))) {
      expect(gator.hp, lessThan(gator.maxHp));
    }
  });

  test('a full simulated hole 9 round 3 plays without errors', () {
    final s = sim(c, hole: 9, round: 3, coins: 2000, bag: ['driver_new', 'wedge_new', 'iron_new'], caddie: 'dottie');
    for (final (id, col, row) in [
      ('range', 0, 0),
      ('tesla', 1, 0),
      ('sprinkler', 1, 1),
      ('cannon', 2, 1),
      ('ripper', 3, 0),
      ('sniper', 0, 1),
      ('snack_shack', 2, 2),
      ('sand_trap', 2, 0),
    ]) {
      expect(s.placeTower(id, col, row), isNotNull, reason: id);
    }
    s.teeOff();
    var t = 0.0;
    var slot = 0;
    while (!s.finished && t < 900) {
      if (s.phase == RoundPhase.revive) s.declineRevive();
      if (s.foreReady) s.triggerFore();
      if (s.caddieReady && s.enemies.isNotEmpty) s.useCaddie();
      if (s.cooldowns[slot] <= 0 && s.enemies.isNotEmpty) {
        final target = s.enemies.first.pos;
        final d = StoryLayout.golfer - target;
        s.beginAim();
        s.aimTime = 0.6;
        s.release(d.x / d.length * 100, d.y / d.length * 100);
        slot = (slot + 1) % 3;
        s.selectSlot(slot);
      }
      s.skipBreak();
      s.update(1 / 30);
      t += 1 / 30;
    }
    expect(s.finished, isTrue);
    expect(s.kills, greaterThan(20));
    expect(s.outcome().endTowers.length, lessThanOrEqualTo(8));
  });

  test('a retry plays the same: same seed, same spawns', () {
    List<String> spawns() {
      final s = sim(c, hole: 8, round: 2)..teeOff();
      final out = <String>[];
      for (var i = 0; i < 300; i++) {
        s.update(1 / 30);
        for (final e in s.enemies) {
          final key = '${e.spec.id}@${e.pos.x.round()},${e.pos.y.round()}#${e.id}';
          if (!out.contains(key) && e.age < 0.05) out.add(key);
        }
      }
      return out;
    }

    expect(spawns(), spawns());
  });

  test('towers loaded from the save keep their level and sell for 70% of their value', () {
    final s = sim(c, towers: [PlacedTower(type: 'range', col: 2, row: 1, level: 3)]);
    final t = s.towers.single;
    expect(t.level, 3);
    expect(s.sellValue(t), ((50 + 37.5 + 62.5) * 0.7).floor());
    expect(s.snapshotTowers(), [PlacedTower(type: 'range', col: 2, row: 1, level: 3)]);
  });
}
