import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../engine/merge_engine.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/farm_art.dart';
import '../theme/farm_themes.dart';
import 'game_screen.dart';
import 'packs_screen.dart';
import 'pro_screen.dart';
import 'settings_screen.dart';
import 'theme_screen.dart';

/// Main menu — cozy farm edition.
/// Logo, farm name, PLAY, daily-challenge status, seasonal event,
/// theme peek, profile, Pro, settings, share.
class MenuScreen extends StatefulWidget {
  final FarmAudio audio;
  final FarmSettings settings;

  const MenuScreen({super.key, required this.audio, required this.settings});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final StoreService _store = StoreService();

  FarmSettings get _s => widget.settings;
  FarmThemeDef get _t => FarmThemes.byId(
        _s.themeId,
        custom: _s.customTheme,
      );

  @override
  void initState() {
    super.initState();
    widget.audio.startMenuMusic();
    _store.init().then((_) {
      if (mounted) setState(() {});
    });
    _store.lastThanks.addListener(_onThanks);
    _store.proPurchased.addListener(_onPro);
  }

  void _onThanks() {
    final msg = _store.lastThanks.value;
    if (msg == null || !mounted) return;
    widget.audio.win();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: Farm.body(15, theme: _t)),
        backgroundColor: _t.woodDeep,
        behavior: SnackBarBehavior.floating,
      ),
    );
    _store.lastThanks.value = null;
  }

  void _onPro() {
    if (_store.proPurchased.value && mounted) {
      _s.setPro(true);
      widget.audio.win();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PRO unlocked — enjoy everything, farmer!',
              style: Farm.body(15, theme: _t)),
          backgroundColor: _t.woodDeep,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _store.proPurchased.value = false;
    }
  }

  @override
  void dispose() {
    _store.lastThanks.removeListener(_onThanks);
    _store.proPurchased.removeListener(_onPro);
    _store.dispose();
    super.dispose();
  }

  void _playEndless() => _playMode(FarmPlayMode.endless, 0);

  void _playRelaxed() => _playMode(FarmPlayMode.relaxed, 0);

  void _openPacks() {
    widget.audio.click();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PacksScreen(audio: widget.audio, settings: _s),
    ));
  }

  void _playMode(FarmPlayMode mode, int packIndex) {
    widget.audio.gameStart();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          audio: widget.audio,
          settings: _s,
          mode: mode,
          packIndex: packIndex,
        ),
      ),
    );
  }

  void _share() {
    widget.audio.click();
    Share.share(
      'Come farm with me on Merge Farm! 🚜🌾\n'
      'https://play.google.com/store/apps/details?id=com.gameswajiha.mergefarm',
      subject: 'Merge Farm',
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final season = SeasonalEvent.current();
    return Scaffold(
      backgroundColor: t.grassLight,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            const SizedBox(height: 16),
            // Logo + names.
            Center(
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: t.gold, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: t.woodDeep.withValues(alpha: 0.45),
                      offset: const Offset(0, 8),
                      blurRadius: 16,
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset('assets/mergefarm_logo.png',
                    fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 10),
            Text('Merge Farm',
                textAlign: TextAlign.center,
                style: Farm.display(34, theme: t)),
            Text('${_s.farmName} · ${_s.playerName}',
                textAlign: TextAlign.center,
                style: Farm.muted(15, theme: t)),
            const SizedBox(height: 6),
            // Seasonal banner.
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: t.gold.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: t.gold, width: 2),
              ),
              child: Text('🎪 ${season.name}\n${season.blurb}',
                  textAlign: TextAlign.center,
                  style: Farm.body(13, theme: t)),
            ),
            const SizedBox(height: 14),
            // Modes: endless farm, level packs, relaxed zen.
            Center(
              child: SizedBox(
                width: 250,
                child: FarmButton(
                  theme: t,
                  label: '🚜 Endless farm',
                  fontSize: 20,
                  onTap: _playEndless,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FarmButton(
                    theme: t,
                    label: '🗺️ Level packs',
                    fontSize: 15,
                    primary: false,
                    onTap: _openPacks,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FarmButton(
                    theme: t,
                    label: '🍃 Relaxed zen',
                    fontSize: 15,
                    primary: false,
                    onTap: _playRelaxed,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Daily challenge status.
            _dailyPeek(t),
            const SizedBox(height: 10),
            // Stats row.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FarmChip(theme: t, text: '📦 ${_s.ordersFilled}'),
                const SizedBox(width: 8),
                FarmChip(theme: t, text: '🔗 ${_s.merges}'),
                const SizedBox(width: 8),
                FarmChip(theme: t, text: '💰 ${_s.coinsEarned}'),
              ],
            ),
            const SizedBox(height: 16),
            // Action grid.
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.4,
              children: [
                _menuTile(t, '🎨', 'Themes', () {
                  widget.audio.click();
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ThemeScreen(
                        audio: widget.audio, settings: _s),
                  ));
                }),
                _menuTile(t, '⭐', _s.isPro ? 'PRO ✓' : 'Go PRO', () {
                  widget.audio.click();
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ProScreen(
                        audio: widget.audio,
                        settings: _s,
                        store: _store),
                  ));
                }),
                _menuTile(t, '⚙️', 'Settings', () {
                  widget.audio.click();
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => SettingsScreen(
                        audio: widget.audio, settings: _s),
                  ));
                }),
                _menuTile(t, '📣', 'Share', _share),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.asset('assets/wajiha_logo.png',
                      width: 26, height: 26, fit: BoxFit.cover),
                ),
                const SizedBox(width: 8),
                Text('Credits: WAJIHA',
                    style: Farm.muted(13, theme: t)),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _dailyPeek(FarmThemeDef t) {
    final d = _s.loadDaily();
    final key = d?['key'] as String?;
    final today = DateTime.now();
    final todayKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final done = key == todayKey && d?['done'] == true;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.woodDeep,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Text(done ? '✅' : '📅',
              style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              done
                  ? 'Daily basket done! Back tomorrow 🌅'
                  : 'Daily Harvest Basket is ready — big bonus coins!',
              style: Farm.body(13, theme: t)
                  .copyWith(color: t.surface),
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuTile(
      FarmThemeDef t, String emoji, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: t.wood, width: 2),
          boxShadow: [
            BoxShadow(
              color: t.woodDeep.withValues(alpha: 0.3),
              offset: const Offset(0, 3),
              blurRadius: 0,
            ),
          ],
        ),
        child: Center(
          child: Text('$emoji $label',
              style: Farm.title(15, theme: t)),
        ),
      ),
    );
  }
}
