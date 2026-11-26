import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fore_last_stand/main.dart';
import 'package:fore_last_stand/meta/profile.dart';
import 'package:fore_last_stand/meta/profile_store.dart';
import 'package:fore_last_stand/story/content.dart';
import 'package:fore_last_stand/story/progression.dart';
import 'package:fore_last_stand/story/save.dart';
import 'package:fore_last_stand/story/arcade.dart';
import 'package:fore_last_stand/story/game/round_game.dart';
import 'package:fore_last_stand/story/sim/layout.dart';
import 'package:fore_last_stand/story/sim/round_sim.dart';
import 'package:fore_last_stand/story/story_store.dart';
import 'package:fore_last_stand/story/ui/round_screen.dart';
import 'package:fore_last_stand/story/ui/story_nav.dart';
import 'package:fore_last_stand/story/ui/story_results_screen.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers.dart';

void main() {
  late StoryContent content;
  setUpAll(() async => content = await loadContent());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  testWidgets('Story: menu, course select, hole map, Prep draft, Tee Off, Main Menu resumes', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    final backend = MemorySaveBackend();
    final story = StoryStore(content, StorySave(), backend);
    await tester.pumpWidget(
      ForeApp(
        store: ProfileStore(Profile(tutorialSeen: ['welcome'])),
        story: story,
      ),
    );
    await tester.tap(find.text('Story'));
    await settle(tester);
    expect(find.text('Suburban Muni'), findsOneWidget);
    expect(find.text('Course 2'), findsOneWidget);
    await tester.tap(find.text('Suburban Muni'));
    await settle(tester);
    expect(find.text('Rank 1'), findsOneWidget);
    expect(find.text('Opening Drive'), findsOneWidget);
    expect(find.text('Pro Shop'), findsOneWidget);
    await tester.tap(find.textContaining('Play: Hole 1, round 1'));
    await settle(tester);
    // Prep opens on the perk draft.
    expect(find.textContaining('Draft a perk'), findsOneWidget);
    final offer = perkOffer(content, muni, story.course(muni).current);
    await tester.tap(find.text(offer.first.name));
    await settle(tester);
    expect(find.text('Tee Off'), findsOneWidget);
    expect(find.text('Rusty 7-Iron'), findsOneWidget);
    await tester.tap(find.text('Tee Off'));
    await settle(tester);
    expect(find.text('Wave 1/3'), findsWidgets);
    expect(story.course(muni).current.roundPerk, offer.first.id, reason: 'saved at Tee Off');
    expect(backend.writes, greaterThan(0));
    // Pause -> Main Menu discards the round; Story resumes the same hole and round.
    await tester.tap(find.byTooltip('Pause'));
    await settle(tester);
    expect(find.text('Concede'), findsOneWidget);
    await tester.tap(find.text('Main Menu'));
    await settle(tester);
    expect(find.textContaining('Suburban Muni: Hole 1, round 1'), findsOneWidget);
  });

  testWidgets('Results: saved at once, no Concede; Next Round opens Prep for round 2', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1000));
    final save = freshSave(content);
    final story = StoryStore(content, save, MemorySaveBackend());
    final deps = StoryDeps(
      profile: ProfileStore(Profile(tutorialSeen: ['welcome'])),
      story: story,
    );
    final pr = finishRound(
      save,
      content,
      muni,
      replay: false,
      outcome: const RoundOutcome(won: true, wavesCleared: 4, totalWaves: 4, flagsLeft: 2, endCoins: 300, endTowers: []),
    );
    final out = commitResult(save, content, muni);
    await tester.pumpWidget(
      MaterialApp(
        home: StoryResultsScreen(deps: deps, courseId: muni, result: pr, outcome: out),
      ),
    );
    await settle(tester);
    expect(find.text('Round 1 won!'), findsOneWidget);
    expect(find.text('+110'), findsOneWidget);
    expect(find.text('Rank 2 on Suburban Muni!'), findsOneWidget);
    expect(find.text('Concede'), findsNothing);
    expect(find.text('Story Menu'), findsOneWidget);
    final cs = story.course(muni);
    expect(cs.rank, 2, reason: 'already saved');
    expect(cs.current.round, 2);
    expect(cs.current.coins, 300);
    await tester.tap(find.text('Next Round'));
    await settle(tester);
    expect(find.textContaining('round 2'), findsWidgets);
  });

  testWidgets('Pause offers Concede only during a round', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    final story = StoryStore(content, freshSave(content), MemorySaveBackend());
    final deps = StoryDeps(
      profile: ProfileStore(Profile(tutorialSeen: ['welcome'])),
      story: story,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: RoundScreen(deps: deps, mode: RoundMode.endless, seed: 3),
      ),
    );
    await settle(tester);
    await tester.tap(find.text(arcadePerkOffer(content, 3, const []).first.name));
    await settle(tester);
    await tester.tap(find.text('Tee Off'));
    await settle(tester);
    // Tapping a plot mid-round opens the build sheet and pauses the round.
    final box = tester.getRect(find.byType(GameWidget<RoundGame>));
    final scale = box.width / StoryLayout.width;
    final plot = StoryLayout.plotCenter(0, 0);
    await tester.tapAt(box.topLeft + Offset(plot.x * scale, plot.y * scale));
    await settle(tester);
    expect(find.text('Paused while you choose.'), findsOneWidget);
    expect(tester.widget<GameWidget<RoundGame>>(find.byType(GameWidget<RoundGame>)).game!.frozen, isTrue);
    await tester.tap(find.byTooltip('Close'));
    await settle(tester);
    expect(tester.widget<GameWidget<RoundGame>>(find.byType(GameWidget<RoundGame>)).game!.frozen, isFalse);
    await tester.tap(find.byTooltip('Pause'));
    await settle(tester);
    expect(find.text('Concede'), findsNothing, reason: 'arcade runs end instead');
    expect(find.text('End run'), findsOneWidget);
  });

  testWidgets('Pro Shop buys a revealed club and the Bag equips it', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1200));
    final save = freshSave(content);
    save.courses[muni]!
      ..rank = 3
      ..tokens = 200;
    final story = StoryStore(content, save, MemorySaveBackend());
    await tester.pumpWidget(
      ForeApp(
        store: ProfileStore(Profile(tutorialSeen: ['welcome'])),
        story: story,
      ),
    );
    await tester.tap(find.text('Story'));
    await settle(tester);
    await tester.tap(find.text('Suburban Muni'));
    await settle(tester);
    await tester.tap(find.text('Pro Shop'));
    await settle(tester);
    await tester.tap(find.text('Buy 🎟 70'));
    await settle(tester);
    expect(save.courses[muni]!.ownedClubs.keys, contains('driver_used'));
    await tester.pageBack();
    await settle(tester);
    await tester.tap(find.text('Bag'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Equip'));
    await settle(tester);
    expect(save.courses[muni]!.bag, ['iron_old', 'driver_used', null]);
  });
}
