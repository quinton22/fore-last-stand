import 'package:material_ui/material_ui.dart';

import '../../meta/profile_store.dart';
import '../ads.dart';
import '../story_store.dart';
import 'course_select_screen.dart';
import 'hole_map_screen.dart';
import 'round_screen.dart';

/// What every Story screen needs.
class StoryDeps {
  const StoryDeps({required this.profile, required this.story, this.adsOverride});

  final ProfileStore profile;
  final StoryStore story;
  final AdService? adsOverride;

  /// No ad SDK yet: the Test ads setting turns on a stand-in.
  AdService get ads => adsOverride ?? (profile.profile.settings.testAds ? const SimulatedAdService() : const NoAdService());
}

const Color storyGreen = Color(0xFF1B5E20);
const Color storyDark = Color(0xFF102614);

/// Main menu.
void goHome(BuildContext context) => Navigator.of(context).popUntil((r) => r.isFirst);

/// Main menu, then Story, then the course's hole map.
void openHoleMap(BuildContext context, StoryDeps deps, String courseId) {
  final nav = Navigator.of(context);
  nav.popUntil((r) => r.isFirst);
  nav.push(MaterialPageRoute(builder: (_) => CourseSelectScreen(deps: deps)));
  nav.push(
    MaterialPageRoute(
      builder: (_) => HoleMapScreen(deps: deps, courseId: courseId),
    ),
  );
}

/// Prep for the next round, replacing the current screen.
void replaceWithRound(BuildContext context, StoryDeps deps, String courseId, {required bool replay}) {
  Navigator.of(context).pushReplacement(
    MaterialPageRoute(
      builder: (_) => RoundScreen(deps: deps, courseId: courseId, replay: replay),
    ),
  );
}

Future<bool> confirmConcede(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Concede this round?'),
      content: const Text(
        'The round is voided as if it was never played: no XP or Club Tokens, and your coins, towers and perk pick go back to how they were at Tee Off. You will play this round again.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Keep it')),
        FilledButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Concede')),
      ],
    ),
  );
  return ok ?? false;
}

/// Small stat chip used across Story screens.
class StatChip extends StatelessWidget {
  const StatChip(this.text, {super.key, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Chip(avatar: icon == null ? null : Icon(icon, size: 16), label: Text(text), visualDensity: VisualDensity.compact);
}
