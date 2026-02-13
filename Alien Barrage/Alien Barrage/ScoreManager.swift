//
//  ScoreManager.swift
//  Alien Barrage
//

import Foundation

class ScoreManager {

    private(set) var currentScore: Int = 0
    private(set) var highScore: Int = 0

    var onScoreChanged: ((Int) -> Void)?

    func addPoints(_ points: Int) {
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
