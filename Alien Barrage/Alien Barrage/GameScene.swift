//
//  GameScene.swift
//  Alien Barrage
//
//  Created by Arnold Biffna on 2/12/26.
//

import SpriteKit
import GameplayKit

class GameScene: SKScene, SKPhysicsContactDelegate {

    var entities = [GKEntity]()
    var graphs = [String: GKGraph]()

    private var lastUpdateTime: TimeInterval = 0

    // Player
    private var playerEntity: PlayerEntity!
    private var touchStartLocation: CGPoint?
    private var playerStartX: CGFloat = 0

    // Aliens
    private var alienFormation: AlienFormation?

    // Scoring
    private let scoreManager = ScoreManager()
    private var scoreDisplay: ScoreDisplay!

    override func didMove(to view: SKView) {
        backgroundColor = .black
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self

        setupPlayer()
        setupAliens()
        setupScoreDisplay()
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

    private func setupScoreDisplay() {
        scoreDisplay = ScoreDisplay()
        addChild(scoreDisplay.node)

        scoreManager.onScoreChanged = { [weak self] score in
            self?.scoreDisplay.update(score: score)
        }
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

    // MARK: - Physics Contact

    func didBegin(_ contact: SKPhysicsContact) {
        let (bodyA, bodyB) = (contact.bodyA, contact.bodyB)

        // Identify which body is the bullet and which is the alien
        let bulletBody: SKPhysicsBody
        let alienBody: SKPhysicsBody

        if bodyA.categoryBitMask == GameConstants.PhysicsCategory.playerBullet &&
           bodyB.categoryBitMask == GameConstants.PhysicsCategory.enemy {
            bulletBody = bodyA
            alienBody = bodyB
        } else if bodyB.categoryBitMask == GameConstants.PhysicsCategory.playerBullet &&
                  bodyA.categoryBitMask == GameConstants.PhysicsCategory.enemy {
            bulletBody = bodyB
            alienBody = bodyA
        } else {
            return
        }

        guard let bulletNode = bulletBody.node as? SKSpriteNode,
              let alienNode = alienBody.node as? SKSpriteNode else { return }

        // Look up entities from userData
        guard let alienEntity = alienNode.userData?["entity"] as? AlienEntity else { return }

        // Apply damage
        let isDead = alienEntity.healthComponent.takeDamage(1)

        if isDead {
            // Get world position before removing
            let worldPos: CGPoint
            if let formationNode = alienNode.parent {
                worldPos = formationNode.convert(alienNode.position, to: self)
            } else {
                worldPos = alienNode.position
            }

            // Remove alien from formation
            alienFormation?.removeAlien(row: alienEntity.row, col: alienEntity.col)

            // Spawn explosion and score popup
            let scoreValue = alienEntity.scoreValueComponent.value
            ExplosionEffect.spawn(at: worldPos, in: self, scoreValue: scoreValue)
            scoreManager.addPoints(scoreValue)
        } else {
            // Still alive — flash white (large alien first hit)
            let colorize = SKAction.colorize(with: .white, colorBlendFactor: 1.0, duration: 0.05)
            let restore = SKAction.colorize(withColorBlendFactor: 0.0, duration: 0.1)
            alienNode.run(SKAction.sequence([colorize, restore]))
        }

        // Remove the bullet
        bulletNode.removeFromParent()
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
