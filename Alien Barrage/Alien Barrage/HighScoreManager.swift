import Foundation

class HighScoreManager {
    static let shared = HighScoreManager()

    private let key = "alienBarrage_highScores"
    private let maxScores = 10

    var topScores: [Int] {
        UserDefaults.standard.array(forKey: key) as? [Int] ?? []
    }

    var highScore: Int {
        topScores.first ?? 0
    }

    @discardableResult
    func submit(score: Int) -> Bool {
        guard score > 0 else { return false }
        var scores = topScores
        scores.append(score)
        scores.sort(by: >)
        if scores.count > maxScores {
            scores = Array(scores.prefix(maxScores))
        }
        UserDefaults.standard.set(scores, forKey: key)
        return scores.contains(score)
    }

    private init() {}
}
