//
//  PowerupIndicator.swift
//  Alien Barrage
//

import SpriteKit

class PowerupIndicator {

    let node: SKNode
    private var iconNodes: [PowerupType: SKSpriteNode] = [:]
    private let iconSize: CGSize
    private let spacing: CGFloat

    init(bottomInset: CGFloat = 0) {
        let hs = GameConstants.hudScale
        iconSize = CGSize(width: 28 * hs, height: 28 * hs)
        spacing = 34 * hs

        node = SKNode()
        node.zPosition = GameConstants.ZPosition.ui

        // Position to the right of the score (score is at sceneWidth/2)
        node.position = CGPoint(
            x: GameConstants.sceneWidth / 2 + 60 * hs,
            y: 30 * hs + bottomInset
        )
    }

    func show(type: PowerupType) {
        if let existing = iconNodes[type] {
            // Already showing — just pop it to indicate refresh
            existing.removeAllActions()
            existing.isHidden = false
            existing.alpha = 1.0
            existing.setScale(1.3)
            existing.run(SKAction.scale(to: 1.0, duration: 0.1))
            return
        }

        guard let texture = PowerupSpinSheet.shared.baseTexture(named: type.spriteName) else { return }

        let icon = SKSpriteNode(texture: texture, size: iconSize)
        icon.isHidden = false
        node.addChild(icon)
        iconNodes[type] = icon

        layoutIcons()

        // Pop-in animation
        icon.setScale(0.5)
        icon.alpha = 0
        icon.run(SKAction.group([
            SKAction.scale(to: 1.0, duration: 0.15),
            SKAction.fadeIn(withDuration: 0.15)
        ]))
    }

    func hide(type: PowerupType) {
        guard let icon = iconNodes[type] else { return }
        icon.run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 0.5, duration: 0.1),
                SKAction.fadeOut(withDuration: 0.1)
            ]),
            SKAction.run { [weak self] in
                icon.removeFromParent()
                self?.iconNodes.removeValue(forKey: type)
                self?.layoutIcons()
            }
        ]))
    }

    func hideAll() {
        for (type, icon) in iconNodes {
            icon.removeAllActions()
            icon.removeFromParent()
            iconNodes.removeValue(forKey: type)
        }
    }

    private func layoutIcons() {
        // Lay out icons left-to-right in a consistent order
        let sorted = iconNodes.keys.sorted { a, b in
            orderIndex(a) < orderIndex(b)
        }
        for (i, type) in sorted.enumerated() {
            iconNodes[type]?.position = CGPoint(x: CGFloat(i) * spacing, y: 0)
        }
    }

    private func orderIndex(_ type: PowerupType) -> Int {
        switch type {
        case .rapidFire:  return 0
        case .spreadShot: return 1
        case .shield:     return 2
        case .extraLife:  return 3
        }
    }
}
