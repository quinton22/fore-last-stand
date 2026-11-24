import 'package:flutter_test/flutter_test.dart';
import 'package:fore_last_stand/data/clubs.dart';
import 'package:fore_last_stand/data/enemies.dart';
import 'package:fore_last_stand/data/towers.dart';
import 'package:fore_last_stand/meta/profile.dart';
import 'package:fore_last_stand/meta/progression.dart';
import 'package:fore_last_stand/sim/battle.dart';
import 'package:fore_last_stand/sim/range_lessons.dart';
import 'package:fore_last_stand/sim/vec.dart';

Battle range() => Battle(rangeConfigFor(Profile()));

void main() {
  test('the range has every club, targets, free coins and never ends', () {
    final b = range();
    expect(b.config.bag.toSet(), clubs.map((c) => c.id).toSet());
    b.update(1 / 60);
    expect(b.enemies.where((e) => e.alive), isNotEmpty);
    expect(b.coins, greaterThanOrEqualTo(9999));
    expect(b.foreReady, isTrue);
    for (var i = 0; i < 600; i++) {
      b.update(1 / 60);
    }
    expect(b.finished, isFalse);
    expect(b.holesCleared, 0);
  });

  test('targets respawn when destroyed and never move', () {
    final b = range();
    b.update(1 / 60);
    final start = {for (final e in b.enemies) e.id: (e.pos.x, e.pos.y)};
    for (final e in List.of(b.enemies)) {
      b.damageEnemy(e, 1e6);
    }
    b.update(1 / 60);
    expect(b.enemies.where((e) => e.alive), isNotEmpty);
    for (var i = 0; i < 120; i++) {
      b.update(1 / 60);
    }
    for (final e in b.enemies.where((e) => start.containsKey(e.id))) {
      expect((e.pos.x, e.pos.y), start[e.id]);
    }
  });

  test('damage and swing stats track practice', () {
    final b = range();
    b.update(1 / 60);
    b.damageEnemy(b.enemies.first, 7);
    expect(b.lastHit, 7);
    expect(b.rangeDamage, 7);
    b.beginSwing();
    b.releaseSwing(0, 100);
    expect(b.swings, 1);
    expect(b.clubsSwung, {'driver'});
    b.resetRangeStats();
    expect(b.swings, 0);
    expect(b.rangeDamage, 0);
  });

  test('building on the range is cheap and does not slow time', () {
    final b = range();
    b.update(1 / 60);
    final plot = b.plotAt(const V2(180, 500))!;
    expect(b.placeTower('sniper', plot.$1, plot.$2), isTrue);
    expect(b.slowMo, 0);
    expect(b.placeCost(towerById('sniper')), 55);
  });

  test('every lesson has a title and goals complete only when achieved', () {
    final b = range();
    for (final l in rangeLessons) {
      expect(l.title, isNotEmpty);
      expect(l.body, isNotEmpty);
    }
    final swing = rangeLessons.firstWhere((l) => l.title == 'Swing');
    expect(swing.isDone(b), isFalse);
    b.update(1 / 60);
    b.damageEnemy(b.enemies.first, 1);
    expect(swing.isDone(b), isTrue);
  });

  test('every bestiary animal has a description', () {
    for (final e in bestiaryEntries) {
      expect(enemyDescription(e), isNotEmpty);
    }
  });

  test('tutorialSeen round-trips through json', () {
    final p = Profile()..tutorialSeen.addAll(['welcome', 'range']);
    expect(Profile.fromJson(p.toJson()).tutorialSeen, ['welcome', 'range']);
  });
}
