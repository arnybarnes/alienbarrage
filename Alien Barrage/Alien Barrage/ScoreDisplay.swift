//
//  ScoreDisplay.swift
//  Alien Barrage
//

import SpriteKit

class ScoreDisplay {

    let node: SKNode
    private let digitNodes: [SKSpriteNode]
    private let digitSize = CGSize(width: 20, height: 25)
    private let digitSpacing: CGFloat = 22.0
    private let maxDigits = 8

    init() {
        node = SKNode()
        node.zPosition = GameConstants.ZPosition.ui

        var slots: [SKSpriteNode] = []
        let totalWidth = CGFloat(maxDigits - 1) * digitSpacing
        let startX = -totalWidth / 2.0

        for i in 0..<maxDigits {
            let digitNode = SKSpriteNode()
            digitNode.size = digitSize
            digitNode.position = CGPoint(x: startX + CGFloat(i) * digitSpacing, y: 0)
            digitNode.isHidden = true
            node.addChild(digitNode)
            slots.append(digitNode)
        }

        digitNodes = slots

        // Position at top-center of scene
        node.position = CGPoint(x: GameConstants.sceneWidth / 2.0, y: 800)

        // Show initial "0"
        update(score: 0)
    }

    func update(score: Int) {
        let scoreString = String(score)
        let digits = Array(scoreString)

        // Hide all slots first
        for slot in digitNodes {
            slot.isHidden = true
        }

        // Right-align digits: fill from the end
        let offset = maxDigits - digits.count
        for (i, char) in digits.enumerated() {
            guard let digit = Int(String(char)),
                  let texture = SpriteSheet.shared.digitTexture(digit) else { continue }
            let slotIndex = offset + i
            digitNodes[slotIndex].texture = texture
            digitNodes[slotIndex].isHidden = false
        }
    }
}
