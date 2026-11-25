import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:fore_last_stand/data/enemies.dart';
import 'package:fore_last_stand/sim/waves.dart';

void main() {
  test('every generated spawn group references a real enemy', () {
    for (var i = 0; i < 20; i++) {
      for (final g in generateHole(i, math.Random(i)).groups) {
        expect(() => enemyById(g.enemyId), returnsNormally, reason: g.enemyId);
      }
    }
  });

  test('schedules are sorted and scale with count but never scale bosses', () {
    final hole = generateHole(8, math.Random(1));
    final s = scheduleHole(hole, math.Random(1), countScale: 2);
    for (var i = 1; i < s.length; i++) {
      expect(s[i].time, greaterThanOrEqualTo(s[i - 1].time));
    }
    expect(s.where((x) => x.enemyId == 'goose_king'), hasLength(1));
    final base = scheduleHole(hole, math.Random(1));
    expect(s.length, greaterThan(base.length));
  });

  test('endless holes grow, have breathers every third and a boss every ninth', () {
    final h1 = generateHole(0, math.Random(1));
    final h8 = generateHole(7, math.Random(1));
    expect(h8.enemyCount, greaterThan(h1.enemyCount));
    expect(generateHole(2, math.Random(1)).breather, isTrue);
    expect(generateHole(8, math.Random(1)).hasBoss, isTrue);
    expect(generateHole(17, math.Random(1)).hasBoss, isTrue);
    expect(generateHole(4, math.Random(1)).hasBoss, isFalse);
  });
}
