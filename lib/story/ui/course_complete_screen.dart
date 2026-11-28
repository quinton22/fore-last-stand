import 'package:material_ui/material_ui.dart';

import '../progression.dart';
import 'story_nav.dart';

/// Shown after the last hole in `holes.json` is beaten.
class CourseCompleteScreen extends StatelessWidget {
  const CourseCompleteScreen({super.key, required this.deps, required this.courseId, required this.outcome});

  final StoryDeps deps;
  final String courseId;
  final CommitOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final content = deps.story.content;
    final course = content.course(courseId);
    final cs = deps.story.course(courseId);
    final next = outcome.unlockedCourse == null ? null : content.courseContent[outcome.unlockedCourse!]?.info;
    return Scaffold(
      backgroundColor: storyGreen,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.emoji_events, color: Colors.amber, size: 72),
                const SizedBox(height: 8),
                const Text(
                  'Course Complete',
                  style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900),
                ),
                Text(course.name, style: const TextStyle(color: Colors.white70, fontSize: 18)),
                const SizedBox(height: 16),
                Text('All ${course.holeCount} holes beaten · rank ${cs.rank}', style: const TextStyle(color: Colors.white)),
                const SizedBox(height: 8),
                Text(
                  next != null ? '${next.name} is now unlocked!' : 'More holes and courses are on the way. Replay any hole for half XP and tokens.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 24),
                FilledButton(onPressed: () => openHoleMap(context, deps, courseId), child: const Text('Hole map')),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => goHome(context),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                  child: const Text('Main Menu'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
