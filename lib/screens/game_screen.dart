import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import '../engine/merge_engine.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/farm_art.dart';
import '../theme/farm_themes.dart';

/// The farm itself: 6x6 soil plots, merge moves, order cards, daily
/// challenge, seasonal event. The engine owns ALL phases — this screen only
/// renders [FarmEngine] and plays its event hooks.
class GameScreen extends StatefulWidget {
  final FarmAudio audio;
  final FarmSettings settings;
  final FarmPlayMode mode;
  final int packIndex;

  const GameScreen({
    super.key,
    required this.audio,
    required this.settings,
    this.mode = FarmPlayMode.endless,
    this.packIndex = 0,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with TickerProviderStateMixin {
  late final FarmEngine _engine;
  late final CropStyleDef _style;
  late AnimationController _ticker; // drives anim repaints
  late AnimationController _coinPulse;
  double _shownCoins = 0;
  bool _levelBanner = false;
  Timer? _bannerTimer;
  bool _reviewAsked = false;

  FarmThemeDef get _t => FarmThemes.byId(
        widget.settings.themeId,
        custom: widget.settings.customTheme,
      );

  @override
  void initState() {
    super.initState();
    _style = CropStyles.byId(
      widget.settings.cropStyleId,
      customTiers: widget.settings.customTiers,
    );
    _engine = FarmEngine();
    _engine.isPro = widget.settings.isPro;
    _engine.onEvent = _onEngineEvent;
    final saved = widget.settings.loadFarmFor(
      widget.mode.name,
      widget.packIndex,
    );
    if (saved != null) {
      _engine.restore(
        saved,
        pro: widget.settings.isPro,
        mode: widget.mode,
        packIndex: widget.packIndex,
      );
    } else {
      _engine.fresh(
        pro: widget.settings.isPro,
        mode: widget.mode,
        packIndex: widget.packIndex,
      );
    }
    _engine.addListener(_onEngineChanged);
    _engine.start();
    _shownCoins = _engine.coins.toDouble();
    widget.settings.addListener(_onSettingsChanged);
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    )..repeat();
    _coinPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    widget.audio.startGameMusic();
  }

  void _onSettingsChanged() {
    _engine.isPro = widget.settings.isPro;
  }

  void _onEngineChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _onEngineEvent(String e) {
    final a = widget.audio;
    switch (e) {
      case 'click':
        a.click();
        break;
      case 'plant':
        a.plant();
        break;
      case 'select':
        a.select();
        break;
      case 'merge':
        a.merge();
        break;
      case 'invalid':
        a.invalid();
        break;
      case 'harvest':
        a.harvest();
        break;
      case 'coin':
        a.coin();
        _coinPulse.forward(from: 0);
        break;
      case 'order':
        a.order();
        _maybeAskReview();
        break;
      case 'levelup':
        a.levelUp();
        _showLevelBanner();
        break;
      case 'daily':
        a.daily();
        _maybeAskReview();
        break;
      case 'packwin':
        // Level-pack complete: unlock the next pack (persisted) and
        // celebrate — the victory sheet handles the rest.
        widget.settings.completePack(_engine.packIndex);
        a.win();
        break;
      case 'win':
        a.win();
        break;
      case 'start':
        a.gameStart();
        break;
      case 'dirty':
        widget.settings.saveFarmFor(
          widget.mode.name,
          widget.packIndex,
          _engine.snapshot(),
        );
        break;
    }
  }

  void _showLevelBanner() {
    setState(() => _levelBanner = true);
    _bannerTimer?.cancel();
    _bannerTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _levelBanner = false);
    });
  }

  Future<void> _maybeAskReview() async {
    // Sensible moment: after the 6th filled order, once per install.
    // Graceful when not installed from Play — the call just no-ops/throws.
    if (_reviewAsked || _engine.ordersFilled < 6) return;
    _reviewAsked = true;
    try {
      final r = InAppReview.instance;
      if (await r.isAvailable()) {
        await r.requestReview();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    widget.settings.removeListener(_onSettingsChanged);
    widget.settings.saveFarmFor(
      widget.mode.name,
      widget.packIndex,
      _engine.snapshot(),
    );
    _engine.removeListener(_onEngineChanged);
    _engine.dispose();
    _ticker.dispose();
    _coinPulse.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ rendering
  Offset _cellCenter(int i, double board) {
    final cs = board / FarmEngine.gridN;
    return Offset((i % FarmEngine.gridN + 0.5) * cs,
        (i ~/ FarmEngine.gridN + 0.5) * cs);
  }

  Widget _cropText(int tier, double size) {
    final emoji = (tier >= 0 && tier < _style.tiers.length)
        ? _style.tiers[tier]
        : '❓';
    return Text(
      emoji,
      style: TextStyle(
        fontSize: size,
        shadows: [
          Shadow(
            color: Colors.black.withValues(alpha: 0.35),
            offset: const Offset(0, 2),
            blurRadius: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildBoard(double boardPx) {
    final cs = boardPx / FarmEngine.gridN;
    final mergingTo = <int>{};
    final planting = <int>{};
    final shaking = <int>{};
    for (final a in _engine.anims) {
      if (a.type == FarmAnimType.merge && a.cells.length == 2) {
        mergingTo.add(a.cells[1]);
      } else if (a.type == FarmAnimType.plant && a.cells.isNotEmpty) {
        if (a.tier < 0) {
          shaking.add(a.cells[0]);
        } else {
          planting.add(a.cells[0]);
        }
      }
    }
    return SizedBox(
      width: boardPx,
      height: boardPx,
      child: Stack(
        children: [
          // Grass bed under the plots.
          Container(
            decoration: BoxDecoration(
              color: _t.grassDark,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _t.wood, width: 4),
              boxShadow: [
                BoxShadow(
                  color: _t.woodDeep.withValues(alpha: 0.5),
                  offset: const Offset(0, 6),
                  blurRadius: 12,
                ),
              ],
            ),
          ),
          // Static plots + crops.
          for (var i = 0; i < FarmEngine.cells; i++)
            Positioned(
              left: (i % FarmEngine.gridN) * cs + 3,
              top: (i ~/ FarmEngine.gridN) * cs + 3,
              width: cs - 6,
              height: cs - 6,
              child: GestureDetector(
                onTap: () => _engine.tapCell(i),
                child: _staticCell(i, mergingTo, planting, shaking),
              ),
            ),
          // Animation overlays (traveling / popping / flying crops).
          for (final a in _engine.anims) _animOverlay(a, boardPx),
        ],
      ),
    );
  }

  Widget _staticCell(
      int i, Set<int> mergingTo, Set<int> planting, Set<int> shaking) {
    final v = _engine.grid[i];
    final sel = _engine.selected == i;
    Widget? crop;
    if (v >= 0 && !mergingTo.contains(i) && !planting.contains(i)) {
      crop = Center(child: _cropText(v, 30));
    }
    var dx = 0.0;
    if (shaking.contains(i)) {
      // Invalid-move wobble — driven by the anim's own progress.
      final a = _engine.anims.firstWhere(
          (x) => x.type == FarmAnimType.plant && x.cells.first == i && x.tier < 0);
      dx = sin(a.progress * pi * 4) * 5 * (1 - a.progress);
    }
    return Transform.translate(
      offset: Offset(dx, 0),
      child: PlotCell(
        theme: _t,
        selected: sel,
        radius: 12,
        child: crop,
      ),
    );
  }

  Widget _animOverlay(FarmAnim a, double boardPx) {
    final p = a.progress;
    if (p <= 0) return const SizedBox.shrink();
    final cs = boardPx / FarmEngine.gridN;
    if (a.type == FarmAnimType.merge && a.cells.length == 2) {
      // The crop visibly travels from the source plot to the target.
      final from = _cellCenter(a.cells[0], boardPx);
      final to = _cellCenter(a.cells[1], boardPx);
      final e = 1 - pow(1 - p, 3).toDouble(); // ease-out
      final pos = Offset(
        from.dx + (to.dx - from.dx) * e,
        from.dy + (to.dy - from.dy) * e - sin(p * pi) * cs * 0.55,
      );
      final scale = 0.9 + 0.5 * sin(p * pi);
      return Positioned(
        left: pos.dx - cs / 2,
        top: pos.dy - cs / 2,
        width: cs,
        height: cs,
        child: Center(
          child: Transform.scale(
            scale: scale,
            child: _cropText(a.tier, cs * 0.62),
          ),
        ),
      );
    }
    if (a.type == FarmAnimType.plant && a.tier >= 0) {
      // Seedling pops up with a bounce.
      final c = _cellCenter(a.cells[0], boardPx);
      final e = p < 0.7
          ? (p / 0.7) * 1.15
          : 1.15 - ((p - 0.7) / 0.3) * 0.15; // overshoot settle
      return Positioned(
        left: c.dx - cs / 2,
        top: c.dy - cs / 2,
        width: cs,
        height: cs,
        child: Center(
          child: Transform.scale(
            scale: e.clamp(0.0, 1.2),
            child: Opacity(
              opacity: p.clamp(0.0, 1.0),
              child: _cropText(a.tier, cs * 0.58),
            ),
          ),
        ),
      );
    }
    if (a.type == FarmAnimType.harvest) {
      // Consumed crop flies upward and fades — staggered by delay.
      final c = _cellCenter(a.cells[0], boardPx);
      final dy = -cs * 2.2 * p;
      return Positioned(
        left: c.dx - cs / 2,
        top: c.dy - cs / 2 + dy,
        width: cs,
        height: cs,
        child: Opacity(
          opacity: (1 - p).clamp(0.0, 1.0),
          child: Center(child: _cropText(a.tier, cs * 0.55 * (1 - p * 0.3))),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _orderCard(FarmOrder o) {
    final can = _engine.canFill(o);
    final items = o.needs.entries
        .map((e) =>
            '${(e.key >= 0 && e.key < _style.tiers.length) ? _style.tiers[e.key] : '❓'}×${e.value}')
        .join(' ');
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _t.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: o.seasonal ? _t.gold : _t.wood, width: o.seasonal ? 3 : 2),
        boxShadow: [
          BoxShadow(
            color: _t.woodDeep.withValues(alpha: 0.25),
            offset: const Offset(0, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          if (o.seasonal)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _t.gold,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('🎪',
                  style: TextStyle(fontSize: 14, color: _t.woodDeep)),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(items,
                    style: Farm.title(17, theme: _t)),
                Text('${o.reward} coins',
                    style: Farm.muted(13, theme: _t)),
              ],
            ),
          ),
          FarmButton(
            theme: _t,
            label: can ? 'Fill 📦' : '…',
            fontSize: 14,
            onTap: can && !_engine.inputLocked ? () => _engine.fillOrder(o) : null,
          ),
        ],
      ),
    );
  }

  Widget _dailyCard() {
    final e = _engine;
    if (e.dailyNeeds.isEmpty) return const SizedBox.shrink();
    final items = e.dailyNeeds.entries
        .map((x) =>
            '${(x.key >= 0 && x.key < _style.tiers.length) ? _style.tiers[x.key] : '❓'}×${x.value}')
        .join(' ');
    final can = !e.dailyDone &&
        e.dailyNeeds.entries
            .every((x) => (e.have[x.key] ?? 0) >= x.value);
    final reward = e.isPro ? e.dailyReward * 2 : e.dailyReward;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _t.woodDeep,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _t.gold, width: 2),
      ),
      child: Row(
        children: [
          Text('📅', style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Today\'s Harvest Basket',
                    style: Farm.title(15, theme: _t)
                        .copyWith(color: _t.surface)),
                Text(
                  e.dailyDone ? 'Done! Come back tomorrow 🌅' : '$items → $reward coins${e.isPro ? ' (Pro ×2)' : ''}',
                  style: Farm.muted(13, theme: _t).copyWith(
                      color: _t.surface.withValues(alpha: 0.85)),
                ),
              ],
            ),
          ),
          if (!e.dailyDone)
            FarmButton(
              theme: _t,
              label: 'Fill 🧺',
              fontSize: 14,
              primary: false,
              onTap: can && !e.inputLocked ? () => e.fillDaily() : null,
            )
          else
            Text('✅', style: const TextStyle(fontSize: 24)),
        ],
      ),
    );
  }

  void _confirmEndDay() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _t.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18)),
        title: Text('End the day?',
            style: Farm.title(20, theme: _t)),
        content: Text(
            'Take a breather, farmer! Your farm keeps everything for tomorrow.',
            style: Farm.body(15, theme: _t)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                Text('Keep farming', style: Farm.body(15, theme: _t)),
          FarmButton(
            theme: _t,
            label: 'End day 🌙',
            fontSize: 14,
            onTap: () {
              Navigator.pop(context);
              _engine.endDay();
            },
          ),
        ],
      ),
    );
  }

  Widget _summarySheet() {
    final e = _engine;
    // Pack victory takes precedence over the plain day summary.
    if (e.packComplete && e.packDef != null) return _packVictorySheet();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _t.woodDeep,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🌙 Day\'s end, ${widget.settings.playerName}!',
                style: Farm.display(24, theme: _t)
                    .copyWith(color: _t.surface)),
            const SizedBox(height: 12),
            WoodCard(
              theme: _t,
              child: Column(
                children: [
                  _statRow('🪙 Coins in pocket', '${e.coins}'),
                  _statRow('💰 Lifetime earned', '${e.earned}'),
                  _statRow('🔗 Total merges', '${e.merges}'),
                  _statRow('📦 Orders filled', '${e.ordersFilled}'),
                  _statRow('⭐ Farm level', '${e.level}'),
                  _statRow('🌟 Best crop', _style.tiers[e.maxTierReached]),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FarmButton(
              theme: _t,
              label: 'Keep farming 🚜',
              onTap: () => e.continueAfterSummary(),
            ),
          ],
        ),
      ),
    );
  }

  /// Victory sheet for a completed level pack: recap, next-pack unlock,
  /// replay, or back to the menu.
  Widget _packVictorySheet() {
    final e = _engine;
    final def = e.packDef!;
    final hasNext = e.packIndex + 1 < packDefs.length;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _t.woodDeep,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🏆 ${def.name} complete!',
                textAlign: TextAlign.center,
                style: Farm.display(26, theme: _t)
                    .copyWith(color: _t.surface)),
            const SizedBox(height: 8),
            Text(
              'You grew a ${_style.tiers[def.goalTier]} and filled '
              '${def.goalOrders} orders. Beautiful farming, '
              '${widget.settings.playerName}! 🌾',
              textAlign: TextAlign.center,
              style: Farm.body(15, theme: _t)
                  .copyWith(color: _t.surface.withValues(alpha: 0.9)),
            ),
            const SizedBox(height: 16),
            if (hasNext)
              FarmButton(
                theme: _t,
                label: 'Next pack: ${packDefs[e.packIndex + 1].name} 🚀',
                onTap: () {
                  widget.audio.gameStart();
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => GameScreen(
                        audio: widget.audio,
                        settings: widget.settings,
                        mode: FarmPlayMode.pack,
                        packIndex: e.packIndex + 1,
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FarmButton(
                    theme: _t,
                    label: 'Replay 🔁',
                    fontSize: 15,
                    primary: false,
                    onTap: () {
                      widget.audio.gameStart();
                      _engine.fresh(
                        pro: widget.settings.isPro,
                        mode: FarmPlayMode.pack,
                        packIndex: e.packIndex,
                      );
                      widget.settings.saveFarmFor(
                        FarmPlayMode.pack.name,
                        e.packIndex,
                        _engine.snapshot(),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FarmButton(
                    theme: _t,
                    label: 'Menu 🏠',
                    fontSize: 15,
                    primary: false,
                    onTap: () {
                      widget.audio.click();
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _packGoalsStrip(FarmEngine e) {
    final def = e.packDef!;
    final tierOk = e.maxTierReached >= def.goalTier;
    final ordersOk = e.packOrders >= def.goalOrders;
    final tierEmoji =
        (def.goalTier >= 0 && def.goalTier < _style.tiers.length)
            ? _style.tiers[def.goalTier]
            : '❓';
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      color: _t.wood.withValues(alpha: 0.95),
      child: Text(
        '🗺️ ${def.name}: grow $tierEmoji '
        '${tierOk ? "✅" : "(best: ${_style.tiers[e.maxTierReached]})"}  ·  '
        'fill ${def.goalOrders} orders '
        '${ordersOk ? "✅" : "(${e.packOrders}/${def.goalOrders})"}',
        textAlign: TextAlign.center,
        style: Farm.body(12, theme: _t).copyWith(
            color: _t.surface, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _zenCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _t.woodDeep,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _t.gold, width: 2),
      ),
      child: Row(
        children: [
          Text('🍃', style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Relaxed zen — planting is free, the whole merge ladder is open. No orders, no timers.',
              style: Farm.body(13, theme: _t)
                  .copyWith(color: _t.surface),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statRow(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k, style: Farm.body(15, theme: _t)),
            Text(v,
                style: Farm.title(15, theme: _t)),
          ],
        ),
      );

  // ---------------------------------------------------------------- build
  @override
  Widget build(BuildContext context) {
    final e = _engine;
    final season = SeasonalEvent.current();
    // Animated coin counter: counts up/down toward the real value.
    final target = e.coins.toDouble();
    if ((_shownCoins - target).abs() > 0.5) {
      _shownCoins += (target - _shownCoins) * 0.25;
    } else {
      _shownCoins = target;
    }
    return Scaffold(
      backgroundColor: _t.grassLight,
      body: SafeArea(
        child: Column(
          children: [
            // Header: farm name, coins, level.
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: _t.woodDeep,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      widget.audio.click();
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _t.wood,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.arrow_back,
                          color: _t.surface, size: 20),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.settings.farmName,
                            style: Farm.title(16, theme: _t)
                                .copyWith(color: _t.surface)),
                        Text('${widget.settings.playerName} · Lv ${e.level}',
                            style: Farm.muted(12, theme: _t).copyWith(
                                color: _t.surface
                                    .withValues(alpha: 0.75))),
                      ],
                    ),
                  ),
                  ScaleTransition(
                    scale: Tween(begin: 1.0, end: 1.25).animate(
                      CurvedAnimation(
                          parent: _coinPulse, curve: Curves.easeOut),
                    ),
                    child: FarmChip(
                        theme: _t,
                        text: '🪙 ${_shownCoins.round()}'),
                  ),
                ],
              ),
            ),
            // XP bar.
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              color: _t.woodDeep,
              child: Row(
                children: [
                  Text('⭐', style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: (e.xp / e.xpToNext(e.level))
                            .clamp(0.0, 1.0),
                        minHeight: 10,
                        backgroundColor:
                            _t.surface.withValues(alpha: 0.25),
                        valueColor: AlwaysStoppedAnimation<Color>(
                            _t.gold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${e.xp}/${e.xpToNext(e.level)}',
                      style: Farm.muted(12, theme: _t).copyWith(
                          color: _t.surface
                              .withValues(alpha: 0.8))),
                ],
              ),
            ),
            // Seasonal banner.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 6),
              color: _t.gold.withValues(alpha: 0.9),
              child: Text('🎪 ${season.name} — ${season.blurb}',
                  textAlign: TextAlign.center,
                  style: Farm.body(12, theme: _t).copyWith(
                      color: _t.woodDeep,
                      fontWeight: FontWeight.w800)),
            ),
            // Level-pack goals strip.
            if (widget.mode == FarmPlayMode.pack && e.packDef != null)
              _packGoalsStrip(e),
            // Board.
            Expanded(
              flex: 5,
              child: Center(
                child: LayoutBuilder(
                  builder: (ctx, constraints) {
                    final board = min(constraints.maxWidth - 24,
                        constraints.maxHeight - 8);
                    return AnimatedBuilder(
                      animation: _ticker,
                      builder: (_, __) => _buildBoard(board),
                    );
                  },
                ),
              ),
            ),
            // Level-up banner overlay.
            if (_levelBanner)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _t.gold,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _t.woodDeep, width: 2),
                ),
                child: Text(
                    '⭐ Level ${e.level}! Bigger merges unlocked — merge up to ${_style.tiers[e.tierCap]}!',
                    textAlign: TextAlign.center,
                    style: Farm.title(13, theme: _t)
                        .copyWith(color: _t.woodDeep)),
              ),
            // Orders panel.
            Expanded(
              flex: 4,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _t.grassDark,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20)),
                  border: Border(
                      top: BorderSide(color: _t.wood, width: 4)),
                ),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  children: [
                    if (widget.mode == FarmPlayMode.endless) _dailyCard(),
                    if (widget.mode == FarmPlayMode.relaxed) _zenCard(),
                    ...e.orders.map(_orderCard),
                    const SizedBox(height: 6),
                    Center(
                      child: TextButton(
                        onPressed:
                            e.inputLocked ? null : _confirmEndDay,
                        child: Text('🌙 End the day',
                            style: Farm.muted(14, theme: _t)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomSheet: e.phase == FarmPhase.over ? _summarySheet() : null,
    );
  }
}
