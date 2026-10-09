import 'package:flutter/material.dart';

/// Farm theme catalog for Merge Farm.
///
/// Every theme stays inside the cozy-farm material world (barn wood, fences,
/// tilled soil, grass, sun) — variety comes from different seasons, woods,
/// soils and light. No neon, no cyberpunk, no generic dashboards.
class FarmThemeDef {
  final String id;
  final String name;
  final Color woodDeep; // barn shadow / header background
  final Color wood; // fences, frames
  final Color woodLight; // rails, accents
  final Color grassLight; // page background
  final Color grassDark; // board bed
  final Color soilLight; // plot top
  final Color soilDark; // plot bottom
  final Color surface; // cards
  final Color text;
  final Color muted;
  final Color gold; // coins / accents

  const FarmThemeDef({
    required this.id,
    required this.name,
    required this.woodDeep,
    required this.wood,
    required this.woodLight,
    required this.grassLight,
    required this.grassDark,
    required this.soilLight,
    required this.soilDark,
    required this.surface,
    required this.text,
    required this.muted,
    required this.gold,
  });
}

class FarmThemes {
  /// First 4 are the FREE starter themes. The rest are PRO.
  static const List<String> freeThemeIds = [
    'pasture',
    'harvest',
    'orchard',
    'twilight',
  ];

  static bool isProTheme(String id) => !freeThemeIds.contains(id) && id != 'custom';

  static const List<FarmThemeDef> all = [
    FarmThemeDef(
      id: 'pasture',
      name: 'Sunny Pasture',
      woodDeep: Color(0xFF4A2C14),
      wood: Color(0xFF7A4E24),
      woodLight: Color(0xFFA9713B),
      grassLight: Color(0xFFDCE8B4),
      grassDark: Color(0xFF9DBE6E),
      soilLight: Color(0xFF8A5A33),
      soilDark: Color(0xFF5E3A1F),
      surface: Color(0xFFFFF8E7),
      text: Color(0xFF3E2A18),
      muted: Color(0xFF7A6248),
      gold: Color(0xFFC99A2E),
    ),
    FarmThemeDef(
      id: 'harvest',
      name: 'Golden Harvest',
      woodDeep: Color(0xFF4E2F10),
      wood: Color(0xFF825122),
      woodLight: Color(0xFFB07A35),
      grassLight: Color(0xFFF3E3B0),
      grassDark: Color(0xFFD9B96A),
      soilLight: Color(0xFF7C4E28),
      soilDark: Color(0xFF523016),
      surface: Color(0xFFFFF6E0),
      text: Color(0xFF45300F),
      muted: Color(0xFF86704A),
      gold: Color(0xFFD4A017),
    ),
    FarmThemeDef(
      id: 'orchard',
      name: 'Apple Orchard',
      woodDeep: Color(0xFF3F2A12),
      wood: Color(0xFF6E4A22),
      woodLight: Color(0xFF9A6B38),
      grassLight: Color(0xFFD2E8B8),
      grassDark: Color(0xFF93BC68),
      soilLight: Color(0xFF6E4E2E),
      soilDark: Color(0xFF4A3018),
      surface: Color(0xFFFDFBF0),
      text: Color(0xFF2E3A1E),
      muted: Color(0xFF6E7A54),
      gold: Color(0xFFB8862E),
    ),
    FarmThemeDef(
      id: 'twilight',
      name: 'Twilight Barn',
      woodDeep: Color(0xFF2B1D3E),
      wood: Color(0xFF4E3A63),
      woodLight: Color(0xFF7A5E94),
      grassLight: Color(0xFFCFC3DE),
      grassDark: Color(0xFF9A8AB8),
      soilLight: Color(0xFF5E4A72),
      soilDark: Color(0xFF3E3050),
      surface: Color(0xFFF3EEDF),
      text: Color(0xFF2E2438),
      muted: Color(0xFF6E6284),
      gold: Color(0xFFC9A24A),
    ),
    FarmThemeDef(
      id: 'clover',
      name: 'Clover Meadow',
      woodDeep: Color(0xFF33431E),
      wood: Color(0xFF55662E),
      woodLight: Color(0xFF7D9048),
      grassLight: Color(0xFFCBE8A8),
      grassDark: Color(0xFF8FC05E),
      soilLight: Color(0xFF6B4A28),
      soilDark: Color(0xFF472F16),
      surface: Color(0xFFF8FCEC),
      text: Color(0xFF2E3A18),
      muted: Color(0xFF66744C),
      gold: Color(0xFFB08D2A),
    ),
    FarmThemeDef(
      id: 'pumpkin',
      name: 'Pumpkin Patch',
      woodDeep: Color(0xFF4A2410),
      wood: Color(0xFF7A421E),
      woodLight: Color(0xFFAA6232),
      grassLight: Color(0xFFE8CDA0),
      grassDark: Color(0xFFC99A5E),
      soilLight: Color(0xFF74401E),
      soilDark: Color(0xFF4E2810),
      surface: Color(0xFFFFF2E2),
      text: Color(0xFF442410),
      muted: Color(0xFF7E5E3E),
      gold: Color(0xFFC0761E),
    ),
    FarmThemeDef(
      id: 'blossom',
      name: 'Cherry Blossom Farm',
      woodDeep: Color(0xFF4E2A34),
      wood: Color(0xFF7E4652),
      woodLight: Color(0xFFAA6E7A),
      grassLight: Color(0xFFF5D8DC),
      grassDark: Color(0xFFD8A8B0),
      soilLight: Color(0xFF6E4A3A),
      soilDark: Color(0xFF4A3024),
      surface: Color(0xFFFFF4F6),
      text: Color(0xFF4A2430),
      muted: Color(0xFF8A6A70),
      gold: Color(0xFFC09A4A),
    ),
    FarmThemeDef(
      id: 'lavender',
      name: 'Lavender Fields',
      woodDeep: Color(0xFF3A2E52),
      wood: Color(0xFF5E4E80),
      woodLight: Color(0xFF8A76AE),
      grassLight: Color(0xFFDCD2EC),
      grassDark: Color(0xFFA894C8),
      soilLight: Color(0xFF5E4A52),
      soilDark: Color(0xFF403038),
      surface: Color(0xFFF6F0FB),
      text: Color(0xFF362A48),
      muted: Color(0xFF77688E),
      gold: Color(0xFFB08D3E),
    ),
    FarmThemeDef(
      id: 'winter',
      name: 'Winter Homestead',
      woodDeep: Color(0xFF22303E),
      wood: Color(0xFF3E5064),
      woodLight: Color(0xFF64788E),
      grassLight: Color(0xFFDCE8F0),
      grassDark: Color(0xFFA8BED0),
      soilLight: Color(0xFF5E6A78),
      soilDark: Color(0xFF404A56),
      surface: Color(0xFFF2F6FA),
      text: Color(0xFF22303E),
      muted: Color(0xFF64788E),
      gold: Color(0xFFB08D3E),
    ),
    FarmThemeDef(
      id: 'desert',
      name: 'Desert Oasis',
      woodDeep: Color(0xFF4E361E),
      wood: Color(0xFF7A5A32),
      woodLight: Color(0xFFAA824E),
      grassLight: Color(0xFFF0DCB0),
      grassDark: Color(0xFFD8B878),
      soilLight: Color(0xFF8A6234),
      soilDark: Color(0xFF5E401E),
      surface: Color(0xFFFFF6E2),
      text: Color(0xFF4A3418),
      muted: Color(0xFF8A7048),
      gold: Color(0xFFD4A017),
    ),
    FarmThemeDef(
      id: 'jungle',
      name: 'Rainforest Grove',
      woodDeep: Color(0xFF1E3324),
      wood: Color(0xFF38543A),
      woodLight: Color(0xFF5A7E58),
      grassLight: Color(0xFFB8D8A0),
      grassDark: Color(0xFF6EA85E),
      soilLight: Color(0xFF4E3A24),
      soilDark: Color(0xFF322414),
      surface: Color(0xFFF0F8E8),
      text: Color(0xFF1E3020),
      muted: Color(0xFF5A7050),
      gold: Color(0xFFA8842A),
    ),
    FarmThemeDef(
      id: 'mill',
      name: 'Rustic Mill',
      woodDeep: Color(0xFF38322C),
      wood: Color(0xFF5E5648),
      woodLight: Color(0xFF8A7E6A),
      grassLight: Color(0xFFD8D2C2),
      grassDark: Color(0xFFA8A090),
      soilLight: Color(0xFF6A5A44),
      soilDark: Color(0xFF483E30),
      surface: Color(0xFFF8F4EA),
      text: Color(0xFF38322C),
      muted: Color(0xFF7A7060),
      gold: Color(0xFFA8842A),
    ),
  ];

  static FarmThemeDef byId(String id, {FarmThemeDef? custom}) {
    if (id == 'custom' && custom != null) return custom;
    for (final t in all) {
      if (t.id == id) return t;
    }
    return all.first;
  }
}

/// Crop/animal style catalog — the emoji "pieces" grown on the farm.
/// 7 tiers per style; merging two of tier N grows one of tier N+1.
/// First 4 are FREE; the rest (and the custom creator) are PRO.
class CropStyleDef {
  final String id;
  final String name;
  final List<String> tiers; // exactly 7

  const CropStyleDef({
    required this.id,
    required this.name,
    required this.tiers,
  });
}

class CropStyles {
  static const List<String> freeStyleIds = [
    'classic',
    'veggie',
    'berries',
    'flowers',
  ];

  static bool isProStyle(String id) =>
      !freeStyleIds.contains(id) && id != 'custom';

  static const List<CropStyleDef> all = [
    CropStyleDef(
      id: 'classic',
      name: 'Classic Crops',
      tiers: ['🌱', '🌿', '🌾', '🌻', '🎃', '🍎', '🧺'],
    ),
    CropStyleDef(
      id: 'veggie',
      name: 'Veggie Patch',
      tiers: ['🌱', '🥬', '🥒', '🌽', '🍅', '🥕', '🧺'],
    ),
    CropStyleDef(
      id: 'berries',
      name: 'Berry Fields',
      tiers: ['🌱', '🫐', '🍇', '🍓', '🍒', '🍉', '🥝'],
    ),
    CropStyleDef(
      id: 'flowers',
      name: 'Flower Meadow',
      tiers: ['🌱', '🌷', '🌸', '🌼', '🌻', '🌺', '🌹'],
    ),
    CropStyleDef(
      id: 'tropical',
      name: 'Tropical Grove',
      tiers: ['🌱', '🌴', '🍌', '🥥', '🍍', '🥭', '🏝️'],
    ),
    CropStyleDef(
      id: 'barnyard',
      name: 'Barnyard Friends',
      tiers: ['🐣', '🐥', '🐤', '🐔', '🦆', '🦢', '🦃'],
    ),
    CropStyleDef(
      id: 'autumn',
      name: 'Autumn Bounty',
      tiers: ['🍂', '🍁', '🎃', '🍎', '🌰', '🥧', '🧺'],
    ),
    CropStyleDef(
      id: 'sweet',
      name: 'Sweet Treats',
      tiers: ['🍯', '🍪', '🧁', '🍩', '🍰', '🎂', '🍾'],
    ),
  ];

  /// Default custom tiers (editable crop creator).
  static const List<String> defaultCustomTiers = [
    '🌱', '🌿', '🌾', '🌻', '🎃', '🍎', '🏆',
  ];

  /// Emoji palette offered in the custom crop creator.
  static const List<String> palette = [
    '🌱', '🌿', '🌾', '🌻', '🎃', '🍎', '🍏', '🍐', '🍒', '🍓',
    '🫐', '🍇', '🍉', '🥝', '🍍', '🥭', '🍌', '🥥', '🍑', '🍊',
    '🥬', '🥒', '🌽', '🍅', '🥕', '🥦', '🧄', '🧅', '🥔', '🍄',
    '🌷', '🌸', '🌼', '🌺', '🌹', '🌵', '🍀', '🍁', '🍂', '🌰',
    '🐣', '🐥', '🐤', '🐔', '🦆', '🐐', '🐑', '🐄', '🐖', '🐴',
    '🍯', '🍪', '🧁', '🍩', '🍰', '🎂', '🥧', '🧺', '🏆', '⭐',
  ];

  static CropStyleDef byId(String id, {List<String>? customTiers}) {
    if (id == 'custom' && customTiers != null && customTiers.length == 7) {
      return CropStyleDef(id: 'custom', name: 'My Crops', tiers: customTiers);
    }
    for (final s in all) {
      if (s.id == id) return s;
    }
    return all.first;
  }
}
