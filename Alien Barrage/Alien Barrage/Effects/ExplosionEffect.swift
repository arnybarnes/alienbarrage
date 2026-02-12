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
        guard let tex1 = SpriteSheet.shared.sprite(named: "explosionGreen1"),
              let tex2 = SpriteSheet.shared.sprite(named: "explosionGreen2"),
              let tex3 = SpriteSheet.shared.sprite(named: "explosionGreen3") else { return }

        let explosionNode = SKSpriteNode(texture: tex1, size: CGSize(width: 50, height: 50))
        explosionNode.position = position
        explosionNode.zPosition = GameConstants.ZPosition.explosion
        scene.addChild(explosionNode)

        let animate = SKAction.animate(with: [tex1, tex2, tex3], timePerFrame: 0.1)
        let fadeOut = SKAction.fadeOut(withDuration: 0.2)
        let scaleUp = SKAction.scale(to: 1.5, duration: 0.2)
        let fadeAndScale = SKAction.group([fadeOut, scaleUp])
        let remove = SKAction.removeFromParent()

        explosionNode.run(SKAction.sequence([animate, fadeAndScale, remove]))
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

        // Build "+" prefix
        if let plusTex = SpriteSheet.shared.sprite(named: "plus100") {
            let plusNode = SKSpriteNode(texture: plusTex, size: CGSize(width: 12, height: 18))
            plusNode.position = CGPoint(x: startX - spacing, y: 0)
            popupNode.addChild(plusNode)
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
