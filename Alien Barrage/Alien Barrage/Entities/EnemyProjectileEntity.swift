//
//  EnemyProjectileEntity.swift
//  Alien Barrage
//

import SpriteKit
import GameplayKit

class EnemyProjectileEntity: GKEntity {

    let spriteComponent: SpriteComponent

    static let bulletSize = CGSize(width: 12, height: 26)

    init(position: CGPoint, sceneHeight: CGFloat) {
        guard let texture = SpriteSheet.shared.sprite(named: "enemyBullet") else {
            fatalError("Missing enemyBullet texture")
        }

        spriteComponent = SpriteComponent(texture: texture, size: EnemyProjectileEntity.bulletSize)

        super.init()

        addComponent(spriteComponent)

        let node = spriteComponent.node
        node.position = position
        node.zPosition = GameConstants.ZPosition.projectile
        node.name = "enemyBullet"

        // Store entity reference for collision lookup
        node.userData = NSMutableDictionary()
        node.userData?["entity"] = self

        // Physics body for collision detection
        let body = SKPhysicsBody(rectangleOf: EnemyProjectileEntity.bulletSize)
        body.categoryBitMask = GameConstants.PhysicsCategory.enemyBullet
        body.contactTestBitMask = GameConstants.PhysicsCategory.player | GameConstants.PhysicsCategory.shield
        body.collisionBitMask = 0
        body.isDynamic = true
        body.affectedByGravity = false
        node.physicsBody = body

        // Move downward and remove when off-screen
        let distance = position.y + EnemyProjectileEntity.bulletSize.height
        let duration = TimeInterval(distance / GameConstants.enemyBulletSpeed)
        let moveDown = SKAction.moveBy(x: 0, y: -distance, duration: duration)
        let remove = SKAction.removeFromParent()
        node.run(SKAction.sequence([moveDown, remove]))
    }

    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
}
