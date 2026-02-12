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
**Status:** Pending

## Phase 2: Alien Grid Formation & Movement
**Status:** Pending

## Phase 3: Collisions, Explosions, & Scoring
**Status:** Pending

## Phase 4: Enemy Shooting, Lives, & Game Over
**Status:** Pending

## Phase 5: Level Progression, UFO, & Difficulty Scaling
**Status:** Pending

## Phase 6: Powerups, Shields, & Visual Polish
**Status:** Pending

## Phase 7: Audio, Menus, High Scores, & Final Polish
**Status:** Pending
