//
//  ExplosionEffect.swift
//  Alien Barrage
//

import SpriteKit

enum ExplosionEffect {

    private static var popupPool: [SKLabelNode] = []
    private static var didWarmUpAssets = false

    /// Pre-create score popup label pool. Call once during scene setup.
    static func warmUp() {
        if !didWarmUpAssets {
            didWarmUpAssets = true
            ExplosionSpriteSheet.shared.warmUp()
            PowerupSpinSheet.shared.warmUp()
        }

        if popupPool.isEmpty {
            for _ in 0..<8 {
                let label = SKLabelNode(fontNamed: "Menlo-Bold")
                label.horizontalAlignmentMode = .center
                label.verticalAlignmentMode = .center
                popupPool.append(label)
            }
        }
    }

    /// Spawns an explosion animation and score popup at the given position.
    static func spawn(at position: CGPoint, in scene: SKScene, scoreValue: Int) {
        spawnExplosion(at: position, in: scene)
        spawnScorePopup(at: position, in: scene, scoreValue: scoreValue)
    }

    /// Spawns a larger, more dramatic explosion for the UFO.
    static func spawnUFO(at position: CGPoint, in scene: SKScene, scoreValue: Int) {
        spawnUFOExplosion(at: position, in: scene)
        spawnScorePopup(at: position, in: scene, scoreValue: scoreValue)
    }

    private static func spawnExplosion(at position: CGPoint, in scene: SKScene) {
        let frames = ExplosionSpriteSheet.shared.randomFrames()
        guard let firstFrame = frames.first else { return }

        let maxFrameWidth = frames.map { $0.size().width }.max() ?? max(CGFloat(1.0), firstFrame.size().width)
        let targetWidth = CGFloat.random(in: 58...72)
        let baseScale = targetWidth / maxFrameWidth

        let explosionNode = SKSpriteNode(texture: firstFrame)
        explosionNode.position = position
        explosionNode.zPosition = GameConstants.ZPosition.explosion
        explosionNode.alpha = 1.0
        explosionNode.setScale(baseScale)
        scene.addChild(explosionNode)

        let frameAnimation = SKAction.animate(with: frames, timePerFrame: 0.08, resize: true, restore: false)
        let hold = SKAction.wait(forDuration: 0.02)
        let remove = SKAction.removeFromParent()

        explosionNode.run(SKAction.sequence([frameAnimation, hold, remove]))
    }

    private static func spawnUFOExplosion(at position: CGPoint, in scene: SKScene) {
        // Primary large explosion at center
        let frames = ExplosionSpriteSheet.shared.randomFrames()
        guard let firstFrame = frames.first else { return }

        let maxFrameWidth = frames.map { $0.size().width }.max() ?? max(CGFloat(1.0), firstFrame.size().width)
        let targetWidth: CGFloat = 140
        let baseScale = targetWidth / maxFrameWidth

        let mainNode = SKSpriteNode(texture: firstFrame)
        mainNode.position = position
        mainNode.zPosition = GameConstants.ZPosition.explosion
        mainNode.alpha = 1.0
        mainNode.setScale(baseScale)
        scene.addChild(mainNode)

        let frameAnim = SKAction.animate(with: frames, timePerFrame: 0.10, resize: true, restore: false)
        mainNode.run(SKAction.sequence([frameAnim, SKAction.removeFromParent()]))

        // Two smaller secondary explosions offset to each side, slightly delayed
        for xOffset: CGFloat in [-30, 30] {
            let secFrames = ExplosionSpriteSheet.shared.randomFrames()
            guard let secFirst = secFrames.first else { continue }
            let secMaxW = secFrames.map { $0.size().width }.max() ?? max(CGFloat(1.0), secFirst.size().width)
            let secScale = CGFloat.random(in: 60...80) / secMaxW

            let secNode = SKSpriteNode(texture: secFirst)
            secNode.position = CGPoint(x: position.x + xOffset, y: position.y + CGFloat.random(in: -10...10))
            secNode.zPosition = GameConstants.ZPosition.explosion
            secNode.alpha = 0.0
            secNode.setScale(secScale)
            scene.addChild(secNode)

            let delay = SKAction.wait(forDuration: 0.08)
            let fadeIn = SKAction.fadeIn(withDuration: 0.02)
            let secAnim = SKAction.animate(with: secFrames, timePerFrame: 0.08, resize: true, restore: false)
            secNode.run(SKAction.sequence([delay, fadeIn, secAnim, SKAction.removeFromParent()]))
        }

        // Brief white flash overlay
        let flash = SKSpriteNode(color: .white, size: CGSize(width: 120, height: 60))
        flash.position = position
        flash.zPosition = GameConstants.ZPosition.explosion - 1
        flash.alpha = 0.7
        flash.blendMode = .add
        scene.addChild(flash)
        flash.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.15),
            SKAction.removeFromParent()
        ]))
    }

    static func spawnScorePopup(at position: CGPoint, in scene: SKScene, scoreValue: Int) {
        guard scoreValue > 0 else { return }

        let node: SKLabelNode
        if let pooled = popupPool.popLast() {
            pooled.removeAllActions()
            node = pooled
        } else {
            node = SKLabelNode(fontNamed: "Menlo-Bold")
            node.horizontalAlignmentMode = .center
            node.verticalAlignmentMode = .center
        }

        node.text = "+\(scoreValue)"
        node.fontSize = scoreValue >= 500 ? 24 : 20
        node.fontColor = scoreValue >= 500 ? .yellow : .green
        node.position = CGPoint(x: position.x, y: position.y + 20)
        node.zPosition = GameConstants.ZPosition.explosion
        node.alpha = 1.0
        scene.addChild(node)

        let moveUp = SKAction.moveBy(x: 0, y: 60, duration: 0.8)
        let fadeOut = SKAction.fadeOut(withDuration: 0.8)
        let group = SKAction.group([moveUp, fadeOut])
        let returnToPool = SKAction.run {
            node.removeFromParent()
            popupPool.append(node)
        }
        node.run(SKAction.sequence([group, returnToPool]))
    }
}
