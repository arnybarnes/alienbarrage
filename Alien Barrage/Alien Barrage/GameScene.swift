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

        // Phase 0 test: display several sprites to validate spritesheet extraction
        let sheet = SpriteSheet.shared
        let centerX = size.width / 2

        // Large alien - top center
        if let tex = sheet.sprite(named: "alienLarge1") {
            let sprite = SKSpriteNode(texture: tex)
            sprite.position = CGPoint(x: centerX, y: size.height - 120)
            sprite.zPosition = GameConstants.ZPosition.enemy
            addChild(sprite)
        }

        // Medium alien
        if let tex = sheet.sprite(named: "alienMedium1") {
            let sprite = SKSpriteNode(texture: tex)
            sprite.position = CGPoint(x: centerX - 80, y: size.height - 280)
            sprite.zPosition = GameConstants.ZPosition.enemy
            addChild(sprite)
        }

        // Small alien
        if let tex = sheet.sprite(named: "alienSmall1") {
            let sprite = SKSpriteNode(texture: tex)
            sprite.position = CGPoint(x: centerX + 80, y: size.height - 280)
            sprite.zPosition = GameConstants.ZPosition.enemy
            addChild(sprite)
        }

        // Player ship - center
        if let tex = sheet.sprite(named: "playerShip") {
            let sprite = SKSpriteNode(texture: tex)
            sprite.setScale(0.4)
            sprite.position = CGPoint(x: centerX, y: size.height / 2)
            sprite.zPosition = GameConstants.ZPosition.player
            addChild(sprite)
        }

        // Projectile
        if let tex = sheet.sprite(named: "playerBullet") {
            let sprite = SKSpriteNode(texture: tex)
            sprite.position = CGPoint(x: centerX, y: 200)
            sprite.zPosition = GameConstants.ZPosition.projectile
            addChild(sprite)
        }

        // UFO
        if let tex = sheet.sprite(named: "ufo") {
            let sprite = SKSpriteNode(texture: tex)
            sprite.setScale(0.35)
            sprite.position = CGPoint(x: centerX, y: 100)
            sprite.zPosition = GameConstants.ZPosition.ufo
            addChild(sprite)
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
