enum GoreLevel { fullSplat, classic, squeakyClean }

/// Player settings (spec 3 accessibility, spec 11 gore and feel).
class Settings {
  Settings({
    this.aimAssist = 0.3,
    this.autoCaddie = false,
    this.leftHanded = false,
    this.gore = GoreLevel.classic,
    this.screenShake = true,
    this.testAds = false,
  });

  double aimAssist;
  bool autoCaddie;
  bool leftHanded;
  GoreLevel gore;
  bool screenShake;

  /// Development stand-in for rewarded ads (no ad SDK is wired up yet).
  bool testAds;

  Map<String, Object?> toJson() => {
    'aimAssist': aimAssist,
    'autoCaddie': autoCaddie,
    'leftHanded': leftHanded,
    'gore': gore.name,
    'screenShake': screenShake,
    'testAds': testAds,
  };

  factory Settings.fromJson(Map<String, Object?> j) => Settings(
    aimAssist: (j['aimAssist'] as num?)?.toDouble() ?? 0.3,
    autoCaddie: j['autoCaddie'] as bool? ?? false,
    leftHanded: j['leftHanded'] as bool? ?? false,
    gore: GoreLevel.values.firstWhere((g) => g.name == j['gore'], orElse: () => GoreLevel.classic),
    screenShake: j['screenShake'] as bool? ?? true,
    testAds: j['testAds'] as bool? ?? false,
  );
}

/// Settings, the bestiary and arcade records. Story progress lives in the
/// Story save (`lib/story/save.dart`).
class Profile {
  Profile({
    this.runsPlayed = 0,
    this.bestSuddenDeath = 0,
    this.lastDailySeed = 0,
    this.bestDailyScore = 0,
    Map<String, int>? bestiary,
    List<String>? tutorialSeen,
    Settings? settings,
  }) : bestiary = bestiary ?? {},
       tutorialSeen = tutorialSeen ?? [],
       settings = settings ?? Settings();

  /// Arcade runs finished.
  int runsPlayed;

  /// Most waves cleared in Sudden Death.
  int bestSuddenDeath;
  int lastDailySeed;
  int bestDailyScore;

  /// Enemy id -> kills.
  Map<String, int> bestiary;

  /// Tutorial topic ids already shown (`welcome`, `range`).
  List<String> tutorialSeen;
  Settings settings;

  Map<String, Object?> toJson() => {
    'v': 2,
    'runsPlayed': runsPlayed,
    'bestSuddenDeath': bestSuddenDeath,
    'lastDailySeed': lastDailySeed,
    'bestDailyScore': bestDailyScore,
    'bestiary': bestiary,
    'tutorialSeen': tutorialSeen,
    'settings': settings.toJson(),
  };

  factory Profile.fromJson(Map<String, Object?> j) {
    Map<String, int> ints(Object? o) => (o as Map?)?.map((k, v) => MapEntry(k as String, (v as num).toInt())) ?? {};
    List<String> strs(Object? o) => (o as List?)?.cast<String>().toList() ?? [];
    // v1 saves counted Sudden Death in holes; v2 counts waves. Old records are dropped.
    final v2 = (j['v'] as num?) == 2;
    return Profile(
      runsPlayed: (j['runsPlayed'] as num?)?.toInt() ?? 0,
      bestSuddenDeath: v2 ? (j['bestSuddenDeath'] as num?)?.toInt() ?? 0 : 0,
      lastDailySeed: v2 ? (j['lastDailySeed'] as num?)?.toInt() ?? 0 : 0,
      bestDailyScore: v2 ? (j['bestDailyScore'] as num?)?.toInt() ?? 0 : 0,
      bestiary: ints(j['bestiary']),
      tutorialSeen: strs(j['tutorialSeen']),
      settings: j['settings'] == null ? null : Settings.fromJson((j['settings'] as Map).cast<String, Object?>()),
    );
  }
}
