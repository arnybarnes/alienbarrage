# Bonus Rounds Spec

## Overview

Every **4th level** (levels 4, 8, 12, 16, 20, ...) is a **Bonus Round** — a non-combat wave where aliens fly across the screen in choreographed formations but **do not shoot or swoop**. The player cannot die during a Bonus Round. The goal is to destroy as many aliens as possible for bonus points.

### Testing Shortcut

For development, add a **debug flag** that starts the game at level 3 (so level 4 bonus round triggers after clearing one wave). This avoids playing through 3 full levels on every test run. Remove before shipping.

---

## Phase 1: LevelManager & Bonus Round Detection [x]

- `LevelManager.config(forLevel:)` checks `level % 4 == 0` → returns a `LevelConfig` with a `isBonusRound: true` flag.
- Bonus rounds still increment `currentLevel`, so level 4 (bonus) is followed by level 5 (normal).
- `GameScene.startNextLevel()` checks `currentConfig.isBonusRound`:
  - If `true`: calls `startBonusRound()` instead of `setupAliens()`.
  - Disables enemy fire timer and swoop timer.
  - Sets a `bonusRoundActive` flag.
- **Powerups do not drop** during bonus rounds.
- **UFOs do not spawn** during bonus rounds.
- Player **can still move and shoot** normally.
- Add the debug start-at-level-3 shortcut.

---

## Phase 2: Entry & Presentation [x]

1. After clearing the preceding level, the standard level-complete flow runs.
2. Instead of "LEVEL N", the overlay reads **"BONUS ROUND"** in a distinct color (gold/yellow).
3. A short subtitle appears beneath: **"Take them out!"**
4. The overlay dismisses after the usual 2.5 seconds, then waves begin.

### CHECKPOINT A — Build & run.
> **How to test**: Start game (level 3 via debug flag), clear the wave. Verify:
> - The overlay says **"BONUS ROUND"** in gold (not "LEVEL 4")
> - Subtitle **"Take them out!"** appears beneath
> - After the overlay dismisses, the screen is empty (no formation spawned) and the player can move/shoot freely
> - No enemy bullets, no swooping aliens, no UFO
>
> **Stop here and let me verify before continuing.**

---

## Phase 3: Wave Structure & Flight Paths [x]

A Bonus Round consists of **5 fly-by waves**, each containing **8 aliens** (40 total targets).

### Wave Timing
- Waves are spaced **~2 seconds** apart (next wave begins 2s after the previous wave's first alien enters).
- Within a wave, aliens enter in quick succession with a **0.15s stagger** between each.

### Flight Paths

Aliens enter from off-screen, follow a curved path across the play area, and **exit off-screen** on the other side. They do not stop or join a formation. Each wave uses a different flight pattern:

| Wave | Entry | Path Description |
|------|-------|-----------------|
| 1 | Top-center | Split into two groups curving outward, then sweeping down in mirrored arcs |
| 2 | Right side | Horizontal S-curve across the screen, exiting left |
| 3 | Bottom corners | Two groups rise upward in crossing diagonal lines (an X pattern) |
| 4 | Top-left | Single-file loop — a large clockwise spiral inward then back out to the right |
| 5 | Both sides simultaneously | Two groups enter from left and right, weave through each other in a braid pattern, exit opposite sides |

Flight paths are implemented as sequences of `CGPoint` waypoints with Bézier interpolation (similar to existing swoop paths). Each alien follows the same path with a time offset based on its stagger position.

### Alien Properties During Bonus Round
- **HP**: 1 (always one-hit kill regardless of level)
- **No shooting**: Enemy fire timer is disabled
- **No swooping**: Swoop timer is disabled
- **No formation**: Aliens are never added to the grid
- **Speed**: Path duration is **3.0 seconds** per alien (entire traversal)

### CHECKPOINT B — Build & run.
> **How to test**: Start game, clear level 3, let the bonus round begin. **Don't shoot — just watch.** Verify:
> - 5 waves of 8 aliens each fly across the screen
> - Each wave has a distinct flight pattern (different entry points, different curves)
> - Aliens enter staggered (not all at once), follow smooth curved paths
> - Aliens exit off-screen cleanly (no lingering sprites)
> - ~2 second gap between waves feels right
> - No enemies shoot at you, no swooping behavior
>
> **Stop here and let me verify before continuing.**

---

## Phase 4: Alien Visuals [x]

Bonus round aliens use the **existing alien sprites** but with a twist:
- All aliens in a single wave are the **same color/type** (one of the 4 variants).
- Each successive wave uses the **next variant**, cycling through all 4 plus a repeat.
- Aliens have a subtle **gold shimmer trail** (particle emitter attached to each alien) to visually distinguish the bonus round from normal gameplay.

### CHECKPOINT C — Build & run.
> **How to test**: Start game, clear level 3, watch the bonus round. Verify:
> - Each wave's aliens are all the same sprite variant
> - Wave 1 uses variant 1, wave 2 uses variant 2, etc.
> - Each alien has a gold shimmer/trail particle effect behind it
> - The trail looks good in motion (not too heavy, not invisible)
> - Shooting an alien: explosion looks normal, trail disappears cleanly
>
> **Stop here and let me verify before continuing.**

---

## Phase 5: Scoring [x]

### Per-Kill Points
Each alien destroyed during a Bonus Round is worth **150 points** (flat rate, not type-dependent).

### End-of-Round Bonus

After the last wave exits (or all 40 are destroyed), a **results tally** is displayed:

```
  BONUS ROUND COMPLETE

     HIT: 32 / 40

    BONUS: 4,800
```

- **Bonus calculation**: `hitsCount × 150` (same as the per-kill value, so effectively double points for each kill)
- **Perfect bonus**: If all 40 are destroyed, the bonus is upgraded to **10,000 points** and the display reads:

```
  BONUS ROUND COMPLETE

     PERFECT!

    BONUS: 10,000
```

The "PERFECT!" text pulses/glows gold.

### Total Points Example
- 40/40 hits: 6,000 (per-kill) + 10,000 (perfect bonus) = **16,000 points**
- 32/40 hits: 4,800 (per-kill) + 4,800 (bonus) = **9,600 points**
- 0/40 hits: 0 + 0 = **0 points**

---

## Phase 6: Results Display [x]

The results screen appears as a centered overlay (similar style to the level overlay):

1. **"BONUS ROUND COMPLETE"** — title text
2. **Hit count** — shown as "HIT: X / 40" (or "PERFECT!" if 40/40)
3. **Bonus value** — animated count-up from 0 to final bonus value over ~1 second
4. A **sound effect** plays on display (distinct chime or fanfare)
5. Display holds for **3.5 seconds**, then dismisses
6. Normal level progression continues — next level loads as usual with `currentLevel` incremented

---

## Phase 7: Level Complete & Results Flow [x]

- `checkLevelComplete()` during a bonus round triggers when all 5 waves have fully exited or been destroyed.
- Track `bonusRoundWavesComplete` (count of waves that have fully exited) and `bonusRoundHits` (aliens destroyed).
- Round ends when `bonusRoundWavesComplete == 5`.
- HUD: During the bonus round, the wave indicator (if any) shows "BONUS" instead of a level number, or simply keeps the level number.
- Score updates in real-time as aliens are hit (the per-kill 150 points).
- The end-of-round bonus is added as a lump sum after the tally animation.

### CHECKPOINT D — Build & run. Full playthrough of a bonus round.
> **How to test**: Play through the bonus round twice — once shooting some aliens, once shooting all of them. Verify:
>
> *Partial hits run (shoot ~20-30 aliens, let the rest fly by):*
> - Score increments by 150 per kill in real-time during the round
> - After the last wave exits, results overlay appears
> - "BONUS ROUND COMPLETE" title, "HIT: X / 40" count is accurate
> - Bonus value counts up from 0 to the correct amount
> - Overlay dismisses after ~3.5 seconds
> - Level 5 starts normally with a regular alien formation
>
> *Perfect run (kill all 40):*
> - Results overlay shows "PERFECT!" instead of hit count
> - Bonus shows 10,000 with gold pulsing text
> - Total score math checks out (6,000 per-kill + 10,000 bonus = 16,000 total from the round)
> - Level 5 starts normally after
>
> **Stop here and let me verify before continuing.**

---

## Phase 8: Edge Cases & Polish [x]

- **Player stops shooting**: Aliens simply fly off-screen. Missed aliens count against the hit total.
- **Active powerups**: Carry over from the previous level normally. Spread shot is particularly useful here. Timers continue to tick.
- **Rapid fire / spread shot**: Work normally, making it easier to hit more targets.
- **Second bonus round**: Level 8 should also trigger a bonus round. Verify the cycle continues.
- Remove the debug start-at-level-3 shortcut.

### CHECKPOINT E — Final verification.
> **How to test**: Play from level 1 through level 8+ (no debug shortcut). Verify:
> - Levels 1-3 play normally
> - Level 4 is a bonus round
> - Level 5 resumes normal gameplay
> - Level 8 is the next bonus round
> - Powerups carrying over from level 3 into the bonus round work correctly
> - No crashes, no orphaned sprites, no audio glitches
>
> **Stop here — feature complete.**

---

## Phase 9: Pattern Variety Per Round [x]

Each bonus round now uses a **different set of 5 wave patterns**, cycling through 4 sets based on the bonus round number (`round % 4`).

### Implementation

- **`BonusPatterns.swift`** — enum with a library of 20 wave patterns grouped into 4 sets of 5.
  - `static func patterns(forBonusRound:screenSize:)` returns 5 closures `(Int) -> CGMutablePath`, one per wave.
  - `round` is 0-indexed: 0 = level 4, 1 = level 8, etc. Selects set via `round % 4`.
- **`GameScene.swift`** — `startBonusRound()` computes the round number and stores the selected pattern closures in `bonusWavePatterns`. `spawnBonusAlien()` uses `bonusWavePatterns[wave](index)`. The old `buildBonusPath()` method was deleted.

### Pattern Sets

| Set | Bonus Round | Patterns |
|-----|-------------|----------|
| **A** | 1st (level 4), 5th (level 20), ... | Top-split, Right S-curve, X-cross, Spiral, Braid |
| **B** | 2nd (level 8), 6th (level 24), ... | V-formation dive, Left S-curve, Figure-8, Rain, Boomerang |
| **C** | 3rd (level 12), 7th (level 28), ... | Diamond, Top zigzag, Funnel, Corkscrew, Pinch |
| **D** | 4th (level 16), 8th (level 32), ... | Cascade, Orbit, Swoop low, Ribbon, Starburst |

### Pattern Descriptions

**Set B:**
1. **V-formation dive** — enter top, split into V shape diving down, exit bottom corners
2. **Left S-curve** — mirror of right S-curve, enter left exit right
3. **Figure-8** — enter left, loop through center twice, exit right
4. **Rain** — enter top spread across width, gentle drift down with slight wave, exit bottom
5. **Boomerang** — enter right, curve left past center, loop back and exit right

**Set C:**
6. **Diamond** — 0-3 from top converge center, exit bottom; 4-7 from bottom converge center, exit top
7. **Top zigzag** — enter top-left, zigzag descending across screen, exit bottom-right
8. **Funnel** — enter wide from top, converge to narrow center point, fan out exiting bottom
9. **Corkscrew** — enter left, tight sinusoidal wave across screen, exit right
10. **Pinch** — 0-3 top-left curving down-right, 4-7 bottom-right curving up-left (crossing)

**Set D:**
11. **Cascade** — enter top-right stepping down, each alien offset lower, exit bottom-left
12. **Orbit** — enter right, large circular loop around screen center, exit right
13. **Swoop low** — enter top, sharp dive to bottom, pull up and exit top opposite side
14. **Ribbon** — enter left mid-height, gentle sine wave across, exit right
15. **Starburst** — all enter center-top, burst outward to different exit points by index

---

## Future Considerations (not in initial implementation)

- Later bonus rounds (level 20+) could have faster flight paths or tighter formations.
- Could introduce a "combo" multiplier for consecutive hits without missing.
- Visual flair: screen background could shift color during bonus rounds.
