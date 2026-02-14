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
    private var playerStartY: CGFloat = 0

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

    // Swooping aliens
    private var swoopingAliens: [AlienEntity] = []
    private var swoopTimer: TimeInterval = 0
    private var currentSwoopInterval: TimeInterval = GameConstants.swoopBaseInterval
    private var maxSimultaneousSwoops: Int = 1

    // Difficulty scaling for wider screens (more columns)
    private var columnDifficultyRatio: Double = 1.0

    // Respawn state — pauses enemy attacks during glitch-in animation
    private var isRespawning: Bool = false

    // Overlay
    private var overlayNode: SKNode?

    var safeAreaInsets: UIEdgeInsets = .zero

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

        scoreManager.scoreMultiplier = settings?.scoreMultiplier ?? 1.0
        setupPlayer()
        setupAliens()
        setupScoreDisplay()
        setupLivesDisplay()
        nextUfoSpawnInterval = randomUFOInterval()

        // Animate first level entrance
        playerEntity.shootingComponent.isFiring = false
        gameState = .levelTransition
        alienFormation?.animateEntrance { [weak self] in
            self?.gameState = .playing
        }

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
        let speedMult = settings?.effectiveAlienSpeedMultiplier ?? 1.0
        let speedMultiplier = (config.baseSpeed / GameConstants.alienBaseSpeed) * speedMult

        // Bonus columns on wider screens (iPad, Plus models)
        let bonusCols = max(0, Int((size.width - 390) / 130))
        let totalCols = config.cols + bonusCols

        // Difficulty scaling: more columns = slower fire/swoop to keep bullet density consistent
        let colRatio = CGFloat(totalCols) / CGFloat(config.cols)
        columnDifficultyRatio = Double(colRatio)

        currentEnemyFireInterval = config.fireInterval * fireIntervalMult * Double(colRatio)

        alienFormation = AlienFormation(
            rows: config.rows,
            cols: totalCols,
            sceneSize: size,
            speedMultiplier: speedMultiplier,
            alienHPBonus: config.alienHPBonus
        )
        worldNode.addChild(alienFormation!.formationNode)

        // Swoop config — scale interval and max count by level + difficulty
        let difficultyMult = settings?.effectiveAlienSpeedMultiplier ?? 1.0
        maxSimultaneousSwoops = config.maxSimultaneousSwoops
        currentSwoopInterval = max(
            GameConstants.swoopMinInterval,
            GameConstants.swoopBaseInterval - Double(currentLevel - 1) * GameConstants.swoopIntervalDecreasePerLevel
        ) / difficultyMult * Double(colRatio)
        swoopTimer = 0
    }

    private func setupScoreDisplay() {
        scoreDisplay = ScoreDisplay(bottomInset: safeAreaInsets.bottom)
        addChild(scoreDisplay.node)  // UI stays on scene, not worldNode

        scoreManager.onScoreChanged = { [weak self] score in
            self?.scoreDisplay.update(score: score)
        }
    }

    private func setupLivesDisplay() {
        livesDisplay = LivesDisplay(bottomInset: safeAreaInsets.bottom)
        addChild(livesDisplay.node)  // UI stays on scene, not worldNode
        let lives = settings?.effectiveLives ?? GameConstants.playerLives
        livesDisplay.update(lives: lives)
    }

    // MARK: - Bullet Spawning

    private func spawnPlayerBullet() {
        guard !isRespawning else { return }
        AudioManager.shared.play(GameConstants.Sound.playerShoot)
        if GameConstants.Haptic.playerShoot { HapticManager.shared.lightImpact() }

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
        var type = PowerupType.random()
        if type == .extraLife && playerEntity.healthComponent.currentHP >= GameConstants.playerMaxLivesForExtraLife {
            // Re-roll once to avoid extra life when player is at max ships
            type = PowerupType.allCases.filter { $0 != .extraLife }.randomElement()!
        }
        let powerup = PowerupEntity(type: type, position: position, sceneHeight: size.height)
        worldNode.addChild(powerup.spriteComponent.node)
        entities.append(powerup)
    }

    // MARK: - Alien Swooping

    private func buildSwoopPath(from start: CGPoint, playerX: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: start)

        // Determine which side to curve away from — opposite to player
        let wr = GameConstants.widthRatio
        let hr = GameConstants.heightRatio
        let offsetDir: CGFloat = start.x < size.width / 2 ? -1 : 1
        let lateralSwing = CGFloat.random(in: 60...120) * wr * offsetDir

        // Control point 1: curve outward from center
        let cp1 = CGPoint(
            x: start.x + lateralSwing,
            y: start.y - CGFloat.random(in: 80...160) * hr
        )
        // Control point 2: sweep toward player
        let cp2 = CGPoint(
            x: playerX + CGFloat.random(in: -30...30) * wr,
            y: CGFloat.random(in: 100...200) * hr
        )
        // End point: below screen
        let end = CGPoint(
            x: playerX + CGFloat.random(in: -20...20) * wr,
            y: GameConstants.swoopDestroyBelowY
        )

        path.addCurve(to: end, control1: cp1, control2: cp2)
        return path
    }

    private func initiateSwoop() {
        guard let formation = alienFormation,
              formation.aliveCount > 0,
              swoopingAliens.count < maxSimultaneousSwoops else { return }

        guard let (alien, _) = formation.extractRandomSwooper(into: worldNode) else { return }

        swoopingAliens.append(alien)

        let node = alien.spriteComponent.node

        // Update physics so swooper can contact the player
        node.physicsBody?.contactTestBitMask |= GameConstants.PhysicsCategory.player
        node.physicsBody?.isDynamic = true
        node.physicsBody?.affectedByGravity = false

        // Build path and calculate duration from speed
        let playerX = playerEntity.spriteComponent.node.position.x
        let swoopPath = buildSwoopPath(from: node.position, playerX: playerX)

        // Approximate path length for duration
        let boundingBox = swoopPath.boundingBox
        let approxLength = hypot(boundingBox.width, boundingBox.height) * 1.4
        let swoopSpeed = GameConstants.swoopSpeed * GameConstants.heightRatio
        let duration = TimeInterval(approxLength / swoopSpeed)

        let follow = SKAction.follow(swoopPath, asOffset: false, orientToPath: false, duration: duration)
        follow.timingMode = .easeIn

        // Add a wobble rotation during flight
        let wobble = SKAction.repeatForever(
            SKAction.sequence([
                SKAction.rotate(byAngle: .pi / 12, duration: 0.15),
                SKAction.rotate(byAngle: -.pi / 6, duration: 0.3),
                SKAction.rotate(byAngle: .pi / 12, duration: 0.15)
            ])
        )

        // Run wobble separately (repeatForever would block a group from completing)
        node.run(wobble, withKey: "swoopWobble")

        let cleanup = SKAction.run { [weak self, weak alien] in
            guard let self, let alien else { return }
            self.destroySwoopingAlien(alien, hitPlayer: false)
        }
        node.run(SKAction.sequence([follow, cleanup]), withKey: "swoopPath")
    }

    private func destroySwoopingAlien(_ alien: AlienEntity, hitPlayer: Bool) {
        guard alien.isAlive else {
            // Already dead — still clean up tracking in case of stale entries
            swoopingAliens.removeAll { $0 === alien }
            return
        }

        alien.isAlive = false
        alien.isSwooping = false
        let node = alien.spriteComponent.node
        node.removeAllActions()

        if hitPlayer {
            // Explosion on player contact
            ExplosionEffect.spawn(at: node.position, in: self, scoreValue: 0)
        }
        // No explosion and no score if it just flew off-screen

        node.removeFromParent()
        swoopingAliens.removeAll { $0 === alien }
        alienFormation?.swooperDestroyed()
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if gameState == .gameOver {
            guard let touch = touches.first else { return }
            let location = touch.location(in: self)
            let tappedNodes = nodes(at: location)
            if tappedNodes.contains(where: { $0.name == "continueButton" }) {
                handleGameOverTap()
            }
            return
        }
        guard gameState == .playing || gameState == .levelTransition else { return }

        guard let touch = touches.first else { return }
        touchStartLocation = touch.location(in: self)
        playerStartX = playerEntity.spriteComponent.node.position.x
        playerStartY = playerEntity.spriteComponent.node.position.y
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard gameState == .playing || gameState == .levelTransition else { return }
        guard let touch = touches.first, let startLoc = touchStartLocation else { return }
        let currentLoc = touch.location(in: self)
        let deltaX = currentLoc.x - startLoc.x
        let deltaY = currentLoc.y - startLoc.y
        playerEntity.movementComponent.move(toX: playerStartX + deltaX, toY: playerStartY + deltaY)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard gameState == .playing || gameState == .levelTransition else { return }
        touchStartLocation = nil
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard gameState == .playing || gameState == .levelTransition else { return }
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

        // Swooping alien hits player
        if (maskA == GameConstants.PhysicsCategory.enemy && maskB == GameConstants.PhysicsCategory.player) ||
           (maskB == GameConstants.PhysicsCategory.enemy && maskA == GameConstants.PhysicsCategory.player) {
            let alienBody = maskA == GameConstants.PhysicsCategory.enemy ? bodyA : bodyB
            handleSwooperHitsPlayer(alienBody: alienBody)
            return
        }

    }

    // MARK: - Collision Handlers

    private func handlePlayerBulletHitsEnemy(bulletBody: SKPhysicsBody, alienBody: SKPhysicsBody) {
        guard gameState == .playing else { return }
        guard let bulletNode = bulletBody.node as? SKSpriteNode,
              let alienNode = alienBody.node as? SKSpriteNode else { return }

        guard let alienEntity = alienNode.userData?["entity"] as? AlienEntity else { return }

        // Spark effect at impact — swooping aliens are already in world coords
        let impactPos: CGPoint
        if alienEntity.isSwooping {
            impactPos = alienNode.position
        } else if let formationNode = alienNode.parent {
            impactPos = formationNode.convert(alienNode.position, to: worldNode)
        } else {
            impactPos = alienNode.position
        }

        // All aliens die in one hit
        let isDead = alienEntity.healthComponent.takeDamage(alienEntity.healthComponent.currentHP)
        ParticleEffects.spawnSparkBurst(at: impactPos, in: worldNode.scene!)

        if isDead {
            AudioManager.shared.play(GameConstants.Sound.enemyDeath)
            if GameConstants.Haptic.alienKilled { HapticManager.shared.mediumImpact() }

            if alienEntity.isSwooping {
                // Swooper: clean up directly (already removed from grid)
                let scoreValue = alienEntity.scoreValueComponent.value
                ExplosionEffect.spawn(at: impactPos, in: self, scoreValue: scoreManager.scaledValue(scoreValue))
                scoreManager.addPoints(scoreValue)

                if Double.random(in: 0...1) < GameConstants.powerupDropChance * (1.0 + (columnDifficultyRatio - 1.0) * 0.75) {
                    spawnPowerup(at: impactPos)
                }

                alienEntity.isAlive = false
                alienEntity.isSwooping = false
                alienNode.removeAllActions()
                alienNode.removeFromParent()
                swoopingAliens.removeAll { $0 === alienEntity }
                alienFormation?.swooperDestroyed()
            } else {
                alienFormation?.removeAlien(row: alienEntity.row, col: alienEntity.col)

                let scoreValue = alienEntity.scoreValueComponent.value
                ExplosionEffect.spawn(at: impactPos, in: self, scoreValue: scoreManager.scaledValue(scoreValue))
                scoreManager.addPoints(scoreValue)

                // Chance to drop powerup
                if Double.random(in: 0...1) < GameConstants.powerupDropChance * (1.0 + (columnDifficultyRatio - 1.0) * 0.75) {
                    spawnPowerup(at: impactPos)
                }
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
            playerEntity.clearPowerup()
            return
        }

        AudioManager.shared.play(GameConstants.Sound.playerHit)
        let isDead = playerEntity.healthComponent.takeDamage(1)
        livesDisplay.update(lives: playerEntity.healthComponent.currentHP)

        if isDead {
            handlePlayerDeath()
        } else {
            respawnPlayer()
        }
    }

    private func handlePlayerBulletHitsUFO(bulletBody: SKPhysicsBody, ufoBody: SKPhysicsBody) {
        guard gameState == .playing || gameState == .levelTransition else { return }
        guard let bulletNode = bulletBody.node as? SKSpriteNode,
              let ufoNode = ufoBody.node as? SKSpriteNode else { return }

        guard let ufo = ufoNode.userData?["entity"] as? UFOEntity else { return }

        // Spark effect
        ParticleEffects.spawnSparkBurst(at: ufoNode.position, in: self)

        let isDead = ufo.healthComponent.takeDamage(1)

        if isDead {
            AudioManager.shared.play(GameConstants.Sound.ufoDestroyed)
            if GameConstants.Haptic.ufoDestroyed { HapticManager.shared.mediumImpact() }

            let worldPos = ufoNode.position
            let scoreValue = ufo.scoreValueComponent.value
            ExplosionEffect.spawn(at: worldPos, in: self, scoreValue: scoreManager.scaledValue(scoreValue))
            scoreManager.addPoints(scoreValue)
            ufoNode.removeFromParent()
            ufoEntity = nil
        } else {
            let blink = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.2, duration: 0.05),
                SKAction.fadeAlpha(to: 1.0, duration: 0.1)
            ])
            ufoNode.run(blink)
        }

        bulletNode.removeFromParent()
    }

    private func handlePlayerCollectsPowerup(powerupBody: SKPhysicsBody) {
        guard gameState == .playing || gameState == .levelTransition else { return }
        guard let powerupNode = powerupBody.node as? SKSpriteNode,
              let powerup = powerupNode.userData?["entity"] as? PowerupEntity else { return }

        AudioManager.shared.play(GameConstants.Sound.powerupCollect)
        if GameConstants.Haptic.powerupCollected { HapticManager.shared.mediumImpact() }

        playerEntity.applyPowerup(powerup.type)

        // Update lives display if extra life + flash message
        if powerup.type == .extraLife {
            livesDisplay.update(lives: playerEntity.healthComponent.currentHP)
            flashExtraLifeMessage()
        }

        // Score
        let scoreValue = GameConstants.powerupCollectScore
        scoreManager.addPoints(scoreValue)
        ExplosionEffect.spawnScorePopup(at: powerupNode.position, in: self, scoreValue: scoreManager.scaledValue(scoreValue))

        // Collection effect
        let pulse = SKAction.group([
            SKAction.scale(to: 1.5, duration: 0.1),
            SKAction.fadeOut(withDuration: 0.15)
        ])
        let remove = SKAction.removeFromParent()
        powerupNode.run(SKAction.sequence([pulse, remove]))
    }

    private func handleSwooperHitsPlayer(alienBody: SKPhysicsBody) {
        guard gameState == .playing else { return }
        guard let alienNode = alienBody.node as? SKSpriteNode,
              let alienEntity = alienNode.userData?["entity"] as? AlienEntity,
              alienEntity.isSwooping, alienEntity.isAlive else { return }

        // Destroy the swooper with explosion
        destroySwoopingAlien(alienEntity, hitPlayer: true)

        // Damage the player
        if playerEntity.isInvulnerable { return }

        if playerEntity.hasShield {
            playerEntity.clearPowerup()
            ScreenShakeEffect.shake(node: worldNode, duration: 0.3, intensity: 6)
            return
        }

        AudioManager.shared.play(GameConstants.Sound.playerHit)
        let isDead = playerEntity.healthComponent.takeDamage(1)
        livesDisplay.update(lives: playerEntity.healthComponent.currentHP)
        ScreenShakeEffect.shake(node: worldNode, duration: 0.4, intensity: 8)

        if isDead {
            handlePlayerDeath()
        } else {
            respawnPlayer()
        }
    }

    // MARK: - Player Death & Game Over

    private func handlePlayerDeath() {
        gameState = .gameOver
        playerEntity.shootingComponent.isFiring = false
        playerEntity.clearPowerup()

        AudioManager.shared.play(GameConstants.Sound.playerDeath)
        if GameConstants.Haptic.playerDeath { HapticManager.shared.heavyImpact() }

        let playerPos = playerEntity.spriteComponent.node.position
        ExplosionEffect.spawn(at: playerPos, in: self, scoreValue: 0)
        playerEntity.spriteComponent.node.isHidden = true

        // Screen shake
        ScreenShakeEffect.shake(node: worldNode, duration: 0.6, intensity: 12)

        // After explosion settles, freeze everything and show game over
        let wait = SKAction.wait(forDuration: 1.0)
        let freezeAndShow = SKAction.run { [weak self] in
            guard let self else { return }
            self.worldNode.isPaused = true
            self.showGameOverOverlay()
        }
        run(SKAction.sequence([wait, freezeAndShow]))
    }

    private func showGameOverOverlay() {
        AudioManager.shared.play(GameConstants.Sound.gameOver)
        if GameConstants.Haptic.gameOver { HapticManager.shared.error() }

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

        let hs = GameConstants.hudScale

        let label = makeOverlayLabel(text: "GAME OVER", fontSize: 48)
        label.position = CGPoint(x: size.width / 2, y: size.height / 2 + 40 * hs)
        overlay.addChild(label)

        let scoreLabel = makeOverlayLabel(text: "SCORE: \(scoreManager.currentScore)", fontSize: 28)
        scoreLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 - 20 * hs)
        overlay.addChild(scoreLabel)

        if isNewHigh {
            let highLabel = makeOverlayLabel(text: "NEW HIGH SCORE!", fontSize: 22)
            highLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 - 60 * hs)
            overlay.addChild(highLabel)
        }
        let btnW = 250 * hs
        let btnH = 50 * hs
        let btnRect = CGRect(x: -btnW / 2, y: -btnH / 2, width: btnW, height: btnH)
        let btnPath = UIBezierPath(roundedRect: btnRect, cornerRadius: 8 * hs)
        let button = SKShapeNode(path: btnPath.cgPath)
        button.strokeColor = SKColor.green.withAlphaComponent(0.5)
        button.lineWidth = 1
        button.fillColor = SKColor.green.withAlphaComponent(0.08)
        button.position = CGPoint(x: size.width / 2, y: size.height / 2 - 110 * hs)
        button.name = "continueButton"

        let buttonLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        buttonLabel.text = "MENU"
        buttonLabel.fontSize = 20 * hs
        buttonLabel.fontColor = .green
        buttonLabel.verticalAlignmentMode = .center
        buttonLabel.horizontalAlignmentMode = .center
        buttonLabel.name = "continueButton"
        button.addChild(buttonLabel)

        overlay.addChild(button)

        addChild(overlay)
        overlayNode = overlay
    }

    // MARK: - Respawn (hit but not dead)

    private func respawnPlayer() {
        isRespawning = true
        playerEntity.shootingComponent.isFiring = false
        playerEntity.spriteComponent.node.alpha = 0

        // Clear all bullets, powerups, and swooping aliens
        worldNode.enumerateChildNodes(withName: "enemyBullet") { node, _ in
            node.removeFromParent()
        }
        worldNode.enumerateChildNodes(withName: "playerBullet") { node, _ in
            node.removeFromParent()
        }
        worldNode.enumerateChildNodes(withName: "powerup") { node, _ in
            node.removeFromParent()
        }

        // Remove swooping aliens
        for swooper in swoopingAliens {
            swooper.isAlive = false
            swooper.isSwooping = false
            swooper.spriteComponent.node.removeAllActions()
            swooper.spriteComponent.node.removeFromParent()
            alienFormation?.swooperDestroyed()
        }
        swoopingAliens.removeAll()

        // Remove UFO if active
        removeUFO()

        // Freeze the game world
        worldNode.isPaused = true

        // Show "SHIP DESTROYED" message with remaining lives
        let lives = playerEntity.healthComponent.currentHP
        let hs = GameConstants.hudScale

        let msgNode = SKNode()
        msgNode.zPosition = GameConstants.ZPosition.overlay

        let destroyedLabel = makeOverlayLabel(text: "SHIP DESTROYED", fontSize: 36)
        destroyedLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 + 20 * hs)
        msgNode.addChild(destroyedLabel)

        let livesText = lives == 1 ? "1 SHIP REMAINING" : "\(lives) SHIPS REMAINING"
        let livesLabel = makeOverlayLabel(text: livesText, fontSize: 22)
        livesLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 - 20 * hs)
        msgNode.addChild(livesLabel)

        // Fade in
        msgNode.alpha = 0
        addChild(msgNode)
        msgNode.run(SKAction.fadeIn(withDuration: 0.2))

        // After a pause, remove message, unfreeze, and glitch-in
        let showDuration: TimeInterval = 1.5
        run(SKAction.sequence([
            SKAction.wait(forDuration: showDuration),
            SKAction.run { [weak self] in
                guard let self else { return }
                msgNode.run(SKAction.sequence([
                    SKAction.fadeOut(withDuration: 0.2),
                    SKAction.removeFromParent()
                ]))

                // Unfreeze world
                self.worldNode.isPaused = false

                let respawnPos = CGPoint(x: self.size.width / 2, y: self.size.height * 0.142)
                self.playerEntity.respawnWithGlitch(
                    at: respawnPos,
                    invulnerabilityDuration: GameConstants.playerInvulnerabilityDuration
                ) { [weak self] in
                    self?.isRespawning = false
                }
            }
        ]))
    }

    // MARK: - Restart

    private func restartGame() {
        // Remove overlay
        overlayNode?.removeFromParent()
        overlayNode = nil

        // Unpause world
        worldNode.isPaused = false

        // Remove all entity sprites and clear
        for entity in entities {
            if let spriteComp = entity.component(ofType: SpriteComponent.self) {
                spriteComp.node.removeFromParent()
            }
        }
        entities.removeAll()

        // Remove formation
        alienFormation?.formationNode.removeFromParent()
        alienFormation = nil

        // Remove UFO if active
        removeUFO()

        // Remove any lingering bullets/powerup nodes
        worldNode.enumerateChildNodes(withName: "enemyBullet") { node, _ in
            node.removeFromParent()
        }
        worldNode.enumerateChildNodes(withName: "playerBullet") { node, _ in
            node.removeFromParent()
        }
        worldNode.enumerateChildNodes(withName: "powerup") { node, _ in
            node.removeFromParent()
        }

        // Clear swooping state
        for swooper in swoopingAliens {
            swooper.spriteComponent.node.removeAllActions()
            swooper.spriteComponent.node.removeFromParent()
        }
        swoopingAliens.removeAll()
        swoopTimer = 0

        // Reset state
        currentLevel = 1
        currentEnemyFireInterval = GameConstants.enemyFireInterval
        enemyFireTimer = 0
        ufoSpawnTimer = 0
        nextUfoSpawnInterval = randomUFOInterval()
        scoreManager.reset()

        // Re-setup
        setupPlayer()
        setupAliens()
        let lives = settings?.effectiveLives ?? GameConstants.playerLives
        livesDisplay.update(lives: lives)

        // Animate entrance
        playerEntity.shootingComponent.isFiring = false
        gameState = .levelTransition
        alienFormation?.animateEntrance { [weak self] in
            self?.gameState = .playing
        }
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
              formation.aliveCount == 0,
              swoopingAliens.isEmpty,
              ufoEntity == nil else { return }

        gameState = .levelTransition
        currentLevel += 1

        // Remove enemy bullets immediately — no reason to let them kill the player after clearing
        worldNode.enumerateChildNodes(withName: "enemyBullet") { node, _ in
            node.removeFromParent()
        }

        // Wait for remaining player bullets, UFO, and powerups to finish
        waitForClearThenShowLevel()
    }

    private func waitForClearThenShowLevel() {
        let checkAction = SKAction.run { [weak self] in
            guard let self else { return }

            var remaining = false
            worldNode.enumerateChildNodes(withName: "playerBullet") { _, stop in
                remaining = true
                stop.pointee = true
            }
            if !remaining {
                worldNode.enumerateChildNodes(withName: "powerup") { _, stop in
                    remaining = true
                    stop.pointee = true
                }
            }
            if !remaining && ufoEntity != nil {
                remaining = true
            }
            if !remaining && !swoopingAliens.isEmpty {
                remaining = true
            }

            if !remaining {
                self.removeAction(forKey: "waitForClear")
                self.removeAction(forKey: "waitForClearTimeout")
                self.showLevelOverlay()

                let wait = SKAction.wait(forDuration: 2.5)
                let startNext = SKAction.run { [weak self] in
                    self?.startNextLevel()
                }
                self.run(SKAction.sequence([wait, startNext]), withKey: "levelStart")
            }
        }

        let poll = SKAction.sequence([SKAction.wait(forDuration: 0.1), checkAction])
        run(SKAction.repeatForever(poll), withKey: "waitForClear")

        // Safety timeout — don't wait forever (10s accommodates UFO crossing wide screens)
        let timeout = SKAction.sequence([
            SKAction.wait(forDuration: 10.0),
            SKAction.run { [weak self] in
                guard let self,
                      self.overlayNode == nil,
                      self.action(forKey: "levelStart") == nil else { return }
                self.removeAction(forKey: "waitForClear")
                worldNode.enumerateChildNodes(withName: "playerBullet") { node, _ in
                    node.removeFromParent()
                }
                worldNode.enumerateChildNodes(withName: "powerup") { node, _ in
                    node.removeFromParent()
                }
                self.showLevelOverlay()
                let wait = SKAction.wait(forDuration: 2.5)
                let startNext = SKAction.run { [weak self] in
                    self?.startNextLevel()
                }
                self.run(SKAction.sequence([wait, startNext]), withKey: "levelStart")
            }
        ])
        run(timeout, withKey: "waitForClearTimeout")
    }

    private func showLevelOverlay() {
        playerEntity.shootingComponent.isFiring = false
        playerEntity.clearPowerup()

        let overlay = SKNode()
        overlay.zPosition = GameConstants.ZPosition.overlay

        // Semi-transparent background fades in
        let bg = SKSpriteNode(color: SKColor(white: 0, alpha: 0.0), size: size)
        bg.position = CGPoint(x: size.width / 2, y: size.height / 2)
        bg.zPosition = -1
        bg.run(SKAction.colorize(with: .black, colorBlendFactor: 1.0, duration: 0.0))
        bg.run(SKAction.fadeAlpha(to: 0.5, duration: 0.3))
        overlay.addChild(bg)

        let hs = GameConstants.hudScale

        let levelLabel = makeOverlayLabel(text: "LEVEL", fontSize: 48)
        levelLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 + 25 * hs)
        overlay.addChild(levelLabel)

        let numberLabel = makeOverlayLabel(text: "\(currentLevel)", fontSize: 56)
        numberLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 - 35 * hs)
        overlay.addChild(numberLabel)

        // Bounce-in animation for text
        for label in [levelLabel, numberLabel] {
            label.setScale(0.0)
            label.run(SKAction.sequence([
                SKAction.scale(to: 1.2, duration: 0.25),
                SKAction.scale(to: 0.9, duration: 0.1),
                SKAction.scale(to: 1.05, duration: 0.08),
                SKAction.scale(to: 1.0, duration: 0.07)
            ]))
        }

        addChild(overlay)
        overlayNode = overlay
    }

    private func startNextLevel() {
        AudioManager.shared.play(GameConstants.Sound.levelStart)
        if GameConstants.Haptic.levelComplete { HapticManager.shared.success() }

        // Remove overlay
        overlayNode?.removeFromParent()
        overlayNode = nil

        // Remove old formation
        alienFormation?.formationNode.removeFromParent()
        alienFormation = nil

        // Clear swooping state
        for swooper in swoopingAliens {
            swooper.spriteComponent.node.removeAllActions()
            swooper.spriteComponent.node.removeFromParent()
        }
        swoopingAliens.removeAll()
        swoopTimer = 0

        // Reset timers (UFO timer carries across levels so it eventually fires)
        enemyFireTimer = 0

        // Create new formation (setupAliens uses LevelManager)
        setupAliens()

        // Reset player position
        playerEntity.spriteComponent.node.position = CGPoint(x: size.width / 2, y: size.height * 0.142)

        // Pause firing and animate aliens appearing
        playerEntity.shootingComponent.isFiring = false
        gameState = .levelTransition

        alienFormation?.animateEntrance { [weak self] in
            self?.gameState = .playing
        }
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
        let scaledSize = fontSize * GameConstants.hudScale
        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.text = text
        label.fontSize = scaledSize
        label.fontColor = SKColor(red: 0.3, green: 0.85, blue: 0.3, alpha: 1.0)
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center

        // Shadow/outline effect via a duplicate label behind
        let shadow = SKLabelNode(fontNamed: "Menlo-Bold")
        shadow.text = text
        shadow.fontSize = scaledSize
        shadow.fontColor = SKColor(red: 0.1, green: 0.3, blue: 0.1, alpha: 1.0)
        shadow.horizontalAlignmentMode = .center
        shadow.verticalAlignmentMode = .center
        shadow.position = CGPoint(x: 2, y: -2)
        shadow.zPosition = -1
        label.addChild(shadow)

        return label
    }

    private func flashExtraLifeMessage() {
        let playerPos = playerEntity.spriteComponent.node.position
        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.text = "EXTRA SHIP!"
        label.fontSize = 18 * GameConstants.hudScale
        label.fontColor = SKColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 1.0)
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .top
        let margin: CGFloat = 60 * GameConstants.hudScale
        let clampedX = min(max(playerPos.x, margin), size.width - margin)
        label.position = CGPoint(x: clampedX, y: playerPos.y - PlayerEntity.shipSize.height / 2 - 8)
        label.zPosition = GameConstants.ZPosition.ui
        worldNode.addChild(label)

        label.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.5),
            SKAction.fadeOut(withDuration: 0.15),
            SKAction.removeFromParent()
        ]))
    }

    // MARK: - Update

    override func update(_ currentTime: TimeInterval) {
        if lastUpdateTime == 0 {
            lastUpdateTime = currentTime
        }

        let dt = currentTime - lastUpdateTime

        if gameState == .playing || gameState == .levelTransition {
            for entity in entities {
                entity.update(deltaTime: dt)
            }

            // Track UFO removal (flew off-screen)
            if let ufo = ufoEntity, ufo.spriteComponent.node.parent == nil {
                ufoEntity = nil
            }
        }

        if gameState == .playing && !isRespawning {
            alienFormation?.update(deltaTime: dt)

            // Update player vertical ceiling: 1 ship height below lowest alien
            if let lowestY = alienFormation?.lowestAlienY() {
                let ceiling = lowestY - PlayerEntity.shipSize.height
                playerEntity.movementComponent.maxY = max(playerEntity.movementComponent.minY, ceiling)
            }

            // Enemy fire timer (paused during respawn)
            if !isRespawning {
                enemyFireTimer += dt
                if enemyFireTimer >= currentEnemyFireInterval {
                    enemyFireTimer = 0
                    spawnEnemyBullet()
                }
            }

            // UFO spawn timer
            ufoSpawnTimer += dt
            if ufoSpawnTimer >= nextUfoSpawnInterval {
                ufoSpawnTimer = 0
                nextUfoSpawnInterval = randomUFOInterval()
                spawnUFO()
            }

            // Swoop timer (paused during respawn)
            if !isRespawning {
                swoopTimer += dt
            }
            if swoopTimer >= currentSwoopInterval {
                swoopTimer = 0
                initiateSwoop()
            }

            // Pause firing when nothing to shoot at, during respawn, or resume if UFO appears
            let shouldFire = !isRespawning &&
                ((alienFormation?.aliveCount ?? 0) > 0 || !swoopingAliens.isEmpty || ufoEntity != nil)
            if shouldFire != playerEntity.shootingComponent.isFiring {
                playerEntity.shootingComponent.isFiring = shouldFire
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
