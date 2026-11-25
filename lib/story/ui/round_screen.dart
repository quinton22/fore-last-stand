import 'dart:async';
import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:material_ui/material_ui.dart';

import '../../sim/vec.dart';
import '../../ui/settings_screen.dart';
import '../ads.dart';
import '../content.dart';
import '../game/round_game.dart';
import '../progression.dart';
import '../save.dart';
import '../sim/layout.dart';
import '../sim/round_sim.dart';
import 'story_bag_screen.dart';
import 'story_nav.dart';
import 'story_results_screen.dart';

/// Prep and the round itself (6a.2 steps 5-6), drawn on the 390 x 844 canvas.
class RoundScreen extends StatefulWidget {
  const RoundScreen({super.key, required this.deps, required this.courseId, this.replay = false});

  final StoryDeps deps;
  final String courseId;
  final bool replay;

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

  /// Plot whose build/upgrade sheet is open.
  (int, int)? _sheetPlot;
  bool _paused = false;
  bool _ended = false;
  bool _busy = false;

  int? _pointer;
  Offset _downAt = Offset.zero;
  (int, int)? _downPlot;
  bool _onTower = false;
  bool _aimingNow = false;
  bool _longPressed = false;
  Timer? _longPress;

  StoryDeps get deps => widget.deps;
  StoryContent get content => deps.story.content;
  Rules get rules => content.rules;
  CourseSave get cs => deps.story.course(widget.courseId);
  HoleRun get run => cs.activeRun(replay: widget.replay);
  CourseContent get course => content.course(widget.courseId);

  @override
  void initState() {
    super.initState();
    final player = deps.story.save.player;
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
        aimAssist: deps.profile.profile.settings.aimAssist,
        reviveAvailable: canOfferReward(player, deps.ads),
      ),
    );
    game = RoundGame(sim, deps.profile.profile.settings);
    game.hudTick.addListener(_onTick);
    if (!run.drafted) {
      _offer = perkOffer(content, widget.courseId, run);
      _showDraft = _offer.isNotEmpty;
    }
    _lifecycle = AppLifecycleListener(onInactive: _autoPause, onHide: _autoPause, onPause: _autoPause);
  }

  @override
  void dispose() {
    _longPress?.cancel();
    _lifecycle.dispose();
    game.hudTick.removeListener(_onTick);
    super.dispose();
  }

  List<BagClub?> _bagFromSave() => [for (final id in cs.bag) id == null ? null : BagClub(course.club(id), cs.ownedClubs[id] ?? 1)];

  // ---------------------------------------------------------------- flow

  void _onTick() {
    if (sim.finished && !_ended) {
      _ended = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _finish());
    }
  }

  void _finish() {
    if (!mounted) return;
    deps.story.update((s) => finishRound(s, content, widget.courseId, replay: widget.replay, outcome: sim.outcome()));
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => StoryResultsScreen(deps: deps, courseId: widget.courseId),
      ),
    );
  }

  void _teeOff() {
    if (sim.phase != RoundPhase.prep || (_offer.isNotEmpty && sim.roundPerk == null)) return;
    final extra = math.max(0, _draftIndex - rules.i('perks.freeRerolls'));
    final coins = sim.coins;
    final towers = sim.snapshotTowers();
    deps.story.update(
      (s) => teeOff(s, widget.courseId, replay: widget.replay, coins: coins, towers: towers, perk: sim.roundPerk, extraRerolls: extra, caddie: sim.caddieId),
    );
    setState(() {
      _sheetPlot = null;
      game.selectedPlot = null;
      sim.teeOff();
    });
  }

  void _pick(StoryPerk p) => setState(() {
    sim.pickPerk(p.id);
    _showDraft = false;
  });

  int get _rerolls => rerollsLeft(rules, cs, run, usedThisDraft: _draftIndex);

  void _reroll() {
    if (_rerolls <= 0) return;
    setState(() {
      _draftIndex++;
      _offer = perkOffer(content, widget.courseId, run, draft: _draftIndex);
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
    deps.story.update((_) => run.bankedBoost = id);
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
    if (mounted && sim.playing && !_paused) _pause();
  }

  void _pause() {
    setState(() => _paused = true);
    game.pauseEngine();
  }

  void _resume() {
    setState(() => _paused = false);
    game.resumeEngine();
  }

  Future<void> _concede() async {
    if (!await confirmConcede(context) || !mounted) return;
    deps.story.update((s) => concede(s, widget.courseId, replay: widget.replay));
    openHoleMap(context, deps, widget.courseId);
  }

  // ---------------------------------------------------------------- input

  void _closeSheet() => setState(() {
    _sheetPlot = null;
    game.selectedPlot = null;
  });

  void _openSheet((int, int) plot) => setState(() {
    _sheetPlot = plot;
    game.selectedPlot = plot;
  });

  bool get _inputBlocked => _paused || _showDraft || sim.phase == RoundPhase.revive || sim.finished;

  void _onDown(PointerDownEvent e) {
    if (_pointer != null || _inputBlocked) return;
    _pointer = e.pointer;
    _downAt = e.localPosition;
    _longPressed = false;
    _aimingNow = false;
    final plot = StoryLayout.plotAt(V2(e.localPosition.dx, e.localPosition.dy));
    _downPlot = plot;
    _onTower = plot != null && sim.towerAt(plot.$1, plot.$2) != null;
    if (!sim.playing) return;
    if (_onTower) {
      _longPress = Timer(Duration(milliseconds: (rules.n('swing.longPressSeconds') * 1000).round()), () {
        if (!mounted || _aimingNow || _pointer == null) return;
        _longPressed = true;
        _openSheet(plot!);
      });
    } else {
      _startAim();
    }
  }

  void _startAim() {
    _aimingNow = true;
    sim.beginAim();
    game.aimDrag = V2.zero;
  }

  void _onMove(PointerMoveEvent e) {
    if (e.pointer != _pointer) return;
    final d = e.localPosition - _downAt;
    if (_onTower && !_aimingNow && !_longPressed && sim.playing && d.distance > rules.n('swing.towerDragThreshold')) {
      _longPress?.cancel();
      _startAim();
    }
    if (_aimingNow) game.aimDrag = V2(d.dx, d.dy);
  }

  void _onUp(PointerUpEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    _longPress?.cancel();
    final d = e.localPosition - _downAt;
    final tap = d.distance <= rules.n('swing.towerDragThreshold');
    final plot = _downPlot;
    if (_aimingNow) {
      _aimingNow = false;
      game.aimDrag = null;
      final balls = sim.release(d.dx, d.dy);
      if (balls.isEmpty && tap) {
        if (plot != null && sim.towerAt(plot.$1, plot.$2) == null) {
          _openSheet(plot);
        } else if (_sheetPlot == null) {
          setState(() => game.selectedPlot = null);
        }
      }
      return;
    }
    if (_longPressed || !tap || plot == null) return;
    if (!sim.playing) {
      _openSheet(plot); // Prep: tap any plot to build, upgrade or sell.
    } else if (_onTower) {
      // Tap selects a tower (shows its range); long-press opens upgrade/sell.
      setState(() => game.selectedPlot = game.selectedPlot == plot ? null : plot);
    }
  }

  void _onCancel(PointerCancelEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    _longPress?.cancel();
    if (_aimingNow) sim.cancelAim();
    _aimingNow = false;
    game.aimDrag = null;
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: sim.phase == RoundPhase.prep,
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
                        child: _Hud(sim: sim, title: _title, onPause: sim.playing ? _pause : null),
                      ),
                      if (sim.banner != null)
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
                      if (sim.playing && _sheetPlot == null && game.selectedPlot != null && sim.towerAt(game.selectedPlot!.$1, game.selectedPlot!.$2) != null)
                        Positioned(
                          left: 8,
                          right: 8,
                          top: 124,
                          child: _SelectedTower(sim: sim, tower: sim.towerAt(game.selectedPlot!.$1, game.selectedPlot!.$2)!),
                        ),
                      if (sim.phase == RoundPhase.buildBreak && _sheetPlot == null)
                        Positioned(
                          left: 40,
                          right: 40,
                          top: 490,
                          child: _BreakBar(sim: sim, onSkip: () => setState(sim.skipBreak)),
                        ),
                      if (sim.phase == RoundPhase.prep && !_showDraft && _sheetPlot == null)
                        Positioned(left: 8, right: 8, bottom: StoryLayout.height - StoryLayout.fairway.bottom + 2, child: _prepPanel()),
                      if (_sheetPlot != null)
                        Positioned(
                          left: 8,
                          right: 8,
                          top: 150,
                          bottom: StoryLayout.height - StoryLayout.fairway.bottom + 2,
                          child: Align(alignment: Alignment.bottomCenter, child: _sheet(_sheetPlot!)),
                        ),
                      if (_showDraft)
                        Positioned(
                          left: 0,
                          right: 0,
                          top: StoryLayout.hud.bottom,
                          bottom: StoryLayout.height - StoryLayout.fairway.bottom,
                          child: _draftPanel(),
                        ),
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

  static final ButtonStyle _light = TextButton.styleFrom(foregroundColor: Colors.lightGreenAccent);

  String get _title => '${widget.replay ? 'Replay · ' : ''}Hole ${sim.holeNumber} · Round ${sim.round}/${rules.roundsPerHole}';

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

  Widget _prepPanel() {
    final player = deps.story.save.player;
    final perk = sim.roundPerk == null ? null : content.perk(sim.roundPerk!);
    final canBoost = sim.boost == null && canOfferReward(player, deps.ads);
    return _panel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Prep: ${sim.hole.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Text(
            '${sim.finalBossRound ? 'Final boss: ${content.bossForHole(sim.holeNumber).name}' : 'Mini-boss: Giant ${content.enemy(sim.hole.featured).name}'} · ${sim.normalWaves} waves first',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
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
          const Text('Tap a plot on the tee box to build. No timer.', style: TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 6),
          Row(
            children: [
              IconButton(
                tooltip: 'Back to the hole map',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              TextButton.icon(style: _light, onPressed: _openBag, icon: const Icon(Icons.sports_golf), label: const Text('Bag')),
              if (canBoost)
                TextButton.icon(
                  style: _light,
                  onPressed: _watchBoost,
                  icon: const Icon(Icons.ondemand_video),
                  label: Text(player.removeAds ? 'Boost' : 'Ad boost'),
                ),
              const Spacer(),
              FilledButton(onPressed: _offer.isNotEmpty && sim.roundPerk == null ? null : _teeOff, child: const Text('Tee Off')),
            ],
          ),
          if (_offer.isNotEmpty && sim.roundPerk == null)
            TextButton(style: _light, onPressed: () => setState(() => _showDraft = true), child: const Text('Draft a perk first')),
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
            '${sim.hole.name}: round ${sim.round}',
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Draft a perk: pick 1 of 3. Perks last for the rest of this hole.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
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
          if (run.perks.isNotEmpty)
            Text(
              'Held: ${run.perks.map((id) => content.perk(id).name).join(', ')}',
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
                  onPressed: _closeSheet,
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
            if (sim.live) const Text('During a wave: double cost, 2 s slow motion.', style: TextStyle(color: Colors.amberAccent, fontSize: 12)),
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
            !unlocked ? 'Unlocks at hole ${spec.unlockHole}' : (!rowOk ? 'Front row only' : '${spec.text}. Overcharge: ${spec.overchargeText}.'),
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
      const Text('Each level adds +40% damage or effect strength. Selling refunds 70%.', style: TextStyle(color: Colors.white54, fontSize: 11)),
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
                  'Revive with 1 flag at full health. Enemies near the tee box are cleared and bosses pushed back. Once per round.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _revive,
                  icon: const Icon(Icons.ondemand_video),
                  label: Text(player.removeAds ? 'Revive' : 'Watch an ad to revive'),
                ),
                TextButton(onPressed: () => setState(sim.declineRevive), child: const Text('Give up')),
              ],
            ),
          ),
        ),
      ),
    );
  }

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
        const SizedBox(height: 20),
        SizedBox(
          width: 220,
          child: FilledButton(onPressed: _resume, child: const Text('Resume')),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 220,
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SettingsScreen(store: deps.profile))),
            child: const Text('Settings', style: TextStyle(color: Colors.white)),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 220,
          child: OutlinedButton(
            onPressed: _concede,
            child: const Text('Concede', style: TextStyle(color: Colors.white)),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 220,
          child: OutlinedButton(
            onPressed: () => goHome(context),
            child: const Text('Main Menu', style: TextStyle(color: Colors.white)),
          ),
        ),
        const SizedBox(height: 8),
        const Text('Main Menu restarts this round from Tee Off next time.', style: TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    ),
  );
}

class _Hud extends StatelessWidget {
  const _Hud({required this.sim, required this.title, required this.onPause});

  final RoundSim sim;
  final String title;
  final VoidCallback? onPause;

  String get _waveText => switch (sim.phase) {
    RoundPhase.prep => 'Prep',
    RoundPhase.buildBreak => 'Build break',
    _ when sim.isBossWave => sim.finalBossRound ? 'Final boss' : 'Mini-boss',
    _ => 'Wave ${sim.wave}/${sim.normalWaves}',
  };

  @override
  Widget build(BuildContext context) {
    final hp = (sim.health / sim.maxHealth).clamp(0.0, 1.0);
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
                Text('${'🚩' * sim.flags}${'·' * math.max(0, sim.rules.i('teeBox.flags') - sim.flags)}'),
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
                  child: Container(color: Colors.white70),
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

class _SelectedTower extends StatelessWidget {
  const _SelectedTower({required this.sim, required this.tower});

  final RoundSim sim;
  final STower tower;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Card(
      color: const Color(0xDD263238),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          '${tower.spec.name} · level ${tower.level}${tower.active ? '' : ' · disabled'}\nHold the tower to upgrade or sell.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
    ),
  );
}
