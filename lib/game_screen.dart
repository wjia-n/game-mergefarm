import 'dart:math';
import 'package:flutter/material.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';

class MergeFarmScreen extends StatefulWidget {
  final List<Player> players;
  final GameCallbacks callbacks;
  const MergeFarmScreen({super.key, required this.players, required this.callbacks});
  @override
  State<MergeFarmScreen> createState() => _MergeFarmScreenState();
}

class _Order { Map<int,int> need; int reward; _Order(this.need, this.reward); }

class _MergeFarmScreenState extends State<MergeFarmScreen> {
  static const crops = ['🌱','🌿','🌾','🌻','🎃','🍎','🏆'];
  static const n = 6;
  final rnd = Random();
  final List<int> grid = List.filled(n * n, -1);
  final List<_Order> orders = [];
  int coins = 40, earned = 0, merges = 0;
  int sel = -1; bool over = false;

  @override
  void initState() {
    super.initState();
    grid[7] = 0; grid[10] = 0; grid[28] = 1;
    for (int i = 0; i < 3; i++) { orders.add(_newOrder()); }
  }

  _Order _newOrder() {
    final tier = rnd.nextInt(4);
    final need = <int,int>{tier: 2 + rnd.nextInt(2)};
    if (rnd.nextBool()) need[tier == 3 ? 2 : tier + 1] = 1;
    final reward = need.entries.fold(0, (s, e) => s + e.key * e.value * 14) + 20 + rnd.nextInt(20);
    return _Order(need, reward);
  }

  void _onTap(int i) {
    if (over) return;
    setState(() {
      if (grid[i] == -1) {
        if (sel >= 0) { sel = -1; return; }
        if (coins < 10) return;
        coins -= 10; grid[i] = 0; Sfx.tap();
        return;
      }
      if (sel == -1) { sel = i; Sfx.tap(); return; }
      if (sel == i) { sel = -1; return; }
      if (grid[sel] == grid[i] && grid[i] < crops.length - 1) {
        grid[i] = grid[i] + 1; grid[sel] = -1; sel = -1;
        merges++; Sfx.move();
      } else {
        sel = i; Sfx.tap();
      }
    });
  }

  bool _canFill(_Order o) {
    final have = <int,int>{};
    for (final g in grid) { if (g >= 0) have[g] = (have[g] ?? 0) + 1; }
    return o.need.entries.every((e) => (have[e.key] ?? 0) >= e.value);
  }

  void _fill(_Order o) {
    if (!_canFill(o)) return;
    setState(() {
      for (final e in o.need.entries) {
        int left = e.value;
        for (int i = 0; i < grid.length && left > 0; i++) {
          if (grid[i] == e.key) { grid[i] = -1; left--; }
        }
      }
      coins += o.reward; earned += o.reward;
      widget.players.first.score = earned;
      orders.remove(o); orders.add(_newOrder());
      Sfx.win();
    });
  }

  void _retire() {
    if (over) return; over = true;
    widget.callbacks.finish(
      headline: '🚜 Farm retired with $earned coins earned!',
      subline: '$merges merges · top crop: ${crops[grid.fold(0, (a, b) => max(a, b))]}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ThemeController.of(context).theme;
    return Column(children: [
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _chip(t, '🪙 $coins'), const SizedBox(width: 8),
        _chip(t, '💰 earned $earned'), const SizedBox(width: 8),
        _chip(t, '🔗 $merges'),
      ]),
      const SizedBox(height: 6),
      Expanded(
        flex: 5,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: n),
            itemCount: n * n,
            itemBuilder: (c, i) => GestureDetector(
              onTap: () => _onTap(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: sel == i ? t.accent.withValues(alpha: 0.4) : t.surface,
                  borderRadius: t.radius,
                  border: sel == i ? Border.all(color: t.accent, width: 2) : null,
                ),
                child: Center(
                  child: Text(grid[i] == -1 ? '' : crops[grid[i]],
                      style: const TextStyle(fontSize: 26)),
                ),
              ),
            ),
          ),
        ),
      ),
      Text('📋 customer orders', style: TextStyle(color: t.muted, fontWeight: FontWeight.bold)),
      Expanded(
        flex: 3,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            ...orders.map((o) {
              final can = _canFill(o);
              final items = o.need.entries.map((e) => '${crops[e.key]}×${e.value}').join(' ');
              return Card(
                color: t.surface, shape: RoundedRectangleBorder(borderRadius: t.radius),
                child: ListTile(
                  dense: true,
                  title: Text(items, style: TextStyle(color: t.text, fontWeight: FontWeight.bold)),
                  trailing: WajihaButton(
                    label: can ? '🪙${o.reward}' : '…', emoji: '📦',
                    onTap: can ? () => _fill(o) : () {},
                  ),
                ),
              );
            }),
            Center(child: TextButton(
              onPressed: _retire,
              child: Text('🏁 Retire farm', style: TextStyle(color: t.muted)),
            )),
          ],
        ),
      ),
    ]);
  }

  Widget _chip(GameTheme t, String v) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: t.surface, borderRadius: t.radius),
    child: Text(v, style: TextStyle(color: t.text, fontWeight: FontWeight.bold)),
  );
}
