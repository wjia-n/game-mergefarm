import 'package:flutter/material.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';
import 'game_screen.dart';

void main() => runApp(const MergeFarmApp());

class MergeFarmApp extends StatelessWidget {
  const MergeFarmApp({super.key});
  @override
  Widget build(BuildContext context) {
    return GameShell(
      title: 'Merge Farm',
      tagline: 'Merge crops, fill orders, grow your dream farm!',
      emoji: '🌾',
      slug: 'mergefarm',
      howToPlay: '• Tap an empty plot to plant a 🌱 seed (10 coins)\n• Tap a crop, then tap a matching crop to merge up\n• Fill customer orders for big coin payouts\n• No timers, no fails — pure cozy farming zen',
      playerOptions: const [1],
      supportsBots: false,
      gameBuilder: (ctx, players, cb) => MergeFarmScreen(players: players, callbacks: cb),
    );
  }
}
