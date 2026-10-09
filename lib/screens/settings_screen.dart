import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/farm_art.dart';
import '../theme/farm_themes.dart';

/// Settings: audio toggles + volume, rename player + farm, reset farm,
/// rate in the Play Store, how to play.
class SettingsScreen extends StatefulWidget {
  final FarmAudio audio;
  final FarmSettings settings;

  const SettingsScreen(
      {super.key, required this.audio, required this.settings});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _playerCtl;
  late final TextEditingController _farmCtl;
  late final FocusNode _playerFocus;
  late final FocusNode _farmFocus;

  FarmSettings get _s => widget.settings;
  FarmThemeDef get _t => FarmThemes.byId(
        _s.themeId,
        custom: _s.customTheme,
      );

  @override
  void initState() {
    super.initState();
    _playerCtl = TextEditingController(text: _s.playerName);
    _farmCtl = TextEditingController(text: _s.farmName);
    _playerFocus = FocusNode();
    _farmFocus = FocusNode();
    // Commit the profile on focus loss (keystroke saves happen live via
    // onChanged below).
    _playerFocus.addListener(() {
      if (!_playerFocus.hasFocus) _saveProfileQuiet();
    });
    _farmFocus.addListener(() {
      if (!_farmFocus.hasFocus) _saveProfileQuiet();
    });
    _s.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _s.removeListener(_refresh);
    _playerFocus.dispose();
    _farmFocus.dispose();
    _playerCtl.dispose();
    _farmCtl.dispose();
    super.dispose();
  }

  Future<void> _rate() async {
    widget.audio.click();
    // Real Play Store listing for this app.
    try {
      final r = InAppReview.instance;
      if (await r.isAvailable()) {
        await r.requestReview();
      } else {
        await r.openStoreListing(appStoreId: 'com.gameswajiha.mergefarm');
      }
    } catch (_) {}
  }

  void _confirmReset() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _t.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18)),
        title: Text('Start a fresh farm?',
            style: Farm.title(20, theme: _t)),
        content: Text(
            'This clears your plots, coins, orders and level. Your themes and Pro stay.',
            style: Farm.body(15, theme: _t)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Keep my farm',
                style: Farm.body(15, theme: _t)),
          ),
          FarmButton(
            theme: _t,
            label: 'Fresh start 🌱',
            fontSize: 14,
            onTap: () async {
              Navigator.pop(context);
              widget.audio.gameStart();
              // Clear the saved farm; the next game screen starts fresh.
              await _s.saveFarm(const {});
              if (mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    return Scaffold(
      backgroundColor: t.grassLight,
      appBar: AppBar(
        backgroundColor: t.woodDeep,
        foregroundColor: t.surface,
        title: Text('Settings', style: Farm.title(20, theme: t).copyWith(color: t.surface)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          WoodCard(
            theme: t,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('🔊 Sound', style: Farm.title(17, theme: t)),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: Text('Music', style: Farm.body(15, theme: t)),
                  value: _s.musicOn,
                  activeThumbColor: t.gold,
                  onChanged: (v) {
                    _s.setMusic(v);
                    widget.audio.configure(
                        musicOn: _s.musicOn,
                        sfxOn: _s.sfxOn,
                        volume: _s.volume);
                    if (v) {
                      widget.audio.startMenuMusic();
                    } else {
                      widget.audio.stopMusic();
                    }
                  },
                ),
                SwitchListTile(
                  title: Text('Sound effects', style: Farm.body(15, theme: t)),
                  value: _s.sfxOn,
                  activeThumbColor: t.gold,
                  onChanged: (v) {
                    _s.setSfx(v);
                    widget.audio.configure(
                        musicOn: _s.musicOn,
                        sfxOn: _s.sfxOn,
                        volume: _s.volume);
                  },
                ),
                ListTile(
                  title: Text('Volume', style: Farm.body(15, theme: t)),
                  subtitle: Slider(
                    value: _s.volume,
                    activeColor: t.gold,
                    onChanged: (v) {
                      _s.setVolume(v);
                      widget.audio.configure(
                          musicOn: _s.musicOn,
                          sfxOn: _s.sfxOn,
                          volume: _s.volume);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          WoodCard(
            theme: t,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('👩‍🌾 Your farm', style: Farm.title(17, theme: t)),
                const SizedBox(height: 8),
                TextField(
                  controller: _playerCtl,
                  focusNode: _playerFocus,
                  decoration: InputDecoration(
                    labelText: 'Farmer name',
                    labelStyle: Farm.muted(14, theme: t),
                    border: const OutlineInputBorder(),
                  ),
                  // Save on EVERY keystroke — never wait for keyboard-done.
                  onChanged: (_) => _saveProfileQuiet(),
                  onSubmitted: (_) => _saveProfile(),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _farmCtl,
                  focusNode: _farmFocus,
                  decoration: InputDecoration(
                    labelText: 'Farm name',
                    labelStyle: Farm.muted(14, theme: t),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => _saveProfileQuiet(),
                  onSubmitted: (_) => _saveProfile(),
                ),
                const SizedBox(height: 10),
                FarmButton(
                  theme: t,
                  label: 'Save names ✏️',
                  fontSize: 15,
                  onTap: _saveProfile,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          WoodCard(
            theme: t,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('📖 How to play', style: Farm.title(17, theme: t)),
                const SizedBox(height: 8),
                Text(
                  '• Tap an empty plot to plant a seed (costs coins)\n'
                  '• Tap a crop, then tap a matching crop to merge it up\n'
                  '• Higher farm levels unlock bigger merges\n'
                  '• Fill customer orders for coin payouts\n'
                  '• Finish the daily Harvest Basket for bonus coins\n'
                  '• Festival orders pay DOUBLE during seasonal events\n'
                  '• No timers, no fails — pure cozy farming zen',
                  style: Farm.body(14, theme: t),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          WoodCard(
            theme: t,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('⭐ Enjoying Merge Farm?',
                    style: Farm.title(17, theme: t)),
                const SizedBox(height: 8),
                Text(
                  'A quick rating in the Play Store helps our little farm grow big. Thank you! 🌻',
                  style: Farm.body(14, theme: t),
                ),
                const SizedBox(height: 10),
                FarmButton(
                  theme: t,
                  label: 'Rate in Play Store ⭐',
                  fontSize: 15,
                  primary: false,
                  onTap: _rate,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: _confirmReset,
              child: Text('🌱 Start a fresh farm',
                  style: Farm.muted(14, theme: t)),
            ),
          ),
        ],
      ),
    );
  }

  void _saveProfile() {
    widget.audio.click();
    _s.setProfile(_playerCtl.text, _farmCtl.text);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Looking good, ${_s.playerName} of ${_s.farmName}! 🚜',
            style: Farm.body(14, theme: _t)),
        backgroundColor: _t.woodDeep,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Quiet save used on every keystroke and on focus loss — no snackbar
  /// spam, just persistence (ONE order-safe JSON string).
  void _saveProfileQuiet() {
    _s.setProfile(_playerCtl.text, _farmCtl.text);
  }
}
