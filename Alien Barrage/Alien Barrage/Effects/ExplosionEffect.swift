//
//  ExplosionEffect.swift
//  Alien Barrage
//

import SpriteKit

enum ExplosionEffect {

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

    private static func spawnScorePopup(at position: CGPoint, in scene: SKScene, scoreValue: Int) {
        let popupNode = SKNode()
        popupNode.position = CGPoint(x: position.x, y: position.y + 20)
        popupNode.zPosition = GameConstants.ZPosition.explosion

        let digits = Array(String(scoreValue))
        let digitSize = CGSize(width: 14, height: 18)
        let spacing: CGFloat = 16.0
        let totalWidth = CGFloat(digits.count - 1) * spacing
        let startX = -totalWidth / 2.0

        // Use the pre-rendered "+100" texture directly for 100-point popups,
        // otherwise build from individual digit textures
        if scoreValue == 100, let plusTex = SpriteSheet.shared.sprite(named: "plus100") {
            let textNode = SKSpriteNode(texture: plusTex, size: CGSize(width: 44, height: 17))
            popupNode.addChild(textNode)

            scene.addChild(popupNode)

            let moveUp = SKAction.moveBy(x: 0, y: 60, duration: 0.8)
            let fadeOut = SKAction.fadeOut(withDuration: 0.8)
            let group = SKAction.group([moveUp, fadeOut])
            let remove = SKAction.removeFromParent()
            popupNode.run(SKAction.sequence([group, remove]))
            return
        }

        for (i, char) in digits.enumerated() {
            guard let digit = Int(String(char)),
                  let texture = SpriteSheet.shared.digitTexture(digit) else { continue }
            let digitNode = SKSpriteNode(texture: texture, size: digitSize)
            digitNode.position = CGPoint(x: startX + CGFloat(i) * spacing, y: 0)
            popupNode.addChild(digitNode)
        }

        scene.addChild(popupNode)

        let moveUp = SKAction.moveBy(x: 0, y: 60, duration: 0.8)
        let fadeOut = SKAction.fadeOut(withDuration: 0.8)
        let group = SKAction.group([moveUp, fadeOut])
        let remove = SKAction.removeFromParent()

        popupNode.run(SKAction.sequence([group, remove]))
    }
}
