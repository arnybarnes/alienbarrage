//
//  PlayerEntity.swift
//  Alien Barrage
//

import SpriteKit
import GameplayKit

class PlayerEntity: GKEntity {

    let spriteComponent: SpriteComponent
    let movementComponent: MovementComponent
    let shootingComponent: ShootingComponent
    let healthComponent: HealthComponent

    var isInvulnerable: Bool = false

    // Powerup state
    private(set) var activePowerup: PowerupType?
    private var powerupTimer: TimeInterval = 0
    var hasShield: Bool = false
    private let baseFireRate: TimeInterval

    static let shipSize = CGSize(width: 92, height: 71)   // source 315×243, preserves aspect ratio

    init(sceneSize: CGSize, lives: Int = GameConstants.playerLives, fireRate: TimeInterval = GameConstants.playerFireRate) {
        guard let texture = SpriteSheet.shared.sprite(named: "playerShip") else {
            fatalError("Missing playerShip texture")
        }

        baseFireRate = fireRate

        spriteComponent = SpriteComponent(texture: texture, size: PlayerEntity.shipSize)
        movementComponent = MovementComponent(
            speed: GameConstants.playerSpeed,
            sceneWidth: sceneSize.width,
            spriteHalfWidth: PlayerEntity.shipSize.width / 2,
            baseY: 120,
            spriteHeight: PlayerEntity.shipSize.height
        )
        shootingComponent = ShootingComponent(fireRate: fireRate)
        healthComponent = HealthComponent(hp: lives)

        super.init()

        addComponent(spriteComponent)
        addComponent(movementComponent)
        addComponent(shootingComponent)
        addComponent(healthComponent)

        let node = spriteComponent.node
        node.position = CGPoint(x: sceneSize.width / 2, y: 120)
        node.zPosition = GameConstants.ZPosition.player

        // Store entity reference for collision lookup
        node.userData = NSMutableDictionary()
        node.userData?["entity"] = self

        // Physics body for collision detection
        let body = SKPhysicsBody(rectangleOf: PlayerEntity.shipSize)
        body.categoryBitMask = GameConstants.PhysicsCategory.player
        body.contactTestBitMask = GameConstants.PhysicsCategory.enemyBullet | GameConstants.PhysicsCategory.powerup
        body.collisionBitMask = 0
        body.isDynamic = false
        body.affectedByGravity = false
        node.physicsBody = body

        // Engine thrust particles
        let thrust = ParticleEffects.createEngineThrust()
        thrust.position = CGPoint(x: 0, y: -PlayerEntity.shipSize.height / 2 - 5)
        thrust.zPosition = -1
        node.addChild(thrust)
    }

    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    override func update(deltaTime seconds: TimeInterval) {
        super.update(deltaTime: seconds)

        // Tick powerup timer for duration-based powerups
        guard let powerup = activePowerup else { return }
        if powerup == .extraLife { return }  // Instant, no duration

        powerupTimer += seconds
        if powerupTimer >= GameConstants.powerupDuration {
            clearPowerup()
        }
    }

    // MARK: - Invulnerability

    func makeInvulnerable(duration: TimeInterval) {
        isInvulnerable = true

        let node = spriteComponent.node
        let fadeOut = SKAction.fadeAlpha(to: 0.3, duration: 0.15)
        let fadeIn = SKAction.fadeAlpha(to: 1.0, duration: 0.15)
        let blink = SKAction.sequence([fadeOut, fadeIn])
        let repeatBlink = SKAction.repeatForever(blink)
        node.run(repeatBlink, withKey: "invulnerabilityBlink")

        let wait = SKAction.wait(forDuration: duration)
        let endInvulnerability = SKAction.run { [weak self] in
            self?.isInvulnerable = false
            node.removeAction(forKey: "invulnerabilityBlink")
            node.alpha = 1.0
        }
        node.run(SKAction.sequence([wait, endInvulnerability]), withKey: "invulnerabilityTimer")
    }

    // MARK: - Powerups

    func applyPowerup(_ type: PowerupType) {
        // Clear any existing duration-based powerup first
        if activePowerup != nil && activePowerup != .extraLife {
            clearPowerup()
        }

        // Temporary glow flash from the powerup's color
        let node = spriteComponent.node
        let glowOn = SKAction.colorize(with: type.glowColor, colorBlendFactor: 0.6, duration: 0.15)
        let glowSettle = SKAction.colorize(with: type.glowColor, colorBlendFactor: 0.25, duration: 0.3)
        node.run(SKAction.sequence([glowOn, glowSettle]), withKey: "powerupGlow")

        switch type {
        case .rapidFire:
            activePowerup = .rapidFire
            powerupTimer = 0
            shootingComponent.fireRate = baseFireRate * 0.4

        case .spreadShot:
            activePowerup = .spreadShot
            powerupTimer = 0

        case .shield:
            activePowerup = .shield
            powerupTimer = 0
            hasShield = true

        case .extraLife:
            // Instant — don't set as activePowerup (preserves current powerup)
            healthComponent.heal(1)
            // Flash then fade the glow back out
            let fadeOut = SKAction.colorize(withColorBlendFactor: 0.0, duration: 0.4)
            node.run(SKAction.sequence([glowOn, fadeOut]), withKey: "powerupGlow")
        }
    }

    func clearPowerup() {
        guard activePowerup != nil else { return }

        if activePowerup == .rapidFire {
            shootingComponent.fireRate = baseFireRate
        }
        if activePowerup == .shield {
            hasShield = false
        }

        // Fade glow out
        spriteComponent.node.run(
            SKAction.colorize(withColorBlendFactor: 0.0, duration: 0.3),
            withKey: "powerupGlow"
        )

        activePowerup = nil
        powerupTimer = 0
    }
}
