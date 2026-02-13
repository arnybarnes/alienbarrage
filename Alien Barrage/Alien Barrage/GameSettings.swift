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

    init() {
        let diffRaw = UserDefaults.standard.string(forKey: "difficulty") ?? "normal"
        self.difficulty = Difficulty(rawValue: diffRaw) ?? .normal
        let speed = UserDefaults.standard.double(forKey: "autofireSpeed")
        self.autofireSpeed = speed > 0 ? speed : 0.25
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
}
