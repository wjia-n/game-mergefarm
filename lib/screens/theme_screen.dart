import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/farm_art.dart';
import '../theme/farm_themes.dart';
import 'pro_screen.dart' show ProScreen;
import '../services/iap_service.dart';

/// Theme studio: 12 farm themes + custom theme creator (colors),
/// 8 crop styles + custom crop creator (emoji per tier).
/// Pro content is locked with a redirect to the Pro screen.
class ThemeScreen extends StatefulWidget {
  final FarmAudio audio;
  final FarmSettings settings;

  const ThemeScreen(
      {super.key, required this.audio, required this.settings});

  @override
  State<ThemeScreen> createState() => _ThemeScreenState();
}

class _ThemeScreenState extends State<ThemeScreen> {
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

  void _goPro() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProScreen(
        audio: widget.audio,
        settings: _s,
        store: StoreService()..init(),
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
        title: Text('Theme studio 🎨',
            style:
                Farm.title(20, theme: t).copyWith(color: t.surface)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Farm themes', style: Farm.title(18, theme: t)),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.85,
            children: [
              for (final th in FarmThemes.all) _themeTile(t, th),
              _customThemeTile(t),
            ],
          ),
          const SizedBox(height: 16),
          Text('Crop styles', style: Farm.title(18, theme: t)),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.85,
            children: [
              for (final cs in CropStyles.all) _cropTile(t, cs),
              _customCropTile(t),
            ],
          ),
          if (_s.isPro) ...[
            const SizedBox(height: 16),
            Text('My crops — custom creator',
                style: Farm.title(18, theme: t)),
            const SizedBox(height: 8),
            _customCropEditor(t),
            const SizedBox(height: 16),
            Text('My farm — custom theme',
                style: Farm.title(18, theme: t)),
            const SizedBox(height: 8),
            _customThemeEditor(t),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- themes
  Widget _themeTile(FarmThemeDef t, FarmThemeDef th) {
    final locked = !_s.isPro && FarmThemes.isProTheme(th.id);
    final active = _s.themeId == th.id;
    return GestureDetector(
      onTap: () {
        widget.audio.click();
        if (locked) {
          _goPro();
          return;
        }
        _s.setTheme(th.id);
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: active ? t.gold : t.wood,
              width: active ? 4 : 2),
          boxShadow: [
            BoxShadow(
              color: t.woodDeep.withValues(alpha: 0.3),
              offset: const Offset(0, 3),
              blurRadius: 0,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  flex: 2,
                  child: Container(color: th.grassDark),
                ),
                Expanded(
                  child: Container(color: th.soilLight),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  color: th.woodDeep,
                  child: Text(
                    th.name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: th.surface),
                  ),
                ),
              ],
            ),
            if (locked)
              Container(
                color: Colors.black.withValues(alpha: 0.45),
                child: const Center(
                  child: Text('🔒',
                      style: TextStyle(fontSize: 26)),
                ),
              ),
            if (active)
              const Positioned(
                top: 4,
                right: 6,
                child: Text('✅',
                    style: TextStyle(fontSize: 18)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _customThemeTile(FarmThemeDef t) {
    final locked = !_s.isPro;
    final active = _s.themeId == 'custom';
    return GestureDetector(
      onTap: () {
        widget.audio.click();
        if (locked) {
          _goPro();
          return;
        }
        _s.setTheme('custom');
      },
      child: Container(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: active ? t.gold : t.wood,
              width: active ? 4 : 2),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🎨',
                      style: const TextStyle(fontSize: 30)),
                  Text('My Farm',
                      style: Farm.title(12, theme: t)),
                  if (locked)
                    Text('PRO 🔒',
                        style: Farm.muted(10, theme: t)),
                ],
              ),
            ),
            if (active)
              const Positioned(
                top: 4,
                right: 6,
                child: Text('✅',
                    style: TextStyle(fontSize: 18)),
              ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------ crop styles
  Widget _cropTile(FarmThemeDef t, CropStyleDef cs) {
    final locked = !_s.isPro && CropStyles.isProStyle(cs.id);
    final active = _s.cropStyleId == cs.id;
    return GestureDetector(
      onTap: () {
        widget.audio.click();
        if (locked) {
          _goPro();
          return;
        }
        _s.setCropStyle(cs.id);
      },
      child: Container(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: active ? t.gold : t.wood,
              width: active ? 4 : 2),
          boxShadow: [
            BoxShadow(
              color: t.woodDeep.withValues(alpha: 0.3),
              offset: const Offset(0, 3),
              blurRadius: 0,
            ),
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 2,
                    children: [
                      for (final e in cs.tiers)
                        Text(e,
                            style:
                                const TextStyle(fontSize: 17)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(cs.name,
                      textAlign: TextAlign.center,
                      style: Farm.title(10, theme: t)),
                  if (locked)
                    Text('PRO 🔒',
                        style: Farm.muted(10, theme: t)),
                ],
              ),
            ),
            if (locked)
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text('🔒',
                      style: TextStyle(fontSize: 26)),
                ),
              ),
            if (active)
              const Positioned(
                top: 4,
                right: 6,
                child: Text('✅',
                    style: TextStyle(fontSize: 16)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _customCropTile(FarmThemeDef t) {
    final locked = !_s.isPro;
    final active = _s.cropStyleId == 'custom';
    return GestureDetector(
      onTap: () {
        widget.audio.click();
        if (locked) {
          _goPro();
          return;
        }
        _s.setCropStyle('custom');
      },
      child: Container(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: active ? t.gold : t.wood,
              width: active ? 4 : 2),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('✏️', style: const TextStyle(fontSize: 30)),
              Text('My Crops', style: Farm.title(12, theme: t)),
              if (locked) Text('PRO 🔒', style: Farm.muted(10, theme: t)),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------ custom editors
  Widget _customCropEditor(FarmThemeDef t) {
    return WoodCard(
      theme: t,
      child: Column(
        children: [
          for (var tier = 0; tier < 7; tier++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: t.grassDark.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: t.wood, width: 2),
                    ),
                    child: Center(
                      child: Text(_s.customTiers[tier],
                          style: const TextStyle(fontSize: 26)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('Tier ${tier + 1}',
                      style: Farm.title(13, theme: t)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (final e in CropStyles.palette)
                          GestureDetector(
                            onTap: () {
                              widget.audio.select();
                              _s.setCustomTier(tier, e);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: _s.customTiers[tier] == e
                                    ? t.gold.withValues(alpha: 0.5)
                                    : Colors.transparent,
                                borderRadius:
                                    BorderRadius.circular(8),
                              ),
                              child: Text(e,
                                  style: const TextStyle(
                                      fontSize: 20)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static const _swatches = [
    0xFF7A4E24, 0xFF5C3A21, 0xFF3B2416, 0xFFC9A227, 0xFFF5EFE0,
    0xFF9DBE6E, 0xFF4A5A34, 0xFF8A5A33, 0xFFB03A2E, 0xFF1D4E9E,
    0xFF7D3C98, 0xFFD8A8B0, 0xFF64788E, 0xFFE8CDA0, 0xFF2E3A1E,
    0xFF3E2A18,
  ];

  Widget _customThemeEditor(FarmThemeDef t) {
    final labels = {
      'woodDeep': 'Barn shadow',
      'wood': 'Fences',
      'woodLight': 'Rails',
      'grassLight': 'Meadow light',
      'grassDark': 'Meadow dark',
      'soilLight': 'Soil top',
      'soilDark': 'Soil base',
      'surface': 'Cards',
      'text': 'Text',
      'muted': 'Muted text',
      'gold': 'Gold',
    };
    return WoodCard(
      theme: t,
      child: Column(
        children: [
          for (final e in labels.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Color(_s.customColors[e.key]!),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: t.wood, width: 2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                      width: 100,
                      child:
                          Text(e.value, style: Farm.body(13, theme: t))),
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final s in _swatches)
                          GestureDetector(
                            onTap: () {
                              widget.audio.select();
                              _s.setCustomColor(e.key, s);
                            },
                            child: Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: Color(s),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color:
                                      _s.customColors[e.key] == s
                                          ? t.gold
                                          : Colors.black26,
                                  width:
                                      _s.customColors[e.key] == s
                                          ? 3
                                          : 1,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          FarmButton(
            theme: t,
            label: 'Reset my colors 🎨',
            fontSize: 14,
            primary: false,
            onTap: () {
              widget.audio.click();
              _s.resetCustomColors();
            },
          ),
        ],
      ),
    );
  }
}
