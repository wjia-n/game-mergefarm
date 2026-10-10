import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/farm_themes.dart';

/// Persisted settings + farm state for Merge Farm. Survives app restarts.
///
/// Stores: audio toggles/volume, renameable profile (player + farm name as
/// ONE order-safe JSON string), theme/appearance choices (incl. custom crop
/// tiers), Pro unlock state, lifetime stats, and the FULL farm state
/// (grid, coins, orders, level/xp, daily-challenge progress, seasonal event).
class FarmSettings extends ChangeNotifier {
  static const _kMusic = 'mergefarm_music_on';
  static const _kSfx = 'mergefarm_sfx_on';
  static const _kVolume = 'mergefarm_volume';
  // Legacy profile keys (migrated once, then removed).
  static const _kLegacyPlayerName = 'mergefarm_player_name';
  static const _kLegacyFarmName = 'mergefarm_farm_name';
  static const _kLegacyProfileJson = 'mergefarm_profile_json';

  /// Order-safe profile storage: ONE JSON string
  /// {"player": "...", "farm": "..."} under `mergefarm_player_names_json`.
  /// Never use a StringList/StringSet for ordered data on Android —
  /// SharedPreferences scrambles their order.
  static const _kProfileJson = 'mergefarm_player_names_json';
  static const _kTheme = 'mergefarm_theme_id';
  static const _kCustomPrefix = 'mergefarm_custom_';
  static const _kCropStyle = 'mergefarm_crop_style';
  static const _kCropTiersJson = 'mergefarm_crop_tiers_json';
  static const _kIsPro = 'mergefarm_is_pro';
  static const _kWins = 'mergefarm_orders_filled';
  static const _kMerges = 'mergefarm_merges';
  static const _kEarned = 'mergefarm_coins_earned';
  static const _kDailyJson = 'mergefarm_daily_json';

  static const defaultPlayerName = 'Farmer';
  static const defaultFarmName = 'Sunny Acres';

  /// Encode the profile (player name + farm name) as one JSON string.
  static String encodeProfile(String player, String farm) =>
      jsonEncode({'player': player, 'farm': farm});

  static Map<String, String> decodeProfile(String? raw) {
    String player = defaultPlayerName;
    String farm = defaultFarmName;
    if (raw != null) {
      try {
        final d = jsonDecode(raw);
        if (d is Map) {
          final p = (d['player'] as String?)?.trim();
          final f = (d['farm'] as String?)?.trim();
          if (p != null && p.isNotEmpty) player = p;
          if (f != null && f.isNotEmpty) farm = f;
        }
      } catch (_) {}
    }
    return {'player': player, 'farm': farm};
  }

  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8;
  String playerName = defaultPlayerName;
  String farmName = defaultFarmName;
  String themeId = 'pasture';
  String cropStyleId = 'classic';
  List<String> customTiers = List.of(CropStyles.defaultCustomTiers);
  Map<String, int> customColors = Map.of(_defaultCustomColors);
  bool isPro = true; // everything unlocked — no Pro version
  int ordersFilled = 0;
  int merges = 0;
  int coinsEarned = 0;

  static const Map<String, int> _defaultCustomColors = {
    'woodDeep': 0xFF4A2C14,
    'wood': 0xFF7A4E24,
    'woodLight': 0xFFA9713B,
    'grassLight': 0xFFDCE8B4,
    'grassDark': 0xFF9DBE6E,
    'soilLight': 0xFF8A5A33,
    'soilDark': 0xFF5E3A1F,
    'surface': 0xFFFFF8E7,
    'text': 0xFF3E2A18,
    'muted': 0xFF7A6248,
    'gold': 0xFFC99A2E,
  };

  /// Builds the user-designed custom theme from stored colors.
  FarmThemeDef get customTheme {
    Color c(String k) => Color(customColors[k] ?? 0xFF000000);
    return FarmThemeDef(
      id: 'custom',
      name: 'My Farm',
      woodDeep: c('woodDeep'),
      wood: c('wood'),
      woodLight: c('woodLight'),
      grassLight: c('grassLight'),
      grassDark: c('grassDark'),
      soilLight: c('soilLight'),
      soilDark: c('soilDark'),
      surface: c('surface'),
      text: c('text'),
      muted: c('muted'),
      gold: c('gold'),
    );
  }

  SharedPreferences? _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs!;
    musicOn = p.getBool(_kMusic) ?? true;
    sfxOn = p.getBool(_kSfx) ?? true;
    volume = p.getDouble(_kVolume) ?? 0.8;
    // Profile: prefer the single JSON key; migrate legacy keys once.
    var raw = p.getString(_kProfileJson);
    if (raw == null) {
      raw = p.getString(_kLegacyProfileJson); // earlier revision's key
    }
    if (raw == null) {
      final legacyPlayer = p.getString(_kLegacyPlayerName);
      final legacyFarm = p.getString(_kLegacyFarmName);
      if (legacyPlayer != null || legacyFarm != null) {
        raw = encodeProfile(
          legacyPlayer ?? defaultPlayerName,
          legacyFarm ?? defaultFarmName,
        );
      }
    }
    if (raw != null) {
      // Normalize everything onto the canonical key.
      await p.setString(_kProfileJson, raw);
    }
    final profile = decodeProfile(raw);
    playerName = profile['player']!;
    farmName = profile['farm']!;
    themeId = p.getString(_kTheme) ?? 'pasture';
    cropStyleId = p.getString(_kCropStyle) ?? 'classic';
    final tiersRaw = p.getString(_kCropTiersJson);
    if (tiersRaw != null) {
      try {
        final d = jsonDecode(tiersRaw);
        if (d is List && d.length == 7 && d.every((e) => e is String)) {
          customTiers = [for (final e in d) e as String];
        }
      } catch (_) {}
    }
    isPro = true; // everything unlocked
    ordersFilled = p.getInt(_kWins) ?? 0;
    merges = p.getInt(_kMerges) ?? 0;
    coinsEarned = p.getInt(_kEarned) ?? 0;
    for (final k in _defaultCustomColors.keys) {
      customColors[k] = p.getInt('$_kCustomPrefix$k') ?? _defaultCustomColors[k]!;
    }
    _loadPacks(p);
    _enforceFreeLimits(silent: true);
    notifyListeners();
  }

  Future<void> _save() async {
    final p = _prefs;
    if (p == null) return;
    await p.setBool(_kMusic, musicOn);
    await p.setBool(_kSfx, sfxOn);
    await p.setDouble(_kVolume, volume);
    await p.setString(_kProfileJson, encodeProfile(playerName, farmName));
    await p.remove(_kLegacyPlayerName);
    await p.remove(_kLegacyFarmName);
    await p.remove(_kLegacyProfileJson);
    await p.setString(_kTheme, themeId);
    await p.setString(_kCropStyle, cropStyleId);
    await p.setString(_kCropTiersJson, jsonEncode(customTiers));
    await p.setBool(_kIsPro, isPro);
    await p.setInt(_kWins, ordersFilled);
    await p.setInt(_kMerges, merges);
    await p.setInt(_kEarned, coinsEarned);
    for (final e in customColors.entries) {
      await p.setInt('$_kCustomPrefix${e.key}', e.value);
    }
  }

  /// Free-tier limits: clamp Pro-only choices back when not Pro.
  void _enforceFreeLimits({bool silent = false}) {
    if (isPro) return;
    var changed = false;
    if (themeId == 'custom' || FarmThemes.isProTheme(themeId)) {
      themeId = 'pasture';
      changed = true;
    }
    if (cropStyleId == 'custom' || CropStyles.isProStyle(cropStyleId)) {
      cropStyleId = 'classic';
      changed = true;
    }
    if (changed && !silent) {
      notifyListeners();
      _save();
    }
  }

  Future<void> setPro(bool v) async {
    isPro = v;
    if (!v) _enforceFreeLimits();
    notifyListeners();
    await _save();
  }

  Future<void> setProfile(String player, String farm) async {
    final p = player.trim();
    final f = farm.trim();
    playerName = p.isEmpty ? defaultPlayerName : p;
    farmName = f.isEmpty ? defaultFarmName : f;
    notifyListeners();
    await _save();
  }

  Future<void> setTheme(String id) async {
    if (!isPro && (id == 'custom' || FarmThemes.isProTheme(id))) return;
    themeId = id;
    notifyListeners();
    await _save();
  }

  Future<void> setCropStyle(String id) async {
    if (!isPro && (id == 'custom' || CropStyles.isProStyle(id))) return;
    cropStyleId = id;
    notifyListeners();
    await _save();
  }

  Future<void> setCustomTier(int index, String emoji) async {
    if (!isPro || index < 0 || index > 6) return;
    customTiers[index] = emoji;
    notifyListeners();
    await _save();
  }

  Future<void> setCustomColor(String key, int argb) async {
    if (!isPro) return; // custom theme creator is a Pro feature
    if (!_defaultCustomColors.containsKey(key)) return;
    customColors[key] = argb;
    notifyListeners();
    await _save();
  }

  Future<void> resetCustomColors() async {
    customColors = Map.of(_defaultCustomColors);
    notifyListeners();
    await _save();
  }

  Future<void> setMusic(bool v) async {
    musicOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setSfx(bool v) async {
    sfxOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setVolume(double v) async {
    volume = v.clamp(0.0, 1.0);
    notifyListeners();
    await _save();
  }

  /// Record an order fill + merges for lifetime stats.
  Future<void> recordStats({int orders = 0, int mergeCount = 0, int earned = 0}) async {
    ordersFilled += orders;
    merges += mergeCount;
    coinsEarned += earned;
    notifyListeners();
    await _save();
  }

  // ------------------------------------------------- full farm persistence
  static const _kPackProgressJson = 'mergefarm_packs_json';

  /// Each play mode keeps its OWN farm so endless / relaxed / pack sessions
  /// never clobber each other.
  static String farmKeyFor(String modeName, int packIndex) {
    if (modeName == 'pack') return 'mergefarm_farm_json_pack_$packIndex';
    if (modeName == 'relaxed') return 'mergefarm_farm_json_relaxed';
    return 'mergefarm_farm_json'; // endless keeps the original key
  }

  /// Save the full live farm state as one JSON string (endless mode).
  Future<void> saveFarm(Map<String, Object?> farmJson) =>
      saveFarmFor('endless', 0, farmJson);

  /// Load the persisted farm state (endless mode), or null if none/invalid.
  Map<String, dynamic>? loadFarm() => loadFarmFor('endless', 0);

  /// Save the full live farm state for a specific mode/pack.
  Future<void> saveFarmFor(
      String modeName, int packIndex, Map<String, Object?> farmJson) async {
    final p = _prefs;
    if (p == null) return;
    try {
      final key = farmKeyFor(modeName, packIndex);
      await p.setString(key, jsonEncode(farmJson));
      // The daily record rides along inside the farm JSON; mirror it to the
      // dedicated daily key so the menu's daily peek can read it cheaply.
      if (modeName == 'endless' && farmJson['daily'] is Map) {
        await p.setString(_kDailyJson, jsonEncode(farmJson['daily']));
      }
    } catch (_) {}
  }

  /// Load the persisted farm state for a specific mode/pack.
  Map<String, dynamic>? loadFarmFor(String modeName, int packIndex) {
    final p = _prefs;
    if (p == null) return null;
    final raw = p.getString(farmKeyFor(modeName, packIndex));
    if (raw == null) return null;
    try {
      final d = jsonDecode(raw);
      if (d is Map<String, dynamic>) return d;
    } catch (_) {}
    return null;
  }

  /// Save the daily-challenge record as one JSON string.
  Future<void> saveDaily(Map<String, Object?> dailyJson) async {
    final p = _prefs;
    if (p == null) return;
    try {
      await p.setString(_kDailyJson, jsonEncode(dailyJson));
    } catch (_) {}
  }

  Map<String, dynamic>? loadDaily() {
    final p = _prefs;
    if (p == null) return null;
    final raw = p.getString(_kDailyJson);
    if (raw == null) return null;
    try {
      final d = jsonDecode(raw);
      if (d is Map<String, dynamic>) return d;
    } catch (_) {}
    return null;
  }

  // ------------------------------------------------------ pack progress
  /// Level-pack progress as ONE order-safe JSON string:
  /// {"unlocked": 1, "done": [0]}. First pack always unlocked; finishing a
  /// pack unlocks the next.
  int _packsUnlocked = 1;
  final Set<int> _packsDone = {};

  int get packsUnlocked => _packsUnlocked;
  bool isPackUnlocked(int i) => i < _packsUnlocked;
  bool isPackDone(int i) => _packsDone.contains(i);

  void _loadPacks(SharedPreferences p) {
    try {
      final raw = p.getString(_kPackProgressJson);
      if (raw != null) {
        final d = jsonDecode(raw);
        if (d is Map) {
          final u = d['unlocked'];
          if (u is int) _packsUnlocked = u.clamp(1, 64);
          final dn = d['done'];
          if (dn is List) {
            for (final v in dn) {
              if (v is int) _packsDone.add(v);
            }
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _savePacks() async {
    final p = _prefs;
    if (p == null) return;
    try {
      await p.setString(
          _kPackProgressJson,
          jsonEncode({
            'unlocked': _packsUnlocked,
            'done': _packsDone.toList(),
          }));
    } catch (_) {}
  }

  /// Mark pack [i] complete; unlocks the next pack. Idempotent.
  Future<void> completePack(int i) async {
    _packsDone.add(i);
    if (_packsUnlocked <= i) _packsUnlocked = i + 1;
    notifyListeners();
    await _savePacks();
  }
}
