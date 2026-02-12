//
//  ScoreValueComponent.swift
//  Alien Barrage
//

import GameplayKit

class ScoreValueComponent: GKComponent {

    let value: Int

    init(value: Int) {
        self.value = value
        super.init()
    }

    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
}
