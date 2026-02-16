import CoreGraphics

enum BonusPatterns {

    /// Returns 5 path-builder closures for the given bonus round.
    /// `round` is 0-indexed (0 = level 4, 1 = level 8, etc.).
    /// Each closure takes an alien index (0-7) and returns a flight path.
    static func patterns(forBonusRound round: Int, screenSize: CGSize) -> [(Int) -> CGMutablePath] {
        let w = screenSize.width
        let h = screenSize.height
        let m: CGFloat = 60

        switch round % 4 {
        case 0: return [
            { i in topSplit(w: w, h: h, m: m, index: i) },
            { i in rightSCurve(w: w, h: h, m: m, index: i) },
            { i in xCross(w: w, h: h, m: m, index: i) },
            { i in spiral(w: w, h: h, m: m, index: i) },
            { i in braid(w: w, h: h, m: m, index: i) }
        ]
        case 1: return [
            { i in vFormationDive(w: w, h: h, m: m, index: i) },
            { i in leftSCurve(w: w, h: h, m: m, index: i) },
            { i in figure8(w: w, h: h, m: m, index: i) },
            { i in rain(w: w, h: h, m: m, index: i) },
            { i in boomerang(w: w, h: h, m: m, index: i) }
        ]
        case 2: return [
            { i in diamond(w: w, h: h, m: m, index: i) },
            { i in topZigzag(w: w, h: h, m: m, index: i) },
            { i in funnel(w: w, h: h, m: m, index: i) },
            { i in corkscrew(w: w, h: h, m: m, index: i) },
            { i in pinch(w: w, h: h, m: m, index: i) }
        ]
        case 3: return [
            { i in cascade(w: w, h: h, m: m, index: i) },
            { i in orbit(w: w, h: h, m: m, index: i) },
            { i in swoopLow(w: w, h: h, m: m, index: i) },
            { i in ribbon(w: w, h: h, m: m, index: i) },
            { i in starburst(w: w, h: h, m: m, index: i) }
        ]
        default: fatalError()
        }
    }

    // MARK: - Set A (existing patterns)

    /// Top-center split: 0-3 arc left, 4-7 arc right
    private static func topSplit(w: CGFloat, h: CGFloat, m: CGFloat, index: Int) -> CGMutablePath {
        let path = CGMutablePath()
        if index < 4 {
            path.move(to: CGPoint(x: w * 0.5, y: h + m))
            path.addCurve(
                to: CGPoint(x: -m, y: h * 0.15),
                control1: CGPoint(x: w * 0.3, y: h * 0.75),
                control2: CGPoint(x: w * 0.05, y: h * 0.4)
            )
        } else {
            path.move(to: CGPoint(x: w * 0.5, y: h + m))
            path.addCurve(
                to: CGPoint(x: w + m, y: h * 0.15),
                control1: CGPoint(x: w * 0.7, y: h * 0.75),
                control2: CGPoint(x: w * 0.95, y: h * 0.4)
            )
        }
        return path
    }

    /// Right-side S-curve across screen
    private static func rightSCurve(w: CGFloat, h: CGFloat, m: CGFloat, index: Int) -> CGMutablePath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: w + m, y: h * 0.7))
        path.addCurve(
            to: CGPoint(x: w * 0.35, y: h * 0.5),
            control1: CGPoint(x: w * 0.75, y: h * 0.9),
            control2: CGPoint(x: w * 0.3, y: h * 0.7)
        )
        path.addCurve(
            to: CGPoint(x: -m, y: h * 0.3),
            control1: CGPoint(x: w * 0.4, y: h * 0.3),
            control2: CGPoint(x: w * 0.15, y: h * 0.15)
        )
        return path
    }

    /// Bottom corners X: 0-3 bottom-left to top-right, 4-7 bottom-right to top-left
    private static func xCross(w: CGFloat, h: CGFloat, m: CGFloat, index: Int) -> CGMutablePath {
        let path = CGMutablePath()
        if index < 4 {
            path.move(to: CGPoint(x: -m, y: -m))
            path.addCurve(
                to: CGPoint(x: w + m, y: h + m),
                control1: CGPoint(x: w * 0.25, y: h * 0.45),
                control2: CGPoint(x: w * 0.65, y: h * 0.65)
            )
        } else {
            path.move(to: CGPoint(x: w + m, y: -m))
            path.addCurve(
                to: CGPoint(x: -m, y: h + m),
                control1: CGPoint(x: w * 0.75, y: h * 0.45),
                control2: CGPoint(x: w * 0.35, y: h * 0.65)
            )
        }
        return path
    }

    /// Top-left spiral: clockwise loop through center, exit right
    private static func spiral(w: CGFloat, h: CGFloat, m: CGFloat, index: Int) -> CGMutablePath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -m, y: h * 0.85))
        path.addCurve(
            to: CGPoint(x: w * 0.55, y: h * 0.65),
            control1: CGPoint(x: w * 0.15, y: h + m * 0.5),
            control2: CGPoint(x: w * 0.65, y: h * 0.9)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.45, y: h * 0.35),
            control1: CGPoint(x: w * 0.25, y: h * 0.55),
            control2: CGPoint(x: w * 0.2, y: h * 0.35)
        )
        path.addCurve(
            to: CGPoint(x: w + m, y: h * 0.5),
            control1: CGPoint(x: w * 0.7, y: h * 0.35),
            control2: CGPoint(x: w * 0.9, y: h * 0.55)
        )
        return path
    }

    /// Both sides braid: 0-3 left-to-right weave, 4-7 right-to-left weave
    private static func braid(w: CGFloat, h: CGFloat, m: CGFloat, index: Int) -> CGMutablePath {
        let path = CGMutablePath()
        if index < 4 {
            path.move(to: CGPoint(x: -m, y: h * 0.5))
            path.addCurve(
                to: CGPoint(x: w * 0.5, y: h * 0.6),
                control1: CGPoint(x: w * 0.15, y: h * 0.8),
                control2: CGPoint(x: w * 0.35, y: h * 0.3)
            )
            path.addCurve(
                to: CGPoint(x: w + m, y: h * 0.5),
                control1: CGPoint(x: w * 0.65, y: h * 0.85),
                control2: CGPoint(x: w * 0.85, y: h * 0.35)
            )
        } else {
            path.move(to: CGPoint(x: w + m, y: h * 0.5))
            path.addCurve(
                to: CGPoint(x: w * 0.5, y: h * 0.4),
                control1: CGPoint(x: w * 0.85, y: h * 0.8),
                control2: CGPoint(x: w * 0.65, y: h * 0.3)
            )
            path.addCurve(
                to: CGPoint(x: -m, y: h * 0.5),
                control1: CGPoint(x: w * 0.35, y: h * 0.85),
                control2: CGPoint(x: w * 0.15, y: h * 0.35)
            )
        }
        return path
    }

    // MARK: - Set B (bonus round 2)

    /// V-formation dive: enter top, split into V diving down, exit bottom corners
    private static func vFormationDive(w: CGFloat, h: CGFloat, m: CGFloat, index: Int) -> CGMutablePath {
        let path = CGMutablePath()
        let spread = CGFloat(index) / 7.0
        if index < 4 {
            path.move(to: CGPoint(x: w * (0.4 + spread * 0.15), y: h + m))
            path.addCurve(
                to: CGPoint(x: -m, y: -m),
                control1: CGPoint(x: w * 0.45, y: h * 0.7),
                control2: CGPoint(x: w * 0.15, y: h * 0.3)
            )
        } else {
            path.move(to: CGPoint(x: w * (0.45 + spread * 0.15), y: h + m))
            path.addCurve(
                to: CGPoint(x: w + m, y: -m),
                control1: CGPoint(x: w * 0.55, y: h * 0.7),
                control2: CGPoint(x: w * 0.85, y: h * 0.3)
            )
        }
        return path
    }

    /// Left S-curve: mirror of right S-curve, enter left exit right
    private static func leftSCurve(w: CGFloat, h: CGFloat, m: CGFloat, index: Int) -> CGMutablePath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -m, y: h * 0.7))
        path.addCurve(
            to: CGPoint(x: w * 0.65, y: h * 0.5),
            control1: CGPoint(x: w * 0.25, y: h * 0.9),
            control2: CGPoint(x: w * 0.7, y: h * 0.7)
        )
        path.addCurve(
            to: CGPoint(x: w + m, y: h * 0.3),
            control1: CGPoint(x: w * 0.6, y: h * 0.3),
            control2: CGPoint(x: w * 0.85, y: h * 0.15)
        )
        return path
    }

    /// Figure-8: enter left, loop through center twice, exit right
    private static func figure8(w: CGFloat, h: CGFloat, m: CGFloat, index: Int) -> CGMutablePath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -m, y: h * 0.5))
        // Upper loop
        path.addCurve(
            to: CGPoint(x: w * 0.5, y: h * 0.5),
            control1: CGPoint(x: w * 0.15, y: h * 0.85),
            control2: CGPoint(x: w * 0.45, y: h * 0.85)
        )
        // Lower loop
        path.addCurve(
            to: CGPoint(x: w * 0.5, y: h * 0.5),
            control1: CGPoint(x: w * 0.55, y: h * 0.15),
            control2: CGPoint(x: w * 0.85, y: h * 0.15)
        )
        // Exit right
        path.addCurve(
            to: CGPoint(x: w + m, y: h * 0.5),
            control1: CGPoint(x: w * 0.85, y: h * 0.75),
            control2: CGPoint(x: w * 0.95, y: h * 0.6)
        )
        return path
    }

    /// Rain: enter top spread across width, gentle drift down with slight wave, exit bottom
    private static func rain(w: CGFloat, h: CGFloat, m: CGFloat, index: Int) -> CGMutablePath {
        let path = CGMutablePath()
        let xPos = w * (0.1 + CGFloat(index) * 0.1)  // spread across width
        let drift: CGFloat = (index % 2 == 0) ? w * 0.08 : -w * 0.08
        path.move(to: CGPoint(x: xPos, y: h + m))
        path.addCurve(
            to: CGPoint(x: xPos + drift, y: h * 0.5),
            control1: CGPoint(x: xPos + drift * 0.5, y: h * 0.8),
            control2: CGPoint(x: xPos - drift * 0.3, y: h * 0.65)
        )
        path.addCurve(
            to: CGPoint(x: xPos, y: -m),
            control1: CGPoint(x: xPos + drift * 0.8, y: h * 0.35),
            control2: CGPoint(x: xPos - drift * 0.5, y: h * 0.1)
        )
        return path
    }

    /// Boomerang: enter right, curve left past center, loop back and exit right
    private static func boomerang(w: CGFloat, h: CGFloat, m: CGFloat, index: Int) -> CGMutablePath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: w + m, y: h * 0.6))
        path.addCurve(
            to: CGPoint(x: w * 0.2, y: h * 0.5),
            control1: CGPoint(x: w * 0.7, y: h * 0.75),
            control2: CGPoint(x: w * 0.3, y: h * 0.7)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.4, y: h * 0.35),
            control1: CGPoint(x: w * 0.1, y: h * 0.35),
            control2: CGPoint(x: w * 0.15, y: h * 0.2)
        )
        path.addCurve(
            to: CGPoint(x: w + m, y: h * 0.4),
            control1: CGPoint(x: w * 0.6, y: h * 0.45),
            control2: CGPoint(x: w * 0.85, y: h * 0.5)
        )
        return path
    }

    // MARK: - Set C (bonus round 3)

    /// Diamond: 0-3 from top converge center exit bottom; 4-7 from bottom converge center exit top
    private static func diamond(w: CGFloat, h: CGFloat, m: CGFloat, index: Int) -> CGMutablePath {
        let path = CGMutablePath()
        if index < 4 {
            let xOff = w * 0.15 * CGFloat(index - 2)
            path.move(to: CGPoint(x: w * 0.5 + xOff, y: h + m))
            path.addCurve(
                to: CGPoint(x: w * 0.5, y: h * 0.5),
                control1: CGPoint(x: w * 0.5 + xOff * 1.5, y: h * 0.8),
                control2: CGPoint(x: w * 0.5 + xOff * 0.3, y: h * 0.6)
            )
            path.addCurve(
                to: CGPoint(x: w * 0.5 + xOff, y: -m),
                control1: CGPoint(x: w * 0.5 - xOff * 0.3, y: h * 0.4),
                control2: CGPoint(x: w * 0.5 - xOff * 1.5, y: h * 0.2)
            )
        } else {
            let xOff = w * 0.15 * CGFloat(index - 6)
            path.move(to: CGPoint(x: w * 0.5 + xOff, y: -m))
            path.addCurve(
                to: CGPoint(x: w * 0.5, y: h * 0.5),
                control1: CGPoint(x: w * 0.5 + xOff * 1.5, y: h * 0.2),
                control2: CGPoint(x: w * 0.5 + xOff * 0.3, y: h * 0.4)
            )
            path.addCurve(
                to: CGPoint(x: w * 0.5 + xOff, y: h + m),
                control1: CGPoint(x: w * 0.5 - xOff * 0.3, y: h * 0.6),
                control2: CGPoint(x: w * 0.5 - xOff * 1.5, y: h * 0.8)
            )
        }
        return path
    }

    /// Top zigzag: enter top-left, zigzag descending across screen, exit bottom-right
    private static func topZigzag(w: CGFloat, h: CGFloat, m: CGFloat, index: Int) -> CGMutablePath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -m, y: h * 0.9))
        path.addLine(to: CGPoint(x: w * 0.7, y: h * 0.75))
        path.addLine(to: CGPoint(x: w * 0.2, y: h * 0.55))
        path.addLine(to: CGPoint(x: w * 0.8, y: h * 0.35))
        path.addLine(to: CGPoint(x: w + m, y: -m))
        return path
    }

    /// Funnel: enter wide from top, converge to narrow center point, fan out exiting bottom
    private static func funnel(w: CGFloat, h: CGFloat, m: CGFloat, index: Int) -> CGMutablePath {
        let path = CGMutablePath()
        let spreadX = w * (0.05 + CGFloat(index) * 0.115)
        path.move(to: CGPoint(x: spreadX, y: h + m))
        path.addCurve(
            to: CGPoint(x: w * 0.5, y: h * 0.5),
            control1: CGPoint(x: spreadX, y: h * 0.8),
            control2: CGPoint(x: w * 0.5, y: h * 0.6)
        )
        let exitX = w * (0.95 - CGFloat(index) * 0.115)
        path.addCurve(
            to: CGPoint(x: exitX, y: -m),
            control1: CGPoint(x: w * 0.5, y: h * 0.4),
            control2: CGPoint(x: exitX, y: h * 0.15)
        )
        return path
    }

    /// Corkscrew: enter left, tight sinusoidal wave across screen, exit right
    private static func corkscrew(w: CGFloat, h: CGFloat, m: CGFloat, index: Int) -> CGMutablePath {
        let path = CGMutablePath()
        let baseY = h * 0.5
        let amp = h * 0.15
        path.move(to: CGPoint(x: -m, y: baseY))
        // 3 oscillations across the screen
        path.addCurve(
            to: CGPoint(x: w * 0.25, y: baseY),
            control1: CGPoint(x: w * 0.08, y: baseY + amp),
            control2: CGPoint(x: w * 0.17, y: baseY - amp)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.5, y: baseY),
            control1: CGPoint(x: w * 0.33, y: baseY + amp),
            control2: CGPoint(x: w * 0.42, y: baseY - amp)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.75, y: baseY),
            control1: CGPoint(x: w * 0.58, y: baseY + amp),
            control2: CGPoint(x: w * 0.67, y: baseY - amp)
        )
        path.addCurve(
            to: CGPoint(x: w + m, y: baseY),
            control1: CGPoint(x: w * 0.83, y: baseY + amp),
            control2: CGPoint(x: w * 0.92, y: baseY - amp)
        )
        return path
    }

    /// Pinch: 0-3 top-left curving down-right, 4-7 bottom-right curving up-left (crossing)
    private static func pinch(w: CGFloat, h: CGFloat, m: CGFloat, index: Int) -> CGMutablePath {
        let path = CGMutablePath()
        if index < 4 {
            path.move(to: CGPoint(x: -m, y: h + m))
            path.addCurve(
                to: CGPoint(x: w * 0.5, y: h * 0.5),
                control1: CGPoint(x: w * 0.2, y: h * 0.85),
                control2: CGPoint(x: w * 0.35, y: h * 0.6)
            )
            path.addCurve(
                to: CGPoint(x: w + m, y: -m),
                control1: CGPoint(x: w * 0.65, y: h * 0.4),
                control2: CGPoint(x: w * 0.8, y: h * 0.15)
            )
        } else {
            path.move(to: CGPoint(x: w + m, y: -m))
            path.addCurve(
                to: CGPoint(x: w * 0.5, y: h * 0.5),
                control1: CGPoint(x: w * 0.8, y: h * 0.15),
                control2: CGPoint(x: w * 0.65, y: h * 0.4)
            )
            path.addCurve(
                to: CGPoint(x: -m, y: h + m),
                control1: CGPoint(x: w * 0.35, y: h * 0.6),
                control2: CGPoint(x: w * 0.2, y: h * 0.85)
            )
        }
        return path
    }

    // MARK: - Set D (bonus round 4)

    /// Cascade: enter top-right stepping down, each alien offset lower, exit bottom-left
    private static func cascade(w: CGFloat, h: CGFloat, m: CGFloat, index: Int) -> CGMutablePath {
        let path = CGMutablePath()
        let yStart = h * (0.95 - CGFloat(index) * 0.07)
        path.move(to: CGPoint(x: w + m, y: yStart))
        path.addCurve(
            to: CGPoint(x: w * 0.5, y: yStart - h * 0.15),
            control1: CGPoint(x: w * 0.8, y: yStart + h * 0.05),
            control2: CGPoint(x: w * 0.65, y: yStart - h * 0.05)
        )
        path.addCurve(
            to: CGPoint(x: -m, y: yStart - h * 0.35),
            control1: CGPoint(x: w * 0.35, y: yStart - h * 0.2),
            control2: CGPoint(x: w * 0.1, y: yStart - h * 0.3)
        )
        return path
    }

    /// Orbit: enter right, large circular loop around screen center, exit right
    private static func orbit(w: CGFloat, h: CGFloat, m: CGFloat, index: Int) -> CGMutablePath {
        let path = CGMutablePath()
        let cx = w * 0.5
        let cy = h * 0.5
        let rx = w * 0.4
        let ry = h * 0.3
        path.move(to: CGPoint(x: w + m, y: cy))
        // Top half of orbit
        path.addCurve(
            to: CGPoint(x: cx, y: cy + ry),
            control1: CGPoint(x: w + m, y: cy + ry * 0.8),
            control2: CGPoint(x: cx + rx * 0.5, y: cy + ry)
        )
        path.addCurve(
            to: CGPoint(x: cx - rx, y: cy),
            control1: CGPoint(x: cx - rx * 0.5, y: cy + ry),
            control2: CGPoint(x: cx - rx, y: cy + ry * 0.5)
        )
        // Bottom half of orbit
        path.addCurve(
            to: CGPoint(x: cx, y: cy - ry),
            control1: CGPoint(x: cx - rx, y: cy - ry * 0.5),
            control2: CGPoint(x: cx - rx * 0.5, y: cy - ry)
        )
        path.addCurve(
            to: CGPoint(x: w + m, y: cy),
            control1: CGPoint(x: cx + rx * 0.5, y: cy - ry),
            control2: CGPoint(x: w + m, y: cy - ry * 0.8)
        )
        return path
    }

    /// Swoop low: enter top, sharp dive to bottom, pull up and exit top opposite side
    private static func swoopLow(w: CGFloat, h: CGFloat, m: CGFloat, index: Int) -> CGMutablePath {
        let path = CGMutablePath()
        if index < 4 {
            path.move(to: CGPoint(x: w * 0.25, y: h + m))
            path.addCurve(
                to: CGPoint(x: w * 0.5, y: h * 0.1),
                control1: CGPoint(x: w * 0.2, y: h * 0.6),
                control2: CGPoint(x: w * 0.35, y: h * 0.1)
            )
            path.addCurve(
                to: CGPoint(x: w * 0.75, y: h + m),
                control1: CGPoint(x: w * 0.65, y: h * 0.1),
                control2: CGPoint(x: w * 0.8, y: h * 0.6)
            )
        } else {
            path.move(to: CGPoint(x: w * 0.75, y: h + m))
            path.addCurve(
                to: CGPoint(x: w * 0.5, y: h * 0.1),
                control1: CGPoint(x: w * 0.8, y: h * 0.6),
                control2: CGPoint(x: w * 0.65, y: h * 0.1)
            )
            path.addCurve(
                to: CGPoint(x: w * 0.25, y: h + m),
                control1: CGPoint(x: w * 0.35, y: h * 0.1),
                control2: CGPoint(x: w * 0.2, y: h * 0.6)
            )
        }
        return path
    }

    /// Ribbon: enter left mid-height, gentle sine wave across, exit right
    private static func ribbon(w: CGFloat, h: CGFloat, m: CGFloat, index: Int) -> CGMutablePath {
        let path = CGMutablePath()
        let baseY = h * 0.55
        let amp = h * 0.1
        path.move(to: CGPoint(x: -m, y: baseY))
        path.addCurve(
            to: CGPoint(x: w * 0.33, y: baseY + amp),
            control1: CGPoint(x: w * 0.1, y: baseY),
            control2: CGPoint(x: w * 0.22, y: baseY + amp)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.67, y: baseY - amp),
            control1: CGPoint(x: w * 0.44, y: baseY + amp),
            control2: CGPoint(x: w * 0.56, y: baseY - amp)
        )
        path.addCurve(
            to: CGPoint(x: w + m, y: baseY),
            control1: CGPoint(x: w * 0.78, y: baseY - amp),
            control2: CGPoint(x: w * 0.9, y: baseY)
        )
        return path
    }

    /// Starburst: all enter center-top, burst outward to different exit points by index
    private static func starburst(w: CGFloat, h: CGFloat, m: CGFloat, index: Int) -> CGMutablePath {
        let path = CGMutablePath()
        let startX = w * 0.5
        let startY = h + m
        path.move(to: CGPoint(x: startX, y: startY))

        // All converge to center first
        let centerX = w * 0.5
        let centerY = h * 0.55
        path.addLine(to: CGPoint(x: centerX, y: centerY))

        // Burst outward based on index — 8 directions
        let angle = (CGFloat.pi * 2.0 * CGFloat(index) / 8.0) - CGFloat.pi / 2.0
        let exitDist = max(w, h) * 0.7
        let exitX = centerX + cos(angle) * exitDist
        let exitY = centerY + sin(angle) * exitDist

        let ctrlDist = exitDist * 0.4
        let ctrlX = centerX + cos(angle) * ctrlDist
        let ctrlY = centerY + sin(angle) * ctrlDist

        path.addCurve(
            to: CGPoint(x: exitX, y: exitY),
            control1: CGPoint(x: ctrlX, y: ctrlY),
            control2: CGPoint(x: exitX * 0.7 + centerX * 0.3, y: exitY * 0.7 + centerY * 0.3)
        )
        return path
    }
}
