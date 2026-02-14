# iPad Layout Optimization Plan

## Rules for Claude

1. **Keep the Status Summary updated.** After completing work on any phase, update the status table below to reflect the current state before doing anything else.
2. **Stop after each phase.** After finishing a phase, do NOT proceed to the next. Instead, present the user with a list of what to test and what to look for in the simulator. Wait for user confirmation before starting the next phase.

---

## Status Summary

| Phase | Status | Notes |
|-------|--------|-------|
| Phase 1: Dynamic Scene Size | **Complete** | Constants.swift uses computed props from UIScreen.main.bounds; GameContainerView uses GeometryReader + .resizeFill |
| Phase 2: Element Sizing Strategy | **Complete** | `hudScale` added to Constants; applied to score font, lives icons/spacing, overlay labels, continue button |
| Phase 3: Alien Formation Layout | **Complete** | Bonus columns from width, proportional spacing/margins/stepDown, formation Y at 81% |
| Phase 4: HUD Repositioning | **Complete** | All items done during Phase 2 and the layout change (HUD moved to bottom, hudScale applied) |
| Phase 5: Player & Movement Bounds | **Complete** | Player start/respawn Y proportional (0.142), maxY dynamic from formation |
| Phase 6: Gameplay Speed Scaling | **Complete** | heightRatio/widthRatio in Constants; applied to player bullets, enemy bullets, powerup fall, UFO, alien march, swoop path/speed; UFO Y proportional (0.858) |
| Phase 7: Difficulty Balancing | **Complete** | Fire interval and swoop interval scale up by column ratio; powerup drop rate slightly boosted on wider screens (dampened 0.75x) |
| Phase 8: Particle Effects | **Complete** | Starfield birth rate scales with screen area, speed/lifetime scale with height ratio, pre-fill time dynamic; sparks and thrust unchanged (relative to sprites) |
| Phase 9: SwiftUI Menus & Screens | **Complete** | MenuView, SettingsView, InstructionsView capped at 500pt maxWidth; exit button scales with hudScale |
| Phase 10: Safe Area Handling | **Complete** | safeAreaInsets passed from GeometryReader to GameScene; ScoreDisplay and LivesDisplay offset by bottom inset |
| Phase 11: Landscape Support | **Skipped** | App stays portrait-only on all devices |

---

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

## Phase 1: Dynamic Scene Size

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

### After this phase, test:
- iPhone 16 simulator (390x844): game should look identical to current build
- iPad simulator (portrait): scene fills the full screen, no black bars
- iPhone SE simulator: scene fills the screen, no letterboxing
- iPhone Plus simulator: scene fills the screen, wider play area
- Verify the game launches and basic gameplay works on each — elements will be mispositioned but not crashing

---

## Phase 2: Element Sizing Strategy

**Game elements stay at iPhone sizes** — the ship, aliens, bullets, powerups, and UFO keep their current point dimensions (92x71 ship, 56x43 large alien, etc.). On iPad the playing field is physically larger, giving the player more room to maneuver and making the game feel more expansive.

**HUD elements scale up independently** to remain readable on larger screens:
- Introduce a `hudScale` factor: `max(1.0, min(sceneWidth, sceneHeight) / 844.0)` or similar
- Apply to: score font size, lives icon size, overlay text, buttons
- Gameplay sprites are **not** scaled

### After this phase, test:
- iPad: HUD text (score, lives) should be noticeably larger than on iPhone — readable from normal tablet distance
- iPhone 16: HUD should look exactly the same as before (`hudScale` = 1.0)
- iPad: gameplay sprites (ship, aliens, bullets) should be the same pixel size as on iPhone — they look small relative to the screen, and that's intentional

---

## Phase 3: Alien Formation Layout

**File: `AlienFormation.swift`**

iPad gets **more columns at all levels** to fill the wider screen.

- Calculate bonus columns based on available width: e.g. `baseColumns + Int((sceneWidth - 390) / 130)` — roughly +2-3 columns on iPad portrait, +4-5 in landscape
- Row count stays the same (scales with level as before)
- `spacingX` / `spacingY`: recalculate relative to scene dimensions rather than hardcoded 65/55
- `edgeMargin` and `movementBuffer`: proportional to scene width
- Formation start Y: `sceneHeight * 0.81` instead of `sceneHeight - 160`
- Step-down distance: proportional to scene height

### After this phase, test:
- iPad portrait: alien grid should be wider (more columns) and well-centered, not bunched to one side
- iPad: aliens should march side-to-side and reach both edges without going off-screen
- iPhone 16: column count and spacing should be identical to the current build
- Play through 2-3 levels on iPad to verify formation scales with level progression
- Check that aliens don't overlap or clip the HUD at the top

---

## Phase 4: HUD Repositioning

**Layout change:** All HUD elements moved from top of screen to **bottom**, below the player ship. This keeps the player's finger in mid-screen, away from the iOS app switcher edge. The exit button also moved to bottom-trailing.

### Score Display
**File: `ScoreDisplay.swift`**

- X: centered (`sceneWidth / 2`) — no change needed
- Y: `30 * hudScale` (bottom of screen, below player ship)
- Font size: `30 * hudScale`

### Lives Display
**File: `LivesDisplay.swift`**

- Position: `(50, 25 * hudScale)` (bottom-left, below player ship)
- Icon size: `26x20 * hudScale`
- Icon spacing: `30 * hudScale`

### Exit Button
**File: `GameContainerView.swift`**

- Moved from `.topTrailing` to `.bottomTrailing`
- Padding changed from `.top` to `.bottom`

### Player Ship
- Raised from Y=80 to Y=120 to clear the HUD below it

### Game Over / Level Transition Overlays
**File: `GameScene.swift`**

- Positions already use `size.width / 2` and `size.height / 2` — good
- Font sizes: scale with `hudScale`
- Continue button: `200x50 * hudScale`
- Vertical offsets between overlay elements: scale proportionally

### After this phase, test:
- iPad: score should be at the bottom center, below the player ship
- iPad: lives icons should be bottom-left, appropriately sized (not tiny)
- iPad: exit button should be bottom-right
- iPhone 16: HUD at bottom, ship above it, aliens at top
- Player ship should have clear space below it for the HUD, and clear space above for gameplay
- Trigger game over: overlay text and continue button should be centered and appropriately sized on both devices
- Trigger level transition: level text should be centered and readable on both devices
- Drag the ship around — finger should stay in mid-screen, well away from the bottom edge

---

## Phase 5: Player & Movement Bounds

**Files: `PlayerEntity.swift`, `MovementComponent.swift`, `GameScene.swift`**

- Player start Y: proportional instead of hardcoded `120` (raised from original 80 to clear bottom HUD)
- Respawn position: same proportional formula
- Ship size: **unchanged** (stays 92x71)
- Movement clamp: already uses `sceneWidth - spriteHalfWidth` — works automatically
- Thrust particle offset: unchanged (relative to ship size)

### After this phase, test:
- iPad: player ship should sit near the bottom of the screen, proportionally same position as iPhone
- iPad: drag the ship to both edges — it should clamp correctly and not go off-screen
- iPhone 16: ship position and movement should be identical to current build
- Die and respawn: ship should reappear at the correct proportional position on both devices

---

## Phase 6: Gameplay Speed Scaling

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

### After this phase, test:
- iPad: fire a bullet — it should take roughly the same time to cross the screen as on iPhone
- iPad: watch alien march speed — should feel the same pace as iPhone, just covering more ground
- iPad: wait for enemy bullets — travel time should feel consistent with iPhone
- iPhone 16: all speeds should be identical to current build (ratios = 1.0)
- Watch for a UFO — should appear near the top of the screen and cross at a reasonable pace on both devices
- Pick up a powerup — it should fall at a consistent-feeling speed on both devices

---

## Phase 7: Difficulty Balancing

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

### After this phase, test:
- iPad portrait: play a full wave — bullet density should feel similar to iPhone, not overwhelming
- iPad: count swooping aliens over a wave — should be roughly the same number as on iPhone
- iPad: observe powerup drops — should feel slightly more frequent than iPhone (more aliens to kill) but not raining powerups
- iPhone 16: difficulty should be identical to current build (all scaling factors = 1.0)
- Side-by-side comparison if possible: play the same level on iPhone and iPad — the pressure/challenge should feel comparable

---

## Phase 8: Particle Effects

**File: `ParticleEffects.swift`**

- Starfield emitter: position and emission range use scene size instead of hardcoded 390x844
- Spark particles: keep current scale (they're small effects, size is fine)
- Thrust particles: unchanged (relative to ship, ship stays same size)

### After this phase, test:
- iPad: starfield should fill the entire screen with no gaps or visible edges
- iPad: stars should not be bunched in a 390-wide strip in the center
- iPhone 16: starfield should look identical to current build
- Destroy an alien on iPad: spark effects should appear at the correct position and look normal
- Check ship thrust particles on iPad: should still trail from the bottom of the ship correctly

---

## Phase 9: SwiftUI Menus & Screens

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

### After this phase, test:
- iPad: main menu should be centered, not stretched edge-to-edge — title and buttons capped at ~500pt wide
- iPad: title text should be larger than on iPhone
- iPad: buttons should be comfortably sized, easy to tap
- iPad: settings screen — controls centered, readable, not tiny
- iPad: instructions screen — text readable, powerup icons appropriately sized
- iPad: exit button during gameplay — large enough to tap easily
- iPhone 16: all menus should look identical to current build
- Navigate through all screens on iPad to check nothing is cut off or overlapping

---

## Phase 10: Safe Area Handling

**Files: `GameContainerView.swift`, `GameScene.swift`**

- Read `safeAreaInsets` via SwiftUI `GeometryReader`
- Pass insets to `GameScene` as a stored property before scene presentation
- HUD elements (score, lives) offset from edges by safe area values
- Particularly important for:
  - iPad models with home indicator (bottom)
  - Camera housing (top on newer iPads)
  - Landscape mode where safe areas shift to sides

### After this phase, test:
- iPad with home indicator: HUD elements should not overlap the home indicator bar
- iPad: score and lives should have proper margins from screen edges, respecting safe areas
- iPhone 16 (with notch/dynamic island): HUD should not be hidden behind the status bar area
- iPhone SE: verify safe area insets are minimal and HUD positions are correct
- If landscape is partially working at this point: check that safe areas shift to the sides correctly

---

## Phase 11: Landscape Support

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
- Starfield emitter: adapts to scene size automatically (from Phase 8)
  - Additional ~0.9x fire rate multiplier to compensate for compressed vertical space (from Phase 7)

### Landscape Menus
- Centered column layout works in both orientations due to max-width constraint
- May need reduced vertical spacing in landscape since height is shorter

### After this phase, test:
- iPad: rotate to landscape on the main menu — layout should adapt, content centered
- iPad: start a game in landscape — aliens should form a very wide grid with more columns
- iPad landscape: player movement, bullet speeds, and general feel should be comparable to portrait
- iPad landscape: HUD should respect landscape safe areas (notch/camera on side)
- iPad: rotate device during a game — orientation should stay locked
- iPad: return to menu after a game — orientation should unlock and respond to rotation
- iPhone: should remain portrait-only at all times, rotation has no effect
- Play a full game in landscape on iPad to verify end-to-end: menu → gameplay → game over → menu

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
