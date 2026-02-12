//
//  AlienEntity.swift
//  Alien Barrage
//

import SpriteKit
import GameplayKit

enum AlienType {
    case large
    case small

    var spritePrefix: String {
        switch self {
        case .large: return "alienLarge"
        case .small: return "alienMedium"
        }
    }

    var size: CGSize {
        switch self {
        case .large: return CGSize(width: 45, height: 50)
        case .small: return CGSize(width: 40, height: 40)
        }
    }

    var scoreValue: Int {
        switch self {
        case .large: return GameConstants.alienLargeScore
        case .small: return GameConstants.alienSmallScore
        }
    }
}

class AlienEntity: GKEntity {

    let spriteComponent: SpriteComponent
    let healthComponent: HealthComponent
    let scoreValueComponent: ScoreValueComponent
    let alienType: AlienType
    let row: Int
    let col: Int
    var isAlive: Bool = true

    init(type: AlienType, row: Int, col: Int) {
        self.alienType = type
        self.row = row
        self.col = col

        // Pick sprite variant based on column (cycle through 4 available sprites)
        let variantIndex = (col % 4) + 1
        let spriteName = "\(type.spritePrefix)\(variantIndex)"
        let texture = SpriteSheet.shared.sprite(named: spriteName)
            ?? SpriteSheet.shared.sprite(named: "\(type.spritePrefix)1")!

        spriteComponent = SpriteComponent(texture: texture, size: type.size)
        healthComponent = HealthComponent(hp: type == .large ? 2 : 1)
        scoreValueComponent = ScoreValueComponent(value: type.scoreValue)

        super.init()

        addComponent(spriteComponent)
        addComponent(healthComponent)
        addComponent(scoreValueComponent)

        let node = spriteComponent.node
        node.zPosition = GameConstants.ZPosition.enemy
        node.name = "alien"

        // Store entity reference for collision lookup
        node.userData = NSMutableDictionary()
        node.userData?["entity"] = self

        // Physics body for collision detection
        let body = SKPhysicsBody(rectangleOf: type.size)
        body.categoryBitMask = GameConstants.PhysicsCategory.enemy
        body.contactTestBitMask = GameConstants.PhysicsCategory.playerBullet
        body.collisionBitMask = 0
        body.isDynamic = false
        body.affectedByGravity = false
        node.physicsBody = body
    }

    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
}
