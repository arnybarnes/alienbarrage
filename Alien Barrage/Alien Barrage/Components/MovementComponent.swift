//
//  MovementComponent.swift
//  Alien Barrage
//

import SpriteKit
import GameplayKit

class MovementComponent: GKComponent {

    var speed: CGFloat
    let minX: CGFloat
    let maxX: CGFloat

    init(speed: CGFloat, sceneWidth: CGFloat, spriteHalfWidth: CGFloat) {
        self.speed = speed
        self.minX = spriteHalfWidth
        self.maxX = sceneWidth - spriteHalfWidth
        super.init()
    }

    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    func move(toX targetX: CGFloat) {
        guard let spriteComp = entity?.component(ofType: SpriteComponent.self) else { return }
        spriteComp.node.position.x = max(minX, min(maxX, targetX))
    }
}
