//
//  LivesDisplay.swift
//  Alien Barrage
//

import SpriteKit

class LivesDisplay {

    let node: SKNode
    private let shipIcon: SKSpriteNode
    private let countLabel: SKLabelNode

    init(maxLives: Int = GameConstants.playerLives, bottomInset: CGFloat = 0) {
        let hs = GameConstants.hudScale

        node = SKNode()
        node.zPosition = GameConstants.ZPosition.ui

        guard let tex = SpriteSheet.shared.sprite(named: "playerShip") else {
            fatalError("Missing playerShip texture")
        }

        let iconSize = CGSize(width: 26 * hs, height: 20 * hs)
        shipIcon = SKSpriteNode(texture: tex, size: iconSize)
        shipIcon.position = .zero
        node.addChild(shipIcon)

        countLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        countLabel.fontSize = 18 * hs
        countLabel.fontColor = .white
        countLabel.horizontalAlignmentMode = .left
        countLabel.verticalAlignmentMode = .center
        countLabel.position = CGPoint(x: iconSize.width / 2 + 6 * hs, y: 0)
        countLabel.text = "x\(maxLives)"
        node.addChild(countLabel)

        // Position at bottom-left of scene, offset by safe area
        node.position = CGPoint(x: 50, y: 25 * hs + bottomInset)
    }

    func update(lives: Int) {
        countLabel.text = "x\(lives)"
    }
}
