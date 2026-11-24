import 'package:material_ui/material_ui.dart';

import '../data/enemies.dart';
import '../data/perks.dart';
import '../sim/battle.dart';
import '../sim/range_lessons.dart';
import 'run_screen.dart' show rarityColors;

/// Top bar for the Driving Range: live damage readouts instead of hole info.
class RangeTopBar extends StatelessWidget {
  const RangeTopBar({super.key, required this.battle, required this.onPause, required this.onTools});

  final Battle battle;
  final VoidCallback onPause;
  final VoidCallback onTools;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0x99000000),
      padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.white, fontSize: 13),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Driving Range', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text(
                    'Last hit ${battle.lastHit.toStringAsFixed(1)}  ·  Total ${battle.rangeDamage.round()}  ·  Swings ${battle.swings}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    '${battle.combo.name} x${battle.combo.coinMultiplier}',
                    style: TextStyle(color: battle.combo.rung >= 2 ? Colors.yellowAccent : Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: onTools,
              icon: const Icon(Icons.tune, color: Colors.white, size: 18),
              label: const Text('Range tools', style: TextStyle(color: Colors.white)),
            ),
            IconButton(onPressed: onPause, icon: const Icon(Icons.pause, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

/// The guided-lesson card shown over the top of the range.
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
    final last = index == total - 1;
    return Card(
      color: const Color(0xF0263238),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: DefaultTextStyle(
          style: const TextStyle(color: Colors.white, fontSize: 13),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Lesson ${index + 1} of $total', style: const TextStyle(color: Colors.lightGreenAccent, fontSize: 11)),
              Text(lesson.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(lesson.body),
              if (showTips)
                for (final t in lesson.tips)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('•  $t', style: const TextStyle(color: Colors.white70)),
                  ),
              if (lesson.goal != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${done ? '✅' : '🎯'} ${lesson.goal}',
                    style: TextStyle(fontWeight: FontWeight.bold, color: done ? Colors.lightGreenAccent : Colors.amberAccent),
                  ),
                ),
              Row(
                children: [
                  if (lesson.tips.isNotEmpty)
                    TextButton(onPressed: onToggleTips, child: Text(showTips ? 'Hide details' : 'More details')),
                  const Spacer(),
                  TextButton(onPressed: onSkip, child: const Text('Skip tutorial')),
                  FilledButton(onPressed: onNext, child: Text(last ? 'Start practicing' : (done ? 'Next' : 'Skip lesson'))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Free-practice tools: spawn targets, try any Mulligan card, reset stats, replay the tutorial.
void showRangeTools(BuildContext context, Battle battle, {required VoidCallback onReplay}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF263238),
    builder: (_) => _RangeTools(battle: battle, onReplay: onReplay),
  );
}

class _RangeTools extends StatefulWidget {
  const _RangeTools({required this.battle, required this.onReplay});

  final Battle battle;
  final VoidCallback onReplay;

  @override
  State<_RangeTools> createState() => _RangeToolsState();
}

class _RangeToolsState extends State<_RangeTools> {
  @override
  Widget build(BuildContext context) {
    final b = widget.battle;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Range tools', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('Spawn a target', style: TextStyle(color: Colors.white70)),
            Wrap(
              spacing: 8,
              children: [
                for (final t in rangeTargets)
                  ActionChip(
                    avatar: CircleAvatar(backgroundColor: Color(t.colorValue)),
                    label: Text('${t.name} (${t.health.round()} HP)'),
                    onPressed: () => b.spawnTarget(t.id),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  onPressed: () => setState(b.resetRangeStats),
                  child: const Text('Reset stats'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onReplay();
                  },
                  child: const Text('Replay tutorial'),
                ),
              ],
            ),
            const Divider(),
            Row(
              children: [
                const Expanded(
                  child: Text('Mulligan cards (tap to add or remove)', style: TextStyle(color: Colors.white70)),
                ),
                TextButton(onPressed: () => setState(b.perksTaken.clear), child: const Text('Clear all')),
              ],
            ),
            for (final p in perks)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  b.perksTaken.contains(p.id) ? Icons.check_circle : Icons.circle_outlined,
                  color: rarityColors[p.rarity],
                ),
                title: Text(p.name, style: const TextStyle(color: Colors.white)),
                subtitle: Text('${p.description}  (${p.rarity.name}, ${p.set.name})', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                onTap: () => setState(() {
                  if (!b.perksTaken.remove(p.id)) b.perksTaken.add(p.id);
                }),
              ),
          ],
        ),
      ),
    );
  }
}
