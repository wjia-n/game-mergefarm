import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/splash_screen.dart';
import 'services/audio_service.dart';
import 'services/settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  final settings = FarmSettings();
  await settings.load();
  final audio = FarmAudio();
  audio.configure(
    musicOn: settings.musicOn,
    sfxOn: settings.sfxOn,
    volume: settings.volume,
  );
  runApp(MergeFarmApp(settings: settings, audio: audio));
}

class MergeFarmApp extends StatefulWidget {
  final FarmSettings settings;
  final FarmAudio audio;
  const MergeFarmApp(
      {super.key, required this.settings, required this.audio});

  @override
  State<MergeFarmApp> createState() => _MergeFarmAppState();
}

class _MergeFarmAppState extends State<MergeFarmApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.audio.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause (not stop) on interruption so music resumes exactly where it
    // left off; the game engine's watchdog recovers any in-flight phase.
    if (state == AppLifecycleState.paused) {
      widget.audio.onAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      widget.audio.onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Merge Farm',
      debugShowCheckedModeBanner: false,
      home: SplashScreen(
        audio: widget.audio,
        settings: widget.settings,
      ),
    );
  }
}
