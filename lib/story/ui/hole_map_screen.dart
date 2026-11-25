import 'package:material_ui/material_ui.dart';

import '../progression.dart';
import 'pro_shop_screen.dart';
import 'round_screen.dart';
import 'story_bag_screen.dart';
import 'story_caddies_screen.dart';
import 'story_clubhouse_screen.dart';
import 'story_nav.dart';

/// Hole map (6a.2 step 3): every hole, the current one highlighted, and the
/// course's Bag, Pro Shop, Clubhouse and Caddies.
class HoleMapScreen extends StatelessWidget {
  const HoleMapScreen({super.key, required this.deps, required this.courseId});

  final StoryDeps deps;
  final String courseId;

  void _open(BuildContext context, Widget screen) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  void _play(BuildContext context, {bool replay = false}) => _open(context, RoundScreen(deps: deps, courseId: courseId, replay: replay));

  Future<void> _replay(BuildContext context, int hole) async {
    final cs = deps.story.course(courseId);
    if (cs.replayRun != null && cs.replayRun!.hole != hole) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Start a new replay?'),
          content: Text('Your replay of hole ${cs.replayRun!.hole} will be abandoned.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.of(c).pop(true), child: Text('Replay hole $hole')),
          ],
        ),
      );
      if (ok != true || !context.mounted) return;
    }
    if (cs.replayRun?.hole != hole) deps.story.update((s) => startReplay(s, deps.story.content, courseId, hole));
    _play(context, replay: true);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: deps.story,
      builder: (context, _) {
        final store = deps.story;
        final content = store.content;
        final course = content.course(courseId);
        final cs = store.course(courseId);
        final rules = content.rules;
        final finished = cs.current.hole > course.holeCount;
        final maxRank = rules.i('xp.rankMax');
        final need = xpToNext(rules, cs.rank);
        return Scaffold(
          backgroundColor: storyGreen,
          appBar: AppBar(title: Text(course.name)),
          body: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Rank ${cs.rank}', style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('🎟 ${cs.tokens} tokens', textAlign: TextAlign.right, overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (cs.rank < maxRank) ...[
                        LinearProgressIndicator(value: (cs.xp / need).clamp(0.0, 1.0), minHeight: 6),
                        const SizedBox(height: 2),
                        Text('${cs.xp}/$need XP to rank ${cs.rank + 1}: reveals a new club', style: const TextStyle(fontSize: 12)),
                      ] else
                        const Text('Max rank'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 1.1,
                children: [for (final h in course.holes) _holeTile(context, h.number, h.name, cs.current.hole, cs.highestHoleBeaten, cs.current.round)],
              ),
              const SizedBox(height: 10),
              if (cs.replayRun != null)
                Card(
                  color: Colors.lightBlue.shade50,
                  child: ListTile(
                    leading: const Icon(Icons.replay),
                    title: Text('Replay in progress: hole ${cs.replayRun!.hole}, round ${cs.replayRun!.round}'),
                    subtitle: const Text('Half XP and tokens. Does not change your story progress.'),
                    trailing: FilledButton(onPressed: () => _play(context, replay: true), child: const Text('Continue')),
                  ),
                ),
              if (finished)
                const Card(
                  child: ListTile(leading: Icon(Icons.emoji_events), title: Text('Course complete'), subtitle: Text('Tap a beaten hole to replay it.')),
                )
              else
                FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56), backgroundColor: Colors.amber, foregroundColor: Colors.black),
                  onPressed: () => _play(context),
                  icon: const Icon(Icons.play_arrow),
                  label: Text('Play: ${resumeLabel(cs, course)}', style: const TextStyle(fontSize: 18)),
                ),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  _nav(context, Icons.sports_golf, 'Bag', StoryBagScreen(deps: deps, courseId: courseId)),
                  _nav(context, Icons.storefront, 'Pro Shop', ProShopScreen(deps: deps, courseId: courseId)),
                  _nav(context, Icons.house, 'Clubhouse', StoryClubhouseScreen(deps: deps, courseId: courseId)),
                  _nav(context, Icons.person, 'Caddies', StoryCaddiesScreen(deps: deps)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _nav(BuildContext context, IconData icon, String label, Widget screen) => SizedBox(
    width: 84,
    child: FilledButton.tonal(
      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
      onPressed: () => _open(context, screen),
      child: Column(
        children: [
          Icon(icon),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    ),
  );

  Widget _holeTile(BuildContext context, int n, String name, int current, int beaten, int round) {
    final isBeaten = n <= beaten;
    final isCurrent = n == current;
    final color = isCurrent ? Colors.amber.shade200 : (isBeaten ? Colors.green.shade100 : Colors.grey.shade400);
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: isBeaten ? () => _replay(context, n) : (isCurrent ? () => _play(context) : null),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$n', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              Text(name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
              Text(
                isBeaten ? '✓ Replay' : (isCurrent ? 'Round $round/${deps.story.rules.roundsPerHole}' : '🔒'),
                style: TextStyle(fontSize: 11, fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
