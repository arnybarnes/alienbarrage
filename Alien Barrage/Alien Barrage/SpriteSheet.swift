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
        // Large Aliens - top row (6 heads, each ~148×160, row starts at y≈0)
        "alienLarge1": CGRect(x: 0, y: 0, width: 148, height: 160),
        "alienLarge2": CGRect(x: 148, y: 0, width: 148, height: 160),
        "alienLarge3": CGRect(x: 296, y: 0, width: 148, height: 160),
        "alienLarge4": CGRect(x: 444, y: 0, width: 148, height: 160),
        "alienLarge5": CGRect(x: 592, y: 0, width: 148, height: 160),
        "alienLarge6": CGRect(x: 740, y: 0, width: 148, height: 160),

        // UFO / Mothership - top right
        "ufo": CGRect(x: 900, y: 0, width: 380, height: 250),

        // Medium Aliens - second row (6 aliens, each ~148×135, row starts at y≈165)
        "alienMedium1": CGRect(x: 0, y: 165, width: 148, height: 135),
        "alienMedium2": CGRect(x: 148, y: 165, width: 148, height: 135),
        "alienMedium3": CGRect(x: 296, y: 165, width: 148, height: 135),
        "alienMedium4": CGRect(x: 444, y: 165, width: 148, height: 135),
        "alienMedium5": CGRect(x: 592, y: 165, width: 148, height: 135),
        "alienMedium6": CGRect(x: 740, y: 165, width: 148, height: 135),

        // Small Aliens - third row (row starts at y≈310)
        "alienSmall1": CGRect(x: 0, y: 310, width: 100, height: 95),
        "alienSmall2": CGRect(x: 105, y: 310, width: 100, height: 95),
        "alienSmall3": CGRect(x: 210, y: 310, width: 100, height: 95),
        "alienSmall4": CGRect(x: 315, y: 310, width: 100, height: 95),

        // Projectiles (middle area)
        "playerBullet": CGRect(x: 420, y: 315, width: 28, height: 60),
        "playerMissile": CGRect(x: 460, y: 310, width: 35, height: 72),
        "enemyBullet": CGRect(x: 508, y: 315, width: 28, height: 60),

        // Green Explosions - right side (two rows of 3)
        "explosionGreen1": CGRect(x: 920, y: 280, width: 150, height: 150),
        "explosionGreen2": CGRect(x: 1080, y: 280, width: 150, height: 150),
        "explosionGreen3": CGRect(x: 1240, y: 280, width: 150, height: 150),
        "explosionGreen4": CGRect(x: 920, y: 440, width: 150, height: 150),
        "explosionGreen5": CGRect(x: 1080, y: 440, width: 150, height: 150),
        "explosionGreen6": CGRect(x: 1240, y: 440, width: 150, height: 150),

        // Orange Explosions - left side, below aliens
        "explosionOrange1": CGRect(x: 0, y: 420, width: 155, height: 155),
        "explosionOrange2": CGRect(x: 165, y: 420, width: 155, height: 155),

        // Small Ships - center area (below small aliens/projectiles)
        "ship1": CGRect(x: 285, y: 445, width: 88, height: 105),
        "ship2": CGRect(x: 380, y: 445, width: 88, height: 105),
        "ship3": CGRect(x: 475, y: 445, width: 88, height: 105),
        "ship4": CGRect(x: 570, y: 445, width: 88, height: 105),

        // Player Ship - large, bottom-left with blue engines
        "playerShip": CGRect(x: 10, y: 570, width: 250, height: 440),

        // UI Text
        "levelStart": CGRect(x: 665, y: 548, width: 490, height: 75),
        "gameOver": CGRect(x: 665, y: 635, width: 465, height: 75),
        "plus100": CGRect(x: 665, y: 725, width: 170, height: 58),

        // Shield / Barrier blocks
        "shield1": CGRect(x: 340, y: 760, width: 95, height: 95),
        "shield2": CGRect(x: 445, y: 760, width: 95, height: 95),

        // Powerups
        "powerupGreen": CGRect(x: 550, y: 765, width: 75, height: 75),
        "powerupShield": CGRect(x: 635, y: 765, width: 75, height: 75),

        // Digits 0-9 (reading "1234567890" left to right from the sheet)
        "digit1": CGRect(x: 830, y: 810, width: 50, height: 58),
        "digit2": CGRect(x: 886, y: 810, width: 50, height: 58),
        "digit3": CGRect(x: 942, y: 810, width: 50, height: 58),
        "digit4": CGRect(x: 998, y: 810, width: 50, height: 58),
        "digit5": CGRect(x: 1054, y: 810, width: 50, height: 58),
        "digit6": CGRect(x: 1110, y: 810, width: 50, height: 58),
        "digit7": CGRect(x: 1166, y: 810, width: 50, height: 58),
        "digit8": CGRect(x: 1222, y: 810, width: 50, height: 58),
        "digit9": CGRect(x: 1278, y: 810, width: 50, height: 58),
        "digit0": CGRect(x: 1334, y: 810, width: 50, height: 58),
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
