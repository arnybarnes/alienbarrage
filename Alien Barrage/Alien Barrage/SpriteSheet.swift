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

    /// Pixel rects for each sprite (x, y, width, height) — y measured from top of image.
    /// Layout reflects the compact 1024x1024 sheet currently in use.
    private let spriteRects: [String: CGRect] = [
        // Core gameplay sprites still sourced from this sheet.
        "playerBullet": CGRect(x: 253, y: 388, width: 54, height: 170),
        "playerShip": CGRect(x: 309, y: 581, width: 160, height: 124),
        "ufo": CGRect(x: 38, y: 599, width: 226, height: 95),
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

        // Aliens are now sourced from a dedicated spritesheet.
        if let alienTexture = AlienSpriteSheet.shared.sprite(named: name) {
            textureCache[name] = alienTexture
            return alienTexture
        }

        // Powerups are now sourced from a dedicated spin spritesheet.
        if let powerupTexture = PowerupSpinSheet.shared.baseTexture(named: name) {
            textureCache[name] = powerupTexture
            return powerupTexture
        }

        // Explosions are now sourced from a dedicated spritesheet.
        if let explosionTexture = ExplosionSpriteSheet.shared.sprite(named: name) {
            textureCache[name] = explosionTexture
            return explosionTexture
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

    /// Returns a UIImage for a named sprite (for use in SwiftUI).
    func uiImage(named name: String) -> UIImage? {
        guard let tex = sprite(named: name) else { return nil }
        let cgImage = tex.cgImage()
        return UIImage(cgImage: cgImage)
    }

    /// Returns a list of all available sprite names
    var availableSprites: [String] {
        return Array(spriteRects.keys).sorted()
    }
}
