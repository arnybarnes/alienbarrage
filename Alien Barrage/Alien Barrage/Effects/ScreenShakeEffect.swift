//
//  ScreenShakeEffect.swift
//  Alien Barrage
//

import SpriteKit

enum ScreenShakeEffect {

    static func shake(node: SKNode, duration: TimeInterval = 0.5, intensity: CGFloat = 10.0) {
        let shakeCount = 12
        let stepDuration = duration / TimeInterval(shakeCount)

        var actions: [SKAction] = []
        for _ in 0..<shakeCount {
            let dx = CGFloat.random(in: -intensity...intensity)
            let dy = CGFloat.random(in: -intensity...intensity)
            let move = SKAction.moveBy(x: dx, y: dy, duration: stepDuration / 2)
            let moveBack = SKAction.moveBy(x: -dx, y: -dy, duration: stepDuration / 2)
            actions.append(contentsOf: [move, moveBack])
        }

        node.run(SKAction.sequence(actions), withKey: "screenShake")
    }
}
