import 'package:material_ui/material_ui.dart';

import '../range_lessons.dart';
import '../sim/round_sim.dart';

/// The guided-lesson card shown over the top of the Driving Range.
class LessonCard extends StatelessWidget {
  const LessonCard({
    super.key,
    required this.lesson,
    required this.index,
    required this.total,
    required this.done,
    required this.showTips,
    required this.onToggleTips,
    required this.onNext,
    required this.onSkip,
  });

  final RangeLesson lesson;
  final int index;
  final int total;
  final bool done;
  final bool showTips;
  final VoidCallback onToggleTips;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final light = TextButton.styleFrom(foregroundColor: Colors.lightGreenAccent);
    return Card(
      color: const Color(0xF0263238),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
        child: DefaultTextStyle(
          style: const TextStyle(color: Colors.white, fontSize: 13),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Lesson ${index + 1} of $total', style: const TextStyle(color: Colors.white54, fontSize: 11)),
              Text(lesson.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Text(lesson.body),
              if (showTips)
                for (final t in lesson.tips)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text('• $t', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ),
              if (lesson.goal != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      Icon(done ? Icons.check_circle : Icons.radio_button_unchecked, size: 18, color: done ? Colors.lightGreenAccent : Colors.white54),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(lesson.goal!, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 4,
                children: [
                  if (lesson.tips.isNotEmpty) TextButton(style: light, onPressed: onToggleTips, child: Text(showTips ? 'Hide tips' : 'Tips')),
                  TextButton(style: light, onPressed: onSkip, child: const Text('Skip tutorial')),
                  if (lesson.goal != null && !done) TextButton(style: light, onPressed: onNext, child: const Text('Skip lesson')),
                  if (lesson.goal == null || done) FilledButton(onPressed: onNext, child: Text(index + 1 >= total ? 'Finish' : 'Next')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Range tools: spawn targets and live animals, put up a flag, try perks.
Future<void> showRangeTools(BuildContext context, RoundSim sim, {required VoidCallback onReplay, required VoidCallback onChanged}) {
  final content = sim.content;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (c) => StatefulBuilder(
      builder: (c, setSheet) {
        void act(VoidCallback f) {
          f();
          onChanged();
          setSheet(() {});
        }

        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(c).size.height * 0.7,
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Text('Range tools', style: Theme.of(c).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text('Swings ${sim.swings} · Sweet Spots ${sim.sweetSwings} · Damage ${sim.damageDealt.round()} · Last hit ${sim.lastHit.toStringAsFixed(1)}'),
                const SizedBox(height: 8),
                const Text('Targets', style: TextStyle(fontWeight: FontWeight.bold)),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final id in const ['dummy', 'dummy_air', 'dummy_tank'])
                      ActionChip(label: Text(content.enemy(id).name), onPressed: () => act(() => sim.spawnTarget(id))),
                    ActionChip(label: const Text('Flag'), onPressed: () => act(sim.spawnPin)),
                    ActionChip(
                      label: const Text('Clear'),
                      onPressed: () => act(() {
                        for (final e in sim.enemies) {
                          e.removed = true;
                        }
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('Live animals (they attack towers but cannot hurt you here)', style: TextStyle(fontWeight: FontWeight.bold)),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final e in content.enemies.values.where((e) => e.spawnable))
                      ActionChip(label: Text(e.name), onPressed: () => act(() => sim.spawnEnemy(e.id))),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('Perks', style: TextStyle(fontWeight: FontWeight.bold)),
                for (final p in content.perks)
                  CheckboxListTile(
                    dense: true,
                    value: sim.perks.contains(p.id),
                    title: Text(p.name),
                    subtitle: Text(p.text),
                    onChanged: (v) => act(() => v == true ? sim.addPerk(p.id) : sim.perks.remove(p.id)),
                  ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () {
                    Navigator.of(c).pop();
                    onReplay();
                  },
                  child: const Text('Replay the tutorial'),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
