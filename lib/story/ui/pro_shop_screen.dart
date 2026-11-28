import 'package:material_ui/material_ui.dart';

import '../progression.dart';
import 'club_text.dart';
import 'story_nav.dart';

/// Pro Shop (6a.6): each rank reveals one club; Club Tokens buy and level them.
class ProShopScreen extends StatelessWidget {
  const ProShopScreen({super.key, required this.deps, required this.courseId});

  final StoryDeps deps;
  final String courseId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: deps.story,
      builder: (context, _) {
        final store = deps.story;
        final rules = store.rules;
        final course = store.content.course(courseId);
        final cs = store.course(courseId);
        final revealed = revealedClubs(course, cs);
        final next = course.clubs.where((c) => c.rank == cs.rank + 1).firstOrNull;
        final maxLevel = maxClubLevel(rules);
        return Scaffold(
          appBar: AppBar(title: Text('Pro Shop · 🎟 ${cs.tokens}')),
          body: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Text('Rank ${cs.rank} on ${course.name}. Each rank-up reveals one club. Levels add +8% damage each; level $maxLevel also cuts the cooldown 10%.'),
              const SizedBox(height: 8),
              for (final c in revealed.reversed)
                () {
                  final level = clubLevel(cs, c.id);
                  final owned = level > 0;
                  final cost = owned ? levelCost(rules, level) : c.price;
                  final canAfford = cost != null && cs.tokens >= cost;
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(clubTitle(c), style: Theme.of(context).textTheme.titleMedium)),
                              Text('Rank ${c.rank}', style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                          Text(clubStatLine(rules, c, owned ? level : 1)),
                          Text(c.family.behavior, style: const TextStyle(fontSize: 12)),
                          if (c.effectText.isNotEmpty) Text('Special: ${c.effectText}', style: const TextStyle(fontStyle: FontStyle.italic)),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              if (owned) Text('Level $level/$maxLevel'),
                              const Spacer(),
                              FilledButton(
                                onPressed: canAfford
                                    ? () => store.update((_) => owned ? levelUpClub(rules, cs, c.id) : buyClub(rules, course, cs, c.id))
                                    : null,
                                child: Text(!owned ? 'Buy 🎟 ${c.price}' : (cost == null ? 'Max level' : 'Level up 🎟 $cost')),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }(),
              if (next != null)
                Card(
                  color: Colors.grey.shade200,
                  child: ListTile(
                    leading: const Icon(Icons.help_outline),
                    title: const Text('???'),
                    subtitle: Text('Reach rank ${next.rank} to reveal the next club.'),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
