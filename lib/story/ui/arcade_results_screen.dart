import 'package:material_ui/material_ui.dart';

import '../arcade.dart';
import '../sim/round_sim.dart';
import 'round_screen.dart';
import 'story_nav.dart';

/// End of a Sudden Death or Daily Tournament run.
class ArcadeResultsScreen extends StatelessWidget {
  const ArcadeResultsScreen({super.key, required this.deps, required this.result, required this.seed});

  final StoryDeps deps;
  final ArcadeResult result;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final endless = result.mode == RoundMode.endless;
    return Scaffold(
      backgroundColor: storyGreen,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              endless ? 'Sudden Death' : 'Daily Tournament',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 6),
            Text(
              result.newBest ? 'New best!' : 'Run over',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    _row('Waves cleared', '${result.waves}'),
                    _row('Kills', '${result.kills}'),
                    if (!endless) _row('Score', '${result.score}'),
                    _row(endless ? 'Best (waves)' : 'Your best today', '${result.best}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (endless)
              FilledButton(
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => RoundScreen(deps: deps, mode: RoundMode.endless, seed: DateTime.now().microsecondsSinceEpoch & 0x7fffffff),
                  ),
                ),
                child: const Text('Play again'),
              ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => goHome(context),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('Main Menu'),
            ),
          ],
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
