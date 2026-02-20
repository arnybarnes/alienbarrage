import SwiftUI
import Combine

enum Difficulty: String, CaseIterable, Identifiable {
    case easy, normal, hard
    var id: String { rawValue }
}

class GameSettings: ObservableObject {
    @Published var difficulty: Difficulty {
        didSet { UserDefaults.standard.set(difficulty.rawValue, forKey: "difficulty") }
    }
    @Published var autofireSpeed: Double {
        didSet { UserDefaults.standard.set(autofireSpeed, forKey: "autofireSpeed") }
    }
    /// Debug toggle — set to false to prevent powerup drops (for perf testing)
    var powerupsEnabled = true


    init() {
        let diffRaw = UserDefaults.standard.string(forKey: "difficulty") ?? "normal"
        self.difficulty = Difficulty(rawValue: diffRaw) ?? .normal
        let speed = UserDefaults.standard.double(forKey: "autofireSpeed")
        self.autofireSpeed = speed > 0 ? min(max(speed, 0.2), 1.0) : 0.2
    }

    var effectiveLives: Int {
        switch difficulty {
        case .easy: return 5
        case .normal: return GameConstants.playerLives
        case .hard: return 2
        }
    }

    var effectiveAlienSpeedMultiplier: CGFloat {
        switch difficulty {
        case .easy: return 0.75
        case .normal: return 1.0
        case .hard: return 1.3
        }
    }

    var effectiveEnemyFireIntervalMultiplier: Double {
        switch difficulty {
        case .easy: return 1.4
        case .normal: return 1.0
        case .hard: return 0.7
        }
    }

    var effectiveFireRate: TimeInterval {
        autofireSpeed
    }

    var scoreMultiplier: Double {
        let difficultyMult: Double
        switch difficulty {
        case .easy: difficultyMult = 0.75
        case .normal: difficultyMult = 1.0
        case .hard: difficultyMult = 1.5
        }
        // Fire speed: 0.2 (fast) → 0.75x, 1.0 (slow) → 1.25x
        let fireSpeedMult = 0.75 + (autofireSpeed - 0.2) / 0.8 * 0.5
        return difficultyMult * fireSpeedMult
    }
}
