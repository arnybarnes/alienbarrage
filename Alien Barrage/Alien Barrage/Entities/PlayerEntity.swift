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
    private(set) var shieldNode: SKSpriteNode?
    private let baseFireRate: TimeInterval

    static let shipSize = CGSize(width: 80, height: 88)   // source 417×459, preserves aspect ratio

    init(sceneSize: CGSize) {
        guard let texture = SpriteSheet.shared.sprite(named: "playerShip") else {
            fatalError("Missing playerShip texture")
        }

        baseFireRate = GameConstants.playerFireRate

        spriteComponent = SpriteComponent(texture: texture, size: PlayerEntity.shipSize)
        movementComponent = MovementComponent(
            speed: GameConstants.playerSpeed,
            sceneWidth: sceneSize.width,
            spriteHalfWidth: PlayerEntity.shipSize.width / 2
        )
        shootingComponent = ShootingComponent(fireRate: GameConstants.playerFireRate)
        healthComponent = HealthComponent(hp: GameConstants.playerLives)

        super.init()

        addComponent(spriteComponent)
        addComponent(movementComponent)
        addComponent(shootingComponent)
        addComponent(healthComponent)

        let node = spriteComponent.node
        node.position = CGPoint(x: sceneSize.width / 2, y: 80)
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

        switch type {
        case .rapidFire:
            activePowerup = .rapidFire
            powerupTimer = 0
            shootingComponent.fireRate = baseFireRate * 0.4

            // Visual tint
            spriteComponent.node.run(
                SKAction.colorize(with: .yellow, colorBlendFactor: 0.3, duration: 0.2),
                withKey: "powerupTint"
            )

        case .spreadShot:
            activePowerup = .spreadShot
            powerupTimer = 0

            // Visual tint
            spriteComponent.node.run(
                SKAction.colorize(with: .cyan, colorBlendFactor: 0.3, duration: 0.2),
                withKey: "powerupTint"
            )

        case .shield:
            activePowerup = .shield
            powerupTimer = 0
            addShieldVisual()

        case .extraLife:
            // Instant — don't set as activePowerup (preserves current powerup)
            healthComponent.heal(1)

            let flash = SKAction.sequence([
                SKAction.colorize(with: .green, colorBlendFactor: 0.6, duration: 0.1),
                SKAction.colorize(withColorBlendFactor: 0.0, duration: 0.3)
            ])
            spriteComponent.node.run(flash)
        }
    }

    func clearPowerup() {
        guard let powerup = activePowerup else { return }

        switch powerup {
        case .rapidFire:
            shootingComponent.fireRate = baseFireRate
        case .spreadShot:
            break
        case .shield:
            removeShieldVisual()
        case .extraLife:
            break
        }

        // Remove tint
        spriteComponent.node.run(
            SKAction.colorize(withColorBlendFactor: 0.0, duration: 0.2),
            withKey: "powerupTint"
        )

        activePowerup = nil
        powerupTimer = 0
    }

    // MARK: - Shield Visual

    private func addShieldVisual() {
        removeShieldVisual()

        guard let tex = SpriteSheet.shared.sprite(named: "powerupShield") else { return }
        let shield = SKSpriteNode(texture: tex, size: CGSize(width: 100, height: 100))
        shield.alpha = 0.4
        shield.zPosition = 1
        shield.name = "playerShield"
        spriteComponent.node.addChild(shield)
        shieldNode = shield

        // Pulse animation
        let scaleUp = SKAction.scale(to: 1.08, duration: 0.6)
        let scaleDown = SKAction.scale(to: 1.0, duration: 0.6)
        scaleUp.timingMode = .easeInEaseOut
        scaleDown.timingMode = .easeInEaseOut
        shield.run(SKAction.repeatForever(SKAction.sequence([scaleUp, scaleDown])))
    }

    func removeShieldVisual() {
        shieldNode?.removeFromParent()
        shieldNode = nil
        if activePowerup == .shield {
            activePowerup = nil
            powerupTimer = 0
        }
    }
}
