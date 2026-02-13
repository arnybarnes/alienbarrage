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
        "alienLarge1": CGRect(x: 70, y: 74, width: 171, height: 214),
        "alienLarge2": CGRect(x: 298, y: 74, width: 173, height: 212),
        "alienLarge3": CGRect(x: 534, y: 74, width: 196, height: 216),
        "alienLarge4": CGRect(x: 767, y: 74, width: 199, height: 212),

        // Medium Aliens - Row 2 (4 spider aliens)
        "alienMedium1": CGRect(x: 48, y: 330, width: 207, height: 172),
        "alienMedium2": CGRect(x: 278, y: 330, width: 217, height: 169),
        "alienMedium3": CGRect(x: 531, y: 330, width: 203, height: 170),
        "alienMedium4": CGRect(x: 769, y: 330, width: 198, height: 169),

        // Small Aliens - Row 3 (4 small drones)
        "alienSmall1": CGRect(x: 81, y: 546, width: 145, height: 115),
        "alienSmall2": CGRect(x: 298, y: 537, width: 172, height: 123),
        "alienSmall3": CGRect(x: 536, y: 536, width: 189, height: 125),
        "alienSmall4": CGRect(x: 789, y: 535, width: 159, height: 122),

        // ── TOP-RIGHT QUADRANT (1024,0)-(2048,1024): Boss aliens + projectiles ──

        // Boss / Elite Aliens (3 large crab aliens)
        "alienBoss1": CGRect(x: 1074, y: 15, width: 280, height: 265),
        "alienBoss2": CGRect(x: 1394, y: 15, width: 280, height: 265),
        "alienBoss3": CGRect(x: 1714, y: 15, width: 280, height: 265),

        // Projectiles - bottom strip of top-right quadrant
        "playerBullet": CGRect(x: 1190, y: 650, width: 68, height: 275),
        "playerMissile": CGRect(x: 1450, y: 730, width: 48, height: 82),
        "enemyBullet": CGRect(x: 1507, y: 657, width: 474, height: 111),

        // ── BOTTOM-LEFT QUADRANT (0,1024)-(1024,2048): Player, UFO, shields, text ──

        // Player Ship - ship body + blue engine flames
        "playerShip": CGRect(x: 42, y: 1061, width: 417, height: 459),

        // UFO / Mothership saucer
        "ufo": CGRect(x: 510, y: 1142, width: 449, height: 211),

        // Shield / Barrier blocks
        "shield1": CGRect(x: 88, y: 1686, width: 170, height: 150),
        "shield2": CGRect(x: 310, y: 1686, width: 170, height: 150),

        // UI Text (pixel-measured from spritesheet)
        "levelStart": CGRect(x: 97, y: 1859, width: 339, height: 34),
        "level": CGRect(x: 97, y: 1859, width: 158, height: 34),
        "gameOver": CGRect(x: 469, y: 1859, width: 268, height: 34),
        "plus100": CGRect(x: 773, y: 1859, width: 151, height: 34),

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

        // Powerup icons (4 circular badges near top of bottom-right quadrant)
        "powerupRapidFire": CGRect(x: 1127, y: 1122, width: 154, height: 155),
        "powerupSpreadShot": CGRect(x: 1351, y: 1124, width: 154, height: 151),
        "powerupShield": CGRect(x: 1563, y: 1118, width: 161, height: 166),
        "powerupExtraLife": CGRect(x: 1785, y: 1123, width: 160, height: 155),

        // Green Explosions - Row 1 (early, mid, peak)
        // Verified via PIL pixel scan: green clouds at y=1330-1560
        "explosionGreen1": CGRect(x: 1024, y: 1325, width: 341, height: 235),
        "explosionGreen2": CGRect(x: 1365, y: 1325, width: 341, height: 235),
        "explosionGreen3": CGRect(x: 1706, y: 1325, width: 342, height: 235),

        // Orange Explosions - Row 2 (early, mid, peak)
        // Verified via PIL pixel scan: orange clouds at y=1565-1765
        "explosionOrange1": CGRect(x: 1024, y: 1565, width: 341, height: 200),
        "explosionOrange2": CGRect(x: 1365, y: 1565, width: 341, height: 200),
        "explosionOrange3": CGRect(x: 1706, y: 1565, width: 342, height: 200),

        // Dissipating Explosions - Row 3 (fade-out frames)
        // Verified via PIL pixel scan: fading clouds at y=1800-1945
        "explosionFade1": CGRect(x: 1024, y: 1800, width: 341, height: 145),
        "explosionFade2": CGRect(x: 1365, y: 1800, width: 341, height: 145),
        "explosionFade3": CGRect(x: 1706, y: 1800, width: 342, height: 145),
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
