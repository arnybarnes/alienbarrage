# Alien Barrage — Detailed Build Plan

## Overview

**Game:** Space Invaders-style iOS game with cybernetic alien theme
**Bundle ID:** `com.biffna.retrostyle1`
**Target:** iOS 17.6+, portrait only, iPhone primary
**Tech Stack:** SpriteKit + GameplayKit, Swift
**Scene Size:** 390×844 points (portrait), `.aspectFill` scale mode
**Spritesheet:** Single 1536×1024 PNG, all game art extracted via `SKTexture(rect:in:)`

### Project Structure

All game source files live in `Alien Barrage/Alien Barrage/`. The Xcode project uses `PBXFileSystemSynchronizedRootGroup` — new files placed in this directory are auto-discovered without pbxproj edits. Subdirectories (like `Entities/`, `Components/`, `Effects/`) are created inside this folder.

### Key Architecture Decisions

- **ECS Pattern:** GKEntity + GKComponent for game objects. GameScene maintains an `entities` array and calls `entity.update(deltaTime:)` each frame.
- **Singleton SpriteSheet:** `SpriteSheet.shared` vends named `SKTexture` objects. Pixel rects defined in a dictionary, converted to normalized coords at runtime.
- **Constants:** All tuning values in `GameConstants` enum (Constants.swift). Sound filenames in `GameConstants.Sound` — empty string means disabled.
- **Physics:** `physicsWorld.gravity = .zero`, all bodies `affectedByGravity = false`. Contact detection via category bitmasks defined in `GameConstants.PhysicsCategory`.

### Sprite Names Available in SpriteSheet.swift

```
Aliens:    alienLarge1-6, alienMedium1-6, alienSmall1-4
Ships:     playerShip, ship1-4
UFO:       ufo
Bullets:   playerBullet, playerMissile, enemyBullet
Explosions: explosionGreen1-6, explosionOrange1-2
Text:      levelStart, gameOver, plus100
Digits:    digit0-9
Shields:   shield1-2
Powerups:  powerupGreen, powerupShield
```

**Note:** Sprite coordinates are estimates from visual inspection of the spritesheet. They may need adjustment during testing. All rects are in the `spriteRects` dictionary in SpriteSheet.swift — easy to tweak.

---

## Phase 0: Project Setup & Spritesheet Integration ✅

**Status:** COMPLETE

**What was done:**
- Copied `spritesheet.png` into project directory
- Created `SpriteSheet.swift` — singleton, loads sheet, caches textures, pixel→normalized conversion
- Created `Constants.swift` — physics categories, z-positions, scene size, gameplay tuning values, sound filename placeholders
- Stripped `GameScene.swift` boilerplate — black bg, displays `alienLarge1` centered at 2× scale
- Rewrote `GameViewController.swift` — programmatic scene creation at 390×844, portrait-only
- Created `docs/status-log.md`, `docs/apple-intelligence-ideas.md`, `docs/build-plan.md`

**Test:** App launches portrait, black screen, one alien sprite centered, FPS overlay visible.

---

## Phase 1: Player Ship & Shooting ✅

**Status:** COMPLETE

**Goal:** Player ship at bottom, touch-drag to move horizontally, auto-fire projectiles upward while touching.

### Files to Create

All paths relative to `Alien Barrage/Alien Barrage/`.

**`Entities/PlayerEntity.swift`**
- Subclass `GKEntity`
- On init: create `SKSpriteNode` using `SpriteSheet.shared.sprite(named: "playerShip")`, scaled to ~60×80 points
- Add components: `SpriteComponent`, `MovementComponent`, `ShootingComponent`
- Store reference to the sprite node for easy access
- Position at `(sceneWidth/2, 80)` — bottom center with some margin

**`Entities/ProjectileEntity.swift`**
- Subclass `GKEntity`
- On init: create `SKSpriteNode` using `SpriteSheet.shared.sprite(named: "playerBullet")`, scaled to ~10×24 points
- Add `SKPhysicsBody(rectangleOf:)` with category `playerBullet`, contactTest against `enemy | ufo | shield`
- Apply `SKAction.moveBy(x: 0, y: sceneHeight, duration: sceneHeight/bulletSpeed)` then remove
- Physics body: `isDynamic = true`, `affectedByGravity = false`, `collisionBitMask = 0` (no physics collision, just contact detection)

**`Components/SpriteComponent.swift`**
- Subclass `GKComponent`
- Holds reference to an `SKSpriteNode`
- Provides convenience access to position, texture, etc.

**`Components/MovementComponent.swift`**
- Subclass `GKComponent`
- Properties: `speed: CGFloat`, `minX: CGFloat`, `maxX: CGFloat`
- Method: `move(toX targetX: CGFloat)` — updates sprite position, clamped to min/max bounds
- The clamping keeps the ship from going off-screen (half-width margin on each side)

**`Components/ShootingComponent.swift`**
- Subclass `GKComponent`
- Properties: `fireRate: TimeInterval`, `timeSinceLastShot: TimeInterval`, `isFiring: Bool`
- On `update(deltaTime:)`: if `isFiring` and cooldown elapsed, call a `fireCallback` closure
- The callback is set by GameScene to spawn a `ProjectileEntity` at the ship's position + offset above

### Files to Modify

**`GameScene.swift`**
- Add `playerEntity: PlayerEntity` property
- In `didMove(to:)`: remove Phase 0 test sprite, create `PlayerEntity`, add its sprite to scene, add entity to `entities` array
- Set `physicsWorld.gravity = .zero`
- Touch handling:
  - `touchesBegan`: record touch start position and player start position, set `isFiring = true`
  - `touchesMoved`: calculate delta from touch start, apply to player start position (relative drag), call `movementComponent.move(toX:)`
  - `touchesEnded`/`touchesCancelled`: set `isFiring = false`
- `ShootingComponent.fireCallback`: spawn `ProjectileEntity` at `(playerX, playerY + 50)`, add sprite to scene, add entity to `entities` array
- In `update()`: remove entities whose sprites have been removed from parent (cleanup)

**`Constants.swift`**
- Values already defined: `playerSpeed` (300), `playerFireRate` (0.25s), `playerBulletSpeed` (600)
- May need to add `playerShipScale` and `bulletScale` if not hardcoded

### Test Criteria
- Ship visible at bottom center
- Drag left/right moves ship horizontally (relative, not jump-to-touch)
- Ship stays within screen bounds
- While touching, green bullets fire upward continuously at ~4/sec
- Bullets disappear off the top of the screen
- Releasing touch stops firing

---

## Phase 2: Alien Grid Formation & Movement ✅

**Status:** COMPLETE

**Goal:** Classic alien grid marches side-to-side, steps down at edges. No collisions yet.

### Files to Create

**`Entities/AlienEntity.swift`**
- Subclass `GKEntity`
- Init params: `type: AlienType` (enum: `.small`, `.large`), `gridPosition: (row: Int, col: Int)`
- Sprite: `.large` uses `alienLarge1`/`alienLarge2` (alternate by row), `.small` uses `alienSmall1`/`alienSmall2`
- Scale sprites to ~40×40 (small) or ~45×50 (large) points — tune to fit 5-column grid
- Store `gridPosition` for formation tracking
- `isAlive: Bool` flag

**`AlienFormation.swift`**
- Class (not entity) — manages the 2D grid of `AlienEntity` objects
- Properties:
  - `aliens: [[AlienEntity?]]` — 2D array [row][col], nil = destroyed
  - `direction: CGFloat` — +1.0 (right) or -1.0 (left)
  - `speed: CGFloat` — current horizontal speed
  - `baseSpeed: CGFloat` — starting speed from config
  - `totalAliens: Int` — starting count
  - `aliveCount: Int` — computed from grid
  - `formationNode: SKNode` — parent node, all alien sprites are children
- Init: takes grid dimensions (rows, cols), creates `AlienEntity` objects in grid pattern
  - Top 2 rows = `.large` aliens (higher score, 2 HP later)
  - Bottom 2 rows = `.small` aliens (lower score, 1 HP later)
  - Spacing from `GameConstants.alienSpacingX/Y`
  - Center the grid horizontally in the scene
  - Start position: top area of scene, with margin from top
- `update(deltaTime:)`:
  - Move `formationNode` horizontally by `speed * direction * dt`
  - Check if any alive alien has reached left/right screen edge
  - If edge hit: reverse `direction`, move `formationNode` down by `alienStepDown`
  - Edge check uses the actual positions of the leftmost/rightmost alive aliens
- `removeAlien(row:col:)`: set grid slot to nil, recalculate speed
- Speed scaling: `speed = baseSpeed * (1.0 + (totalAliens - aliveCount) * speedMultiplierPerKill)`
  - As aliens die, formation speeds up
- `allDestroyed: Bool` — true when `aliveCount == 0`

### Files to Modify

**`GameScene.swift`**
- Add `alienFormation: AlienFormation?` property
- In `didMove(to:)`: create `AlienFormation(rows: 4, cols: 5)`, add `formationNode` to scene
- In `update()`: call `alienFormation?.update(deltaTime: dt)`
- Player bullets will visually pass through aliens (no physics yet)

**`Constants.swift`**
- Values already defined: `alienGridColumns` (5), `alienGridRows` (4), `alienSpacingX` (65), `alienSpacingY` (55), `alienBaseSpeed` (40), `alienStepDown` (20), `alienSpeedMultiplierPerKill` (0.04)

### Test Criteria
- 20 aliens in a 5×4 grid, top rows larger than bottom rows
- Formation marches right → hits edge → steps down → marches left → repeat
- Formation visually speeds up (not yet via kills, just verify movement looks right)
- Player can shoot but bullets pass through aliens (no collision)
- Player movement still works correctly

---

## Phase 3: Collisions, Explosions, & Scoring ✅

**Status:** COMPLETE

**Goal:** Bullets destroy aliens with explosions, score rendered with spritesheet digit sprites.

### Files to Create

**`Components/HealthComponent.swift`**
- Subclass `GKComponent`
- Properties: `maxHP: Int`, `currentHP: Int`
- Method: `takeDamage(_ amount: Int) -> Bool` — returns true if dead (HP <= 0)
- Large aliens: 2 HP. Small aliens: 1 HP.

**`Components/ScoreValueComponent.swift`**
- Subclass `GKComponent`
- Property: `value: Int`
- Large aliens: 200 points. Small aliens: 100 points.

**`ScoreDisplay.swift`**
- Class that renders the current score at the top of the screen using digit textures from the spritesheet
- Properties: `digitNodes: [SKSpriteNode]`, `parentNode: SKNode`
- Method: `update(score: Int)` — converts score to digits, shows/hides digit nodes, updates textures
- Pre-create enough digit nodes for max displayable score (e.g., 8 digits)
- Position at top-center of scene, below any safe-area margin
- Each digit sprite scaled to ~20×25 points, spaced ~22 points apart

**`ScoreManager.swift`**
- Singleton or simple class
- Properties: `currentScore: Int`, `highScore: Int`
- Methods: `addPoints(_ points: Int)`, `reset()`
- Notifies `ScoreDisplay` on change (via closure or direct reference)

**`Effects/ExplosionEffect.swift`**
- Static method: `spawn(at position: CGPoint, in scene: SKScene)`
- Creates `SKSpriteNode` using `explosionGreen1` texture
- Runs animation: scale up slightly + fade out over ~0.4 seconds, then remove
- Optionally cycle through `explosionGreen1`→`explosionGreen2`→`explosionGreen3` as frame animation
- Also spawns a "+100" (or "+200") popup:
  - `SKSpriteNode` with `plus100` texture (or build from digit textures for variable amounts)
  - Float up ~60 points over 0.8 seconds while fading out, then remove
- Z-position: `GameConstants.ZPosition.explosion`

### Files to Modify

**`GameScene.swift`**
- Adopt `SKPhysicsContactDelegate`, set `physicsWorld.contactDelegate = self`
- `didBegin(_ contact:)`: identify contact between `playerBullet` and `enemy`
  - Get the alien entity from the physics body's node (store entity ref on node via `userData` or a custom property)
  - Call `healthComponent.takeDamage(1)`
  - If alive (large alien, first hit): flash the sprite white briefly (SKAction colorize)
  - If dead: call `alienFormation.removeAlien(row:col:)`, spawn explosion effect, add score, remove sprite
  - Remove the bullet sprite and entity
- Add `scoreManager` and `scoreDisplay` properties
- In `didMove(to:)`: set up `scoreDisplay` at top of screen, initialize `scoreManager`
- Wire up scoring in collision handler

**`AlienFormation.swift`**
- `removeAlien(row:col:)` implementation: set grid slot to nil, remove sprite from parent, recalculate `aliveCount` and `speed`

**`AlienEntity.swift`**
- Add `SKPhysicsBody` to sprite: `categoryBitMask = enemy`, `contactTestBitMask = playerBullet`, `collisionBitMask = 0`
- `isDynamic = false` (moved by formation, not physics)
- `affectedByGravity = false`
- Add `HealthComponent` and `ScoreValueComponent`
- Store row/col as properties for lookup

**`ProjectileEntity.swift`**
- Add `SKPhysicsBody`: `categoryBitMask = playerBullet`, `contactTestBitMask = enemy | ufo`, `collisionBitMask = 0`
- Store reference to entity on the sprite node (for contact handler lookup)

### Linking Entities to Sprite Nodes

For the `didBegin(_ contact:)` handler, we need to go from `SKPhysicsBody` → `SKNode` → `GKEntity`. Approach:
- Add a `.userData` dictionary to each sprite node: `node.userData = ["entity": alienEntity]`
- Or add a stored property via a lightweight wrapper: subclass `SKSpriteNode` as `EntityNode` with an `entity: GKEntity?` property
- The `EntityNode` approach is cleaner — create once, use everywhere

### Test Criteria
- Shooting aliens causes green explosion animation
- "+100" or "+200" popup floats up from explosion point
- Score at top of screen updates with neon digit sprites
- Large aliens (top 2 rows) take 2 hits — first hit causes a white flash, second hit destroys
- Small aliens (bottom 2 rows) die in 1 hit
- Formation speeds up as aliens are destroyed
- All prior functionality still works

---

## Phase 4: Enemy Shooting, Lives, & Game Over ✅

**Status:** COMPLETE

**Goal:** Aliens shoot back, player has 3 lives, death sequence, game over state.

### Files to Create

**`Components/EnemyShootingComponent.swift`**
- Not a per-entity component — logic lives in `AlienFormation` or `GameScene`
- Timer-based: every `enemyFireInterval` seconds, pick a random column that has alive aliens
- Find the lowest alive alien in that column — only it fires
- Spawn `EnemyProjectileEntity` at that alien's position

**`Entities/EnemyProjectileEntity.swift`**
- Similar to `ProjectileEntity` but moves downward
- Sprite: `SpriteSheet.shared.sprite(named: "enemyBullet")`, possibly tinted or rotated 180°
- Physics: `categoryBitMask = enemyBullet`, `contactTestBitMask = player | shield`, `collisionBitMask = 0`
- Movement: `SKAction.moveBy(x: 0, y: -sceneHeight, duration: sceneHeight/enemyBulletSpeed)` then remove

**`LivesDisplay.swift`**
- Renders remaining lives as small ship icons at top-left of screen
- Uses a scaled-down version of the player ship sprite (or `ship1` sprite)
- Update method: show/hide icons based on lives remaining
- Position: top-left, row of small sprites ~20×20 each

**`GameState.swift`**
- Enum: `.playing`, `.playerDeath`, `.gameOver`, `.levelComplete`
- Used by `GameScene` to control game flow
- During `.playerDeath`: input disabled, death animation plays, then transition back to `.playing` (or `.gameOver` if no lives)
- During `.gameOver`: show "GAME OVER" graphic, show final score, tap to restart

### Files to Modify

**`GameScene.swift`**
- Add `gameState: GameState` property, start as `.playing`
- Add `livesRemaining: Int` (init to `GameConstants.playerLives`)
- Add `livesDisplay: LivesDisplay`
- Enemy shooting timer: use `SKAction.repeatForever(SKAction.sequence([wait, run block]))` or manual timer in `update()`
  - Every `enemyFireInterval`: pick random column, find lowest alien, spawn `EnemyProjectileEntity`
- Collision: `enemyBullet` → `player`:
  - Set `gameState = .playerDeath`
  - Spawn explosion at player position
  - Decrement `livesRemaining`, update `LivesDisplay`
  - If lives > 0: after 1.5s delay, respawn player with 2s invulnerability (blink effect via `SKAction.repeatForever(fadeIn/fadeOut)`)
  - If lives == 0: set `gameState = .gameOver`, show "GAME OVER" sprite + final score, wait for tap
- Invulnerability: during blink, set player physics `contactTestBitMask = 0` (immune to enemy bullets), restore after duration
- "GAME OVER" display: `SKSpriteNode` with `SpriteSheet.shared.sprite(named: "gameOver")`, centered on screen, with score below it
- Tap to restart during `.gameOver`: create fresh `GameScene`, present it
- Aliens reaching player Y-position check: in `update()`, if any alive alien's world position Y <= player Y → instant game over
- Guard all touch handling and shooting logic with `gameState == .playing`

**`AlienFormation.swift`**
- Add method: `lowestAlien(inColumn col: Int) -> AlienEntity?` — returns the lowest row alive alien in that column
- Add method: `lowestAlienY() -> CGFloat` — returns the Y position of the lowest alive alien (for bottom-reached check)
- Add method: `randomFiringAlien() -> AlienEntity?` — picks a random column and returns its lowest alien

### Test Criteria
- Aliens fire green/red bullets downward at random intervals
- Only the lowest alien per column fires
- Getting hit: explosion on player, life lost, lives display updates
- After death: player respawns blinking (invulnerable) for 2 seconds
- 0 lives: "GAME OVER" graphic appears with final score
- Tap during game over restarts the game
- Aliens reaching the bottom = instant game over
- All prior functionality still works

---

## Phase 5: Level Progression, UFO, & Difficulty Scaling

**Goal:** Clearing all aliens advances level. UFO bonus. Escalating difficulty.

### Files to Create

**`LevelManager.swift`**
- Struct `LevelConfig`: `level: Int`, `rows: Int`, `cols: Int`, `baseSpeed: CGFloat`, `fireInterval: TimeInterval`, `alienHPBonus: Int`
- Static method: `config(forLevel level: Int) -> LevelConfig`
- Scaling formulas:
  - Level 1: 4 rows × 5 cols, speed 40, fireInterval 2.0, alienHPBonus 0
  - Level 2: 4 rows × 6 cols, speed 48, fireInterval 1.8, alienHPBonus 0
  - Level 3+: rows min(6, 4 + level/3), cols min(8, 5 + level/2), speed 40 + level*8, fireInterval max(0.6, 2.0 - level*0.15), alienHPBonus level/4
  - Cap values at reasonable maximums so the game stays playable

**`Entities/UFOEntity.swift`**
- Subclass `GKEntity`
- Sprite: `SpriteSheet.shared.sprite(named: "ufo")`, scaled to ~80×45 points
- Flies horizontally across the top of the screen (Y near top - 50)
- Enters from left or right (random), exits the opposite side
- Movement: `SKAction.moveTo(x:, duration:)` based on `ufoSpeed`
- Physics: `categoryBitMask = ufo`, `contactTestBitMask = playerBullet`, `collisionBitMask = 0`
- HP: 3 (from `GameConstants.ufoHP`)
- Score: 500 points
- On destroy: large explosion effect
- If it exits the screen without being destroyed, remove it

**`LevelTransition.swift`**
- Static method: `show(level: Int, in scene: SKScene, completion: @escaping () -> Void)`
- Displays "LEVEL START" sprite (`SpriteSheet.shared.sprite(named: "levelStart")`) centered
- Below it, show the level number using digit textures
- Sequence: fade in over 0.3s → hold 1.5s → fade out 0.3s → call completion
- During transition, game state is paused (no input, no alien movement)

### Files to Modify

**`GameScene.swift`**
- Add `currentLevel: Int` property (start at 1)
- Add `ufoEntity: UFOEntity?` property
- In `update()`: check `alienFormation?.allDestroyed` — if true:
  - Set `gameState = .levelComplete`
  - Increment `currentLevel`
  - Show `LevelTransition`, on completion: spawn new formation with `LevelManager.config(forLevel:)`, set `gameState = .playing`
- UFO spawn timer: schedule between `ufoSpawnIntervalMin` and `ufoSpawnIntervalMax`
  - Only spawn if no UFO currently active and `gameState == .playing`
  - Create `UFOEntity`, add to scene
- UFO collision handling in `didBegin`: `playerBullet` → `ufo`, apply damage, destroy if HP depleted
- On game restart: reset `currentLevel` to 1

**`AlienFormation.swift`**
- Accept `LevelConfig` in initializer (or a method to reconfigure)
- Use config's rows, cols, baseSpeed, fireInterval
- `alienHPBonus` added to each alien's base HP

### Test Criteria
- Destroying all aliens shows "LEVEL START" + level number
- New wave spawns with more aliens / faster speed / faster shooting
- UFO flies across the top every 20-40 seconds
- UFO takes 3 hits to destroy, awards 500 points
- UFO that isn't destroyed flies off-screen and despawns
- Difficulty noticeably increases each level
- Score, lives, and state carry over between levels
- All prior functionality still works

---

## Phase 6: Powerups, Shields, & Visual Polish

**Goal:** Powerup drops, destructible shield barriers, starfield background, particle effects, screen shake.

### Files to Create

**`Entities/PowerupEntity.swift`**
- Subclass `GKEntity`
- Enum `PowerupType`: `.rapidFire`, `.spreadShot`, `.shield`, `.extraLife`
- Sprite: use `powerupGreen` or `powerupShield` texture depending on type (or tint to differentiate)
- Falls downward at `powerupFallSpeed`
- Physics: `categoryBitMask = powerup`, `contactTestBitMask = player`, `collisionBitMask = 0`
- Remove if falls off bottom of screen

**`Components/PowerupEffectComponent.swift`**
- Tracks active powerup on the player
- Properties: `activeType: PowerupType?`, `remainingDuration: TimeInterval`
- `update(deltaTime:)`: count down duration, expire when done
- Effects:
  - `.rapidFire`: halve `ShootingComponent.fireRate` for duration
  - `.spreadShot`: fire 3 bullets (left-angled, straight, right-angled) for duration
  - `.shield`: add a shield sprite around player, absorbs 1 hit
  - `.extraLife`: instant, adds 1 life (no duration)

**`Entities/ShieldBarrierEntity.swift`**
- Subclass `GKEntity`
- Destructible barriers positioned between player and aliens
- Sprite: `shield1` or `shield2` texture, scaled to ~50×40 points
- HP: 5 (from `GameConstants.shieldHP`)
- Physics: `categoryBitMask = shield`, `contactTestBitMask = playerBullet | enemyBullet | enemy`
- Takes damage from both player and enemy bullets (1 damage each)
- Visual degradation: change alpha or tint as HP decreases
- Place 3-4 barriers evenly spaced across the screen, at Y ~200

**`Effects/ParticleEffects.swift`**
- Static methods to create various particle effects:
- `starfield() -> SKEmitterNode`: scrolling star background, moving downward slowly
  - White/blue tiny particles, long lifetime, spawning across full width
  - Z-position: `GameConstants.ZPosition.stars`
- `engineThrust(for node: SKSpriteNode) -> SKEmitterNode`: small flame/glow behind player ship
- `sparkBurst(at position: CGPoint, in scene: SKScene)`: brief spark particle burst on bullet impacts

**`Effects/ScreenShake.swift`**
- Static method: `shake(camera: SKCameraNode, intensity: CGFloat, duration: TimeInterval)`
- Rapidly offset camera position randomly within intensity range
- Use `SKAction` sequence of random moves + return to center
- Call on player death for dramatic effect

### Files to Modify

**`GameScene.swift`**
- Add `SKCameraNode`: create camera, assign to scene's `camera` property
  - Camera starts at scene center `(sceneWidth/2, sceneHeight/2)`
  - All UI elements (score, lives) are children of the camera node so they don't shake
- In `didMove(to:)`: add starfield emitter as background child
- Shield barriers: create 3-4 `ShieldBarrierEntity` objects, position evenly
- Powerup collisions in `didBegin`: `player` → `powerup`, apply effect
- Collision: bullets hitting shields — damage shield, remove bullet
- On player death: call `ScreenShake.shake()`
- Add engine thrust particle to player ship

**`AlienFormation.swift`**
- On alien death: roll `powerupDropChance` (15%), if hit spawn `PowerupEntity` at alien's death position

**`PlayerEntity.swift`**
- Add `PowerupEffectComponent`
- Add method to apply powerup effects (modify fire rate, fire pattern)
- Method to clear active powerup on expiry

### Test Criteria
- Starfield scrolls slowly in background
- 3-4 shield barriers visible between player and aliens
- Shields take damage from both player and enemy bullets, visually degrade, then break
- ~15% of alien kills drop a powerup
- Powerups fall down and can be collected by the player
- Rapid fire increases fire rate
- Spread shot fires 3 bullets in a fan pattern
- Shield powerup adds protective aura (absorbs 1 hit)
- Extra life adds a life icon
- Screen shakes on player death
- Particle sparks on impacts
- Engine glow on player ship
- All prior functionality still works

---

## Phase 7: SwiftUI Menus, Settings, Audio, High Scores, & Final Polish

**Goal:** SwiftUI app shell with menu and settings screens, sound effects, persistent high scores, haptic feedback. Full game loop. Settings for difficulty, autofire, and autofire speed.

### Architecture: SwiftUI + SpriteKit Integration

Replace the UIKit App Delegate + Storyboard entry point with a SwiftUI `@main App`. The game is embedded via `SpriteView`. Navigation between menu, settings, and game is handled by SwiftUI.

**Flow:** App Launch → MenuView (SwiftUI) → [Settings | Instructions (SwiftUI)] → Game (SpriteView) → Game Over → MenuView

### Files to Create

**`Views/AlienBarrageApp.swift`**
- `@main` struct conforming to `App`
- Creates `GameSettings` as `@StateObject`
- Body: `ContentView().environmentObject(gameSettings)`
- Replaces `@main` on `AppDelegate.swift`

**`Views/ContentView.swift`**
- Manages app navigation state: `.menu`, `.playing`, `.settings`, `.instructions`
- Switches between `MenuView`, `SettingsView`, `InstructionsView`, and `GameContainerView`
- Passes `GameSettings` down via environment

**`Views/MenuView.swift`**
- SwiftUI menu screen
- Display:
  - "ALIEN BARRAGE" title (large, neon-styled text or custom font)
  - High score from `HighScoreManager`
  - "TAP TO START" button → transitions to `.playing`
  - "HOW TO PLAY" button → transitions to `.instructions`
  - Settings gear icon → transitions to `.settings`
  - Dark/black background matching game aesthetic
- Animations: pulsing title, subtle glow effects

**`Views/InstructionsView.swift`**
- SwiftUI instructions/how-to-play screen
- Dark/black background matching game aesthetic
- Sections:
  - **Controls**: Touch and drag to move ship. Ship fires automatically while touching.
  - **Objective**: Destroy all aliens to advance to the next level. Don't let them reach the bottom.
  - **Enemies**: Aliens shoot plasma balls downward. A UFO occasionally flies across the top for bonus points (500 pts, 3 hits to destroy).
  - **Scoring**: Small aliens = 100 pts, Large aliens = 200 pts (take 2 hits). Score displayed at top of screen.
  - **Lives**: Start with 3 lives. Getting hit costs a life. Brief invulnerability after respawn.
  - **Powerups** (with icons from spritesheet or colored circles):
    - **Rapid Fire** (green orb) — Doubles fire rate for 8 seconds
    - **Spread Shot** (blue orb) — Fires 3 bullets in a fan pattern for 8 seconds
    - **Shield** (teal orb) — Protective aura that absorbs one enemy hit
    - **Extra Life** (gold orb) — Instantly adds one life
    - Powerups drop from destroyed aliens (~15% chance)
  - **Difficulty**: Each level adds more aliens, faster movement, and quicker enemy fire
- Back button to return to menu
- Scrollable if content exceeds screen height

**`Views/SettingsView.swift`**
- SwiftUI settings screen with these options:
  - **Difficulty** — picker: Easy / Normal / Hard
    - Easy: slower aliens, slower fire rate, more lives (5)
    - Normal: default values from GameConstants
    - Hard: faster aliens, faster fire rate, fewer lives (2)
  - **Autofire** — toggle (Bool)
    - ON: ship fires automatically while alive (no touch required)
    - OFF: ship fires only while touching (current behavior)
  - **Autofire Speed** — slider (when autofire is ON)
    - Range: slow (0.4s) to fast (0.1s) fire interval
    - Default: 0.25s (same as normal fire rate)
  - Back button to return to menu
- All settings persisted via `@AppStorage` (UserDefaults)

**`Views/GameContainerView.swift`**
- Wraps `SpriteView(scene:)` for the game
- Creates `GameScene` with the current `GameSettings` applied
- Handles game-over callback to return to menu
- Shows FPS overlay in debug builds
- Portrait-locked

**`GameSettings.swift`**
- `ObservableObject` (also readable as plain class by GameScene)
- Published properties:
  - `difficulty: Difficulty` (enum: `.easy`, `.normal`, `.hard`)
  - `autofire: Bool` (default: false)
  - `autofireSpeed: TimeInterval` (default: 0.25, range 0.1...0.4)
- All backed by `@AppStorage` for persistence
- Computed properties that return adjusted game values based on difficulty:
  - `effectiveAlienSpeed: CGFloat`
  - `effectiveEnemyFireInterval: TimeInterval`
  - `effectiveLives: Int`
  - `effectiveFireRate: TimeInterval` (uses autofireSpeed when autofire is on, else playerFireRate)

**`AudioManager.swift`**
- Singleton: `AudioManager.shared`
- Method: `play(_ soundName: String)` — checks if string is empty, skips if so
- If sound filename is non-empty: play via `SKAction.playSoundFileNamed()` or `AVAudioPlayer`
- Future: could add programmatic synth sounds via `AVAudioEngine` if desired
- All sounds respect the `GameConstants.Sound` string check — empty string = skip
- Volume control and mute toggle

**`HighScoreManager.swift`**
- Singleton: `HighScoreManager.shared`
- `UserDefaults`-based persistence
- Properties: `topScores: [Int]` (top 10, sorted descending)
- Methods: `submit(score: Int) -> Bool` (returns true if new high score), `highScore: Int` (top entry)
- Key: `"alienBarrage_highScores"`

**`HapticManager.swift`**
- Singleton: `HapticManager.shared`
- Wraps `UIImpactFeedbackGenerator`, `UINotificationFeedbackGenerator`, `UISelectionFeedbackGenerator`
- Methods:
  - `lightImpact()` — on shooting
  - `mediumImpact()` — on alien kill
  - `heavyImpact()` — on player death
  - `success()` — on level complete
  - `error()` — on game over
- Pre-prepare generators for responsiveness

### Files to Modify

**`AppDelegate.swift`**
- Remove `@main` attribute (SwiftUI App struct takes over as entry point)
- Keep lifecycle methods for background pause notification if needed
- Or remove entirely if lifecycle is handled in SwiftUI

**`GameScene.swift`**
- Accept `GameSettings` reference on init: `init(size:settings:)`
- Apply settings on setup:
  - Use `settings.effectiveLives` for starting lives
  - Use `settings.effectiveAlienSpeed` for formation base speed
  - Use `settings.effectiveEnemyFireInterval` for enemy shooting timer
  - Use `settings.effectiveFireRate` for player fire rate
- Autofire logic: if `settings.autofire` is true, set `shootingComponent.isFiring = true` on scene start and never toggle it off. Touch controls only move the ship.
- If autofire is false: current behavior (fire while touching)
- Integrate `AudioManager.play()` calls at all event points:
  - Player shoots: `AudioManager.shared.play(GameConstants.Sound.playerShoot)`
  - Alien dies: `AudioManager.shared.play(GameConstants.Sound.enemyDeath)`
  - Player hit: `AudioManager.shared.play(GameConstants.Sound.playerHit)`
  - Player death: `AudioManager.shared.play(GameConstants.Sound.playerDeath)`
  - Powerup collected: `AudioManager.shared.play(GameConstants.Sound.powerupCollect)`
  - UFO appears: `AudioManager.shared.play(GameConstants.Sound.ufoAppear)`
  - UFO destroyed: `AudioManager.shared.play(GameConstants.Sound.ufoDestroyed)`
  - Level start: `AudioManager.shared.play(GameConstants.Sound.levelStart)`
  - Game over: `AudioManager.shared.play(GameConstants.Sound.gameOver)`
  - Shield hit: `AudioManager.shared.play(GameConstants.Sound.shieldHit)`
- Integrate `HapticManager` calls alongside audio
- On game over: submit score to `HighScoreManager`, notify SwiftUI to return to menu
- Pause game on app background: observe `UIApplication.willResignActiveNotification`, set `isPaused = true`

**`GameViewController.swift`**
- May be removed entirely if using pure SwiftUI + SpriteView approach
- Or kept as a fallback and wrapped via `UIViewControllerRepresentable`

**Remove/update:**
- `Main.storyboard` — remove Main storyboard reference from Info.plist (SwiftUI manages the window)
- `LaunchScreen.storyboard` — keep for launch screen or replace with Info.plist launch config

### Files to Remove
- `Scenes/MenuScene.swift` — replaced by SwiftUI `MenuView`

### Test Criteria
- Full game loop: SwiftUI Menu → Play → Game Over → SwiftUI Menu
- Instructions screen accessible from menu, covers controls, scoring, powerups, and enemies
- Settings screen accessible from menu with difficulty, autofire, autofire speed options
- Autofire ON: ship fires continuously without touching; touch only moves ship
- Autofire OFF: ship fires only while touching (original behavior)
- Autofire speed slider adjusts fire rate when autofire is on
- Difficulty affects alien speed, enemy fire rate, and starting lives
- Settings persist across app launches
- High score persists across app launches
- Sound plays on every action (once sound filenames are populated — until then, silent is fine)
- Haptic feedback on shooting, kills, death, level complete
- Game pauses when app goes to background
- All prior functionality still works
- No crashes, no visual glitches, smooth performance

---

## Cross-Phase Notes

### Entity-to-Node Linking
Create an `EntityNode` subclass of `SKSpriteNode` with a weak `entity` reference. Use this for all game objects so the physics contact delegate can look up the entity from any physics body's node.

### Cleanup Pattern
In `GameScene.update()`, iterate `entities` and remove any whose sprite has no parent (meaning it was removed from the scene). This prevents entity array from growing unbounded.

### Sound Integration Pattern
Every `AudioManager.play()` call checks if the sound name string is empty. If empty, the call is a no-op. This lets us define all the trigger points now and add actual sounds later by just filling in the `GameConstants.Sound` values.

### Sprite Coordinate Refinement
The pixel rects in `SpriteSheet.swift` are visual estimates. During testing of each phase, if a sprite looks wrong (cropped, offset, or showing adjacent sprite bleed), adjust the pixel rect in the `spriteRects` dictionary. The normalized coordinate conversion handles the rest.

### Memory Management
- Remove entities and their sprites when they leave the screen or are destroyed
- The `SpriteSheet` texture cache prevents redundant texture creation
- Particle emitters should have finite lifetimes (except the background starfield)

### GameSettings & Autofire (Phase 7 Integration)
When Phase 7 introduces `GameSettings`, earlier code will be updated:
- **ShootingComponent** (Phase 1): if `autofire` is ON, `isFiring` is set to `true` at scene start and touch only controls movement. Fire rate uses `autofireSpeed` from settings.
- **AlienFormation** (Phase 2): base speed adjusted by `difficulty` setting.
- **Enemy shooting** (Phase 4): fire interval adjusted by `difficulty` setting.
- **PlayerEntity** (Phase 1): starting lives adjusted by `difficulty` setting.
- **GameScene init** accepts a `GameSettings` object and applies all values during setup.
- Until Phase 7, all values use the defaults in `GameConstants`.

### SwiftUI + SpriteKit Architecture (Phase 7)
The app transitions from UIKit (AppDelegate + Storyboard) to SwiftUI (`@main App` + `SpriteView`). During Phases 0-6, the game runs via `GameViewController` with the storyboard. In Phase 7, this is replaced with:
- `AlienBarrageApp.swift` — `@main` entry point
- `ContentView.swift` — navigation state manager
- `MenuView.swift` — main menu with start + settings buttons
- `SettingsView.swift` — difficulty, autofire toggle, autofire speed slider
- `GameContainerView.swift` — wraps `SpriteView(scene: GameScene(...))`
- `GameSettings.swift` — `ObservableObject` with `@AppStorage`-backed properties

### Performance Targets
- Maintain 60 FPS at all times
- Keep node count reasonable (< 200 at peak)
- Use `ignoresSiblingOrder = true` for rendering optimization
