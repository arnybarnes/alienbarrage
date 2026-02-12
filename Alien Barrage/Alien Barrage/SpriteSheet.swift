//
//  SpriteSheet.swift
//  Alien Barrage
//

import SpriteKit

/// Singleton that loads the spritesheet and vends named SKTexture objects.
/// All pixel coordinates are defined relative to the top-left of the 2048×2048 image.
class SpriteSheet {

    static let shared = SpriteSheet()

    let texture: SKTexture
    let sheetWidth: CGFloat = 2048.0
    let sheetHeight: CGFloat = 2048.0

    /// Pixel rects for each sprite (x, y, width, height) — y measured from top of image.
    /// Layout: TL(0,0) = aliens, TR(1024,0) = boss aliens + projectiles,
    ///         BL(0,1024) = player/UFO/shields/text, BR(1024,1024) = powerups/explosions
    private let spriteRects: [String: CGRect] = [
        // ── TOP-LEFT QUADRANT (0,0)-(1024,1024): Alien sprites ──

        // Large Aliens - Row 1 (4 skull heads)
        "alienLarge1": CGRect(x: 73, y: 76, width: 166, height: 154),
        "alienLarge2": CGRect(x: 301, y: 76, width: 167, height: 154),
        "alienLarge3": CGRect(x: 539, y: 76, width: 189, height: 154),
        "alienLarge4": CGRect(x: 771, y: 76, width: 190, height: 154),

        // Medium Aliens - Row 2 (4 spider aliens)
        "alienMedium1": CGRect(x: 50, y: 220, width: 202, height: 230),
        "alienMedium2": CGRect(x: 280, y: 220, width: 212, height: 230),
        "alienMedium3": CGRect(x: 533, y: 220, width: 199, height: 230),
        "alienMedium4": CGRect(x: 770, y: 220, width: 195, height: 230),

        // Small Aliens - Row 3 (4 small drones)
        "alienSmall1": CGRect(x: 54, y: 440, width: 196, height: 219),
        "alienSmall2": CGRect(x: 280, y: 440, width: 212, height: 218),
        "alienSmall3": CGRect(x: 534, y: 440, width: 197, height: 219),
        "alienSmall4": CGRect(x: 774, y: 440, width: 189, height: 215),

        // ── TOP-RIGHT QUADRANT (1024,0)-(2048,1024): Boss aliens + projectiles ──

        // Boss / Elite Aliens (3 large crab aliens)
        "alienBoss1": CGRect(x: 1074, y: 15, width: 280, height: 265),
        "alienBoss2": CGRect(x: 1394, y: 15, width: 280, height: 265),
        "alienBoss3": CGRect(x: 1714, y: 15, width: 280, height: 265),

        // Projectiles - bottom strip of top-right quadrant
        "playerBullet": CGRect(x: 1190, y: 650, width: 68, height: 275),
        "playerMissile": CGRect(x: 1450, y: 730, width: 48, height: 82),
        "enemyBullet": CGRect(x: 1540, y: 715, width: 435, height: 70),

        // ── BOTTOM-LEFT QUADRANT (0,1024)-(1024,2048): Player, UFO, shields, text ──

        // Player Ship - ship body + blue engine flames
        "playerShip": CGRect(x: 42, y: 1061, width: 417, height: 459),

        // UFO / Mothership saucer
        "ufo": CGRect(x: 375, y: 1088, width: 470, height: 175),

        // Shield / Barrier blocks
        "shield1": CGRect(x: 88, y: 1686, width: 170, height: 150),
        "shield2": CGRect(x: 310, y: 1686, width: 170, height: 150),

        // UI Text
        "levelStart": CGRect(x: 62, y: 1864, width: 228, height: 34),
        "gameOver": CGRect(x: 318, y: 1864, width: 208, height: 34),
        "plus100": CGRect(x: 552, y: 1864, width: 88, height: 34),

        // Digits 0-9 (reading "0123456789" left to right)
        "digit0": CGRect(x: 72, y: 1944, width: 30, height: 38),
        "digit1": CGRect(x: 121, y: 1944, width: 30, height: 38),
        "digit2": CGRect(x: 170, y: 1944, width: 30, height: 38),
        "digit3": CGRect(x: 219, y: 1944, width: 30, height: 38),
        "digit4": CGRect(x: 268, y: 1944, width: 30, height: 38),
        "digit5": CGRect(x: 317, y: 1944, width: 30, height: 38),
        "digit6": CGRect(x: 366, y: 1944, width: 30, height: 38),
        "digit7": CGRect(x: 415, y: 1944, width: 30, height: 38),
        "digit8": CGRect(x: 464, y: 1944, width: 30, height: 38),
        "digit9": CGRect(x: 513, y: 1944, width: 30, height: 38),

        // ── BOTTOM-RIGHT QUADRANT (1024,1024)-(2048,2048): Powerups, explosions ──

        // Powerup orbs (4 colored orbs across top)
        "powerupRapidFire": CGRect(x: 1129, y: 1054, width: 110, height: 110),
        "powerupSpreadShot": CGRect(x: 1354, y: 1054, width: 110, height: 110),
        "powerupShield": CGRect(x: 1579, y: 1054, width: 110, height: 110),
        "powerupExtraLife": CGRect(x: 1804, y: 1054, width: 110, height: 110),

        // Green Explosions - Row 1 (early, mid, peak)
        "explosionGreen1": CGRect(x: 1074, y: 1204, width: 280, height: 260),
        "explosionGreen2": CGRect(x: 1394, y: 1204, width: 280, height: 260),
        "explosionGreen3": CGRect(x: 1714, y: 1204, width: 280, height: 260),

        // Orange Explosions - Row 2 (early, mid, peak)
        "explosionOrange1": CGRect(x: 1074, y: 1494, width: 280, height: 260),
        "explosionOrange2": CGRect(x: 1394, y: 1494, width: 280, height: 260),
        "explosionGreen4": CGRect(x: 1714, y: 1494, width: 280, height: 260),

        // Dissipating Explosions - Row 3 (fade-out frames)
        "explosionGreen5": CGRect(x: 1074, y: 1784, width: 280, height: 230),
        "explosionGreen6": CGRect(x: 1394, y: 1784, width: 280, height: 230),
        "explosionGreen7": CGRect(x: 1714, y: 1784, width: 280, height: 230),
        "explosionGreen8": CGRect(x: 1074, y: 1494, width: 280, height: 260),
        "explosionGreen9": CGRect(x: 1394, y: 1494, width: 280, height: 260),
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
