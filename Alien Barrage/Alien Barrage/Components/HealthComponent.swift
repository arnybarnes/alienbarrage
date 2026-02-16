//
//  HealthComponent.swift
//  Alien Barrage
//

import GameplayKit

class HealthComponent: GKComponent {

    let maxHP: Int
    private(set) var currentHP: Int

    init(hp: Int) {
        self.maxHP = hp
        self.currentHP = hp
        super.init()
    }

    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    /// Applies damage. Returns true if the entity is now dead (HP <= 0).
    func takeDamage(_ amount: Int) -> Bool {
        currentHP -= amount
        return currentHP <= 0
    }

    /// Restores HP (uncapped — spawn rules gate extra-life availability).
    func heal(_ amount: Int) {
        currentHP += amount
    }
}
