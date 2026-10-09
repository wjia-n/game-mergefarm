import 'package:flutter/material.dart';
import '../engine/merge_engine.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/farm_art.dart';
import '../theme/farm_themes.dart';
import 'game_screen.dart';

/// Level packs: curated farms with fixed setups and clear goals.
/// Finish a pack to unlock the next. Progress persists across restarts.
class PacksScreen extends StatefulWidget {
  final FarmAudio audio;
  final FarmSettings settings;

  const PacksScreen(
      {super.key, required this.audio, required this.settings});

  @override
  State<PacksScreen> createState() => _PacksScreenState();
}

class _PacksScreenState extends State<PacksScreen> {
  FarmSettings get _s => widget.settings;
  FarmThemeDef get _t => FarmThemes.byId(
        _s.themeId,
        custom: _s.customTheme,
      );

  @override
  void initState() {
    super.initState();
    _s.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _s.removeListener(_refresh);
    super.dispose();
  }

  void _openPack(int i) {
    widget.audio.gameStart();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => GameScreen(
        audio: widget.audio,
        settings: _s,
        mode: FarmPlayMode.pack,
        packIndex: i,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    return Scaffold(
      backgroundColor: t.grassLight,
      appBar: AppBar(
        backgroundColor: t.woodDeep,
        foregroundColor: t.surface,
        title: Text('Level packs 🗺️',
            style: Farm.title(20, theme: t).copyWith(color: t.surface)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Curated farms with clear goals — finish one to unlock the next.',
            style: Farm.muted(14, theme: t),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < packDefs.length; i++) _packCard(t, i),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _packCard(FarmThemeDef t, int i) {
    final def = packDefs[i];
    final unlocked = _s.isPackUnlocked(i);
    final done = _s.isPackDone(i);
    return Opacity(
      opacity: unlocked ? 1.0 : 0.55,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: done ? t.gold : t.wood,
              width: done ? 3 : 2),
          boxShadow: [
            BoxShadow(
              color: t.woodDeep.withValues(alpha: 0.25),
              offset: const Offset(0, 3),
              blurRadius: 0,
            ),
          ],
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          leading: Text(
            done ? '🏆' : (unlocked ? '🗺️' : '🔒'),
            style: const TextStyle(fontSize: 30),
          ),
          title: Text('Pack ${i + 1}: ${def.name}',
              style: Farm.title(16, theme: t)),
          subtitle: Text(def.blurb,
              style: Farm.muted(13, theme: t)),
          trailing: unlocked
              ? FarmButton(
                  theme: t,
                  label: done ? 'Replay' : 'Play',
                  fontSize: 14,
                  onTap: () => _openPack(i),
                )
              : Text('Finish pack $i\nto unlock',
                  textAlign: TextAlign.center,
                  style: Farm.muted(11, theme: t)),
        ),
      ),
    );
  }
}
