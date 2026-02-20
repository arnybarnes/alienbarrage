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

    var spinCycleDuration: TimeInterval {
        switch self {
        case .rapidFire:  return 0.75
        case .spreadShot: return 0.95
        case .shield:     return 1.10
        case .extraLife:  return 0.85
        }
    }

    var spinDirection: CGFloat {
        switch self {
        case .rapidFire, .shield:
            return 1.0
        case .spreadShot, .extraLife:
            return -1.0
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

    init(type: PowerupType, position: CGPoint, sceneHeight: CGFloat, speedMultiplier: CGFloat = 1.0) {
        self.type = type

        guard let texture = PowerupSpinSheet.shared.baseTexture(named: type.spriteName) else {
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

        // 3D spin via frame-sequence animation from the dedicated powerup spritesheet.
        if let spinFrames = PowerupSpinSheet.shared.spinFrames(named: type.spriteName), !spinFrames.isEmpty {
            let loopFrames: [SKTexture]
            if type.spinDirection < 0 {
                loopFrames = Array(spinFrames.reversed())
            } else {
                loopFrames = spinFrames
            }

            let frameCount = max(1, loopFrames.count)
            let adjustedDuration = type.spinCycleDuration / GameConstants.powerupSpinSpeed
            let timePerFrame = adjustedDuration / Double(frameCount)
            let animate = SKAction.animate(with: loopFrames, timePerFrame: timePerFrame, resize: false, restore: false)
            node.run(SKAction.repeatForever(animate), withKey: "powerupSpin3D")
        }

        // Fall downward (speed scales with screen height)
        let distance = position.y + PowerupEntity.powerupSize.height
        let speed = GameConstants.powerupFallSpeed * GameConstants.heightRatio * speedMultiplier
        let duration = TimeInterval(distance / speed)
        let moveDown = SKAction.moveBy(x: 0, y: -distance, duration: duration)
        let remove = SKAction.removeFromParent()
        node.run(SKAction.sequence([moveDown, remove]))

    }

    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
}
