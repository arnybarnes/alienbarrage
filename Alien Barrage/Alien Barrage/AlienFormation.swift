//
//  AlienFormation.swift
//  Alien Barrage
//

import SpriteKit
import GameplayKit

class AlienFormation {

    /// 2D grid of aliens [row][col], nil = destroyed
    private(set) var aliens: [[AlienEntity?]]
    let rows: Int
    let cols: Int

    /// Parent node — all alien sprites are children of this node
    let formationNode: SKNode

    /// Movement
    private var direction: CGFloat = 1.0  // +1 = right, -1 = left
    private var speed: CGFloat
    private let baseSpeed: CGFloat
    private let totalAliens: Int
    private let sceneWidth: CGFloat
    private var justReversed: Bool = false

    /// Number of aliens currently swooping (removed from grid but still alive)
    private(set) var swoopingCount: Int = 0

    var aliveCount: Int {
        aliens.flatMap { $0 }.compactMap { $0 }.filter { $0.isAlive }.count
    }

    var allDestroyed: Bool {
        aliveCount == 0 && swoopingCount == 0
    }

    init(rows: Int, cols: Int, sceneSize: CGSize, speedMultiplier: CGFloat = 1.0, alienHPBonus: Int = 0) {
        self.rows = rows
        self.cols = cols
        self.sceneWidth = sceneSize.width
        self.baseSpeed = GameConstants.alienBaseSpeed * speedMultiplier
        self.speed = GameConstants.alienBaseSpeed * speedMultiplier
        self.totalAliens = rows * cols
        self.formationNode = SKNode()
        self.aliens = []

        // Calculate spacing that ensures the formation fits with room to move.
        // Available width = sceneWidth minus edge margins minus largest alien width minus movement buffer.
        let edgeMargin: CGFloat = 10.0
        let maxAlienHalfWidth: CGFloat = max(AlienType.large.size.width, AlienType.small.size.width) / 2.0
        let movementBuffer: CGFloat = 40.0
        let maxGridWidth = sceneSize.width - 2 * (edgeMargin + maxAlienHalfWidth) - movementBuffer
        let spacingX: CGFloat = cols > 1
            ? min(GameConstants.alienSpacingX, maxGridWidth / CGFloat(cols - 1))
            : 0

        // Build the grid
        var grid: [[AlienEntity?]] = []
        for row in 0..<rows {
            var rowArray: [AlienEntity?] = []
            // Top 2 rows = large, bottom rows = small
            let type: AlienType = row < 2 ? .large : .small

            for col in 0..<cols {
                let alien = AlienEntity(type: type, row: row, col: col, hpBonus: alienHPBonus)

                // Position within the formation (row 0 = top)
                let x = CGFloat(col) * spacingX
                let y = -CGFloat(row) * GameConstants.alienSpacingY
                alien.spriteComponent.node.position = CGPoint(x: x, y: y)

                formationNode.addChild(alien.spriteComponent.node)
                rowArray.append(alien)
            }
            grid.append(rowArray)
        }
        self.aliens = grid

        // Center the formation horizontally
        let gridWidth = CGFloat(cols - 1) * spacingX
        let startX = (sceneSize.width - gridWidth) / 2.0
        let startY = sceneSize.height - 160

        formationNode.position = CGPoint(x: startX, y: startY)
    }

    // MARK: - Update

    func update(deltaTime dt: TimeInterval) {
        // Move horizontally
        formationNode.position.x += speed * direction * CGFloat(dt)

        // Check if any alive alien has reached the screen edge.
        // Skip check for one frame after reversing to prevent rapid re-triggers.
        if justReversed {
            justReversed = false
        } else if shouldReverseDirection() {
            direction *= -1
            formationNode.position.y -= GameConstants.alienStepDown
            justReversed = true
        }
    }

    private func shouldReverseDirection() -> Bool {
        let margin: CGFloat = 10.0

        for row in aliens {
            for alien in row {
                guard let alien = alien, alien.isAlive else { continue }
                let worldPos = formationNode.convert(alien.spriteComponent.node.position, to: formationNode.parent!)

                if direction > 0 && worldPos.x + alien.alienType.size.width / 2 >= sceneWidth - margin {
                    return true
                }
                if direction < 0 && worldPos.x - alien.alienType.size.width / 2 <= margin {
                    return true
                }
            }
        }
        return false
    }

    // MARK: - Alien Management

    func removeAlien(row: Int, col: Int) {
        guard row >= 0, row < rows, col >= 0, col < cols else { return }
        guard let alien = aliens[row][col], alien.isAlive else { return }

        alien.isAlive = false
        alien.spriteComponent.node.removeFromParent()
        aliens[row][col] = nil

        // Speed up as aliens are destroyed
        let destroyed = totalAliens - aliveCount
        speed = baseSpeed * (1.0 + CGFloat(destroyed) * GameConstants.alienSpeedMultiplierPerKill)
    }

    /// Returns the lowest alive alien in a given column
    func lowestAlien(inColumn col: Int) -> AlienEntity? {
        for row in stride(from: rows - 1, through: 0, by: -1) {
            if let alien = aliens[row][col], alien.isAlive {
                return alien
            }
        }
        return nil
    }

    // MARK: - Swooping

    /// Picks a random bottom-row alien, removes it from the grid, reparents it into
    /// `worldParent`, and returns the entity + its world position.
    func extractRandomSwooper(into worldParent: SKNode) -> (AlienEntity, CGPoint)? {
        guard let parent = formationNode.parent else { return nil }

        // Collect the lowest alive alien in each column
        var candidates: [(AlienEntity, Int, Int)] = []
        for col in 0..<cols {
            for row in stride(from: rows - 1, through: 0, by: -1) {
                if let alien = aliens[row][col], alien.isAlive {
                    candidates.append((alien, row, col))
                    break
                }
            }
        }
        guard let (alien, row, col) = candidates.randomElement() else { return nil }

        // Convert position to world coordinates before reparenting
        let worldPos = formationNode.convert(alien.spriteComponent.node.position, to: parent)

        // Remove from grid
        aliens[row][col] = nil
        swoopingCount += 1

        // Reparent sprite from formation to world
        let node = alien.spriteComponent.node
        node.removeFromParent()
        node.position = worldPos
        worldParent.addChild(node)

        // Stop bounce animation so the swoop path isn't fighting it
        node.removeAction(forKey: "alienAliveMotion")
        node.setScale(1.0)

        alien.isSwooping = true
        return (alien, worldPos)
    }

    /// Called when a swooping alien is destroyed or flies off-screen.
    func swooperDestroyed() {
        swoopingCount = max(0, swoopingCount - 1)
    }

    /// Returns the world Y position of the lowest alive alien
    func lowestAlienY() -> CGFloat? {
        guard let parent = formationNode.parent else { return nil }
        var lowestY: CGFloat = .greatestFiniteMagnitude
        for row in aliens {
            for alien in row {
                guard let alien = alien, alien.isAlive else { continue }
                let worldPos = formationNode.convert(alien.spriteComponent.node.position, to: parent)
                lowestY = min(lowestY, worldPos.y)
            }
        }
        return lowestY == .greatestFiniteMagnitude ? nil : lowestY
    }
}
