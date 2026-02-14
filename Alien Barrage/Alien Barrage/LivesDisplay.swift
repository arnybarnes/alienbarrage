//
//  LivesDisplay.swift
//  Alien Barrage
//

import SpriteKit

class LivesDisplay {

    let node: SKNode
    private let shipIcons: [SKSpriteNode]
    private let maxLives: Int
    private let iconSize = CGSize(width: 26, height: 20)   // matches player ship aspect ratio
    private let iconSpacing: CGFloat = 30.0

    init(maxLives: Int = GameConstants.playerLives) {
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

        node.position = CGPoint(x: 50, y: GameConstants.sceneHeight - 80)
    }

    func update(lives: Int) {
        for (i, icon) in shipIcons.enumerated() {
            icon.isHidden = i >= lives
        }
    }
}
