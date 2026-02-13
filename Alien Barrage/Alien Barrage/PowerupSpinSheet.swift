//
//  PowerupSpinSheet.swift
//  Alien Barrage
//

import SpriteKit
import CoreGraphics

/// Dedicated spritesheet loader for powerup 3D-spin frame animations.
final class PowerupSpinSheet {

    static let shared = PowerupSpinSheet()

    private let texture: SKTexture
    private let sheetWidth: CGFloat = 512.0
    private let sheetHeight: CGFloat = 256.0

    // Rows in art/powerups.png (top to bottom).
    private let rowBySpriteName: [String: Int] = [
        "powerupSpreadShot": 0, // flame
        "powerupRapidFire": 1,  // lightning
        "powerupExtraLife": 2,  // plus
        "powerupShield": 3,     // star
    ]

    // Centers for the 9 rotation frames in each row.
    private let frameCenterXs: [CGFloat] = [92, 136, 179, 221, 265, 308, 349, 389, 427]
    private let frameCenterYs: [CGFloat] = [52, 101, 152, 203]
    private let frameSize = CGSize(width: 40, height: 40)

    private var spinFramesCache: [String: [SKTexture]] = [:]
    private var baseTextureCache: [String: SKTexture] = [:]

    private init() {
        texture = SKTexture(imageNamed: "powerups")
        texture.filteringMode = .nearest
    }

    /// Returns the first frame texture for the given powerup sprite name.
    func baseTexture(named spriteName: String) -> SKTexture? {
        if let cached = baseTextureCache[spriteName] {
            return cached
        }

        guard let frames = spinFrames(named: spriteName), let first = frames.first else {
            return nil
        }

        baseTextureCache[spriteName] = first
        return first
    }

    /// Returns a full-loop sequence:
    /// original forward 9 frames + horizontally flipped reverse 9 frames.
    func spinFrames(named spriteName: String) -> [SKTexture]? {
        if let cached = spinFramesCache[spriteName] {
            return cached
        }

        guard let rowIndex = rowBySpriteName[spriteName] else {
            return nil
        }

        var forward: [SKTexture] = []
        for centerX in frameCenterXs {
            let pixelRect = CGRect(
                x: centerX - frameSize.width / 2,
                y: frameCenterYs[rowIndex] - frameSize.height / 2,
                width: frameSize.width,
                height: frameSize.height
            )
            forward.append(textureForPixelRect(pixelRect))
        }

        let mirroredReverse = forward.reversed().map { mirroredTexture($0) }
        let fullLoop = forward + mirroredReverse

        spinFramesCache[spriteName] = fullLoop
        return fullLoop
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

    private func mirroredTexture(_ source: SKTexture) -> SKTexture {
        let cgImage = source.cgImage()

        let width = cgImage.width
        let height = cgImage.height

        guard
            let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else {
            return source
        }

        context.translateBy(x: CGFloat(width), y: 0)
        context.scaleBy(x: -1, y: 1)
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))

        guard let flippedCG = context.makeImage() else { return source }

        let flipped = SKTexture(cgImage: flippedCG)
        flipped.filteringMode = .nearest
        return flipped
    }
}
