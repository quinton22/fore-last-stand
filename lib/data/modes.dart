/// Game modes are wrappers around the same engine (spec 6).
/// Arcade modes. Story Mode (section 6a) has its own engine in `lib/story/`.
enum ModeId { suddenDeath, dailyTournament }

/// Run-wide twists used by the Daily Tournament.
enum Modifier { none, windy, bigBalls, stampede, cheapSeats, glassClubhouse }

class ModeSpec {
  const ModeSpec({
    required this.id,
    required this.name,
    required this.length,
    required this.structure,
    required this.flags,
    this.holes,
  });

  final ModeId id;
  final String name;
  final String length;
  final String structure;

  /// Clubhouse flag lives.
  final int flags;

  /// Number of holes, or null for endless.
  final int? holes;

  bool get endless => holes == null;
}

const List<ModeSpec> modes = [
  ModeSpec(id: ModeId.suddenDeath, name: 'Sudden Death', length: 'Open-ended', structure: 'Endless waves, one flag life', flags: 1),
  ModeSpec(id: ModeId.dailyTournament, name: 'Daily Tournament', length: '5 min', structure: 'Fixed daily seed and modifier, 5 holes', flags: 3, holes: 5),
];

ModeSpec modeById(ModeId id) => modes.firstWhere((m) => m.id == id);

const Map<Modifier, String> modifierNames = {
  Modifier.none: 'None',
  Modifier.windy: 'Windy: balls drift sideways',
  Modifier.bigBalls: 'Big Balls: balls are 60% bigger',
  Modifier.stampede: 'Stampede: enemies move 25% faster',
  Modifier.cheapSeats: 'Cheap Seats: towers cost 25% less',
  Modifier.glassClubhouse: 'Glass Clubhouse: 40% less clubhouse HP, 50% more coins',
};

/// Seed shared by everyone on a given (UTC) day.
int dailySeed(DateTime day) {
  final d = day.toUtc();
  return d.year * 10000 + d.month * 100 + d.day;
}

Modifier dailyModifier(int seed) {
  final options = Modifier.values.where((m) => m != Modifier.none).toList();
  return options[seed % options.length];
}
