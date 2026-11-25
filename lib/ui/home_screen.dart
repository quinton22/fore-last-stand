import 'package:material_ui/material_ui.dart';

import '../data/modes.dart';
import '../meta/profile_store.dart';
import '../meta/progression.dart';
import 'bestiary_screen.dart';
import 'run_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.store});

  final ProfileStore store;

  void _range(BuildContext context) {
    store.update((p) {
      if (!p.tutorialSeen.contains('welcome')) p.tutorialSeen.add('welcome');
    });
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            RunScreen(store: store, config: rangeConfigFor(store.profile)),
      ),
    );
  }

  void _play(BuildContext context, ModeId mode) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            RunScreen(store: store, config: configFor(store.profile, mode)),
      ),
    );
  }

  void _open(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final p = store.profile;
        final today = dailySeed(DateTime.now());
        return Scaffold(
          backgroundColor: const Color(0xFF1B5E20),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const SizedBox(height: 12),
                const Text(
                  'FORE!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 52,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Text(
                  'LAST STAND',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.lightGreenAccent,
                    fontSize: 22,
                    letterSpacing: 6,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  children: [
                    Chip(label: Text('🪙 ${p.coins}')),
                    Chip(label: Text('🎟 ${p.clubTokens} tokens')),
                    Chip(label: Text('⭐ ${p.xp} XP')),
                  ],
                ),
                const SizedBox(height: 16),
                for (final m in modes)
                  Card(
                    child: ListTile(
                      title: Text(
                        m.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        [
                          '${m.length} · ${m.structure}',
                          if (m.id == ModeId.suddenDeath &&
                              p.bestSuddenDeath > 0)
                            'Best: ${p.bestSuddenDeath} holes',
                          if (m.id == ModeId.dailyTournament)
                            'Today: ${modifierNames[dailyModifier(today)]}',
                          if (m.id == ModeId.dailyTournament &&
                              p.lastDailySeed == today)
                            'Your best today: ${p.bestDailyScore}',
                        ].join('\n'),
                      ),
                      trailing: const Icon(Icons.play_arrow),
                      onTap: () => _play(context, m.id),
                    ),
                  ),
                Card(
                  color: const Color(0xFF33691E),
                  child: ListTile(
                    leading: const Icon(Icons.golf_course, color: Colors.white),
                    title: const Text(
                      'Driving Range',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    subtitle: Text(
                      p.tutorialSeen.contains('range')
                          ? 'Practice clubs, towers and Mulligan cards on targets.'
                          : 'Start here: a hands-on tutorial, then free practice.',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    trailing: const Icon(Icons.play_arrow, color: Colors.white),
                    onTap: () => _range(context),
                  ),
                ),

                for (final u in nearestUnlocks(p))
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${u.name}: ${u.have}/${u.need} ${u.currency}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        LinearProgressIndicator(
                          value: u.progress,
                          minHeight: 4,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
