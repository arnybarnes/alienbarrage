//
//  ParticleEffects.swift
//  Alien Barrage
//

import SpriteKit

enum ParticleEffects {

    /// Creates a small circular dot texture via CoreGraphics.
    private static func dotTexture(diameter: CGFloat) -> SKTexture {
        let size = CGSize(width: diameter, height: diameter)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        let d = Int(diameter)
        guard let ctx = CGContext(data: nil, width: d, height: d,
                                  bitsPerComponent: 8, bytesPerRow: d * 4,
                                  space: colorSpace, bitmapInfo: bitmapInfo) else {
            return SKTexture()
        }
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        ctx.fillEllipse(in: CGRect(origin: .zero, size: size))
        guard let cgImage = ctx.makeImage() else { return SKTexture() }
        return SKTexture(cgImage: cgImage)
    }

    // MARK: - Starfield Background

    static func createStarfield(sceneSize: CGSize) -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleTexture = dotTexture(diameter: 4)

        // Scale birth rate and speed with screen area so star density looks consistent
        let areaRatio = (sceneSize.width * sceneSize.height) / (390.0 * 844.0)
        let heightRatio = sceneSize.height / 844.0

        emitter.particleBirthRate = 40 * CGFloat(areaRatio)
        emitter.particleLifetime = 6 * CGFloat(heightRatio)
        emitter.particleLifetimeRange = 2

        emitter.particlePosition = CGPoint(x: sceneSize.width / 2, y: sceneSize.height)
        emitter.particlePositionRange = CGVector(dx: sceneSize.width, dy: 0)

        emitter.emissionAngle = -.pi / 2  // Downward
        emitter.emissionAngleRange = 0
        emitter.particleSpeed = 50 * CGFloat(heightRatio)
        emitter.particleSpeedRange = 20 * CGFloat(heightRatio)

        emitter.particleScale = 0.2
        emitter.particleScaleRange = 0.15
        emitter.particleAlpha = 0.6
        emitter.particleAlphaRange = 0.3

        emitter.particleColorBlendFactor = 1.0
        emitter.particleColor = .white
        emitter.particleColorRedRange = 0
        emitter.particleColorGreenRange = 0
        emitter.particleColorBlueRange = 0.3  // Slight blue tint variation

        emitter.zPosition = GameConstants.ZPosition.stars
        emitter.advanceSimulationTime(Double(emitter.particleLifetime) + 2)  // Pre-fill the screen

        return emitter
    }

    // MARK: - Engine Thrust

    static func createEngineThrust() -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleTexture = dotTexture(diameter: 6)

        emitter.particleBirthRate = 50
        emitter.particleLifetime = 0.3
        emitter.particleLifetimeRange = 0.1

        emitter.emissionAngle = -.pi / 2  // Downward
        emitter.emissionAngleRange = 0.3
        emitter.particleSpeed = 120
        emitter.particleSpeedRange = 30

        emitter.particleScale = 0.3
        emitter.particleScaleRange = 0.1
        emitter.particleScaleSpeed = -0.5

        emitter.particleAlpha = 0.7
        emitter.particleAlphaSpeed = -2.0

        emitter.particleColorBlendFactor = 1.0
        emitter.particleColor = SKColor(red: 0.3, green: 0.8, blue: 1.0, alpha: 1.0)  // Cyan

        return emitter
    }

    // MARK: - Spark Burst

    static func spawnSparkBurst(at position: CGPoint, in scene: SKScene) {
        let emitter = SKEmitterNode()
        emitter.particleTexture = dotTexture(diameter: 4)

        emitter.particleBirthRate = 0  // We use numParticlesToEmit
        emitter.numParticlesToEmit = 8
        emitter.particleLifetime = 0.3
        emitter.particleLifetimeRange = 0.1

        emitter.emissionAngle = 0
        emitter.emissionAngleRange = .pi * 2  // All directions
        emitter.particleSpeed = 100
        emitter.particleSpeedRange = 40

        emitter.particleScale = 0.2
        emitter.particleScaleSpeed = -0.4

        emitter.particleAlpha = 1.0
        emitter.particleAlphaSpeed = -3.0

        emitter.particleColorBlendFactor = 1.0
        emitter.particleColor = SKColor(red: 1.0, green: 0.9, blue: 0.5, alpha: 1.0)  // Yellow-white

        emitter.position = position
        emitter.zPosition = GameConstants.ZPosition.explosion
        scene.addChild(emitter)

        let wait = SKAction.wait(forDuration: 0.5)
        let remove = SKAction.removeFromParent()
        emitter.run(SKAction.sequence([wait, remove]))
    }
}
