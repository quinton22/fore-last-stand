import 'package:material_ui/material_ui.dart';

import '../meta/profile_store.dart';
import '../story/story_store.dart';

/// Bestiary (spec 7): every animal and boss, what it does, and kills toward completion.
class BestiaryScreen extends StatelessWidget {
  const BestiaryScreen({super.key, required this.store, required this.story});

  final ProfileStore store;
  final StoryStore story;

  /// Kills to complete an entry.
  static const int entryGoal = 50;

  @override
  Widget build(BuildContext context) {
    final p = store.profile;
    final content = story.content;
    final animals = content.enemies.values.where((e) => e.spawnable).toList()..sort((a, b) => a.firstHole.compareTo(b.firstHole));
    final entries = <(String id, String name, int color, String text)>[
      for (final e in animals) (e.id, e.name, e.color, '${e.description}\nFirst seen on hole ${e.firstHole}. Good against it: ${e.counter}'),
      for (final b in content.bosses) (b.id, b.name, b.color, 'Boss. ${b.text}.\nFinal boss of holes ${b.holes.join(', ')}.'),
    ];
    final done = entries.where((e) => (p.bestiary[e.$1] ?? 0) >= entryGoal).length;
    return Scaffold(
      appBar: AppBar(title: Text('Bestiary  ·  $done/${entries.length} complete')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('Every animal has a trick. Read up here before you meet them. Kills fill the bar on each entry.'),
          ),
          for (final e in entries)
            Card(
              child: ListTile(
                leading: CircleAvatar(backgroundColor: Color(e.$3)),
                title: Text(e.$2),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.$4),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(value: ((p.bestiary[e.$1] ?? 0) / entryGoal).clamp(0.0, 1.0)),
                  ],
                ),
                trailing: Text('${p.bestiary[e.$1] ?? 0}/$entryGoal'),
              ),
            ),
        ],
      ),
    );
  }
}
