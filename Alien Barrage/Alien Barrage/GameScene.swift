//
//  GameScene.swift
//  Alien Barrage
//
//  Created by Arnold Biffna on 2/12/26.
//

import SpriteKit
import GameplayKit

class GameScene: SKScene {

    var entities = [GKEntity]()
    var graphs = [String: GKGraph]()

    private var lastUpdateTime: TimeInterval = 0

    override func didMove(to view: SKView) {
        backgroundColor = .black

        // Phase 0 test: display one sprite from the spritesheet, centered
        if let alienTexture = SpriteSheet.shared.sprite(named: "alienLarge1") {
            let testSprite = SKSpriteNode(texture: alienTexture)
            testSprite.position = CGPoint(x: size.width / 2, y: size.height / 2)
            testSprite.setScale(2.0)
            testSprite.zPosition = GameConstants.ZPosition.enemy
            addChild(testSprite)
        }
    }

    override func update(_ currentTime: TimeInterval) {
        if lastUpdateTime == 0 {
            lastUpdateTime = currentTime
        }

        let dt = currentTime - lastUpdateTime

        for entity in entities {
            entity.update(deltaTime: dt)
        }

        lastUpdateTime = currentTime
    }
}
