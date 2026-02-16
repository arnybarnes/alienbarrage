//
//  ProjectileEntity.swift
//  Alien Barrage
//

import SpriteKit
import GameplayKit

class ProjectileEntity: GKEntity {

    let spriteComponent: SpriteComponent

    // Preserve the source texture aspect ratio (~1:3) so the full beam shape reads clearly.
    static let bulletSize = CGSize(width: 8, height: 24)

    init(position: CGPoint, sceneHeight: CGFloat, speedMultiplier: CGFloat = 1.0) {
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

        // Store entity reference for collision lookup
        node.userData = NSMutableDictionary()
        node.userData?["entity"] = self

        // Physics body for collision detection (or disabled when using manual bullet collisions).
        if GameConstants.Performance.manualPlayerBulletCollision {
            node.physicsBody = nil
        } else {
            let body = SKPhysicsBody(rectangleOf: ProjectileEntity.bulletSize)
            body.categoryBitMask = GameConstants.PhysicsCategory.playerBullet
            body.contactTestBitMask = GameConstants.PhysicsCategory.enemy | GameConstants.PhysicsCategory.ufo
            body.collisionBitMask = 0
            body.isDynamic = true
            body.affectedByGravity = false
            node.physicsBody = body
        }

        // Move upward and remove when off-screen (speed scales with screen height)
        let distance = sceneHeight - position.y + ProjectileEntity.bulletSize.height
        let speed = GameConstants.playerBulletSpeed * GameConstants.heightRatio * max(0.1, speedMultiplier)
        let duration = TimeInterval(distance / speed)
        let moveUp = SKAction.moveBy(x: 0, y: distance, duration: duration)
        let remove = SKAction.removeFromParent()
        node.run(SKAction.sequence([moveUp, remove]))
    }

    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
}
