//
//  GameScene.swift
//  Alien Barrage
//
//  Created by Arnold Biffna on 2/12/26.
//

import SpriteKit
import GameplayKit

enum GameState {
    case playing
    case gameOver
    case levelTransition
}

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

    // Game state
    private var gameState: GameState = .playing
    private var currentLevel: Int = 1

    // Lives
    private var livesDisplay: LivesDisplay!

    // Enemy shooting
    private var enemyFireTimer: TimeInterval = 0
    private var currentEnemyFireInterval: TimeInterval = GameConstants.enemyFireInterval

    // Overlay
    private var overlayNode: SKNode?

    override func didMove(to view: SKView) {
        backgroundColor = .black
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self

        setupPlayer()
        setupAliens()
        setupScoreDisplay()
        setupLivesDisplay()
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
        let speedMultiplier: CGFloat = 1.0 + CGFloat(currentLevel - 1) * 0.15
        alienFormation = AlienFormation(
            rows: GameConstants.alienGridRows,
            cols: GameConstants.alienGridColumns,
            sceneSize: size,
            speedMultiplier: speedMultiplier
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

    private func setupLivesDisplay() {
        livesDisplay = LivesDisplay()
        addChild(livesDisplay.node)
        livesDisplay.update(lives: GameConstants.playerLives)
    }

    private func spawnPlayerBullet() {
        let playerPos = playerEntity.spriteComponent.node.position
        let bulletPos = CGPoint(x: playerPos.x, y: playerPos.y + PlayerEntity.shipSize.height / 2 + 5)

        let bullet = ProjectileEntity(position: bulletPos, sceneHeight: size.height)
        addChild(bullet.spriteComponent.node)
        entities.append(bullet)
    }

    // MARK: - Enemy Shooting

    private func spawnEnemyBullet() {
        guard gameState == .playing,
              let formation = alienFormation,
              !formation.allDestroyed else { return }

        // Collect columns that have alive aliens
        var shooterCandidates: [AlienEntity] = []
        for col in 0..<formation.cols {
            if let lowest = formation.lowestAlien(inColumn: col) {
                shooterCandidates.append(lowest)
            }
        }

        guard let shooter = shooterCandidates.randomElement() else { return }

        // Convert alien position to world coordinates
        let alienLocalPos = shooter.spriteComponent.node.position
        let worldPos = formation.formationNode.convert(alienLocalPos, to: self)
        let bulletPos = CGPoint(x: worldPos.x, y: worldPos.y - shooter.alienType.size.height / 2 - 5)

        let bullet = EnemyProjectileEntity(position: bulletPos, sceneHeight: size.height)
        addChild(bullet.spriteComponent.node)
        entities.append(bullet)
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if gameState == .gameOver {
            restartGame()
            return
        }
        guard gameState == .playing else { return }

        guard let touch = touches.first else { return }
        touchStartLocation = touch.location(in: self)
        playerStartX = playerEntity.spriteComponent.node.position.x
        playerEntity.shootingComponent.isFiring = true
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard gameState == .playing else { return }
        guard let touch = touches.first, let startLoc = touchStartLocation else { return }
        let currentLoc = touch.location(in: self)
        let deltaX = currentLoc.x - startLoc.x
        playerEntity.movementComponent.move(toX: playerStartX + deltaX)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard gameState == .playing else { return }
        touchStartLocation = nil
        playerEntity.shootingComponent.isFiring = false
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard gameState == .playing else { return }
        touchStartLocation = nil
        playerEntity.shootingComponent.isFiring = false
    }

    // MARK: - Physics Contact

    func didBegin(_ contact: SKPhysicsContact) {
        let (bodyA, bodyB) = (contact.bodyA, contact.bodyB)
        let maskA = bodyA.categoryBitMask
        let maskB = bodyB.categoryBitMask

        // Player bullet hits enemy
        if (maskA == GameConstants.PhysicsCategory.playerBullet && maskB == GameConstants.PhysicsCategory.enemy) ||
           (maskB == GameConstants.PhysicsCategory.playerBullet && maskA == GameConstants.PhysicsCategory.enemy) {
            let bulletBody = maskA == GameConstants.PhysicsCategory.playerBullet ? bodyA : bodyB
            let alienBody = maskA == GameConstants.PhysicsCategory.enemy ? bodyA : bodyB
            handlePlayerBulletHitsEnemy(bulletBody: bulletBody, alienBody: alienBody)
            return
        }

        // Enemy bullet hits player
        if (maskA == GameConstants.PhysicsCategory.enemyBullet && maskB == GameConstants.PhysicsCategory.player) ||
           (maskB == GameConstants.PhysicsCategory.enemyBullet && maskA == GameConstants.PhysicsCategory.player) {
            let bulletBody = maskA == GameConstants.PhysicsCategory.enemyBullet ? bodyA : bodyB
            let playerBody = maskA == GameConstants.PhysicsCategory.player ? bodyA : bodyB
            handleEnemyBulletHitsPlayer(bulletBody: bulletBody, playerBody: playerBody)
            return
        }
    }

    private func handlePlayerBulletHitsEnemy(bulletBody: SKPhysicsBody, alienBody: SKPhysicsBody) {
        guard gameState == .playing else { return }
        guard let bulletNode = bulletBody.node as? SKSpriteNode,
              let alienNode = alienBody.node as? SKSpriteNode else { return }

        guard let alienEntity = alienNode.userData?["entity"] as? AlienEntity else { return }

        let isDead = alienEntity.healthComponent.takeDamage(1)

        if isDead {
            let worldPos: CGPoint
            if let formationNode = alienNode.parent {
                worldPos = formationNode.convert(alienNode.position, to: self)
            } else {
                worldPos = alienNode.position
            }

            alienFormation?.removeAlien(row: alienEntity.row, col: alienEntity.col)

            let scoreValue = alienEntity.scoreValueComponent.value
            ExplosionEffect.spawn(at: worldPos, in: self, scoreValue: scoreValue)
            scoreManager.addPoints(scoreValue)
        } else {
            let colorize = SKAction.colorize(with: .white, colorBlendFactor: 1.0, duration: 0.05)
            let restore = SKAction.colorize(withColorBlendFactor: 0.0, duration: 0.1)
            alienNode.run(SKAction.sequence([colorize, restore]))
        }

        bulletNode.removeFromParent()
    }

    private func handleEnemyBulletHitsPlayer(bulletBody: SKPhysicsBody, playerBody: SKPhysicsBody) {
        guard let bulletNode = bulletBody.node else { return }

        // Remove the bullet
        bulletNode.removeFromParent()

        // Ignore if not playing or player is invulnerable
        guard gameState == .playing else { return }
        if playerEntity.isInvulnerable { return }

        let isDead = playerEntity.healthComponent.takeDamage(1)
        livesDisplay.update(lives: playerEntity.healthComponent.currentHP)

        if isDead {
            handlePlayerDeath()
        } else {
            playerEntity.makeInvulnerable(duration: GameConstants.playerInvulnerabilityDuration)
        }
    }

    // MARK: - Player Death & Game Over

    private func handlePlayerDeath() {
        gameState = .gameOver
        playerEntity.shootingComponent.isFiring = false

        let playerPos = playerEntity.spriteComponent.node.position
        ExplosionEffect.spawn(at: playerPos, in: self, scoreValue: 0)
        playerEntity.spriteComponent.node.isHidden = true

        // Hide formation and remove lingering bullets
        alienFormation?.formationNode.isHidden = true
        enumerateChildNodes(withName: "enemyBullet") { node, _ in
            node.removeFromParent()
        }
        enumerateChildNodes(withName: "playerBullet") { node, _ in
            node.removeFromParent()
        }

        let wait = SKAction.wait(forDuration: 1.0)
        let showOverlay = SKAction.run { [weak self] in
            self?.showGameOverOverlay()
        }
        run(SKAction.sequence([wait, showOverlay]))
    }

    private func showGameOverOverlay() {
        let overlay = SKNode()
        overlay.zPosition = GameConstants.ZPosition.overlay

        // Dimmed background (z=-1 so text renders on top)
        let bg = SKSpriteNode(color: SKColor(white: 0, alpha: 0.7), size: size)
        bg.position = CGPoint(x: size.width / 2, y: size.height / 2)
        bg.zPosition = -1
        overlay.addChild(bg)

        if let gameOverTexture = SpriteSheet.shared.sprite(named: "gameOver") {
            let gameOverSprite = SKSpriteNode(texture: gameOverTexture, size: CGSize(width: 300, height: 38))
            gameOverSprite.position = CGPoint(x: size.width / 2, y: size.height / 2)
            overlay.addChild(gameOverSprite)
        }

        addChild(overlay)
        overlayNode = overlay
    }

    // MARK: - Restart

    private func restartGame() {
        // Remove overlay
        overlayNode?.removeFromParent()
        overlayNode = nil

        // Remove all entity sprites and clear
        for entity in entities {
            if let spriteComp = entity.component(ofType: SpriteComponent.self) {
                spriteComp.node.removeFromParent()
            }
        }
        entities.removeAll()

        // Remove formation (unhide first in case it was hidden during game over)
        alienFormation?.formationNode.isHidden = false
        alienFormation?.formationNode.removeFromParent()
        alienFormation = nil

        // Reset state
        currentLevel = 1
        currentEnemyFireInterval = GameConstants.enemyFireInterval
        enemyFireTimer = 0
        gameState = .playing
        scoreManager.reset()

        // Re-setup
        setupPlayer()
        setupAliens()
        livesDisplay.update(lives: GameConstants.playerLives)
    }

    // MARK: - Level Progression

    private func checkLevelComplete() {
        guard gameState == .playing,
              let formation = alienFormation,
              formation.allDestroyed else { return }

        gameState = .levelTransition
        currentLevel += 1
        playerEntity.shootingComponent.isFiring = false

        // Clean up lingering bullets
        enumerateChildNodes(withName: "enemyBullet") { node, _ in
            node.removeFromParent()
        }
        enumerateChildNodes(withName: "playerBullet") { node, _ in
            node.removeFromParent()
        }

        showLevelOverlay()

        let wait = SKAction.wait(forDuration: 2.0)
        let startNext = SKAction.run { [weak self] in
            self?.startNextLevel()
        }
        run(SKAction.sequence([wait, startNext]))
    }

    private func showLevelOverlay() {
        let overlay = SKNode()
        overlay.zPosition = GameConstants.ZPosition.overlay

        // Semi-transparent background (z=-1 so text renders on top)
        let bg = SKSpriteNode(color: SKColor(white: 0, alpha: 0.5), size: size)
        bg.position = CGPoint(x: size.width / 2, y: size.height / 2)
        bg.zPosition = -1
        overlay.addChild(bg)

        // "LEVEL" text sprite centered (cropped from "LEVEL START")
        if let levelTexture = SpriteSheet.shared.sprite(named: "level") {
            let levelSprite = SKSpriteNode(texture: levelTexture, size: CGSize(width: 150, height: 44))
            levelSprite.position = CGPoint(x: size.width / 2, y: size.height / 2 + 30)
            overlay.addChild(levelSprite)
        }

        // Level number centered below the "LEVEL" text
        let digits = Array(String(currentLevel))
        let digitSize = CGSize(width: 26, height: 33)
        let spacing: CGFloat = 30.0
        let totalWidth = CGFloat(digits.count - 1) * spacing
        let startX = size.width / 2 - totalWidth / 2
        for (i, char) in digits.enumerated() {
            guard let digit = Int(String(char)),
                  let texture = SpriteSheet.shared.digitTexture(digit) else { continue }
            let digitNode = SKSpriteNode(texture: texture, size: digitSize)
            digitNode.position = CGPoint(x: startX + CGFloat(i) * spacing, y: size.height / 2 - 25)
            overlay.addChild(digitNode)
        }

        addChild(overlay)
        overlayNode = overlay
    }

    private func startNextLevel() {
        // Remove overlay
        overlayNode?.removeFromParent()
        overlayNode = nil

        // Remove old formation
        alienFormation?.formationNode.removeFromParent()
        alienFormation = nil

        // Update difficulty
        currentEnemyFireInterval = max(0.8, 2.0 - Double(currentLevel - 1) * 0.2)
        enemyFireTimer = 0

        // Create new formation with speed multiplier
        setupAliens()

        // Reset player position
        playerEntity.spriteComponent.node.position = CGPoint(x: size.width / 2, y: 80)

        gameState = .playing
    }

    // MARK: - Update

    override func update(_ currentTime: TimeInterval) {
        if lastUpdateTime == 0 {
            lastUpdateTime = currentTime
        }

        let dt = currentTime - lastUpdateTime

        if gameState == .playing {
            for entity in entities {
                entity.update(deltaTime: dt)
            }

            alienFormation?.update(deltaTime: dt)

            // Enemy fire timer
            enemyFireTimer += dt
            if enemyFireTimer >= currentEnemyFireInterval {
                enemyFireTimer = 0
                spawnEnemyBullet()
            }

            // Check level completion
            checkLevelComplete()
        }

        // Clean up entities whose sprites have been removed from the scene (runs in all states)
        entities.removeAll { entity in
            if let spriteComp = entity.component(ofType: SpriteComponent.self) {
                return spriteComp.node.parent == nil
            }
            return false
        }

        lastUpdateTime = currentTime
    }
}
