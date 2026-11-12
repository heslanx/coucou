import SwiftUI
import QuartzCore

// How the Mac feels, on Koru (prototype features/mood.js): MochiMood.swift keeps the levels, the hops, the looks, the
// blinks and the throws; these hooks draw them her way. Busy: plump glowing drops from just outside her sides and tense,
// trembling pupils. Hot: a red flush rising from her base, a heat glow under her and on the floor, deeper cheeks and heat
// waves between her tufts. Tired: heavy lids. Asleep and full need nothing more (closed eyes and the puff are BotEngine's).

@MainActor
enum KoruMood {
    /// Mochi's body is 1.14 × 0.88 R; his drops are thrown in his units, stretched here to Koru's sides and floor.
    static let KX = KoruShape.rx / 1.14, KY = KoruShape.ryBot / 0.88
    /// Gravity (R/s²) and the floor (R below her resting centre), as MochiMood.swift's, in Koru's units.
    static let gravity = 6 * KY, floorY = 1.05 * KY

    /// A drop of sweat in Koru's units (R) from her resting centre.
    struct Drop {
        var x, y, vx, vy: CGFloat
        var born: Double
        var size, stretch, tint, alpha, wobble: CGFloat
    }

    /// The half-width of her body at height y (R), core.js bodyW.
    static func bodyW(_ y: CGFloat) -> CGFloat {
        let top = y < 0, n = top ? KoruShape.nTop : KoruShape.nBot
        return KoruShape.rx * pow(max(0, 1 - pow(abs(y / (top ? KoruShape.ryTop : KoruShape.ryBot)), n)), 1 / n)
    }

    /// Koru's version of the drops BotEngine threw (MochiMood.swift throwDrop), as mood.js throws them: from just outside
    /// her outline below her tufts (Mochi's sides are inside her body), at 0.45 × the speed so their arcs land inside the
    /// canvas, smaller, plumper and more opaque; the second drop of a burst leaves from the other side a beat later. Size,
    /// stretch and tint in steps, one cached sprite each. Each drop's own random values (its wobble phase) stand in for
    /// the ones mood.js draws, so a drop keeps its look from frame to frame.
    static func drops(_ ds: [MoodDrop]) -> [Drop] {
        func step(_ v: CGFloat, _ k: CGFloat) -> CGFloat { (v * k).rounded() / k }
        var out: [Drop] = []
        var prev: (born: Double, side: CGFloat)? = nil
        for d in ds {
            let thrown: CGFloat = d.x >= 0 ? 1 : -1   // MochiMood throws at ±0.92…1.05 plus a hop of at most 0.28
            var side = thrown, born = d.born
            let r = d.wobble / (2 * .pi)
            if let p = prev, p.born == d.born {
                side = -p.side
                born += 0.08 + 0.06 * Double(r)
            }
            prev = (d.born, side)
            let y = (-0.38 + 0.26 * KoruShape.clamp((d.y + 0.5) / 0.25, 0, 1)) * KY
            let shift = d.x - thrown * 0.985   // the hop's shift when it was thrown
            let small = d.size < 0.14
            out.append(Drop(x: side * (bodyW(y) + 0.02 + 0.06 * r) + shift, y: y,
                            vx: side * abs(d.vx) * KX * 0.45, vy: d.vy * KY, born: born,
                            size: step(d.size * 0.62, 100),
                            stretch: step(small ? d.stretch : 1 + (d.stretch - 1) * 0.25 / 0.55, 10),
                            tint: step(d.tint, 3), alpha: 0.88 + CGFloat((d.alpha - 0.7) / 0.3) * 0.12, wobble: d.wobble))
        }
        return out
    }

    private static func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
        CGColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
    }
    private static func lin(_ stops: [(Color, CGFloat)], _ a: CGPoint, _ b: CGPoint) -> GraphicsContext.Shading {
        .linearGradient(Gradient(stops: stops.map { .init(color: $0.0, location: $0.1) }), startPoint: a, endPoint: b)
    }
    private static func rad(_ stops: [(Color, CGFloat)], _ c: CGPoint, _ r: CGFloat) -> GraphicsContext.Shading {
        .radialGradient(Gradient(stops: stops.map { .init(color: $0.0, location: $0.1) }), center: c, startRadius: 0, endRadius: r)
    }

    /// One drop, the round end down: a glowing blue body, a soft highlight and a sharp glint (mood.js sprite).
    private static func sprite(_ p: Drop, Rpx: CGFloat) -> KoruSheets.Sheet? {
        KoruSheets.get("moodDrop\(p.size):\(p.stretch):\(p.tint)", R: Rpx) { R in
            let s = R * p.size, L = p.stretch, tn = p.tint, m = R * 0.07
            return KoruSheets.render(box: CGRect(x: -s * 1.2 - m, y: -s * 1.1 * L - m, width: s * 2.4 + 2 * m, height: s * 1.1 * L + s * 0.75 + 2 * m), R: R) { g, _ in
                let tear = CGMutablePath()
                tear.move(to: CGPoint(x: 0, y: -s * 1.1 * L))
                tear.addQuadCurve(to: CGPoint(x: 0, y: s * 0.75), control: CGPoint(x: s * 1.15, y: s * 0.25))
                tear.addQuadCurve(to: CGPoint(x: 0, y: -s * 1.1 * L), control: CGPoint(x: -s * 1.15, y: s * 0.25))
                KoruSheets.drop(g, tear, rgb(110, 185, 255, 0.55), R * 0.05)
                g.saveGState(); g.addPath(tear); g.clip()
                KoruSheets.fillLinear(g, tear.boundingBox, [rgb((0.72 - 0.2 * tn) * 255, (0.88 - 0.12 * tn) * 255, 255),
                                                            rgb((0.36 - 0.12 * tn) * 255, (0.68 - 0.14 * tn) * 255, 250)], [0, 1],
                                      from: CGPoint(x: 0, y: -s * L), to: CGPoint(x: 0, y: s * 0.75))
                g.restoreGState()
                g.setFillColor(rgb(255, 255, 255, 0.4 + 0.35 * tn))
                g.fillEllipse(in: CGRect(x: -s * 0.28 - s * 0.12, y: s * 0.08 * L - s * 0.17 * L, width: s * 0.24, height: s * 0.34 * L))
                g.setFillColor(rgb(255, 255, 255, 0.9))
                g.fillEllipse(in: CGRect(x: -s * 0.26 - s * 0.08, y: -s * 0.04 * L - s * 0.08, width: s * 0.16, height: s * 0.16))
            }
        }
    }

    /// The drops in canvas space (mood.js sweat), fading out before they reach the floor and the canvas edges; the wobble
    /// squeezes the sprite. rest: her resting centre in the canvas.
    static func sweat(_ x: GraphicsContext, _ drops: [Drop], R: CGFloat, rest: CGPoint, canvas: CGSize, scale: CGFloat, now: Double) {
        let edge = R * 0.12
        for p in drops {
            let a = CGFloat(now - p.born)
            guard a >= 0 else { continue }
            let px = rest.x + (p.x + p.vx * a) * R, py = p.y + p.vy * a + gravity * a * a / 2, vy = p.vy + gravity * a
            let Y = rest.y + py * R, wob = 1 + sin(a * 22 + p.wobble) * 0.08, m = R * p.size * 1.1
            let al = p.alpha * min(1, a / 0.06) * KoruShape.clamp((floorY - py) / (0.25 * KY), 0, 1)
                * KoruShape.clamp((min(px, canvas.width - px) - m) / edge, 0, 1) * KoruShape.clamp((Y - m) / edge, 0, 1)
            guard al > 0.005 else { continue }
            var c = x
            c.opacity *= Double(al)
            c.translateBy(x: px, y: Y)
            c.rotate(by: .radians(atan2(vy, p.vx) - .pi / 2))   // the round end leads, the tip trails
            c.scaleBy(x: 1 / wob, y: wob)
            KoruSheets.stamp(c, sprite(p, Rpx: R * scale), R: R)
        }
    }

    /// The warm flush rising from her base (body space): deep red at the base, gone by the top of the belly, with a screen
    /// pass along the base that makes it glow like heat.
    static func flush(_ x: GraphicsContext, _ d: KoruGeometry, _ a: CGFloat) {
        let R = d.R
        x.fill(d.body, with: lin([(koruRGBA(236, 58, 30, 0.95 * a), 0), (koruRGBA(240, 66, 36, 0.85 * a), 0.35),
                                  (koruRGBA(246, 84, 56, 0.34 * a), 0.7), (koruRGBA(246, 84, 56, 0), 1)],
                                 CGPoint(x: 0, y: d.ryB), CGPoint(x: 0, y: R * 0.36)))
        var s = x
        s.blendMode = .screen
        s.fill(d.body, with: lin([(koruRGBA(255, 130, 50, 0.6 * a), 0), (koruRGBA(255, 110, 50, 0), 1)],
                                 CGPoint(x: 0, y: d.ryB), CGPoint(x: 0, y: d.ryB - R * 0.32)))
    }

    /// The heat glowing out of her base (body space), below 0.3 R only.
    static func heatGlow(_ x: GraphicsContext, _ d: KoruGeometry, _ a: CGFloat) {
        var c = x
        c.opacity *= Double(a)
        KoruSheets.stamp(c, KoruSheets.get("moodHeat", R: d.R * d.scale) { Rq in
            let rxq = Rq * KoruShape.rx
            return KoruSheets.render(box: CGRect(x: -rxq * 1.5, y: Rq * 0.3, width: rxq * 3, height: Rq * 1.3), pad: Rq * 0.6, R: Rq) { g, _ in
                KoruSheets.drop(g, KoruShape.scaled(KoruShape.body, Rq).cgPath, rgb(255, 84, 40, 0.8), Rq * 0.2, 0, Rq * 0.06)
            }
        }, R: d.R)
    }

    /// The heat deepens her blush (head space): the same spot on each ring, clipped to the face, from pink to red.
    static func cheeks(_ x: GraphicsContext, _ d: KoruGeometry, _ a: CGFloat) {
        var c = x
        c.clip(to: d.face)
        let R = d.R
        for e in d.eyes {
            let bx = e.x + e.sd * R * 0.22, by = e.y + R * 0.43
            c.fill(Path(CGRect(x: bx - R * 0.2, y: by - R * 0.2, width: R * 0.4, height: R * 0.4)),
                   with: rad([(koruRGBA(255, 64, 64, 0.55 * a), 0), (koruRGBA(255, 64, 64, 0.25 * a), 0.55), (koruRGBA(255, 64, 64, 0), 1)],
                             CGPoint(x: bx, y: by), R * 0.2))
        }
    }

    /// Heat waves (canvas space): three glowing wisps rising out of the top of her head between the tufts, fading in at the
    /// bottom and out at the top, 0.14 R short of the canvas top; hotter, they grow longer. Glow in widening passes.
    static func heatWaves(_ x: GraphicsContext, _ d: KoruGeometry, _ al: CGFloat, t: CGFloat) {
        let R = d.R, base = d.cy - d.ryT * d.sy - R * 0.03, len = R * 0.46 * (0.4 + 0.6 * al)
        var c = x
        c.blendMode = .plusLighter
        for i in 0..<3 {
            let x0 = d.cx + CGFloat(i - 1) * R * 0.24, ph = t * 4 + CGFloat(i) * 1.7
            let rise = (t * 0.6 + CGFloat(i) * 0.33).truncatingRemainder(dividingBy: 1)
            let bot = base - R * 0.08 * rise, top = max(bot - len, R * 0.14)
            let a = min(1, al * 4) * (0.55 + 0.45 * al) * (0.75 + 0.25 * sin(rise * .pi))
            guard bot - top >= R * 0.1 else { continue }
            var w = Path()
            for k in 0...24 {
                let f = CGFloat(k) / 24
                let p = CGPoint(x: x0 + sin(ph - f * 5) * R * 0.045 * (0.6 + 0.4 * f), y: bot - (bot - top) * f)
                if k == 0 { w.move(to: p) } else { w.addLine(to: p) }
            }
            let g = lin([(koruRGBA(255, 90, 30, 0), 0), (koruRGBA(255, 112, 44, a), 0.3), (koruRGBA(255, 92, 34, 0.75 * a), 0.75),
                         (koruRGBA(255, 80, 30, 0), 1)], CGPoint(x: 0, y: bot), CGPoint(x: 0, y: top))
            for (lw, a2) in [(0.17, 0.22), (0.09, 0.45), (0.042, 1)] as [(CGFloat, Double)] {
                var s = c
                s.opacity *= a2
                s.stroke(w, with: g, style: StrokeStyle(lineWidth: R * lw, lineCap: .round, lineJoin: .round))
            }
        }
    }

    /// A warm glow on the floor under a hot Koru (canvas space).
    static func floorGlow(_ x: GraphicsContext, _ d: KoruGeometry, _ a: CGFloat) {
        let r = d.rx * 1.2
        var c = x
        c.translateBy(x: d.cx, y: d.cy + d.ryB * d.sy)
        c.scaleBy(x: 1, y: 0.14)
        c.fill(KoruShape.circle(0, 0, r), with: rad([(koruRGBA(255, 96, 40, 0.55 * a), 0), (koruRGBA(255, 80, 40, 0.2 * a), 0.5),
                                                     (koruRGBA(255, 80, 40, 0), 1)], .zero, r))
    }

    /// Fear narrows the pupils (Mochi's eye goes 0.8 × 0.9, her round pupil takes the mean) and makes them tremble
    /// (Mochi's whole eye shakes; her discs sit in the rings, so her pupils do, over their reach of 0.214 R).
    static func tense(_ c: GraphicsContext, _ e: KoruEyeInfo, busy: CGFloat, tremble: CGPoint) {
        var i = e
        let reach = e.dr - e.pr - e.R * 0.02
        i.px += tremble.x / 0.214 * reach
        i.py += tremble.y / 0.214 * reach
        Koru.pupil(c, i, r: e.pr * e.pose.cfg.pupil * (1 - 0.15 * min(1, busy * 1.3)))
    }

    /// Heavy lids for a low battery (Swift's tired eye): a soft lid sagging over the top half, a thin crease, a shade under it.
    static func drowsy(_ c: GraphicsContext, _ e: KoruEyeInfo) {
        let dr = e.dr, R = e.R, y0 = -dr * 0.04
        Koru.pupil(c, e, r: e.pr)
        var lid = Path()
        lid.move(to: CGPoint(x: -dr, y: -dr)); lid.addLine(to: CGPoint(x: dr, y: -dr)); lid.addLine(to: CGPoint(x: dr, y: y0 - dr * 0.1))
        lid.addQuadCurve(to: CGPoint(x: -dr, y: y0 - dr * 0.1), control: CGPoint(x: 0, y: y0 + dr * 0.16))
        lid.closeSubpath()
        var l = c
        l.addFilter(.shadow(color: koruRGBA(120, 50, 0, 0.35), radius: R * 0.04 * Koru.shadowK, x: 0, y: R * 0.015))
        l.fill(lid, with: lin([(KoruRGB(hex: "#4EBBC3").color(), 0), (KoruRGB(hex: "#36A6B2").color(), 1)], CGPoint(x: 0, y: -dr), CGPoint(x: 0, y: y0)))
        var crease = Path()
        crease.move(to: CGPoint(x: dr, y: y0 - dr * 0.1))
        crease.addQuadCurve(to: CGPoint(x: -dr, y: y0 - dr * 0.1), control: CGPoint(x: 0, y: y0 + dr * 0.16))
        c.stroke(crease, with: .color(KoruRGB(hex: "#164149").color()), style: StrokeStyle(lineWidth: R * 0.022, lineCap: .round))
    }
}

extension KoruGeometry {
    /// Body space → Koru's canvas, as Koru.draw places the body: on whole pixels when full, rolled, squashed.
    var koruBodyToCanvas: CGAffineTransform {
        let by = cy + ryB * (1 - sy)
        var T = full ? CGAffineTransform(translationX: (cx * scale).rounded() / scale, y: (by * scale).rounded() / scale)
                     : CGAffineTransform(translationX: cx, y: by)
        if pose.rollSelf && pose.roll != 0 { T = T.rotated(by: pose.roll) }
        return T.scaledBy(x: sx, y: sy)
    }
}

extension BotEngine {
    /// The Mac's mood on Koru (MochiMood.swift's levels, drawn as mood.js draws them); none while she is calm.
    func koruMoodLayers() -> KoruLayers {
        var L = KoruLayers()
        guard !isMini else { return L }
        let hot = moodHot, busy = moodBusy, tired = moodTired, tremble = stressTremble
        let drops = moodDrops.isEmpty ? [] : KoruMood.drops(moodDrops)
        if hot > 0.01 || !drops.isEmpty {
            // Behind her: the heat out of her base, and the sweat leaving from behind her sides (it never crosses her face).
            L.behind.append { b, d in
                if hot > 0.01 { KoruMood.heatGlow(b, d, hot) }
                guard !drops.isEmpty else { return }
                var c = b
                c.concatenate(d.koruBodyToCanvas.inverted())
                let rest = CGPoint(x: d.cx - d.pose.ox * d.R, y: d.cy - d.pose.oy * d.R)
                KoruMood.sweat(c, drops, R: d.R, rest: rest, canvas: d.size, scale: d.scale, now: CACurrentMediaTime())
            }
        }
        if hot > 0.01 {
            L.floor.append { c, d in KoruMood.floorGlow(c, d, hot) }
            L.body.append { c, d in KoruMood.flush(c, d, hot) }
            L.face.append { c, d in KoruMood.cheeks(c, d, hot) }
            if hot > 0.5 { L.front.append { c, d in KoruMood.heatWaves(c, d, (hot - 0.5) * 2, t: d.pose.t) } }
        }
        if busy > 0.01 || tired > 0.5 {
            L.eye.append { c, e in
                if tired > 0.5 && e.shape == .tired { KoruMood.drowsy(c, e); return true }
                if busy > 0.01 && e.shape == .pill { KoruMood.tense(c, e, busy: busy, tremble: tremble); return true }
                return false
            }
        }
        return L
    }
}
