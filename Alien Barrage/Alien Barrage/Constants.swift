//
//  Constants.swift
//  Alien Barrage
//

import SpriteKit
import UIKit

enum GameConstants {

    // MARK: - Scene (dynamic — reads actual screen size)
    static var sceneWidth: CGFloat { UIScreen.main.bounds.width }
    static var sceneHeight: CGFloat { UIScreen.main.bounds.height }
    static var sceneSize: CGSize { CGSize(width: sceneWidth, height: sceneHeight) }

    // MARK: - HUD Scaling (scales up on larger screens, never below 1.0)
    static var hudScale: CGFloat { max(1.0, min(sceneWidth, sceneHeight) / 844.0) }

    // MARK: - Speed Scaling Ratios (consistent travel time across screen sizes)
    static var heightRatio: CGFloat { sceneHeight / 844.0 }
    static var widthRatio: CGFloat { sceneWidth / 390.0 }

    // MARK: - Physics Categories (bitmask)
    struct PhysicsCategory {
        static let none:            UInt32 = 0
        static let player:          UInt32 = 0b1         // 1
        static let playerBullet:    UInt32 = 0b10        // 2
        static let enemy:           UInt32 = 0b100       // 4
        static let enemyBullet:     UInt32 = 0b1000      // 8
        static let powerup:         UInt32 = 0b10000     // 16
        static let ufo:             UInt32 = 0b100000    // 32
    }

    // MARK: - Z-Positions (layering)
    struct ZPosition {
        static let background: CGFloat = -10
        static let stars: CGFloat = -5
        static let enemy: CGFloat = 10
        static let player: CGFloat = 15
        static let projectile: CGFloat = 20
        static let powerup: CGFloat = 25
        static let explosion: CGFloat = 30
        static let ufo: CGFloat = 35
        static let ui: CGFloat = 50
        static let overlay: CGFloat = 100
    }

    // MARK: - Player
    static let playerSpeed: CGFloat = 300.0
    static let playerFireRate: TimeInterval = 0.7
    static let playerBulletSpeed: CGFloat = 600.0
    static let playerLives: Int = 3
    static let playerMaxLivesForExtraLife: Int = 4
    static let playerInvulnerabilityDuration: TimeInterval = 2.0

    // MARK: - Aliens
    static let alienGridColumns: Int = 5
    static let alienGridRows: Int = 4
    static let alienSpacingX: CGFloat = 65.0
    static let alienSpacingY: CGFloat = 55.0
    static let alienBaseSpeed: CGFloat = 40.0
    static let alienStepDown: CGFloat = 20.0
    static let alienSpeedMultiplierPerKill: CGFloat = 0.04

    // MARK: - Enemy Shooting
    static let enemyFireInterval: TimeInterval = 2.0
    static let enemyBulletSpeed: CGFloat = 350.0

    // MARK: - UFO
    static let ufoSpeed: CGFloat = 100.0
    static let ufoHP: Int = 3
    static let ufoScoreValue: Int = 500
    static let ufoSpawnIntervalMin: TimeInterval = 10.0
    static let ufoSpawnIntervalMax: TimeInterval = 25.0

    // MARK: - Scoring
    static let alienSmallScore: Int = 100
    static let alienLargeScore: Int = 200
    static let powerupCollectScore: Int = 50
    static let bonusRoundKillScore: Int = 150
    static let bonusRoundPerfectBonus: Int = 10_000

    // MARK: - Powerups
    static let powerupDropChance: Double = 0.15
    static let powerupFallSpeed: CGFloat = 150.0
    static let powerupDuration: TimeInterval = 8.0
    static let powerupSpinSpeed: Double = 1.5  // multiplier: <1 = slower, >1 = faster

    // MARK: - Haptic Feedback
    struct Haptic {
        static let playerShoot      = false
        static let alienKilled      = false
        static let ufoDestroyed     = false
        static let powerupCollected = true
        static let playerDeath      = true
        static let levelComplete    = false
        static let gameOver         = false
    }

    // MARK: - Sound File Names
    // Empty string = sound disabled. Set to a filename (e.g. "shoot.wav") to enable.
    struct Sound {
        static let playerShoot         = "SFX_SciFiLaserShotFlat5.wav"
        static let playerDeath         = "SFX_Explosion8.wav"
        static let enemyDeath          = "SFX_ImpactCraftFunnyPop1.wav"
        static let enemyShoot          = "SFX_SciFiLaserShotFlat7.wav"
        static let explosion           = "SFX_Explosion1.wav"
        static let powerupCollect      = "SFX_PowerUpv1.wav"
        static let powerupRapidFire    = "SFX_CoinRewardMusical4.wav"
        static let powerupSpreadShot   = "SFX_CoinRewardMusical3.wav"
        static let powerupShield       = "SFX_CoinRewardMusicDelay11.wav"
        static let powerupExtraLife    = "SFX_CoinRewardMusical8.wav"
        static let powerupExpire       = "SFX_SlideDownv1.wav"
        static let ufoAppear           = "SFX_SciFiEngine1.wav"
        static let ufoAmbience         = "SFX_AmbienceSpaceVoidShip2.wav"
        static let ufoDestroyed        = "SFX_Explosion7.wav"
        static let levelStart          = "SFX_WhooshSciFiPassByShip3.wav"
        static let bonusComplete       = "SFX_CoinRewardMusicDelay7.wav"
        static let gameOver            = "SFX_FanfareMusicLose1.wav"
        static let menuSelect          = "SFX_UiOptionChangev1.wav"
        static let playerHit           = "SFX_Explosion5.wav"
        static let extraLife           = "SFX_CoinRewardMusicDelay8.wav"
        static let highScore           = "SFX_FanfareMusicWin1.wav"
        static let alienSwoop          = "SFX_SciFiEnginePitchDown2.wav"
    }

    // MARK: - Alien Swooping
    static let swoopBaseInterval: TimeInterval = 4.0
    static let swoopMinInterval: TimeInterval = 1.2
    static let swoopIntervalDecreasePerLevel: Double = 0.3
    static let swoopSpeed: CGFloat = 280.0
    static let swoopMaxSimultaneous: Int = 4
    static let swoopDestroyBelowY: CGFloat = -30.0

    // MARK: - Visual FX
    // Internal runtime toggles for quickly testing visual options.
    struct VisualFX {
        static let alienEyeGlowEnabled: Bool = false
    }

    // MARK: - Performance Tuning
    struct Performance {
        // Feature flag: manual broadphase/narrowphase for player bullet hits (enemy + UFO).
        static let manualPlayerBulletCollision: Bool = true
        // Spread-shot bullets are spawned a few milliseconds apart to avoid contact bursts.
        static let spreadShotStagger: TimeInterval = 0.018
        // Cap active player bullets to bound manual sweep cost.
        // Default eviction trims the farthest bullet; spread/UFO paths can preserve far-travel bullets.
        static let maxActivePlayerBullets: Int = 24
        // Lightweight compensation for player-bullet cap pressure in rapid/spread fire.
        static let playerBulletCapSpeedMultiplier: CGFloat = 1.15
        // Cap active enemy bullets to limit late-level physics churn.
        static let maxActiveEnemyBullets: Int = 16
        // Y-axis band size for manual player-bullet broadphase.
        static let manualCollisionBandHeight: CGFloat = 72.0
        // Max queued player-bullet hit resolutions to process per frame.
        static let manualResolutionMaxPerFrame: Int = 2
        // Max time budget for manual player-bullet hit resolution work each frame.
        static let manualResolutionBudgetMs: Double = 4.0
        // When backlog exceeds this, use cheaper hit VFX to protect frame time.
        static let manualResolutionLiteFxBacklog: Int = 4
        // Prefer low-cost impact FX in manual collision mode to reduce resolve stalls.
        static let manualResolutionPreferLiteFX: Bool = true
        // Logs per-frame manual sweep outliers when exceeded.
        static let manualSweepOutlierThresholdMs: Double = 10.0
        // Logs per-hit resolve breakdowns when a single resolve is unusually expensive.
        static let manualResolveOutlierLogging: Bool = true
        static let manualResolveOutlierThresholdMs: Double = 20.0
        // Logs large frame gaps when dt is high but measured in-frame work is low.
        static let frameGapLogging: Bool = true
        static let frameGapThresholdMs: Double = 80.0
        static let frameGapUnexplainedThresholdMs: Double = 25.0
        // Minimum spacing for enemy-death sound playback to avoid per-kill audio stalls.
        static let enemyDeathSoundMinInterval: TimeInterval = 0.08
        // In reduced-FX mode we can suppress per-kill SFX to protect frame time.
        static let enemyDeathSoundDuringReducedFX: Bool = false
        static let enemyDeathSoundDuringBonusRounds: Bool = false
    }
}
