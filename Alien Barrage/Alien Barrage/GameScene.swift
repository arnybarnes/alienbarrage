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
    private var starfieldNode: SKEmitterNode?

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

    // Powerup indicator
    private var powerupIndicator: PowerupIndicator!

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
    private var lastShootSoundTime: Double = 0
    private var lastEnemyDeathSoundTime: TimeInterval = 0
    private var transitionStallStartedAt: TimeInterval = 0
    private var lastTransitionWatchdogLogAt: TimeInterval = 0

    // Manual player bullet collision bookkeeping (enabled by feature flag).
    private var trackedPlayerBullets: [ObjectIdentifier: SKSpriteNode] = [:]
    private var playerBulletPreviousPositions: [ObjectIdentifier: CGPoint] = [:]
    private var pendingManualHits: [PendingManualHit] = []

    // Bonus round — disables formation combat mechanics
    private var bonusRoundActive: Bool = false
    private var bonusAliensTotal: Int = 0
    private var bonusAliensResolved: Int = 0  // killed or exited
    private var bonusRoundHits: Int = 0       // killed only (for scoring)
    private var bonusWavePatterns: [(Int) -> CGMutablePath] = []

    // Overlay
    private var overlayNode: SKNode?

    // Impact snapshot — captured at moment of ship destruction
    private var impactSnapshot: SKTexture?
    private var impactPlayerPosition: CGPoint = .zero

    var safeAreaInsets: UIEdgeInsets = .zero

    convenience init(size: CGSize, settings: GameSettings) {
        self.init(size: size)
        self.settings = settings
    }

    override func didMove(to view: SKView) {
        #if DEBUG
        PerformanceLog.enabled = true
        PerformanceLog.sessionStart()
        PerformanceLog.event(
            "PerfConfig",
            "manualPB=\(GameConstants.Performance.manualPlayerBulletCollision) spreadStagger=\(GameConstants.Performance.spreadShotStagger) playerCap=\(GameConstants.Performance.maxActivePlayerBullets) playerCapSpeed=\(GameConstants.Performance.playerBulletCapSpeedMultiplier) enemyCap=\(GameConstants.Performance.maxActiveEnemyBullets) bandH=\(GameConstants.Performance.manualCollisionBandHeight) resolveCap=\(GameConstants.Performance.manualResolutionMaxPerFrame) budgetMs=\(GameConstants.Performance.manualResolutionBudgetMs) liteFxBacklog=\(GameConstants.Performance.manualResolutionLiteFxBacklog) preferLiteFx=\(GameConstants.Performance.manualResolutionPreferLiteFX) outlierMs=\(GameConstants.Performance.manualSweepOutlierThresholdMs) resolveOutlierMs=\(GameConstants.Performance.manualResolveOutlierThresholdMs) frameGapMs=\(GameConstants.Performance.frameGapThresholdMs) frameGapUnexplainedMs=\(GameConstants.Performance.frameGapUnexplainedThresholdMs) enemyDeathSfxMs=\(GameConstants.Performance.enemyDeathSoundMinInterval) enemyDeathSfxReduced=\(GameConstants.Performance.enemyDeathSoundDuringReducedFX) enemyDeathSfxBonus=\(GameConstants.Performance.enemyDeathSoundDuringBonusRounds)"
        )
        #endif

        ExplosionEffect.warmUp()

        backgroundColor = .black
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self

        // World node holds all gameplay objects
        worldNode = SKNode()
        addChild(worldNode)

        // Starfield background
        let starfield = ParticleEffects.createStarfield(sceneSize: size)
        addChild(starfield)
        starfieldNode = starfield

        scoreManager.scoreMultiplier = settings?.scoreMultiplier ?? 1.0
        setupPlayer()
        setupScoreDisplay()
        setupLivesDisplay()
        setupPowerupIndicator()
        nextUfoSpawnInterval = randomUFOInterval()

        let config = LevelManager.config(forLevel: currentLevel)
        bonusRoundActive = config.isBonusRound

        if bonusRoundActive {
            print("Bonus round active for level \(currentLevel)")
            gameState = .playing
            startBonusRound()
        } else {
            setupAliens()

            // Animate first level entrance
            playerEntity.shootingComponent.isFiring = false
            gameState = .levelTransition
            AudioManager.shared.play(GameConstants.Sound.levelStart)
            alienFormation?.animateEntrance { [weak self] in
                self?.gameState = .playing
            }
        }

        // Pause on background
        NotificationCenter.default.addObserver(
            self, selector: #selector(appWillResignActive(_:)),
            name: UIApplication.willResignActiveNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(appDidBecomeActive(_:)),
            name: UIApplication.didBecomeActiveNotification, object: nil
        )
    }

    override func willMove(from view: SKView) {
        super.willMove(from: view)
        NotificationCenter.default.removeObserver(self)
        PerformanceLog.sessionEnd(finalLevel: currentLevel, score: scoreManager.currentScore)
    }

    @objc private func appWillResignActive(_ notification: Notification) {
        PerformanceLog.event("AppState", "willResign gameState=\(gameState) paused=\(isPaused)")
        if gameState == .playing {
            isPaused = true
        }
    }

    @objc private func appDidBecomeActive(_ notification: Notification) {
        PerformanceLog.event("AppState", "didBecomeActive gameState=\(gameState) paused=\(isPaused)")
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
        playerEntity.onPowerupCleared = { [weak self] type in
            self?.powerupIndicator.hide(type: type)
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

    private func setupPowerupIndicator() {
        powerupIndicator = PowerupIndicator(bottomInset: safeAreaInsets.bottom)
        addChild(powerupIndicator.node)
    }

    private func setupLivesDisplay() {
        livesDisplay = LivesDisplay(bottomInset: safeAreaInsets.bottom)
        addChild(livesDisplay.node)  // UI stays on scene, not worldNode
        let lives = settings?.effectiveLives ?? GameConstants.playerLives
        livesDisplay.update(lives: lives)
    }

    // MARK: - Bullet Spawning

    private func playEnemyDeathSoundThrottled(reducedFX: Bool) {
        // In reduced-FX mode we prioritize frame stability over per-kill audio.
        if reducedFX && !GameConstants.Performance.enemyDeathSoundDuringReducedFX {
            return
        }

        if bonusRoundActive && !GameConstants.Performance.enemyDeathSoundDuringBonusRounds {
            return
        }

        let minInterval = max(0, GameConstants.Performance.enemyDeathSoundMinInterval)
        if minInterval == 0 {
            AudioManager.shared.play(GameConstants.Sound.enemyDeath)
            return
        }

        let now = CACurrentMediaTime()
        if now - lastEnemyDeathSoundTime >= minInterval {
            AudioManager.shared.play(GameConstants.Sound.enemyDeath)
            lastEnemyDeathSoundTime = now
        }
    }

    private func spawnPlayerBullet() {
        guard !isRespawning else { return }
        // Throttle shoot sound — skip if last sound was <0.15s ago (only affects rapid fire)
        let now = CACurrentMediaTime()
        if now - lastShootSoundTime >= 0.15 {
            AudioManager.shared.play(GameConstants.Sound.playerShoot)
            lastShootSoundTime = now
        }
        if GameConstants.Haptic.playerShoot { HapticManager.shared.lightImpact() }

        let playerPos = playerEntity.spriteComponent.node.position
        let baseY = playerPos.y + PlayerEntity.shipSize.height / 2 + 5
        let bulletPos = CGPoint(x: playerPos.x, y: baseY)

        if playerEntity.activePowerups.contains(.spreadShot) {
            // Fire 3 bullets in a fan pattern
            let angles: [CGFloat] = [-0.25, 0, 0.25]  // ~14 degrees
            for (index, angle) in angles.enumerated() {
                let delay = GameConstants.Performance.spreadShotStagger * Double(index)
                spawnPlayerBullet(at: bulletPos, angle: angle, delay: delay)
            }
        } else {
            spawnPlayerBullet(at: bulletPos, angle: 0, delay: 0)
        }
    }

    private func spawnPlayerBullet(at position: CGPoint, angle: CGFloat, delay: TimeInterval) {
        let spawnBlock: () -> Void = { [weak self] in
            guard let self else { return }
            guard self.gameState == .playing || self.gameState == .levelTransition else { return }
            guard !self.isRespawning else { return }
            self.enforcePlayerBulletCapIfNeeded()

            let speedMultiplier = self.playerBulletSpeedMultiplierForCurrentState()
            let bullet = ProjectileEntity(
                position: position,
                sceneHeight: self.size.height,
                speedMultiplier: speedMultiplier
            )
            let node = bullet.spriteComponent.node

            if angle != 0 {
                // Replace the default straight-up action with angled movement.
                node.removeAllActions()
                let distance = self.size.height - position.y + ProjectileEntity.bulletSize.height
                let speed = GameConstants.playerBulletSpeed * GameConstants.heightRatio * max(0.1, speedMultiplier)
                let duration = TimeInterval(distance / speed)
                let dx = sin(angle) * distance
                let move = SKAction.moveBy(x: dx, y: distance, duration: duration)
                let remove = SKAction.removeFromParent()
                node.run(SKAction.sequence([move, remove]))
            }

            self.worldNode.addChild(node)
            self.entities.append(bullet)
            self.trackPlayerBullet(node)
        }

        if delay > 0 {
            let spawnAction = SKAction.run { spawnBlock() }
            run(SKAction.sequence([SKAction.wait(forDuration: delay), spawnAction]))
        } else {
            spawnBlock()
        }
    }

    private func trackPlayerBullet(_ node: SKSpriteNode) {
        guard GameConstants.Performance.manualPlayerBulletCollision else { return }
        let id = ObjectIdentifier(node)
        trackedPlayerBullets[id] = node
        playerBulletPreviousPositions[id] = node.position
    }

    private func untrackPlayerBullet(_ node: SKSpriteNode) {
        let id = ObjectIdentifier(node)
        trackedPlayerBullets.removeValue(forKey: id)
        playerBulletPreviousPositions.removeValue(forKey: id)
    }

    private func removePlayerBullet(_ node: SKNode?) {
        guard let node else { return }
        if let sprite = node as? SKSpriteNode {
            untrackPlayerBullet(sprite)
            sprite.removeFromParent()
            return
        }
        node.removeFromParent()
    }

    private func clearTrackedPlayerBullets() {
        trackedPlayerBullets.removeAll(keepingCapacity: true)
        playerBulletPreviousPositions.removeAll(keepingCapacity: true)
        clearPendingManualHits()
    }

    private func activePlayerBulletNodes() -> [SKSpriteNode] {
        if GameConstants.Performance.manualPlayerBulletCollision {
            let staleIDs = trackedPlayerBullets.compactMap { pair in
                let (id, node) = pair
                return node.parent == nil ? id : nil
            }
            for id in staleIDs {
                trackedPlayerBullets.removeValue(forKey: id)
                playerBulletPreviousPositions.removeValue(forKey: id)
            }
            return Array(trackedPlayerBullets.values)
        }

        return entities.compactMap { entity in
            guard let bullet = entity as? ProjectileEntity else { return nil }
            let node = bullet.spriteComponent.node
            return node.parent != nil ? node : nil
        }
    }

    private func activeEnemyBulletCount() -> Int {
        entities.reduce(into: 0) { count, entity in
            guard let bullet = entity as? EnemyProjectileEntity else { return }
            if bullet.spriteComponent.node.parent != nil {
                count += 1
            }
        }
    }

    private func playerBulletSpeedMultiplierForCurrentState() -> CGFloat {
        guard GameConstants.Performance.maxActivePlayerBullets > 0 else { return 1.0 }
        let underCapPressure =
            playerEntity.activePowerups.contains(.rapidFire) ||
            playerEntity.activePowerups.contains(.spreadShot)
        guard underCapPressure else { return 1.0 }
        return max(1.0, GameConstants.Performance.playerBulletCapSpeedMultiplier)
    }

    private func enforcePlayerBulletCapIfNeeded() {
        var maxBullets = GameConstants.Performance.maxActivePlayerBullets
        if playerEntity.activePowerups.contains(.spreadShot) {
            // Spread shot needs a little extra headroom so side bullets can travel long enough.
            maxBullets += 6
        }
        guard maxBullets > 0 else { return }

        let activeBullets = activePlayerBulletNodes()
        guard activeBullets.count >= maxBullets else { return }

        let preserveHighTravelBullets = playerEntity.activePowerups.contains(.spreadShot) || ufoEntity != nil
        let bulletToEvict: SKSpriteNode?
        if preserveHighTravelBullets {
            // During spread/UFO pressure, keep far-travel bullets alive and trim near-player bullets first.
            bulletToEvict = activeBullets.min(by: { $0.position.y < $1.position.y })
        } else {
            // Default behavior keeps newest shots visible by trimming the farthest bullet first.
            bulletToEvict = activeBullets.max(by: { $0.position.y < $1.position.y })
        }
        guard let bulletToEvict else { return }

        removePlayerBullet(bulletToEvict)
        PerformanceLog.bulletCap(
            playerEvictions: 1,
            playerNearEvictions: preserveHighTravelBullets ? 1 : 0,
            playerFarEvictions: preserveHighTravelBullets ? 0 : 1,
            playerSpreadOrUFOEvictions: preserveHighTravelBullets ? 1 : 0
        )
    }

    // MARK: - Enemy Shooting

    private func spawnEnemyBullet() {
        guard gameState == .playing,
              let formation = alienFormation,
              !formation.allDestroyed else { return }

        let maxEnemyBullets = GameConstants.Performance.maxActiveEnemyBullets
        if maxEnemyBullets > 0 && activeEnemyBulletCount() >= maxEnemyBullets {
            PerformanceLog.bulletCap(enemySkips: 1)
            return
        }

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
        guard settings?.powerupsEnabled != false else { return }
        // Exclude powerups the player already has active (rapid fire and spread shot don't stack)
        var excluded: Set<PowerupType> = []
        if playerEntity.activePowerups.contains(.rapidFire) { excluded.insert(.rapidFire) }
        if playerEntity.activePowerups.contains(.spreadShot) { excluded.insert(.spreadShot) }
        if playerEntity.healthComponent.currentHP >= GameConstants.playerMaxLivesForExtraLife {
            excluded.insert(.extraLife)
        }

        let candidates = PowerupType.allCases.filter { !excluded.contains($0) }
        guard let type = candidates.randomElement() else { return }
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
        entities.append(alien)  // manual collision scans entities for swooper targets

        let node = alien.spriteComponent.node

        // Play swoop SFX via AudioManager (preloaded AVAudioEngine path).
        // This avoids first-use SKAudioNode file decode stalls.
        let swoopSound = GameConstants.Sound.alienSwoop
        if !swoopSound.isEmpty && !AudioManager.shared.isMuted(swoopSound) {
            AudioManager.shared.play(swoopSound)
        }

        // Ensure swoopers have an active player-contact collider.
        alien.enableSwoopPhysics()

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

    // MARK: - Bonus Round

    private func startBonusRound() {
        for i in 0..<5 { removeAction(forKey: "bonusWave\(i)") }
        for i in 0..<4 { removeAction(forKey: "bonusPowerup\(i)") }
        removeAction(forKey: "levelStart")
        removeAction(forKey: "waitForClear")
        removeAction(forKey: "waitForClearTimeout")

        bonusAliensTotal = 40
        bonusAliensResolved = 0
        bonusRoundHits = 0

        let round = (currentLevel / 4) - 1
        bonusWavePatterns = BonusPatterns.patterns(forBonusRound: round, screenSize: size)
        PerformanceLog.event("BonusFlow", "startBonusRound level=\(currentLevel) round=\(round) patterns=\(bonusWavePatterns.count)")

        for wave in 0..<5 {
            let delay = TimeInterval(wave) * 2.0
            run(SKAction.sequence([
                SKAction.wait(forDuration: delay),
                SKAction.run { [weak self] in
                    guard let self else { return }
                    PerformanceLog.event("BonusFlow", "spawnWave wave=\(wave) resolved=\(self.bonusAliensResolved)/\(self.bonusAliensTotal)")
                    self.spawnBonusWave(wave)
                }
            ]), withKey: "bonusWave\(wave)")
        }

        // Schedule 4 powerup drops (2 Rapid Fire, 2 Spread Shot) evenly across the round.
        // Waves span 0–8s; aliens fly a few more seconds after. Space powerups at 2.5s intervals.
        let bonusPowerupTypes: [PowerupType] = [.rapidFire, .spreadShot, .rapidFire, .spreadShot]
        let margin: CGFloat = 40
        for i in 0..<4 {
            let delay = 0.5 + TimeInterval(i) * 0.5  // 0.5s, 1.0s, 1.5s, 2.0s
            run(SKAction.sequence([
                SKAction.wait(forDuration: delay),
                SKAction.run { [weak self] in
                    guard let self, self.settings?.powerupsEnabled != false else { return }
                    let x = CGFloat.random(in: margin...(self.size.width - margin))
                    let pos = CGPoint(x: x, y: self.size.height + PowerupEntity.powerupSize.height)
                    let powerup = PowerupEntity(type: bonusPowerupTypes[i], position: pos, sceneHeight: self.size.height, speedMultiplier: 2.0)
                    self.worldNode.addChild(powerup.spriteComponent.node)
                    self.entities.append(powerup)
                }
            ]), withKey: "bonusPowerup\(i)")
        }
    }

    private func spawnBonusWave(_ waveIndex: Int) {
        PerformanceLog.event("BonusFlow", "spawnBonusWave wave=\(waveIndex) patterns=\(bonusWavePatterns.count)")
        for i in 0..<8 {
            let delay = TimeInterval(i) * 0.15
            run(SKAction.sequence([
                SKAction.wait(forDuration: delay),
                SKAction.run { [weak self] in
                    self?.spawnBonusAlien(wave: waveIndex, index: i)
                }
            ]))
        }
    }

    private func spawnBonusAlien(wave: Int, index: Int) {
        PerformanceLog.event("BonusSpawn", "wave=\(wave) index=\(index)")
        guard wave >= 0, wave < bonusWavePatterns.count else {
            PerformanceLog.error("BonusFlow: waveIndexOutOfRange wave=\(wave) patterns=\(bonusWavePatterns.count) level=\(currentLevel)")
            return
        }
        let alien = AlienEntity(type: .small, row: 0, col: wave)
        alien.isSwooping = true  // use swooping cleanup path in collision handler

        let node = alien.spriteComponent.node
        node.removeAction(forKey: "alienAliveMotion")
        node.setScale(1.0)

        let trail = ParticleEffects.createGoldTrail()
        trail.name = "goldTrail"
        trail.position = CGPoint(x: 0, y: -alien.alienType.size.height / 2)
        trail.zPosition = -1
        node.addChild(trail)

        let path = bonusWavePatterns[wave](index)
        node.position = path.currentPoint

        worldNode.addChild(node)
        trail.targetNode = worldNode
        entities.append(alien)

        let follow = SKAction.follow(path, asOffset: false, orientToPath: false, duration: 3.0)
        let cleanup = SKAction.run { [weak self, weak alien] in
            guard let self, let alien, alien.isAlive else { return }
            alien.isAlive = false
            let n = alien.spriteComponent.node
            self.detachGoldTrail(from: n)
            n.removeAllActions()
            n.removeFromParent()
            self.bonusAliensResolved += 1
            self.checkBonusRoundComplete()
        }
        node.run(SKAction.sequence([follow, cleanup]), withKey: "bonusFlightPath")
    }

    private func detachGoldTrail(from node: SKNode) {
        guard let trail = node.childNode(withName: "goldTrail") as? SKEmitterNode else { return }
        let worldPos = node.convert(trail.position, to: worldNode)
        trail.removeFromParent()
        trail.position = worldPos
        trail.targetNode = nil
        trail.particleBirthRate = 0
        worldNode.addChild(trail)
        trail.run(SKAction.sequence([
            SKAction.wait(forDuration: 1.0),
            SKAction.removeFromParent()
        ]))
    }

    private func checkBonusRoundComplete() {
        guard bonusRoundActive,
              gameState == .playing,
              bonusAliensTotal > 0,
              bonusAliensResolved >= bonusAliensTotal else { return }

        PerformanceLog.event(
            "BonusFlow",
            "complete hits=\(bonusRoundHits) resolved=\(bonusAliensResolved)/\(bonusAliensTotal) level=\(currentLevel)"
        )

        PerformanceLog.levelComplete(level: currentLevel, isBonus: true, aliveAliens: 0, fireInterval: currentEnemyFireInterval)

        gameState = .levelTransition
        playerEntity.shootingComponent.isFiring = false

        // Remove remaining player bullets
        worldNode.enumerateChildNodes(withName: "playerBullet") { node, _ in
            self.removePlayerBullet(node)
        }
        clearTrackedPlayerBullets()

        // Short pause before showing results
        run(SKAction.sequence([
            SKAction.wait(forDuration: 0.8),
            SKAction.run { [weak self] in
                guard let self else { return }
                PerformanceLog.event("BonusFlow", "invokeShowResults level=\(self.currentLevel)")
                self.showBonusResults()
            }
        ]))
    }

    private func showBonusResults() {
        PerformanceLog.event("BonusFlow", "showResults level=\(currentLevel) hits=\(bonusRoundHits)/\(bonusAliensTotal)")
        let isPerfect = bonusRoundHits >= bonusAliensTotal
        let bonus = isPerfect ? GameConstants.bonusRoundPerfectBonus : bonusRoundHits * GameConstants.bonusRoundKillScore

        // Add the end-of-round bonus to the score
        scoreManager.addRawPoints(bonus)

        AudioManager.shared.play(GameConstants.Sound.bonusComplete)

        let overlay = SKNode()
        overlay.zPosition = GameConstants.ZPosition.overlay

        let bg = SKSpriteNode(color: SKColor(white: 0, alpha: 0.0), size: size)
        bg.position = CGPoint(x: size.width / 2, y: size.height / 2)
        bg.zPosition = -1
        bg.run(SKAction.fadeAlpha(to: 0.6, duration: 0.3))
        overlay.addChild(bg)

        let hs = GameConstants.hudScale
        let cx = size.width / 2
        let cy = size.height / 2

        // Title: "BONUS ROUND COMPLETE"
        let titleLabel = makeOverlayLabel(text: "BONUS ROUND", fontSize: 40, gold: true)
        titleLabel.position = CGPoint(x: cx, y: cy + 80 * hs)
        overlay.addChild(titleLabel)

        let completeLabel = makeOverlayLabel(text: "COMPLETE", fontSize: 40, gold: true)
        completeLabel.position = CGPoint(x: cx, y: cy + 40 * hs)
        overlay.addChild(completeLabel)

        // Hit count or PERFECT!
        if isPerfect {
            let perfectLabel = makeOverlayLabel(text: "PERFECT!", fontSize: 44, gold: true)
            perfectLabel.position = CGPoint(x: cx, y: cy - 15 * hs)
            overlay.addChild(perfectLabel)

            // Pulse animation for PERFECT!
            let pulse = SKAction.sequence([
                SKAction.scale(to: 1.15, duration: 0.4),
                SKAction.scale(to: 1.0, duration: 0.4)
            ])
            perfectLabel.run(SKAction.repeatForever(pulse))
        } else {
            let hitLabel = makeOverlayLabel(text: "HIT: \(bonusRoundHits) / \(bonusAliensTotal)", fontSize: 34, gold: true)
            hitLabel.position = CGPoint(x: cx, y: cy - 15 * hs)
            overlay.addChild(hitLabel)
        }

        // Bonus value with count-up animation
        let bonusLabel = makeOverlayLabel(text: "BONUS: 0", fontSize: 36, gold: true)
        bonusLabel.position = CGPoint(x: cx, y: cy - 65 * hs)
        overlay.addChild(bonusLabel)

        // Animate count-up over ~1 second
        if bonus > 0 {
            let steps = 20
            let stepDuration = 1.0 / Double(steps)
            var actions: [SKAction] = [SKAction.wait(forDuration: 0.3)]  // brief pause before counting
            for i in 1...steps {
                let value = bonus * i / steps
                let formatted = NumberFormatter.localizedString(from: NSNumber(value: value), number: .decimal)
                actions.append(SKAction.run {
                    bonusLabel.text = "BONUS: \(formatted)"
                    // Update shadow text too
                    if let shadow = bonusLabel.children.first as? SKLabelNode {
                        shadow.text = bonusLabel.text
                    }
                })
                actions.append(SKAction.wait(forDuration: stepDuration))
            }
            bonusLabel.run(SKAction.sequence(actions))
        }

        // Bounce-in animation for all labels
        for child in overlay.children where child is SKLabelNode {
            child.setScale(0.0)
            child.run(SKAction.sequence([
                SKAction.scale(to: 1.2, duration: 0.25),
                SKAction.scale(to: 0.9, duration: 0.1),
                SKAction.scale(to: 1.05, duration: 0.08),
                SKAction.scale(to: 1.0, duration: 0.07)
            ]))
        }

        addChild(overlay)
        overlayNode = overlay

        // Dismiss after 3.5 seconds, then proceed to next level
        currentLevel += 1
        let hadLevelStart = action(forKey: "levelStart") != nil
        PerformanceLog.event(
            "BonusFlow",
            "scheduleLevelStart delay=3.5 level=\(currentLevel) existingLevelStart=\(hadLevelStart) scenePaused=\(isPaused) worldPaused=\(worldNode.isPaused)"
        )
        run(SKAction.sequence([
            SKAction.wait(forDuration: 3.5),
            SKAction.run { [weak self] in
                guard let self else { return }
                PerformanceLog.event("BonusFlow", "startNextLevel fromBonus level=\(self.currentLevel)")
                self.startNextLevel()
            }
        ]), withKey: "levelStart")
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

    private struct ManualAlienTarget {
        let node: SKSpriteNode
        let rect: CGRect
        let centerY: CGFloat
        let alien: AlienEntity
        let isSwooper: Bool
    }

    private struct PendingManualHit {
        enum Target {
            case alien(alien: AlienEntity, node: SKSpriteNode, isSwooper: Bool)
            case ufo(ufo: UFOEntity, node: SKSpriteNode)
        }
        let target: Target
    }

    private struct ManualDetectionStats {
        let bullets: Int
        let targets: Int
        let candidateRefs: Int
        let overlapChecks: Int
        let queuedHits: Int
        let detectMs: Double
    }

    private struct ManualResolutionStats {
        let resolvedHits: Int
        let reducedFXHits: Int
        let queueDepth: Int
        let resolveMs: Double
    }

    private func runManualPlayerBulletCollisions() {
        guard GameConstants.Performance.manualPlayerBulletCollision else { return }
        guard gameState == .playing || gameState == .levelTransition else {
            clearPendingManualHits()
            return
        }

        let detect = detectManualPlayerBulletCollisions()
        let resolve = processPendingManualHitResolutions()
        let totalMs = detect.detectMs + resolve.resolveMs

        PerformanceLog.manualBulletSweep(
            bullets: detect.bullets,
            targets: detect.targets,
            candidateRefs: detect.candidateRefs,
            overlapChecks: detect.overlapChecks,
            queuedHits: detect.queuedHits,
            resolvedHits: resolve.resolvedHits,
            reducedFXHits: resolve.reducedFXHits,
            queueDepth: resolve.queueDepth,
            detectMs: detect.detectMs,
            resolveMs: resolve.resolveMs,
            durationMs: totalMs
        )
    }

    private func detectManualPlayerBulletCollisions() -> ManualDetectionStats {
        // Drop stale nodes that were removed by actions/cleanup.
        for (id, node) in trackedPlayerBullets where node.parent == nil {
            trackedPlayerBullets.removeValue(forKey: id)
            playerBulletPreviousPositions.removeValue(forKey: id)
        }

        let detectStart = CACurrentMediaTime()
        guard !trackedPlayerBullets.isEmpty else {
            return ManualDetectionStats(
                bullets: 0,
                targets: 0,
                candidateRefs: 0,
                overlapChecks: 0,
                queuedHits: 0,
                detectMs: (CACurrentMediaTime() - detectStart) * 1000
            )
        }

        var overlapChecks = 0
        var queuedHits = 0
        var candidateRefs = 0
        let bullets = Array(trackedPlayerBullets.values)
        let bandHeight = max(24, GameConstants.Performance.manualCollisionBandHeight)

        let swooperTargets = buildSwooperTargets()
        let formationTargets = buildFormationTargets()
        let swooperBands = buildBands(for: swooperTargets, bandHeight: bandHeight)
        let formationBands = buildBands(for: formationTargets, bandHeight: bandHeight)
        let targets = formationTargets.count + swooperTargets.count + (ufoEntity == nil ? 0 : 1)

        for bulletNode in bullets {
            guard bulletNode.parent != nil else {
                untrackPlayerBullet(bulletNode)
                continue
            }

            let bulletID = ObjectIdentifier(bulletNode)
            let previous = playerBulletPreviousPositions[bulletID] ?? bulletNode.position
            let current = bulletNode.position
            let sweepRect = sweptRect(from: previous, to: current, size: bulletNode.frame.size)

            if let ufo = ufoEntity, ufo.spriteComponent.node.parent != nil {
                overlapChecks += 1
                if sweepRect.intersects(worldRect(for: ufo.spriteComponent.node)) {
                    queueManualHit(.ufo(ufo: ufo, node: ufo.spriteComponent.node))
                    removePlayerBullet(bulletNode)
                    queuedHits += 1
                    continue
                }
            }

            let swooperCandidateIndices = candidateIndices(
                for: sweepRect,
                bands: swooperBands,
                bandHeight: bandHeight
            )
            candidateRefs += swooperCandidateIndices.count
            if let swooperTarget = firstIntersectingTarget(
                in: swooperTargets,
                candidateIndices: swooperCandidateIndices,
                sweepRect: sweepRect,
                bulletY: current.y,
                overlapChecks: &overlapChecks
            ) {
                queueManualHit(.alien(alien: swooperTarget.alien, node: swooperTarget.node, isSwooper: true))
                removePlayerBullet(bulletNode)
                queuedHits += 1
                continue
            }

            let formationCandidateIndices = candidateIndices(
                for: sweepRect,
                bands: formationBands,
                bandHeight: bandHeight
            )
            candidateRefs += formationCandidateIndices.count
            if let formationTarget = firstIntersectingTarget(
                in: formationTargets,
                candidateIndices: formationCandidateIndices,
                sweepRect: sweepRect,
                bulletY: current.y,
                overlapChecks: &overlapChecks
            ) {
                queueManualHit(.alien(alien: formationTarget.alien, node: formationTarget.node, isSwooper: false))
                removePlayerBullet(bulletNode)
                queuedHits += 1
                continue
            }

            playerBulletPreviousPositions[bulletID] = current
        }

        let detectMs = (CACurrentMediaTime() - detectStart) * 1000
        return ManualDetectionStats(
            bullets: bullets.count,
            targets: targets,
            candidateRefs: candidateRefs,
            overlapChecks: overlapChecks,
            queuedHits: queuedHits,
            detectMs: detectMs
        )
    }

    private func processPendingManualHitResolutions() -> ManualResolutionStats {
        let resolveStart = CACurrentMediaTime()
        guard !pendingManualHits.isEmpty else {
            return ManualResolutionStats(resolvedHits: 0, reducedFXHits: 0, queueDepth: 0, resolveMs: 0)
        }

        let maxPerFrame = max(1, GameConstants.Performance.manualResolutionMaxPerFrame)
        let budgetMs = max(0.5, GameConstants.Performance.manualResolutionBudgetMs)

        var resolvedHits = 0
        var reducedFXHits = 0

        while true {
            if resolvedHits >= maxPerFrame { break }
            let elapsedMs = (CACurrentMediaTime() - resolveStart) * 1000
            if elapsedMs >= budgetMs { break }

            guard let pending = pendingManualHits.popLast() else { break }

            let backlogAfterCurrent = pendingManualHits.count
            let preferLiteFX = GameConstants.Performance.manualResolutionPreferLiteFX
            let useReducedFX =
                preferLiteFX ||
                backlogAfterCurrent >= GameConstants.Performance.manualResolutionLiteFxBacklog ||
                elapsedMs >= budgetMs * 0.75

            switch pending.target {
            case let .alien(alien, node, isSwooper):
                guard alien.isAlive, node.parent != nil else { continue }
                PerformanceLog.manualCollisionType(isSwooper ? "playerBullet-swooper" : "playerBullet-enemy")
                resolvePlayerBulletHitsEnemy(alienNode: node, alienEntity: alien, reducedFX: useReducedFX)
                resolvedHits += 1
                if useReducedFX { reducedFXHits += 1 }

            case let .ufo(ufo, node):
                guard ufoEntity === ufo, node.parent != nil else { continue }
                PerformanceLog.manualCollisionType("playerBullet-ufo")
                resolvePlayerBulletHitsUFO(ufoNode: node, ufo: ufo, reducedFX: useReducedFX)
                resolvedHits += 1
                if useReducedFX { reducedFXHits += 1 }
            }
        }

        let resolveMs = (CACurrentMediaTime() - resolveStart) * 1000
        return ManualResolutionStats(
            resolvedHits: resolvedHits,
            reducedFXHits: reducedFXHits,
            queueDepth: pendingManualHits.count,
            resolveMs: resolveMs
        )
    }

    private func queueManualHit(_ target: PendingManualHit.Target) {
        pendingManualHits.append(PendingManualHit(target: target))
    }

    private func clearPendingManualHits() {
        pendingManualHits.removeAll(keepingCapacity: true)
    }

    private func buildSwooperTargets() -> [ManualAlienTarget] {
        var targets: [ManualAlienTarget] = []
        for entity in entities {
            guard let alien = entity as? AlienEntity,
                  alien.isAlive,
                  alien.isSwooping else { continue }
            let node = alien.spriteComponent.node
            guard node.parent != nil else { continue }

            let rect = worldRect(for: node)
            targets.append(ManualAlienTarget(node: node, rect: rect, centerY: node.position.y, alien: alien, isSwooper: true))
        }
        return targets
    }

    private func buildFormationTargets() -> [ManualAlienTarget] {
        guard let formation = alienFormation else { return [] }
        var targets: [ManualAlienTarget] = []

        for row in formation.aliens {
            for alien in row {
                guard let alien, alien.isAlive, !alien.isSwooping else { continue }
                let node = alien.spriteComponent.node
                guard node.parent != nil else { continue }

                let rect = worldRect(for: alien, in: formation)
                let centerY = rect.midY
                targets.append(ManualAlienTarget(node: node, rect: rect, centerY: centerY, alien: alien, isSwooper: false))
            }
        }
        return targets
    }

    private func buildBands(
        for targets: [ManualAlienTarget],
        bandHeight: CGFloat
    ) -> [Int: [Int]] {
        var bands: [Int: [Int]] = [:]
        for (index, target) in targets.enumerated() {
            let minBand = bandIndex(forY: target.rect.minY, bandHeight: bandHeight)
            let maxBand = bandIndex(forY: target.rect.maxY, bandHeight: bandHeight)
            if minBand <= maxBand {
                for band in minBand...maxBand {
                    bands[band, default: []].append(index)
                }
            }
        }
        return bands
    }

    private func candidateIndices(
        for sweepRect: CGRect,
        bands: [Int: [Int]],
        bandHeight: CGFloat
    ) -> [Int] {
        let minBand = bandIndex(forY: sweepRect.minY, bandHeight: bandHeight)
        let maxBand = bandIndex(forY: sweepRect.maxY, bandHeight: bandHeight)
        guard minBand <= maxBand else { return [] }

        var seen = Set<Int>()
        var indices: [Int] = []
        for band in minBand...maxBand {
            guard let bandIndices = bands[band] else { continue }
            for index in bandIndices where seen.insert(index).inserted {
                indices.append(index)
            }
        }
        return indices
    }

    private func firstIntersectingTarget(
        in targets: [ManualAlienTarget],
        candidateIndices: [Int],
        sweepRect: CGRect,
        bulletY: CGFloat,
        overlapChecks: inout Int
    ) -> ManualAlienTarget? {
        var best: (target: ManualAlienTarget, distance: CGFloat)?

        for index in candidateIndices {
            guard index >= 0, index < targets.count else { continue }
            let target = targets[index]
            guard target.alien.isAlive, target.node.parent != nil else { continue }

            overlapChecks += 1
            guard sweepRect.intersects(target.rect) else { continue }

            let distance = abs(target.centerY - bulletY)
            if let existing = best {
                if distance < existing.distance {
                    best = (target, distance)
                }
            } else {
                best = (target, distance)
            }
        }

        if let best {
            return best.target
        }
        return nil
    }

    private func bandIndex(forY y: CGFloat, bandHeight: CGFloat) -> Int {
        Int(floor(y / bandHeight))
    }

    private func sweptRect(from start: CGPoint, to end: CGPoint, size: CGSize) -> CGRect {
        let width = max(1, size.width)
        let height = max(1, size.height)
        let minX = min(start.x, end.x) - width / 2
        let minY = min(start.y, end.y) - height / 2
        let maxX = max(start.x, end.x) + width / 2
        let maxY = max(start.y, end.y) + height / 2
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private func worldRect(for node: SKSpriteNode) -> CGRect {
        let size = CGSize(
            width: node.size.width * abs(node.xScale),
            height: node.size.height * abs(node.yScale)
        )
        return CGRect(
            x: node.position.x - size.width / 2,
            y: node.position.y - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    private func worldRect(for alien: AlienEntity, in formation: AlienFormation) -> CGRect {
        let node = alien.spriteComponent.node
        let worldPos = formation.formationNode.convert(node.position, to: worldNode)
        let size = CGSize(
            width: alien.alienType.size.width * abs(node.xScale),
            height: alien.alienType.size.height * abs(node.yScale)
        )
        return CGRect(
            x: worldPos.x - size.width / 2,
            y: worldPos.y - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    // MARK: - Physics Contact

    func didBegin(_ contact: SKPhysicsContact) {
        PerformanceLog.begin("ContactHandler")
        defer { PerformanceLog.end("ContactHandler") }

        let (bodyA, bodyB) = (contact.bodyA, contact.bodyB)
        let maskA = bodyA.categoryBitMask
        let maskB = bodyB.categoryBitMask

        if !GameConstants.Performance.manualPlayerBulletCollision {
            // Player bullet hits enemy
            if (maskA == GameConstants.PhysicsCategory.playerBullet && maskB == GameConstants.PhysicsCategory.enemy) ||
               (maskB == GameConstants.PhysicsCategory.playerBullet && maskA == GameConstants.PhysicsCategory.enemy) {
                PerformanceLog.contactType("playerBullet-enemy")
                let bulletBody = maskA == GameConstants.PhysicsCategory.playerBullet ? bodyA : bodyB
                let alienBody = maskA == GameConstants.PhysicsCategory.enemy ? bodyA : bodyB
                handlePlayerBulletHitsEnemy(bulletBody: bulletBody, alienBody: alienBody)
                return
            }

            // Player bullet hits UFO
            if (maskA == GameConstants.PhysicsCategory.playerBullet && maskB == GameConstants.PhysicsCategory.ufo) ||
               (maskB == GameConstants.PhysicsCategory.playerBullet && maskA == GameConstants.PhysicsCategory.ufo) {
                PerformanceLog.contactType("playerBullet-ufo")
                let bulletBody = maskA == GameConstants.PhysicsCategory.playerBullet ? bodyA : bodyB
                let ufoBody = maskA == GameConstants.PhysicsCategory.ufo ? bodyA : bodyB
                handlePlayerBulletHitsUFO(bulletBody: bulletBody, ufoBody: ufoBody)
                return
            }
        }

        // Enemy bullet hits player
        if (maskA == GameConstants.PhysicsCategory.enemyBullet && maskB == GameConstants.PhysicsCategory.player) ||
           (maskB == GameConstants.PhysicsCategory.enemyBullet && maskA == GameConstants.PhysicsCategory.player) {
            PerformanceLog.contactType("enemyBullet-player")
            let bulletBody = maskA == GameConstants.PhysicsCategory.enemyBullet ? bodyA : bodyB
            let playerBody = maskA == GameConstants.PhysicsCategory.player ? bodyA : bodyB
            handleEnemyBulletHitsPlayer(bulletBody: bulletBody, playerBody: playerBody)
            return
        }

        // Player collects powerup
        if (maskA == GameConstants.PhysicsCategory.player && maskB == GameConstants.PhysicsCategory.powerup) ||
           (maskB == GameConstants.PhysicsCategory.player && maskA == GameConstants.PhysicsCategory.powerup) {
            PerformanceLog.contactType("player-powerup")
            let powerupBody = maskA == GameConstants.PhysicsCategory.powerup ? bodyA : bodyB
            handlePlayerCollectsPowerup(powerupBody: powerupBody)
            return
        }

        // Swooping alien hits player
        if (maskA == GameConstants.PhysicsCategory.enemy && maskB == GameConstants.PhysicsCategory.player) ||
           (maskB == GameConstants.PhysicsCategory.enemy && maskA == GameConstants.PhysicsCategory.player) {
            PerformanceLog.contactType("enemy-player")
            let alienBody = maskA == GameConstants.PhysicsCategory.enemy ? bodyA : bodyB
            handleSwooperHitsPlayer(alienBody: alienBody)
            return
        }

    }

    // MARK: - Collision Handlers

    private func handlePlayerBulletHitsEnemy(bulletBody: SKPhysicsBody, alienBody: SKPhysicsBody) {
        guard let bulletNode = bulletBody.node as? SKSpriteNode,
              let alienNode = alienBody.node as? SKSpriteNode else { return }
        guard let alienEntity = alienNode.userData?["entity"] as? AlienEntity else { return }
        handlePlayerBulletHitsEnemy(bulletNode: bulletNode, alienNode: alienNode, alienEntity: alienEntity)
    }

    private func handlePlayerBulletHitsEnemy(
        bulletNode: SKSpriteNode,
        alienNode: SKSpriteNode,
        alienEntity: AlienEntity
    ) {
        guard gameState == .playing else { return }
        resolvePlayerBulletHitsEnemy(alienNode: alienNode, alienEntity: alienEntity, reducedFX: false)
        removePlayerBullet(bulletNode)
    }

    private func resolvePlayerBulletHitsEnemy(
        alienNode: SKSpriteNode,
        alienEntity: AlienEntity,
        reducedFX: Bool
    ) {
        guard gameState == .playing || gameState == .levelTransition else { return }
        let wasSwooper = alienEntity.isSwooping

        #if DEBUG
        let shouldProfileResolve = GameConstants.Performance.manualResolveOutlierLogging
        let resolveStart = shouldProfileResolve ? CACurrentMediaTime() : 0
        var damageMs: Double = 0
        var sparkMs: Double = 0
        var audioMs: Double = 0
        var formationRemoveMs: Double = 0
        var scoreFxMs: Double = 0
        var powerupMs: Double = 0
        var cleanupMs: Double = 0
        var completionMs: Double = 0
        var droppedPowerup = false
        #endif

        // Spark effect at impact — swooping aliens are already in world coords.
        let impactPos: CGPoint
        if wasSwooper {
            impactPos = alienNode.position
        } else if let formationNode = alienNode.parent {
            impactPos = formationNode.convert(alienNode.position, to: worldNode)
        } else {
            impactPos = alienNode.position
        }

        // All aliens die in one hit.
        #if DEBUG
        let damageStart = shouldProfileResolve ? CACurrentMediaTime() : 0
        #endif
        let isDead = alienEntity.healthComponent.takeDamage(alienEntity.healthComponent.currentHP)
        #if DEBUG
        if shouldProfileResolve {
            damageMs = (CACurrentMediaTime() - damageStart) * 1000
        }
        #endif

        if !reducedFX {
            #if DEBUG
            let sparkStart = shouldProfileResolve ? CACurrentMediaTime() : 0
            #endif
            ParticleEffects.spawnSparkBurst(at: impactPos, in: worldNode.scene ?? self)
            #if DEBUG
            if shouldProfileResolve {
                sparkMs = (CACurrentMediaTime() - sparkStart) * 1000
            }
            #endif
        }

        if isDead {
            #if DEBUG
            let audioStart = shouldProfileResolve ? CACurrentMediaTime() : 0
            #endif
            playEnemyDeathSoundThrottled(reducedFX: reducedFX)
            if GameConstants.Haptic.alienKilled { HapticManager.shared.mediumImpact() }
            #if DEBUG
            if shouldProfileResolve {
                audioMs = (CACurrentMediaTime() - audioStart) * 1000
            }
            #endif

            if wasSwooper {
                // Swooper: clean up directly (already removed from grid).
                let scoreValue = bonusRoundActive ? GameConstants.bonusRoundKillScore : alienEntity.scoreValueComponent.value
                let scaledScore = scoreManager.scaledValue(scoreValue)
                #if DEBUG
                let scoreFxStart = shouldProfileResolve ? CACurrentMediaTime() : 0
                #endif
                if reducedFX {
                    ExplosionEffect.spawnScorePopup(at: impactPos, in: self, scoreValue: scaledScore)
                } else {
                    ExplosionEffect.spawn(at: impactPos, in: self, scoreValue: scaledScore)
                }
                scoreManager.addPoints(scoreValue)
                #if DEBUG
                if shouldProfileResolve {
                    scoreFxMs += (CACurrentMediaTime() - scoreFxStart) * 1000
                }
                #endif

                if !bonusRoundActive && Double.random(in: 0...1) < GameConstants.powerupDropChance * (1.0 + (columnDifficultyRatio - 1.0) * 0.75) {
                    #if DEBUG
                    let powerupStart = shouldProfileResolve ? CACurrentMediaTime() : 0
                    #endif
                    spawnPowerup(at: impactPos)
                    #if DEBUG
                    droppedPowerup = true
                    if shouldProfileResolve {
                        powerupMs += (CACurrentMediaTime() - powerupStart) * 1000
                    }
                    #endif
                }

                #if DEBUG
                let cleanupStart = shouldProfileResolve ? CACurrentMediaTime() : 0
                #endif
                alienEntity.isAlive = false
                alienEntity.isSwooping = false
                if bonusRoundActive { detachGoldTrail(from: alienNode) }
                alienNode.removeAllActions()
                alienNode.removeFromParent()
                swoopingAliens.removeAll { $0 === alienEntity }
                alienFormation?.swooperDestroyed()
                #if DEBUG
                if shouldProfileResolve {
                    cleanupMs += (CACurrentMediaTime() - cleanupStart) * 1000
                }
                #endif

                if bonusRoundActive {
                    #if DEBUG
                    let completionStart = shouldProfileResolve ? CACurrentMediaTime() : 0
                    #endif
                    bonusRoundHits += 1
                    bonusAliensResolved += 1
                    checkBonusRoundComplete()
                    #if DEBUG
                    if shouldProfileResolve {
                        completionMs += (CACurrentMediaTime() - completionStart) * 1000
                    }
                    #endif
                }
            } else {
                #if DEBUG
                let formationRemoveStart = shouldProfileResolve ? CACurrentMediaTime() : 0
                #endif
                alienFormation?.removeAlien(row: alienEntity.row, col: alienEntity.col)
                #if DEBUG
                if shouldProfileResolve {
                    formationRemoveMs += (CACurrentMediaTime() - formationRemoveStart) * 1000
                }
                #endif

                let scoreValue = alienEntity.scoreValueComponent.value
                let scaledScore = scoreManager.scaledValue(scoreValue)
                #if DEBUG
                let scoreFxStart = shouldProfileResolve ? CACurrentMediaTime() : 0
                #endif
                if reducedFX {
                    ExplosionEffect.spawnScorePopup(at: impactPos, in: self, scoreValue: scaledScore)
                } else {
                    ExplosionEffect.spawn(at: impactPos, in: self, scoreValue: scaledScore)
                }
                scoreManager.addPoints(scoreValue)
                #if DEBUG
                if shouldProfileResolve {
                    scoreFxMs += (CACurrentMediaTime() - scoreFxStart) * 1000
                }
                #endif

                // Chance to drop powerup (disabled in bonus rounds — those are scheduled).
                if !bonusRoundActive && Double.random(in: 0...1) < GameConstants.powerupDropChance * (1.0 + (columnDifficultyRatio - 1.0) * 0.75) {
                    #if DEBUG
                    let powerupStart = shouldProfileResolve ? CACurrentMediaTime() : 0
                    #endif
                    spawnPowerup(at: impactPos)
                    #if DEBUG
                    droppedPowerup = true
                    if shouldProfileResolve {
                        powerupMs += (CACurrentMediaTime() - powerupStart) * 1000
                    }
                    #endif
                }
            }
        } else if !reducedFX {
            #if DEBUG
            let cleanupStart = shouldProfileResolve ? CACurrentMediaTime() : 0
            #endif
            let colorize = SKAction.colorize(with: .white, colorBlendFactor: 1.0, duration: 0.05)
            let restore = SKAction.colorize(withColorBlendFactor: 0.0, duration: 0.1)
            alienNode.run(SKAction.sequence([colorize, restore]))
            #if DEBUG
            if shouldProfileResolve {
                cleanupMs += (CACurrentMediaTime() - cleanupStart) * 1000
            }
            #endif
        }

        #if DEBUG
        if shouldProfileResolve {
            let totalMs = (CACurrentMediaTime() - resolveStart) * 1000
            if totalMs >= GameConstants.Performance.manualResolveOutlierThresholdMs {
                PerformanceLog.event(
                    "ManualResolve",
                    "manualResolve kind=enemy total=\(String(format: "%.3f", totalMs))ms damage=\(String(format: "%.3f", damageMs)) spark=\(String(format: "%.3f", sparkMs)) audio=\(String(format: "%.3f", audioMs)) formationRemove=\(String(format: "%.3f", formationRemoveMs)) scoreFx=\(String(format: "%.3f", scoreFxMs)) powerup=\(String(format: "%.3f", powerupMs)) cleanup=\(String(format: "%.3f", cleanupMs)) completion=\(String(format: "%.3f", completionMs)) isDead=\(isDead) swooper=\(wasSwooper) reducedFX=\(reducedFX) droppedPowerup=\(droppedPowerup) level=\(currentLevel) bonus=\(bonusRoundActive)"
                )
            }
        }
        #endif
    }

    private func handleEnemyBulletHitsPlayer(bulletBody: SKPhysicsBody, playerBody: SKPhysicsBody) {
        guard let bulletNode = bulletBody.node else { return }

        // Ignore if not playing or player is invulnerable
        guard gameState == .playing else {
            bulletNode.removeFromParent()
            return
        }
        if playerEntity.isInvulnerable {
            bulletNode.removeFromParent()
            return
        }

        // Shield powerup absorbs the hit
        if playerEntity.hasShield {
            bulletNode.removeFromParent()
            playerEntity.clearPowerup(.shield)
            return
        }

        // Capture snapshot while bullet is still visible
        captureImpactSnapshot()
        bulletNode.removeFromParent()

        AudioManager.shared.play(GameConstants.Sound.playerHit)
        powerupIndicator.hide(type: .extraLife)
        let isDead = playerEntity.healthComponent.takeDamage(1)
        livesDisplay.update(lives: playerEntity.healthComponent.currentHP)

        if isDead {
            handlePlayerDeath()
        } else {
            respawnPlayer()
        }
    }

    private func handlePlayerBulletHitsUFO(bulletBody: SKPhysicsBody, ufoBody: SKPhysicsBody) {
        guard let bulletNode = bulletBody.node as? SKSpriteNode,
              let ufoNode = ufoBody.node as? SKSpriteNode else { return }
        guard let ufo = ufoNode.userData?["entity"] as? UFOEntity else { return }
        handlePlayerBulletHitsUFO(bulletNode: bulletNode, ufoNode: ufoNode, ufo: ufo)
    }

    private func handlePlayerBulletHitsUFO(
        bulletNode: SKSpriteNode,
        ufoNode: SKSpriteNode,
        ufo: UFOEntity
    ) {
        guard gameState == .playing || gameState == .levelTransition else { return }
        resolvePlayerBulletHitsUFO(ufoNode: ufoNode, ufo: ufo, reducedFX: false)
        removePlayerBullet(bulletNode)
    }

    private func resolvePlayerBulletHitsUFO(
        ufoNode: SKSpriteNode,
        ufo: UFOEntity,
        reducedFX: Bool
    ) {
        guard gameState == .playing || gameState == .levelTransition else { return }

        #if DEBUG
        let shouldProfileResolve = GameConstants.Performance.manualResolveOutlierLogging
        let resolveStart = shouldProfileResolve ? CACurrentMediaTime() : 0
        var sparkMs: Double = 0
        var damageMs: Double = 0
        var audioMs: Double = 0
        var scoreFxMs: Double = 0
        var cleanupMs: Double = 0
        #endif

        // Spark effect.
        if !reducedFX {
            #if DEBUG
            let sparkStart = shouldProfileResolve ? CACurrentMediaTime() : 0
            #endif
            ParticleEffects.spawnSparkBurst(at: ufoNode.position, in: self)
            #if DEBUG
            if shouldProfileResolve {
                sparkMs = (CACurrentMediaTime() - sparkStart) * 1000
            }
            #endif
        }

        #if DEBUG
        let damageStart = shouldProfileResolve ? CACurrentMediaTime() : 0
        #endif
        let isDead = ufo.healthComponent.takeDamage(1)
        #if DEBUG
        if shouldProfileResolve {
            damageMs = (CACurrentMediaTime() - damageStart) * 1000
        }
        #endif

        if isDead {
            #if DEBUG
            let audioStart = shouldProfileResolve ? CACurrentMediaTime() : 0
            #endif
            AudioManager.shared.play(GameConstants.Sound.ufoDestroyed)
            if GameConstants.Haptic.ufoDestroyed { HapticManager.shared.mediumImpact() }
            #if DEBUG
            if shouldProfileResolve {
                audioMs = (CACurrentMediaTime() - audioStart) * 1000
            }
            #endif

            let worldPos = ufoNode.position
            let scoreValue = ufo.scoreValueComponent.value
            let scaledScore = scoreManager.scaledValue(scoreValue)
            #if DEBUG
            let scoreFxStart = shouldProfileResolve ? CACurrentMediaTime() : 0
            #endif
            if reducedFX {
                ExplosionEffect.spawnScorePopup(at: worldPos, in: self, scoreValue: scaledScore)
            } else {
                ExplosionEffect.spawn(at: worldPos, in: self, scoreValue: scaledScore)
            }
            scoreManager.addPoints(scoreValue)
            #if DEBUG
            if shouldProfileResolve {
                scoreFxMs = (CACurrentMediaTime() - scoreFxStart) * 1000
            }
            #endif

            #if DEBUG
            let cleanupStart = shouldProfileResolve ? CACurrentMediaTime() : 0
            #endif
            AudioManager.shared.stopLoop(GameConstants.Sound.ufoAmbience)
            ufoNode.removeFromParent()
            ufoEntity = nil
            #if DEBUG
            if shouldProfileResolve {
                cleanupMs = (CACurrentMediaTime() - cleanupStart) * 1000
            }
            #endif
        } else if !reducedFX {
            #if DEBUG
            let cleanupStart = shouldProfileResolve ? CACurrentMediaTime() : 0
            #endif
            let blink = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.2, duration: 0.05),
                SKAction.fadeAlpha(to: 1.0, duration: 0.1)
            ])
            ufoNode.run(blink)
            #if DEBUG
            if shouldProfileResolve {
                cleanupMs = (CACurrentMediaTime() - cleanupStart) * 1000
            }
            #endif
        }

        #if DEBUG
        if shouldProfileResolve {
            let totalMs = (CACurrentMediaTime() - resolveStart) * 1000
            if totalMs >= GameConstants.Performance.manualResolveOutlierThresholdMs {
                PerformanceLog.event(
                    "ManualResolve",
                    "manualResolve kind=ufo total=\(String(format: "%.3f", totalMs))ms spark=\(String(format: "%.3f", sparkMs)) damage=\(String(format: "%.3f", damageMs)) audio=\(String(format: "%.3f", audioMs)) scoreFx=\(String(format: "%.3f", scoreFxMs)) cleanup=\(String(format: "%.3f", cleanupMs)) isDead=\(isDead) reducedFX=\(reducedFX) level=\(currentLevel) bonus=\(bonusRoundActive)"
                )
            }
        }
        #endif
    }

    private func handlePlayerCollectsPowerup(powerupBody: SKPhysicsBody) {
        guard gameState == .playing || gameState == .levelTransition else { return }
        guard let powerupNode = powerupBody.node as? SKSpriteNode,
              let powerup = powerupNode.userData?["entity"] as? PowerupEntity else { return }

        // Play per-powerup sound, falling back to generic collect sound
        let powerupSound: String
        switch powerup.type {
        case .rapidFire:  powerupSound = GameConstants.Sound.powerupRapidFire
        case .spreadShot: powerupSound = GameConstants.Sound.powerupSpreadShot
        case .shield:     powerupSound = GameConstants.Sound.powerupShield
        case .extraLife:  powerupSound = GameConstants.Sound.powerupExtraLife
        }
        AudioManager.shared.play(powerupSound.isEmpty ? GameConstants.Sound.powerupCollect : powerupSound)
        if GameConstants.Haptic.powerupCollected { HapticManager.shared.mediumImpact() }

        playerEntity.applyPowerup(powerup.type)

        // Show powerup indicator (extra life stays until next ship lost)
        powerupIndicator.show(type: powerup.type)

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

        // Damage the player
        if playerEntity.isInvulnerable {
            destroySwoopingAlien(alienEntity, hitPlayer: true)
            return
        }

        if playerEntity.hasShield {
            destroySwoopingAlien(alienEntity, hitPlayer: true)
            playerEntity.clearPowerup(.shield)
            ScreenShakeEffect.shake(node: worldNode, duration: 0.3, intensity: 6)
            return
        }

        // Capture snapshot while swooper is still visible, then destroy it
        captureImpactSnapshot()
        destroySwoopingAlien(alienEntity, hitPlayer: true)

        AudioManager.shared.play(GameConstants.Sound.playerHit)
        powerupIndicator.hide(type: .extraLife)
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
        // Log current level stats + session summary before game over
        PerformanceLog.levelComplete(level: currentLevel, isBonus: bonusRoundActive, aliveAliens: alienFormation?.aliveCount ?? 0, fireInterval: currentEnemyFireInterval)
        PerformanceLog.sessionEnd(finalLevel: currentLevel, score: scoreManager.currentScore)

        gameState = .gameOver
        clearPendingManualHits()
        playerEntity.shootingComponent.isFiring = false
        playerEntity.clearAllPowerups()
        powerupIndicator.hide(type: .extraLife)

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
        let cx = size.width / 2
        let hasInset = impactSnapshot != nil

        // Layout from top down: title, inset, score, [high score], button
        let insetW: CGFloat = 300 * hs
        let insetH: CGFloat = 210 * hs
        let padding: CGFloat = 15 * hs

        // Title at top of group
        let titleY = size.height / 2 + (hasInset ? (insetH / 2 + padding + 30 * hs) : 40 * hs)
        let label = makeOverlayLabel(text: "GAME OVER", fontSize: 48)
        label.position = CGPoint(x: cx, y: titleY)
        overlay.addChild(label)

        // Inset below title
        if let inset = makeImpactInset(width: insetW, height: insetH) {
            let insetY = titleY - 30 * hs - padding - insetH / 2
            inset.position = CGPoint(x: cx, y: insetY)
            overlay.addChild(inset)
        }

        let belowInsetY = hasInset
            ? (titleY - 30 * hs - padding - insetH - padding * 2)
            : (size.height / 2 - 20 * hs)

        let scoreLabel = makeOverlayLabel(text: "SCORE: \(scoreManager.currentScore)", fontSize: 28)
        scoreLabel.position = CGPoint(x: cx, y: belowInsetY)
        overlay.addChild(scoreLabel)

        if isNewHigh {
            let highLabel = makeOverlayLabel(text: "NEW HIGH SCORE!", fontSize: 22)
            highLabel.position = CGPoint(x: cx, y: belowInsetY - 40 * hs)
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
        button.position = CGPoint(x: cx, y: belowInsetY - (isNewHigh ? 90 * hs : 60 * hs))
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
            self.removePlayerBullet(node)
        }
        clearTrackedPlayerBullets()
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

        // Freeze the game world and dim it
        worldNode.isPaused = true
        worldNode.alpha = 0.5
        starfieldNode?.isPaused = true

        // Show "SHIP DESTROYED" message with remaining lives
        let lives = playerEntity.healthComponent.currentHP
        let hs = GameConstants.hudScale

        let msgNode = SKNode()
        msgNode.zPosition = GameConstants.ZPosition.overlay

        let cx = size.width / 2
        let hasInset = impactSnapshot != nil
        let insetW: CGFloat = 300 * hs
        let insetH: CGFloat = 210 * hs
        let padding: CGFloat = 15 * hs

        // Title at top
        let titleY = size.height / 2 + (hasInset ? (insetH / 2 + padding + 22 * hs) : 20 * hs)
        let destroyedLabel = makeOverlayLabel(text: "SHIP DESTROYED", fontSize: 36)
        destroyedLabel.position = CGPoint(x: cx, y: titleY)
        msgNode.addChild(destroyedLabel)

        // Inset below title
        if let inset = makeImpactInset(width: insetW, height: insetH) {
            let insetY = titleY - 22 * hs - padding - insetH / 2
            inset.position = CGPoint(x: cx, y: insetY)
            msgNode.addChild(inset)
        }

        let belowInsetY = hasInset
            ? (titleY - 22 * hs - padding - insetH - padding * 2)
            : (size.height / 2 - 20 * hs)

        let livesText = lives == 1 ? "1 SHIP REMAINING" : "\(lives) SHIPS REMAINING"
        let livesLabel = makeOverlayLabel(text: livesText, fontSize: 22)
        livesLabel.position = CGPoint(x: cx, y: belowInsetY)
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

                // Restore world opacity, unfreeze, and clean up snapshot
                self.worldNode.alpha = 1.0
                self.worldNode.isPaused = false
                self.starfieldNode?.isPaused = false
                self.impactSnapshot = nil

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
        impactSnapshot = nil

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
            self.removePlayerBullet(node)
        }
        clearTrackedPlayerBullets()
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

        // Reset bonus round state
        bonusAliensTotal = 0
        bonusAliensResolved = 0
        bonusRoundHits = 0
        for i in 0..<5 { removeAction(forKey: "bonusWave\(i)") }

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
        powerupIndicator.hideAll()

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

        PerformanceLog.levelComplete(level: currentLevel, isBonus: false, aliveAliens: 0, fireInterval: currentEnemyFireInterval)

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
                    self.removePlayerBullet(node)
                }
                self.clearTrackedPlayerBullets()
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
        playerEntity.clearAllPowerups()
        powerupIndicator.hide(type: .extraLife)

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
        let nextConfig = LevelManager.config(forLevel: currentLevel)

        var labels: [SKLabelNode] = []

        if nextConfig.isBonusRound {
            let bonusLabel = makeOverlayLabel(text: "BONUS ROUND", fontSize: 48, gold: true)
            bonusLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 + 25 * hs)
            overlay.addChild(bonusLabel)
            labels.append(bonusLabel)

            let subtitleLabel = makeOverlayLabel(text: "Take them out!", fontSize: 28, gold: true)
            subtitleLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 - 35 * hs)
            overlay.addChild(subtitleLabel)
            labels.append(subtitleLabel)
        } else {
            let levelLabel = makeOverlayLabel(text: "LEVEL", fontSize: 48)
            levelLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 + 25 * hs)
            overlay.addChild(levelLabel)
            labels.append(levelLabel)

            let numberLabel = makeOverlayLabel(text: "\(currentLevel)", fontSize: 56)
            numberLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 - 35 * hs)
            overlay.addChild(numberLabel)
            labels.append(numberLabel)
        }

        // Bounce-in animation for text
        for label in labels {
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
        let hasLevelStartAction = action(forKey: "levelStart") != nil
        PerformanceLog.event(
            "LevelFlow",
            "startNextLevel level=\(currentLevel) bonusActive=\(bonusRoundActive) overlay=\(overlayNode != nil) hasLevelStart=\(hasLevelStartAction) scenePaused=\(isPaused) worldPaused=\(worldNode.isPaused)"
        )
        if GameConstants.Haptic.levelComplete { HapticManager.shared.success() }

        // Remove overlay
        overlayNode?.removeFromParent()
        overlayNode = nil
        impactSnapshot = nil

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

        // Check if the new level is a bonus round
        let config = LevelManager.config(forLevel: currentLevel)
        bonusRoundActive = config.isBonusRound

        // Reset player position
        playerEntity.spriteComponent.node.position = CGPoint(x: size.width / 2, y: size.height * 0.142)

        if bonusRoundActive {
            print("Bonus round active for level \(currentLevel)")
            gameState = .playing
            startBonusRound()
        } else {
            // Create new formation (setupAliens uses LevelManager)
            setupAliens()

            // Pause firing and animate aliens appearing
            playerEntity.shootingComponent.isFiring = false
            gameState = .levelTransition
            AudioManager.shared.play(GameConstants.Sound.levelStart)

            alienFormation?.animateEntrance { [weak self] in
                self?.gameState = .playing
            }
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

        // Looping ambience via AudioManager (preloaded AVAudioEngine path).
        let ambienceSound = GameConstants.Sound.ufoAmbience
        if !ambienceSound.isEmpty && !AudioManager.shared.isMuted(ambienceSound) {
            AudioManager.shared.playLoop(ambienceSound)
        }
    }

    private func removeUFO() {
        AudioManager.shared.stopLoop(GameConstants.Sound.ufoAmbience)
        ufoEntity?.spriteComponent.node.removeFromParent()
        ufoEntity = nil
    }

    // MARK: - UI Helpers

    private func makeOverlayLabel(text: String, fontSize: CGFloat, gold: Bool = false) -> SKLabelNode {
        let scaledSize = fontSize * GameConstants.hudScale
        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.text = text
        label.fontSize = scaledSize
        label.fontColor = gold
            ? SKColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 1.0)
            : SKColor(red: 0.3, green: 0.85, blue: 0.3, alpha: 1.0)
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center

        // Shadow/outline effect via a duplicate label behind
        let shadow = SKLabelNode(fontNamed: "Menlo-Bold")
        shadow.text = text
        shadow.fontSize = scaledSize
        shadow.fontColor = gold
            ? SKColor(red: 0.4, green: 0.3, blue: 0.05, alpha: 1.0)
            : SKColor(red: 0.1, green: 0.3, blue: 0.1, alpha: 1.0)
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

    // MARK: - Impact Snapshot

    private func captureImpactSnapshot() {
        guard let view = self.view else { return }
        impactPlayerPosition = playerEntity.spriteComponent.node.position
        impactSnapshot = view.texture(from: self)
    }

    private func makeImpactInset(width: CGFloat, height: CGFloat) -> SKNode? {
        guard let snapshot = impactSnapshot else { return nil }

        let container = SKNode()

        // Crop node to show the scene at actual size, centered on player
        let cropNode = SKCropNode()
        let maskNode = SKSpriteNode(color: .white, size: CGSize(width: width, height: height))
        cropNode.maskNode = maskNode

        let snapshotSprite = SKSpriteNode(texture: snapshot)
        let zoomScale: CGFloat = 1.5
        snapshotSprite.setScale(zoomScale)

        // Offset so the player position is centered in the crop window
        let texW = snapshot.size().width
        let texH = snapshot.size().height
        let normX = impactPlayerPosition.x / size.width
        let normY = impactPlayerPosition.y / size.height
        let offsetX = texW / 2 - normX * texW
        let offsetY = texH / 2 - normY * texH
        snapshotSprite.position = CGPoint(x: offsetX * zoomScale, y: offsetY * zoomScale)

        cropNode.addChild(snapshotSprite)
        container.addChild(cropNode)

        // Green border frame
        let borderRect = CGRect(x: -width / 2 - 1, y: -height / 2 - 1, width: width + 2, height: height + 2)
        let border = SKShapeNode(rect: borderRect)
        border.strokeColor = SKColor(red: 0.3, green: 0.85, blue: 0.3, alpha: 0.8)
        border.lineWidth = 2
        border.fillColor = .clear
        container.addChild(border)

        return container
    }

    private func monitorTransitionWatchdog(currentTime: TimeInterval) {
        guard gameState == .levelTransition else {
            transitionStallStartedAt = 0
            lastTransitionWatchdogLogAt = 0
            return
        }

        let hasOverlay = overlayNode != nil
        let hasLevelStart = action(forKey: "levelStart") != nil
        let hasWaitForClear = action(forKey: "waitForClear") != nil
        let hasWaitForClearTimeout = action(forKey: "waitForClearTimeout") != nil
        let likelyStalled = hasOverlay && !hasLevelStart && !hasWaitForClear

        guard likelyStalled else {
            transitionStallStartedAt = 0
            lastTransitionWatchdogLogAt = 0
            return
        }

        if transitionStallStartedAt == 0 {
            transitionStallStartedAt = currentTime
        }

        let stalledFor = currentTime - transitionStallStartedAt
        let shouldLog = stalledFor >= 2.0 &&
            (lastTransitionWatchdogLogAt == 0 || currentTime - lastTransitionWatchdogLogAt >= 2.0)
        guard shouldLog else { return }

        lastTransitionWatchdogLogAt = currentTime
        PerformanceLog.event(
            "TransitionWatchdog",
            "stalledFor=\(String(format: "%.2f", stalledFor))s level=\(currentLevel) bonusActive=\(bonusRoundActive) overlay=\(hasOverlay) levelStart=\(hasLevelStart) waitForClear=\(hasWaitForClear) waitTimeout=\(hasWaitForClearTimeout) scenePaused=\(isPaused) worldPaused=\(worldNode.isPaused) pendingHits=\(pendingManualHits.count)"
        )
    }

    // MARK: - Update

    override func update(_ currentTime: TimeInterval) {
        PerformanceLog.begin("FrameTotal")

        if lastUpdateTime == 0 {
            lastUpdateTime = currentTime
        }

        let dt = currentTime - lastUpdateTime

        if gameState == .playing || gameState == .levelTransition {
            PerformanceLog.begin("EntityUpdates")
            for entity in entities {
                entity.update(deltaTime: dt)
            }
            PerformanceLog.end("EntityUpdates")

            // Track UFO removal (flew off-screen)
            if let ufo = ufoEntity, ufo.spriteComponent.node.parent == nil {
                removeUFO()
            }

            if GameConstants.Performance.manualPlayerBulletCollision {
                PerformanceLog.begin("ManualPlayerBulletCollision")
                runManualPlayerBulletCollisions()
                PerformanceLog.end("ManualPlayerBulletCollision")
            }
        }

        if gameState == .playing && !isRespawning {
            PerformanceLog.begin("FormationUpdate")
            alienFormation?.update(deltaTime: dt)
            PerformanceLog.end("FormationUpdate")

            // Update player vertical ceiling
            if bonusRoundActive {
                playerEntity.movementComponent.maxY = size.height * 0.9
            } else if let lowestY = alienFormation?.lowestAlienY() {
                let ceiling = lowestY - PlayerEntity.shipSize.height
                playerEntity.movementComponent.maxY = max(playerEntity.movementComponent.minY, ceiling)
            }

            // Enemy fire timer (paused during respawn and bonus rounds)
            if !isRespawning && !bonusRoundActive {
                enemyFireTimer += dt
                if enemyFireTimer >= currentEnemyFireInterval {
                    enemyFireTimer = 0
                    spawnEnemyBullet()
                }
            }

            // UFO spawn timer (disabled during bonus rounds)
            if !bonusRoundActive {
                ufoSpawnTimer += dt
                if ufoSpawnTimer >= nextUfoSpawnInterval {
                    ufoSpawnTimer = 0
                    nextUfoSpawnInterval = randomUFOInterval()
                    spawnUFO()
                }
            }

            // Swoop timer (paused during respawn and bonus rounds)
            if !isRespawning && !bonusRoundActive {
                swoopTimer += dt
            }
            if swoopTimer >= currentSwoopInterval && !bonusRoundActive {
                swoopTimer = 0
                initiateSwoop()
            }

            // Pause firing when nothing to shoot at, during respawn, or resume if UFO appears
            let shouldFire = !isRespawning &&
                ((alienFormation?.aliveCount ?? 0) > 0 || !swoopingAliens.isEmpty || ufoEntity != nil || bonusRoundActive)
            if shouldFire != playerEntity.shootingComponent.isFiring {
                playerEntity.shootingComponent.isFiring = shouldFire
            }

            // Check if aliens reached the bottom (instant game over, disabled in bonus rounds)
            if !bonusRoundActive {
                PerformanceLog.begin("CheckBottom")
                checkAliensReachedBottom()
                PerformanceLog.end("CheckBottom")
            }

            // Check level completion
            PerformanceLog.begin("CheckComplete")
            checkLevelComplete()
            PerformanceLog.end("CheckComplete")
        }

        // Clean up entities whose sprites have been removed from the scene (runs in all states)
        PerformanceLog.begin("EntityCleanup")
        entities.removeAll { entity in
            if let spriteComp = entity.component(ofType: SpriteComponent.self) {
                return spriteComp.node.parent == nil
            }
            return false
        }
        PerformanceLog.end("EntityCleanup")

        PerformanceLog.end("FrameTotal")
        PerformanceLog.recordFrame(
            dt: dt,
            entityCount: entities.count,
            nodeCount: worldNode.children.count,
            spriteCount: worldNode.children.filter { $0 is SKSpriteNode }.count,
            emitterCount: worldNode.children.filter { $0 is SKEmitterNode }.count,
            swoopCount: swoopingAliens.count
        )

        monitorTransitionWatchdog(currentTime: currentTime)
        lastUpdateTime = currentTime
    }
}
