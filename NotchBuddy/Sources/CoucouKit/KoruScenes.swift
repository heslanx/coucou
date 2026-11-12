import SwiftUI
import QuartzCore

// Koru where the app sized things for Mochi: the minis' hop and hearts (prototype features/minis.js LOOP), the desktop
// Koru's hit area and the floor shadow of the FlowHub's minis. Each caller routes here only while Koru.enabled.

extension BotEngine {
    /// minis.js LOOP for the two behaviours sized for Mochi's body: Koru's wings and tufts fill a mini's canvas, so her hop
    /// and squash are smaller, and her hearts rise beside her head, slower, fading before the canvas top. False for the
    /// others (annoyed, wink), which run as Mochi's.
    func koruMiniBehavior() -> Bool {
        let now = CACurrentMediaTime()
        switch permanentEmote {
        case .happy:
            guard !locks.contains("oy") else {
                miniNextBehavior = now + 0.4
                return true
            }
            anim("oy", keys: [TweenKey(target: -0.24, duration: 120, ease: Ease.out),
                              TweenKey(target: 0.02, duration: 200, ease: Ease.inOut),
                              TweenKey(target: 0, duration: 160, ease: Ease.back)])
            anim("sy", keys: [TweenKey(target: 0.88, duration: 80, ease: Ease.out),
                              TweenKey(target: 1.07, duration: 130, ease: Ease.out),
                              TweenKey(target: 0.94, duration: 160, ease: Ease.inOut),
                              TweenKey(target: 1, duration: 200, ease: Ease.back)])
            anim("sx", keys: [TweenKey(target: 1.08, duration: 80, ease: Ease.out),
                              TweenKey(target: 0.94, duration: 130, ease: Ease.out),
                              TweenKey(target: 1.03, duration: 160, ease: Ease.inOut),
                              TweenKey(target: 1, duration: 200, ease: Ease.back)])
            miniNextBehavior = now + 2.2 + Double.random(in: 0...1.2)
        case .love:
            let first = particles.count
            emit(.heart, count: 2)
            // In real seconds as the prototype's; the engine ages particles 3× real time (one 0.05 s step per frame).
            for i in first..<particles.count {
                let sd: CGFloat = i == first ? -1 : 1
                particles[i].x = sd * (0.6 + .random(in: 0...0.15))
                particles[i].y = -0.7 - .random(in: 0...0.1)
                particles[i].vx = sd * 0.08 / 3
                particles[i].vy = -(0.25 + .random(in: 0...0.08)) / 3
                particles[i].age = -Double(i - first) * 0.14 * 3
                particles[i].life = (1.1 + .random(in: 0...0.2)) * 3
                particles[i].size = 0.14 + .random(in: 0...0.04)
            }
            anim("tilt", keys: [TweenKey(target: -0.1, duration: 180, ease: Ease.out),
                                TweenKey(target: 0.1, duration: 340, ease: Ease.inOut),
                                TweenKey(target: 0, duration: 220, ease: Ease.inOut)])
            miniNextBehavior = now + 2.6 + Double.random(in: 0...1.5)
        default:
            return false
        }
        return true
    }
}

@MainActor
enum KoruScenes {
    /// Koru at rest in a canvas of width w (no particle overhang): her radius, body centre and base, y down.
    static func rest(canvasWidth w: CGFloat) -> (R: CGFloat, cy: CGFloat, base: CGFloat) {
        let R = w * 0.3 * Koru.frame, cy = w / 2 + KoruShape.cy * R
        return (R, cy, cy + KoruShape.ryBot * R)
    }

    /// The desktop Koru's hit area in its square panel (AppKit y-up local coordinates): an ellipse as wide as her body,
    /// from just above its dome to its base. It covers 84 % of her at rest and 1-7 % of it is off her, where Mochi's
    /// circle (0.24 × the panel) covers 66 % of her.
    static func isOverBody(localPoint p: CGPoint, panelSize s: CGFloat) -> Bool {
        let r = rest(canvasWidth: s)
        let top = r.cy - 1.08 * r.R
        let a = KoruShape.rx * r.R, b = (r.base - top) / 2
        let dx = p.x - s / 2, dy = (s - p.y) - (top + b)
        return (dx * dx) / (a * a) + (dy * dy) / (b * b) <= 1
    }

    /// The floor shadow under a mini Koru drawn in a w × w canvas whose top is at canvasTop (FlowHubMochis): Mochi's
    /// shadow, in proportion to Koru's body width, under her base.
    static func floorShadow(centreX cx: CGFloat, canvasTop: CGFloat, width w: CGFloat) -> CGRect {
        let r = rest(canvasWidth: w), bw = 2 * KoruShape.rx * r.R
        // Mochi's: 0.52 w wide (0.76 of his 0.684 w body), 0.09 w high, its top 0.009 w above his base.
        let sw = bw * 0.76, sh = bw * 0.1316
        return CGRect(x: cx - sw / 2, y: canvasTop + r.base - bw * 0.0132, width: sw, height: sh)
    }
}
