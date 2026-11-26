import 'package:material_ui/material_ui.dart';

import '../meta/profile_store.dart';
import '../story/arcade.dart';
import '../story/progression.dart' as story_rules;
import '../story/sim/round_sim.dart';
import '../story/story_store.dart';
import '../story/ui/course_select_screen.dart';
import '../story/ui/round_screen.dart';
import '../story/ui/story_nav.dart';
import 'bestiary_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.store, required this.story});

  final ProfileStore store;
  final StoryStore story;

  StoryDeps get deps => StoryDeps(profile: store, story: story);

  void _open(BuildContext context, Widget screen) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  void _range(BuildContext context) {
    store.update((p) {
      if (!p.tutorialSeen.contains('welcome')) p.tutorialSeen.add('welcome');
    });
    _open(context, RoundScreen(deps: deps, mode: RoundMode.range, seed: DateTime.now().microsecondsSinceEpoch & 0x7fffffff));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([store, story]),
      builder: (context, _) {
        final p = store.profile;
        final today = dailySeed(DateTime.now());
        return Scaffold(
          backgroundColor: storyGreen,
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const SizedBox(height: 12),
                const Text(
                  'FORE!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 52, fontWeight: FontWeight.w900),
                ),
                const Text(
                  'LAST STAND',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.lightGreenAccent, fontSize: 22, letterSpacing: 6),
                ),
                const SizedBox(height: 16),
                _storyCard(context),
                const Padding(
                  padding: EdgeInsets.fromLTRB(4, 12, 4, 4),
                  child: Text(
                    'Arcade',
                    style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, letterSpacing: 2),
                  ),
                ),
                Card(
                  child: ListTile(
                    title: const Text('Sudden Death', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(['Endless waves, one flag. Uses your Story bag.', if (p.bestSuddenDeath > 0) 'Best: ${p.bestSuddenDeath} waves'].join('\n')),
                    trailing: const Icon(Icons.play_arrow),
                    onTap: () => _open(context, RoundScreen(deps: deps, mode: RoundMode.endless, seed: DateTime.now().microsecondsSinceEpoch & 0x7fffffff)),
                  ),
                ),
                Card(
                  child: ListTile(
                    title: const Text('Daily Tournament', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      [
                        'Same hole and seed for everyone today: 5 waves, then a boss.',
                        'Today: ${modifierNames[dailyModifier(today)]}',
                        if (p.lastDailySeed == today) 'Your best today: ${p.bestDailyScore}',
                      ].join('\n'),
                    ),
                    trailing: const Icon(Icons.play_arrow),
                    onTap: () => _open(context, RoundScreen(deps: deps, mode: RoundMode.daily, seed: today)),
                  ),
                ),
                Card(
                  color: const Color(0xFF33691E),
                  child: ListTile(
                    leading: const Icon(Icons.golf_course, color: Colors.white),
                    title: const Text(
                      'Driving Range',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    subtitle: Text(
                      p.tutorialSeen.contains('range')
                          ? 'Practice clubs, towers and perks on targets.'
                          : 'Start here: a hands-on tutorial, then free practice.',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    trailing: const Icon(Icons.play_arrow, color: Colors.white),
                    onTap: () => _range(context),
                  ),
                ),
                if (!p.tutorialSeen.contains('welcome')) _welcome(context),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _NavButton(
                      icon: Icons.menu_book,
                      label: 'Bestiary',
                      onTap: () => _open(context, BestiaryScreen(store: store, story: story)),
                    ),
                    _NavButton(
                      icon: Icons.settings,
                      label: 'Settings',
                      onTap: () => _open(context, SettingsScreen(store: store)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _storyCard(BuildContext context) {
    final content = story.content;
    final courseId = arcadeCourse(story);
    final course = content.course(courseId);
    final cs = story.course(courseId);
    return Card(
      color: Colors.amber.shade100,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: const Icon(Icons.flag, size: 40, color: Color(0xFFC62828)),
        title: const Text('Story', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22)),
        subtitle: Text(
          '${course.name}: ${story_rules.resumeLabel(cs, course)} · Rank ${cs.rank}\nHoles of 3 rounds each. Earn clubs, towers carry between rounds.',
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.play_arrow),
        onTap: () => _open(context, CourseSelectScreen(deps: deps)),
      ),
    );
  }

  Widget _welcome(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Welcome to Fore! Last Stand', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              IconButton(tooltip: 'Dismiss', onPressed: () => store.update((p) => p.tutorialSeen.add('welcome')), icon: const Icon(Icons.close)),
            ],
          ),
          const Text(
            'The course is overrun with zombie animals and you are the last one standing. Two places to learn the ropes:\n\n'
            '⛳ Driving Range: a guided tutorial on swinging, clubs, towers and perks, then free practice on targets.\n\n'
            '📖 Bestiary: what every animal does and what counters it.',
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              FilledButton(onPressed: () => _range(context), child: const Text('Open Driving Range')),
              OutlinedButton(
                onPressed: () {
                  store.update((p) => p.tutorialSeen.add('welcome'));
                  _open(context, BestiaryScreen(store: store, story: story));
                },
                child: const Text('Read animal guide'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      child: FilledButton.tonal(
        onPressed: onTap,
        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
        child: Column(children: [Icon(icon), Text(label)]),
      ),
    );
  }
}
