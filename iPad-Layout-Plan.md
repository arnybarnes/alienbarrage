# iPad Layout Optimization Plan

## Design Decisions

| Decision | Choice |
|----------|--------|
| Scene sizing | **Fully dynamic everywhere** — all devices use actual screen points, no more letterboxing on any model |
| Game element sizes | **Keep iPhone sizes** — more battlefield, not bigger sprites |
| HUD element sizes | **Scale up independently** — readable score/lives on large screens |
| Alien formation | **More columns on iPad**, same row count. Extra columns at **all levels** |
| Landscape | **Include now** — iPad supports both portrait and landscape |
| Landscape gameplay | **Keep vertical shooter** — player bottom, aliens top, wider+shorter viewport |
| Bullet/movement speeds | **Adjust for consistent travel time** — scale with screen dimensions |
| Orientation mid-game | **Lock during gameplay** — menus can auto-rotate, game cannot |
| Menu layout | **Centered column with max width** — simple, clean |
| Difficulty balancing | **Tune per layout** — scale fire rate, swoop frequency, and powerup drops to normalize difficulty across screen sizes |

---

## Current State

The game uses a **fixed 390x844 scene** (iPhone 14/15 dimensions) with `.aspectFit` scaling mode. On iPad this results in heavy letterboxing — black bars fill the unused screen area. All HUD positions, element sizes, and formation layouts are hardcoded for that one resolution. There is zero device-detection or adaptive layout logic anywhere.

---

## 1. Dynamic Scene Size

**File: `Constants.swift`**

Read `UIScreen.main.bounds` at launch and use actual screen points as the scene size. Every layout calculation must be relative to the scene dimensions. This applies to **all devices** — iPhones also get their native screen size instead of the old fixed 390x844. This eliminates letterboxing on every model (SE, Plus/Max, Mini, etc.) at the cost of minor per-model gameplay variation.

- iPhone SE 3rd gen: 375 x 667
- iPhone 13/14/15: 390 x 844
- iPhone Plus/Max: 430 x 932
- iPhone 16 Pro Max: 440 x 956
- iPad portrait: ~768x1024, ~810x1080, ~834x1194, etc.
- iPad landscape: dimensions flip (e.g. 1024x768)
- Switch `scaleMode` from `.aspectFit` to `.resizeFill` so the scene fills the entire screen

The current `sceneWidth` / `sceneHeight` / `sceneSize` statics become computed from the actual screen or are set once at launch.

### iPhone Impact
On non-390x844 iPhones, this means:
- Play area matches the physical screen (no black bars)
- Speeds scale slightly so travel time stays consistent
- HUD positions adapt to each screen's actual dimensions
- Plus/Max models get a slightly wider battlefield
- SE gets a shorter battlefield with compressed vertical spacing

---

## 2. Element Sizing Strategy

**Game elements stay at iPhone sizes** — the ship, aliens, bullets, powerups, and UFO keep their current point dimensions (92x71 ship, 56x43 large alien, etc.). On iPad the playing field is physically larger, giving the player more room to maneuver and making the game feel more expansive.

**HUD elements scale up independently** to remain readable on larger screens:
- Introduce a `hudScale` factor: `max(1.0, min(sceneWidth, sceneHeight) / 844.0)` or similar
- Apply to: score font size, lives icon size, overlay text, buttons
- Gameplay sprites are **not** scaled

---

## 3. Alien Formation Layout

**File: `AlienFormation.swift`**

iPad gets **more columns at all levels** to fill the wider screen.

- Calculate bonus columns based on available width: e.g. `baseColumns + Int((sceneWidth - 390) / 130)` — roughly +2-3 columns on iPad portrait, +4-5 in landscape
- Row count stays the same (scales with level as before)
- `spacingX` / `spacingY`: recalculate relative to scene dimensions rather than hardcoded 65/55
- `edgeMargin` and `movementBuffer`: proportional to scene width
- Formation start Y: `sceneHeight * 0.81` instead of `sceneHeight - 160`
- Step-down distance: proportional to scene height

---

## 4. HUD Repositioning

### Score Display
**File: `ScoreDisplay.swift`**

- X: centered (`sceneWidth / 2`) — no change needed
- Y: `sceneHeight - safeAreaTop - 20` instead of hardcoded `770`
- Font size: `30 * hudScale`

### Lives Display
**File: `LivesDisplay.swift`**

- Position: `(safeAreaLeft + 50, sceneHeight - safeAreaTop - 30)` instead of `(50, sceneHeight - 80)`
- Icon size: `26x20 * hudScale`
- Icon spacing: `30 * hudScale`

### Game Over / Level Transition Overlays
**File: `GameScene.swift`**

- Positions already use `size.width / 2` and `size.height / 2` — good
- Font sizes: scale with `hudScale`
- Continue button: `200x50 * hudScale`
- Vertical offsets between overlay elements: scale proportionally

---

## 5. Player & Movement Bounds

**Files: `PlayerEntity.swift`, `MovementComponent.swift`, `GameScene.swift`**

- Player start Y: `sceneHeight * 0.095` instead of hardcoded `80`
- Respawn position: same proportional formula
- Ship size: **unchanged** (stays 92x71)
- Movement clamp: already uses `sceneWidth - spriteHalfWidth` — works automatically
- Thrust particle offset: unchanged (relative to ship size)

---

## 6. Gameplay Speed Scaling

**Files: `GameScene.swift`, `Constants.swift`**

All speeds scale so **travel time stays consistent** regardless of screen size. Use height ratio for vertical speeds, width ratio for horizontal:

```
heightRatio = sceneHeight / 844.0
widthRatio  = sceneWidth / 390.0
```

- Player bullet speed: `base * heightRatio`
- Enemy bullet speed: `base * heightRatio`
- Alien horizontal movement speed: `base * widthRatio`
- Alien step-down: `base * heightRatio`
- Swoop control point offsets: lateral `* widthRatio`, vertical `* heightRatio`
- UFO speed: `base * widthRatio`
- Powerup fall speed: `base * heightRatio`
- Destroy-below-Y threshold: `-30` (unchanged, still just off-screen)
- UFO Y position: `sceneHeight * 0.858` instead of `sceneHeight - 120`

---

## 7. Difficulty Balancing

**Files: `GameScene.swift`, `Constants.swift`**

More columns on iPad means more aliens firing simultaneously, and landscape compresses the vertical play area. To keep difficulty feeling equivalent across all screen sizes, three levers scale inversely with the alien count / screen ratio:

### Alien Fire Rate
- The base per-alien fire rate is tuned for the iPhone baseline (~5 columns)
- Scale down per-alien fire probability as column count increases: `baseFireRate * (baseColumns / actualColumns)`
- This keeps the overall bullet density (bullets per second on screen) roughly constant regardless of grid size
- Example: 5 cols at 1.0 rate vs 8 cols at 0.625 rate = same total bullets per second

### Swoop Frequency
- More aliens = more potential swoopers. Scale down swoop probability similarly: `baseSwoopRate * (baseColumns / actualColumns)`
- Keeps the number of simultaneous swoops consistent — player faces the same dodge pressure

### Powerup Drop Rate
- More aliens to destroy = more chances to drop powerups, but the player also needs more time to clear waves
- Scale up powerup drop probability slightly on larger grids: `baseDropRate * (actualColumns / baseColumns) * 0.75`
- The 0.75 dampener prevents powerups from feeling too generous — the player gets more drops but not linearly more

### Landscape-Specific
- The compressed vertical space in landscape means less visual reaction time even with consistent travel speeds
- Consider a small additional fire rate reduction (~0.9x multiplier) in landscape to compensate for the tighter vertical window

---

## 8. Particle Effects

**File: `ParticleEffects.swift`**

- Starfield emitter: position and emission range use scene size instead of hardcoded 390x844
- Spark particles: keep current scale (they're small effects, size is fine)
- Thrust particles: unchanged (relative to ship, ship stays same size)

---

## 9. SwiftUI Menus & Screens

All menus use the **centered column, max-width** approach: same vertical stack layout as iPhone, capped at ~500pt wide and horizontally centered on larger screens.

### MenuView
**File: `MenuView.swift`**

- Wrap content in `.frame(maxWidth: 500)` centered in the screen
- Title font: use `hudScale` or size-class to bump from 36 → ~44 on iPad
- Button max width: `min(screenWidth * 0.6, 400)`
- Spacing: increase slightly on iPad

### SettingsView
**File: `SettingsView.swift`**

- `.frame(maxWidth: 500)` centered
- Font sizes: scale slightly for readability

### InstructionsView
**File: `InstructionsView.swift`**

- `.frame(maxWidth: 500)` centered
- Powerup icon sizes: scale slightly
- Font sizes: scale slightly

### GameContainerView
**File: `GameContainerView.swift`**

- Exit button: scale size from 30x30 using `hudScale` (e.g. ~44x44 on iPad)
- Read screen bounds and pass as scene size
- Use `GeometryReader` to capture safe area insets

---

## 10. Safe Area Handling

**Files: `GameContainerView.swift`, `GameScene.swift`**

- Read `safeAreaInsets` via SwiftUI `GeometryReader`
- Pass insets to `GameScene` as a stored property before scene presentation
- HUD elements (score, lives) offset from edges by safe area values
- Particularly important for:
  - iPad models with home indicator (bottom)
  - Camera housing (top on newer iPads)
  - Landscape mode where safe areas shift to sides

---

## 11. Landscape Support

**Included in this pass.** iPad supports both portrait and landscape; iPhone stays portrait-only.

### Orientation Locking
- **Menus**: allow auto-rotation (portrait + landscape)
- **During gameplay**: lock to whatever orientation was active when the game started
- Implementation: use `AppDelegate` or `supportedInterfaceOrientations` override to control per-screen

### Landscape Scene Adjustments
- Scene reads actual screen bounds — in landscape the width > height (e.g. 1024x768)
- Gameplay remains vertical shooter: player at bottom, aliens at top
- The viewport is wider and shorter than portrait:
  - Alien formation: many more columns, same rows — fills the wide screen
  - Vertical distance between player and aliens is compressed
  - Bullet speeds scale with `heightRatio` so travel time stays consistent
  - Player has more horizontal room to dodge
- HUD: score centered at top, lives in top-left — positions use safe area offsets
- Starfield emitter: adapts to scene size automatically (from section 8)
  - Additional ~0.9x fire rate multiplier to compensate for compressed vertical space (from section 7)

### Landscape Menus
- Centered column layout works in both orientations due to max-width constraint
- May need reduced vertical spacing in landscape since height is shorter

---

## Files Changed Summary

| File | Changes |
|------|---------|
| `Constants.swift` | Dynamic scene size from screen bounds, `hudScale`, speed ratios |
| `GameContainerView.swift` | Screen bounds → scene size, safe area pass-through, exit button scaling, orientation control |
| `GameScene.swift` | Relative overlay positioning, speed scaling with ratios, safe area HUD offsets, difficulty balancing (fire rate, swoops, powerups) |
| `AlienFormation.swift` | Bonus columns from width, proportional spacing/margins |
| `ScoreDisplay.swift` | Relative Y positioning, `hudScale` font |
| `LivesDisplay.swift` | Relative positioning, `hudScale` icons/spacing |
| `PlayerEntity.swift` | Proportional start Y (ship size unchanged) |
| `MovementComponent.swift` | Minimal — bounds already relative |
| `ProjectileEntity.swift` | Speed scaling (size unchanged) |
| `EnemyProjectileEntity.swift` | Speed scaling (size unchanged) |
| `PowerupEntity.swift` | Fall speed scaling (size unchanged) |
| `UFOEntity.swift` | Relative Y position, speed scaling (size unchanged) |
| `ParticleEffects.swift` | Dynamic starfield emitter dimensions |
| `ExplosionEffect.swift` | No change (explosions stay same size) |
| `MenuView.swift` | Max-width container, slight font scaling |
| `SettingsView.swift` | Max-width container, slight font scaling |
| `InstructionsView.swift` | Max-width container, slight font scaling |
| `AlienBarrageApp.swift` or Info.plist | iPad landscape orientation support |
