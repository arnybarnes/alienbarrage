//
//  SpriteSheet.swift
//  Alien Barrage
//

import SpriteKit

/// Singleton that loads the spritesheet and vends named SKTexture objects.
/// All pixel coordinates are defined relative to the top-left of the 1024×1024 image.
class SpriteSheet {

    static let shared = SpriteSheet()

    let texture: SKTexture
    let sheetWidth: CGFloat = 1024.0
    let sheetHeight: CGFloat = 1024.0

    /// Pixel rects for each sprite (x, y, width, height) — y measured from top of image
    private let spriteRects: [String: CGRect] = [
        // Large Aliens - top row (4 heads, ~125×125 each)
        "alienLarge1": CGRect(x: 2, y: 2, width: 125, height: 125),
        "alienLarge2": CGRect(x: 132, y: 2, width: 125, height: 125),
        "alienLarge3": CGRect(x: 260, y: 2, width: 125, height: 125),
        "alienLarge4": CGRect(x: 388, y: 2, width: 125, height: 125),

        // UFO / Mothership - top right
        "ufo": CGRect(x: 530, y: 0, width: 440, height: 200),

        // Medium Aliens - second row (4 aliens, ~125×115 each)
        "alienMedium1": CGRect(x: 2, y: 135, width: 125, height: 115),
        "alienMedium2": CGRect(x: 132, y: 135, width: 125, height: 115),
        "alienMedium3": CGRect(x: 260, y: 135, width: 125, height: 115),
        "alienMedium4": CGRect(x: 388, y: 135, width: 125, height: 115),

        // Small Aliens / Fighter sprites - middle area
        "alienSmall1": CGRect(x: 225, y: 345, width: 65, height: 72),
        "alienSmall2": CGRect(x: 300, y: 345, width: 65, height: 72),
        "alienSmall3": CGRect(x: 375, y: 345, width: 65, height: 72),
        "alienSmall4": CGRect(x: 450, y: 345, width: 65, height: 72),

        // Orange Explosions
        "explosionOrange1": CGRect(x: 2, y: 262, width: 125, height: 120),
        "explosionOrange2": CGRect(x: 2, y: 680, width: 148, height: 148),
        "explosionOrange3": CGRect(x: 2, y: 845, width: 148, height: 148),

        // Projectiles
        "playerBullet": CGRect(x: 138, y: 260, width: 26, height: 80),
        "playerMissile": CGRect(x: 175, y: 258, width: 36, height: 85),
        "enemyBullet": CGRect(x: 222, y: 270, width: 30, height: 65),

        // Powerup orbs / targeting items (green circles)
        "powerupRapidFire": CGRect(x: 268, y: 280, width: 58, height: 52),
        "powerupSpreadShot": CGRect(x: 340, y: 280, width: 58, height: 52),

        // Green Explosions - right side (2 rows of 3)
        "explosionGreen1": CGRect(x: 540, y: 258, width: 148, height: 148),
        "explosionGreen2": CGRect(x: 700, y: 258, width: 148, height: 148),
        "explosionGreen3": CGRect(x: 855, y: 258, width: 148, height: 148),
        "explosionGreen4": CGRect(x: 540, y: 418, width: 148, height: 148),
        "explosionGreen5": CGRect(x: 700, y: 418, width: 148, height: 148),
        "explosionGreen6": CGRect(x: 855, y: 418, width: 148, height: 148),

        // Player Ship - large, bottom-left with blue engines
        "playerShip": CGRect(x: 5, y: 395, width: 185, height: 265),

        // Powerup items (below player ship area)
        "powerupShield": CGRect(x: 210, y: 448, width: 58, height: 52),
        "powerupExtraLife": CGRect(x: 280, y: 448, width: 58, height: 52),

        // Shield / Barrier blocks
        "shield1": CGRect(x: 355, y: 490, width: 78, height: 68),
        "shield2": CGRect(x: 445, y: 490, width: 78, height: 68),

        // UI Text
        "levelStart": CGRect(x: 340, y: 640, width: 315, height: 38),
        "gameOver": CGRect(x: 340, y: 688, width: 300, height: 38),
        "plus100": CGRect(x: 535, y: 790, width: 120, height: 32),

        // Digits 0-9 (reading "1234567890" left to right from the sheet)
        "digit1": CGRect(x: 342, y: 738, width: 28, height: 32),
        "digit2": CGRect(x: 376, y: 738, width: 28, height: 32),
        "digit3": CGRect(x: 410, y: 738, width: 28, height: 32),
        "digit4": CGRect(x: 444, y: 738, width: 28, height: 32),
        "digit5": CGRect(x: 478, y: 738, width: 28, height: 32),
        "digit6": CGRect(x: 512, y: 738, width: 28, height: 32),
        "digit7": CGRect(x: 546, y: 738, width: 28, height: 32),
        "digit8": CGRect(x: 580, y: 738, width: 28, height: 32),
        "digit9": CGRect(x: 614, y: 738, width: 28, height: 32),
        "digit0": CGRect(x: 648, y: 738, width: 28, height: 32),

        // More green explosions (bottom-right area)
        "explosionGreen7": CGRect(x: 700, y: 580, width: 155, height: 155),
        "explosionGreen8": CGRect(x: 855, y: 700, width: 148, height: 148),
        "explosionGreen9": CGRect(x: 855, y: 855, width: 148, height: 148),
    ]

    private var textureCache: [String: SKTexture] = [:]

    private init() {
        texture = SKTexture(imageNamed: "spritesheet")
        texture.filteringMode = .nearest
    }

    /// Returns a named texture from the spritesheet.
    /// Converts pixel coordinates (top-left origin) to normalized SpriteKit texture coordinates (bottom-left origin).
    func sprite(named name: String) -> SKTexture? {
        if let cached = textureCache[name] {
            return cached
        }

        guard let pixelRect = spriteRects[name] else {
            print("SpriteSheet: Unknown sprite '\(name)'")
            return nil
        }

        let normalizedRect = CGRect(
            x: pixelRect.origin.x / sheetWidth,
            y: 1.0 - (pixelRect.origin.y + pixelRect.size.height) / sheetHeight,
            width: pixelRect.size.width / sheetWidth,
            height: pixelRect.size.height / sheetHeight
        )

        let tex = SKTexture(rect: normalizedRect, in: texture)
        tex.filteringMode = .nearest
        textureCache[name] = tex
        return tex
    }

    /// Convenience to get a digit texture (0-9)
    func digitTexture(_ digit: Int) -> SKTexture? {
        let clamped = max(0, min(9, digit))
        return sprite(named: "digit\(clamped)")
    }

    /// Returns a list of all available sprite names
    var availableSprites: [String] {
        return Array(spriteRects.keys).sorted()
    }
}
