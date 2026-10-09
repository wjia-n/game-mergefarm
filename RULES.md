# Merge Farm — Rules

The authoritative source of truth for Merge Farm gameplay. The engine must
enforce these rules; if the implementation conflicts with this document, fix
the implementation.

## 1. Objective

Grow the most prosperous cozy farm: plant seeds, merge matching crops into
higher tiers, and fill customer orders (plus the daily Harvest Basket) for
coins. Raise your Farm Level to unlock bigger merges and more order slots.

## 2. Setup

- 6×6 grid (36 soil plots), all empty except: plot 7 and plot 10 start with a
  tier-0 seedling, plot 28 starts with a tier-1 sprout.
- Player starts with 60 coins at Farm Level 1 (0 XP).
- 3 customer orders + 1 seasonal festival order are dealt.
- Today's Harvest Basket (daily challenge) is generated deterministically
  from the calendar date.
- Merge cap starts at tier 3 (two tier-3 crops merge into tier-4 only from
  level 2; cap = min(3 + level − 1, 6)).

## 3. Turn order

Merge Farm is a single-player, untimed puzzle. There are no turns — the
player acts freely whenever the engine phase is `ready`.

## 4. Legal moves

1. **Plant:** tap an empty plot with nothing selected → a tier-0 seedling is
   planted if the player can afford it (cost = 6 + level coins). The seedling
   visibly pops out of the soil.
2. **Select:** tap a crop with nothing selected → it is highlighted.
3. **Deselect:** tap the selected crop again, or tap an empty plot while a
   crop is selected → selection clears.
4. **Merge:** tap a crop, then tap a second crop of the SAME tier → the
   first crop visibly travels to the second and they become one crop of
   tier+1. Merge gives 2 XP.
5. **Fill order:** tap "Fill" on a customer order when the farm holds every
   required crop → the required crops visibly fly to the order card, coins
   are paid, XP is granted (max(4, reward/6)), and a fresh order is dealt.
6. **Fill daily basket:** same as an order, once per day; grants the daily
   reward (doubled for Pro) and 12 XP.
7. **End day:** ends the session with a summary; the farm persists unchanged.

## 5. Illegal moves

- Planting without enough coins → the plot wobbles and an "invalid" sound
  plays; no coins are taken, no seedling appears.
- Merging two crops of DIFFERENT tiers → the tap switches the selection to
  the tapped crop (never an error, never a penalty).
- Merging at or above the current merge cap → treated as a different-tier
  tap (selection switches); the cap is shown via the level banner.
- Tapping "Fill" without the required crops → the button is disabled; if
  triggered anyway, only feedback plays and nothing is consumed.
- No input is accepted while the engine is animating/settling — taps are
  ignored until the phase returns to `ready`.

## 6. Captures

Not applicable — there are no opponents or captures in Merge Farm.

## 7. Special rules

- **Merge cap:** crops may merge up to `min(3 + level − 1, 6)`. Tier 6 is the
  absolute top tier and can never merge further.
- **Deterministic harvest:** filling an order consumes the lowest-index
  matching crops first.
- **Seasonal festival order:** one extra order slot exists during the
  current season's event; its reward is doubled. Completing it deals a new
  seasonal order.
- **Daily basket:** deterministic per calendar date (seeded RNG). Completing
  it marks the date done; it regenerates automatically the next day.
- **No fail state:** the farm can never be lost. Coins can always be earned
  again by filling orders.

## 8. Scoring

- Coins are the score. Orders pay `sum((tier+1) × count × 12) + 18..33`
  (×2 when seasonal). The daily basket pays `100 + 25 × level` (×2 for Pro).
- Level-ups grant `20 × level` bonus coins.
- Lifetime stats tracked: orders filled, merges, coins earned.

## 9. Winning conditions

Merge Farm is an endless cozy game — there is no final win. Milestones:
reaching Farm Level milestones, growing a tier-6 crop, completing the daily
basket, and filling every seasonal festival order.

## 10. Draw conditions

Not applicable.

## 11. AI strategy

Not applicable — single-player game, no bots.

## 12. Edge cases

- **Grid full with no merges possible:** the player can still fill orders
  (freeing plots) or end the day. Planting is blocked only by coins, not by
  space — a full grid simply means taps on empty plots can't happen.
- **App killed mid-animation:** on next launch the farm restores from the
  last persisted snapshot; animations are never persisted, so the phase is
  always `ready` after restore.
- **Day rollover while playing:** the watchdog regenerates the daily basket
  automatically; an in-progress day's completion is never revoked.
- **Order needs a tier above the merge cap:** orders only ever request tiers
  within the current cap (order generation uses `tierCap`).
- **Corrupt save data:** restore falls back to a fresh farm — never a
  half-loaded one.
- **Level-up during a fill:** multiple level-ups resolve in one pass; each
  grants its coin bonus and raises the merge cap.

## Modes

Merge Farm ships three modes; each mode keeps its OWN saved farm, so
sessions never clobber each other.

1. **Endless farm** (default): the full game described above — orders, XP,
   farm levels, merge cap growth, daily Harvest Basket, seasonal festival
   order.
2. **Level packs:** four curated packs (Sprout Fields, Sunny Rows, Golden
   Acres, Harvest Crown). Each pack starts with fixed coins and a scattered
   set of seedlings, and has two clear goals: grow a crop of a target tier
   AND fill a target number of orders. Goals are checked after every merge
   and every order fill; meeting both at once completes the pack — a
   victory sheet appears (never an auto-advance), the pack is marked done,
   and the next pack unlocks. Pack 1 is always unlocked; progress persists.
   Pack farms otherwise follow all endless rules (merge cap grows with
   level, seasonal order present). Ending the day in a pack shows the
   normal summary unless the pack just completed.
3. **Relaxed zen:** pure merge zen — planting is FREE, there are NO orders
   (no order slots, no daily, no seasonal), NO XP and NO levels; the full
   merge ladder (tier 0–6) is open from the start. Everything else (merge
   rules, animations, persistence) is identical.

## 13. Test cases

1. Plant with 60 coins at level 1 (cost 7): coins become 53, seedling appears
   with a pop animation.
2. Plant with 0 coins: plot wobbles, invalid sound, coins stay 0.
3. Select crop A, tap matching crop B: B becomes tier+1 with a visible
   travel animation; A’s plot empties; merges +1; XP +2.
4. Select crop A, tap different-tier crop C: selection moves to C, no merge.
5. Merge two tier-3 crops at level 1 (cap 3): no merge; selection switches.
6. Fill an order the farm can satisfy: crops fly to the card, coins increase
   by exactly the reward, a new order appears.
7. Fill button is disabled when crops are missing.
8. Daily basket completes once; second attempt is rejected; reward doubles
   for Pro.
9. XP crossing the threshold levels up: coins bonus granted, cap raised,
   banner shows.
10. Kill the app mid-merge animation; relaunch: farm intact, phase ready,
    no stuck input.
11. Corrupt the farm JSON; relaunch: fresh starter farm, no crash.
12. Buy Pro (store configured): themes/styles unlock immediately and persist
    across restart. Store unconfigured: Pro screen shows the honest
    "after store setup" state, never a fake buy button.
13. Level pack win: in Sprout Fields, reach tier 3 AND 2 pack orders — the
    victory sheet appears, pack 1 is marked done, pack 2 unlocks.
14. Relaxed zen: planting costs 0 coins; no orders are dealt; tier-5 and
    tier-6 merges are legal immediately.
15. Mode isolation: play a pack, then open endless — each restores its own
    saved farm; a pack snapshot never loads into endless.
16. Rename the farmer mid-keystroke: every keystroke persists; kill the app
    mid-word — the partial name restores exactly.
