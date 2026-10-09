import 'dart:async';
import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/farm_art.dart';
import '../theme/farm_themes.dart';
import 'menu_screen.dart';

/// Launch splash in two beats (SINGLE splash screen):
/// 1. WAJIHA company moment — the official logo fades in on dark wood.
/// 2. Game splash — logo + name, animated loading line, "Credits: WAJIHA".
class SplashScreen extends StatefulWidget {
  final FarmAudio audio;
  final FarmSettings settings;
  const SplashScreen({super.key, required this.audio, required this.settings});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loader;
  bool _companyDone = false;

  @override
  void initState() {
    super.initState();
    _loader = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _run();
  }

  Future<void> _run() async {
    // Company moment: pre-warm audio while the WAJIHA logo shows,
    // then start menu music.
    unawaited(widget.audio.prewarm());
    unawaited(widget.audio.startMenuMusic());
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    setState(() => _companyDone = true);
    unawaited(_loader.forward());
    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MenuScreen(
          audio: widget.audio,
          settings: widget.settings,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _loader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FarmThemes.byId(
      widget.settings.themeId,
      custom: widget.settings.customTheme,
    );
    // Beat 1: the company moment — official WAJIHA logo, full presence.
    if (!_companyDone) {
      return Scaffold(
        backgroundColor: const Color(0xFF141414),
        body: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 900),
            builder: (_, v, __) => Opacity(
              opacity: v,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset('assets/wajiha_logo.png',
                        width: 170, height: 170, fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 18),
                  Text('WAJIHA',
                      style: Farm.display(30, theme: theme).copyWith(
                        color: const Color(0xFFF5EFE0),
                        letterSpacing: 8,
                      )),
                ],
              ),
            ),
          ),
        ),
      );
    }
    // Beat 2: the game splash.
    return Scaffold(
      backgroundColor: theme.woodDeep,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: theme.gold, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.55),
                    offset: const Offset(0, 10),
                    blurRadius: 24,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset('assets/mergefarm_logo.png',
                  fit: BoxFit.cover),
            ),
            const SizedBox(height: 22),
            Text('Merge Farm',
                style: Farm.display(38, theme: theme).copyWith(
                  color: theme.surface,
                )),
            const SizedBox(height: 6),
            Text('Merge crops, fill orders, grow your dream farm!',
                style: Farm.muted(15, theme: theme).copyWith(
                  color: theme.surface.withValues(alpha: 0.8),
                )),
            const SizedBox(height: 28),
            SizedBox(
              width: 200,
              child: AnimatedBuilder(
                animation: _loader,
                builder: (_, __) => ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _loader.value,
                    minHeight: 10,
                    backgroundColor:
                        theme.surface.withValues(alpha: 0.25),
                    valueColor:
                        AlwaysStoppedAnimation<Color>(theme.gold),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 26),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset('assets/wajiha_logo.png',
                      width: 34, height: 34, fit: BoxFit.cover),
                ),
                const SizedBox(width: 10),
                Text('Credits: WAJIHA',
                    style: Farm.title(16, theme: theme).copyWith(
                      color: theme.surface,
                    )),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
