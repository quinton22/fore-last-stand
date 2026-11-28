import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:fore_last_stand/sim/vec.dart';
import 'package:fore_last_stand/story/content.dart';
import 'package:fore_last_stand/story/sim/layout.dart';

import 'helpers.dart';

/// Runs one enemy alone (no towers, no waves) and records where it walked.
List<V2> walk(StoryContent c, int hole, String id, int seedOffset) {
  final s = sim(c, hole: hole)..teeOff();
  s.enemies.clear();
  for (var i = 0; i < seedOffset; i++) {
    s.rng.nextDouble();
  }
  final e = s.spawnEnemy(id);
  e.abilityTimer = 999;
  final trail = <V2>[e.pos];
  for (var t = 0.0; t < 90 && !e.atBall && e.alive; t += 1 / 30) {
    // Keep only this enemy on the field.
    s.enemies.removeWhere((o) => o != e && o.leader != e);
    s.update(1 / 30);
    trail.add(e.pos);
  }
  expect(e.atBall, isTrue, reason: '$id on hole $hole stuck at ${e.pos}');
  return trail;
}

/// x where a trail crosses [y].
double xAt(List<V2> trail, double y) => trail.firstWhere((p) => p.y >= y, orElse: () => trail.last).x;

void main() {
  late StoryContent c;
  setUpAll(() async => c = await loadContent());

  test('every enemy type reaches the ball on every hole, whatever its path', () {
    for (var hole = 1; hole <= 9; hole++) {
      for (final id in ['goose', 'raccoon', 'gator', 'crow', 'squirrel', 'boar', 'skunk', 'coyote']) {
        for (var k = 0; k < 3; k++) {
          walk(c, hole, id, k * 7);
        }
      }
    }
  });

  test('enemies do not all come single file down the middle', () {
    final y = StoryLayout.teeBox.top - 45;
    final xs = [for (var k = 0; k < 12; k++) xAt(walk(c, 1, 'goose', k * 5), y)];
    final mean = xs.reduce((a, b) => a + b) / xs.length;
    final spread = math.sqrt(xs.map((x) => (x - mean) * (x - mean)).reduce((a, b) => a + b) / xs.length);
    expect(spread, greaterThan(40), reason: 'geese spread across the build zone: $xs');
  });

  test('raccoons and coyotes flank down a side; squirrels weave', () {
    for (final id in ['raccoon', 'coyote']) {
      for (var k = 0; k < 6; k++) {
        final x = xAt(walk(c, 1, id, k * 3), 420);
        expect(x < 60 || x > StoryLayout.width - 60, isTrue, reason: '$id crossed y 420 at x $x');
      }
    }
    final trail = walk(c, 1, 'squirrel', 0).where((p) => p.y < 450).toList();
    var turns = 0;
    for (var i = 2; i < trail.length; i++) {
      final a = trail[i - 1].x - trail[i - 2].x, b = trail[i].x - trail[i - 1].x;
      if (a * b < 0) turns++;
    }
    expect(turns, greaterThan(2), reason: 'a squirrel zigzags');
  });

  test('coyote followers keep beside their leader', () {
    final s = sim(c, hole: 8)..teeOff();
    s.enemies.clear();
    final leader = s.spawnEnemy('coyote', at: const V2(200, 120));
    final pups = s.enemies.where((e) => e.leader == leader).toList();
    expect(pups, hasLength(2));
    for (var i = 0; i < 90; i++) {
      s.update(1 / 30);
    }
    for (final p in pups) {
      expect(p.pos.distanceTo(leader.pos), lessThan(60));
    }
  });
}
