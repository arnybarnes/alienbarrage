//
//  ShootingComponent.swift
//  Alien Barrage
//

import SpriteKit
import GameplayKit

class ShootingComponent: GKComponent {

    var fireRate: TimeInterval
    var isFiring: Bool = false
    var fireCallback: (() -> Void)?

    private var timeSinceLastShot: TimeInterval = 0

    init(fireRate: TimeInterval) {
        self.fireRate = fireRate
        super.init()
    }

    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    override func update(deltaTime seconds: TimeInterval) {
        timeSinceLastShot += seconds

        if isFiring && timeSinceLastShot >= fireRate {
            timeSinceLastShot = 0
            fireCallback?()
        }
    }
}
