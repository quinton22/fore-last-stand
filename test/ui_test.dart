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

  testWidgets('home screen lists the modes and gates meta screens', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1500));
    await tester.pumpWidget(ForeApp(store: ProfileStore(Profile()), story: story()));
    expect(find.text('Story'), findsOneWidget);
    expect(find.text('Quick Round'), findsNothing);
    expect(find.text('Full Round'), findsNothing);
    expect(find.text('Sudden Death'), findsOneWidget);
    expect(find.text('Daily Tournament'), findsOneWidget);
    expect(find.text('after 3 rounds'), findsOneWidget);
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

  testWidgets('a run screen renders the HUD', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    await tester.pumpWidget(ForeApp(store: ProfileStore(Profile(tutorialSeen: ['welcome'])), story: story()));
    await tester.ensureVisible(find.text('Sudden Death'));
    await tester.tap(find.text('Sudden Death'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Hole 1/∞'), findsOneWidget);
    expect(find.text('FORE!'), findsOneWidget);
    expect(find.text('Driver'), findsOneWidget);
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
    expect(find.text('Range tools'), findsOneWidget);
  });

  testWidgets('the bestiary describes every animal before you meet it', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1500));
    await tester.pumpWidget(ForeApp(store: ProfileStore(Profile(tutorialSeen: ['welcome'])), story: story()));
    await tester.ensureVisible(find.text('Bestiary'));
    await tester.tap(find.text('Bestiary'));
    await tester.pumpAndSettle();
    expect(find.text('Goose'), findsOneWidget);
    expect(find.textContaining('honk stuns every tower'), findsOneWidget);
  });
}
