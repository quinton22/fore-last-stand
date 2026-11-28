import 'package:material_ui/material_ui.dart';

import '../progression.dart';
import 'story_nav.dart';

/// Caddies (6a.11): equip one; ranks cost Caddie Badges. Caddies travel between courses.
class StoryCaddiesScreen extends StatelessWidget {
  const StoryCaddiesScreen({super.key, required this.deps});

  final StoryDeps deps;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: deps.story,
      builder: (context, _) {
        final store = deps.story;
        final rules = store.rules;
        final p = store.save.player;
        return Scaffold(
          appBar: AppBar(title: Text('Caddies · ${p.caddieBadges} badges')),
          body: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              const Text('One Caddie Badge for each hole beaten for the first time, on any course. Each rank raises both effects by 10% of their base.'),
              const SizedBox(height: 8),
              for (final c in store.content.caddies)
                () {
                  final rank = p.caddies[c.id];
                  final scale = caddieScale(rules, rank ?? 1);
                  final cost = rank == null ? null : caddieRankCost(rules, rank);
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(backgroundColor: Color(c.color), child: Text(c.name[0])),
                              const SizedBox(width: 12),
                              Expanded(child: Text(c.name, style: Theme.of(context).textTheme.titleMedium)),
                              if (rank != null) Text('Rank $rank/${maxCaddieRank(rules)}'),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text('Passive: ${c.passiveText} (now +${(c.passiveValue * scale * 100).round()}%)'),
                          Text('Once per round, ${c.activeName}: ${c.activeText}'),
                          const SizedBox(height: 8),
                          if (rank == null)
                            Text('Locked: ${c.unlockText}', style: const TextStyle(fontStyle: FontStyle.italic))
                          else
                            Row(
                              children: [
                                OutlinedButton(
                                  onPressed: p.equippedCaddie == c.id ? null : () => store.update((s) => s.player.equippedCaddie = c.id),
                                  child: Text(p.equippedCaddie == c.id ? 'Equipped ✓' : 'Equip'),
                                ),
                                const Spacer(),
                                FilledButton(
                                  onPressed: cost != null && p.caddieBadges >= cost ? () => store.update((s) => rankUpCaddie(rules, s.player, c.id)) : null,
                                  child: Text(cost == null ? 'Max rank' : 'Rank up · $cost badge${cost == 1 ? '' : 's'}'),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  );
                }(),
            ],
          ),
        );
      },
    );
  }
}
