import 'package:flutter_test/flutter_test.dart';
import 'package:fore_last_stand/main.dart';
import 'package:fore_last_stand/meta/profile.dart';
import 'package:fore_last_stand/meta/profile_store.dart';
import 'package:fore_last_stand/story/content.dart';
import 'package:fore_last_stand/story/save.dart';
import 'package:fore_last_stand/story/story_store.dart';
import 'package:material_ui/material_ui.dart';

import 'story/helpers.dart';

void main() {
  late StoryContent content;
  setUpAll(() async => content = await loadContent());
  StoryStore story([StorySave? save]) => StoryStore(content, save ?? StorySave(), MemorySaveBackend());

  testWidgets('home screen lists Story, the arcade modes and the range', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1500));
    await tester.pumpWidget(ForeApp(store: ProfileStore(Profile()), story: story()));
    expect(find.text('Story'), findsOneWidget);
    expect(find.text('Quick Round'), findsNothing);
    expect(find.text('Full Round'), findsNothing);
    expect(find.text('Sudden Death'), findsOneWidget);
    expect(find.text('Daily Tournament'), findsOneWidget);
    expect(find.text('Driving Range'), findsOneWidget);
    expect(find.text('Welcome to Fore! Last Stand'), findsOneWidget);
  });

  testWidgets('settings toggles persist into the profile', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1500));
    final store = ProfileStore(Profile(tutorialSeen: ['welcome']));
    await tester.pumpWidget(ForeApp(store: store, story: story()));
    await tester.ensureVisible(find.text('Settings'));
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Left-handed layout'));
    await tester.tap(find.text('Squeaky Clean (confetti)'));
    await tester.pumpAndSettle();
    expect(store.profile.settings.leftHanded, isTrue);
    expect(store.profile.settings.gore, GoreLevel.squeakyClean);
  });

  testWidgets('Sudden Death runs on the Story engine', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    await tester.pumpWidget(ForeApp(store: ProfileStore(Profile(tutorialSeen: ['welcome'])), story: story()));
    await tester.ensureVisible(find.text('Sudden Death'));
    await tester.tap(find.text('Sudden Death'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Sudden Death · '), findsOneWidget);
    expect(find.text('FORE!'), findsOneWidget);
    expect(find.text('Rusty 7-Iron'), findsOneWidget, reason: 'arcade modes use the Story bag');
    expect(find.textContaining('Draft a perk'), findsOneWidget);
  });

  testWidgets('the Driving Range starts a guided tutorial and advances on goals', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    final store = ProfileStore(Profile(tutorialSeen: ['welcome']));
    await tester.pumpWidget(ForeApp(store: store, story: story()));
    await tester.dragUntilVisible(find.text('Driving Range'), find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Driving Range'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Lesson 1 of 11'), findsOneWidget);
    expect(find.text('Welcome to the Driving Range'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.tap(find.text('Skip lesson'));
    await tester.pump();
    expect(find.text('Lesson 3 of 11'), findsOneWidget);
    expect(find.text('Sweet Spot'), findsOneWidget);
    await tester.tap(find.text('Skip tutorial'));
    await tester.pump();
    expect(find.textContaining('Lesson'), findsNothing);
    expect(store.profile.tutorialSeen, contains('range'));
    expect(find.byTooltip('Range tools'), findsOneWidget);
    // The range has a Bag button instead of a row of clubs.
    await tester.tap(find.text('Bag'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.scrollUntilVisible(find.text('The Foghorn'), 200, scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('The Foghorn'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.text('The Foghorn'), findsOneWidget, reason: 'now the selected club on the bar');
  });

  testWidgets('the bestiary describes every animal before you meet it', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1500));
    await tester.pumpWidget(ForeApp(store: ProfileStore(Profile(tutorialSeen: ['welcome'])), story: story()));
    await tester.ensureVisible(find.text('Bestiary'));
    await tester.tap(find.text('Bestiary'));
    await tester.pumpAndSettle();
    expect(find.text('Goose'), findsOneWidget);
    expect(find.textContaining('stunning towers within 80'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Goose King'), 300);
    expect(find.text('Goose King'), findsOneWidget);
  });
}
