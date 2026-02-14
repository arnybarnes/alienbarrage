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
        static let playerShoot         = ""
        static let playerDeath         = ""
        static let enemyDeath          = ""
        static let enemyShoot          = ""
        static let explosion           = ""
        static let powerupCollect      = ""
        static let powerupExpire       = ""
        static let ufoAppear           = ""
        static let ufoDestroyed        = ""
        static let levelStart          = ""
        static let gameOver            = ""
        static let menuSelect          = ""
        static let playerHit           = ""
        static let extraLife           = ""
        static let highScore           = ""
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
}
