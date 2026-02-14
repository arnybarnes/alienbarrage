//
//  EnemyProjectileEntity.swift
//  Alien Barrage
//

import SpriteKit
import GameplayKit

class EnemyProjectileEntity: GKEntity {

    let spriteComponent: SpriteComponent

    static let bulletSize = CGSize(width: 16, height: 16)

    /// Generates a red/orange plasma ball texture via CoreGraphics radial gradient.
    private static let plasmaTexture: SKTexture = {
        let diameter = 32
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let ctx = CGContext(data: nil, width: diameter, height: diameter,
                                  bitsPerComponent: 8, bytesPerRow: diameter * 4,
                                  space: colorSpace, bitmapInfo: bitmapInfo) else {
            return SKTexture()
        }

        let center = CGPoint(x: CGFloat(diameter) / 2, y: CGFloat(diameter) / 2)
        let radius = CGFloat(diameter) / 2
        let colors = [
            CGColor(red: 1.0, green: 1.0, blue: 0.9, alpha: 1.0),   // Bright white-yellow center
            CGColor(red: 1.0, green: 0.6, blue: 0.1, alpha: 1.0),   // Orange mid
            CGColor(red: 0.9, green: 0.2, blue: 0.05, alpha: 0.8),  // Red edge
            CGColor(red: 0.6, green: 0.05, blue: 0.0, alpha: 0.0)   // Fade to transparent
        ] as CFArray
        let locations: [CGFloat] = [0.0, 0.3, 0.65, 1.0]

        guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) else {
            return SKTexture()
        }

        ctx.drawRadialGradient(gradient,
                               startCenter: center, startRadius: 0,
                               endCenter: center, endRadius: radius,
                               options: [])

        guard let cgImage = ctx.makeImage() else { return SKTexture() }
        return SKTexture(cgImage: cgImage)
    }()

    init(position: CGPoint, sceneHeight: CGFloat) {
        spriteComponent = SpriteComponent(texture: EnemyProjectileEntity.plasmaTexture,
                                          size: EnemyProjectileEntity.bulletSize)

        super.init()

        addComponent(spriteComponent)

        let node = spriteComponent.node
        node.position = position
        node.zPosition = GameConstants.ZPosition.projectile
        node.name = "enemyBullet"
        node.blendMode = .add  // Additive blending for glow effect

        // Store entity reference for collision lookup
        node.userData = NSMutableDictionary()
        node.userData?["entity"] = self

        // Circular physics body
        let body = SKPhysicsBody(circleOfRadius: EnemyProjectileEntity.bulletSize.width / 2)
        body.categoryBitMask = GameConstants.PhysicsCategory.enemyBullet
        body.contactTestBitMask = GameConstants.PhysicsCategory.player
        body.collisionBitMask = 0
        body.isDynamic = true
        body.affectedByGravity = false
        node.physicsBody = body

        // Move downward and remove when off-screen (speed scales with screen height)
        let distance = position.y + EnemyProjectileEntity.bulletSize.height
        let speed = GameConstants.enemyBulletSpeed * GameConstants.heightRatio
        let duration = TimeInterval(distance / speed)
        let moveDown = SKAction.moveBy(x: 0, y: -distance, duration: duration)
        let remove = SKAction.removeFromParent()
        node.run(SKAction.sequence([moveDown, remove]))

        // Subtle pulse for "alive" feel
        let pulseUp = SKAction.scale(to: 1.15, duration: 0.15)
        let pulseDown = SKAction.scale(to: 0.9, duration: 0.15)
        pulseUp.timingMode = .easeInEaseOut
        pulseDown.timingMode = .easeInEaseOut
        node.run(SKAction.repeatForever(SKAction.sequence([pulseUp, pulseDown])))
    }

    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
}
