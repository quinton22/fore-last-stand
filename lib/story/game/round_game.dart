import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show HSVColor;

import '../../meta/profile.dart';
import '../../sim/vec.dart';
import '../content.dart';
import '../sim/fx.dart';
import '../sim/layout.dart';
import '../sim/round_sim.dart';

/// Flame layer for a Story round: runs the [RoundSim] and draws the 390 x 844
/// logical canvas. Flutter widgets around it handle HUD, club bar and input.
class RoundGame extends FlameGame {
  RoundGame(this.sim, this.settings);

  final RoundSim sim;
  final Settings settings;

  /// Ticks whenever the HUD should rebuild.
  final ValueNotifier<int> hudTick = ValueNotifier(0);

  /// Drag vector while aiming, in logical units, or null.
  V2? aimDrag;

  /// Plot highlighted by a sheet or a tap.
  (int, int)? selectedPlot;

  /// True while a tower sheet or a draft is open: the round holds still.
  bool frozen = false;

  double _hudAccumulator = 0;
  RoundPhase _lastPhase = RoundPhase.prep;
  double _t = 0;

  @override
  Color backgroundColor() => const Color(0xFF14301A);

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    if (!frozen) sim.update(dt);
    _hudAccumulator += dt;
    if (_hudAccumulator > 0.1 || sim.phase != _lastPhase) {
      _hudAccumulator = 0;
      _lastPhase = sim.phase;
      hudTick.value++;
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final sx = size.x <= 0 ? 1.0 : size.x / StoryLayout.width;
    final sy = size.y <= 0 ? 1.0 : size.y / StoryLayout.height;
    canvas.save();
    canvas.scale(sx, sy);
    if (settings.screenShake && sim.shake > 0) {
      final m = sim.shake * 8;
      canvas.translate(math.sin(_t * 90) * m, math.cos(_t * 77) * m);
    }
    _drawGround(canvas);
    _drawHazards(canvas);
    _drawTeeBox(canvas);
    _drawGas(canvas);
    _drawTowers(canvas);
    _drawPins(canvas);
    _drawEnemies(canvas);
    _drawGolfer(canvas);
    _drawBalls(canvas);
    _drawAim(canvas);
    _drawFx(canvas);
    canvas.restore();
  }

  static Rect _r(Box b) => Rect.fromLTRB(b.left, b.top, b.right, b.bottom);
  static Offset _o(V2 v) => Offset(v.x, v.y);

  // ------------------------------------------------------------------ ground

  void _drawGround(Canvas canvas) {
    canvas.drawRect(_r(StoryLayout.hud), Paint()..color = const Color(0xFF102614));
    canvas.drawRect(_r(StoryLayout.fairway), Paint()..color = const Color(0xFF2E7D32));
    final stripe = Paint()..color = const Color(0xFF388E3C);
    for (var y = StoryLayout.fairway.top; y < StoryLayout.fairway.bottom; y += 60) {
      canvas.drawRect(Rect.fromLTWH(0, y, StoryLayout.width, 30), stripe);
    }
    // Rough around the build zone and the tee where the golfer stands.
    canvas.drawRect(Rect.fromLTRB(0, StoryLayout.fairway.bottom, StoryLayout.width, StoryLayout.clubBar.top), Paint()..color = const Color(0xFF1E5E24));
    canvas.drawOval(Rect.fromCenter(center: _o(StoryLayout.golfer + const V2(0, 4)), width: 120, height: 40), Paint()..color = const Color(0xFF43A047));
    canvas.drawRect(_r(StoryLayout.clubBar), Paint()..color = const Color(0xFF102614));
  }

  void _drawHazards(Canvas canvas) {
    final h = sim.hazards;
    for (final s in h.sand) {
      canvas.drawRRect(RRect.fromRectAndRadius(_r(s), const Radius.circular(16)), Paint()..color = const Color(0xFFE6D29A));
    }
    for (final w in h.water) {
      canvas.drawRRect(RRect.fromRectAndRadius(_r(w), const Radius.circular(18)), Paint()..color = const Color(0xFF29B6F6));
      canvas.drawRRect(
        RRect.fromRectAndRadius(_r(w).deflate(6), const Radius.circular(14)),
        Paint()
          ..style = PaintingStyle.stroke
          ..color = const Color(0x55FFFFFF),
      );
    }
    for (final f in h.fences) {
      canvas.drawRect(_r(f), Paint()..color = const Color(0xFFF5F5F5));
      final post = Paint()..color = const Color(0xFF8D6E63);
      final vertical = f.height > f.width;
      final len = vertical ? f.height : f.width;
      for (var d = 0.0; d <= len; d += 16) {
        final c = vertical ? Offset(f.center.x, f.top + d) : Offset(f.left + d, f.center.y);
        canvas.drawCircle(c, 3, post);
      }
    }
    for (final t in h.trees) {
      canvas.drawCircle(_o(t.center + const V2(3, 4)), t.radius, Paint()..color = const Color(0x44000000));
      canvas.drawCircle(_o(t.center), t.radius, Paint()..color = const Color(0xFF1B5E20));
      canvas.drawCircle(_o(t.center - V2(t.radius * 0.25, t.radius * 0.25)), t.radius * 0.55, Paint()..color = const Color(0xFF2E7D32));
    }
  }

  void _drawTeeBox(Canvas canvas) {
    // The pad under every open plot: 6 x 2 to start, plus front-row plots from Grounds Crew.
    final pad = Paint()..color = const Color(0xFF66BB6A);
    for (var c = 0; c < StoryLayout.plotCols; c++) {
      for (var r = 0; r < StoryLayout.plotRows; r++) {
        if (sim.isPlotOpen(c, r)) canvas.drawRRect(RRect.fromRectAndRadius(_r(StoryLayout.plot(c, r)).inflate(3), const Radius.circular(8)), pad);
      }
    }
    // Sand Trap zones just above the tee box.
    for (final t in sim.towers) {
      if (t.spec.kind != TowerKind.sandTrap) continue;
      final p = StoryLayout.plot(t.col, sim.frontRow(t.col));
      final h = t.spec.stat('zoneHeight');
      canvas.drawRect(Rect.fromLTRB(p.left + 2, p.top - h, p.right - 2, p.top), Paint()..color = const Color(0x88E6D29A));
    }
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x66FFFFFF);
    for (var c = 0; c < StoryLayout.plotCols; c++) {
      for (var r = 0; r < StoryLayout.plotRows; r++) {
        if (!sim.isPlotOpen(c, r)) continue;
        final rect = _r(StoryLayout.plot(c, r)).deflate(2);
        final rr = RRect.fromRectAndRadius(rect, const Radius.circular(6));
        if ((sim.disabledPlots[(c, r)] ?? 0) > 0) canvas.drawRRect(rr, Paint()..color = const Color(0xCC6D4C41));
        if (selectedPlot == (c, r)) canvas.drawRRect(rr, Paint()..color = const Color(0x55FFFFFF));
        canvas.drawRRect(rr, line);
      }
    }
  }

  void _drawGas(Canvas canvas) {
    for (final g in sim.gas) {
      canvas.drawCircle(_o(g.pos), g.radius, Paint()..color = Color.fromRGBO(156, 204, 101, 0.35 * math.min(1, g.time)));
    }
  }

  // ------------------------------------------------------------------ towers

  void _drawTowers(Canvas canvas) {
    const r = StoryLayout.towerRadius;
    for (final t in sim.towers) {
      final sel = selectedPlot == (t.col, t.row);
      final range = sim.rangeOf(t);
      if (sel && range > 0) {
        canvas.drawCircle(_o(t.pos), range, Paint()..color = const Color(0x22FFFFFF));
        canvas.drawCircle(
          _o(t.pos),
          range,
          Paint()
            ..style = PaintingStyle.stroke
            ..color = const Color(0x88FFFFFF),
        );
      }
      if (t.overcharged) canvas.drawCircle(_o(t.pos), r + 5 + math.sin(_t * 20) * 2, Paint()..color = const Color(0x66FFEB3B));
      var color = Color(t.spec.color);
      if (!t.active) color = Color.lerp(color, const Color(0xFF616161), 0.65)!;
      if (t.hitFlash > 0) color = const Color(0xFFFF8A80);
      final rect = Rect.fromCircle(center: _o(t.pos), radius: r);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(r * 0.3)), Paint()..color = color);
      if (t.spec.kind == TowerKind.ripper || t.spec.kind == TowerKind.sprinkler) {
        canvas.save();
        canvas.translate(t.pos.x, t.pos.y);
        canvas.rotate(t.spin);
        final blade = Paint()
          ..color = const Color(0xDDFFFFFF)
          ..strokeWidth = 2.5;
        canvas.drawLine(const Offset(-r, 0), const Offset(r, 0), blade);
        canvas.drawLine(const Offset(0, -r), const Offset(0, r), blade);
        canvas.restore();
      }
      _label(canvas, t.spec.badge, t.pos, 12, const Color(0xFF000000));
      for (var i = 0; i < t.level; i++) {
        canvas.drawCircle(Offset(t.pos.x - r + 4 + i * 7, t.pos.y + r - 4), 2.4, Paint()..color = const Color(0xFFFFFFFF));
      }
      if (!t.active) _label(canvas, t.stun > 0 ? 'zz' : '✕', t.pos - const V2(0, r + 8), 11, const Color(0xFFFFFFFF));
      if (t.hp < t.maxHp) _bar(canvas, t.pos + const V2(0, r + 3), r * 2, t.hp / t.maxHp, const Color(0xFF64DD17));
    }
  }

  // ------------------------------------------------------------------ enemies

  void _drawEnemies(Canvas canvas) {
    for (final e in sim.enemies) {
      if (!e.alive) continue;
      var color = Color(e.spec.color);
      if (e.wetTimer > 0) color = Color.lerp(color, const Color(0xFF4FC3F7), 0.35)!;
      if (e.hitFlash > 0) color = const Color(0xFFFFFFFF);
      if (e.submerged) color = color.withValues(alpha: 0.25);
      final c = _o(e.pos);
      final rad = e.radius;
      if (e.flier) {
        canvas.drawOval(Rect.fromCenter(center: c.translate(0, rad + 10), width: rad * 1.6, height: rad * 0.6), Paint()..color = const Color(0x33000000));
      }
      final paint = Paint()..color = color;
      final outline = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0xCC000000);
      final Path shape;
      switch (e.spec.shape) {
        case EnemyShape.circle:
          shape = Path()..addOval(Rect.fromCircle(center: c, radius: rad));
        case EnemyShape.square:
          shape = Path()..addRRect(RRect.fromRectAndRadius(Rect.fromCircle(center: c, radius: rad), Radius.circular(rad * 0.35)));
        case EnemyShape.triangle:
          shape = Path()
            ..moveTo(c.dx, c.dy + rad)
            ..lineTo(c.dx - rad, c.dy - rad * 0.8)
            ..lineTo(c.dx + rad, c.dy - rad * 0.8)
            ..close();
        case EnemyShape.diamond:
          shape = Path()
            ..moveTo(c.dx, c.dy - rad)
            ..lineTo(c.dx + rad, c.dy)
            ..lineTo(c.dx, c.dy + rad)
            ..lineTo(c.dx - rad, c.dy)
            ..close();
      }
      canvas.drawPath(shape, paint);
      canvas.drawPath(shape, outline);
      final dark = Color(e.spec.color).computeLuminance() > 0.4;
      _label(canvas, e.spec.name[0], e.pos, rad, dark ? const Color(0xFF000000) : const Color(0xFFFFFFFF));
      if (e.boss) {
        final top = c.dy - rad - 2;
        canvas.drawPath(
          Path()
            ..moveTo(c.dx - 12, top)
            ..lineTo(c.dx - 12, top - 10)
            ..lineTo(c.dx - 6, top - 4)
            ..lineTo(c.dx, top - 12)
            ..lineTo(c.dx + 6, top - 4)
            ..lineTo(c.dx + 12, top - 10)
            ..lineTo(c.dx + 12, top)
            ..close(),
          Paint()..color = e.finalBoss ? const Color(0xFFFFC107) : const Color(0xFFB0BEC5),
        );
      }
      if (e.leader != null && e.leader!.alive) {
        canvas.drawCircle(
          c,
          rad + 3,
          Paint()
            ..style = PaintingStyle.stroke
            ..color = const Color(0x88FF8A65),
        );
      }
      if (e.snareTimer > 0) {
        canvas.drawCircle(
          c,
          rad + 3,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = const Color(0xFFE6D29A),
        );
      }
      if (e.burnTimer > 0) {
        canvas.drawCircle(
          c,
          rad + 2,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = const Color(0xFFFF7043),
        );
      }
      if (e.markTimer > 0 || e.sniperMarkTimer > 0) {
        final m = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = const Color(0xFFFF1744);
        canvas.drawCircle(c, rad + 5, m);
        canvas.drawLine(c.translate(-rad - 8, 0), c.translate(rad + 8, 0), m);
        canvas.drawLine(c.translate(0, -rad - 8), c.translate(0, rad + 8), m);
      }
      if (e.stolen > 0) _label(canvas, '\$', e.pos - V2(0, rad + 8), 12, const Color(0xFFFFEB3B));
      if (e.hp < e.maxHp || e.boss) _bar(canvas, e.pos - V2(0, rad + 7), math.max(22, rad * 2), e.hp / e.maxHp, const Color(0xFFE53935));
    }
  }

  // ------------------------------------------------------------------ golfer, pins, balls

  void _drawGolfer(Canvas canvas) {
    const g = StoryLayout.golfer;
    canvas.drawOval(Rect.fromCenter(center: _o(g + const V2(0, 10)), width: 26, height: 8), Paint()..color = const Color(0x44000000));
    canvas.drawCircle(_o(g), 8, Paint()..color = const Color(0xFFFFFFFF));
    canvas.drawCircle(_o(g - const V2(0, 12)), 6, Paint()..color = const Color(0xFFFFCC80));
    canvas.drawRect(Rect.fromCenter(center: _o(g - const V2(0, 17)), width: 14, height: 3), Paint()..color = const Color(0xFFE53935));
    // Cooldown arc for the selected club.
    final s = sim.currentStats;
    final cd = sim.cooldowns.isEmpty ? 0.0 : sim.cooldowns[sim.selectedSlot];
    if (s != null && cd > 0 && sim.playing) {
      final fill = (1 - cd / s.cooldown).clamp(0.0, 1.0);
      final rect = Rect.fromCircle(center: _o(g), radius: 14);
      canvas.drawArc(
        rect,
        -math.pi / 2,
        fill * 2 * math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..color = Color.lerp(const Color(0xFFFF7043), const Color(0xFF76FF03), fill)!,
      );
    }
  }

  void _drawPins(Canvas canvas) {
    for (final p in sim.pins) {
      if (p.ttl < 2 && (p.ttl * 6).floor().isEven) continue;
      final c = _o(p.pos);
      final r = sim.rules.n('overcharge.flagRadius');
      canvas.drawCircle(c, r, Paint()..color = const Color(0xFF000000));
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFFFFEB3B),
      );
      canvas.drawLine(
        c,
        c - const Offset(0, 34),
        Paint()
          ..color = const Color(0xFFFFFFFF)
          ..strokeWidth = 2,
      );
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy - 34)
          ..lineTo(c.dx + 16, c.dy - 28)
          ..lineTo(c.dx, c.dy - 22)
          ..close(),
        Paint()..color = const Color(0xFFE53935),
      );
    }
  }

  void _drawBalls(Canvas canvas) {
    final white = Paint()..color = const Color(0xFFFFFFFF);
    for (final b in sim.balls) {
      if (b.done) continue;
      if (b.isLob) {
        final h = b.height * 60;
        canvas.drawCircle(_o(b.pos), b.radius, Paint()..color = const Color(0x55000000));
        canvas.drawCircle(_o(b.pos - V2(0, h)), b.radius * (1 + b.height * 0.6), white);
        canvas.drawCircle(
          _o(b.lobTarget!),
          b.stats.blastRadius,
          Paint()
            ..style = PaintingStyle.stroke
            ..color = const Color(0x55FFFFFF),
        );
        continue;
      }
      if (b.sweet) {
        canvas.drawLine(
          _o(b.pos),
          _o(b.pos - b.vel.normalized() * 16),
          Paint()
            ..color = const Color(0xAA76FF03)
            ..strokeWidth = b.radius * 1.4
            ..strokeCap = StrokeCap.round,
        );
      }
      canvas.drawCircle(_o(b.pos), b.radius, white);
    }
  }

  void _drawAim(Canvas canvas) {
    final drag = aimDrag;
    if (!sim.aiming || !sim.playing) return;
    const g = StoryLayout.golfer;
    // Sweet Spot band and the shrinking ring.
    final end = sim.rules.n('swing.ringEnd');
    final outer = sim.sweetOuter;
    canvas.drawCircle(
      _o(g),
      (end + outer) / 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = outer - end
        ..color = const Color(0x5576FF03),
    );
    canvas.drawCircle(
      _o(g),
      sim.ringRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = sim.inSweetSpot ? const Color(0xFF76FF03) : const Color(0xDDFFFFFF),
    );
    if (drag == null) return;
    final path = sim.aimPreview(drag.x, drag.y);
    if (path.isEmpty) return;
    final s = sim.currentStats;
    if (s != null && s.blastRadius > 0) {
      canvas.drawCircle(
        _o(path.last),
        s.blastRadius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = const Color(0x99FFFFFF),
      );
    }
    final cooling = sim.cooldowns[sim.selectedSlot] > 0;
    final dot = Paint()..color = cooling ? const Color(0x55FFFFFF) : const Color(0xDDFFFFFF);
    for (var i = 0; i < path.length - 1; i++) {
      final a0 = path[i], a1 = path[i + 1];
      final seg = a1 - a0;
      final n = (seg.length / 12).floor();
      for (var k = 0; k <= n; k++) {
        canvas.drawCircle(_o(a0 + seg * (k / math.max(1, n))), 2, dot);
      }
    }
  }

  // ------------------------------------------------------------------ fx

  void _drawFx(Canvas canvas) {
    for (final f in sim.fx) {
      final p = f.progress;
      final color = Color(f.colorValue);
      switch (f.kind) {
        case FxKind.gib:
          _gibs(canvas, f, p);
        case FxKind.explosion:
          canvas.drawCircle(_o(f.points.first), f.radius * (0.4 + 0.6 * p), Paint()..color = color.withValues(alpha: 0.6 * (1 - p)));
        case FxKind.splash:
        case FxKind.honk:
        case FxKind.sweet:
          canvas.drawCircle(
            _o(f.points.first),
            f.radius * (0.3 + 0.7 * p),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = color.withValues(alpha: (1 - p) * color.a),
          );
        case FxKind.lightning:
          if (f.points.length < 2) break;
          final path = Path()..moveTo(f.points.first.x, f.points.first.y);
          for (var i = 1; i < f.points.length; i++) {
            final a = f.points[i - 1], b = f.points[i];
            final mid = (a + b) / 2 + V2(math.sin(i * 7.0 + _t * 50) * 6, math.cos(i * 5.0 + _t * 40) * 6);
            path
              ..lineTo(mid.x, mid.y)
              ..lineTo(b.x, b.y);
          }
          canvas.drawPath(
            path,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5
              ..color = color.withValues(alpha: 1 - p),
          );
        case FxKind.tracer:
          canvas.drawLine(
            _o(f.points[0]),
            _o(f.points[1]),
            Paint()
              ..strokeWidth = 1.5
              ..color = color.withValues(alpha: 1 - p),
          );
        case FxKind.text:
          _label(canvas, f.text ?? '', f.points.first - V2(0, 20 * p), 16, color.withValues(alpha: 1 - p * p));
      }
    }
  }

  void _gibs(Canvas canvas, Fx f, double p) {
    final gore = settings.gore;
    final rnd = math.Random(f.hashCode);
    final n = gore == GoreLevel.fullSplat ? 14 : 9;
    for (var i = 0; i < n; i++) {
      final a = rnd.nextDouble() * math.pi * 2;
      final d = (8 + rnd.nextDouble() * 22) * p + f.radius * 0.3;
      final Color c = switch (gore) {
        GoreLevel.fullSplat => i.isEven ? const Color(0xFFC62828) : Color(f.colorValue),
        GoreLevel.classic => Color(f.colorValue),
        GoreLevel.squeakyClean => HSVColor.fromAHSV(1, rnd.nextDouble() * 360, 0.7, 1).toColor(),
      };
      canvas.drawCircle(
        Offset(f.points.first.x + math.cos(a) * d, f.points.first.y + math.sin(a) * d),
        2.5 * (1 - p) + 0.5,
        Paint()..color = c.withValues(alpha: 1 - p),
      );
    }
  }

  // ------------------------------------------------------------------ helpers

  void _bar(Canvas canvas, V2 center, double width, double fraction, Color color) {
    final rect = Rect.fromCenter(center: _o(center), width: width, height: 3);
    canvas.drawRect(rect, Paint()..color = const Color(0x88000000));
    canvas.drawRect(Rect.fromLTWH(rect.left, rect.top, width * fraction.clamp(0, 1), 3), Paint()..color = color);
  }

  final Map<String, Paragraph> _labelCache = {};

  void _label(Canvas canvas, String text, V2 at, double size, Color color) {
    final key = '$text|$size|${color.toARGB32()}';
    final para = _labelCache.putIfAbsent(key, () {
      if (_labelCache.length > 300) _labelCache.clear();
      final b = ParagraphBuilder(ParagraphStyle(textAlign: TextAlign.center, fontSize: size, fontWeight: FontWeight.bold))
        ..pushStyle(TextStyle(color: color))
        ..addText(text);
      return b.build()..layout(const ParagraphConstraints(width: 120));
    });
    canvas.drawParagraph(para, Offset(at.x - 60, at.y - para.height / 2));
  }
}
