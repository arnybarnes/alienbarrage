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

    // Aliens
    private var alienFormation: AlienFormation?

    override func didMove(to view: SKView) {
        backgroundColor = .black
        physicsWorld.gravity = .zero

        setupPlayer()
        setupAliens()
    }

    // MARK: - Setup

    private func setupPlayer() {
        playerEntity = PlayerEntity(sceneSize: size)
        addChild(playerEntity.spriteComponent.node)
        entities.append(playerEntity)

        playerEntity.shootingComponent.fireCallback = { [weak self] in
            self?.spawnPlayerBullet()
        }
    }

    private func setupAliens() {
        alienFormation = AlienFormation(
            rows: GameConstants.alienGridRows,
            cols: GameConstants.alienGridColumns,
            sceneSize: size
        )
        addChild(alienFormation!.formationNode)
    }

    private func spawnPlayerBullet() {
        let playerPos = playerEntity.spriteComponent.node.position
        let bulletPos = CGPoint(x: playerPos.x, y: playerPos.y + PlayerEntity.shipSize.height / 2 + 5)

        let bullet = ProjectileEntity(position: bulletPos, sceneHeight: size.height)
        addChild(bullet.spriteComponent.node)
        entities.append(bullet)
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        touchStartLocation = touch.location(in: self)
        playerStartX = playerEntity.spriteComponent.node.position.x
        playerEntity.shootingComponent.isFiring = true
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let startLoc = touchStartLocation else { return }
        let currentLoc = touch.location(in: self)
        let deltaX = currentLoc.x - startLoc.x
        playerEntity.movementComponent.move(toX: playerStartX + deltaX)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchStartLocation = nil
        playerEntity.shootingComponent.isFiring = false
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchStartLocation = nil
        playerEntity.shootingComponent.isFiring = false
    }

    // MARK: - Update

    override func update(_ currentTime: TimeInterval) {
        if lastUpdateTime == 0 {
            lastUpdateTime = currentTime
        }

        let dt = currentTime - lastUpdateTime

        for entity in entities {
            entity.update(deltaTime: dt)
        }

        alienFormation?.update(deltaTime: dt)

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
