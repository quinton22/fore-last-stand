import 'dart:math' as math;

import 'vec.dart';

/// Rotates [dir] toward [toTarget] when it lies within [maxAngle] radians,
/// by [strength] (0..1) of the gap. Used by the aim-assist slider.
V2 assistAim(V2 dir, V2 toTarget, double strength, {double maxAngle = 0.35}) {
  if (strength <= 0 || toTarget.length == 0) return dir;
  var delta = toTarget.angle - dir.angle;
  while (delta > math.pi) {
    delta -= 2 * math.pi;
  }
  while (delta < -math.pi) {
    delta += 2 * math.pi;
  }
  if (delta.abs() > maxAngle) return dir;
  return dir.rotated(delta * strength.clamp(0, 1));
}
