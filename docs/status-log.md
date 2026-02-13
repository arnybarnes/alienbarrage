# Alien Barrage — Status Log

## Phase 0: Project Setup & Spritesheet Integration
**Status:** Complete
**Date:** 2026-02-12

**What was done:**
- Copied `spritesheet.png` (1536×1024) into the Xcode project
- Created `SpriteSheet.swift` — singleton that loads the sheet and vends named `SKTexture` objects via `SKTexture(rect:in:)` with pixel-to-normalized coordinate mapping
- Created `Constants.swift` — physics categories, z-positions, scene dimensions, gameplay constants
- Stripped boilerplate from `GameScene.swift` — black background, displays one test sprite centered
- Modified `GameViewController.swift` — creates scene programmatically at 390×844 (portrait), `.aspectFill` scale mode
- Created `docs/status-log.md` (this file)
- Created `docs/apple-intelligence-ideas.md`

**Test criteria:** App launches portrait, black screen, one sprite from the sheet displayed centered, FPS overlay visible.

---

## Phase 1: Player Ship & Shooting
**Status:** Complete
**Date:** 2026-02-12

**What was done:**
- Created `PlayerEntity.swift` with `SpriteComponent`, `MovementComponent`, `ShootingComponent`
- Created `ProjectileEntity.swift` — player bullets fire upward and despawn off-screen
- Created `EntityNode.swift` — `SKSpriteNode` subclass with weak entity reference for physics lookups
- Implemented touch-drag controls: relative horizontal movement, auto-fire while touching
- Player ship clamped to screen bounds
- Updated spritesheet with new 1024×1024 version and remapped all coordinates
- Later replaced again with 2048×2048 transparent 4-quadrant version

**Test criteria:** Ship at bottom, drag to move, bullets fire while touching, bullets despawn off top.

---

## Phase 2: Alien Grid Formation & Movement
**Status:** Complete
**Date:** 2026-02-12

**What was done:**
- Created `AlienEntity.swift` — large and small alien types with grid position tracking
- Created `AlienFormation.swift` — manages 4×5 grid, march side-to-side, step down at edges
- Formation speeds up as aliens are destroyed
- Two alien sizes: large (top rows) and small (bottom rows)

**Test criteria:** 20 aliens in 5×4 grid march and step down. Bullets pass through (no collision yet).

---

## Phase 3: Collisions, Explosions, & Scoring
**Status:** Complete
**Date:** 2026-02-12

**What was done:**
- Created `HealthComponent.swift` — large aliens 2 HP, small aliens 1 HP
- Created `ScoreValueComponent.swift` — large aliens 200 pts, small aliens 100 pts
- Created `ScoreDisplay.swift` — renders score with spritesheet digit textures
- Created `ScoreManager.swift` — tracks current and high score
- Created `ExplosionEffect.swift` — green explosion animation with score popup
- Implemented `SKPhysicsContactDelegate` for bullet-alien collisions
- Fixed explosion texture rects and score popup rendering

**Test criteria:** Shooting aliens triggers explosions and score popups. Large aliens take 2 hits with flash on first. Score updates at top of screen.

---

## Phase 4: Enemy Shooting, Lives, & Game Over
**Status:** Complete
**Date:** 2026-02-12

**What was done:**
- Created `EnemyProjectileEntity.swift` — enemy bullets fire downward from lowest alien per column
- Created `LivesDisplay.swift` — small ship icons at top-left showing remaining lives
- Created `GameState.swift` — enum for `.playing`, `.playerDeath`, `.gameOver`, `.levelComplete`
- Implemented player death sequence with respawn invulnerability (blinking)
- Game over screen with "GAME OVER" text and tap-to-restart
- Replaced sprite-based overlay text with styled `SKLabelNode` fonts
- Fixed overlay rendering and enemy bullet aspect ratio

**Test criteria:** Aliens shoot back, player loses lives on hit, respawns with invulnerability. Game over at 0 lives with restart.

---

## Phase 5: Level Progression, UFO, & Difficulty Scaling
**Status:** Complete
**Date:** 2026-02-12

**What was done:**
- Created `LevelManager.swift` — generates `LevelConfig` with scaling rows, cols, speed, fire interval per level
- Created `UFOEntity.swift` — bonus enemy flies across top of screen, 3 HP, 500 points
- Created `LevelTransition.swift` — "LEVEL START" display between waves
- Clearing all aliens advances to next level with harder configuration
- UFO spawns on a random timer during gameplay
- Sprite coordinate fixes by Codex

**Test criteria:** Clearing aliens shows level transition, next wave is harder. UFO flies across top periodically, takes 3 hits for 500 pts.

---

## Phase 6: Powerups, Shields, & Visual Polish
**Status:** Complete
**Date:** 2026-02-12

**What was done:**
- Created `PowerupEntity.swift` — 4 powerup types (rapid fire, spread shot, shield, extra life) with drop animations
- Created `ShieldBarrierEntity.swift` — destructible barriers with visual degradation
- Created `ParticleEffects.swift` — starfield background, engine thrust, spark bursts
- Created `ScreenShakeEffect.swift` — camera shake on player death
- Integrated powerup collection, shield barriers, and visual effects into GameScene
- Powerups drop from destroyed aliens at 15% chance

**Test criteria:** Starfield background, shield barriers take damage, powerups drop and can be collected, screen shake on death, particle effects on impacts.

---

## Phase 7: SwiftUI Menus, Settings, Audio, High Scores, & Final Polish
**Status:** Complete
**Date:** 2026-02-13

**What was done:**
- Replaced UIKit entry point (AppDelegate + Main.storyboard + GameViewController) with SwiftUI @main App
- Created `GameSettings.swift` — ObservableObject with UserDefaults persistence for difficulty, autofire, autofire speed
- Created `HighScoreManager.swift` — singleton, UserDefaults-backed top 10 scores
- Created `HapticManager.swift` — singleton wrapping UIFeedbackGenerators (light/medium/heavy/success/error)
- Created `AudioManager.swift` — singleton with no-op play() (all sound filenames empty for now)
- Created `Views/AlienBarrageApp.swift` — @main SwiftUI App struct
- Created `Views/ContentView.swift` — state-driven navigation (menu/playing/settings/instructions)
- Created `Views/MenuView.swift` — title screen with pulsing title, high score, start/settings/instructions buttons
- Created `Views/SettingsView.swift` — difficulty picker, autofire toggle, autofire speed slider
- Created `Views/InstructionsView.swift` — how-to-play with controls, scoring, powerup descriptions
- Created `Views/GameContainerView.swift` — wraps SpriteView, creates GameScene with settings
- Modified `PlayerEntity.swift` — configurable lives and fire rate parameters
- Modified `GameScene.swift` — settings integration, onGameOver callback, autofire logic, difficulty scaling, audio/haptic hooks, enhanced game over overlay with score/high score, pause on background
- Deleted AppDelegate.swift, Main.storyboard, GameViewController.swift
- Removed INFOPLIST_KEY_UIMainStoryboardFile from project.pbxproj

**Test criteria:** Full SwiftUI flow (Menu → Game → Game Over → Menu). Settings persist. High scores persist. Autofire works. Difficulty affects gameplay. Haptics fire on events. Game pauses on background.
