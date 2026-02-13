//
//  PowerupEntity.swift
//  Alien Barrage
//

import SpriteKit
import GameplayKit

enum PowerupType: CaseIterable {
    case rapidFire
    case spreadShot
    case shield
    case extraLife

    var spriteName: String {
        switch self {
        case .rapidFire:  return "powerupRapidFire"
        case .spreadShot: return "powerupSpreadShot"
        case .shield:     return "powerupShield"
        case .extraLife:  return "powerupExtraLife"
        }
    }

    var glowColor: SKColor {
        switch self {
        case .rapidFire:  return SKColor(red: 0.2, green: 0.9, blue: 0.2, alpha: 1.0)  // Green
        case .spreadShot: return SKColor(red: 0.2, green: 0.7, blue: 1.0, alpha: 1.0)  // Blue
        case .shield:     return SKColor(red: 0.2, green: 0.9, blue: 0.9, alpha: 1.0)  // Teal
        case .extraLife:  return SKColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 1.0) // Gold
        }
    }

    static func random() -> PowerupType {
        allCases.randomElement()!
    }
}

class PowerupEntity: GKEntity {

    let spriteComponent: SpriteComponent
    let type: PowerupType

    static let powerupSize = CGSize(width: 30, height: 30)

    init(type: PowerupType, position: CGPoint, sceneHeight: CGFloat) {
        self.type = type

        guard let texture = SpriteSheet.shared.sprite(named: type.spriteName) else {
            fatalError("Missing \(type.spriteName) texture")
        }

        spriteComponent = SpriteComponent(texture: texture, size: PowerupEntity.powerupSize)

        super.init()

        addComponent(spriteComponent)

        let node = spriteComponent.node
        node.position = position
        node.zPosition = GameConstants.ZPosition.powerup
        node.name = "powerup"

        node.userData = NSMutableDictionary()
        node.userData?["entity"] = self

        let body = SKPhysicsBody(circleOfRadius: PowerupEntity.powerupSize.width / 2)
        body.categoryBitMask = GameConstants.PhysicsCategory.powerup
        body.contactTestBitMask = GameConstants.PhysicsCategory.player
        body.collisionBitMask = 0
        body.isDynamic = true
        body.affectedByGravity = false
        node.physicsBody = body

        // Fall downward
        let distance = position.y + PowerupEntity.powerupSize.height
        let duration = TimeInterval(distance / GameConstants.powerupFallSpeed)
        let moveDown = SKAction.moveBy(x: 0, y: -distance, duration: duration)
        let remove = SKAction.removeFromParent()
        node.run(SKAction.sequence([moveDown, remove]))

        // Subtle pulse animation
        let scaleUp = SKAction.scale(to: 1.15, duration: 0.4)
        let scaleDown = SKAction.scale(to: 1.0, duration: 0.4)
        scaleUp.timingMode = .easeInEaseOut
        scaleDown.timingMode = .easeInEaseOut
        node.run(SKAction.repeatForever(SKAction.sequence([scaleUp, scaleDown])))
    }

    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
}
