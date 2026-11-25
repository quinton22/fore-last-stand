import 'dart:math' as math;

import 'content.dart';
import 'save.dart';

/// Story Mode progression rules (6a.2, 6a.5, 6a.6, 6a.11). Pure functions over
/// [StorySave] so every rule is unit-testable without Flutter.

/// Stable 31-bit hash (FNV-1a), so seeds do not depend on `String.hashCode`.
int stableHash(String s) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h & 0x7fffffff;
}

/// Seed for course, hole and round, so a retry plays the same.
int roundSeed(String courseId, int hole, int round, [String salt = '']) => stableHash('$courseId/$hole/$round/$salt');

// ------------------------------------------------------------------ rank and XP

/// XP to go from [rank] to rank + 1.
int xpToNext(Rules r, int rank) => r.i('xp.base') + r.i('xp.perRank') * (rank - 1);

class RoundReward {
  const RoundReward(this.xp, this.tokens);
  final int xp;
  final int tokens;
}

/// XP and Club Tokens for a finished round (conceded rounds get nothing).
RoundReward roundReward(Rules r, {required int hole, required bool won, required int wavesCleared, required int totalWaves, bool replay = false}) {
  var xp = (r.n('xp.roundBase') + r.n('xp.roundPerHole') * hole).toDouble();
  var tokens = r.n('tokens.roundBase') + r.n('tokens.roundPerHole') * hole;
  if (!won) {
    final frac = totalWaves == 0 ? 0.0 : (wavesCleared / totalWaves).clamp(0.0, 1.0);
    xp *= r.n('xp.lossFraction') * frac;
    tokens *= r.n('tokens.lossFraction') * frac;
  }
  if (replay) {
    xp *= r.n('xp.replayFraction');
    tokens *= r.n('tokens.replayFraction');
  }
  return RoundReward(xp.floor(), tokens.floor());
}

// ------------------------------------------------------------------ course setup

int holeStartCoins(Rules r, CourseSave cs) => r.i('coins.holeStart') + (r.wing('snackBar').perTier * cs.wingTier('snackBar')).round();

/// The course's save, created on first visit.
CourseSave courseSave(StorySave save, StoryContent content, String courseId) {
  return save.courses.putIfAbsent(courseId, () {
    final course = content.course(courseId);
    return CourseSave.fresh(starterClub: course.starterClub, startCoins: content.rules.i('coins.holeStart'));
  });
}

bool courseUnlocked(StorySave save, StoryContent content, String courseId) =>
    save.unlockedCourses.contains(courseId) && content.courseContent.containsKey(courseId);

/// True once every hole in `holes.json` is beaten.
bool courseFinished(CourseSave cs, CourseContent course) => cs.highestHoleBeaten >= course.holeCount;

/// Towers that can be built on [hole]; unlocks stay unlocked per course.
List<StoryTower> towersFor(StoryContent content, CourseSave cs, int hole) => content.towersUnlockedAt(math.max(hole, cs.highestHoleBeaten));

// ------------------------------------------------------------------ clubs and bag

List<StoryClub> revealedClubs(CourseContent course, CourseSave cs) => course.revealedAt(cs.rank);

bool isRevealed(CourseContent course, CourseSave cs, String clubId) => (course.clubOrNull(clubId)?.rank ?? 999) <= cs.rank;

int clubLevel(CourseSave cs, String clubId) => cs.ownedClubs[clubId] ?? 0;

int maxClubLevel(Rules r) => r.list('tokens.levelCosts').length + 1;

/// Tokens to go from [level] to level + 1, or null at max level.
int? levelCost(Rules r, int level) {
  final costs = r.list('tokens.levelCosts');
  return level < 1 || level > costs.length ? null : costs[level - 1].round();
}

/// A revealed club must be bought with Club Tokens before it can be equipped.
bool buyClub(Rules r, CourseContent course, CourseSave cs, String clubId) {
  final c = course.clubOrNull(clubId);
  if (c == null || cs.ownedClubs.containsKey(clubId) || !isRevealed(course, cs, clubId) || cs.tokens < c.price) return false;
  cs.tokens -= c.price;
  cs.ownedClubs[clubId] = 1;
  return true;
}

bool levelUpClub(Rules r, CourseSave cs, String clubId) {
  final level = clubLevel(cs, clubId);
  final cost = levelCost(r, level);
  if (level == 0 || cost == null || cs.tokens < cost) return false;
  cs.tokens -= cost;
  cs.ownedClubs[clubId] = level + 1;
  return true;
}

/// Equips an owned club. A club from a family already in the bag replaces that
/// club; otherwise it takes [slot] (or the first empty slot).
/// Returns false if nothing changed (not owned, or the bag is full and no slot given).
bool equipClub(CourseContent course, CourseSave cs, String clubId, {int? slot}) {
  final club = course.clubOrNull(clubId);
  if (club == null || !cs.ownedClubs.containsKey(clubId) || cs.bag.contains(clubId)) return false;
  final sameFamily = cs.bag.indexWhere((id) => id != null && course.club(id).family.id == club.family.id);
  final target = sameFamily >= 0 ? sameFamily : (slot ?? cs.bag.indexOf(null));
  if (target < 0 || target >= cs.bag.length) return false;
  cs.bag[target] = clubId;
  return true;
}

/// Empties a bag slot. At least one club stays equipped.
bool unequipSlot(CourseSave cs, int slot) {
  if (slot < 0 || slot >= cs.bag.length || cs.bag[slot] == null) return false;
  if (cs.bag.where((id) => id != null).length <= 1) return false;
  cs.bag[slot] = null;
  return true;
}

/// True if the bag follows the rules: 1-3 clubs, all owned, one per family.
bool bagIsValid(CourseContent course, CourseSave cs) {
  final ids = cs.bag.whereType<String>().toList();
  if (ids.isEmpty || cs.bag.length != 3) return false;
  if (!ids.every(cs.ownedClubs.containsKey)) return false;
  final families = ids.map((id) => course.club(id).family.id).toSet();
  return families.length == ids.length;
}

// ------------------------------------------------------------------ clubhouse and caddies

bool buyWing(Rules r, CourseSave cs, String wingId) {
  final w = r.wing(wingId);
  final tier = cs.wingTier(wingId);
  if (tier >= w.maxTier || cs.tokens < w.costs[tier]) return false;
  cs.tokens -= w.costs[tier];
  cs.clubhouse[wingId] = tier + 1;
  return true;
}

int maxCaddieRank(Rules r) => r.list('caddies.rankCosts').length + 1;

/// Badges to go from [rank] to rank + 1, or null at max.
int? caddieRankCost(Rules r, int rank) {
  final costs = r.list('caddies.rankCosts');
  return rank < 1 || rank > costs.length ? null : costs[rank - 1].round();
}

bool rankUpCaddie(Rules r, PlayerSave p, String id) {
  final rank = p.caddies[id];
  if (rank == null) return false;
  final cost = caddieRankCost(r, rank);
  if (cost == null || p.caddieBadges < cost) return false;
  p.caddieBadges -= cost;
  p.caddies[id] = rank + 1;
  return true;
}

/// A caddie's effect amount at [rank]: +10% of the base per rank above 1.
double caddieScale(Rules r, int rank) => 1 + r.n('caddies.rankStep') * (rank - 1);

/// Grants caddies whose unlock is "from the start" (for old or fresh saves).
void grantStartingCaddies(StoryContent content, PlayerSave p) {
  for (final c in content.caddies) {
    if (c.unlockHole == 0) p.caddies.putIfAbsent(c.id, () => 1);
  }
  if (p.equippedCaddie != null && !p.caddies.containsKey(p.equippedCaddie)) p.equippedCaddie = null;
  p.equippedCaddie ??= p.caddies.keys.isEmpty ? null : p.caddies.keys.first;
}

// ------------------------------------------------------------------ perks

/// Rerolls left in a draft: one free per draft plus Locker Room rerolls per hole.
int rerollsLeft(Rules r, CourseSave cs, HoleRun run, {required int usedThisDraft}) {
  final free = r.i('perks.freeRerolls');
  final extra = (r.wing('lockerRoom').perTier * cs.wingTier('lockerRoom')).round() - run.extraRerollsUsed;
  final usedExtra = math.max(0, usedThisDraft - free);
  return math.max(0, free - usedThisDraft) + math.max(0, extra - usedExtra);
}

/// The [draft]th offer (0 = first, 1 = after one reroll...) for a round. Seeded,
/// so a retry or concede shows the same three. Perks already taken on the hole
/// are never offered again. Equal odds, no rarities in v1.
List<StoryPerk> perkOffer(StoryContent content, String courseId, HoleRun run, {int draft = 0}) {
  final rng = math.Random(roundSeed(courseId, run.hole, run.round, 'perks${run.replay ? 'r' : ''}$draft'));
  final pool = content.perks.where((p) => !run.perks.contains(p.id)).toList();
  final n = math.min(content.rules.i('perks.choices'), pool.length);
  final out = <StoryPerk>[];
  for (var i = 0; i < n; i++) {
    out.add(pool.removeAt(rng.nextInt(pool.length)));
  }
  return out;
}

// ------------------------------------------------------------------ the round lifecycle

/// Saves the Tee Off snapshot: coins and towers after Prep, plus the drafted perk.
void teeOff(
  StorySave save,
  String courseId, {
  required bool replay,
  required int coins,
  required List<PlacedTower> towers,
  String? perk,
  int extraRerolls = 0,
  String? caddie,
}) {
  final cs = save.courses[courseId]!;
  final run = cs.activeRun(replay: replay);
  run.coins = coins;
  run.towers = [for (final t in towers) t.copy()];
  if (perk != null && run.roundPerk == null) {
    run.perks.add(perk);
    run.roundPerk = perk;
  }
  run.extraRerollsUsed += extraRerolls;
  if (caddie != null) save.player.equippedCaddie = caddie;
}

/// What the round sim reports when a round ends.
class RoundOutcome {
  const RoundOutcome({
    required this.won,
    required this.wavesCleared,
    required this.totalWaves,
    required this.flagsLeft,
    required this.endCoins,
    required this.endTowers,
    this.kills = const {},
  });

  final bool won;
  final int wavesCleared;
  final int totalWaves;
  final int flagsLeft;
  final int endCoins;
  final List<PlacedTower> endTowers;
  final Map<String, int> kills;
}

/// Stores a finished round as pending. Nothing is applied until [commitResult].
PendingResult finishRound(StorySave save, StoryContent content, String courseId, {required bool replay, required RoundOutcome outcome}) {
  final cs = save.courses[courseId]!;
  final run = cs.activeRun(replay: replay);
  final reward = roundReward(
    content.rules,
    hole: run.hole,
    won: outcome.won,
    wavesCleared: outcome.wavesCleared,
    totalWaves: outcome.totalWaves,
    replay: replay,
  );
  final pending = PendingResult(
    won: outcome.won,
    hole: run.hole,
    round: run.round,
    xp: reward.xp,
    tokens: reward.tokens,
    endCoins: outcome.endCoins,
    endTowers: outcome.endTowers,
    wavesCleared: outcome.wavesCleared,
    totalWaves: outcome.totalWaves,
    flagsLeft: outcome.flagsLeft,
    kills: outcome.kills,
    replay: replay,
  );
  cs.pendingResult = pending;
  return pending;
}

class CommitOutcome {
  CommitOutcome();

  /// Ranks reached, in order.
  final List<int> rankUps = [];

  /// Clubs newly revealed in the Pro Shop.
  final List<StoryClub> revealed = [];
  final List<String> newCaddies = [];
  int badges = 0;
  bool holeBeaten = false;
  bool courseComplete = false;
  bool replayFinished = false;
  String? unlockedCourse;
}

/// Applies the pending result: XP, tokens, reveals, coins, towers and progress.
CommitOutcome commitResult(StorySave save, StoryContent content, String courseId) {
  final out = CommitOutcome();
  final cs = save.courses[courseId]!;
  final pr = cs.pendingResult;
  if (pr == null) return out;
  cs.pendingResult = null;
  final r = content.rules;
  final course = content.course(courseId);

  // XP and rank.
  cs.xp += pr.xp;
  final maxRank = r.i('xp.rankMax');
  while (cs.rank < maxRank && cs.xp >= xpToNext(r, cs.rank)) {
    cs.xp -= xpToNext(r, cs.rank);
    cs.rank++;
    out.rankUps.add(cs.rank);
    out.revealed.addAll(course.clubs.where((c) => c.rank == cs.rank));
  }
  cs.tokens += pr.tokens;

  final run = cs.activeRun(replay: pr.replay);
  run.bankedBoost = null;
  if (!pr.won) return out; // coins and towers stay at the Tee Off snapshot.

  run.roundPerk = null;
  if (pr.round < r.roundsPerHole) {
    run.round++;
    run.coins = pr.endCoins;
    run.towers = [for (final t in pr.endTowers) t.copy()];
    return out;
  }

  out.holeBeaten = true;
  if (pr.replay) {
    cs.replayRun = null;
    out.replayFinished = true;
    return out;
  }
  if (pr.hole > cs.highestHoleBeaten) {
    cs.highestHoleBeaten = pr.hole;
    save.player.caddieBadges++;
    out.badges++;
    for (final c in content.caddies) {
      if (c.unlockHole > 0 && c.unlockHole <= pr.hole && !save.player.caddies.containsKey(c.id)) {
        save.player.caddies[c.id] = 1;
        out.newCaddies.add(c.id);
      }
    }
  }
  cs.current = HoleRun(hole: pr.hole + 1, coins: holeStartCoins(r, cs));
  if (pr.hole >= course.holeCount) {
    out.courseComplete = true;
    final next = content.nextCourse(courseId);
    if (next != null && next.available && !save.unlockedCourses.contains(next.id)) {
      save.unlockedCourses.add(next.id);
      out.unlockedCourse = next.id;
    }
  }
  return out;
}

/// Voids the round as if it was never played: drops the pending result (XP,
/// tokens, reveals), leaves coins and towers at the Tee Off snapshot and removes
/// this round's perk pick so the draft is offered again.
void concede(StorySave save, String courseId, {required bool replay}) {
  final cs = save.courses[courseId]!;
  final pr = cs.pendingResult;
  cs.pendingResult = null;
  final run = cs.activeRun(replay: pr?.replay ?? replay);
  final pick = run.roundPerk;
  if (pick != null) {
    run.perks.remove(pick);
    run.roundPerk = null;
  }
}

/// Starts a replay of a beaten hole: 150 coins, no saved towers, half rewards.
HoleRun startReplay(StorySave save, StoryContent content, String courseId, int hole) {
  final cs = save.courses[courseId]!;
  final run = HoleRun(hole: hole, coins: content.rules.i('coins.replayStart'), replay: true);
  cs.replayRun = run;
  return run;
}

/// Hole and round the player resumes at, as text.
String resumeLabel(CourseSave cs, CourseContent course) {
  if (cs.current.hole > course.holeCount) return 'Course complete';
  return 'Hole ${cs.current.hole}, round ${cs.current.round}';
}
