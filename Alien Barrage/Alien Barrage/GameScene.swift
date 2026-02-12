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

    // Player
    private var playerEntity: PlayerEntity!
    private var touchStartLocation: CGPoint?
    private var playerStartX: CGFloat = 0

    override func didMove(to view: SKView) {
        backgroundColor = .black
        physicsWorld.gravity = .zero

        // Sprite test grid — validate new spritesheet coordinates
        let sheet = SpriteSheet.shared
        let testSprites: [(name: String, x: CGFloat, y: CGFloat, scale: CGFloat)] = [
            ("alienLarge1",  65,  770, 0.6),
            ("alienLarge2", 195,  770, 0.6),
            ("alienLarge3", 325,  770, 0.6),
            ("alienMedium1", 65,  670, 0.55),
            ("alienMedium2",195,  670, 0.55),
            ("alienSmall1", 65,  590, 0.7),
            ("alienSmall2", 195,  590, 0.7),
            ("playerShip",  195,  440, 0.35),
            ("ufo",         195,  310, 0.18),
            ("playerBullet", 65,  310, 1.0),
            ("playerMissile",105,  310, 1.0),
            ("enemyBullet", 145,  310, 1.0),
            ("explosionGreen1", 325, 590, 0.4),
            ("explosionOrange1", 325, 670, 0.4),
            ("levelStart",  195,  200, 0.5),
            ("gameOver",    195,  150, 0.5),
            ("shield1",     65,  100, 0.6),
            ("powerupRapidFire", 175, 100, 0.8),
            ("plus100",     300,  100, 0.6),
        ]

        for item in testSprites {
            if let tex = sheet.sprite(named: item.name) {
                let sprite = SKSpriteNode(texture: tex)
                sprite.position = CGPoint(x: item.x, y: item.y)
                sprite.setScale(item.scale)
                sprite.zPosition = 10
                addChild(sprite)
            }
        }

        // Show digit row at the bottom
        for i in 0...9 {
            if let tex = sheet.digitTexture(i) {
                let digit = SKSpriteNode(texture: tex)
                digit.position = CGPoint(x: CGFloat(60 + i * 30), y: 40)
                digit.zPosition = 10
                addChild(digit)
            }
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

        // Clean up entities whose sprites have been removed from the scene
        entities.removeAll { entity in
            if let spriteComp = entity.component(ofType: SpriteComponent.self) {
                return spriteComp.node.parent == nil
            }
            return false
        }

        lastUpdateTime = currentTime
    }
}
