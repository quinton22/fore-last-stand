import 'package:material_ui/material_ui.dart';

import '../progression.dart';
import 'club_text.dart';
import 'story_nav.dart';

/// The Bag (6a.6): 3 slots, at most one club per family, only bought clubs.
class StoryBagScreen extends StatelessWidget {
  const StoryBagScreen({super.key, required this.deps, required this.courseId});

  final StoryDeps deps;
  final String courseId;

  Future<void> _equip(BuildContext context, String clubId) async {
    final store = deps.story;
    final course = store.content.course(courseId);
    final cs = store.course(courseId);
    if (store.update((_) => equipClub(course, cs, clubId))) return;
    // Bag is full and no club of this family: ask which slot to replace.
    final slot = await showDialog<int>(
      context: context,
      builder: (c) => SimpleDialog(
        title: Text('Replace which club with ${course.club(clubId).name}?'),
        children: [
          for (var i = 0; i < cs.bag.length; i++)
            SimpleDialogOption(onPressed: () => Navigator.of(c).pop(i), child: Text(cs.bag[i] == null ? 'Empty slot' : course.club(cs.bag[i]!).name)),
        ],
      ),
    );
    if (slot != null) store.update((_) => equipClub(course, cs, clubId, slot: slot));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: deps.story,
      builder: (context, _) {
        final store = deps.story;
        final rules = store.rules;
        final course = store.content.course(courseId);
        final cs = store.course(courseId);
        final owned = course.clubs.where((c) => cs.ownedClubs.containsKey(c.id)).toList();
        final unbought = revealedClubs(course, cs).where((c) => !cs.ownedClubs.containsKey(c.id)).toList();
        return Scaffold(
          appBar: AppBar(title: Text('Bag · ${course.name}')),
          body: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              const Text(
                '3 slots, at most one club per family. Equipping a club from a family already in the bag replaces it. '
                'Change the bag here or between rounds, never during a round.',
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (var i = 0; i < cs.bag.length; i++)
                    Expanded(
                      child: Card(
                        color: cs.bag[i] == null ? Colors.grey.shade200 : Colors.lightGreen.shade100,
                        child: InkWell(
                          onTap: cs.bag[i] == null ? null : () => store.update((_) => unequipSlot(cs, i)),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              children: [
                                Text('Slot ${i + 1}', style: const TextStyle(fontSize: 11)),
                                Text(
                                  cs.bag[i] == null ? 'Empty' : course.club(cs.bag[i]!).name,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                if (cs.bag[i] != null) Text(course.club(cs.bag[i]!).family.name, style: const TextStyle(fontSize: 11)),
                                if (cs.bag[i] != null) const Text('tap to remove', style: TextStyle(fontSize: 10, color: Colors.black54)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text('Your clubs', style: Theme.of(context).textTheme.titleMedium),
              for (final c in owned)
                Card(
                  child: ListTile(
                    title: Text(clubTitle(c)),
                    subtitle: Text(
                      'Level ${cs.ownedClubs[c.id]} · ${clubStatLine(rules, c, cs.ownedClubs[c.id]!)}\n${c.family.behavior}${c.effectText.isEmpty ? '' : '\n${c.effectText}'}',
                    ),
                    isThreeLine: true,
                    trailing: cs.bag.contains(c.id)
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : FilledButton(onPressed: () => _equip(context, c.id), child: const Text('Equip')),
                  ),
                ),
              if (unbought.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Revealed, not bought', style: Theme.of(context).textTheme.titleMedium),
                for (final c in unbought)
                  Card(
                    color: Colors.grey.shade200,
                    child: ListTile(
                      leading: const Icon(Icons.lock_outline),
                      title: Text(clubTitle(c)),
                      subtitle: Text('Buy it in the Pro Shop for 🎟 ${c.price} to equip it.'),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}
