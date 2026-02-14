//
//  UFOEntity.swift
//  Alien Barrage
//

import SpriteKit
import GameplayKit

class UFOEntity: GKEntity {

    let spriteComponent: SpriteComponent
    let healthComponent: HealthComponent
    let scoreValueComponent: ScoreValueComponent

    static let ufoSize = CGSize(width: 80, height: 33)   // source 446×181, preserves new UFO aspect ratio

    init(sceneSize: CGSize) {
        guard let texture = SpriteSheet.shared.sprite(named: "ufo") else {
            fatalError("Missing ufo texture")
        }

        spriteComponent = SpriteComponent(texture: texture, size: UFOEntity.ufoSize)
        healthComponent = HealthComponent(hp: GameConstants.ufoHP)
        scoreValueComponent = ScoreValueComponent(value: GameConstants.ufoScoreValue)

        super.init()

        addComponent(spriteComponent)
        addComponent(healthComponent)
        addComponent(scoreValueComponent)

        let node = spriteComponent.node
        node.zPosition = GameConstants.ZPosition.ufo
        node.name = "ufo"

        // Store entity reference for collision lookup
        node.userData = NSMutableDictionary()
        node.userData?["entity"] = self

        // Physics body
        let body = SKPhysicsBody(rectangleOf: UFOEntity.ufoSize)
        body.categoryBitMask = GameConstants.PhysicsCategory.ufo
        body.contactTestBitMask = GameConstants.PhysicsCategory.playerBullet
        body.collisionBitMask = 0
        body.isDynamic = false
        body.affectedByGravity = false
        node.physicsBody = body

        // Random entry side — fly near the top (proportional Y position)
        let enterFromLeft = Bool.random()
        let yPos = sceneSize.height * 0.858
        let startX: CGFloat = enterFromLeft ? -UFOEntity.ufoSize.width : sceneSize.width + UFOEntity.ufoSize.width
        let endX: CGFloat = enterFromLeft ? sceneSize.width + UFOEntity.ufoSize.width : -UFOEntity.ufoSize.width

        node.position = CGPoint(x: startX, y: yPos)

        // Fly across and remove (speed scales with screen width)
        let distance = abs(endX - startX)
        let speed = GameConstants.ufoSpeed * GameConstants.widthRatio
        let duration = TimeInterval(distance / speed)
        let moveAcross = SKAction.moveTo(x: endX, duration: duration)
        let remove = SKAction.removeFromParent()
        node.run(SKAction.sequence([moveAcross, remove]), withKey: "ufoFly")
    }

    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
}
