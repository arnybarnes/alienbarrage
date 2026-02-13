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

    // Settings & callbacks
    private var settings: GameSettings?
    var onGameOver: ((Int) -> Void)?

    // World node — all gameplay objects are children of this (allows screen shake without shaking UI)
    private var worldNode: SKNode!

    // Player
    private var playerEntity: PlayerEntity!
    private var touchStartLocation: CGPoint?
    private var playerStartX: CGFloat = 0

    // Aliens
    private var alienFormation: AlienFormation?

    // Scoring
    private let scoreManager = ScoreManager()
    private var scoreDisplay: ScoreDisplay!
    var currentScore: Int { scoreManager.currentScore }

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

    // Shield barriers
    private var shieldBarriers: [ShieldBarrierEntity] = []

    // Overlay
    private var overlayNode: SKNode?

    convenience init(size: CGSize, settings: GameSettings) {
        self.init(size: size)
        self.settings = settings
    }

    override func didMove(to view: SKView) {
        backgroundColor = .black
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self

        // World node holds all gameplay objects
        worldNode = SKNode()
        addChild(worldNode)

        // Starfield background
        let starfield = ParticleEffects.createStarfield(sceneSize: size)
        addChild(starfield)

        setupPlayer()
        setupAliens()
        setupShieldBarriers()
        setupScoreDisplay()
        setupLivesDisplay()
        nextUfoSpawnInterval = randomUFOInterval()

        // Pause on background
        NotificationCenter.default.addObserver(
            self, selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification, object: nil
        )
    }

    @objc private func appWillResignActive() {
        if gameState == .playing {
            isPaused = true
        }
    }

    @objc private func appDidBecomeActive() {
        isPaused = false
    }

    // MARK: - Setup

    private func setupPlayer() {
        let lives = settings?.effectiveLives ?? GameConstants.playerLives
        let fireRate = settings?.effectiveFireRate ?? GameConstants.playerFireRate
        playerEntity = PlayerEntity(sceneSize: size, lives: lives, fireRate: fireRate)
        worldNode.addChild(playerEntity.spriteComponent.node)
        entities.append(playerEntity)

        playerEntity.shootingComponent.fireCallback = { [weak self] in
            self?.spawnPlayerBullet()
        }

        playerEntity.shootingComponent.isFiring = true
    }

    private func setupAliens() {
        let config = LevelManager.config(forLevel: currentLevel)
        let fireIntervalMult = settings?.effectiveEnemyFireIntervalMultiplier ?? 1.0
        currentEnemyFireInterval = config.fireInterval * fireIntervalMult
        let speedMult = settings?.effectiveAlienSpeedMultiplier ?? 1.0
        let speedMultiplier = (config.baseSpeed / GameConstants.alienBaseSpeed) * speedMult
        alienFormation = AlienFormation(
            rows: config.rows,
            cols: config.cols,
            sceneSize: size,
            speedMultiplier: speedMultiplier,
            alienHPBonus: config.alienHPBonus
        )
        worldNode.addChild(alienFormation!.formationNode)
    }

    private func setupScoreDisplay() {
        scoreDisplay = ScoreDisplay()
        addChild(scoreDisplay.node)  // UI stays on scene, not worldNode

        scoreManager.onScoreChanged = { [weak self] score in
            self?.scoreDisplay.update(score: score)
        }
    }

    private func setupLivesDisplay() {
        livesDisplay = LivesDisplay()
        addChild(livesDisplay.node)  // UI stays on scene, not worldNode
        let lives = settings?.effectiveLives ?? GameConstants.playerLives
        livesDisplay.update(lives: lives)
    }

    private func setupShieldBarriers() {
        // Remove any existing barriers
        for barrier in shieldBarriers {
            barrier.spriteComponent.node.removeFromParent()
        }
        shieldBarriers.removeAll()

        guard GameConstants.shieldBarriersEnabled else { return }

        let barrierCount = 4
        let spacing = size.width / CGFloat(barrierCount + 1)
        let yPosition: CGFloat = 200

        for i in 1...barrierCount {
            let xPos = spacing * CGFloat(i)
            let barrier = ShieldBarrierEntity(position: CGPoint(x: xPos, y: yPosition))
            worldNode.addChild(barrier.spriteComponent.node)
            entities.append(barrier)
            shieldBarriers.append(barrier)
        }
    }

    // MARK: - Bullet Spawning

    private func spawnPlayerBullet() {
        AudioManager.shared.play(GameConstants.Sound.playerShoot)
        HapticManager.shared.lightImpact()

        let playerPos = playerEntity.spriteComponent.node.position
        let baseY = playerPos.y + PlayerEntity.shipSize.height / 2 + 5

        if playerEntity.activePowerup == .spreadShot {
            // Fire 3 bullets in a fan pattern
            let angles: [CGFloat] = [-0.25, 0, 0.25]  // ~14 degrees
            for angle in angles {
                let bulletPos = CGPoint(x: playerPos.x, y: baseY)
                let bullet = ProjectileEntity(position: bulletPos, sceneHeight: size.height)
                let node = bullet.spriteComponent.node

                // Replace the default straight-up action with angled movement
                node.removeAllActions()
                let distance = size.height - bulletPos.y + ProjectileEntity.bulletSize.height
                let duration = TimeInterval(distance / GameConstants.playerBulletSpeed)
                let dx = sin(angle) * distance
                let move = SKAction.moveBy(x: dx, y: distance, duration: duration)
                let remove = SKAction.removeFromParent()
                node.run(SKAction.sequence([move, remove]))

                worldNode.addChild(node)
                entities.append(bullet)
            }
        } else {
            let bulletPos = CGPoint(x: playerPos.x, y: baseY)
            let bullet = ProjectileEntity(position: bulletPos, sceneHeight: size.height)
            worldNode.addChild(bullet.spriteComponent.node)
            entities.append(bullet)
        }
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
        let worldPos = formation.formationNode.convert(alienLocalPos, to: worldNode)
        let bulletPos = CGPoint(x: worldPos.x, y: worldPos.y - shooter.alienType.size.height / 2 - 5)

        let bullet = EnemyProjectileEntity(position: bulletPos, sceneHeight: size.height)
        worldNode.addChild(bullet.spriteComponent.node)
        entities.append(bullet)
    }

    // MARK: - Powerup Spawning

    private func spawnPowerup(at position: CGPoint) {
        let type = PowerupType.random()
        let powerup = PowerupEntity(type: type, position: position, sceneHeight: size.height)
        worldNode.addChild(powerup.spriteComponent.node)
        entities.append(powerup)
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if gameState == .gameOver {
            handleGameOverTap()
            return
        }
        guard gameState == .playing else { return }

        guard let touch = touches.first else { return }
        touchStartLocation = touch.location(in: self)
        playerStartX = playerEntity.spriteComponent.node.position.x
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
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard gameState == .playing else { return }
        touchStartLocation = nil
    }

    private func handleGameOverTap() {
        HighScoreManager.shared.submit(score: scoreManager.currentScore)
        if let callback = onGameOver {
            callback(scoreManager.currentScore)
        } else {
            restartGame()
        }
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

        // Player collects powerup
        if (maskA == GameConstants.PhysicsCategory.player && maskB == GameConstants.PhysicsCategory.powerup) ||
           (maskB == GameConstants.PhysicsCategory.player && maskA == GameConstants.PhysicsCategory.powerup) {
            let powerupBody = maskA == GameConstants.PhysicsCategory.powerup ? bodyA : bodyB
            handlePlayerCollectsPowerup(powerupBody: powerupBody)
            return
        }

        // Player bullet hits shield barrier
        if (maskA == GameConstants.PhysicsCategory.playerBullet && maskB == GameConstants.PhysicsCategory.shield) ||
           (maskB == GameConstants.PhysicsCategory.playerBullet && maskA == GameConstants.PhysicsCategory.shield) {
            let bulletBody = maskA == GameConstants.PhysicsCategory.playerBullet ? bodyA : bodyB
            let shieldBody = maskA == GameConstants.PhysicsCategory.shield ? bodyA : bodyB
            handleBulletHitsShield(bulletBody: bulletBody, shieldBody: shieldBody)
            return
        }

        // Enemy bullet hits shield barrier
        if (maskA == GameConstants.PhysicsCategory.enemyBullet && maskB == GameConstants.PhysicsCategory.shield) ||
           (maskB == GameConstants.PhysicsCategory.enemyBullet && maskA == GameConstants.PhysicsCategory.shield) {
            let bulletBody = maskA == GameConstants.PhysicsCategory.enemyBullet ? bodyA : bodyB
            let shieldBody = maskA == GameConstants.PhysicsCategory.shield ? bodyA : bodyB
            handleBulletHitsShield(bulletBody: bulletBody, shieldBody: shieldBody)
            return
        }
    }

    // MARK: - Collision Handlers

    private func handlePlayerBulletHitsEnemy(bulletBody: SKPhysicsBody, alienBody: SKPhysicsBody) {
        guard gameState == .playing else { return }
        guard let bulletNode = bulletBody.node as? SKSpriteNode,
              let alienNode = alienBody.node as? SKSpriteNode else { return }

        guard let alienEntity = alienNode.userData?["entity"] as? AlienEntity else { return }

        let isDead = alienEntity.healthComponent.takeDamage(1)

        // Spark effect at impact
        let impactPos: CGPoint
        if let formationNode = alienNode.parent {
            impactPos = formationNode.convert(alienNode.position, to: worldNode)
        } else {
            impactPos = alienNode.position
        }
        ParticleEffects.spawnSparkBurst(at: impactPos, in: worldNode.scene!)

        if isDead {
            AudioManager.shared.play(GameConstants.Sound.enemyDeath)
            HapticManager.shared.mediumImpact()

            alienFormation?.removeAlien(row: alienEntity.row, col: alienEntity.col)

            let scoreValue = alienEntity.scoreValueComponent.value
            ExplosionEffect.spawn(at: impactPos, in: self, scoreValue: scoreValue)
            scoreManager.addPoints(scoreValue)

            // Chance to drop powerup
            if Double.random(in: 0...1) < GameConstants.powerupDropChance {
                spawnPowerup(at: impactPos)
            }
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

        // Shield powerup absorbs the hit
        if playerEntity.hasShield {
            AudioManager.shared.play(GameConstants.Sound.shieldHit)
            playerEntity.clearPowerup()
            return
        }

        AudioManager.shared.play(GameConstants.Sound.playerHit)
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

        // Spark effect
        ParticleEffects.spawnSparkBurst(at: ufoNode.position, in: self)

        let isDead = ufo.healthComponent.takeDamage(1)

        if isDead {
            AudioManager.shared.play(GameConstants.Sound.ufoDestroyed)
            HapticManager.shared.mediumImpact()

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

    private func handlePlayerCollectsPowerup(powerupBody: SKPhysicsBody) {
        guard gameState == .playing else { return }
        guard let powerupNode = powerupBody.node as? SKSpriteNode,
              let powerup = powerupNode.userData?["entity"] as? PowerupEntity else { return }

        AudioManager.shared.play(GameConstants.Sound.powerupCollect)
        HapticManager.shared.mediumImpact()

        playerEntity.applyPowerup(powerup.type)

        // Update lives display if extra life
        if powerup.type == .extraLife {
            livesDisplay.update(lives: playerEntity.healthComponent.currentHP)
        }

        // Collection effect
        let pulse = SKAction.group([
            SKAction.scale(to: 1.5, duration: 0.1),
            SKAction.fadeOut(withDuration: 0.15)
        ])
        let remove = SKAction.removeFromParent()
        powerupNode.run(SKAction.sequence([pulse, remove]))
    }

    private func handleBulletHitsShield(bulletBody: SKPhysicsBody, shieldBody: SKPhysicsBody) {
        guard let bulletNode = bulletBody.node,
              let shieldNode = shieldBody.node as? SKSpriteNode,
              let barrier = shieldNode.userData?["entity"] as? ShieldBarrierEntity else { return }

        AudioManager.shared.play(GameConstants.Sound.shieldHit)

        // Spark effect at impact
        ParticleEffects.spawnSparkBurst(at: bulletNode.position, in: self)

        let isDead = barrier.healthComponent.takeDamage(1)

        if isDead {
            shieldNode.removeFromParent()
            shieldBarriers.removeAll { $0 === barrier }
        } else {
            barrier.updateVisual()

            // Flash effect
            let flash = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.3, duration: 0.05),
                SKAction.fadeAlpha(to: CGFloat(barrier.healthComponent.currentHP) / CGFloat(barrier.healthComponent.maxHP) * 0.6 + 0.4, duration: 0.05)
            ])
            shieldNode.run(flash)
        }

        bulletNode.removeFromParent()
    }

    // MARK: - Player Death & Game Over

    private func handlePlayerDeath() {
        gameState = .gameOver
        playerEntity.shootingComponent.isFiring = false
        playerEntity.clearPowerup()

        AudioManager.shared.play(GameConstants.Sound.playerDeath)
        HapticManager.shared.heavyImpact()

        let playerPos = playerEntity.spriteComponent.node.position
        ExplosionEffect.spawn(at: playerPos, in: self, scoreValue: 0)
        playerEntity.spriteComponent.node.isHidden = true

        // Screen shake
        ScreenShakeEffect.shake(node: worldNode, duration: 0.6, intensity: 12)

        // Hide formation and remove lingering bullets/UFO/powerups
        alienFormation?.formationNode.isHidden = true
        removeUFO()
        worldNode.enumerateChildNodes(withName: "enemyBullet") { node, _ in
            node.removeFromParent()
        }
        worldNode.enumerateChildNodes(withName: "playerBullet") { node, _ in
            node.removeFromParent()
        }
        worldNode.enumerateChildNodes(withName: "powerup") { node, _ in
            node.removeFromParent()
        }

        let wait = SKAction.wait(forDuration: 1.0)
        let showOverlay = SKAction.run { [weak self] in
            self?.showGameOverOverlay()
        }
        run(SKAction.sequence([wait, showOverlay]))
    }

    private func showGameOverOverlay() {
        AudioManager.shared.play(GameConstants.Sound.gameOver)
        HapticManager.shared.error()

        // Submit score
        let isNewHigh = scoreManager.currentScore > 0 &&
                        scoreManager.currentScore > HighScoreManager.shared.highScore
        HighScoreManager.shared.submit(score: scoreManager.currentScore)

        let overlay = SKNode()
        overlay.zPosition = GameConstants.ZPosition.overlay

        // Dimmed background (z=-1 so text renders on top)
        let bg = SKSpriteNode(color: SKColor(white: 0, alpha: 0.7), size: size)
        bg.position = CGPoint(x: size.width / 2, y: size.height / 2)
        bg.zPosition = -1
        overlay.addChild(bg)

        let label = makeOverlayLabel(text: "GAME OVER", fontSize: 48)
        label.position = CGPoint(x: size.width / 2, y: size.height / 2 + 40)
        overlay.addChild(label)

        let scoreLabel = makeOverlayLabel(text: "SCORE: \(scoreManager.currentScore)", fontSize: 28)
        scoreLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 - 20)
        overlay.addChild(scoreLabel)

        if isNewHigh {
            let highLabel = makeOverlayLabel(text: "NEW HIGH SCORE!", fontSize: 22)
            highLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 - 60)
            overlay.addChild(highLabel)
        }

        let tapLabel = makeOverlayLabel(text: "TAP TO CONTINUE", fontSize: 20)
        tapLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 - 110)
        tapLabel.alpha = 0.6
        tapLabel.run(SKAction.repeatForever(
            SKAction.sequence([
                SKAction.fadeAlpha(to: 1.0, duration: 0.8),
                SKAction.fadeAlpha(to: 0.4, duration: 0.8)
            ])
        ))
        overlay.addChild(tapLabel)

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
        shieldBarriers.removeAll()

        // Remove formation (unhide first in case it was hidden during game over)
        alienFormation?.formationNode.isHidden = false
        alienFormation?.formationNode.removeFromParent()
        alienFormation = nil

        // Remove UFO if active
        removeUFO()

        // Remove any lingering powerup nodes
        worldNode.enumerateChildNodes(withName: "powerup") { node, _ in
            node.removeFromParent()
        }

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
        setupShieldBarriers()
        let lives = settings?.effectiveLives ?? GameConstants.playerLives
        livesDisplay.update(lives: lives)
    }

    // MARK: - Level Progression

    private func checkAliensReachedBottom() {
        guard gameState == .playing,
              let formation = alienFormation,
              let lowestY = formation.lowestAlienY() else { return }

        let playerY = playerEntity.spriteComponent.node.position.y
        if lowestY <= playerY {
            handlePlayerDeath()
        }
    }

    private func checkLevelComplete() {
        guard gameState == .playing,
              let formation = alienFormation,
              formation.allDestroyed else { return }

        gameState = .levelTransition
        currentLevel += 1
        playerEntity.shootingComponent.isFiring = false
        playerEntity.clearPowerup()

        // Clean up UFO, lingering bullets, and powerups
        removeUFO()
        worldNode.enumerateChildNodes(withName: "enemyBullet") { node, _ in
            node.removeFromParent()
        }
        worldNode.enumerateChildNodes(withName: "playerBullet") { node, _ in
            node.removeFromParent()
        }
        worldNode.enumerateChildNodes(withName: "powerup") { node, _ in
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
        AudioManager.shared.play(GameConstants.Sound.levelStart)
        HapticManager.shared.success()

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

        // Respawn shield barriers
        setupShieldBarriers()

        // Reset player position
        playerEntity.spriteComponent.node.position = CGPoint(x: size.width / 2, y: 80)

        gameState = .playing

        playerEntity.shootingComponent.isFiring = true
    }

    // MARK: - UFO

    private func randomUFOInterval() -> TimeInterval {
        TimeInterval.random(in: GameConstants.ufoSpawnIntervalMin...GameConstants.ufoSpawnIntervalMax)
    }

    private func spawnUFO() {
        guard ufoEntity == nil else { return }

        AudioManager.shared.play(GameConstants.Sound.ufoAppear)

        let ufo = UFOEntity(sceneSize: size)
        worldNode.addChild(ufo.spriteComponent.node)
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

            // Check if aliens reached the bottom (instant game over)
            checkAliensReachedBottom()

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
