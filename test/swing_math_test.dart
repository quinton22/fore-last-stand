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
}
