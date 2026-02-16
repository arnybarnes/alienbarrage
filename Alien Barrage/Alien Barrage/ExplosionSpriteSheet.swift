//
//  ExplosionSpriteSheet.swift
//  Alien Barrage
//

import SpriteKit

/// Dedicated spritesheet loader for explosion art sourced from `explosions.png`.
final class ExplosionSpriteSheet {

    static let shared = ExplosionSpriteSheet()

    private let texture: SKTexture
    private let sheetWidth: CGFloat = 1024.0
    private let sheetHeight: CGFloat = 1024.0

    // 3x3 explosion sheet laid out left-to-right, top-to-bottom.
    // Rects include extra transparent margin so edges aren't clipped when scaled.
    private let framesByRow: [[CGRect]] = [
        [
            CGRect(x: 34,  y: 35,  width: 337, height: 272),
            CGRect(x: 370, y: 45,  width: 296, height: 281),
            CGRect(x: 677, y: 45,  width: 318, height: 269),
        ],
        [
            CGRect(x: 27,  y: 337, width: 343, height: 261),
            CGRect(x: 364, y: 338, width: 314, height: 268),
            CGRect(x: 677, y: 342, width: 323, height: 267),
        ],
        [
            CGRect(x: 32,  y: 645, width: 336, height: 262),
            CGRect(x: 356, y: 640, width: 321, height: 278),
            CGRect(x: 668, y: 638, width: 329, height: 268),
        ]
    ]

    private var textureCache: [String: SKTexture] = [:]
    private var sequenceCache: [Int: [SKTexture]] = [:]

    private init() {
        texture = SKTexture(imageNamed: "explosions")
        texture.filteringMode = .nearest
    }

    /// Returns one of three explosion frame sequences.
    /// Sequence 0/1/2 correspond to column 0/1/2, played top-to-bottom.
    func frames(sequence index: Int) -> [SKTexture] {
        let clamped = max(0, min(2, index))
        if let cached = sequenceCache[clamped] {
            return cached
        }

        let frames = [framesByRow[0][clamped], framesByRow[1][clamped], framesByRow[2][clamped]]
            .map { textureForPixelRect($0) }

        sequenceCache[clamped] = frames
        return frames
    }

    func randomFrames() -> [SKTexture] {
        frames(sequence: Int.random(in: 0...2))
    }

    /// Pre-decodes explosion frame sequences so first-hit gameplay avoids lazy texture setup.
    func warmUp() {
        for sequence in 0...2 {
            _ = frames(sequence: sequence)
        }
    }

    /// Legacy sprite name support so old explosion keys resolve to this new sheet.
    func sprite(named name: String) -> SKTexture? {
        if let cached = textureCache[name] {
            return cached
        }

        let rect: CGRect
        switch name {
        case "explosionOrange1": rect = framesByRow[0][0]
        case "explosionOrange2": rect = framesByRow[1][0]
        case "explosionOrange3": rect = framesByRow[2][0]
        case "explosionFade1": rect = framesByRow[0][1]
        case "explosionFade2": rect = framesByRow[1][1]
        case "explosionFade3": rect = framesByRow[2][1]
        case "explosionGreen1": rect = framesByRow[0][2]
        case "explosionGreen2": rect = framesByRow[1][2]
        case "explosionGreen3": rect = framesByRow[2][2]
        default:
            return nil
        }

        let tex = textureForPixelRect(rect)
        textureCache[name] = tex
        return tex
    }

    private func textureForPixelRect(_ pixelRect: CGRect) -> SKTexture {
        let normalizedRect = CGRect(
            x: pixelRect.origin.x / sheetWidth,
            y: 1.0 - (pixelRect.origin.y + pixelRect.size.height) / sheetHeight,
            width: pixelRect.size.width / sheetWidth,
            height: pixelRect.size.height / sheetHeight
        )

        let frame = SKTexture(rect: normalizedRect, in: texture)
        frame.filteringMode = .nearest
        return frame
    }
}
