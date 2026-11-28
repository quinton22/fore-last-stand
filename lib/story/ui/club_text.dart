import '../content.dart';

/// One-line stats for a club at [level].
String clubStatLine(Rules r, StoryClub c, int level) {
  final f = c.family;
  final dmg = f.damage * r.tierMultiplier(c.tier) * (1 + r.n('tokens.levelDamage') * (level - 1));
  final maxLevel = r.list('tokens.levelCosts').length + 1;
  final cd = f.cooldown * (level >= maxLevel ? 1 - r.n('tokens.maxLevelCooldownCut') : 1);
  return 'Damage ${dmg.toStringAsFixed(1)} · cooldown ${cd.toStringAsFixed(2)} s · range ${f.range.round()}';
}

String clubTitle(StoryClub c) => '${c.name} · ${c.tierName} ${c.family.name}';
