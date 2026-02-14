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
    let minY: CGFloat
    var maxY: CGFloat

    init(speed: CGFloat, sceneWidth: CGFloat, spriteHalfWidth: CGFloat,
         baseY: CGFloat, spriteHeight: CGFloat) {
        self.speed = speed
        self.minX = spriteHalfWidth
        self.maxX = sceneWidth - spriteHalfWidth
        self.minY = baseY
        self.maxY = baseY + spriteHeight  // initial cap; updated each frame from formation
        super.init()
    }

    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    func move(toX targetX: CGFloat) {
        guard let spriteComp = entity?.component(ofType: SpriteComponent.self) else { return }
        let clampedX = max(minX, min(maxX, targetX))
        spriteComp.node.position.x = clampedX.rounded()
    }

    func move(toX targetX: CGFloat, toY targetY: CGFloat) {
        guard let spriteComp = entity?.component(ofType: SpriteComponent.self) else { return }
        spriteComp.node.position.x = max(minX, min(maxX, targetX)).rounded()
        spriteComp.node.position.y = max(minY, min(maxY, targetY)).rounded()
    }
}
