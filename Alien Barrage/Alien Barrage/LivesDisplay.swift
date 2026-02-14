//
//  LivesDisplay.swift
//  Alien Barrage
//

import SpriteKit

class LivesDisplay {

    let node: SKNode
    private let shipIcons: [SKSpriteNode]
    private let maxLives: Int
    private let iconSize = CGSize(width: 26 * GameConstants.hudScale, height: 20 * GameConstants.hudScale)
    private let iconSpacing: CGFloat = 30.0 * GameConstants.hudScale

    init(maxLives: Int = GameConstants.playerLives, bottomInset: CGFloat = 0) {
        self.maxLives = maxLives
        node = SKNode()
        node.zPosition = GameConstants.ZPosition.ui

        guard let texture = SpriteSheet.shared.sprite(named: "playerShip") else {
            fatalError("Missing playerShip texture")
        }

        var icons: [SKSpriteNode] = []
        for i in 0..<maxLives {
            let icon = SKSpriteNode(texture: texture, size: iconSize)
            icon.position = CGPoint(x: CGFloat(i) * iconSpacing, y: 0)
            node.addChild(icon)
            icons.append(icon)
        }
        shipIcons = icons

        // Position at bottom-left of scene (below player ship), offset by safe area
        node.position = CGPoint(x: 50, y: 25 * GameConstants.hudScale + bottomInset)
    }

    func update(lives: Int) {
        for (i, icon) in shipIcons.enumerated() {
            icon.isHidden = i >= lives
        }
    }
}
