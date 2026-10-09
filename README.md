# Merge Farm

A cozy farm merge-puzzle game by Wajiha — plant seeds, merge matching crops
into higher tiers, and fill customer orders for coins. Package:
`com.gameswajiha.mergefarm`.

## Modes

- **Endless farm** — the full game: orders, XP, farm levels, merge-cap growth,
  daily Harvest Basket, seasonal festival orders.
- **Level packs** — 4 curated packs (Sprout Fields → Harvest Crown) with
  fixed setups and clear goals; finish one to unlock the next.
- **Relaxed zen** — free planting, no orders, no XP; the whole merge ladder
  open from the start.

## Architecture

- `lib/engine/merge_engine.dart` — engine-owned `FarmPhase` state machine
  (`ready`/`animating`/`settling`/`over`) with a 1-second watchdog; the UI
  never owns phases, so stuck states are impossible by construction.
- `lib/screens/` — splash (company moment → game splash), menu, game,
  level-pack list, theme studio, settings, Pro screen.
- `lib/services/` — synthesized audio (`FarmAudio`: cached WAV clips,
  generation-serialized music, pause/resume on lifecycle), settings +
  persistence (`FarmSettings`), Play Billing (`StoreService`).
- `lib/theme/` — 12 cozy farm themes + custom theme creator; 8 crop styles +
  custom crop creator; warm physical-material widgets (no neon).

## Key rules (see RULES.md — authoritative)

- 6×6 grid; merge two same-tier crops below the merge cap → tier+1 (2 XP).
- Orders pay coins; daily basket pays `100 + 25 × level` (×2 for Pro).
- Player/farm names persist as ONE order-preserving JSON string
  (`mergefarm_player_names_json`) — never `setStringList`.
- IAP product IDs: `mergefarmpro` (one-time), `mergefarmcoffee`,
  `mergefarmchocolate` (consumables). Graceful before Play Console setup.

## Build

```sh
flutter pub get
flutter analyze
flutter build apk --release
flutter build appbundle --release
```

CI (`.github/workflows/build.yml`) runs analyze + signed release builds on
manual dispatch; signed with the shared Wajiha upload key.
