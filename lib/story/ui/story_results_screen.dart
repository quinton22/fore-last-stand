import 'package:material_ui/material_ui.dart';

import '../progression.dart';
import '../save.dart';
import 'course_complete_screen.dart';
import 'story_nav.dart';

/// Results (6a.2 step 7). The round was saved the moment it ended; from here
/// the player continues or goes back to the Story menu.
class StoryResultsScreen extends StatelessWidget {
  const StoryResultsScreen({super.key, required this.deps, required this.courseId, required this.result, required this.outcome});

  final StoryDeps deps;
  final String courseId;
  final PendingResult result;
  final CommitOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final content = deps.story.content;
    final course = content.course(courseId);
    final pr = result;
    final out = outcome;
    final rounds = content.rules.roundsPerHole;
    final String title;
    final String primary;
    if (!pr.won) {
      title = 'The ball has fallen';
      primary = 'Retry Round';
    } else if (pr.round < rounds) {
      title = 'Round ${pr.round} won!';
      primary = 'Next Round';
    } else if (pr.replay) {
      title = 'Hole ${pr.hole} beaten again!';
      primary = 'Back to Map';
    } else if (out.courseComplete) {
      title = '${course.name} complete!';
      primary = 'Finish Course';
    } else {
      title = 'Hole ${pr.hole} beaten!';
      primary = 'Next Hole';
    }

    void onPrimary() {
      if (!pr.won || pr.round < rounds) {
        replaceWithRound(context, deps, courseId, replay: pr.replay);
      } else if (pr.replay) {
        openHoleMap(context, deps, courseId);
      } else if (out.courseComplete) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => CourseCompleteScreen(deps: deps, courseId: courseId, outcome: out),
          ),
        );
      } else {
        replaceWithRound(context, deps, courseId, replay: false);
      }
    }

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: storyGreen,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '${pr.replay ? 'Replay · ' : ''}Hole ${pr.hole} · ${course.hole(pr.hole).name} · Round ${pr.round}/$rounds',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      _row('Flags left', pr.flagsLeft == 0 ? '0' : '🚩' * pr.flagsLeft),
                      _row('Waves cleared', '${pr.wavesCleared}/${pr.totalWaves}'),
                      _row('XP', '+${pr.xp}'),
                      _row('Club Tokens', '+${pr.tokens}'),
                      if (pr.won && pr.round < rounds) _row('Coins carried to round ${pr.round + 1}', '🪙 ${pr.endCoins}'),
                      if (pr.won && pr.round < rounds) _row('Towers carried', '${pr.endTowers.length}'),
                      if (!pr.won) _row('Coins and towers', 'back to Tee Off'),
                    ],
                  ),
                ),
              ),
              for (final r in out.rankUps)
                Card(
                  color: Colors.amber.shade100,
                  child: ListTile(
                    leading: const Icon(Icons.military_tech),
                    title: Text('Rank $r on ${course.name}!'),
                    subtitle: Text(
                      [for (final c in out.revealed.where((c) => c.rank == r)) 'New in the Pro Shop: ${c.name} (${c.tierName} ${c.family.name}), 🎟 ${c.price}']
                          .join('\n'),
                    ),
                  ),
                ),
              if (out.badges > 0)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.verified),
                    title: Text('+${out.badges} Caddie Badge'),
                    subtitle: const Text('Spend badges to rank up caddies.'),
                  ),
                ),
              for (final id in out.newCaddies)
                Card(
                  color: Colors.lightBlue.shade50,
                  child: ListTile(
                    leading: const Icon(Icons.person_add),
                    title: Text('New caddie: ${content.caddie(id).name}'),
                    subtitle: Text(content.caddie(id).passiveText),
                  ),
                ),
              const SizedBox(height: 8),
              const Text(
                'Progress saved.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
              const SizedBox(height: 12),
              FilledButton(onPressed: onPrimary, child: Text(primary)),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => openHoleMap(context, deps, courseId),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                child: const Text('Story Menu'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    ),
  );
}
