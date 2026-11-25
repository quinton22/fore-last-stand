import 'dart:math' as math;

import '../../sim/entities.dart' show Fx, FxKind;
import '../../sim/swing_math.dart' show assistAim;
import '../../sim/vec.dart';
import '../content.dart';
import '../progression.dart';
import '../save.dart';
import 'flow_field.dart';
import 'layout.dart';
import 'story_waves.dart';

/// One Story Mode round (6a): Prep, then waves with build breaks, then a boss.
/// Pure Dart, so the Flame layer only draws it and forwards input.

enum RoundPhase { prep, wave, buildBreak, revive, won, lost }

class BagClub {
  const BagClub(this.club, this.level);
  final StoryClub club;
  final int level;
}

class RoundSetup {
  RoundSetup({
    required this.content,
    required this.courseId,
    required this.hole,
    required this.round,
    required this.coins,
    required this.towers,
    required this.perks,
    required this.bag,
    required this.unlockedTowers,
    this.roundPerk,
    this.caddieId,
    this.caddieRank = 1,
    this.boost,
    this.greenskeepingTier = 0,
    this.aimAssist = 0,
    this.reviveAvailable = false,
  });

  final StoryContent content;
  final String courseId;
  final StoryHole hole;
  final int round;
  final int coins;
  final List<PlacedTower> towers;

  /// Perks held on this hole, including [roundPerk] if already drafted.
  final List<String> perks;
  final String? roundPerk;
  final List<BagClub?> bag;
  final List<StoryTower> unlockedTowers;
  final String? caddieId;
  final int caddieRank;
  final String? boost;
  final int greenskeepingTier;
  final double aimAssist;

  /// Whether a revive (rewarded ad or Remove Ads) can be offered.
  final bool reviveAvailable;
}

/// Club stats after tier, level, perks and boosts.
class ClubStats {
  ClubStats({
    required this.club,
    required this.damage,
    required this.cooldown,
    required this.speed,
    required this.range,
    required this.pierce,
    required this.bounces,
    required this.blastRadius,
  });

  final StoryClub club;
  final double damage;
  final double cooldown;
  final double speed;
  final double range;
  final int pierce;
  final int bounces;
  final double blastRadius;

  ClubFamily get family => club.family;
  BallMotion get motion => family.motion;
  bool get hitsFliers => family.hitsFliers;
  ClubEffect? get effect => club.effect;
}

class SEnemy {
  SEnemy({
    required this.id,
    required this.spec,
    required this.pos,
    required this.maxHp,
    required this.radius,
    required this.speed,
    required this.damage,
    required this.coins,
    this.boss = false,
    this.bossSpec,
    this.leader,
  }) : hp = maxHp;

  final int id;
  final StoryEnemy spec;
  V2 pos;
  final double maxHp;
  double hp;
  final double radius;
  final double speed;
  final double damage;
  final int coins;

  /// Mini-boss or final boss: immune to knockback, retreats after hitting the tee box.
  final bool boss;

  /// Set for the round 3 final boss.
  final StoryBoss? bossSpec;
  final SEnemy? leader;
  bool removed = false;

  double abilityTimer = 0;
  double slowTimer = 0;
  double slowAmount = 0;
  double wetTimer = 0;
  double burnTimer = 0;
  double burnDps = 0;
  double markTimer = 0;
  double markAmount = 0;
  double sniperMarkTimer = 0;
  double snareTimer = 0;
  double hitFlash = 0;
  double age = 0;
  double submergeTimer = 0;
  double secondAbilityTimer = 0;
  final Set<int> snaredBy = {};

  int stolen = 0;
  bool fleeing = false;
  bool retreating = false;
  bool dived = false;

  double pauseTimer = 0;
  double chargeCooldown = 0;
  V2? chargeDir;

  bool get alive => !removed && hp > 0;
  bool get flier => spec.flier;
  bool get finalBoss => bossSpec != null;
  bool get submerged => submergeTimer > 0;
  bool get targetable => alive && !submerged;
  String get abilityType => spec.ability?.type ?? '';
  String get name => bossSpec?.name ?? (boss ? 'Giant ${spec.name}' : spec.name);
}

class SBall {
  SBall({
    required this.stats,
    required this.pos,
    required this.vel,
    required this.damage,
    required this.pierce,
    required this.bounces,
    required this.distance,
    this.sweet = false,
    this.free = false,
  });

  final ClubStats stats;
  V2 pos;
  V2 vel;
  final double damage;
  int pierce;
  int bounces;

  /// Units of travel left before the ball lands.
  double distance;
  final bool sweet;

  /// Fore! burst balls never break the combo or charge the meter.
  final bool free;
  final double radius = 5;
  bool done = false;
  bool hitSomething = false;
  final Set<int> hitIds = {};

  V2? lobStart;
  V2? lobTarget;
  double lobTime = 0;
  double lobTotal = 0;

  bool get isLob => lobTarget != null;
  bool get rolls => stats.motion == BallMotion.roll;

  /// 0..1 height for drawing lobs and iron arcs.
  double get height {
    if (isLob) {
      final p = lobTotal == 0 ? 1.0 : (lobTime / lobTotal).clamp(0.0, 1.0);
      return 4 * p * (1 - p);
    }
    return 0;
  }
}

class STower {
  STower({required this.id, required this.spec, required this.col, required this.row, required this.level, required this.invested})
    : pos = StoryLayout.plotCenter(col, row);

  final int id;
  final StoryTower spec;
  final int col;
  final int row;
  final V2 pos;
  int level;
  int invested;
  double cooldown = 0;
  double stun = 0;
  double disabled = 0;
  double overcharge = 0;
  bool gassed = false;
  bool plotDisabled = false;
  double spin = 0;

  bool get active => stun <= 0 && disabled <= 0 && !gassed && !plotDisabled;
  bool get overcharged => overcharge > 0;
}

class SPin {
  SPin(this.pos, this.ttl) : maxTtl = ttl;
  final V2 pos;
  double ttl;
  final double maxTtl;
  bool sunk = false;
}

class SGas {
  SGas(this.pos, this.radius, this.time);
  final V2 pos;
  final double radius;
  double time;
}

class RoundSim {
  RoundSim(this.setup)
    : rules = setup.content.rules,
      rng = math.Random(roundSeed(setup.courseId, setup.hole.number, setup.round, 'sim')),
      coins = setup.coins,
      perks = List.of(setup.perks),
      roundPerk = setup.roundPerk,
      caddieId = setup.caddieId,
      caddieRank = setup.caddieRank,
      boost = setup.boost {
    flow = FlowField.build(
      setup.hole.hazards,
      cell: rules.n('pathfinding.cell'),
      margin: rules.n('pathfinding.obstacleMargin'),
      sandCost: rules.n('pathfinding.sandCost'),
    );
    flags = rules.i('teeBox.flags');
    maxHealth = _baseMaxHealth;
    health = maxHealth;
    for (final t in setup.towers) {
      final spec = content.tower(t.type);
      towers.add(STower(id: _nextId++, spec: spec, col: t.col, row: t.row, level: t.level, invested: nominalTowerValue(spec, t.level)));
    }
    setBag(setup.bag);
  }

  final RoundSetup setup;
  final Rules rules;
  final math.Random rng;
  late final FlowField flow;

  StoryContent get content => setup.content;
  StoryHole get hole => setup.hole;
  int get holeNumber => hole.number;
  int get round => setup.round;
  Hazards get hazards => hole.hazards;

  RoundPhase phase = RoundPhase.prep;
  RoundPhase _phaseBeforeRevive = RoundPhase.wave;

  int coins;
  final List<String> perks;
  String? roundPerk;
  String? caddieId;
  int caddieRank;
  String? boost;

  late int flags;
  int flagsLost = 0;
  late double maxHealth;
  late double health;

  /// Current wave, 1-based (0 during Prep).
  int wave = 0;
  int wavesCleared = 0;
  final List<String> _spawnQueue = [];
  bool _bossPending = false;
  double _spawnTimer = 0;
  double breakTimer = 0;

  final List<SEnemy> enemies = [];
  final List<SBall> balls = [];
  final List<STower> towers = [];
  final List<SPin> pins = [];
  final List<SGas> gas = [];
  final List<Fx> fx = [];

  /// Plots disabled by a boss: (col, row) -> seconds left.
  final Map<(int, int), double> disabledPlots = {};

  /// The 3 bag slots; changeable at Prep only.
  List<BagClub?> bag = const [];
  late List<double> cooldowns;
  late int selectedSlot;
  bool aiming = false;
  double aimTime = 0;

  int comboRung = 0;
  int bestRung = 0;
  double foreMeter = 0;
  int _foreBallsLeft = 0;
  int _foreBallsTotal = 0;
  double _foreTimer = 0;
  bool caddieUsed = false;
  bool reviveUsed = false;
  double slowMo = 0;
  double shake = 0;
  double time = 0;

  String? banner;
  double bannerTimer = 0;

  int kills = 0;
  final Map<String, int> killsById = {};
  double _pinTimer = 0;
  int _nextId = 0;

  // ---------------------------------------------------------------- perks

  double perkSum(String effect) {
    var s = 0.0;
    for (final id in perks) {
      final p = content.perk(id);
      if (p.effect == effect) s += p.value;
    }
    return s;
  }

  double perkProduct(String effect) {
    var s = 1.0;
    for (final id in perks) {
      final p = content.perk(id);
      if (p.effect == effect) s *= 1 - p.value;
    }
    return s;
  }

  bool hasPerk(String effect) => perks.any((id) => content.perk(id).effect == effect);

  /// Drafts this round's perk at Prep.
  void pickPerk(String id) {
    if (phase != RoundPhase.prep || roundPerk != null) return;
    roundPerk = id;
    perks.add(id);
  }

  StoryCaddie? get caddie => caddieId == null ? null : content.caddie(caddieId!);
  double get _caddieScale => caddieScale(rules, caddieRank);
  double caddiePassive(String type) {
    final c = caddie;
    return c != null && c.passive == type ? c.passiveValue * _caddieScale : 0;
  }

  // ---------------------------------------------------------------- getters

  bool get finished => phase == RoundPhase.won || phase == RoundPhase.lost;
  bool get live => phase == RoundPhase.wave;
  bool get playing => phase == RoundPhase.wave || phase == RoundPhase.buildBreak;
  int get normalWaves => rules.rounds[round - 1].waves;
  int get totalWaveCount => normalWaves + 1;
  bool get isBossWave => wave == totalWaveCount;
  bool get finalBossRound => rules.rounds[round - 1].finalBoss;
  double get maxFore => rules.n('fore.max');
  bool get foreReady => foreMeter >= maxFore && playing && _foreBallsLeft == 0;
  bool get caddieReady => caddie != null && !caddieUsed && playing;
  int get comboCount => rules.comboNames.length;
  String get comboName => rules.comboNames[comboRung];
  double get comboMultiplier => rules.comboMultipliers[comboRung];
  double get _baseMaxHealth => rules.n('teeBox.health') + rules.wing('greenskeeping').perTier * setup.greenskeepingTier;

  /// Enemies still to come in this wave, plus those on the course.
  int get enemiesLeft => _spawnQueue.length + (_bossPending ? 1 : 0) + enemies.where((e) => e.alive).length;

  List<StoryTower> get unlockedTowers => setup.unlockedTowers;

  // ---------------------------------------------------------------- clubs

  BagClub? get selectedClub => bag.isEmpty ? null : bag[selectedSlot];

  /// Sets the bag (Prep only: never during a round).
  void setBag(List<BagClub?> clubs) {
    if (phase != RoundPhase.prep) return;
    bag = List.of(clubs);
    cooldowns = List.filled(bag.length, 0);
    selectedSlot = math.max(0, bag.indexWhere((b) => b != null));
  }

  ClubStats statsFor(BagClub b) {
    final f = b.club.family;
    final maxLevel = maxClubLevel(rules);
    var damage = f.damage * rules.tierMultiplier(b.club.tier) * (1 + rules.n('tokens.levelDamage') * (b.level - 1));
    damage *= 1 + perkSum('clubDamage');
    if (boost == 'club_damage') damage *= 1 + rules.boost('club_damage').value;
    var cooldown = f.cooldown * perkProduct('clubCooldown');
    if (b.level >= maxLevel) cooldown *= 1 - rules.n('tokens.maxLevelCooldownCut');
    if (towers.any((t) => t.spec.kind == TowerKind.snackShack && t.overcharged && t.active)) {
      cooldown *= 1 - content.towers.firstWhere((t) => t.kind == TowerKind.snackShack).stat('swingCooldown');
    }
    return ClubStats(
      club: b.club,
      damage: damage,
      cooldown: cooldown,
      speed: f.speed,
      range: f.range,
      pierce: f.pierce + perkSum('extraPierce').round(),
      bounces: f.bounces + perkSum('extraBounce').round(),
      blastRadius: f.blastRadius * (1 + perkSum('blastRadius')),
    );
  }

  ClubStats? get currentStats => selectedClub == null ? null : statsFor(selectedClub!);

  void selectSlot(int i) {
    if (i >= 0 && i < bag.length && bag[i] != null) selectedSlot = i;
  }

  // ---------------------------------------------------------------- swing

  double get ringRadius {
    final start = rules.n('swing.ringStart'), end = rules.n('swing.ringEnd'), period = rules.n('swing.ringPeriod');
    return start - (start - end) * ((aimTime % period) / period);
  }

  /// Outer edge of the Sweet Spot band (16-24, wider with a perk).
  double get sweetOuter {
    final end = rules.n('swing.ringEnd');
    return end + (rules.n('swing.sweetOuter') - end) * (1 + perkSum('sweetWidth'));
  }

  bool get inSweetSpot => ringRadius <= sweetOuter + 1e-9;

  /// Power for a drag of [length] units, or null if it cancels.
  double? powerFor(double length) {
    final minDrag = rules.n('swing.minDrag'), maxDrag = rules.n('swing.maxDrag'), minPower = rules.n('swing.minPower');
    if (length < minDrag) return null;
    final t = ((length.clamp(minDrag, maxDrag) - minDrag) / (maxDrag - minDrag)).toDouble();
    return minPower + (1 - minPower) * t;
  }

  void beginAim() {
    aiming = true;
    aimTime = 0;
  }

  void cancelAim() => aiming = false;

  V2 _assisted(V2 dir, ClubStats s) {
    if (setup.aimAssist <= 0) return dir;
    final target = _nearest(StoryLayout.golfer, (e) => e.targetable && (s.hitsFliers || !e.flier));
    return target == null ? dir : assistAim(dir, target.pos - StoryLayout.golfer, setup.aimAssist);
  }

  /// Releases a drag. The ball goes opposite the drag. Returns the balls
  /// launched (empty if the drag cancelled or the club is cooling down).
  List<SBall> release(double dx, double dy) {
    final sweet = inSweetSpot;
    aiming = false;
    final b = selectedClub;
    if (!playing || b == null || cooldowns[selectedSlot] > 0) return const [];
    final len = math.sqrt(dx * dx + dy * dy);
    final power = powerFor(len);
    if (power == null) return const [];
    final s = statsFor(b);
    final dir = _assisted(V2(-dx / len, -dy / len), s);
    cooldowns[selectedSlot] = s.cooldown;
    var damage = s.damage;
    if (sweet) {
      damage *= 1 + rules.n('swing.sweetDamage') + perkSum('sweetDamage');
      shake = 0.2;
      fx.add(Fx(FxKind.sweet, [StoryLayout.golfer], ttl: 0.35, radius: 30, colorValue: 0xFF76FF03));
    }
    final e = s.effect;
    if (e != null && e.type == 'twin') {
      final out = <SBall>[];
      final spread = e.spread * math.pi / 180;
      for (var i = 0; i < e.balls; i++) {
        final a = e.balls == 1 ? 0.0 : -spread / 2 + spread * i / (e.balls - 1);
        out.add(_launch(s, dir.rotated(a), power, damage * e.damage, sweet: sweet));
      }
      return out;
    }
    return [_launch(s, dir, power, damage, sweet: sweet)];
  }

  SBall _launch(ClubStats s, V2 dir, double power, double damage, {bool sweet = false, bool free = false}) {
    final ball = SBall(
      stats: s,
      pos: StoryLayout.golfer,
      vel: dir * s.speed,
      damage: damage,
      pierce: s.pierce + (sweet ? rules.i('swing.sweetPierce') : 0),
      bounces: s.bounces,
      distance: s.range * power,
      sweet: sweet,
      free: free,
    );
    if (s.motion == BallMotion.lob) {
      ball.lobStart = StoryLayout.golfer;
      ball.lobTarget = lobTargetFor(dir, power, s);
      ball.lobTotal = ball.lobTarget!.distanceTo(StoryLayout.golfer) / s.speed;
    }
    balls.add(ball);
    return ball;
  }

  V2 lobTargetFor(V2 dir, double power, ClubStats s) {
    final p = StoryLayout.golfer + dir * (s.range * power);
    return V2(p.x.clamp(0, StoryLayout.width).toDouble(), p.y.clamp(StoryLayout.fairway.top, StoryLayout.fairway.bottom).toDouble());
  }

  /// Dotted preview for a drag: the first leg and one wall bounce, or the lob landing.
  List<V2> aimPreview(double dx, double dy) {
    final b = selectedClub;
    final len = math.sqrt(dx * dx + dy * dy);
    final power = powerFor(len);
    if (b == null || power == null) return const [];
    final s = statsFor(b);
    final dir = _assisted(V2(-dx / len, -dy / len), s);
    if (s.motion == BallMotion.lob) return [StoryLayout.golfer, lobTargetFor(dir, power, s)];
    final points = [StoryLayout.golfer];
    var p = StoryLayout.golfer, d = dir, left = s.range * power;
    for (var bounce = 0; bounce <= (s.bounces > 0 ? 1 : 0) && left > 0; bounce++) {
      var t = double.infinity;
      V2? normal;
      if (d.x < 0) {
        final tx = -p.x / d.x;
        if (tx < t) (t, normal) = (tx, const V2(1, 0));
      } else if (d.x > 0) {
        final tx = (StoryLayout.width - p.x) / d.x;
        if (tx < t) (t, normal) = (tx, const V2(-1, 0));
      }
      if (d.y < 0) {
        final ty = (StoryLayout.fairway.top - p.y) / d.y;
        if (ty < t) (t, normal) = (ty, const V2(0, 1));
      }
      if (t >= left || normal == null) {
        points.add(p + d * left);
        break;
      }
      p = p + d * t;
      points.add(p);
      left -= t;
      d = d.reflect(normal);
    }
    return points;
  }

  // ---------------------------------------------------------------- Fore! and caddie

  bool triggerFore() {
    if (!foreReady || selectedClub == null) return false;
    foreMeter = 0;
    _foreBallsTotal = rules.i('fore.balls') + perkSum('foreBalls').round();
    _foreBallsLeft = _foreBallsTotal;
    _foreTimer = 0;
    shake = 0.3;
    _say('FORE!');
    return true;
  }

  void _updateFore(double dt) {
    if (_foreBallsLeft <= 0) return;
    _foreTimer -= dt;
    final b = selectedClub;
    if (b == null) {
      _foreBallsLeft = 0;
      return;
    }
    final s = statsFor(b);
    final interval = rules.n('fore.seconds') / _foreBallsTotal;
    final fan = rules.n('fore.fanDegrees') * math.pi / 180;
    final damage = s.damage * rules.n('fore.damage') * (1 + caddiePassive('foreDamage'));
    while (_foreBallsLeft > 0 && _foreTimer <= 0) {
      final i = _foreBallsTotal - _foreBallsLeft;
      final a = -math.pi / 2 - fan / 2 + fan * (_foreBallsTotal == 1 ? 0.5 : i / (_foreBallsTotal - 1));
      _launch(s, V2(math.cos(a), math.sin(a)), 1, damage, free: true);
      _foreBallsLeft--;
      _foreTimer += interval;
    }
  }

  bool get foreFiring => _foreBallsLeft > 0;

  void _chargeFore(double amount) => foreMeter = math.min(maxFore, foreMeter + amount * (1 + perkSum('foreCharge')));

  bool useCaddie() {
    final c = caddie;
    if (c == null || !caddieReady) return false;
    caddieUsed = true;
    switch (c.active) {
      case 'foreMeter':
        foreMeter = math.min(maxFore, foreMeter + c.activeValue * _caddieScale);
      case 'mark':
        SEnemy? best;
        for (final e in enemies) {
          if (!e.targetable) continue;
          if (best == null || e.hp > best.hp) best = e;
        }
        if (best != null) {
          best.markTimer = c.activeSeconds;
          best.markAmount = c.activeValue * _caddieScale;
          fx.add(Fx(FxKind.tracer, [StoryLayout.golfer, best.pos], ttl: 0.3, colorValue: c.color));
        }
    }
    _say(c.activeName);
    return true;
  }

  // ---------------------------------------------------------------- round flow

  /// Leaves Prep and starts wave 1. Perk "coins now" and boosts apply here, so
  /// the Tee Off snapshot never includes them.
  void teeOff() {
    if (phase != RoundPhase.prep) return;
    if (roundPerk != null && content.perk(roundPerk!).effect == 'coinsNow') coins += content.perk(roundPerk!).value.round();
    if (boost == 'coins') coins += rules.boost('coins').value.round();
    if (boost == 'full_fore') foreMeter = maxFore;
    maxHealth = _baseMaxHealth + perkSum('teeHealth');
    health = maxHealth;
    _pinTimer = rules.n('overcharge.flagMinGap');
    _startWave(1);
  }

  void _startWave(int n) {
    wave = n;
    _spawnQueue.clear();
    _bossPending = false;
    if (n <= normalWaves) {
      _spawnQueue.addAll(waveRoster(content, setup.courseId, hole: holeNumber, round: round, wave: n, flagsLost: flagsLost));
      _say('Wave $n of $normalWaves');
    } else {
      _bossPending = true;
      _say(finalBossRound ? content.bossForHole(holeNumber).name : 'Mini-boss: Giant ${content.enemy(hole.featured).name}');
    }
    _spawnTimer = 0;
    phase = RoundPhase.wave;
  }

  void skipBreak() {
    if (phase == RoundPhase.buildBreak) breakTimer = 0;
  }

  void _waveCleared() {
    wavesCleared++;
    pins.clear();
    if (wave >= totalWaveCount) {
      phase = RoundPhase.won;
      _say(finalBossRound ? 'Hole ${hole.number} beaten!' : 'Round won!');
      return;
    }
    final heal = perkSum('waveHeal');
    if (heal > 0) health = math.min(maxHealth, health + heal);
    breakTimer = rules.n('waves.buildBreak');
    phase = RoundPhase.buildBreak;
  }

  void acceptRevive() {
    if (phase != RoundPhase.revive) return;
    reviveUsed = true;
    flags = 1;
    health = maxHealth;
    final clear = rules.n('ads.reviveClearRadius');
    for (final e in enemies) {
      if (!e.alive) continue;
      if (e.boss) {
        e.pos = V2(e.pos.x, StoryLayout.fairway.top + e.radius + 4);
        e.retreating = false;
      } else if (StoryLayout.distanceToTeeBox(e.pos) <= clear) {
        e.removed = true;
        fx.add(Fx(FxKind.gib, [e.pos], ttl: 0.5, radius: e.radius, colorValue: e.spec.color));
      }
    }
    enemies.removeWhere((e) => !e.alive);
    phase = _phaseBeforeRevive;
    _say('Revived!');
  }

  void declineRevive() {
    if (phase == RoundPhase.revive) phase = RoundPhase.lost;
  }

  RoundOutcome outcome() => RoundOutcome(
    won: phase == RoundPhase.won,
    wavesCleared: wavesCleared,
    totalWaves: totalWaveCount,
    flagsLeft: flags,
    endCoins: coins,
    endTowers: snapshotTowers(),
    kills: Map.of(killsById),
  );

  List<PlacedTower> snapshotTowers() => [for (final t in towers) PlacedTower(type: t.spec.id, col: t.col, row: t.row, level: t.level)];

  void _say(String text) {
    banner = text;
    bannerTimer = 2;
  }

  // ---------------------------------------------------------------- towers

  bool get canBuild => phase == RoundPhase.prep || playing;
  double get _costMultiplier => (1 - perkSum('towerCost')).clamp(0.2, 1.0) * (live ? rules.n('coins.liveCostMultiplier') : 1);

  /// Coins a tower is worth at [level] at normal prices (no discounts).
  int nominalTowerValue(StoryTower spec, int level) {
    var v = spec.cost.toDouble();
    final costs = rules.list('towers.levelCosts');
    for (var l = 1; l < level && l - 1 < costs.length; l++) {
      v += spec.cost * costs[l - 1];
    }
    return v.round();
  }

  int get maxTowerLevel => rules.list('towers.levelCosts').length + 1;
  int placeCost(StoryTower spec) => (spec.cost * _costMultiplier).round();

  int? upgradeCost(STower t) {
    final costs = rules.list('towers.levelCosts');
    if (t.level - 1 >= costs.length) return null;
    return (t.spec.cost * costs[t.level - 1] * _costMultiplier).round();
  }

  int sellValue(STower t) => (t.invested * rules.n('coins.sellRefund')).floor();

  STower? towerAt(int col, int row) {
    for (final t in towers) {
      if (t.col == col && t.row == row) return t;
    }
    return null;
  }

  bool isUnlocked(StoryTower spec) => setup.unlockedTowers.any((t) => t.id == spec.id);

  bool canPlace(StoryTower spec, int col, int row) =>
      canBuild && isUnlocked(spec) && towerAt(col, row) == null && (!spec.frontRowOnly || row == 0) && coins >= placeCost(spec);

  STower? placeTower(String id, int col, int row) {
    final spec = content.tower(id);
    if (!canPlace(spec, col, row)) return null;
    final cost = placeCost(spec);
    coins -= cost;
    final t = STower(id: _nextId++, spec: spec, col: col, row: row, level: 1, invested: cost);
    towers.add(t);
    if (live) slowMo = rules.n('coins.slowMoSeconds');
    return t;
  }

  bool upgradeTower(STower t) {
    final cost = upgradeCost(t);
    if (!canBuild || cost == null || coins < cost) return false;
    coins -= cost;
    t.invested += cost;
    t.level++;
    if (live) slowMo = rules.n('coins.slowMoSeconds');
    return true;
  }

  int sellTower(STower t) {
    if (!canBuild || !towers.contains(t)) return 0;
    final v = sellValue(t);
    coins += v;
    towers.remove(t);
    return v;
  }

  double _levelMult(STower t) => 1 + rules.n('towers.levelStrength') * (t.level - 1);
  double towerRange(STower t, double base) => base * (1 + perkSum('towerRange'));

  /// Range ring for the renderer (0 = no ring).
  double rangeOf(STower t) => switch (t.spec.kind) {
    TowerKind.ballMachine || TowerKind.cartCannon || TowerKind.teeTesla => towerRange(t, t.spec.stat('range')),
    TowerKind.sprinkler => towerRange(t, t.spec.stat('radius')) * (t.overcharged ? 1.5 : 1),
    _ => 0,
  };

  double _rateMult(STower t) {
    var m = 1.0;
    for (final o in towers) {
      if (o.spec.kind != TowerKind.snackShack || !o.active || o == t) continue;
      if ((o.col - t.col).abs() + (o.row - t.row).abs() == 1) m += o.spec.stat('adjacentRate') * _levelMult(o);
    }
    return m;
  }

  /// The targetable enemy nearest the tee box within [range] of [from].
  SEnemy? _nearestTee(V2 from, double range, {bool fliers = true}) {
    SEnemy? best;
    var bestD = double.infinity;
    for (final e in enemies) {
      if (!e.targetable || (!fliers && e.flier) || e.pos.distanceTo(from) > range) continue;
      final d = StoryLayout.teeLine - e.pos.y;
      if (d < bestD) {
        bestD = d;
        best = e;
      }
    }
    return best;
  }

  void _updateTowers(double dt) {
    final dmgPerk = 1 + perkSum('towerDamage');
    for (final t in towers) {
      t.stun = math.max(0, t.stun - dt);
      t.disabled = math.max(0, t.disabled - dt);
      t.overcharge = math.max(0, t.overcharge - dt);
      t.gassed = gas.any((g) => g.pos.distanceTo(t.pos) < g.radius);
      t.plotDisabled = (disabledPlots[(t.col, t.row)] ?? 0) > 0;
      if (!t.active || phase != RoundPhase.wave) continue;
      final lvl = _levelMult(t);
      final over = t.overcharged;
      final s = t.spec;
      var rate = _rateMult(t);
      if (over && (s.kind == TowerKind.ballMachine || s.kind == TowerKind.cartCannon)) rate *= 2;
      t.cooldown -= dt * rate;
      switch (s.kind) {
        case TowerKind.ballMachine:
          if (t.cooldown > 0) break;
          final e = _nearestTee(t.pos, towerRange(t, s.stat('range')));
          if (e == null) break;
          t.cooldown = s.stat('interval');
          fx.add(Fx(FxKind.tracer, [t.pos, e.pos], ttl: 0.08, colorValue: 0xFFFFFFFF));
          damageEnemy(e, s.stat('damage') * lvl * dmgPerk);
        case TowerKind.sprinkler:
          t.spin += dt * 3;
          if (t.cooldown > 0) break;
          t.cooldown = 0.5;
          final radius = towerRange(t, s.stat('radius')) * (over ? 1.5 : 1);
          if (hasPerk('sprinklerHeal')) health = math.min(maxHealth, health + perkSum('sprinklerHeal') * 0.5);
          fx.add(Fx(FxKind.splash, [t.pos], ttl: 0.4, radius: radius, colorValue: 0x554FC3F7));
          for (final e in enemies) {
            if (!e.targetable || e.flier || e.pos.distanceTo(t.pos) > radius) continue;
            e.wetTimer = s.stat('wet');
            _slow(e, math.min(0.6, s.stat('slow') * lvl), 0.6);
          }
        case TowerKind.sandTrap:
          final box = StoryLayout.plot(t.col, 0);
          final top = StoryLayout.teeLine - s.stat('zoneHeight');
          final snare = (over ? 2 : 1) * s.stat('snare') * lvl;
          for (final e in enemies) {
            if (!e.targetable || e.flier || e.boss || e.snaredBy.contains(t.id)) continue;
            if (e.pos.x < box.left || e.pos.x > box.right || e.pos.y < top || e.pos.y > StoryLayout.teeLine) continue;
            e.snaredBy.add(t.id);
            e.snareTimer = math.max(e.snareTimer, snare);
          }
        case TowerKind.cartCannon:
          if (t.cooldown > 0) break;
          final e = _nearestTee(t.pos, towerRange(t, s.stat('range')), fliers: false);
          if (e == null) break;
          t.cooldown = s.stat('interval');
          final at = e.pos;
          final blast = s.stat('blast') * (1 + perkSum('blastRadius'));
          fx.add(Fx(FxKind.explosion, [at], ttl: 0.35, radius: blast, colorValue: 0xFFCE93D8));
          for (final o in List.of(enemies)) {
            if (o.targetable && !o.flier && o.pos.distanceTo(at) < blast + o.radius) damageEnemy(o, s.stat('damage') * lvl * dmgPerk);
          }
        case TowerKind.teeTesla:
          if (t.cooldown > 0) break;
          final first = _nearestTee(t.pos, towerRange(t, s.stat('range')));
          if (first == null) break;
          t.cooldown = s.stat('interval');
          final jumps = (over ? s.stat('overchargeChains') : s.stat('chains')).round();
          final chain = <SEnemy>[first];
          var cur = first;
          while (chain.length < jumps) {
            final next = _nearest(cur.pos, (e) => e.targetable && !chain.contains(e), range: s.stat('chainRange'));
            if (next == null) break;
            chain.add(next);
            cur = next;
          }
          fx.add(Fx(FxKind.lightning, [t.pos, ...chain.map((e) => e.pos)], ttl: 0.2, colorValue: 0xFFFFF176));
          for (final e in chain) {
            damageEnemy(e, s.stat('damage') * lvl * dmgPerk, wetBonus: s.stat('wetBonus'));
          }
        case TowerKind.ripper:
          t.spin += dt * (over ? 24 : 10);
          final box = StoryLayout.plot(t.col, t.row);
          final reach = s.stat('reach');
          final dps = s.stat('dps') * lvl * dmgPerk * (over ? 2 : 1);
          for (final e in List.of(enemies)) {
            if (!e.targetable || e.flier) continue;
            if (e.pos.x < box.left - e.radius || e.pos.x > box.right + e.radius) continue;
            if (e.pos.y < StoryLayout.teeLine - reach - e.radius) continue;
            damageEnemy(e, dps * dt, quiet: true);
            e.hitFlash = 0.05;
          }
        case TowerKind.sniper:
          if (t.cooldown > 0) break;
          SEnemy? best;
          int rank(SEnemy e) => e.boss ? 2 : (e.abilityType == 'pack' ? 1 : 0);
          for (final e in enemies) {
            if (!e.targetable) continue;
            if (best == null || rank(e) > rank(best) || (rank(e) == rank(best) && e.hp > best.hp)) best = e;
          }
          if (best == null) break;
          t.cooldown = s.stat('interval');
          if (over) {
            best.sniperMarkTimer = s.stat('markSeconds');
          }
          fx.add(Fx(FxKind.tracer, [t.pos, best.pos], ttl: 0.15, colorValue: 0xFFA5D6A7));
          damageEnemy(best, s.stat('damage') * lvl * dmgPerk);
        case TowerKind.snackShack:
          health = math.min(maxHealth, health + s.stat('heal') * lvl * dt);
      }
    }
  }

  void _overchargeAll() {
    final seconds = rules.n('overcharge.seconds') + perkSum('overchargeSeconds');
    for (final t in towers) {
      t.overcharge = math.max(t.overcharge, seconds);
      if (t.spec.kind == TowerKind.cartCannon) t.cooldown = 0;
      fx.add(Fx(FxKind.sweet, [t.pos], ttl: 0.3, radius: 30, colorValue: 0xFFFFEB3B));
    }
    _say('Towers overcharged!');
  }

  void _updatePins(double dt) {
    for (final p in pins) {
      p.ttl -= dt;
    }
    pins.removeWhere((p) => p.ttl <= 0 || p.sunk);
    if (phase != RoundPhase.wave) return;
    _pinTimer -= dt;
    if (_pinTimer > 0) return;
    final minGap = rules.n('overcharge.flagMinGap'), maxGap = rules.n('overcharge.flagMaxGap');
    _pinTimer = minGap + rng.nextDouble() * (maxGap - minGap);
    if (pins.isNotEmpty || towers.isEmpty) return;
    for (var tries = 0; tries < 20; tries++) {
      final p = V2(40 + rng.nextDouble() * (StoryLayout.width - 80), 140 + rng.nextDouble() * 320);
      if (FlowField.isObstacle(hazards, p, 12) || hazards.sand.any((s) => s.contains(p))) continue;
      pins.add(SPin(p, rules.n('overcharge.flagLifetime')));
      return;
    }
  }

  bool _checkPins(V2 at, double radius, {double reach = 0.4}) {
    final r = rules.n('overcharge.flagRadius');
    for (final p in pins) {
      if (p.sunk || p.pos.distanceTo(at) > r + radius * reach) continue;
      p.sunk = true;
      fx.add(Fx(FxKind.sweet, [p.pos], ttl: 0.4, radius: 26, colorValue: 0xFFFFEB3B));
      _overchargeAll();
      return true;
    }
    return false;
  }

  // ---------------------------------------------------------------- enemies

  void _slow(SEnemy e, double amount, double seconds) {
    if (e.spec.immuneSlow) return;
    e.slowTimer = math.max(e.slowTimer, seconds);
    e.slowAmount = e.slowTimer > 0 ? math.max(e.slowAmount, amount) : amount;
  }

  SEnemy? _nearest(V2 from, bool Function(SEnemy) ok, {double range = double.infinity}) {
    SEnemy? best;
    var bestD = range;
    for (final e in enemies) {
      if (!ok(e)) continue;
      final d = e.pos.distanceTo(from);
      if (d < bestD) {
        bestD = d;
        best = e;
      }
    }
    return best;
  }

  STower? _nearestTower(V2 from) {
    STower? best;
    var bestD = double.infinity;
    for (final t in towers) {
      final d = t.pos.distanceTo(from);
      if (d < bestD) {
        bestD = d;
        best = t;
      }
    }
    return best;
  }

  double get _hpScale => 1 + rules.n('waves.hpPerHole') * (holeNumber - 1);

  V2 _edgePoint(double radius) {
    final sideMax = rules.n('pathfinding.sideSpawnMaxY');
    for (var tries = 0; tries < 40; tries++) {
      final V2 p;
      if (rng.nextBool()) {
        p = V2(radius + 4 + rng.nextDouble() * (StoryLayout.width - 2 * radius - 8), StoryLayout.spawnTop + radius + 1);
      } else {
        final x = rng.nextBool() ? radius + 1 : StoryLayout.width - radius - 1;
        p = V2(x, StoryLayout.spawnTop + radius + rng.nextDouble() * (sideMax - StoryLayout.spawnTop - radius));
      }
      if (!flow.blockedAt(p) && flow.reachable(p)) return p;
    }
    return V2(StoryLayout.width / 2, StoryLayout.spawnTop + radius + 1);
  }

  /// A point just outside a water hazard's edge (gators).
  V2? _waterPoint(double radius) {
    if (hazards.water.isEmpty) return null;
    final margin = rules.n('pathfinding.obstacleMargin') + radius + 2;
    for (var tries = 0; tries < 40; tries++) {
      final w = hazards.water[rng.nextInt(hazards.water.length)];
      final V2 p;
      switch (rng.nextInt(4)) {
        case 0:
          p = V2(w.left + rng.nextDouble() * w.width, w.top - margin);
        case 1:
          p = V2(w.left + rng.nextDouble() * w.width, w.bottom + margin);
        case 2:
          p = V2(w.left - margin, w.top + rng.nextDouble() * w.height);
        default:
          p = V2(w.right + margin, w.top + rng.nextDouble() * w.height);
      }
      if (p.x < radius || p.x > StoryLayout.width - radius || p.y < StoryLayout.spawnTop + radius || p.y > StoryLayout.teeLine - 60) continue;
      if (!flow.blockedAt(p) && flow.reachable(p)) return p;
    }
    return null;
  }

  SEnemy spawnEnemy(String id, {V2? at, SEnemy? leader, bool mini = false}) {
    final spec = content.enemy(id);
    final r = rules;
    final size = mini ? r.n('miniBoss.size') : 1.0;
    final radius = spec.radius * size;
    final pos = at ?? (spec.spawnFromWater ? _waterPoint(radius) : null) ?? _edgePoint(radius);
    final e = SEnemy(
      id: _nextId++,
      spec: spec,
      pos: pos,
      maxHp: spec.hp * _hpScale * (mini ? r.n('miniBoss.hp') : 1),
      radius: radius,
      speed: spec.speed,
      damage: spec.damage * (mini ? r.n('miniBoss.damage') : 1),
      coins: (spec.coins * (mini ? r.n('miniBoss.coins') : 1)).round(),
      boss: mini,
      leader: leader,
    );
    e.abilityTimer = spec.ability?.every ?? 0;
    enemies.add(e);
    final a = spec.ability;
    if (a != null && a.type == 'pack' && a.follower != null) {
      for (var i = 0; i < a.followers; i++) {
        final offset = V2((i == 0 ? -1 : 1) * (radius + 10), -6);
        var p = pos + offset;
        if (flow.blockedAt(p) || p.x < 0 || p.x > StoryLayout.width) p = pos;
        spawnEnemy(a.follower!, at: p, leader: e);
      }
    }
    return e;
  }

  SEnemy spawnFinalBoss() {
    final b = content.bossForHole(holeNumber);
    final r = rules;
    final radius = r.n('finalBoss.radius');
    final spec = StoryEnemy(
      id: b.id,
      name: b.name,
      hp: b.hp,
      speed: r.n('finalBoss.speed'),
      damage: r.n('finalBoss.damage'),
      coins: r.i('finalBoss.coins'),
      cost: 0,
      firstHole: 1,
      radius: radius,
      color: b.color,
      shape: EnemyShape.circle,
      spawnable: false,
    );
    final e = SEnemy(
      id: _nextId++,
      spec: spec,
      pos: V2(StoryLayout.width / 2, StoryLayout.spawnTop + radius + 1),
      maxHp: b.hp * (1 + r.n('finalBoss.hpPerHole') * (holeNumber - 1)) * hole.bossHpMultiplier,
      radius: radius,
      speed: spec.speed,
      damage: spec.damage,
      coins: spec.coins,
      boss: true,
      bossSpec: b,
    );
    if (flow.blockedAt(e.pos)) e.pos = _edgePoint(radius);
    e.abilityTimer = b.ability.every;
    e.secondAbilityTimer = hole.bossSummonBelowHalf?.every ?? 0;
    enemies.add(e);
    return e;
  }

  void _spawnDue(double dt) {
    if (phase != RoundPhase.wave) return;
    _spawnTimer -= dt;
    if (_spawnTimer > 0) return;
    if (_bossPending) {
      _bossPending = false;
      if (finalBossRound) {
        spawnFinalBoss();
      } else {
        spawnEnemy(hole.featured, mini: true);
      }
      _spawnTimer = rules.n('waves.spawnInterval');
      return;
    }
    if (_spawnQueue.isEmpty) return;
    spawnEnemy(_spawnQueue.removeAt(0));
    _spawnTimer = rules.n('waves.spawnInterval');
  }

  void _updateEnemies(double dt) {
    for (final e in List.of(enemies)) {
      if (finished || phase == RoundPhase.revive) return;
      if (!e.alive) continue;
      e.age += dt;
      e.hitFlash = math.max(0, e.hitFlash - dt);
      e.markTimer = math.max(0, e.markTimer - dt);
      e.sniperMarkTimer = math.max(0, e.sniperMarkTimer - dt);
      e.wetTimer = math.max(0, e.wetTimer - dt);
      e.slowTimer = math.max(0, e.slowTimer - dt);
      if (e.slowTimer <= 0) e.slowAmount = 0;
      e.snareTimer = math.max(0, e.snareTimer - dt);
      e.submergeTimer = math.max(0, e.submergeTimer - dt);
      if (e.burnTimer > 0) {
        e.burnTimer -= dt;
        damageEnemy(e, e.burnDps * dt, quiet: true);
        if (!e.alive) continue;
      }
      _ability(e, dt);
      if (!e.alive) continue;
      _move(e, dt);
    }
  }

  void _ability(SEnemy e, double dt) {
    e.abilityTimer -= dt;
    final b = e.bossSpec;
    if (b != null) {
      _bossAbility(e, b.ability, dt);
      final extra = hole.bossSummonBelowHalf;
      if (extra != null && e.hp < e.maxHp / 2) {
        e.secondAbilityTimer -= dt;
        if (e.secondAbilityTimer <= 0) {
          e.secondAbilityTimer = extra.every;
          _summon(e, extra.enemy ?? 'goose', extra.count);
        }
      }
      return;
    }
    final a = e.spec.ability;
    if (a == null || a.type != 'honk' || e.abilityTimer > 0) return;
    e.abilityTimer = a.every;
    final near = towers.where((t) => t.pos.distanceTo(e.pos) < a.radius).toList();
    for (final t in near) {
      t.stun = math.max(t.stun, a.stun);
    }
    fx.add(Fx(FxKind.honk, [e.pos], ttl: 0.5, radius: a.radius, colorValue: 0xFFFFFFFF));
  }

  void _bossAbility(SEnemy e, BossAbility a, double dt) {
    if (e.abilityTimer > 0) return;
    e.abilityTimer = a.every;
    switch (a.type) {
      case 'summon':
        _summon(e, a.enemy ?? 'goose', a.count);
      case 'submerge':
        e.submergeTimer = a.seconds;
        fx.add(Fx(FxKind.splash, [e.pos], ttl: 0.5, radius: e.radius * 2, colorValue: 0xFF29B6F6));
      case 'disablePlots':
        final occupied = [for (final t in towers) (t.col, t.row)]..shuffle(rng);
        final empty = [
          for (var c = 0; c < StoryLayout.plotCols; c++)
            for (var r = 0; r < StoryLayout.plotRows; r++)
              if (towerAt(c, r) == null) (c, r),
        ]..shuffle(rng);
        final picks = [...occupied, ...empty].take(a.count);
        for (final p in picks) {
          disabledPlots[p] = a.seconds;
          fx.add(Fx(FxKind.explosion, [StoryLayout.plotCenter(p.$1, p.$2)], ttl: 0.5, radius: 30, colorValue: 0xFF8D6E63));
        }
    }
  }

  void _summon(SEnemy e, String id, int n) {
    for (var i = 0; i < n; i++) {
      var p = e.pos + V2((i - (n - 1) / 2) * 26, e.radius + 6);
      if (flow.blockedAt(p) || p.x < 8 || p.x > StoryLayout.width - 8) p = e.pos;
      spawnEnemy(id, at: p);
    }
    fx.add(Fx(FxKind.honk, [e.pos], ttl: 0.6, radius: 60, colorValue: e.spec.color));
  }

  double _speedOf(SEnemy e) {
    if (e.snareTimer > 0) return 0;
    var s = e.speed * (1 - perkSum('enemySlow'));
    final leader = e.leader;
    if (leader != null && leader.alive) s *= 1 + (leader.spec.ability?.speedBonus ?? 0);
    if (!e.flier && hazards.sand.any((b) => b.contains(e.pos))) s *= 1 - rules.n('hazards.sandSlow');
    if (!e.spec.immuneSlow && e.slowTimer > 0) s *= 1 - e.slowAmount;
    return s;
  }

  V2 _teeGoal(V2 p) => V2(p.x.clamp(StoryLayout.teeBox.left + 8, StoryLayout.teeBox.right - 8).toDouble(), StoryLayout.teeLine);

  void _move(SEnemy e, double dt) {
    // Bosses walk back to the top after hitting the tee box.
    if (e.retreating) {
      e.pos = e.pos + V2(0, -math.max(60, e.speed * 3) * dt);
      if (e.pos.y <= StoryLayout.spawnTop + e.radius + 4) e.retreating = false;
      return;
    }
    if (e.fleeing) {
      e.pos = e.pos + V2(0, -e.speed * 1.3 * dt);
      if (e.pos.y < StoryLayout.spawnTop - e.radius) e.removed = true;
      return;
    }
    final speed = _speedOf(e);
    final type = e.abilityType;
    if (e.flier) {
      V2 target = _teeGoal(e.pos);
      final tower = type == 'dive' && !e.dived ? _nearestTower(e.pos) : null;
      if (tower != null) target = tower.pos;
      final to = target - e.pos;
      if (to.length > 1) e.pos = e.pos + to.normalized() * math.min(to.length, speed * dt);
      if (tower != null && e.pos.distanceTo(tower.pos) < e.radius + 18) {
        tower.disabled = math.max(tower.disabled, e.spec.ability!.disable);
        e.dived = true;
        fx.add(Fx(FxKind.gib, [tower.pos], ttl: 0.3, colorValue: 0xFF263238));
      }
    } else if (type == 'bomber' && e.pos.y >= StoryLayout.teeLine - 20 && towers.isNotEmpty) {
      final tower = _nearestTower(e.pos)!;
      final to = tower.pos - e.pos;
      e.pos = e.pos + to.normalized() * math.min(to.length, speed * dt);
      if (e.pos.distanceTo(tower.pos) < e.radius + 20) {
        tower.disabled = math.max(tower.disabled, e.spec.ability!.disable);
        fx.add(Fx(FxKind.explosion, [e.pos], ttl: 0.4, radius: 45, colorValue: 0xFFFF6D00));
        _arrive(e);
      }
      return;
    } else if (type == 'charge') {
      _moveBoar(e, speed, dt);
    } else {
      final dir = flow.direction(e.pos);
      e.pos = e.pos + dir * (speed * dt);
    }
    if (e.pos.y >= StoryLayout.teeLine - 1) _arrive(e);
  }

  void _moveBoar(SEnemy e, double speed, double dt) {
    final a = e.spec.ability!;
    e.chargeCooldown = math.max(0, e.chargeCooldown - dt);
    final dir = e.chargeDir;
    if (dir != null) {
      final next = e.pos + dir * (a.speed * (e.snareTimer > 0 ? 0 : 1) * dt);
      if (next.y < StoryLayout.teeLine && flow.blockedAt(next)) {
        e.chargeDir = null;
        e.chargeCooldown = 2;
        return;
      }
      e.pos = next;
      return;
    }
    if (e.pauseTimer > 0) {
      e.pauseTimer -= dt;
      if (e.pauseTimer <= 0) e.chargeDir = (_teeGoal(e.pos) - e.pos).normalized();
      return;
    }
    final goal = _teeGoal(e.pos);
    if (e.chargeCooldown <= 0 && e.pos.distanceTo(goal) > 80 && flow.lineClear(e.pos, goal)) {
      e.pauseTimer = a.pause;
      return;
    }
    e.pos = e.pos + flow.direction(e.pos) * (speed * dt);
  }

  /// An enemy reached the tee box: it deals its damage once and is removed.
  /// Raccoons also steal and flee; bosses retreat and advance again.
  void _arrive(SEnemy e) {
    final a = e.spec.ability;
    if (e.boss) {
      damageTee(e.damage);
      e.retreating = true;
      e.chargeDir = null;
      if (a?.type == 'gas') _gas(e);
      return;
    }
    if (a?.type == 'thief') {
      e.stolen = math.min(coins, a!.steal);
      coins -= e.stolen;
      e.fleeing = true;
      if (e.stolen > 0) fx.add(Fx(FxKind.text, [e.pos], ttl: 0.8, text: '-${e.stolen}', colorValue: 0xFFFFEB3B));
      damageTee(e.damage);
      return;
    }
    if (a?.type == 'gas') _gas(e);
    e.removed = true;
    damageTee(e.damage);
  }

  void _gas(SEnemy e) {
    final a = e.spec.ability!;
    gas.add(SGas(e.pos, a.radius, a.disable));
  }

  void damageTee(double amount) {
    if (finished || phase == RoundPhase.revive) return;
    health -= amount;
    shake = math.max(shake, 0.2);
    if (health > 0) return;
    flags--;
    flagsLost++;
    if (flags <= 0) {
      health = 0;
      if (setup.reviveAvailable && !reviveUsed) {
        _phaseBeforeRevive = phase;
        phase = RoundPhase.revive;
      } else {
        phase = RoundPhase.lost;
        _say('The tee box has fallen');
      }
      return;
    }
    health = rules.n('teeBox.flagRestoreHealth');
    _say('A flag has fallen!');
  }

  /// Applies damage with every multiplier. [wetBonus] applies to wet enemies (Tee-Tesla).
  void damageEnemy(SEnemy e, double amount, {double wetBonus = 0, bool quiet = false}) {
    if (!e.targetable) return;
    var m = 1.0;
    if (wetBonus > 0 && e.wetTimer > 0) m *= 1 + wetBonus;
    if (e.markTimer > 0) m *= 1 + e.markAmount;
    if (e.sniperMarkTimer > 0) m *= 1 + content.towers.firstWhere((t) => t.kind == TowerKind.sniper).stat('mark');
    if (e.boss) m *= 1 + perkSum('bossDamage') + caddiePassive('bossDamage');
    e.hp -= amount * m;
    if (!quiet) e.hitFlash = 0.1;
    if (e.hp <= 0) _kill(e);
  }

  void _kill(SEnemy e) {
    e.hp = 0;
    e.removed = true;
    kills++;
    killsById[e.spec.id] = (killsById[e.spec.id] ?? 0) + 1;
    coins += (e.coins * comboMultiplier * (1 + perkSum('coinGain'))).round();
    coins += e.stolen;
    if (e.abilityType == 'gas') _gas(e);
    fx.add(Fx(FxKind.gib, [e.pos], ttl: e.boss ? 1.2 : 0.7, radius: e.radius, colorValue: e.spec.color));
    if (e.boss) shake = 0.5;
  }

  // ---------------------------------------------------------------- balls

  void _updateBalls(double dt) {
    for (final b in balls) {
      if (b.done) continue;
      if (b.isLob) {
        b.lobTime += dt;
        final p = b.lobTotal == 0 ? 1.0 : (b.lobTime / b.lobTotal).clamp(0.0, 1.0);
        b.pos = b.lobStart! + (b.lobTarget! - b.lobStart!) * p;
        if (p >= 1) _landLob(b);
        continue;
      }
      final magnet = b.stats.effect?.type == 'magnet' ? b.stats.effect!.radius : 0.0;
      if (magnet > 0) {
        final e = _nearest(b.pos, (e) => e.targetable && (b.stats.hitsFliers || !e.flier) && !b.hitIds.contains(e.id), range: magnet);
        if (e != null) {
          final speed = b.vel.length;
          final want = (e.pos - b.pos).normalized() * speed;
          b.vel = (b.vel + (want - b.vel) * math.min(1, 6 * dt)).normalized() * speed;
        }
      }
      final stepLen = b.vel.length * dt;
      final steps = math.max(1, (stepLen / 4).ceil());
      final step = dt / steps;
      for (var i = 0; i < steps && !b.done; i++) {
        b.pos = b.pos + b.vel * step;
        b.distance -= b.vel.length * step;
        _ballWalls(b);
        if (b.done) break;
        _ballHazards(b);
        if (b.done) break;
        if (_checkPins(b.pos, b.radius)) {
          b.hitSomething = true;
          b.done = true;
          break;
        }
        _ballEnemies(b);
        if (!b.done && b.distance <= 0) _endBall(b);
      }
    }
  }

  void _ballWalls(SBall b) {
    V2? normal;
    if (b.pos.x < b.radius && b.vel.x < 0) normal = const V2(1, 0);
    if (b.pos.x > StoryLayout.width - b.radius && b.vel.x > 0) normal = const V2(-1, 0);
    if (b.pos.y < StoryLayout.fairway.top + b.radius && b.vel.y < 0) normal = const V2(0, 1);
    if (normal != null) {
      if (b.bounces > 0) {
        b.bounces--;
        b.vel = b.vel.reflect(normal);
      } else {
        _endBall(b);
      }
      return;
    }
    if (b.pos.y > StoryLayout.teeLine - 10 && b.vel.y > 0) _endBall(b);
  }

  void _ballHazards(SBall b) {
    final h = hazards;
    for (final f in h.fences) {
      final c = f.clamp(b.pos);
      var n = b.pos - c;
      if (n.length > b.radius) continue;
      if (n.length < 1e-6) {
        // Centre inside the fence: push out along the shallowest side.
        final dl = b.pos.x - f.left, dr = f.right - b.pos.x, dt = b.pos.y - f.top, db = f.bottom - b.pos.y;
        final m = [dl, dr, dt, db].reduce(math.min);
        n = m == dl
            ? const V2(-1, 0)
            : m == dr
            ? const V2(1, 0)
            : m == dt
            ? const V2(0, -1)
            : const V2(0, 1);
      }
      n = n.normalized();
      if (b.vel.dot(n) < 0) b.vel = b.vel.reflect(n);
      b.pos = c + n * (b.radius + 0.5);
    }
    for (final t in h.trees) {
      final d = b.pos - t.center;
      if (d.length > t.radius + b.radius) continue;
      final n = d.length < 1e-6 ? const V2(0, 1) : d.normalized();
      if (b.vel.dot(n) < 0) b.vel = b.vel.reflect(n) * h.treeBounce;
      b.pos = t.center + n * (t.radius + b.radius + 0.5);
    }
    if (b.rolls) {
      if (h.water.any((w) => w.contains(b.pos))) {
        fx.add(Fx(FxKind.splash, [b.pos], ttl: 0.4, radius: 14, colorValue: 0xFF81D4FA));
        _endBall(b);
      } else if (h.sand.any((s) => s.contains(b.pos))) {
        _endBall(b);
      }
    }
  }

  bool _canHit(SBall b, SEnemy e) => e.targetable && (b.stats.hitsFliers || !e.flier);

  void _ballEnemies(SBall b) {
    for (final e in List.of(enemies)) {
      if (!_canHit(b, e) || b.hitIds.contains(e.id)) continue;
      if (e.pos.distanceTo(b.pos) > e.radius + b.radius) continue;
      b.hitIds.add(e.id);
      _ballHit(b, e);
      if (b.pierce > 0) {
        b.pierce--;
        continue;
      }
      if (b.bounces > 0) {
        b.bounces--;
        b.vel = b.vel.reflect((b.pos - e.pos).normalized());
        continue;
      }
      _endBall(b);
      return;
    }
  }

  void _ballHit(SBall b, SEnemy e) {
    final first = !b.hitSomething;
    b.hitSomething = true;
    damageEnemy(e, b.damage);
    final effect = b.stats.effect;
    if (effect != null) {
      switch (effect.type) {
        case 'knockback':
          if (!e.boss && e.alive) {
            final p = e.pos + b.vel.normalized() * effect.distance;
            if (e.flier || (!flow.blockedAt(p) && p.y > StoryLayout.spawnTop && p.x > 0 && p.x < StoryLayout.width)) e.pos = p;
          }
        case 'burn':
          if (e.alive) {
            e.burnTimer = effect.seconds;
            e.burnDps = effect.dps;
          }
        case 'chain':
          if (b.sweet) {
            final chain = <SEnemy>[e];
            var cur = e;
            while (chain.length <= effect.targets) {
              final next = _nearest(cur.pos, (o) => o.targetable && !chain.contains(o), range: effect.range);
              if (next == null) break;
              chain.add(next);
              cur = next;
            }
            fx.add(Fx(FxKind.lightning, [for (final c in chain) c.pos], ttl: 0.25, colorValue: 0xFF80D8FF));
            for (final o in chain.skip(1)) {
              damageEnemy(o, b.damage * effect.damage);
            }
          }
      }
    }
    if (!b.free) _chargeFore(b.sweet ? rules.n('fore.perSweetHit') : rules.n('fore.perHit'));
    if (first) _registerHit(b);
  }

  void _registerHit(SBall b) {
    if (b.free) return;
    comboRung = math.min(comboCount - 1, comboRung + 1);
    bestRung = math.max(bestRung, comboRung);
    if (comboRung >= 2) fx.add(Fx(FxKind.text, [StoryLayout.golfer - const V2(0, 50)], ttl: 1, text: '$comboName!', colorValue: 0xFFFFEB3B));
  }

  void _landLob(SBall b) {
    final at = b.lobTarget!;
    if (hazards.water.any((w) => w.contains(at))) {
      fx.add(Fx(FxKind.splash, [at], ttl: 0.4, radius: 18, colorValue: 0xFF81D4FA));
      _endBall(b);
      return;
    }
    _checkPins(at, b.stats.blastRadius, reach: 0.15);
    final radius = b.stats.blastRadius * (b.sweet ? 1.3 : 1);
    fx.add(Fx(FxKind.explosion, [at], ttl: 0.35, radius: radius, colorValue: 0xFFFFF59D));
    final freeze = b.stats.effect?.type == 'freeze' ? b.stats.effect : null;
    var hits = 0;
    for (final e in List.of(enemies)) {
      if (!e.targetable || e.flier || e.pos.distanceTo(at) > radius + e.radius) continue;
      hits++;
      damageEnemy(e, b.damage);
      if (freeze != null && e.alive) _slow(e, freeze.slow, freeze.seconds);
      if (!b.free) _chargeFore(b.sweet ? rules.n('fore.perSweetHit') : rules.n('fore.perHit'));
    }
    if (hits > 0) {
      b.hitSomething = true;
      _registerHit(b);
    }
    _endBall(b);
  }

  void _endBall(SBall b) {
    if (b.done) return;
    b.done = true;
    if (!b.hitSomething && !b.free) comboRung = 0;
  }

  // ---------------------------------------------------------------- update

  void update(double realDt) {
    final dt0 = realDt.clamp(0.0, 0.05);
    for (final f in fx) {
      f.ttl -= dt0;
    }
    fx.removeWhere((f) => f.ttl <= 0);
    shake = math.max(0, shake - dt0);
    if (bannerTimer > 0) {
      bannerTimer -= dt0;
      if (bannerTimer <= 0) banner = null;
    }
    if (aiming) aimTime += dt0;
    if (!playing) return;
    final slowed = slowMo > 0;
    slowMo = math.max(0, slowMo - dt0);
    final dt = slowed ? dt0 * rules.n('coins.slowMoSpeed') : dt0;
    time += dt;
    for (var i = 0; i < cooldowns.length; i++) {
      cooldowns[i] = math.max(0, cooldowns[i] - dt);
    }
    for (final k in disabledPlots.keys.toList()) {
      final left = disabledPlots[k]! - dt;
      if (left <= 0) {
        disabledPlots.remove(k);
      } else {
        disabledPlots[k] = left;
      }
    }
    for (final g in gas) {
      g.time -= dt;
    }
    gas.removeWhere((g) => g.time <= 0);

    if (phase == RoundPhase.buildBreak) {
      breakTimer -= dt;
      _updateTowers(dt);
      _updateFore(dt);
      _updateBalls(dt);
      balls.removeWhere((b) => b.done);
      if (breakTimer <= 0) _startWave(wave + 1);
      return;
    }

    _spawnDue(dt);
    _updatePins(dt);
    _updateFore(dt);
    _updateTowers(dt);
    _updateEnemies(dt);
    if (!playing) return;
    _updateBalls(dt);
    enemies.removeWhere((e) => !e.alive);
    balls.removeWhere((b) => b.done);
    if (phase == RoundPhase.wave && _spawnQueue.isEmpty && !_bossPending && enemies.isEmpty) _waveCleared();
  }
}
