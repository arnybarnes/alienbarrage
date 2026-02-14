//
//  ScoreDisplay.swift
//  Alien Barrage
//

import SpriteKit

class ScoreDisplay {

    let node: SKNode
    private let labelNode: SKLabelNode

    init() {
        node = SKNode()
        node.zPosition = GameConstants.ZPosition.ui

        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.fontSize = 30
        label.fontColor = .white
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.text = "0"
        node.addChild(label)
        labelNode = label

        // Position at top-center of scene
        node.position = CGPoint(x: GameConstants.sceneWidth / 2.0, y: 800)

        // Show initial "0"
        update(score: 0)
    }

    func update(score: Int) {
        labelNode.text = "\(score)"
    }
}
