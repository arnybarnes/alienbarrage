//
//  SpriteComponent.swift
//  Alien Barrage
//

import SpriteKit
import GameplayKit

class SpriteComponent: GKComponent {

    let node: SKSpriteNode

    init(texture: SKTexture, size: CGSize) {
        node = SKSpriteNode(texture: texture, size: size)
        super.init()
    }

    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
}
