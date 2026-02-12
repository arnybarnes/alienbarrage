//
//  SpriteSheet.swift
//  Alien Barrage
//

import SpriteKit

/// Singleton that loads the spritesheet and vends named SKTexture objects.
/// All pixel coordinates are defined relative to the top-left of the 1536×1024 image.
class SpriteSheet {

    static let shared = SpriteSheet()

    let texture: SKTexture
    let sheetWidth: CGFloat = 1536.0
    let sheetHeight: CGFloat = 1024.0

    /// Pixel rects for each sprite (x, y, width, height) — y measured from top of image
    private let spriteRects: [String: CGRect] = [
        // Large Aliens - top row
        "alienLarge1": CGRect(x: 5, y: 5, width: 130, height: 155),
        "alienLarge2": CGRect(x: 145, y: 5, width: 130, height: 155),
        "alienLarge3": CGRect(x: 285, y: 5, width: 130, height: 155),
        "alienLarge4": CGRect(x: 425, y: 5, width: 130, height: 155),
        "alienLarge5": CGRect(x: 565, y: 5, width: 130, height: 155),
        "alienLarge6": CGRect(x: 705, y: 5, width: 130, height: 155),

        // UFO / Mothership - top right
        "ufo": CGRect(x: 890, y: 0, width: 350, height: 235),

        // Medium Aliens - second row
        "alienMedium1": CGRect(x: 5, y: 170, width: 112, height: 118),
        "alienMedium2": CGRect(x: 130, y: 170, width: 112, height: 118),
        "alienMedium3": CGRect(x: 255, y: 170, width: 112, height: 118),
        "alienMedium4": CGRect(x: 380, y: 170, width: 112, height: 118),
        "alienMedium5": CGRect(x: 505, y: 170, width: 112, height: 118),
        "alienMedium6": CGRect(x: 630, y: 170, width: 112, height: 118),

        // Small Aliens - third row
        "alienSmall1": CGRect(x: 5, y: 300, width: 85, height: 85),
        "alienSmall2": CGRect(x: 100, y: 300, width: 85, height: 85),
        "alienSmall3": CGRect(x: 195, y: 300, width: 85, height: 85),
        "alienSmall4": CGRect(x: 290, y: 300, width: 85, height: 85),

        // Projectiles
        "playerBullet": CGRect(x: 340, y: 310, width: 22, height: 54),
        "playerMissile": CGRect(x: 375, y: 300, width: 30, height: 68),
        "enemyBullet": CGRect(x: 420, y: 310, width: 22, height: 54),

        // Green Explosions - right side
        "explosionGreen1": CGRect(x: 900, y: 270, width: 135, height: 135),
        "explosionGreen2": CGRect(x: 1055, y: 270, width: 135, height: 135),
        "explosionGreen3": CGRect(x: 1210, y: 270, width: 135, height: 135),
        "explosionGreen4": CGRect(x: 900, y: 420, width: 135, height: 135),
        "explosionGreen5": CGRect(x: 1055, y: 420, width: 135, height: 135),
        "explosionGreen6": CGRect(x: 1210, y: 420, width: 135, height: 135),

        // Orange Explosions - left side, below aliens
        "explosionOrange1": CGRect(x: 5, y: 420, width: 145, height: 145),
        "explosionOrange2": CGRect(x: 165, y: 420, width: 145, height: 145),

        // Small Ships - center area
        "ship1": CGRect(x: 275, y: 440, width: 80, height: 95),
        "ship2": CGRect(x: 365, y: 440, width: 80, height: 95),
        "ship3": CGRect(x: 455, y: 440, width: 80, height: 95),
        "ship4": CGRect(x: 545, y: 440, width: 80, height: 95),

        // Player Ship - large, bottom-left with blue engines
        "playerShip": CGRect(x: 15, y: 580, width: 235, height: 420),

        // UI Text
        "levelStart": CGRect(x: 680, y: 555, width: 465, height: 68),
        "gameOver": CGRect(x: 680, y: 640, width: 435, height: 68),
        "plus100": CGRect(x: 680, y: 730, width: 155, height: 52),

        // Shield / Barrier blocks
        "shield1": CGRect(x: 350, y: 770, width: 85, height: 85),
        "shield2": CGRect(x: 445, y: 770, width: 85, height: 85),

        // Powerups
        "powerupGreen": CGRect(x: 545, y: 770, width: 65, height: 65),
        "powerupShield": CGRect(x: 620, y: 770, width: 65, height: 65),

        // Digits 0-9 (reading "1234567890" left to right from the sheet)
        "digit1": CGRect(x: 835, y: 815, width: 44, height: 54),
        "digit2": CGRect(x: 885, y: 815, width: 44, height: 54),
        "digit3": CGRect(x: 935, y: 815, width: 44, height: 54),
        "digit4": CGRect(x: 985, y: 815, width: 44, height: 54),
        "digit5": CGRect(x: 1035, y: 815, width: 44, height: 54),
        "digit6": CGRect(x: 1085, y: 815, width: 44, height: 54),
        "digit7": CGRect(x: 1135, y: 815, width: 44, height: 54),
        "digit8": CGRect(x: 1185, y: 815, width: 44, height: 54),
        "digit9": CGRect(x: 1235, y: 815, width: 44, height: 54),
        "digit0": CGRect(x: 1285, y: 815, width: 44, height: 54),
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
