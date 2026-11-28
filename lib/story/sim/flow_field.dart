import 'dart:math' as math;

import '../../sim/vec.dart';
import '../content.dart';
import 'layout.dart';

/// A flow field over the field (6a.7 Pathfinding): a grid of square cells,
/// built once per hole, that leads ground enemies to the ball. Water,
/// fences and trees block cells; sand costs more. Towers never block.
class FlowField {
  FlowField._(this.cell, this.cols, this.rows, this._blocked, this._cost, this._dist);

  factory FlowField.build(Hazards hazards, {double cell = 15, double margin = 8, double sandCost = 1.4}) {
    final cols = (StoryLayout.width / cell).ceil();
    final rows = ((StoryLayout.fieldBottom - StoryLayout.spawnTop) / cell).ceil();
    final blocked = List<bool>.filled(cols * rows, false);
    final cost = List<double>.filled(cols * rows, 1);
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final p = V2((c + 0.5) * cell, StoryLayout.spawnTop + (r + 0.5) * cell);
        final i = r * cols + c;
        blocked[i] = isObstacle(hazards, p, margin);
        if (hazards.sand.any((s) => s.contains(p))) cost[i] = sandCost;
      }
    }
    final dist = List<double>.filled(cols * rows, double.infinity);
    // Goal: the cells around the ball.
    final queue = _MinHeap();
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final i = r * cols + c;
        final centre = V2((c + 0.5) * cell, StoryLayout.spawnTop + (r + 0.5) * cell);
        if (blocked[i] || centre.distanceTo(StoryLayout.golfer) > cell * 1.5) continue;
        dist[i] = 0;
        queue.push(0, i);
      }
    }
    const dirs = [(1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)];
    while (queue.isNotEmpty) {
      final (d, i) = queue.pop();
      if (d > dist[i]) continue;
      final c = i % cols, r = i ~/ cols;
      for (final (dc, dr) in dirs) {
        final nc = c + dc, nr = r + dr;
        if (nc < 0 || nr < 0 || nc >= cols || nr >= rows) continue;
        final ni = nr * cols + nc;
        if (blocked[ni]) continue;
        // No corner cutting past an obstacle.
        if (dc != 0 && dr != 0 && (blocked[r * cols + nc] || blocked[nr * cols + c])) continue;
        final step = (dc != 0 && dr != 0 ? math.sqrt2 : 1.0) * cost[ni];
        final nd = d + step;
        if (nd < dist[ni]) {
          dist[ni] = nd;
          queue.push(nd, ni);
        }
      }
    }
    return FlowField._(cell, cols, rows, blocked, cost, dist);
  }

  final double cell;
  final int cols;
  final int rows;
  final List<bool> _blocked;
  final List<double> _cost;
  final List<double> _dist;

  /// True if [p] is inside a hazard that blocks ground movement (with [margin]).
  static bool isObstacle(Hazards h, V2 p, double margin) {
    for (final w in h.water) {
      if (_inflate(w, margin).contains(p)) return true;
    }
    for (final f in h.fences) {
      if (_inflate(f, margin).contains(p)) return true;
    }
    for (final t in h.trees) {
      if (t.center.distanceTo(p) < t.radius + margin) return true;
    }
    return false;
  }

  static Box _inflate(Box b, double m) => Box(b.left - m, b.top - m, b.right + m, b.bottom + m);

  (int, int) cellOf(V2 p) => ((p.x / cell).floor().clamp(0, cols - 1), ((p.y - StoryLayout.spawnTop) / cell).floor().clamp(0, rows - 1));

  V2 cellCenter(int c, int r) => V2((c + 0.5) * cell, StoryLayout.spawnTop + (r + 0.5) * cell);

  bool blockedCell(int c, int r) => _blocked[r * cols + c];
  bool blockedAt(V2 p) {
    final (c, r) = cellOf(p);
    return blockedCell(c, r);
  }

  double distanceCell(int c, int r) => _dist[r * cols + c];

  /// Path cost from [p] to the tee box; infinite if it cannot get there.
  double distanceAt(V2 p) {
    final (c, r) = cellOf(p);
    return distanceCell(c, r);
  }

  bool reachable(V2 p) => distanceAt(p).isFinite;

  /// Movement cost of the cell under [p] (sand > 1).
  double costAt(V2 p) {
    final (c, r) = cellOf(p);
    return _cost[r * cols + c];
  }

  /// Unit direction a ground enemy at [p] should walk.
  V2 direction(V2 p) {
    if (p.y < StoryLayout.spawnTop) return const V2(0, 1);
    final (c, r) = cellOf(p);
    if (distanceCell(c, r) == 0 || p.distanceTo(StoryLayout.golfer) < cell * 2) {
      final to = StoryLayout.golfer - p;
      return to.length < 1e-6 ? V2.zero : to.normalized();
    }
    var best = distanceCell(c, r);
    (int, int)? to;
    for (var dr = -1; dr <= 1; dr++) {
      for (var dc = -1; dc <= 1; dc++) {
        if (dc == 0 && dr == 0) continue;
        final nc = c + dc, nr = r + dr;
        if (nc < 0 || nr < 0 || nc >= cols || nr >= rows || blockedCell(nc, nr)) continue;
        if (dc != 0 && dr != 0 && (blockedCell(c + dc, r) || blockedCell(c, r + dr))) continue;
        final d = distanceCell(nc, nr);
        // Inside a blocked cell (knocked there): step to any open neighbour.
        if (d < best || (blockedCell(c, r) && to == null && d.isFinite)) {
          best = d;
          to = (nc, nr);
        }
      }
    }
    if (to == null) {
      // Cell centre or straight down as a last resort.
      final centre = cellCenter(c, r);
      final toCentre = centre - p;
      return toCentre.length > 1 ? toCentre.normalized() : const V2(0, 1);
    }
    return (cellCenter(to.$1, to.$2) - p).normalized();
  }

  /// True if a straight walk from [a] to [b] crosses no blocked cell.
  bool lineClear(V2 a, V2 b) {
    final d = b - a;
    final n = math.max(1, (d.length / (cell / 3)).ceil());
    for (var k = 0; k <= n; k++) {
      final p = a + d * (k / n);
      if (p.y >= StoryLayout.spawnTop && blockedAt(p)) return false;
    }
    return true;
  }
}

class _MinHeap {
  final List<(double, int)> _h = [];

  bool get isNotEmpty => _h.isNotEmpty;

  void push(double d, int i) {
    _h.add((d, i));
    var k = _h.length - 1;
    while (k > 0) {
      final p = (k - 1) ~/ 2;
      if (_h[p].$1 <= _h[k].$1) break;
      final t = _h[p];
      _h[p] = _h[k];
      _h[k] = t;
      k = p;
    }
  }

  (double, int) pop() {
    final top = _h.first;
    final last = _h.removeLast();
    if (_h.isNotEmpty) {
      _h[0] = last;
      var k = 0;
      while (true) {
        final l = 2 * k + 1, r = l + 1;
        var m = k;
        if (l < _h.length && _h[l].$1 < _h[m].$1) m = l;
        if (r < _h.length && _h[r].$1 < _h[m].$1) m = r;
        if (m == k) break;
        final t = _h[m];
        _h[m] = _h[k];
        _h[k] = t;
        k = m;
      }
    }
    return top;
  }
}
