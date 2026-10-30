#if !APPSTORE
import AppKit

// Koncluí: the greeting's card (the notch's hello when Koncluí starts) gets the life of the window's bands behind the Koru:
// the brand's mint glowing and breathing in its top corner, particles rising with depth (far ones small, slow and dim, one in
// nine white) and the website's grain. It arrives once the Koru lands, after the warp and the ring that are her entrance, so
// the two never compete, and it leaves with the card. Reduce Motion keeps the glow and the grain, without particles. Drawn in
// Core Graphics like the rest of the greeting and from its clock alone: nothing is kept between frames.
enum KoncluiGreetingAmbient {
    /// When the life comes in, eased out: from the end of the ring burst to the Koru's landing.
    static let arrival = (start: 1.2, end: 2.0)

    private struct Mote {
        let x, y, speed, drift, radius, phase, depth: CGFloat
        let white: Bool
    }

    /// Fixed motes, so the greeting is the same every time; the clock moves them.
    private static let motes: [Mote] = {
        var seed: UInt64 = 0x6B6F7275
        func next() -> CGFloat {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return CGFloat(seed >> 11) / CGFloat(UInt64(1) << 53)
        }
        return (0..<36).map { _ in
            let depth = 0.4 + next() * 0.6
            return Mote(x: next(), y: next(), speed: (3 + next() * 10) * depth, drift: (next() * 6 - 3) * depth,
                        radius: (0.5 + next()) * (0.6 + depth * 0.7), phase: next() * 2 * .pi, depth: depth, white: next() < 1.0 / 9)
        }
    }()

    /// The card itself is a band: the same navy well (`KoncluiPalette.sunken`), so the glow reads as on the window's bands
    /// and not as a light patch over a grey.
    static let cardFill = color(KoncluiPalette.sunken, 1)

    static func draw(_ ctx: CGContext, card: CGRect, radius: CGFloat, t: Double, alpha: Double) {
        // The bands' edge, mint at 16 %, from the card's first frame.
        if alpha > 0.01 {
            ctx.saveGState()
            ctx.addPath(CGPath(roundedRect: card.insetBy(dx: 0.5, dy: 0.5), cornerWidth: radius - 0.5, cornerHeight: radius - 0.5,
                               transform: nil))
            ctx.setStrokeColor(mint(0.16 * CGFloat(alpha)))
            ctx.setLineWidth(1)
            ctx.strokePath()
            ctx.restoreGState()
        }
        let k = min(1, max(0, (t - arrival.start) / (arrival.end - arrival.start)))
        let shown = CGFloat(alpha * (1 - pow(1 - k, 3)))   // ease-out
        guard shown > 0.01 else { return }
        let still = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let time = CGFloat(t)

        ctx.saveGState()
        ctx.addPath(CGPath(roundedRect: card, cornerWidth: radius, cornerHeight: radius, transform: nil))
        ctx.clip()

        // The brand's colour, low from the opposite corner and breathing in the top one, as on the bands.
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        if let wash = CGGradient(colorsSpace: space, colors: [mint(0.10 * shown), mint(0)] as CFArray, locations: [0, 1]) {
            ctx.drawLinearGradient(wash, start: CGPoint(x: card.maxX, y: card.minY),
                                   end: CGPoint(x: card.minX + card.width * 0.35, y: card.maxY), options: [])
        }
        let breath = still ? 1 : 0.85 + 0.15 * sin(time * 0.9)
        if let glow = CGGradient(colorsSpace: space, colors: [mint(0.30 * breath * shown), mint(0.08 * shown), mint(0)] as CFArray,
                                 locations: [0, 0.5, 1]) {
            let centre = CGPoint(x: card.minX + card.width * 0.92, y: card.minY - card.height * 0.15)
            ctx.drawRadialGradient(glow, startCenter: centre, startRadius: 0, endCenter: centre,
                                   endRadius: max(card.width, card.height) * 0.55 * breath, options: [])
        }

        if !still {
            for m in motes {
                // Rising, and back in at the foot once out at the top; drifting sideways, back in on the other side.
                let y = card.minY - 6 + wrap(m.y * (card.height + 12) - time * m.speed, card.height + 12)
                let x = card.minX + wrap(m.x * card.width + m.drift * time, card.width) + sin(time * 0.7 + m.phase) * 5 * m.depth
                let twinkle = (0.22 + 0.5 * (0.5 + 0.5 * sin(time * (1.2 + m.depth) + m.phase))) * m.depth
                let a = min(1, twinkle) * shown
                let dot = CGRect(x: x - m.radius, y: y - m.radius, width: m.radius * 2, height: m.radius * 2)
                if m.radius > 1.1 {
                    ctx.setFillColor(m.white ? white(a * 0.12) : mint(a * 0.12))
                    ctx.fillEllipse(in: dot.insetBy(dx: -m.radius * 1.6, dy: -m.radius * 1.6))
                }
                ctx.setFillColor(m.white ? white(a) : mint(a))
                ctx.fillEllipse(in: dot)
            }
        }

        if let tile = KoncluiGrain.tile {
            ctx.setBlendMode(.softLight)
            ctx.setAlpha(shown)
            ctx.interpolationQuality = .none
            ctx.draw(tile, in: CGRect(x: card.minX, y: card.minY, width: 128, height: 128), byTiling: true)
        }
        ctx.restoreGState()
    }

    private static func mint(_ alpha: CGFloat) -> CGColor { color(KoncluiPalette.accent, alpha) }

    private static func color(_ hex: String, _ alpha: CGFloat) -> CGColor {
        let c = KoncluiContrast.channels(hex)
        return CGColor(srgbRed: c.r / 255, green: c.g / 255, blue: c.b / 255, alpha: alpha)
    }

    private static func white(_ alpha: CGFloat) -> CGColor { CGColor(srgbRed: 1, green: 1, blue: 1, alpha: alpha) }

    private static func wrap(_ value: CGFloat, _ span: CGFloat) -> CGFloat {
        let r = value.truncatingRemainder(dividingBy: span)
        return r < 0 ? r + span : r
    }
}
#endif
