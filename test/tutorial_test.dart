import 'package:flutter_test/flutter_test.dart';
import 'package:fore_last_stand/data/enemies.dart';
import 'package:fore_last_stand/data/modes.dart';
import 'package:fore_last_stand/meta/profile.dart';
import 'package:fore_last_stand/sim/battle.dart';
import 'package:fore_last_stand/ui/tutorial.dart';

void main() {
  test('every enemy has an explanation page', () {
    for (final e in [...enemies, ...bosses]) {
      final page = enemyPage(e);
      expect(page.body, isNotEmpty);
      expect(page.bullets, isNotEmpty);
    }
  });

  test('topics come in order and only once', () {
    final battle = Battle(RunConfig(mode: modeById(ModeId.quickRound), seed: 1));
    final p = Profile();
    expect(pendingTutorialTopic(battle, p), 'intro');
    p.tutorialSeen.add('intro');
    expect(pendingTutorialTopic(battle, p), isNull);
  });

  test('tutorialSeen round-trips through json', () {
    final p = Profile()..tutorialSeen.addAll(['intro', 'enemy:goose']);
    expect(Profile.fromJson(p.toJson()).tutorialSeen, ['intro', 'enemy:goose']);
  });
}
