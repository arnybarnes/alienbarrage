//
//  ShieldBarrierEntity.swift
//  Alien Barrage
//

import SpriteKit
import GameplayKit

class ShieldBarrierEntity: GKEntity {

    let spriteComponent: SpriteComponent
    let healthComponent: HealthComponent

    static let barrierSize = CGSize(width: 60, height: 50)

    init(position: CGPoint) {
        guard let texture = SpriteSheet.shared.sprite(named: "shield1") else {
            fatalError("Missing shield1 texture")
        }

        spriteComponent = SpriteComponent(texture: texture, size: ShieldBarrierEntity.barrierSize)
        healthComponent = HealthComponent(hp: GameConstants.shieldHP)

        super.init()

        addComponent(spriteComponent)
        addComponent(healthComponent)

        let node = spriteComponent.node
        node.position = position
        node.zPosition = GameConstants.ZPosition.shieldBarrier
        node.name = "shieldBarrier"

        node.userData = NSMutableDictionary()
        node.userData?["entity"] = self

        let body = SKPhysicsBody(rectangleOf: ShieldBarrierEntity.barrierSize)
        body.categoryBitMask = GameConstants.PhysicsCategory.shield
        body.contactTestBitMask = GameConstants.PhysicsCategory.playerBullet | GameConstants.PhysicsCategory.enemyBullet
        body.collisionBitMask = 0
        body.isDynamic = false
        body.affectedByGravity = false
        node.physicsBody = body
    }

    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    func updateVisual() {
        let hp = healthComponent.currentHP
        let node = spriteComponent.node

        // Switch to damaged texture at low HP
        if hp <= 2, let damagedTex = SpriteSheet.shared.sprite(named: "shield2") {
            node.texture = damagedTex
        }

        // Fade alpha based on remaining HP
        let fraction = CGFloat(hp) / CGFloat(healthComponent.maxHP)
        node.alpha = 0.4 + 0.6 * fraction
    }
}
