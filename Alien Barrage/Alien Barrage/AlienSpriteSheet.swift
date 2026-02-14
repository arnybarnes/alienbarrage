//
//  AlienSpriteSheet.swift
//  Alien Barrage
//

import SpriteKit

/// Dedicated spritesheet loader for alien art sourced from `aliens3.png`.
final class AlienSpriteSheet {

    static let shared = AlienSpriteSheet()

    private let texture: SKTexture
    private let sheetWidth: CGFloat = 1024.0
    private let sheetHeight: CGFloat = 1024.0

    /// Pixel rects for the alien variants in `aliens3.png`.
    /// Coordinates use top-left origin.
    private let spriteRects: [String: CGRect] = [
        // Large tier
        "alienLarge1": CGRect(x: 19,  y: 39,  width: 251, height: 206),
        "alienLarge2": CGRect(x: 725, y: 55,  width: 285, height: 193),
        "alienLarge3": CGRect(x: 281, y: 60,  width: 191, height: 171),
        "alienLarge4": CGRect(x: 482, y: 69,  width: 232, height: 168),

        // Medium tier
        "alienMedium1": CGRect(x: 292, y: 270, width: 165, height: 156),
        "alienMedium2": CGRect(x: 476, y: 271, width: 244, height: 169),
        "alienMedium3": CGRect(x: 37,  y: 280, width: 211, height: 152),
        "alienMedium4": CGRect(x: 781, y: 286, width: 203, height: 143),

        // Small tier
        "alienSmall1": CGRect(x: 238, y: 470, width: 245, height: 109),
        "alienSmall2": CGRect(x: 496, y: 471, width: 162, height: 104),
        "alienSmall3": CGRect(x: 46,  y: 472, width: 170, height: 102),
        "alienSmall4": CGRect(x: 827, y: 476, width: 147, height: 94),

        // Boss tier
        "alienBoss1": CGRect(x: 697, y: 599, width: 318, height: 197),
        "alienBoss2": CGRect(x: 345, y: 600, width: 341, height: 195),
        "alienBoss3": CGRect(x: 16,  y: 605, width: 310, height: 189),
    ]

    private var textureCache: [String: SKTexture] = [:]

    private init() {
        texture = SKTexture(imageNamed: "aliens3")
        texture.filteringMode = .nearest
    }

    func sprite(named name: String) -> SKTexture? {
        if let cached = textureCache[name] {
            return cached
        }

        guard let pixelRect = spriteRects[name] else {
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
}
