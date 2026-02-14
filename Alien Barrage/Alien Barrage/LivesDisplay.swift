//
//  LivesDisplay.swift
//  Alien Barrage
//

import SpriteKit

class LivesDisplay {

    let node: SKNode
    private var shipIcons: [SKSpriteNode] = []
    private let maxLives: Int
    private let texture: SKTexture
    private let bottomInset: CGFloat

    // Available width from the lives origin (x=50) to just before the score (centered at sceneWidth/2)
    private let availableWidth: CGFloat

    init(maxLives: Int = GameConstants.playerLives, bottomInset: CGFloat = 0) {
        self.maxLives = maxLives
        self.bottomInset = bottomInset
        // Leave a margin before the score label at sceneWidth/2
        self.availableWidth = GameConstants.sceneWidth / 2.0 - 50 - 40 * GameConstants.hudScale

        node = SKNode()
        node.zPosition = GameConstants.ZPosition.ui

        guard let tex = SpriteSheet.shared.sprite(named: "playerShip") else {
            fatalError("Missing playerShip texture")
        }
        texture = tex

        layoutIcons(count: maxLives)

        // Position at bottom-left of scene (below player ship), offset by safe area
        node.position = CGPoint(x: 50, y: 25 * GameConstants.hudScale + bottomInset)
    }

    func update(lives: Int) {
        // Add more icons if lives exceed current count
        if lives > shipIcons.count {
            layoutIcons(count: lives)
        }
        for (i, icon) in shipIcons.enumerated() {
            icon.isHidden = i >= lives
        }
    }

    private func layoutIcons(count: Int) {
        // Remove existing icons
        for icon in shipIcons {
            icon.removeFromParent()
        }
        shipIcons.removeAll()

        guard count > 0 else { return }

        let baseW: CGFloat = 26 * GameConstants.hudScale
        let baseH: CGFloat = 20 * GameConstants.hudScale
        let baseSpacing: CGFloat = 30 * GameConstants.hudScale

        // Total width needed at base size
        let neededWidth = CGFloat(count - 1) * baseSpacing + baseW

        // Scale down if needed to fit available width
        let scale: CGFloat = neededWidth > availableWidth ? availableWidth / neededWidth : 1.0
        let iconSize = CGSize(width: baseW * scale, height: baseH * scale)
        let spacing = baseSpacing * scale

        for i in 0..<count {
            let icon = SKSpriteNode(texture: texture, size: iconSize)
            icon.position = CGPoint(x: CGFloat(i) * spacing, y: 0)
            node.addChild(icon)
            shipIcons.append(icon)
        }
    }
}
