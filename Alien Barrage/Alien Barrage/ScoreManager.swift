//
//  ScoreManager.swift
//  Alien Barrage
//

import Foundation

class ScoreManager {

    private(set) var currentScore: Int = 0
    private(set) var highScore: Int = 0
    var scoreMultiplier: Double = 1.0

    var onScoreChanged: ((Int) -> Void)?

    func scaledValue(_ points: Int) -> Int {
        Int(round(Double(points) * scoreMultiplier))
    }

    func addPoints(_ points: Int) {
        currentScore += scaledValue(points)
        if currentScore > highScore {
            highScore = currentScore
        }
        onScoreChanged?(currentScore)
    }

    func addRawPoints(_ points: Int) {
        currentScore += points
        if currentScore > highScore {
            highScore = currentScore
        }
        onScoreChanged?(currentScore)
    }

    func reset() {
        currentScore = 0
        onScoreChanged?(currentScore)
    }
}
