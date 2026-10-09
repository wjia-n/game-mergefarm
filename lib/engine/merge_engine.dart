import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';

/// Engine-owned farm state machine for Merge Farm.
///
/// Phases owned entirely by the engine (never by UI timers):
/// - [ready]: awaiting tap input.
/// - [animating]: a plant/merge/harvest animation is in flight; input locked.
/// - [settling]: short engine-owned resolution (order refresh, level-up).
/// - [over]: day ended; shows the summary until the player continues.
///
/// A watchdog ([_watchdog]) ticks every second: any phase stuck without a
/// live animation or pending settle timer is recovered to [ready]. Stuck
/// states are impossible by construction: every non-ready phase has a
/// deadline, and the watchdog enforces it.
enum FarmPhase { ready, animating, settling, over }

enum FarmAnimType { plant, merge, harvest }

/// How this farm session is played.
/// - [endless]: the full cozy farm — orders, XP, levels, daily challenge.
/// - [relaxed]: pure merge zen — planting is free, no orders, no XP, the
///   merge cap is fully open from the start.
/// - [pack]: a curated level pack with fixed setup and clear goals.
enum FarmPlayMode { endless, relaxed, pack }

/// One curated level pack: a fixed starting farm and two clear goals —
/// grow a crop of [goalTier] and fill [goalOrders] orders.
class PackDef {
  final String name;
  final String blurb;
  final int startCoins;
  final int seedCount;
  final int goalTier;
  final int goalOrders;

  const PackDef({
    required this.name,
    required this.blurb,
    required this.startCoins,
    required this.seedCount,
    required this.goalTier,
    required this.goalOrders,
  });
}

const List<PackDef> packDefs = [
  PackDef(
    name: 'Sprout Fields',
    blurb: 'Learn the ropes: grow a tier-3 crop and fill 2 orders.',
    startCoins: 80,
    seedCount: 4,
    goalTier: 3,
    goalOrders: 2,
  ),
  PackDef(
    name: 'Sunny Rows',
    blurb: 'Find your rhythm: grow a tier-4 crop and fill 3 orders.',
    startCoins: 70,
    seedCount: 3,
    goalTier: 4,
    goalOrders: 3,
  ),
  PackDef(
    name: 'Golden Acres',
    blurb: 'A real challenge: grow a tier-5 crop and fill 4 orders.',
    startCoins: 60,
    seedCount: 2,
    goalTier: 5,
    goalOrders: 4,
  ),
  PackDef(
    name: 'Harvest Crown',
    blurb: 'The crown jewel: grow a tier-6 crop and fill 5 orders.',
    startCoins: 50,
    seedCount: 2,
    goalTier: 6,
    goalOrders: 5,
  ),
];

/// A visual animation in flight. The logical state is applied at once; the
/// UI interpolates using these records so every action is SEEN, never popped.
class FarmAnim {
  final String id;
  final FarmAnimType type;
  final List<int> cells; // merge: [from, to]; plant/harvest: [cell]
  final int tier;
  final int delayMs;
  final int durationMs;
  final DateTime startedAt = DateTime.now();

  FarmAnim({
    required this.id,
    required this.type,
    required this.cells,
    required this.tier,
    this.delayMs = 0,
    this.durationMs = 320,
  });

  double get progress {
    final e = DateTime.now().difference(startedAt).inMilliseconds - delayMs;
    if (e <= 0) return 0.0;
    return (e / durationMs).clamp(0.0, 1.0);
  }

  bool get done => progress >= 1.0;

  /// Hard age cap: an animation older than 6s is dead by definition
  /// (watchdog drops it even if [done] never flipped).
  bool get expired =>
      DateTime.now().difference(startedAt).inMilliseconds > delayMs + 6000;
}

class FarmOrder {
  final String id;
  final Map<int, int> needs; // tier -> count
  final int reward;
  final bool seasonal;

  FarmOrder({
    required this.id,
    required this.needs,
    required this.reward,
    this.seasonal = false,
  });
}

/// Seasonal events by month (cozy, farm-appropriate).
class SeasonalEvent {
  final String name;
  final String blurb;

  const SeasonalEvent(this.name, this.blurb);

  static SeasonalEvent current([DateTime? now]) {
    final m = (now ?? DateTime.now()).month;
    if (m >= 3 && m <= 5) {
      return const SeasonalEvent(
          'Spring Bloom Festival', 'Festival orders pay DOUBLE coins!');
    } else if (m >= 6 && m <= 8) {
      return const SeasonalEvent(
          'Summer Sun Fair', 'Festival orders pay DOUBLE coins!');
    } else if (m >= 9 && m <= 11) {
      return const SeasonalEvent(
          'Autumn Harvest Festival', 'Festival orders pay DOUBLE coins!');
    }
    return const SeasonalEvent(
        'Winter Frost Fair', 'Festival orders pay DOUBLE coins!');
  }
}

class FarmEngine extends ChangeNotifier {
  static const int gridN = 6;
  static const int cells = gridN * gridN;
  static const int maxTier = 6; // 7 tiers: 0..6
  static const int startCoins = 60;

  final Random _rnd = Random();
  final List<int> grid = List.filled(cells, -1);
  final List<FarmAnim> anims = [];
  final List<FarmOrder> orders = [];

  int coins = startCoins;
  int level = 1;
  int xp = 0;
  int merges = 0;
  int ordersFilled = 0;
  int earned = 0;
  int selected = -1;
  FarmPhase phase = FarmPhase.ready;
  bool isPro = false;

  // Play mode + pack progress (pack mode only).
  FarmPlayMode playMode = FarmPlayMode.endless;
  int packIndex = 0;
  int packOrders = 0;
  bool packComplete = false;

  PackDef? get packDef => playMode == FarmPlayMode.pack &&
          packIndex >= 0 &&
          packIndex < packDefs.length
      ? packDefs[packIndex]
      : null;

  // Daily challenge
  String dailyKey = '';
  bool dailyDone = false;
  Map<int, int> dailyNeeds = {};
  int dailyReward = 0;

  Timer? _settleTimer;
  Timer? _watchdog;
  int _animSeq = 0;
  bool _disposed = false;

  /// UI hooks: sound events ('click','plant','select','merge','invalid',
  /// 'harvest','coin','order','levelup','daily','win','start'),
  /// 'dirty' when state should be persisted.
  void Function(String event)? onEvent;

  FarmEngine();

  // ------------------------------------------------------------- lifecycle
  void start() {
    _watchdog?.cancel();
    _watchdog = Timer.periodic(const Duration(seconds: 1), (_) => _watch());
  }

  @override
  void dispose() {
    _disposed = true;
    _watchdog?.cancel();
    _settleTimer?.cancel();
    super.dispose();
  }

  // ------------------------------------------------------------- derived
  /// Relaxed zen: the full merge ladder is open from the start.
  int get tierCap => playMode == FarmPlayMode.relaxed
      ? maxTier
      : min(3 + (level - 1), maxTier);

  /// Relaxed zen: planting is always free.
  int get plantCost => playMode == FarmPlayMode.relaxed ? 0 : 6 + level;

  int get orderSlots {
    if (playMode == FarmPlayMode.relaxed) return 0;
    if (playMode == FarmPlayMode.pack) return 3;
    var n = 3 + (level >= 3 ? 1 : 0);
    if (isPro && level >= 5) n += 1;
    return n;
  }

  int xpToNext(int lvl) => 30 + 20 * lvl;

  int get maxTierReached {
    var m = 0;
    for (final g in grid) {
      if (g > m) m = g;
    }
    return m;
  }

  bool get inputLocked => phase != FarmPhase.ready;

  Map<int, int> get have {
    final h = <int, int>{};
    for (final g in grid) {
      if (g >= 0) h[g] = (h[g] ?? 0) + 1;
    }
    return h;
  }

  bool canFill(FarmOrder o) =>
      o.needs.entries.every((e) => (have[e.key] ?? 0) >= e.value);

  bool get canAffordPlant => coins >= plantCost;

  // ---------------------------------------------------------------- moves
  /// Handle a plot tap. All rules enforced here; invalid taps only produce
  /// feedback, never illegal state.
  void tapCell(int i) {
    if (_disposed || inputLocked || i < 0 || i >= cells) return;
    onEvent?.call('click');
    if (grid[i] == -1) {
      // Empty plot: plant a seed (costs coins) or deselect.
      if (selected >= 0) {
        selected = -1;
        notifyListeners();
        return;
      }
      _plant(i);
      return;
    }
    if (selected == -1) {
      selected = i;
      onEvent?.call('select');
      notifyListeners();
      return;
    }
    if (selected == i) {
      selected = -1;
      notifyListeners();
      return;
    }
    final a = grid[selected];
    final b = grid[i];
    if (a == b && a >= 0 && a < tierCap && a < maxTier) {
      _merge(selected, i);
    } else {
      // Different tiers: switch selection (elegant, never an error).
      selected = i;
      onEvent?.call('select');
      notifyListeners();
    }
  }

  void _plant(int i) {
    if (coins < plantCost) {
      onEvent?.call('invalid');
      _shake(i);
      return;
    }
    coins -= plantCost;
    grid[i] = 0;
    _animate(FarmAnimType.plant, [i], 0, durationMs: 380);
    onEvent?.call('plant');
    _settle(400);
    _dirty();
  }

  void _merge(int from, int to) {
    final tier = grid[from];
    grid[from] = -1;
    grid[to] = tier + 1;
    selected = -1;
    merges++;
    _gainXp(2);
    _animate(FarmAnimType.merge, [from, to], tier + 1, durationMs: 420);
    onEvent?.call('merge');
    _settle(440);
    _checkLevelUp();
    _checkPackWin();
    _dirty();
  }

  /// Invalid-move feedback: a tiny wobble anim + the invalid sound.
  /// The state never changes.
  void _shake(int i) {
    _animate(FarmAnimType.plant, [i], -1, durationMs: 240);
    _settle(260);
    notifyListeners();
  }

  bool fillOrder(FarmOrder o) {
    if (_disposed || inputLocked) return false;
    if (!canFill(o)) {
      onEvent?.call('invalid');
      return false;
    }
    // Consume crops lowest-index first (deterministic).
    final consumed = <int>[];
    for (final e in o.needs.entries) {
      var left = e.value;
      for (var i = 0; i < cells && left > 0; i++) {
        if (grid[i] == e.key) {
          consumed.add(i);
          left--;
        }
      }
    }
    for (final i in consumed) {
      grid[i] = -1;
    }
    selected = -1;
    ordersFilled++;
    if (playMode == FarmPlayMode.pack) packOrders++;
    coins += o.reward;
    earned += o.reward;
    _gainXp(max(4, o.reward ~/ 6));
    // Staggered harvest flight: each crop visibly flies to the order card.
    for (var k = 0; k < consumed.length; k++) {
      _animate(FarmAnimType.harvest, [consumed[k]], 0,
          delayMs: k * 90, durationMs: 340);
    }
    onEvent?.call('harvest');
    onEvent?.call('coin');
    Future.delayed(
        Duration(milliseconds: 120 * consumed.length), () => onEvent?.call('order'));
    orders.remove(o);
    if (o.seasonal) {
      _addSeasonalOrder();
    } else {
      _addOrder();
    }
    _settle(140 * consumed.length + 420);
    _checkLevelUp();
    _checkPackWin();
    _dirty();
    return true;
  }

  /// Fill the daily challenge basket.
  bool fillDaily() {
    if (_disposed || inputLocked || dailyDone || dailyNeeds.isEmpty) {
      onEvent?.call('invalid');
      return false;
    }
    final ok = dailyNeeds.entries.every((e) => (have[e.key] ?? 0) >= e.value);
    if (!ok) {
      onEvent?.call('invalid');
      return false;
    }
    final consumed = <int>[];
    for (final e in dailyNeeds.entries) {
      var left = e.value;
      for (var i = 0; i < cells && left > 0; i++) {
        if (grid[i] == e.key) {
          consumed.add(i);
          left--;
        }
      }
    }
    for (final i in consumed) {
      grid[i] = -1;
    }
    selected = -1;
    dailyDone = true;
    final bonus = isPro ? dailyReward * 2 : dailyReward;
    coins += bonus;
    earned += bonus;
    ordersFilled++;
    _gainXp(12);
    for (var k = 0; k < consumed.length; k++) {
      _animate(FarmAnimType.harvest, [consumed[k]], 0,
          delayMs: k * 90, durationMs: 340);
    }
    onEvent?.call('daily');
    onEvent?.call('coin');
    _settle(140 * consumed.length + 420);
    _checkLevelUp();
    _dirty();
    return true;
  }

  void _gainXp(int n) {
    if (playMode == FarmPlayMode.relaxed) return; // zen: no levels
    xp += n;
  }

  void _checkLevelUp() {
    if (playMode == FarmPlayMode.relaxed) return;
    while (xp >= xpToNext(level)) {
      xp -= xpToNext(level);
      level++;
      final bonus = 20 * level;
      coins += bonus;
      earned += bonus;
      onEvent?.call('levelup');
    }
    // Backfill order slots unlocked by the new level.
    while (orders.length < orderSlots) {
      _addOrder();
    }
  }

  /// Level-pack win check: both goals met at once. Fires the 'packwin'
  /// event (the UI unlocks the next pack) and opens the victory phase.
  /// Never auto-resolves anything else — the player taps to continue.
  void _checkPackWin() {
    final def = packDef;
    if (def == null || packComplete || _disposed) return;
    if (maxTierReached >= def.goalTier && packOrders >= def.goalOrders) {
      packComplete = true;
      phase = FarmPhase.over;
      onEvent?.call('packwin');
      notifyListeners();
      _dirty();
    }
  }

  /// End the day: summary phase. Never locks the farm — the player continues
  /// after the summary.
  void endDay() {
    if (_disposed || inputLocked) return;
    phase = FarmPhase.over;
    onEvent?.call('win');
    notifyListeners();
    _dirty();
  }

  void continueAfterSummary() {
    if (phase != FarmPhase.over) return;
    phase = FarmPhase.ready;
    notifyListeners();
  }

  // -------------------------------------------------------------- orders
  FarmOrder _newOrder({bool seasonal = false}) {
    final cap = max(1, tierCap);
    final t1 = _rnd.nextInt(cap);
    final needs = <int, int>{t1: 2 + _rnd.nextInt(2)};
    if (_rnd.nextBool()) {
      final t2 = t1 + 1 <= cap ? t1 + 1 : max(0, t1 - 1);
      needs[t2] = (needs[t2] ?? 0) + 1;
    }
    var reward = needs.entries.fold(0, (s, e) => s + (e.key + 1) * e.value * 12) +
        18 +
        _rnd.nextInt(16);
    if (seasonal) reward *= 2;
    return FarmOrder(
      id: 'o${DateTime.now().microsecondsSinceEpoch}_${_rnd.nextInt(1 << 20)}',
      needs: needs,
      reward: reward,
      seasonal: seasonal,
    );
  }

  void _addOrder() {
    orders.add(_newOrder());
  }

  void _addSeasonalOrder() {
    orders.add(_newOrder(seasonal: true));
  }

  // ------------------------------------------------------ daily challenge
  static String _dayKey([DateTime? now]) {
    final d = now ?? DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  void ensureDaily() {
    final key = _dayKey();
    if (key == dailyKey) return;
    dailyKey = key;
    dailyDone = false;
    // Deterministic per-day needs: seeded by the date string.
    var seed = 0;
    for (final c in key.codeUnits) {
      seed = (seed * 31 + c) & 0x7fffffff;
    }
    final r = Random(seed);
    final cap = max(2, tierCap);
    final t1 = 1 + r.nextInt(cap - 1);
    dailyNeeds = {t1: 2 + r.nextInt(2)};
    if (r.nextBool()) {
      final t2 = max(1, t1 - 1);
      dailyNeeds[t2] = (dailyNeeds[t2] ?? 0) + 1;
    }
    dailyReward = 100 + 25 * level;
    notifyListeners();
  }

  // ------------------------------------------------------------- anim
  void _animate(FarmAnimType type, List<int> cells, int tier,
      {int delayMs = 0, required int durationMs}) {
    phase = FarmPhase.animating;
    anims.add(FarmAnim(
      id: 'a${_animSeq++}',
      type: type,
      cells: cells,
      tier: tier,
      delayMs: delayMs,
      durationMs: durationMs,
    ));
    notifyListeners();
  }

  /// Engine-owned settle: after [ms], if no animation is still live,
  /// the phase returns to [ready]. The watchdog backs this up.
  void _settle(int ms) {
    phase = FarmPhase.settling;
    _settleTimer?.cancel();
    final deadline = DateTime.now().add(Duration(milliseconds: ms + 250));
    _settleTimer = Timer(Duration(milliseconds: ms + 250), () {
      if (_disposed) return;
      _pruneAnims();
      if (phase == FarmPhase.settling && anims.isEmpty) {
        phase = FarmPhase.ready;
        notifyListeners();
      } else if (phase == FarmPhase.settling) {
        // Animations still legitimately in flight — re-arm until deadline.
        if (DateTime.now().isBefore(deadline)) {
          _settleTimer = Timer(const Duration(milliseconds: 300), () {
            if (_disposed) return;
            _pruneAnims();
            if (phase == FarmPhase.settling && anims.isEmpty) {
              phase = FarmPhase.ready;
              notifyListeners();
            }
          });
        }
      }
    });
    notifyListeners();
  }

  void _pruneAnims() {
    anims.removeWhere((a) => a.done || a.expired);
  }

  /// Watchdog: every second, drop dead animations and recover any phase
  /// that has no live animation and no pending settle timer. Runs forever
  /// while the engine lives, so a stuck phase is always transient.
  void _watch() {
    if (_disposed) return;
    final before = anims.length;
    _pruneAnims();
    if (anims.length != before) notifyListeners();
    if ((phase == FarmPhase.animating || phase == FarmPhase.settling) &&
        anims.isEmpty &&
        !(_settleTimer?.isActive ?? false)) {
      phase = FarmPhase.ready;
      selected = -1;
      notifyListeners();
    }
    // Daily rollover check (endless mode only; cheap: once a second is fine).
    if (playMode == FarmPlayMode.endless && _dayKey() != dailyKey) {
      ensureDaily();
    }
  }

  void _dirty() {
    notifyListeners();
    onEvent?.call('dirty');
  }

  // -------------------------------------------------------- persistence
  Map<String, Object?> snapshot() => {
        'grid': List.of(grid),
        'coins': coins,
        'level': level,
        'xp': xp,
        'merges': merges,
        'ordersFilled': ordersFilled,
        'earned': earned,
        'mode': playMode.name,
        'packIndex': packIndex,
        'packOrders': packOrders,
        'packComplete': packComplete,
        'orders': [
          for (final o in orders)
            {
              'id': o.id,
              'needs': {for (final e in o.needs.entries) '${e.key}': e.value},
              'reward': o.reward,
              'seasonal': o.seasonal,
            }
        ],
        'daily': {
          'key': dailyKey,
          'done': dailyDone,
          'needs': {for (final e in dailyNeeds.entries) '${e.key}': e.value},
          'reward': dailyReward,
        },
        'isPro': isPro,
      };

  /// Restore from a snapshot; returns true on success. Any corrupt/missing
  /// data falls back to a fresh farm — never a half-loaded one.
  bool restore(Map<String, dynamic>? json,
      {required bool pro,
      FarmPlayMode mode = FarmPlayMode.endless,
      int packIndex = 0}) {
    isPro = pro;
    try {
      if (json == null) throw const FormatException('no farm');
      final g = json['grid'];
      if (g is! List || g.length != cells) throw const FormatException('grid');
      for (var i = 0; i < cells; i++) {
        final v = g[i];
        grid[i] = (v is int && v >= -1 && v <= maxTier) ? v : -1;
      }
      // A snapshot that doesn't match this session's mode is rejected —
      // each mode keeps its own farm.
      final savedMode = json['mode'];
      final parsedMode = savedMode is String
          ? FarmPlayMode.values.firstWhere(
              (m) => m.name == savedMode,
              orElse: () => FarmPlayMode.endless,
            )
          : FarmPlayMode.endless;
      if (parsedMode != mode ||
          (mode == FarmPlayMode.pack &&
              _asInt(json['packIndex'], -1) != packIndex)) {
        throw const FormatException('mode mismatch');
      }
      playMode = mode;
      this.packIndex = packIndex.clamp(0, packDefs.length - 1);
      packOrders = _asInt(json['packOrders'], 0).clamp(0, 9999);
      packComplete = json['packComplete'] == true;
      coins = _asInt(json['coins'], startCoins).clamp(0, 999999);
      level = _asInt(json['level'], 1).clamp(1, 99);
      xp = _asInt(json['xp'], 0).clamp(0, 999999);
      merges = _asInt(json['merges'], 0);
      ordersFilled = _asInt(json['ordersFilled'], 0);
      earned = _asInt(json['earned'], 0);
      orders.clear();
      final ol = json['orders'];
      if (ol is List) {
        for (final raw in ol) {
          if (raw is Map) {
            final needs = <int, int>{};
            final rn = raw['needs'];
            if (rn is Map) {
              rn.forEach((k, v) {
                final t = int.tryParse('$k');
                if (t != null && v is int && t >= 0 && t <= maxTier) {
                  needs[t] = v.clamp(1, 9);
                }
              });
            }
            if (needs.isNotEmpty) {
              orders.add(FarmOrder(
                id: '${raw['id'] ?? 'o_restored'}',
                needs: needs,
                reward: _asInt(raw['reward'], 30).clamp(5, 9999),
                seasonal: raw['seasonal'] == true,
              ));
            }
          }
        }
      }
      final d = json['daily'];
      if (d is Map) {
        dailyKey = '${d['key'] ?? ''}';
        dailyDone = d['done'] == true;
        final dn = d['needs'];
        dailyNeeds = {};
        if (dn is Map) {
          dn.forEach((k, v) {
            final t = int.tryParse('$k');
            if (t != null && v is int) dailyNeeds[t] = v.clamp(1, 9);
          });
        }
        dailyReward = _asInt(d['reward'], 100);
      }
      if (playMode == FarmPlayMode.endless) {
        ensureDaily(); // regenerates if the day rolled over
      }
      while (orders.length < orderSlots) {
        _addOrder();
      }
      // Guarantee the seasonal slot exists in-season (not in relaxed zen).
      if (playMode != FarmPlayMode.relaxed &&
          !orders.any((o) => o.seasonal)) {
        _addSeasonalOrder();
      }
      phase = FarmPhase.ready;
      selected = -1;
      anims.clear();
      notifyListeners();
      return true;
    } catch (_) {
      fresh(pro: pro, mode: mode, packIndex: packIndex);
      return false;
    }
  }

  static int _asInt(Object? v, int fallback) =>
      v is int ? v : (v is num ? v.toInt() : fallback);

  void fresh({
    required bool pro,
    FarmPlayMode mode = FarmPlayMode.endless,
    int packIndex = 0,
  }) {
    isPro = pro;
    playMode = mode;
    this.packIndex = packIndex.clamp(0, packDefs.length - 1);
    packOrders = 0;
    packComplete = false;
    for (var i = 0; i < cells; i++) {
      grid[i] = -1;
    }
    if (mode == FarmPlayMode.pack) {
      // Curated pack start: fixed coins + scattered seedlings.
      final def = packDefs[this.packIndex];
      coins = def.startCoins;
      final spots = List<int>.generate(cells, (i) => i)..shuffle(_rnd);
      for (var k = 0; k < def.seedCount; k++) {
        grid[spots[k]] = 0;
      }
    } else {
      grid[7] = 0;
      grid[10] = 0;
      grid[28] = 1;
      coins = startCoins;
    }
    level = 1;
    xp = 0;
    merges = 0;
    ordersFilled = 0;
    earned = 0;
    selected = -1;
    phase = FarmPhase.ready;
    anims.clear();
    orders.clear();
    while (orders.length < orderSlots) {
      _addOrder();
    }
    if (mode != FarmPlayMode.relaxed) _addSeasonalOrder();
    dailyKey = '';
    dailyDone = false;
    dailyNeeds = {};
    dailyReward = 0;
    if (mode == FarmPlayMode.endless) ensureDaily();
    notifyListeners();
  }

  String exportJson() => jsonEncode(snapshot());
}
