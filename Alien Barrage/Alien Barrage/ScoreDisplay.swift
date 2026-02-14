//
//  ScoreDisplay.swift
//  Alien Barrage
//

import SpriteKit

class ScoreDisplay {

    let node: SKNode
    private let labelNode: SKLabelNode

    init(bottomInset: CGFloat = 0) {
        node = SKNode()
        node.zPosition = GameConstants.ZPosition.ui

        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.fontSize = 30 * GameConstants.hudScale
        label.fontColor = .white
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.text = "0"
        node.addChild(label)
        labelNode = label

        // Position at bottom-center of scene (below player ship), offset by safe area
        node.position = CGPoint(x: GameConstants.sceneWidth / 2.0, y: 30 * GameConstants.hudScale + bottomInset)

        // Show initial "0"
        update(score: 0)
    }

    func update(score: Int) {
        labelNode.text = "\(score)"
    }
}
