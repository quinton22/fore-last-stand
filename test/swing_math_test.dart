import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:fore_last_stand/sim/swing_math.dart';
import 'package:fore_last_stand/sim/vec.dart';

void main() {
  test('aim assist nudges toward a nearby target only', () {
    const up = V2(0, -1);
    final nudged = assistAim(up, const V2(0.2, -1), 1);
    expect(nudged.x, greaterThan(0));
    expect(assistAim(up, const V2(1, 0), 1), up, reason: 'too far off');
    expect(assistAim(up, const V2(0.2, -1), 0), up);
  });

  test('sweeping the aim never skips at the edge of the assist cone', () {
    for (final strength in [0.3, 0.6, 1.0]) {
      sweep(strength, (prev, next) {
        expect((next - prev).abs(), lessThan(0.25 * math.pi / 180 * 2.05), reason: 'strength $strength');
        expect(next, greaterThanOrEqualTo(prev), reason: 'aim moves the same way as the finger');
      });
    }
  });
}

void sweep(double strength, void Function(double prev, double next) check) {
  const target = V2(0, -1);
  double? prev;
  for (var deg = -60.0; deg <= 60; deg += 0.25) {
    final a = -math.pi / 2 + deg * math.pi / 180;
    final out = assistAim(V2(math.cos(a), math.sin(a)), target, strength).angle;
    if (prev != null) check(prev, out);
    prev = out;
  }
}
