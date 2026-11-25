import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fore_last_stand/main.dart';
import 'package:fore_last_stand/meta/profile.dart';
import 'package:fore_last_stand/meta/profile_store.dart';
import 'package:fore_last_stand/story/content.dart';
import 'package:fore_last_stand/story/progression.dart';
import 'package:fore_last_stand/story/save.dart';
import 'package:fore_last_stand/story/story_store.dart';
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

  testWidgets('the app reopens on a pending Results screen; Concede voids it', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1000));
    final save = freshSave(content);
    finishRound(
      save,
      content,
      muni,
      replay: false,
      outcome: const RoundOutcome(won: true, wavesCleared: 4, totalWaves: 4, flagsLeft: 2, endCoins: 300, endTowers: []),
    );
    final story = StoryStore(content, StorySave.fromJson((jsonDecode(jsonEncode(save.toJson())) as Map).cast<String, Object?>()), MemorySaveBackend());
    await tester.pumpWidget(
      ForeApp(
        store: ProfileStore(Profile(tutorialSeen: ['welcome'])),
        story: story,
      ),
    );
    await settle(tester);
    expect(find.text('Round 1 won!'), findsOneWidget);
    expect(find.text('Next Round'), findsOneWidget);
    expect(find.text('+110'), findsOneWidget);
    expect(find.text('Rank 2 on Suburban Muni!'), findsOneWidget);
    await tester.tap(find.text('Concede'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Concede'));
    await settle(tester);
    final cs = story.course(muni);
    expect(cs.pendingResult, isNull);
    expect(cs.rank, 1);
    expect(cs.current.round, 1);
    expect(find.text('Rank 1'), findsOneWidget, reason: 'back on the hole map');
  });

  testWidgets('Next Round commits the result and opens Prep for round 2', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1000));
    final save = freshSave(content);
    finishRound(
      save,
      content,
      muni,
      replay: false,
      outcome: const RoundOutcome(won: true, wavesCleared: 4, totalWaves: 4, flagsLeft: 2, endCoins: 300, endTowers: []),
    );
    final story = StoryStore(content, save, MemorySaveBackend());
    await tester.pumpWidget(
      ForeApp(
        store: ProfileStore(Profile(tutorialSeen: ['welcome'])),
        story: story,
      ),
    );
    await settle(tester);
    await tester.tap(find.text('Next Round'));
    await settle(tester);
    final cs = story.course(muni);
    expect(cs.rank, 2);
    expect(cs.current.round, 2);
    expect(cs.current.coins, 300);
    expect(find.textContaining('round 2'), findsWidgets);
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
