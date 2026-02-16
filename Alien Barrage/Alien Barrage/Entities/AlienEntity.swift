//
//  AlienEntity.swift
//  Alien Barrage
//

import SpriteKit
import GameplayKit
import CoreGraphics

enum AlienType {
    case large
    case small

    var spritePrefix: String {
        switch self {
        case .large: return "alienLarge"
        case .small: return "alienSmall"
        }
    }

    var size: CGSize {
        // Sizes preserve the new aliens3 sprite proportions.
        switch self {
        case .large: return CGSize(width: 56, height: 43)   // source avg ~240×184
        case .small: return CGSize(width: 50, height: 31)   // source avg ~181×102
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
    var isSwooping: Bool = false

    private static var eyeGlowTextureCache: [String: SKTexture] = [:]
    private static var eyeGlowColorCache: [String: SKColor] = [:]
    private static var noEyeGlowSprites: Set<String> = []

    init(type: AlienType, row: Int, col: Int, hpBonus: Int = 0) {
        self.alienType = type
        self.row = row
        self.col = col

        // Pick sprite variant based on column (cycle through 4 available sprites)
        let variantIndex = (col % 4) + 1
        let spriteName = "\(type.spritePrefix)\(variantIndex)"
        let texture = SpriteSheet.shared.sprite(named: spriteName)
            ?? SpriteSheet.shared.sprite(named: "\(type.spritePrefix)1")!

        let baseHP = type == .large ? 2 : 1
        spriteComponent = SpriteComponent(texture: texture, size: type.size)
        healthComponent = HealthComponent(hp: baseHP + hpBonus)
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
        if GameConstants.Performance.manualPlayerBulletCollision {
            // Formation aliens do not need physics while manual player-bullet collision is enabled.
            node.physicsBody = nil
        } else {
            let body = SKPhysicsBody(rectangleOf: type.size)
            body.categoryBitMask = GameConstants.PhysicsCategory.enemy
            body.contactTestBitMask = GameConstants.PhysicsCategory.playerBullet
            body.collisionBitMask = 0
            body.isDynamic = false
            body.affectedByGravity = false
            node.physicsBody = body
        }

        setupAliveMotionBehavior(on: node)
        if GameConstants.VisualFX.alienEyeGlowEnabled {
            setupEyeGlowBehavior(spriteName: spriteName, baseTexture: texture, on: node)
        }
    }

    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    // MARK: - Ambient Behavior

    private func setupAliveMotionBehavior(on node: SKSpriteNode) {
        node.setScale(1.0)

        let upScale = CGFloat.random(in: 1.03...1.07)
        let downScale = CGFloat.random(in: 0.95...0.99)
        let bounceHeight = CGFloat.random(in: 0.8...2.0)
        let upDuration = Double.random(in: 0.28...0.52)
        let downDuration = Double.random(in: 0.32...0.60)
        let phaseDelay = Double.random(in: 0.0...1.0)

        let scaleUp = SKAction.scale(to: upScale, duration: upDuration)
        let scaleDown = SKAction.scale(to: downScale, duration: downDuration)
        scaleUp.timingMode = .easeOut
        scaleDown.timingMode = .easeInEaseOut

        let moveUp = SKAction.moveBy(x: 0, y: bounceHeight, duration: upDuration)
        let moveDown = SKAction.moveBy(x: 0, y: -bounceHeight, duration: downDuration)
        moveUp.timingMode = .easeOut
        moveDown.timingMode = .easeInEaseOut

        let cycle = SKAction.sequence([
            SKAction.group([scaleUp, moveUp]),
            SKAction.group([scaleDown, moveDown])
        ])

        let settle = SKAction.scale(to: 1.0, duration: Double.random(in: 0.2...0.35))
        settle.timingMode = .easeInEaseOut
        let driftPause = SKAction.wait(forDuration: Double.random(in: 0.12...0.30))

        let loop = SKAction.repeatForever(SKAction.sequence([cycle, settle, driftPause]))
        let start = SKAction.sequence([SKAction.wait(forDuration: phaseDelay), loop])
        node.run(start, withKey: "alienAliveMotion")
    }

    func enableSwoopPhysics() {
        let node = spriteComponent.node
        let body = node.physicsBody ?? SKPhysicsBody(rectangleOf: alienType.size)
        body.categoryBitMask = GameConstants.PhysicsCategory.enemy
        let playerBulletMask = GameConstants.Performance.manualPlayerBulletCollision
            ? GameConstants.PhysicsCategory.none
            : GameConstants.PhysicsCategory.playerBullet
        body.contactTestBitMask = playerBulletMask | GameConstants.PhysicsCategory.player
        body.collisionBitMask = 0
        body.isDynamic = true
        body.affectedByGravity = false
        node.physicsBody = body
    }

    private func setupEyeGlowBehavior(spriteName: String, baseTexture: SKTexture, on node: SKSpriteNode) {
        guard let glowTexture = eyeGlowTexture(for: spriteName, baseTexture: baseTexture) else { return }

        let glowNode = SKSpriteNode(texture: glowTexture, size: alienType.size)
        glowNode.zPosition = 1
        glowNode.blendMode = .add
        glowNode.alpha = CGFloat.random(in: 0.24...0.40)
        glowNode.color = Self.eyeGlowColorCache[spriteName] ?? .white
        glowNode.colorBlendFactor = 0.92
        node.addChild(glowNode)

        // Secondary halo makes the glow feel stronger at small on-screen sizes.
        let auraNode = SKSpriteNode(
            texture: glowTexture,
            size: CGSize(width: alienType.size.width * 1.34, height: alienType.size.height * 1.34)
        )
        auraNode.zPosition = 0.5
        auraNode.blendMode = .add
        auraNode.alpha = glowNode.alpha * 0.85
        auraNode.color = glowNode.color
        auraNode.colorBlendFactor = 1.0
        node.addChild(auraNode)

        let outerAuraNode = SKSpriteNode(
            texture: glowTexture,
            size: CGSize(width: alienType.size.width * 1.62, height: alienType.size.height * 1.62)
        )
        outerAuraNode.zPosition = 0.3
        outerAuraNode.blendMode = .add
        outerAuraNode.alpha = glowNode.alpha * 0.45
        outerAuraNode.color = glowNode.color
        outerAuraNode.colorBlendFactor = 1.0
        node.addChild(outerAuraNode)

        let wait = SKAction.wait(forDuration: 0.45, withRange: 1.8)
        let pulse = SKAction.run { [weak glowNode, weak auraNode, weak outerAuraNode] in
            guard let glowNode, let auraNode, let outerAuraNode else { return }

            let peakCoreAlpha = CGFloat.random(in: 0.85...1.0)
            let settleCoreAlpha = CGFloat.random(in: 0.30...0.50)
            let peakAuraAlpha = min(1.0, peakCoreAlpha * CGFloat.random(in: 0.80...1.05))
            let settleAuraAlpha = settleCoreAlpha * CGFloat.random(in: 0.72...0.94)
            let peakOuterAuraAlpha = peakAuraAlpha * CGFloat.random(in: 0.45...0.65)
            let settleOuterAuraAlpha = settleAuraAlpha * CGFloat.random(in: 0.34...0.52)
            let riseDuration = Double.random(in: 0.05...0.11)
            let settleDuration = Double.random(in: 0.14...0.25)

            let riseCore = SKAction.fadeAlpha(to: peakCoreAlpha, duration: riseDuration)
            let settleCore = SKAction.fadeAlpha(to: settleCoreAlpha, duration: settleDuration)
            riseCore.timingMode = .easeOut
            settleCore.timingMode = .easeInEaseOut
            glowNode.run(SKAction.sequence([riseCore, settleCore]), withKey: "eyeGlowPulse")

            let riseAura = SKAction.fadeAlpha(to: peakAuraAlpha, duration: riseDuration)
            let settleAuraAction = SKAction.fadeAlpha(to: settleAuraAlpha, duration: settleDuration)
            riseAura.timingMode = .easeOut
            settleAuraAction.timingMode = .easeInEaseOut
            let auraExpand = SKAction.scale(to: CGFloat.random(in: 1.10...1.20), duration: riseDuration)
            let auraSettle = SKAction.scale(to: CGFloat.random(in: 0.96...1.03), duration: settleDuration)
            auraExpand.timingMode = .easeOut
            auraSettle.timingMode = .easeInEaseOut
            auraNode.run(
                SKAction.group([
                    SKAction.sequence([riseAura, settleAuraAction]),
                    SKAction.sequence([auraExpand, auraSettle])
                ]),
                withKey: "eyeGlowAuraPulse"
            )

            let riseOuterAura = SKAction.fadeAlpha(to: peakOuterAuraAlpha, duration: riseDuration)
            let settleOuterAura = SKAction.fadeAlpha(to: settleOuterAuraAlpha, duration: settleDuration)
            riseOuterAura.timingMode = .easeOut
            settleOuterAura.timingMode = .easeInEaseOut
            outerAuraNode.run(
                SKAction.sequence([riseOuterAura, settleOuterAura]),
                withKey: "eyeGlowOuterAuraPulse"
            )
        }
        glowNode.run(SKAction.repeatForever(SKAction.sequence([wait, pulse])), withKey: "eyeGlowLoop")
    }

    private func eyeGlowTexture(for spriteName: String, baseTexture: SKTexture) -> SKTexture? {
        if let cached = Self.eyeGlowTextureCache[spriteName] {
            return cached
        }
        if Self.noEyeGlowSprites.contains(spriteName) {
            return nil
        }

        let cgImage = baseTexture.cgImage()
        let width = cgImage.width
        let height = cgImage.height

        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let pixelCount = width * height
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        var input = [UInt8](repeating: 0, count: pixelCount * bytesPerPixel)
        var output = [UInt8](repeating: 0, count: pixelCount * bytesPerPixel)

        let drewSource: Bool = input.withUnsafeMutableBytes { ptr in
            guard let baseAddress = ptr.baseAddress else { return false }
            guard let context = CGContext(
                data: baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            ) else {
                return false
            }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }

        guard drewSource else {
            Self.noEyeGlowSprites.insert(spriteName)
            return nil
        }

        var glowPixels = 0
        var accumR: Double = 0
        var accumG: Double = 0
        var accumB: Double = 0
        var accumW: Double = 0

        for i in stride(from: 0, to: input.count, by: 4) {
            let r = Double(input[i]) / 255.0
            let g = Double(input[i + 1]) / 255.0
            let b = Double(input[i + 2]) / 255.0
            let a = Double(input[i + 3]) / 255.0
            if a < 0.2 { continue }

            let maxV = max(r, max(g, b))
            let minV = min(r, min(g, b))
            let delta = maxV - minV
            let saturation = maxV > 0 ? delta / maxV : 0

            // Keep bright, saturated colored pixels (typical alien eye regions).
            guard maxV > 0.24, saturation > 0.18, delta > 0.06 else { continue }

            let brightness = min(1.0, (maxV - 0.20) * 2.8)
            let chroma = min(1.0, saturation * 2.2)
            let intensity = brightness * chroma

            let outAlpha = UInt8(min(255.0, 255.0 * a * (0.62 + 1.05 * intensity)))
            if outAlpha < 10 { continue }

            output[i] = UInt8(min(255.0, Double(input[i]) * (1.35 + 1.95 * intensity)))
            output[i + 1] = UInt8(min(255.0, Double(input[i + 1]) * (1.35 + 1.95 * intensity)))
            output[i + 2] = UInt8(min(255.0, Double(input[i + 2]) * (1.35 + 1.95 * intensity)))
            output[i + 3] = outAlpha

            let w = Double(outAlpha) / 255.0
            accumR += r * w
            accumG += g * w
            accumB += b * w
            accumW += w
            glowPixels += 1
        }

        guard glowPixels >= 12 else {
            Self.noEyeGlowSprites.insert(spriteName)
            return nil
        }

        let glowImage: CGImage? = output.withUnsafeMutableBytes { ptr in
            guard let baseAddress = ptr.baseAddress else { return nil }
            guard let context = CGContext(
                data: baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            ) else {
                return nil
            }
            return context.makeImage()
        }

        guard let glowImage else {
            Self.noEyeGlowSprites.insert(spriteName)
            return nil
        }

        let glowTexture = SKTexture(cgImage: glowImage)
        glowTexture.filteringMode = .nearest
        Self.eyeGlowTextureCache[spriteName] = glowTexture

        if accumW > 0 {
            let color = SKColor(
                red: CGFloat(accumR / accumW),
                green: CGFloat(accumG / accumW),
                blue: CGFloat(accumB / accumW),
                alpha: 1.0
            )
            Self.eyeGlowColorCache[spriteName] = color
        }

        return glowTexture
    }
}
