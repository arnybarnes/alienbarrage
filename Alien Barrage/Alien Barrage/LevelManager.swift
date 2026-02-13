//
//  LevelManager.swift
//  Alien Barrage
//

import SpriteKit

struct LevelConfig {
    let level: Int
    let rows: Int
    let cols: Int
    let baseSpeed: CGFloat
    let fireInterval: TimeInterval
    let alienHPBonus: Int
}

enum LevelManager {

    static func config(forLevel level: Int) -> LevelConfig {
        switch level {
        case 1:
            return LevelConfig(
                level: 1,
                rows: 4, cols: 5,
                baseSpeed: 40,
                fireInterval: 2.0,
                alienHPBonus: 0
            )
        case 2:
            return LevelConfig(
                level: 2,
                rows: 4, cols: 6,
                baseSpeed: 48,
                fireInterval: 1.8,
                alienHPBonus: 0
            )
        default:
            let rows = min(6, 4 + level / 3)
            let cols = min(8, 5 + level / 2)
            let baseSpeed = CGFloat(40 + level * 8)
            let fireInterval = max(0.6, 2.0 - Double(level) * 0.15)
            let alienHPBonus = level / 4
            return LevelConfig(
                level: level,
                rows: rows, cols: cols,
                baseSpeed: baseSpeed,
                fireInterval: fireInterval,
                alienHPBonus: alienHPBonus
            )
        }
    }
}
