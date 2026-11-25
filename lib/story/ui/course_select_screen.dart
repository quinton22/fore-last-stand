import 'package:material_ui/material_ui.dart';

import '../progression.dart';
import 'hole_map_screen.dart';
import 'story_nav.dart';

/// Course select (6a.2 step 2): locked courses greyed out, with holes beaten and rank.
class CourseSelectScreen extends StatelessWidget {
  const CourseSelectScreen({super.key, required this.deps});

  final StoryDeps deps;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: deps.story,
      builder: (context, _) {
        final store = deps.story;
        final content = store.content;
        return Scaffold(
          backgroundColor: storyGreen,
          appBar: AppBar(title: const Text('Story · Choose a course')),
          body: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              for (final info in content.courses)
                () {
                  final open = courseUnlocked(store.save, content, info.id);
                  final course = content.courseContent[info.id];
                  final cs = open ? store.course(info.id) : null;
                  return Opacity(
                    opacity: open ? 1 : 0.45,
                    child: Card(
                      child: ListTile(
                        leading: Icon(open ? Icons.golf_course : Icons.lock, size: 36),
                        title: Text(info.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          open && course != null && cs != null
                              ? '${info.description}\n${cs.highestHoleBeaten}/${course.holeCount} holes beaten · Rank ${cs.rank} · ${resumeLabel(cs, course)}'
                              : (info.available ? 'Beat the previous course to unlock.' : 'Coming soon.'),
                        ),
                        isThreeLine: open,
                        trailing: open ? const Icon(Icons.chevron_right) : null,
                        onTap: open
                            ? () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => HoleMapScreen(deps: deps, courseId: info.id),
                                ),
                              )
                            : null,
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
