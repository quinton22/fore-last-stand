import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:material_ui/material_ui.dart';

import '../../sim/vec.dart';
import '../../ui/settings_screen.dart';
import '../ads.dart';
import '../arcade.dart';
import '../content.dart';
import '../game/round_game.dart';
import '../progression.dart';
import '../range_lessons.dart';
import '../save.dart';
import '../sim/layout.dart';
import '../sim/round_sim.dart';
import 'arcade_results_screen.dart';
import 'range_ui.dart';
import 'story_bag_screen.dart';
import 'story_nav.dart';
import 'story_results_screen.dart';

/// Prep and the round itself, drawn on the 390 x 844 canvas. Story rounds,
/// Sudden Death, the Daily Tournament and the Driving Range all play here.
class RoundScreen extends StatefulWidget {
  const RoundScreen({super.key, required this.deps, this.courseId = '', this.replay = false, this.mode = RoundMode.story, this.seed = 0});

  final StoryDeps deps;
  final String courseId;
  final bool replay;
  final RoundMode mode;

  /// Seed for arcade runs (the date for the Daily Tournament).
  final int seed;

  @override
  State<RoundScreen> createState() => _RoundScreenState();
}

class _RoundScreenState extends State<RoundScreen> {
  late final RoundSim sim;
  late final RoundGame game;
  late final AppLifecycleListener _lifecycle;

  List<StoryPerk> _offer = const [];
  int _draftIndex = 0;
  bool _showDraft = false;

  /// Plot whose build/upgrade sheet is open (the round is paused meanwhile).
  (int, int)? _sheetPlot;
  bool _paused = false;
  bool _ended = false;
  bool _busy = false;

  int? _pointer;
  Offset _downAt = Offset.zero;
  (int, int)? _downPlot;
  bool _aimingNow = false;

  // Driving Range tutorial.
  int _lesson = 0;
  bool _guideOpen = true;
  bool _tips = false;

  StoryDeps get deps => widget.deps;
  StoryContent get content => deps.story.content;
  Rules get rules => content.rules;
  bool get story => widget.mode == RoundMode.story;
  bool get range => widget.mode == RoundMode.range;
  CourseSave get cs => deps.story.course(widget.courseId);
  HoleRun get run => cs.activeRun(replay: widget.replay);
  CourseContent get course => content.course(widget.courseId);

  @override
  void initState() {
    super.initState();
    final player = deps.story.save.player;
    final settings = deps.profile.profile.settings;
    if (story) {
      final caddie = player.equippedCaddie;
      sim = RoundSim(
        RoundSetup(
          content: content,
          courseId: widget.courseId,
          hole: course.hole(math.min(run.hole, course.holeCount)),
          round: run.round,
          coins: run.coins,
          towers: run.towers,
          perks: run.perks,
          roundPerk: run.roundPerk,
          bag: _bagFromSave(),
          unlockedTowers: towersFor(content, cs, run.hole),
          caddieId: caddie,
          caddieRank: caddie == null ? 1 : player.caddies[caddie] ?? 1,
          boost: run.bankedBoost,
          greenskeepingTier: cs.wingTier('greenskeeping'),
          aimAssist: settings.aimAssist,
          autoCaddie: settings.autoCaddie,
          reviveAvailable: canOfferReward(player, deps.ads),
        ),
      );
      if (!run.drafted) _offer = perkOffer(content, widget.courseId, run);
    } else {
      sim = RoundSim(arcadeSetup(deps.story, settings, widget.mode, seed: widget.seed, reviveAvailable: canOfferReward(player, deps.ads)));
      if (!range) _offer = arcadePerkOffer(content, widget.seed, const []);
    }
    _showDraft = _offer.isNotEmpty;
    game = RoundGame(sim, settings);
    game.hudTick.addListener(_onTick);
    if (range) {
      sim.teeOff();
      _guideOpen = true;
    }
    _lifecycle = AppLifecycleListener(onInactive: _autoPause, onHide: _autoPause, onPause: _autoPause);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    game.hudTick.removeListener(_onTick);
    super.dispose();
  }

  List<BagClub?> _bagFromSave() => [for (final id in cs.bag) id == null ? null : BagClub(course.club(id), cs.ownedClubs[id] ?? 1)];

  void _refreeze() => game.frozen = _sheetPlot != null || (_showDraft && sim.playing);

  // ---------------------------------------------------------------- flow

  void _onTick() {
    if (sim.finished && !_ended) {
      _ended = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _finish());
    }
    // Sudden Death: draft a perk every few waves; the round holds still meanwhile.
    if (sim.draftDue && !_showDraft && sim.phase == RoundPhase.buildBreak) {
      setState(() {
        _draftIndex = 0;
        _offer = arcadePerkOffer(content, widget.seed + sim.wave, sim.perks);
        _showDraft = _offer.isNotEmpty;
        if (!_showDraft) sim.draftDue = false;
        _refreeze();
      });
    }
  }

  /// A finished round is saved at once; Results only shows what happened.
  void _finish() {
    if (!mounted) return;
    if (story) {
      final kills = sim.killsById;
      late PendingResult pr;
      late CommitOutcome out;
      deps.story.update((s) {
        pr = finishRound(s, content, widget.courseId, replay: widget.replay, outcome: sim.outcome());
        out = commitResult(s, content, widget.courseId);
      });
      deps.profile.update((p) => addKills(p, kills));
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => StoryResultsScreen(deps: deps, courseId: widget.courseId, result: pr, outcome: out),
        ),
      );
      return;
    }
    final result = deps.profile.update((p) => recordArcade(p, sim, seed: widget.seed));
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ArcadeResultsScreen(deps: deps, result: result, seed: widget.seed),
      ),
    );
  }

  bool get _needsDraft => _offer.isNotEmpty && sim.roundPerk == null && sim.phase == RoundPhase.prep;

  void _teeOff() {
    if (sim.phase != RoundPhase.prep || _needsDraft) return;
    if (story) {
      final extra = math.max(0, _draftIndex - rules.i('perks.freeRerolls'));
      final coins = sim.coins;
      final towers = sim.snapshotTowers();
      deps.story.update(
        (s) => teeOff(s, widget.courseId, replay: widget.replay, coins: coins, towers: towers, perk: sim.roundPerk, extraRerolls: extra, caddie: sim.caddieId),
      );
    }
    setState(() {
      _sheetPlot = null;
      game.selectedPlot = null;
      sim.teeOff();
      _refreeze();
    });
  }

  void _pick(StoryPerk p) => setState(() {
    if (sim.phase == RoundPhase.prep) {
      sim.pickPerk(p.id);
    } else {
      sim.addPerk(p.id);
      sim.draftDue = false;
    }
    _showDraft = false;
    _refreeze();
  });

  int get _rerolls {
    if (story && sim.phase == RoundPhase.prep) return rerollsLeft(rules, cs, run, usedThisDraft: _draftIndex);
    return math.max(0, rules.i('perks.freeRerolls') - _draftIndex);
  }

  void _reroll() {
    if (_rerolls <= 0) return;
    setState(() {
      _draftIndex++;
      _offer = story && sim.phase == RoundPhase.prep
          ? perkOffer(content, widget.courseId, run, draft: _draftIndex)
          : arcadePerkOffer(content, widget.seed + sim.wave, sim.perks, draft: _draftIndex);
    });
  }

  Future<void> _watchBoost() async {
    if (_busy) return;
    _busy = true;
    final ok = await earnReward(context, deps.story.save.player, deps.ads);
    _busy = false;
    if (!ok || !mounted) return;
    final id = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (c) => SimpleDialog(
        title: const Text('Choose a boost for this round'),
        children: [for (final b in rules.boosts) SimpleDialogOption(onPressed: () => Navigator.of(c).pop(b.id), child: Text(b.name))],
      ),
    );
    if (id == null || !mounted) return;
    if (story) deps.story.update((_) => run.bankedBoost = id);
    setState(() => sim.boost = id);
  }

  Future<void> _openBag() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StoryBagScreen(deps: deps, courseId: widget.courseId),
      ),
    );
    if (mounted) setState(() => sim.setBag(_bagFromSave()));
  }

  Future<void> _revive() async {
    if (_busy) return;
    _busy = true;
    final ok = await earnReward(context, deps.story.save.player, deps.ads);
    _busy = false;
    if (!mounted) return;
    setState(() => ok ? sim.acceptRevive() : null);
  }

  void _autoPause() {
    if (mounted && sim.playing && !_paused && !range) _pause();
  }

  void _pause() {
    setState(() => _paused = true);
    game.pauseEngine();
  }

  void _resume() {
    setState(() => _paused = false);
    game.resumeEngine();
  }

  /// Story only, and only while a round is being played.
  Future<void> _concede() async {
    if (!await confirmConcede(context) || !mounted) return;
    deps.story.update((s) => concede(s, widget.courseId, replay: widget.replay));
    openHoleMap(context, deps, widget.courseId);
  }

  void _endRun() {
    _resume();
    setState(sim.endRun);
  }

  // ---------------------------------------------------------------- input

  void _closeSheet() => setState(() {
    _sheetPlot = null;
    game.selectedPlot = null;
    _refreeze();
  });

  /// Selecting a tower or an empty plot pauses the round until the sheet closes.
  void _openSheet((int, int) plot) => setState(() {
    _sheetPlot = plot;
    game.selectedPlot = plot;
    _refreeze();
  });

  bool get _inputBlocked => _paused || _showDraft || sim.phase == RoundPhase.revive || sim.finished || _sheetPlot != null;

  void _onDown(PointerDownEvent e) {
    if (_pointer != null || _inputBlocked) return;
    _pointer = e.pointer;
    _downAt = e.localPosition;
    _aimingNow = false;
    _downPlot = StoryLayout.plotAt(V2(e.localPosition.dx, e.localPosition.dy));
    // Off the build zone, aiming starts at once (the Sweet Spot ring runs from touch down).
    if (sim.playing && _downPlot == null) _startAim();
  }

  void _startAim() {
    _aimingNow = true;
    sim.beginAim();
    game.aimDrag = V2.zero;
  }

  void _onMove(PointerMoveEvent e) {
    if (e.pointer != _pointer) return;
    final d = e.localPosition - _downAt;
    // A touch on the build zone that moves becomes an aim drag.
    if (!_aimingNow && sim.playing && d.distance > rules.n('swing.towerDragThreshold')) _startAim();
    if (_aimingNow) game.aimDrag = V2(d.dx, d.dy);
  }

  void _onUp(PointerUpEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    final d = e.localPosition - _downAt;
    if (_aimingNow) {
      _aimingNow = false;
      game.aimDrag = null;
      sim.release(d.dx, d.dy);
      return;
    }
    if (d.distance <= rules.n('swing.towerDragThreshold') && _downPlot != null && sim.canBuild) _openSheet(_downPlot!);
  }

  void _onCancel(PointerCancelEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    if (_aimingNow) sim.cancelAim();
    _aimingNow = false;
    game.aimDrag = null;
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: sim.phase == RoundPhase.prep || range,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && sim.playing && !_paused) _pause();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Center(
            child: FittedBox(
              child: SizedBox(
                width: StoryLayout.width,
                height: StoryLayout.height,
                child: ValueListenableBuilder<int>(
                  valueListenable: game.hudTick,
                  builder: (context, _, child) => Stack(
                    children: [
                      child!,
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 0,
                        height: StoryLayout.hud.bottom,
                        child: _Hud(
                          sim: sim,
                          title: _title,
                          onPause: sim.playing && !range ? _pause : null,
                          onTools: range ? _openTools : null,
                          onLeave: range ? () => Navigator.of(context).maybePop() : null,
                        ),
                      ),
                      if (sim.banner != null && !range)
                        Positioned(
                          left: 16,
                          right: 16,
                          top: 92,
                          child: IgnorePointer(
                            child: Text(
                              sim.banner!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 6)]),
                            ),
                          ),
                        ),
                      if (range && _guideOpen && _lesson < rangeLessons.length && _sheetPlot == null)
                        Positioned(
                          left: 6,
                          right: 6,
                          top: 84,
                          child: LessonCard(
                            lesson: rangeLessons[_lesson],
                            index: _lesson,
                            total: rangeLessons.length,
                            done: rangeLessons[_lesson].isDone(sim),
                            showTips: _tips,
                            onToggleTips: () => setState(() => _tips = !_tips),
                            onNext: _nextLesson,
                            onSkip: _closeGuide,
                          ),
                        ),
                      if (sim.phase == RoundPhase.buildBreak && _sheetPlot == null && !_showDraft)
                        Positioned(
                          left: 40,
                          right: 40,
                          top: 446,
                          child: _BreakBar(sim: sim, onSkip: () => setState(sim.skipBreak)),
                        ),
                      if (sim.phase == RoundPhase.prep && !_showDraft && _sheetPlot == null)
                        Positioned(left: 8, right: 8, bottom: StoryLayout.height - StoryLayout.teeBox.top + 6, child: _prepPanel()),
                      if (_sheetPlot != null)
                        Positioned(
                          left: 8,
                          right: 8,
                          top: 90,
                          bottom: StoryLayout.height - StoryLayout.teeBox.top + 6,
                          child: Align(alignment: Alignment.bottomCenter, child: _sheet(_sheetPlot!)),
                        ),
                      if (_showDraft)
                        Positioned(left: 0, right: 0, top: StoryLayout.hud.bottom, bottom: StoryLayout.height - StoryLayout.teeBox.top, child: _draftPanel()),
                      Positioned(
                        left: 0,
                        right: 0,
                        top: StoryLayout.clubBar.top,
                        bottom: 0,
                        child: _ClubBar(sim: sim, leftHanded: deps.profile.profile.settings.leftHanded, onChanged: () => setState(() {})),
                      ),
                      if (sim.phase == RoundPhase.revive) Positioned.fill(child: _reviveOverlay()),
                      if (_paused) Positioned.fill(child: _pauseOverlay()),
                    ],
                  ),
                  child: Positioned.fill(
                    child: Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: _onDown,
                      onPointerMove: _onMove,
                      onPointerUp: _onUp,
                      onPointerCancel: _onCancel,
                      child: GameWidget(game: game),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String get _title => switch (widget.mode) {
    RoundMode.story => '${widget.replay ? 'Replay · ' : ''}Hole ${sim.holeNumber} · Round ${sim.round}/${rules.roundsPerHole}',
    RoundMode.endless => 'Sudden Death · ${sim.hole.name}',
    RoundMode.daily => 'Daily · ${modifierNames[sim.modifier]!.split(':').first}',
    RoundMode.range => 'Driving Range',
  };

  static final ButtonStyle _light = TextButton.styleFrom(foregroundColor: Colors.lightGreenAccent);

  Widget _panel({required Widget child, EdgeInsets padding = const EdgeInsets.all(10)}) => Card(
    color: const Color(0xF0263238),
    margin: EdgeInsets.zero,
    child: Padding(
      padding: padding,
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.white, fontSize: 13),
        child: child,
      ),
    ),
  );

  String get _prepGoal {
    if (widget.mode == RoundMode.endless) return 'Endless waves, one flag. A mini-boss every 5 waves, a boss every 10, a perk every 3.';
    final boss = sim.finalBossRound ? 'Final boss: ${content.bossForHole(sim.holeNumber).name}' : 'Mini-boss: Giant ${content.enemy(sim.hole.featured).name}';
    final daily = widget.mode == RoundMode.daily ? '${modifierNames[sim.modifier]}\n' : '';
    return '$daily$boss · ${sim.normalWaves} waves first';
  }

  Widget _prepPanel() {
    final player = deps.story.save.player;
    final perk = sim.roundPerk == null ? null : content.perk(sim.roundPerk!);
    final canBoost = story && sim.boost == null && canOfferReward(player, deps.ads);
    return _panel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Prep: ${sim.hole.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Text(_prepGoal, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 6),
          Text(perk == null ? 'Perk: none' : 'Perk this round: ${perk.name} (${perk.text})'),
          if (sim.perks.length > (perk == null ? 0 : 1))
            Text(
              'Hole perks: ${sim.perks.where((p) => p != sim.roundPerk).map((p) => content.perk(p).name).join(', ')}',
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Caddie:'),
              for (final c in content.caddies.where((c) => player.caddies.containsKey(c.id)))
                ChoiceChip(
                  label: Text('${c.name} ★${player.caddies[c.id]}'),
                  selected: sim.caddieId == c.id,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => setState(() {
                    sim.caddieId = c.id;
                    sim.caddieRank = player.caddies[c.id] ?? 1;
                  }),
                ),
            ],
          ),
          if (sim.boost != null) Text('Boost: ${rules.boost(sim.boost!).name}', style: const TextStyle(color: Colors.amberAccent)),
          const SizedBox(height: 4),
          const Text('Tap a plot in the build zone to build. Tapping a plot later pauses the round.', style: TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 6),
          Row(
            children: [
              IconButton(
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              if (story) TextButton.icon(style: _light, onPressed: _openBag, icon: const Icon(Icons.sports_golf), label: const Text('Bag')),
              if (canBoost)
                TextButton.icon(
                  style: _light,
                  onPressed: _watchBoost,
                  icon: const Icon(Icons.ondemand_video),
                  label: Text(player.removeAds ? 'Boost' : 'Ad boost'),
                ),
              const Spacer(),
              FilledButton(onPressed: _needsDraft ? null : _teeOff, child: const Text('Tee Off')),
            ],
          ),
          if (_needsDraft) TextButton(style: _light, onPressed: () => setState(() => _showDraft = true), child: const Text('Draft a perk first')),
        ],
      ),
    );
  }

  Widget _draftPanel() => Container(
    color: const Color(0xDD000000),
    alignment: Alignment.center,
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            sim.phase == RoundPhase.prep ? '${sim.hole.name}${story ? ': round ${sim.round}' : ''}' : 'Wave ${sim.wave} cleared',
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            story ? 'Draft a perk: pick 1 of 3. Perks last for the rest of this hole.' : 'Draft a perk: pick 1 of 3. Perks last for the rest of the run.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          for (final p in _offer)
            Card(
              color: const Color(0xFF263238),
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: Colors.lightGreenAccent, width: 1.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: ListTile(
                title: Text(
                  p.name,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(p.text, style: const TextStyle(color: Colors.white70)),
                onTap: () => _pick(p),
              ),
            ),
          const SizedBox(height: 6),
          TextButton.icon(style: _light, onPressed: _rerolls > 0 ? _reroll : null, icon: const Icon(Icons.refresh), label: Text('Reroll ($_rerolls left)')),
          if (sim.perks.isNotEmpty)
            Text(
              'Held: ${sim.perks.map((id) => content.perk(id).name).join(', ')}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
        ],
      ),
    ),
  );

  Widget _sheet((int, int) plot) {
    final tower = sim.towerAt(plot.$1, plot.$2);
    return _panel(
      padding: const EdgeInsets.fromLTRB(10, 4, 4, 8),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    tower == null ? 'Build on plot ${plot.$1 + 1}-${plot.$2 + 1}' : '${tower.spec.name}  (level ${tower.level})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                Text('🪙 ${sim.coins}'),
                IconButton(
                  tooltip: 'Close',
                  onPressed: _closeSheet,
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
            if (sim.playing) const Text('Paused while you choose.', style: TextStyle(color: Colors.amberAccent, fontSize: 12)),
            if (tower == null) ..._buildOptions(plot) else ..._towerOptions(tower),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildOptions((int, int) plot) => [
    for (final spec in content.towers)
      () {
        final unlocked = sim.isUnlocked(spec);
        final rowOk = !spec.frontRowOnly || plot.$2 == 0;
        final cost = sim.placeCost(spec);
        final ok = unlocked && rowOk && sim.coins >= cost;
        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: Color(unlocked ? spec.color : 0xFF616161),
            child: Text(spec.badge, style: const TextStyle(fontSize: 11, color: Colors.black)),
          ),
          title: Text(spec.name, style: TextStyle(color: unlocked ? Colors.white : Colors.white38)),
          subtitle: Text(
            !unlocked
                ? 'Unlocks at hole ${spec.unlockHole}'
                : (!rowOk ? 'Front row only' : '${spec.text}. ${spec.health.round()} health. Overcharge: ${spec.overchargeText}.'),
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
          trailing: unlocked
              ? Text('🪙 $cost', style: TextStyle(color: ok ? Colors.white : Colors.white38))
              : const Icon(Icons.lock, color: Colors.white38, size: 18),
          enabled: ok,
          onTap: () {
            if (sim.placeTower(spec.id, plot.$1, plot.$2) != null) _closeSheet();
          },
        );
      }(),
  ];

  List<Widget> _towerOptions(STower tower) {
    final up = sim.upgradeCost(tower);
    return [
      Text('${tower.spec.text}. Overcharge: ${tower.spec.overchargeText}.', style: const TextStyle(color: Colors.white70, fontSize: 12)),
      Text('Health ${tower.hp.ceil()}/${tower.maxHp.round()}${tower.active ? '' : ' · disabled'}', style: const TextStyle(fontSize: 12)),
      const Text('Upgrading adds +40% damage or effect and repairs the tower. Selling refunds 70%.', style: TextStyle(color: Colors.white54, fontSize: 11)),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: FilledButton(
              onPressed: up != null && sim.coins >= up
                  ? () {
                      sim.upgradeTower(tower);
                      _closeSheet();
                    }
                  : null,
              child: Text(up == null ? 'Max level' : 'Upgrade 🪙 $up'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                sim.sellTower(tower);
                _closeSheet();
              },
              child: Text('Sell +${sim.sellValue(tower)}', style: const TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    ];
  }

  Widget _reviveOverlay() {
    final player = deps.story.save.player;
    return ColoredBox(
      color: const Color(0xCC000000),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _panel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Your last flag fell!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text(
                  'Revive with 1 flag at full health. Enemies near the ball are cleared and bosses pushed back. Once per round.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _revive,
                  icon: const Icon(Icons.ondemand_video),
                  label: Text(player.removeAds ? 'Revive' : 'Watch an ad to revive'),
                ),
                TextButton(style: _light, onPressed: () => setState(sim.declineRevive), child: const Text('Give up')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pauseButton(String label, VoidCallback onPressed, {bool filled = false}) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: SizedBox(
      width: 220,
      child: filled
          ? FilledButton(onPressed: onPressed, child: Text(label))
          : OutlinedButton(
              onPressed: onPressed,
              child: Text(label, style: const TextStyle(color: Colors.white)),
            ),
    ),
  );

  Widget _pauseOverlay() => Container(
    color: const Color(0xCC000000),
    alignment: Alignment.center,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Paused',
          style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold),
        ),
        Text(_title, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 12),
        _pauseButton('Resume', _resume, filled: true),
        _pauseButton('Settings', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SettingsScreen(store: deps.profile)))),
        if (story && sim.playing) _pauseButton('Concede', _concede),
        if (story) _pauseButton('Main Menu', () => goHome(context)) else _pauseButton('End run', _endRun),
        const SizedBox(height: 8),
        if (story) const Text('Main Menu restarts this round from Tee Off next time.', style: TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    ),
  );

  // ---------------------------------------------------------------- Driving Range

  void _nextLesson() {
    if (_lesson + 1 >= rangeLessons.length) return _closeGuide();
    setState(() {
      _tips = false;
      _lesson++;
      final spawn = rangeLessons[_lesson].spawn;
      if (spawn != null) sim.spawnTarget(spawn);
    });
  }

  void _closeGuide() {
    setState(() => _guideOpen = false);
    deps.profile.update((p) {
      if (!p.tutorialSeen.contains('range')) p.tutorialSeen.add('range');
    });
  }

  void _openTools() {
    showRangeTools(
      context,
      sim,
      onChanged: () => setState(() {}),
      onReplay: () => setState(() {
        _lesson = 0;
        _guideOpen = true;
        _tips = false;
      }),
    );
  }
}

class _Hud extends StatelessWidget {
  const _Hud({required this.sim, required this.title, required this.onPause, this.onTools, this.onLeave});

  final RoundSim sim;
  final String title;
  final VoidCallback? onPause;
  final VoidCallback? onTools;
  final VoidCallback? onLeave;

  String get _waveText => switch (sim.phase) {
    RoundPhase.prep => 'Prep',
    RoundPhase.buildBreak => 'Build break',
    _ when sim.range => 'Practice',
    _ when sim.isBossWave => sim.finalBossRound ? 'Final boss' : 'Mini-boss',
    _ when sim.endless => 'Wave ${sim.wave}',
    _ => 'Wave ${sim.wave}/${sim.normalWaves}',
  };

  @override
  Widget build(BuildContext context) {
    final hp = (sim.health / sim.maxHealth).clamp(0.0, 1.0);
    final maxFlags = sim.endless ? 1 : sim.rules.i('teeBox.flags');
    return DefaultTextStyle(
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 4, 0, 4),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: Text(title, overflow: TextOverflow.ellipsis)),
                Text('🪙 ${sim.coins}'),
                if (onTools != null)
                  IconButton(
                    tooltip: 'Range tools',
                    visualDensity: VisualDensity.compact,
                    onPressed: onTools,
                    icon: const Icon(Icons.tune, color: Colors.white),
                  ),
                if (onLeave != null)
                  IconButton(
                    tooltip: 'Leave range',
                    visualDensity: VisualDensity.compact,
                    onPressed: onLeave,
                    icon: const Icon(Icons.close, color: Colors.white),
                  )
                else
                  IconButton(
                    tooltip: 'Pause',
                    visualDensity: VisualDensity.compact,
                    onPressed: onPause,
                    icon: Icon(Icons.pause, color: onPause == null ? Colors.white24 : Colors.white),
                  ),
              ],
            ),
            Row(
              children: [
                Text('${'🚩' * sim.flags}${'·' * math.max(0, maxFlags - sim.flags)}'),
                const SizedBox(width: 6),
                Expanded(
                  child: LinearProgressIndicator(
                    value: hp,
                    minHeight: 7,
                    color: hp > 0.4 ? Colors.lightGreenAccent : Colors.redAccent,
                    backgroundColor: Colors.black45,
                  ),
                ),
                const SizedBox(width: 8),
                Text(_waveText),
                const SizedBox(width: 8),
                SizedBox(
                  width: 74,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Fore! ${sim.comboName}', style: TextStyle(fontSize: 10, color: sim.comboRung >= 2 ? Colors.yellowAccent : Colors.white70)),
                      LinearProgressIndicator(value: sim.foreMeter / sim.maxFore, minHeight: 5, color: Colors.deepOrange, backgroundColor: Colors.black45),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ClubBar extends StatelessWidget {
  const _ClubBar({required this.sim, required this.leftHanded, required this.onChanged});

  final RoundSim sim;
  final bool leftHanded;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final caddie = sim.caddie;
    final children = <Widget>[
      for (var i = 0; i < sim.bag.length; i++) Expanded(flex: 4, child: _clubButton(i)),
      Expanded(
        flex: 3,
        child: _BarButton(
          label: 'FORE!',
          color: Colors.deepOrange,
          fill: sim.foreMeter / sim.maxFore,
          enabled: sim.foreReady,
          onTap: () {
            sim.triggerFore();
            onChanged();
          },
        ),
      ),
      Expanded(
        flex: 3,
        child: _BarButton(
          label: caddie == null ? 'No caddie' : caddie.activeName,
          color: Color(caddie?.color ?? 0xFF616161),
          fill: sim.caddieUsed ? 0 : 1,
          enabled: sim.caddieReady,
          onTap: () {
            sim.useCaddie();
            onChanged();
          },
        ),
      ),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
      child: Row(children: leftHanded ? children.reversed.toList() : children),
    );
  }

  Widget _clubButton(int i) {
    final b = sim.bag[i];
    if (b == null) return const _BarButton(label: '—', color: Colors.black26, fill: 0, enabled: false);
    final s = sim.statsFor(b);
    final cd = sim.cooldowns[i];
    return _BarButton(
      label: b.club.name,
      sub: b.club.family.name,
      color: sim.selectedSlot == i ? Colors.lightGreen : const Color(0xFF37474F),
      fill: s.cooldown == 0 ? 1 : 1 - cd / s.cooldown,
      enabled: true,
      selected: sim.selectedSlot == i,
      onTap: () {
        sim.selectSlot(i);
        onChanged();
      },
    );
  }
}

class _BarButton extends StatelessWidget {
  const _BarButton({required this.label, required this.color, required this.fill, required this.enabled, this.onTap, this.sub, this.selected = false});

  final String label;
  final String? sub;
  final Color color;
  final double fill;
  final bool enabled;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: enabled ? color : Colors.black45,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                bottom: 0,
                height: 4,
                right: 0,
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: fill.clamp(0.0, 1.0),
                  child: const ColoredBox(color: Colors.white70),
                ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white, fontWeight: selected ? FontWeight.w900 : FontWeight.bold, fontSize: 11),
                    ),
                    if (sub != null) Text(sub!, maxLines: 1, style: const TextStyle(color: Colors.white70, fontSize: 9)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BreakBar extends StatelessWidget {
  const _BreakBar({required this.sim, required this.onSkip});

  final RoundSim sim;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) => Card(
    color: const Color(0xEE263238),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text('Build break ${sim.breakTimer.ceil()} s · wave ${sim.wave + 1} next', style: const TextStyle(color: Colors.white, fontSize: 13)),
          ),
          FilledButton(onPressed: onSkip, child: const Text('Skip')),
        ],
      ),
    ),
  );
}
