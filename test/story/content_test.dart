import 'package:flutter_test/flutter_test.dart';
import 'package:fore_last_stand/sim/vec.dart';
import 'package:fore_last_stand/story/sim/flow_field.dart';
import 'package:fore_last_stand/story/sim/layout.dart';
import 'package:fore_last_stand/story/sim/story_waves.dart';

import 'helpers.dart';

void main() {
  test('content loads: MVP holes 1-9, 18 clubs, 8 towers, 20 perks, 2 caddies, 4 bosses', () async {
    final c = await loadContent();
    final course = c.course(muni);
    expect(course.holeCount, 9, reason: 'playable holes = length of holes.json');
    expect([for (final h in course.holes) h.number], [for (var i = 1; i <= 9; i++) i]);
    expect(course.clubs, hasLength(18));
    expect(c.towers, hasLength(8));
    expect(c.perks, hasLength(20));
    expect(c.caddies, hasLength(2));
    expect(c.bosses, hasLength(4));
    expect(c.rules.rounds.map((r) => r.waves), [3, 4, 5]);
    expect(c.courses.where((x) => !x.available), hasLength(2), reason: 'courses 2 and 3 are not designed yet');
  });

  test('one club is revealed per rank and prices follow the tier table', () async {
    final c = await loadContent();
    final clubs = c.course(muni).clubs;
    expect([for (final x in clubs) x.rank], [for (var r = 1; r <= 18; r++) r]);
    expect(clubs.first.id, 'iron_old');
    expect(c.course(muni).club('wood_old').price, 25);
    var total = 0;
    for (final x in clubs.where((x) => x.rank >= 2 && x.rank <= 11)) {
      total += x.price;
    }
    expect(total, 875);
    for (final x in clubs.where((x) => x.tier == 'special')) {
      expect(x.effect, isNotNull, reason: x.id);
    }
  });

  test('every featured enemy and boss exists, every hole has a final boss', () async {
    final c = await loadContent();
    for (final h in c.course(muni).holes) {
      expect(c.enemies.containsKey(h.featured), isTrue, reason: h.featured);
      expect(c.bosses.any((b) => b.holes.contains(h.number)), isTrue, reason: 'hole ${h.number}');
    }
    expect(c.bossForHole(9).id, 'grizzly_greenskeeper');
    expect(c.bossForHole(1).id, 'goose_king');
  });

  test('every enemy can reach the tee box on every hole', () async {
    final c = await loadContent();
    final r = c.rules;
    for (final h in c.course(muni).holes) {
      final flow = FlowField.build(h.hazards, cell: r.n('pathfinding.cell'), margin: r.n('pathfinding.obstacleMargin'), sandCost: r.n('pathfinding.sandCost'));
      // Every open cell on the spawn edges has a path.
      var openEdges = 0;
      for (var col = 0; col < flow.cols; col++) {
        if (flow.blockedCell(col, 0)) continue;
        openEdges++;
        expect(flow.distanceCell(col, 0).isFinite, isTrue, reason: 'hole ${h.number} top col $col');
      }
      for (var y = StoryLayout.spawnTop + 8; y < r.n('pathfinding.sideSpawnMaxY'); y += 15) {
        for (final x in [8.0, StoryLayout.width - 8]) {
          final p = V2(x, y);
          if (!flow.blockedAt(p)) expect(flow.reachable(p), isTrue, reason: 'hole ${h.number} side $p');
        }
      }
      expect(openEdges, greaterThan(10));
      // Walk a ground enemy along the field from several spawn points.
      for (final start in const [V2(20, 90), V2(195, 90), V2(370, 90), V2(8, 300), V2(382, 300)]) {
        if (flow.blockedAt(start)) continue;
        var p = start;
        for (var i = 0; i < 4000 && p.y < StoryLayout.teeLine; i++) {
          p = p + flow.direction(p) * 2;
        }
        expect(p.y, greaterThanOrEqualTo(StoryLayout.teeLine - 1), reason: 'hole ${h.number} from $start got stuck at $p');
      }
    }
  });

  test('wave budget matches the formula and the newest enemy leads wave 1', () async {
    final c = await loadContent();
    expect(waveBudget(c.rules, hole: 1, round: 1, wave: 1), closeTo(10, 1e-9));
    expect(waveBudget(c.rules, hole: 3, round: 2, wave: 4), closeTo(10 * 1.24 * 1.15 * 1.3, 1e-9));
    expect(waveBudget(c.rules, hole: 1, round: 1, wave: 1, flagsLost: 2), closeTo(13, 1e-9));
    expect(waveRoster(c, muni, hole: 1, round: 1, wave: 1), List.filled(10, 'goose'));
    for (var h = 2; h <= 9; h++) {
      final roster = waveRoster(c, muni, hole: h, round: 1, wave: 1);
      expect(roster.first, newestEnemy(c, h).id, reason: 'hole $h');
      for (final id in roster) {
        expect(c.enemy(id).firstHole, lessThanOrEqualTo(h));
        expect(c.enemy(id).spawnable, isTrue);
      }
    }
    // Seeded: a retry plays the same.
    expect(waveRoster(c, muni, hole: 7, round: 3, wave: 2), waveRoster(c, muni, hole: 7, round: 3, wave: 2));
  });
}
