/// Story Mode save (section 6a.13). Plain data with a JSON round trip.
library;

typedef Json = Map<String, Object?>;

int _i(Object? v, [int fallback = 0]) => (v as num?)?.toInt() ?? fallback;
Json _m(Object? v) => (v as Map?)?.cast<String, Object?>() ?? {};
List<Object?> _l(Object? v) => (v as List?) ?? const [];

class PlacedTower {
  PlacedTower({required this.type, required this.col, required this.row, this.level = 1});

  factory PlacedTower.fromJson(Json j) => PlacedTower(type: j['type'] as String, col: _i(j['col']), row: _i(j['row']), level: _i(j['level'], 1));

  final String type;
  final int col;
  final int row;
  int level;

  PlacedTower copy() => PlacedTower(type: type, col: col, row: row, level: level);
  Json toJson() => {'type': type, 'col': col, 'row': row, 'level': level};

  @override
  bool operator ==(Object other) => other is PlacedTower && other.type == type && other.col == col && other.row == row && other.level == level;

  @override
  int get hashCode => Object.hash(type, col, row, level);
}

/// Progress through one hole: coins, towers and perks carry between its rounds.
/// Outside a round this is the Tee Off snapshot a lost or conceded round returns to.
class HoleRun {
  HoleRun({
    required this.hole,
    this.round = 1,
    required this.coins,
    List<String>? perks,
    this.roundPerk,
    this.bankedBoost,
    List<PlacedTower>? towers,
    this.extraRerollsUsed = 0,
    this.replay = false,
  }) : perks = perks ?? [],
       towers = towers ?? [];

  factory HoleRun.fromJson(Json j) => HoleRun(
    hole: _i(j['hole'], 1),
    round: _i(j['round'], 1),
    coins: _i(j['coins']),
    perks: [for (final p in _l(j['perks'])) p as String],
    roundPerk: j['roundPerk'] as String?,
    bankedBoost: j['bankedBoost'] as String?,
    towers: [for (final t in _l(j['towers'])) PlacedTower.fromJson(_m(t))],
    extraRerollsUsed: _i(j['extraRerollsUsed']),
    replay: j['replay'] as bool? ?? false,
  );

  int hole;
  int round;
  int coins;

  /// Perks drafted on this hole, including [roundPerk].
  List<String> perks;

  /// The perk drafted at this round's Prep, once teed off. Null until then.
  /// A conceded round removes it so the draft is offered again.
  String? roundPerk;

  /// Ad boost watched at Prep. Kept on concede, used up on a win or loss.
  String? bankedBoost;
  List<PlacedTower> towers;

  /// Locker Room rerolls spent on this hole.
  int extraRerollsUsed;

  /// A replay of a beaten hole: half rewards, no effect on story progress.
  bool replay;

  bool get drafted => roundPerk != null;

  HoleRun copy() => HoleRun.fromJson(toJson());

  Json toJson() => {
    'hole': hole,
    'round': round,
    'coins': coins,
    'perks': perks,
    'roundPerk': roundPerk,
    'bankedBoost': bankedBoost,
    'towers': [for (final t in towers) t.toJson()],
    'extraRerollsUsed': extraRerollsUsed,
    'replay': replay,
  };
}

/// A finished round waiting on the Results screen. Nothing in it is applied
/// until the player leaves Results by any button except Concede.
class PendingResult {
  PendingResult({
    required this.won,
    required this.hole,
    required this.round,
    required this.xp,
    required this.tokens,
    required this.endCoins,
    required this.endTowers,
    required this.wavesCleared,
    required this.totalWaves,
    required this.flagsLeft,
    this.kills = const {},
    this.replay = false,
  });

  factory PendingResult.fromJson(Json j) => PendingResult(
    won: j['won'] as bool? ?? false,
    hole: _i(j['hole'], 1),
    round: _i(j['round'], 1),
    xp: _i(j['xp']),
    tokens: _i(j['tokens']),
    endCoins: _i(j['endCoins']),
    endTowers: [for (final t in _l(j['endTowers'])) PlacedTower.fromJson(_m(t))],
    wavesCleared: _i(j['wavesCleared']),
    totalWaves: _i(j['totalWaves']),
    flagsLeft: _i(j['flagsLeft']),
    kills: {for (final e in _m(j['kills']).entries) e.key: _i(e.value)},
    replay: j['replay'] as bool? ?? false,
  );

  final bool won;
  final int hole;
  final int round;
  final int xp;
  final int tokens;
  final int endCoins;
  final List<PlacedTower> endTowers;
  final int wavesCleared;
  final int totalWaves;
  final int flagsLeft;
  final Map<String, int> kills;
  final bool replay;

  Json toJson() => {
    'won': won,
    'hole': hole,
    'round': round,
    'xp': xp,
    'tokens': tokens,
    'endCoins': endCoins,
    'endTowers': [for (final t in endTowers) t.toJson()],
    'wavesCleared': wavesCleared,
    'totalWaves': totalWaves,
    'flagsLeft': flagsLeft,
    'kills': kills,
    'replay': replay,
  };
}

/// Everything that belongs to one course (6a.10).
class CourseSave {
  CourseSave({
    this.rank = 1,
    this.xp = 0,
    this.tokens = 0,
    required this.ownedClubs,
    Map<String, int>? clubhouse,
    required this.bag,
    this.highestHoleBeaten = 0,
    required this.current,
    this.replayRun,
    this.pendingResult,
  }) : clubhouse = clubhouse ?? {'snackBar': 0, 'greenskeeping': 0, 'lockerRoom': 0};

  factory CourseSave.fresh({required String starterClub, required int startCoins}) => CourseSave(
    ownedClubs: {starterClub: 1},
    bag: [starterClub, null, null],
    current: HoleRun(hole: 1, coins: startCoins),
  );

  factory CourseSave.fromJson(Json j) => CourseSave(
    rank: _i(j['rank'], 1),
    xp: _i(j['xp']),
    tokens: _i(j['tokens']),
    ownedClubs: {for (final e in _m(j['ownedClubs']).entries) e.key: _i(e.value, 1)},
    clubhouse: {for (final e in _m(j['clubhouse']).entries) e.key: _i(e.value)},
    bag: [for (final b in _l(j['bag'])) b as String?],
    highestHoleBeaten: _i(j['highestHoleBeaten']),
    current: HoleRun.fromJson(_m(j['current'])),
    replayRun: j['replay'] == null ? null : HoleRun.fromJson(_m(j['replay'])),
    pendingResult: j['pendingResult'] == null ? null : PendingResult.fromJson(_m(j['pendingResult'])),
  );

  int rank;

  /// Progress within the current rank.
  int xp;
  int tokens;

  /// Bought club id -> level (1-5).
  Map<String, int> ownedClubs;
  Map<String, int> clubhouse;

  /// Three slots, null = empty.
  List<String?> bag;
  int highestHoleBeaten;
  HoleRun current;

  /// An in-progress replay of a beaten hole.
  HoleRun? replayRun;
  PendingResult? pendingResult;

  int wingTier(String id) => clubhouse[id] ?? 0;

  /// The hole run a round is being played on.
  HoleRun activeRun({required bool replay}) => replay ? replayRun! : current;

  Json toJson() => {
    'rank': rank,
    'xp': xp,
    'tokens': tokens,
    'ownedClubs': ownedClubs,
    'clubhouse': clubhouse,
    'bag': bag,
    'highestHoleBeaten': highestHoleBeaten,
    'current': current.toJson(),
    if (replayRun != null) 'replay': replayRun!.toJson(),
    'pendingResult': pendingResult?.toJson(),
  };
}

/// What travels between courses (6a.10).
class PlayerSave {
  PlayerSave({Map<String, int>? caddies, this.equippedCaddie = 'big_earl', this.caddieBadges = 0, this.removeAds = false})
    : caddies = caddies ?? {'big_earl': 1};

  factory PlayerSave.fromJson(Json j) => PlayerSave(
    caddies: {for (final e in _m(j['caddies']).entries) e.key: _i(e.value, 1)},
    equippedCaddie: j['equippedCaddie'] as String?,
    caddieBadges: _i(j['caddieBadges']),
    removeAds: j['removeAds'] as bool? ?? false,
  );

  /// Unlocked caddie id -> rank (1-5).
  Map<String, int> caddies;
  String? equippedCaddie;
  int caddieBadges;
  bool removeAds;

  Json toJson() => {'caddies': caddies, 'equippedCaddie': equippedCaddie, 'caddieBadges': caddieBadges, 'removeAds': removeAds};
}

class StorySave {
  StorySave({List<String>? unlockedCourses, PlayerSave? player, Map<String, CourseSave>? courses})
    : unlockedCourses = unlockedCourses ?? ['suburban_muni'],
      player = player ?? PlayerSave(),
      courses = courses ?? {};

  factory StorySave.fromJson(Json j) => StorySave(
    unlockedCourses: [for (final c in _l(j['unlockedCourses'])) c as String],
    player: PlayerSave.fromJson(_m(j['player'])),
    courses: {for (final e in _m(j['courses']).entries) e.key: CourseSave.fromJson(_m(e.value))},
  );

  static const int version = 1;

  List<String> unlockedCourses;
  PlayerSave player;
  Map<String, CourseSave> courses;

  /// The course whose Results screen is waiting, if any.
  String? get pendingCourse {
    for (final e in courses.entries) {
      if (e.value.pendingResult != null) return e.key;
    }
    return null;
  }

  Json toJson() => {
    'version': version,
    'unlockedCourses': unlockedCourses,
    'player': player.toJson(),
    'courses': {for (final e in courses.entries) e.key: e.value.toJson()},
  };
}
