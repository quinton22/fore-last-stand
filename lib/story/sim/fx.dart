import '../../sim/vec.dart';

enum FxKind { gib, explosion, lightning, tracer, splash, text, sweet, honk }

/// Short-lived visual effect for the renderer. The simulation never reads these.
class Fx {
  Fx(this.kind, this.points, {this.ttl = 0.4, this.radius = 0, this.colorValue = 0xFFFFFFFF, this.text}) : maxTtl = ttl;

  final FxKind kind;
  final List<V2> points;
  double ttl;
  final double maxTtl;
  final double radius;
  final int colorValue;
  final String? text;

  double get progress => 1 - (ttl / maxTtl).clamp(0.0, 1.0);
}
