//
//  PlayerEntity.swift
//  Alien Barrage
//

import SpriteKit
import GameplayKit

class PlayerEntity: GKEntity {

    let spriteComponent: SpriteComponent
    let movementComponent: MovementComponent
    let shootingComponent: ShootingComponent

    static let shipSize = CGSize(width: 80, height: 110)

    init(sceneSize: CGSize) {
        guard let texture = SpriteSheet.shared.sprite(named: "playerShip") else {
            fatalError("Missing playerShip texture")
        }

        spriteComponent = SpriteComponent(texture: texture, size: PlayerEntity.shipSize)
        movementComponent = MovementComponent(
            speed: GameConstants.playerSpeed,
            sceneWidth: sceneSize.width,
            spriteHalfWidth: PlayerEntity.shipSize.width / 2
        )
        shootingComponent = ShootingComponent(fireRate: GameConstants.playerFireRate)

        super.init()

        addComponent(spriteComponent)
        addComponent(movementComponent)
        addComponent(shootingComponent)

        let node = spriteComponent.node
        node.position = CGPoint(x: sceneSize.width / 2, y: 80)
        node.zPosition = GameConstants.ZPosition.player
    }

    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
}
