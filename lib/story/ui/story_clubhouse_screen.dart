import 'package:material_ui/material_ui.dart';

import '../progression.dart';
import 'story_nav.dart';

/// Clubhouse (6a.11): per course, paid with that course's Club Tokens.
class StoryClubhouseScreen extends StatelessWidget {
  const StoryClubhouseScreen({super.key, required this.deps, required this.courseId});

  final StoryDeps deps;
  final String courseId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: deps.story,
      builder: (context, _) {
        final store = deps.story;
        final rules = store.rules;
        final cs = store.course(courseId);
        return Scaffold(
          appBar: AppBar(title: Text('Clubhouse · 🎟 ${cs.tokens}')),
          body: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Text('Upgrades belong to ${store.content.course(courseId).name}. The tee box stays 4x4.'),
              const SizedBox(height: 8),
              for (final w in rules.clubhouse)
                () {
                  final tier = cs.wingTier(w.id);
                  final maxed = tier >= w.maxTier;
                  return Card(
                    child: ListTile(
                      title: Text('${w.name}  ($tier/${w.maxTier})'),
                      subtitle: Text('${w.description} per tier.'),
                      trailing: maxed
                          ? const Text('Max')
                          : FilledButton(
                              onPressed: cs.tokens >= w.costs[tier] ? () => store.update((_) => buyWing(rules, cs, w.id)) : null,
                              child: Text('🎟 ${w.costs[tier]}'),
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
