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

    static let shipSize = CGSize(width: 80, height: 110)

    init(sceneSize: CGSize) {
        guard let texture = SpriteSheet.shared.sprite(named: "playerShip") else {
            fatalError("Missing playerShip texture")
        }

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
        body.contactTestBitMask = GameConstants.PhysicsCategory.enemyBullet
        body.collisionBitMask = 0
        body.isDynamic = false
        body.affectedByGravity = false
        node.physicsBody = body
    }

    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

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
}
