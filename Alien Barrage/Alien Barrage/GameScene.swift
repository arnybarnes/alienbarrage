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

    // UFO
    private var ufoEntity: UFOEntity?
    private var ufoSpawnTimer: TimeInterval = 0
    private var nextUfoSpawnInterval: TimeInterval = 0

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
        nextUfoSpawnInterval = randomUFOInterval()
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
        let config = LevelManager.config(forLevel: currentLevel)
        currentEnemyFireInterval = config.fireInterval
        let speedMultiplier = config.baseSpeed / GameConstants.alienBaseSpeed
        alienFormation = AlienFormation(
            rows: config.rows,
            cols: config.cols,
            sceneSize: size,
            speedMultiplier: speedMultiplier,
            alienHPBonus: config.alienHPBonus
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

        // Player bullet hits UFO
        if (maskA == GameConstants.PhysicsCategory.playerBullet && maskB == GameConstants.PhysicsCategory.ufo) ||
           (maskB == GameConstants.PhysicsCategory.playerBullet && maskA == GameConstants.PhysicsCategory.ufo) {
            let bulletBody = maskA == GameConstants.PhysicsCategory.playerBullet ? bodyA : bodyB
            let ufoBody = maskA == GameConstants.PhysicsCategory.ufo ? bodyA : bodyB
            handlePlayerBulletHitsUFO(bulletBody: bulletBody, ufoBody: ufoBody)
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

    private func handlePlayerBulletHitsUFO(bulletBody: SKPhysicsBody, ufoBody: SKPhysicsBody) {
        guard gameState == .playing else { return }
        guard let bulletNode = bulletBody.node as? SKSpriteNode,
              let ufoNode = ufoBody.node as? SKSpriteNode else { return }

        guard let ufo = ufoNode.userData?["entity"] as? UFOEntity else { return }

        let isDead = ufo.healthComponent.takeDamage(1)

        if isDead {
            let worldPos = ufoNode.position
            let scoreValue = ufo.scoreValueComponent.value
            ExplosionEffect.spawn(at: worldPos, in: self, scoreValue: scoreValue)
            scoreManager.addPoints(scoreValue)
            ufoNode.removeFromParent()
            ufoEntity = nil
        } else {
            let colorize = SKAction.colorize(with: .white, colorBlendFactor: 1.0, duration: 0.05)
            let restore = SKAction.colorize(withColorBlendFactor: 0.0, duration: 0.1)
            ufoNode.run(SKAction.sequence([colorize, restore]))
        }

        bulletNode.removeFromParent()
    }

    // MARK: - Player Death & Game Over

    private func handlePlayerDeath() {
        gameState = .gameOver
        playerEntity.shootingComponent.isFiring = false

        let playerPos = playerEntity.spriteComponent.node.position
        ExplosionEffect.spawn(at: playerPos, in: self, scoreValue: 0)
        playerEntity.spriteComponent.node.isHidden = true

        // Hide formation and remove lingering bullets/UFO
        alienFormation?.formationNode.isHidden = true
        removeUFO()
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

        let label = makeOverlayLabel(text: "GAME OVER", fontSize: 48)
        label.position = CGPoint(x: size.width / 2, y: size.height / 2)
        overlay.addChild(label)

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

        // Remove UFO if active
        removeUFO()

        // Reset state
        currentLevel = 1
        currentEnemyFireInterval = GameConstants.enemyFireInterval
        enemyFireTimer = 0
        ufoSpawnTimer = 0
        nextUfoSpawnInterval = randomUFOInterval()
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

        // Clean up UFO and lingering bullets
        removeUFO()
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

        let levelLabel = makeOverlayLabel(text: "LEVEL", fontSize: 48)
        levelLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 + 25)
        overlay.addChild(levelLabel)

        let numberLabel = makeOverlayLabel(text: "\(currentLevel)", fontSize: 56)
        numberLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 - 35)
        overlay.addChild(numberLabel)

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

        // Reset timers
        enemyFireTimer = 0
        ufoSpawnTimer = 0
        nextUfoSpawnInterval = randomUFOInterval()

        // Create new formation (setupAliens uses LevelManager)
        setupAliens()

        // Reset player position
        playerEntity.spriteComponent.node.position = CGPoint(x: size.width / 2, y: 80)

        gameState = .playing
    }

    // MARK: - UFO

    private func randomUFOInterval() -> TimeInterval {
        TimeInterval.random(in: GameConstants.ufoSpawnIntervalMin...GameConstants.ufoSpawnIntervalMax)
    }

    private func spawnUFO() {
        guard ufoEntity == nil else { return }

        let ufo = UFOEntity(sceneSize: size)
        addChild(ufo.spriteComponent.node)
        entities.append(ufo)
        ufoEntity = ufo
    }

    private func removeUFO() {
        ufoEntity?.spriteComponent.node.removeFromParent()
        ufoEntity = nil
    }

    // MARK: - UI Helpers

    private func makeOverlayLabel(text: String, fontSize: CGFloat) -> SKLabelNode {
        let label = SKLabelNode(fontNamed: "AvenirNext-HeavyItalic")
        label.text = text
        label.fontSize = fontSize
        label.fontColor = SKColor(red: 0.3, green: 0.85, blue: 0.3, alpha: 1.0)
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center

        // Shadow/outline effect via a duplicate label behind
        let shadow = SKLabelNode(fontNamed: "AvenirNext-HeavyItalic")
        shadow.text = text
        shadow.fontSize = fontSize
        shadow.fontColor = SKColor(red: 0.1, green: 0.3, blue: 0.1, alpha: 1.0)
        shadow.horizontalAlignmentMode = .center
        shadow.verticalAlignmentMode = .center
        shadow.position = CGPoint(x: 2, y: -2)
        shadow.zPosition = -1
        label.addChild(shadow)

        return label
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

            // UFO spawn timer
            ufoSpawnTimer += dt
            if ufoSpawnTimer >= nextUfoSpawnInterval {
                ufoSpawnTimer = 0
                nextUfoSpawnInterval = randomUFOInterval()
                spawnUFO()
            }

            // Track UFO removal (flew off-screen)
            if let ufo = ufoEntity, ufo.spriteComponent.node.parent == nil {
                ufoEntity = nil
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
