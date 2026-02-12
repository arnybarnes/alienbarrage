//
//  ProjectileEntity.swift
//  Alien Barrage
//

import SpriteKit
import GameplayKit

class ProjectileEntity: GKEntity {

    let spriteComponent: SpriteComponent

    static let bulletSize = CGSize(width: 10, height: 24)

    init(position: CGPoint, sceneHeight: CGFloat) {
        guard let texture = SpriteSheet.shared.sprite(named: "playerBullet") else {
            fatalError("Missing playerBullet texture")
        }

        spriteComponent = SpriteComponent(texture: texture, size: ProjectileEntity.bulletSize)

        super.init()

        addComponent(spriteComponent)

        let node = spriteComponent.node
        node.position = position
        node.zPosition = GameConstants.ZPosition.projectile
        node.name = "playerBullet"

        // Physics body for collision detection (set up for Phase 3)
        let body = SKPhysicsBody(rectangleOf: ProjectileEntity.bulletSize)
        body.categoryBitMask = GameConstants.PhysicsCategory.playerBullet
        body.contactTestBitMask = GameConstants.PhysicsCategory.enemy | GameConstants.PhysicsCategory.ufo | GameConstants.PhysicsCategory.shield
        body.collisionBitMask = 0
        body.isDynamic = true
        body.affectedByGravity = false
        node.physicsBody = body

        // Move upward and remove when off-screen
        let distance = sceneHeight - position.y + ProjectileEntity.bulletSize.height
        let duration = TimeInterval(distance / GameConstants.playerBulletSpeed)
        let moveUp = SKAction.moveBy(x: 0, y: distance, duration: duration)
        let remove = SKAction.removeFromParent()
        node.run(SKAction.sequence([moveUp, remove]))
    }

    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
}
