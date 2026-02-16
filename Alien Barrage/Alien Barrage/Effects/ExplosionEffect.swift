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
