import 'dart:convert';

import '../sim/vec.dart';

/// Story Mode content (section 6a). Everything here is parsed from JSON in
/// `assets/courses/`; balance values live in the JSON, not in code.

typedef Json = Map<String, Object?>;

double _d(Object? v, [double fallback = 0]) => (v as num?)?.toDouble() ?? fallback;
int _i(Object? v, [int fallback = 0]) => (v as num?)?.toInt() ?? fallback;
Json _m(Object? v) => (v as Map?)?.cast<String, Object?>() ?? const {};
List<Object?> _l(Object? v) => (v as List?) ?? const [];
int _color(Object? v) => v is String ? int.parse(v) : _i(v, 0xFFFFFFFF);

// ------------------------------------------------------------------ rules

class RoundRule {
  const RoundRule(this.waves, this.finalBoss);
  final int waves;
  final bool finalBoss;
}

class ClubhouseWing {
  const ClubhouseWing({required this.id, required this.name, required this.description, required this.perTier, required this.costs});
  final String id;
  final String name;
  final String description;
  final double perTier;
  final List<int> costs;
  int get maxTier => costs.length;
}

class BoostSpec {
  const BoostSpec(this.id, this.name, this.value);
  final String id;
  final String name;
  final double value;
}

/// Tuning values from `rules.json`, kept as a map with typed lookups so new
/// numbers can be added to the file without a schema change.
class Rules {
  Rules(this.raw)
    : rounds = [for (final r in _l(raw['rounds'])) RoundRule(_i(_m(r)['waves']), _m(r)['boss'] == 'final')],
      clubhouse = [
        for (final w in _l(raw['clubhouse']))
          ClubhouseWing(
            id: _m(w)['id'] as String,
            name: _m(w)['name'] as String,
            description: _m(w)['description'] as String? ?? '',
            perTier: _d(_m(w)['perTier']),
            costs: [for (final c in _l(_m(w)['costs'])) _i(c)],
          ),
      ],
      boosts = [for (final b in _l(_m(raw['ads'])['boosts'])) BoostSpec(_m(b)['id'] as String, _m(b)['name'] as String, _d(_m(b)['value']))],
      comboNames = [for (final n in _l(_m(raw['combo'])['names'])) n as String],
      comboMultipliers = [for (final n in _l(_m(raw['combo'])['multipliers'])) _d(n)];

  final Json raw;
  final List<RoundRule> rounds;
  final List<ClubhouseWing> clubhouse;
  final List<BoostSpec> boosts;
  final List<String> comboNames;
  final List<double> comboMultipliers;

  /// Number at a dotted path such as `swing.minDrag`.
  double n(String path) {
    Object? cur = raw;
    for (final part in path.split('.')) {
      cur = _m(cur)[part];
    }
    if (cur is! num) throw StateError('rules.json is missing a number at $path');
    return cur.toDouble();
  }

  int i(String path) => n(path).round();

  List<double> list(String path) {
    Object? cur = raw;
    for (final part in path.split('.')) {
      cur = _m(cur)[part];
    }
    return [for (final v in _l(cur)) _d(v)];
  }

  int get roundsPerHole => rounds.length;
  ClubhouseWing wing(String id) => clubhouse.firstWhere((w) => w.id == id);
  BoostSpec boost(String id) => boosts.firstWhere((b) => b.id == id);
  double tierMultiplier(String tier) => n('tiers.$tier');
}

// ------------------------------------------------------------------ clubs

enum BallMotion { arc, straight, lob, roll }

class ClubFamily {
  const ClubFamily({
    required this.id,
    required this.name,
    required this.damage,
    required this.speed,
    required this.cooldown,
    required this.range,
    required this.pierce,
    required this.bounces,
    required this.hitsFliers,
    required this.motion,
    required this.blastRadius,
    required this.behavior,
  });

  factory ClubFamily.fromJson(Json j) => ClubFamily(
    id: j['id'] as String,
    name: j['name'] as String,
    damage: _d(j['damage']),
    speed: _d(j['speed']),
    cooldown: _d(j['cooldown']),
    range: _d(j['range']),
    pierce: _i(j['pierce']),
    bounces: _i(j['bounces']),
    hitsFliers: j['hitsFliers'] as bool? ?? false,
    motion: BallMotion.values.byName(j['motion'] as String? ?? 'straight'),
    blastRadius: _d(j['blastRadius']),
    behavior: j['behavior'] as String? ?? '',
  );

  final String id;
  final String name;
  final double damage;
  final double speed;
  final double cooldown;
  final double range;
  final int pierce;
  final int bounces;
  final bool hitsFliers;
  final BallMotion motion;
  final double blastRadius;
  final String behavior;
}

/// A Special club's effect. Unused fields are zero.
class ClubEffect {
  const ClubEffect({
    required this.type,
    this.distance = 0,
    this.dps = 0,
    this.seconds = 0,
    this.slow = 0,
    this.radius = 0,
    this.balls = 0,
    this.spread = 0,
    this.damage = 0,
    this.targets = 0,
    this.range = 0,
  });

  factory ClubEffect.fromJson(Json j) => ClubEffect(
    type: j['type'] as String,
    distance: _d(j['distance']),
    dps: _d(j['dps']),
    seconds: _d(j['seconds']),
    slow: _d(j['slow']),
    radius: _d(j['radius']),
    balls: _i(j['balls']),
    spread: _d(j['spreadDegrees']),
    damage: _d(j['damage']),
    targets: _i(j['targets']),
    range: _d(j['range'], 110),
  );

  /// knockback, burn, freeze, magnet, twin or chain.
  final String type;
  final double distance;
  final double dps;
  final double seconds;
  final double slow;
  final double radius;
  final int balls;
  final double spread;
  final double damage;
  final int targets;
  final double range;
}

class StoryClub {
  const StoryClub({
    required this.id,
    required this.name,
    required this.family,
    required this.tier,
    required this.rank,
    required this.price,
    this.effect,
    this.effectText = '',
  });

  final String id;
  final String name;
  final ClubFamily family;

  /// old, used, new or special.
  final String tier;

  /// Course rank that reveals this club in the Pro Shop.
  final int rank;
  final int price;
  final ClubEffect? effect;
  final String effectText;

  String get tierName => tier[0].toUpperCase() + tier.substring(1);
}

// ------------------------------------------------------------------ holes

class Hazards {
  const Hazards({this.water = const [], this.fences = const [], this.sand = const [], this.trees = const [], this.treeBounce = 1});

  factory Hazards.fromJson(Json j) {
    List<Box> boxes(Object? o) => [
      for (final b in _l(o))
        () {
          final v = [for (final x in _l(b)) _d(x)];
          return Box(v[0], v[1], v[0] + v[2], v[1] + v[3]);
        }(),
    ];
    return Hazards(
      water: boxes(j['water']),
      fences: boxes(j['fences']),
      sand: boxes(j['sand']),
      trees: [
        for (final t in _l(j['trees']))
          () {
            final v = [for (final x in _l(t)) _d(x)];
            return Tree(V2(v[0], v[1]), v[2]);
          }(),
      ],
      treeBounce: _d(j['treeBounce'], 1),
    );
  }

  final List<Box> water;
  final List<Box> fences;
  final List<Box> sand;
  final List<Tree> trees;

  /// Speed multiplier when a ball bounces off a tree (Pinball: 1.2).
  final double treeBounce;

  bool get isEmpty => water.isEmpty && fences.isEmpty && sand.isEmpty && trees.isEmpty;
}

class Tree {
  const Tree(this.center, this.radius);
  final V2 center;
  final double radius;
}

class StoryHole {
  const StoryHole({
    required this.number,
    required this.name,
    required this.featured,
    required this.hazards,
    this.bossHpMultiplier = 1,
    this.bossSummonBelowHalf,
  });

  final int number;
  final String name;

  /// Enemy id the mini-boss is built from.
  final String featured;
  final Hazards hazards;
  final double bossHpMultiplier;

  /// Hole 18: below 50% HP the final boss also summons these.
  final BossAbility? bossSummonBelowHalf;
}

// ------------------------------------------------------------------ enemies

enum EnemyShape { circle, square, triangle, diamond }

class EnemyAbility {
  const EnemyAbility({
    required this.type,
    this.every = 0,
    this.radius = 0,
    this.stun = 0,
    this.steal = 0,
    this.disable = 0,
    this.pause = 0,
    this.speed = 0,
    this.followers = 0,
    this.follower,
    this.speedBonus = 0,
  });

  factory EnemyAbility.fromJson(Json j) => EnemyAbility(
    type: j['type'] as String,
    every: _d(j['every']),
    radius: _d(j['radius']),
    stun: _d(j['stun']),
    steal: _i(j['steal']),
    disable: _d(j['disable']),
    pause: _d(j['pause']),
    speed: _d(j['speed']),
    followers: _i(j['followers']),
    follower: j['follower'] as String?,
    speedBonus: _d(j['speedBonus']),
  );

  /// honk, thief, dive, bomber, charge, gas or pack.
  final String type;
  final double every;
  final double radius;
  final double stun;
  final int steal;
  final double disable;
  final double pause;
  final double speed;
  final int followers;
  final String? follower;
  final double speedBonus;
}

class StoryEnemy {
  const StoryEnemy({
    required this.id,
    required this.name,
    required this.hp,
    required this.speed,
    required this.damage,
    required this.coins,
    required this.cost,
    required this.firstHole,
    required this.radius,
    required this.color,
    required this.shape,
    this.flier = false,
    this.immuneSlow = false,
    this.spawnable = true,
    this.spawnFromWater = false,
    this.ability,
    this.description = '',
    this.counter = '',
    this.target = false,
    this.path = 'direct',
  });

  factory StoryEnemy.fromJson(Json j) => StoryEnemy(
    id: j['id'] as String,
    name: j['name'] as String,
    hp: _d(j['hp']),
    speed: _d(j['speed']),
    damage: _d(j['damage']),
    coins: _i(j['coins']),
    cost: _d(j['cost']),
    firstHole: _i(j['firstHole'], 1),
    radius: _d(j['radius'], 12),
    color: _color(j['color']),
    shape: EnemyShape.values.byName(j['shape'] as String? ?? 'circle'),
    flier: j['flier'] as bool? ?? false,
    immuneSlow: j['immuneSlow'] as bool? ?? false,
    spawnable: j['spawnable'] as bool? ?? true,
    spawnFromWater: j['spawn'] == 'water',
    description: j['description'] as String? ?? '',
    counter: j['counter'] as String? ?? '',
    target: j['target'] as bool? ?? false,
    path: j['path'] as String? ?? 'direct',
    ability: j['ability'] == null ? null : EnemyAbility.fromJson(_m(j['ability'])),
  );

  final String id;
  final String name;
  final double hp;
  final double speed;
  final double damage;
  final int coins;

  /// Wave budget cost.
  final double cost;
  final int firstHole;
  final double radius;
  final int color;
  final EnemyShape shape;
  final bool flier;
  final bool immuneSlow;

  /// False for enemies that only arrive with another (coyote followers).
  final bool spawnable;
  final bool spawnFromWater;
  final EnemyAbility? ability;
  final String description;
  final String counter;

  /// Driving Range practice target: never moves or attacks.
  final bool target;

  /// How it crosses the fairway: direct (shortest path to the ball), spread
  /// (to a random point along the build zone), flank (down a side edge),
  /// weave (zigzag) or follow (stays beside its pack leader).
  final String path;
}

class BossAbility {
  const BossAbility({required this.type, this.enemy, this.count = 0, this.every = 0, this.seconds = 0});

  factory BossAbility.fromJson(Json j) =>
      BossAbility(type: j['type'] as String, enemy: j['enemy'] as String?, count: _i(j['count']), every: _d(j['every']), seconds: _d(j['seconds']));

  /// summon, submerge or disablePlots.
  final String type;
  final String? enemy;
  final int count;
  final double every;
  final double seconds;
}

class StoryBoss {
  const StoryBoss({
    required this.id,
    required this.name,
    required this.hp,
    required this.holes,
    required this.color,
    required this.ability,
    required this.text,
  });

  factory StoryBoss.fromJson(Json j) => StoryBoss(
    id: j['id'] as String,
    name: j['name'] as String,
    hp: _d(j['hp']),
    holes: [for (final h in _l(j['holes'])) _i(h)],
    color: _color(j['color']),
    ability: BossAbility.fromJson(_m(j['ability'])),
    text: j['text'] as String? ?? '',
  );

  final String id;
  final String name;
  final double hp;
  final List<int> holes;
  final int color;
  final BossAbility ability;
  final String text;
}

// ------------------------------------------------------------------ towers

enum TowerKind { ballMachine, sprinkler, sandTrap, cartCannon, teeTesla, ripper, sniper, snackShack }

class StoryTower {
  const StoryTower({
    required this.id,
    required this.name,
    required this.badge,
    required this.kind,
    required this.cost,
    required this.unlockHole,
    required this.color,
    required this.stats,
    required this.text,
    required this.overchargeText,
    this.frontRowOnly = false,
    this.health = 60,
  });

  factory StoryTower.fromJson(Json j) => StoryTower(
    id: j['id'] as String,
    name: j['name'] as String,
    badge: j['badge'] as String,
    kind: TowerKind.values.byName(j['kind'] as String),
    cost: _i(j['cost']),
    unlockHole: _i(j['unlockHole'], 1),
    color: _color(j['color']),
    stats: {for (final e in _m(j['stats']).entries) e.key: _d(e.value)},
    text: j['text'] as String? ?? '',
    overchargeText: j['overchargeText'] as String? ?? '',
    frontRowOnly: j['frontRowOnly'] as bool? ?? false,
    health: _d(j['health'], 60),
  );

  final String id;
  final String name;
  final String badge;
  final TowerKind kind;
  final int cost;
  final int unlockHole;
  final int color;
  final Map<String, double> stats;
  final String text;
  final String overchargeText;
  final bool frontRowOnly;

  /// Hit points at level 1; enemies attack towers in their way.
  final double health;

  double stat(String key) => stats[key] ?? 0;
}

// ------------------------------------------------------------------ perks and caddies

class StoryPerk {
  const StoryPerk({required this.id, required this.name, required this.text, required this.effect, required this.value});

  factory StoryPerk.fromJson(Json j) =>
      StoryPerk(id: j['id'] as String, name: j['name'] as String, text: j['text'] as String, effect: j['effect'] as String, value: _d(j['value']));

  final String id;
  final String name;
  final String text;
  final String effect;
  final double value;
}

class StoryCaddie {
  const StoryCaddie({
    required this.id,
    required this.name,
    required this.color,
    required this.passive,
    required this.passiveValue,
    required this.passiveText,
    required this.active,
    required this.activeValue,
    required this.activeSeconds,
    required this.activeName,
    required this.activeText,
    required this.unlockHole,
    required this.unlockText,
  });

  factory StoryCaddie.fromJson(Json j) {
    final passive = _m(j['passive']), active = _m(j['active']), unlock = _m(j['unlock']);
    return StoryCaddie(
      id: j['id'] as String,
      name: j['name'] as String,
      color: _color(j['color']),
      passive: passive['type'] as String,
      passiveValue: _d(passive['value']),
      passiveText: j['passiveText'] as String? ?? '',
      active: active['type'] as String,
      activeValue: _d(active['value']),
      activeSeconds: _d(active['seconds']),
      activeName: j['activeName'] as String? ?? 'Ability',
      activeText: j['activeText'] as String? ?? '',
      unlockHole: unlock['type'] == 'beatHole' ? _i(unlock['hole']) : 0,
      unlockText: j['unlockText'] as String? ?? '',
    );
  }

  final String id;
  final String name;
  final int color;

  /// foreDamage or bossDamage.
  final String passive;
  final double passiveValue;
  final String passiveText;

  /// foreMeter or mark.
  final String active;
  final double activeValue;
  final double activeSeconds;
  final String activeName;
  final String activeText;

  /// 0 = available from the start; otherwise unlocked by beating this hole on any course.
  final int unlockHole;
  final String unlockText;
}

// ------------------------------------------------------------------ courses

class CourseInfo {
  const CourseInfo({required this.id, required this.name, required this.description, required this.available});

  final String id;
  final String name;
  final String description;

  /// False for courses that have no content yet.
  final bool available;
}

class CourseContent {
  CourseContent({required this.info, required this.clubs, required this.holes, required this.starterClub});

  final CourseInfo info;
  final List<StoryClub> clubs;
  final List<StoryHole> holes;
  final String starterClub;

  String get id => info.id;
  String get name => info.name;
  int get holeCount => holes.length;
  StoryHole hole(int number) => holes[number - 1];
  StoryClub club(String id) => clubs.firstWhere((c) => c.id == id);
  StoryClub? clubOrNull(String id) {
    for (final c in clubs) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Clubs revealed in the Pro Shop at [rank] (one per rank).
  List<StoryClub> revealedAt(int rank) => clubs.where((c) => c.rank <= rank).toList();
}

/// Reads one content file by path relative to `assets/courses/`.
typedef ContentReader = Future<String> Function(String path);

class StoryContent {
  StoryContent({
    required this.rules,
    required this.courses,
    required this.courseContent,
    required this.families,
    required this.enemies,
    required this.bosses,
    required this.towers,
    required this.perks,
    required this.caddies,
  });

  static const String assetRoot = 'assets/courses';

  final Rules rules;

  /// Every course in order, including ones without content yet.
  final List<CourseInfo> courses;
  final Map<String, CourseContent> courseContent;
  final Map<String, ClubFamily> families;
  final Map<String, StoryEnemy> enemies;
  final List<StoryBoss> bosses;
  final List<StoryTower> towers;
  final List<StoryPerk> perks;
  final List<StoryCaddie> caddies;

  static Future<StoryContent> load(ContentReader read) async {
    Future<Json> json(String path) async => (jsonDecode(await read(path)) as Map).cast<String, Object?>();
    final rules = Rules(await json('rules.json'));
    final familiesJson = await json('club_families.json');
    final families = {for (final f in _l(familiesJson['families'])) _m(f)['id'] as String: ClubFamily.fromJson(_m(f))};
    final courses = [
      for (final c in _l((await json('courses.json'))['courses']))
        CourseInfo(
          id: _m(c)['id'] as String,
          name: _m(c)['name'] as String,
          description: _m(c)['description'] as String? ?? '',
          available: _m(c)['available'] as bool? ?? true,
        ),
    ];
    final tiers = _m(_m(rules.raw['tokens'])['tierPrices']);
    final content = <String, CourseContent>{};
    for (final info in courses.where((c) => c.available)) {
      final clubsJson = await json('${info.id}/clubs.json');
      final holesJson = await json('${info.id}/holes.json');
      content[info.id] = CourseContent(
        info: info,
        starterClub: clubsJson['starter'] as String,
        clubs: [
          for (final c in _l(clubsJson['clubs']))
            () {
              final j = _m(c);
              final tier = j['tier'] as String;
              return StoryClub(
                id: j['id'] as String,
                name: j['name'] as String,
                family: families[j['family']]!,
                tier: tier,
                rank: _i(j['rank']),
                price: j.containsKey('price') ? _i(j['price']) : _i(tiers[tier]),
                effect: j['effect'] == null ? null : ClubEffect.fromJson(_m(j['effect'])),
                effectText: j['effectText'] as String? ?? '',
              );
            }(),
        ],
        holes: [
          for (final h in _l(holesJson['holes']))
            StoryHole(
              number: _i(_m(h)['number']),
              name: _m(h)['name'] as String,
              featured: _m(h)['featured'] as String,
              hazards: Hazards.fromJson(_m(_m(h)['hazards'])),
              bossHpMultiplier: _d(_m(h)['bossHpMultiplier'], 1),
              bossSummonBelowHalf: _m(h)['bossSummonBelowHalf'] == null ? null : BossAbility.fromJson(_m(_m(h)['bossSummonBelowHalf'])),
            ),
        ],
      );
    }
    return StoryContent(
      rules: rules,
      courses: courses,
      courseContent: content,
      families: families,
      enemies: {for (final e in _l((await json('enemies.json'))['enemies'])) _m(e)['id'] as String: StoryEnemy.fromJson(_m(e))},
      bosses: [for (final b in _l((await json('bosses.json'))['bosses'])) StoryBoss.fromJson(_m(b))],
      towers: [for (final t in _l((await json('towers.json'))['towers'])) StoryTower.fromJson(_m(t))],
      perks: [for (final p in _l((await json('perks.json'))['perks'])) StoryPerk.fromJson(_m(p))],
      caddies: [for (final c in _l((await json('caddies.json'))['caddies'])) StoryCaddie.fromJson(_m(c))],
    );
  }

  CourseContent course(String id) => courseContent[id]!;
  StoryEnemy enemy(String id) => enemies[id]!;
  StoryTower tower(String id) => towers.firstWhere((t) => t.id == id);
  StoryPerk perk(String id) => perks.firstWhere((p) => p.id == id);
  StoryCaddie caddie(String id) => caddies.firstWhere((c) => c.id == id);

  StoryBoss bossForHole(int hole) => bosses.firstWhere((b) => b.holes.contains(hole), orElse: () => bosses.first);

  /// The course after [id] in order, or null for the last one.
  CourseInfo? nextCourse(String id) {
    final i = courses.indexWhere((c) => c.id == id);
    return i < 0 || i + 1 >= courses.length ? null : courses[i + 1];
  }

  /// Towers that can be built on [hole].
  List<StoryTower> towersUnlockedAt(int hole) => towers.where((t) => t.unlockHole <= hole).toList();
}
