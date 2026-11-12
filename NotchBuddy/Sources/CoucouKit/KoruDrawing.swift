import SwiftUI
import CoreGraphics

// Koru drawn into a SwiftUI GraphicsContext: core.js draw() and eye(), frame for frame. Live shapes (face, eyes, beak,
// wings, gradients) are drawn every frame; their blurred shading comes from KoruSheets. Badge, aura and particles are
// drawn by drawFront(), outside the body's transform, as BotEngine draws Mochi's.

@MainActor
enum Koru {
    /// The single switch: BotEngine (and the greeting) draw Koru instead of Mochi while it is on. Set once, at launch.
    nonisolated(unsafe) static var enabled = true
    /// Koru's size in a canvas (1 = the prototype's targets). 0.8 leaves room for hops, squashes, the raised wing and
    /// the tufts, and gives her Mochi's height on screen.
    static var frame: CGFloat = 0.8
    /// Canvas shadowBlur → GraphicsContext shadow radius.
    static var shadowK: CGFloat = 0.55
}

/// Everything a frame of Koru needs, read from BotEngine (or any other driver).
struct KoruPose {
    var yaw: CGFloat = 0, pitch: CGFloat = 0, tilt: CGFloat = 0
    /// Radians (BotEngine's roll).
    var roll: CGFloat = 0
    /// False when the caller already turns the whole canvas (BotCanvasView's rigid roll with an outfit).
    var rollSelf = true
    var open: CGFloat = 1, sx: CGFloat = 1, sy: CGFloat = 1, ox: CGFloat = 0, oy: CGFloat = 0
    var hy: CGFloat = 0, ear: CGFloat = 0, tint: CGFloat = 0.2, go: CGFloat = 0.6
    var hands: CGFloat = 0, blush: CGFloat = 0, es: CGFloat = 1, badgeS: CGFloat = 0, auraA: CGFloat = 0
    var col = KoruRGB(hex: "#1EAAC8")
    var palette: KoruPalette? = nil
    var mini = false
    var eye: EyeShape = .pill
    var cfg: KoruStateCfg = KoruStates[.idle]
    var aura: KoruAura? = nil
    /// Seconds, for what animates in the drawing itself (badge dots, spiral eyes, aura).
    var t: CGFloat = 0
    /// CACurrentMediaTime(), for the wave.
    var now: Double = 0
    var waveStart: Double = 0, waveUntil: Double = 0
    var handSide: CGFloat = -1
    var cup = false
    var overhang: CGFloat = 0
    var frame: CGFloat = 0.8
}

/// Where Koru stands in a canvas.
struct KoruFrame {
    let R, rx, ryB, ryT, cx, cy, sx, sy: CGFloat

    init(size: CGSize, pose p: KoruPose) {
        R = size.width * 0.3 * p.frame
        rx = R * KoruShape.rx; ryB = R * KoruShape.ryBot; ryT = R * KoruShape.ryTop
        cx = size.width / 2 + p.ox * R
        cy = size.height / 2 + p.overhang / 2 + (KoruShape.cy + p.oy) * R
        sx = p.sx; sy = p.sy
    }
}

extension Koru {
    private typealias S = KoruShape

    private static func lin(_ stops: [(Color, CGFloat)], _ a: CGPoint, _ b: CGPoint) -> GraphicsContext.Shading {
        .linearGradient(Gradient(stops: stops.map { .init(color: $0.0, location: $0.1) }), startPoint: a, endPoint: b)
    }
    private static func rad(_ stops: [(Color, CGFloat)], _ c: CGPoint, _ r: CGFloat) -> GraphicsContext.Shading {
        .radialGradient(Gradient(stops: stops.map { .init(color: $0.0, location: $0.1) }), center: c, startRadius: 0, endRadius: r)
    }
    private static func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> Path { Path(CGRect(x: x, y: y, width: w, height: h)) }

    /// A soft shadow of a shape without the shape (core.js drop, live).
    private static func drop(_ ctx: GraphicsContext, _ path: Path, _ color: Color, _ blur: CGFloat, _ dx: CGFloat = 0, _ dy: CGFloat = 0) {
        var c = ctx
        c.addFilter(.shadow(color: color, radius: blur * shadowK, x: dx, y: dy, options: .shadowOnly))
        c.fill(path, with: .color(.black))
    }
    /// Inner light or shade along the edges of a shape (core.js inner, live), inside the current clip.
    private static func inner(_ ctx: GraphicsContext, _ path: Path, _ color: Color, _ blur: CGFloat, _ dx: CGFloat = 0, _ dy: CGFloat = 0) {
        var c = ctx
        c.clip(to: path)
        c.addFilter(.shadow(color: color, radius: blur * shadowK, x: dx, y: dy, options: [.invertsAlpha, .shadowOnly]))
        c.fill(path, with: .color(.black))
    }
    private static func grainStamp(_ ctx: GraphicsContext, _ path: Path, _ s: KoruSheets.Sheet?, alpha: CGFloat, R: CGFloat) {
        guard s != nil else { return }
        var c = ctx
        c.clip(to: path)
        c.blendMode = .softLight
        c.opacity *= Double(alpha)
        KoruSheets.stamp(c, s, R: R)
    }

    // MARK: - Body, wings, head

    /// layers: draw hooks (KoruLayers.swift) run at their z-points; `.none` draws Koru alone.
    static func draw(_ context: GraphicsContext, size: CGSize, pose p: KoruPose, layers L: KoruLayers = .none) {
        KoruSheets.beginFrame()
        let scale = max(1, context.environment.displayScale)
        let fr = KoruFrame(size: size, pose: p)
        let R = fr.R, rx = fr.rx, ryB = fr.ryB, cx = fr.cx, cy = fr.cy, sxE = fr.sx, syE = fr.sy
        guard R > 0.5 else { return }
        let Rpx = R * scale
        // The grain is 1.6 px noise made for a Koru of ~350 px R; smaller, it would read as sand, so it fades.
        let grainK = S.clamp(Rpx / 150, 0.3, 1)
        let full = !p.mini
        let P = p.palette ?? .koru
        let col = p.col, tint = p.tint, glowA = p.go
        let cool = S.clamp((col.b - col.r) / 255 + 0.3, 0, 1)
        let yawN = S.clamp(p.yaw / 0.62, -1, 1), pitN = S.clamp(p.pitch / 0.5, -1, 1)
        let f = sin(p.yaw) * S.face, fx = f * R
        let lit = 1 + 0.9 * max(0, tint - 0.3)
        let upright = (1 + cos(p.roll)) / 2
        // The head transform from the body's space, and where the beak sits in it: the head turns rigidly, the body's
        // squash undone around the turn, so a tilted head is never sheared.
        let headT = CGAffineTransform(translationX: 0, y: p.hy * R - R * 0.15).scaledBy(x: 1 / sxE, y: 1 / syE)
            .rotated(by: p.tilt).scaledBy(x: sxE, y: syE).translatedBy(x: 0, y: R * 0.15)
        let body = S.scaled(S.body, R)
        // What the hooks get, filled in as the frame is drawn.
        var d = KoruGeometry(size: size, R: R, rx: rx, ryB: ryB, ryT: fr.ryT, cx: cx, cy: cy, sx: sxE, sy: syE, pose: p, col: col, tint: tint,
                             yawN: yawN, pitN: pitN, f: f, fx: fx, scale: scale, head: headT, beakAt: CGPoint(x: fx * 1.08, y: R * 0.096), body: body)
        func layer(_ hooks: [KoruLayers.Hook], _ ctx: GraphicsContext) { for hook in hooks { hook(ctx, d) } }

        // Floor glow: a saturated band where the body meets the floor, and a wider pool.
        for (k, sk, r0, a0) in [(1.0, 0.09, 1.15, 0.7), (1.02, 0.16, 1.4, 0.35)] as [(CGFloat, CGFloat, CGFloat, CGFloat)] {
            let a = a0 * glowA * lit, r = rx * r0 * (1 + 0.2 * (lit - 1))
            var c = context
            c.translateBy(x: cx, y: cy + ryB * syE * k)
            c.scaleBy(x: 1, y: sk)
            c.fill(S.circle(0, 0, r), with: rad([(col.mix(.white, 0.1).color(S.clamp(a, 0, 1)), 0), (col.color(S.clamp(0.5 * a, 0, 1)), 0.4),
                                                 (col.color(0.12 * a), 0.75), (col.color(0), 1)], .zero, r))
        }
        layer(L.floor, context)

        // Squash keeps the base on the floor; full size, the body sits on whole pixels so its shading lines up with its edge.
        let by = cy + ryB * (1 - syE)
        var b = context
        if full { b.translateBy(x: (cx * scale).rounded() / scale, y: (by * scale).rounded() / scale) } else { b.translateBy(x: cx, y: by) }
        if p.rollSelf && p.roll != 0 { b.rotate(by: .radians(p.roll)) }
        b.scaleBy(x: sxE, y: syE)
        d.bodyT = bodyTransform(cx: cx, by: by, pose: p, sx: sxE, sy: syE, scale: scale)

        // Sheet boxes (px at Rq): the body, its halo, and the canvas at frame 1, which limits the widest shading.
        func boxes(_ Rq: CGFloat) -> (BB: CGRect, SB: CGRect, HB: CGRect, C1: CGRect, body: CGPath) {
            let rxq = Rq * S.rx, ryTq = Rq * S.ryTop, ryBq = Rq * S.ryBot
            let BB = CGRect(x: -rxq, y: -ryTq, width: 2 * rxq, height: ryTq + ryBq)
            return (BB, BB.insetBy(dx: -2, dy: -2), BB.insetBy(dx: -Rq * 0.6, dy: -Rq * 0.6),
                    CGRect(x: -Rq / 0.6, y: -Rq / 0.6 - S.cy * Rq, width: 2 * Rq / 0.6, height: 2 * Rq / 0.6), S.scaled(S.body, Rq).cgPath)
        }

        if full {
            // Bloom: the state colour from below only, then a faint cyan halo all round.
            if tint > 0.3 {
                let s = KoruSheets.get("bloom", R: Rpx) { Rq in
                    let x = boxes(Rq)
                    return KoruSheets.render(box: x.HB, R: Rq) { g, _ in
                        KoruSheets.drop(g, x.body, CGColor(gray: 1, alpha: 1), Rq * 0.24, 0, Rq * 0.07)
                        g.setBlendMode(.destinationOut)
                        KoruSheets.fillLinear(g, CGRect(x: x.HB.minX, y: x.HB.minY, width: x.HB.width, height: Rq * 0.3 - x.HB.minY),
                                              [CGColor(gray: 0, alpha: 0), CGColor(gray: 0, alpha: 1)], [0, 1],
                                              from: CGPoint(x: 0, y: Rq * 0.3), to: CGPoint(x: 0, y: -Rq * 0.15))
                    }
                }
                KoruSheets.stampTint(b, s, R: R, color: col.color(min(1, 1.15 * (tint - 0.3)) * upright))
            }
            KoruSheets.stamp(b, KoruSheets.get("halo", R: Rpx) { Rq in
                let x = boxes(Rq)
                return KoruSheets.render(box: x.HB, R: Rq) { g, _ in
                    KoruSheets.drop(g, x.body, CGColor(srgbRed: 40 / 255, green: 170 / 255, blue: 200 / 255, alpha: 0.12), Rq * 0.08, 0, Rq * 0.05)
                    KoruSheets.drop(g, x.body, CGColor(srgbRed: 30 / 255, green: 150 / 255, blue: 180 / 255, alpha: 0.14), Rq * 0.2, 0, Rq * 0.11)
                }
            }, R: R)
        }

        // Wings: the far one (the side the head turns to) folds back behind the body; the near one rises and waves.
        let wt = CGFloat(p.now - p.waveStart)
        let waving = p.waveStart > 0 && p.now >= p.waveStart && p.now < p.waveUntil
        let wave: CGFloat = waving ? min(S.easeOut(min(1, wt / 0.18)), S.clamp(CGFloat(p.waveUntil - p.now) / 0.15, 0, 1)) : 0
        struct Wing { let sd, far, lift, base: CGFloat; let cup: Bool; let sway: CGFloat }
        let side = p.handSide
        let wings: [Wing] = [-1, 1].map { (sd: CGFloat) in
            var lift: CGFloat = sd == side ? p.hands : 0
            if sd == side && wave > 0 { lift += sin(wt * 13) * 0.17 * wave * min(1, p.hands) }
            return Wing(sd: sd, far: S.clamp(sd * yawN, 0, 1), lift: lift, base: sd == side ? p.hands : 0,
                        cup: sd == side && p.cup, sway: sd != side && wave > 0 ? sin(6 * wt) * 0.07 * wave : 0)
        }
        // The wing's transform in the body's space; shapes are drawn for the left side.
        func wingM(_ w: Wing, _ over: CGFloat, lift: CGFloat? = nil) -> CGAffineTransform {
            let lift = lift ?? w.lift
            var M = CGAffineTransform(scaleX: -w.sd, y: 1).translatedBy(x: 0, y: R * 0.15 * w.far)
                .translatedBy(x: -R * 1.42, y: 0).scaledBy(x: 1 - 0.25 * w.far, y: 1).translatedBy(x: R * 1.42, y: 0)
            if w.sway != 0 { M = M.translatedBy(x: -R * 1.05, y: -R * 0.05).rotated(by: w.sway).translatedBy(x: R * 1.05, y: R * 0.05) }
            let L = min(S.clamp(lift, 0, 1.3), 1)
            if w.cup {   // up beside the head, its top flaring out
                return M.translatedBy(x: -R * 1.1, y: -R * 0.05).translatedBy(x: R * 0.07 * L, y: -R * 0.47 * L)
                    .rotated(by: -0.2 * L).scaledBy(x: 1, y: 1 + 0.12 * L).translatedBy(x: R * 1.1, y: R * 0.05)
            }
            // Raising: the wing swings up from its root and turns over (over: 1 before, -1 after); never edge-on.
            let k = cos(.pi * S.smooth(S.clamp(lift / 0.45, 0, 1)))
            return M.translatedBy(x: -R * 1.1, y: -R * 0.05)
                .translatedBy(x: -R * 0.06 * L + R * 0.2 * (1 - abs(k)) + R * 1.2 * L * (1 - L), y: -R * 0.2 * L)
                .rotated(by: lift * 2.78).scaledBy(x: over * max(0.3, over * k), y: 1).translatedBy(x: R * 1.1, y: R * 0.05)
        }
        func at(_ M: CGAffineTransform, _ u: CGFloat, _ v: CGFloat) -> CGPoint { CGPoint(x: u * R, y: v * R).applying(M) }
        func dir(_ a: CGPoint, _ q: CGPoint) -> CGFloat { atan2(q.y - a.y, q.x - a.x) }
        // Raised (turned over), the wing is also flipped top to bottom about its centre, so the feather tips point up;
        // the wave then turns it round the shoulder at its base.
        func wingT(_ w: Wing, _ over: CGFloat) -> CGAffineTransform {
            let M = wingM(w, over)
            guard over < 0 && !w.cup else { return M }
            let M0 = wingM(w, over, lift: w.base), c = at(M0, -1.2, 0.23), e = at(M0, -1.11, 0.55)
            let sh = CGPoint(x: e.x, y: 2 * c.y - e.y)
            let turn = dir(at(M, -1.1, -0.05), at(M, -1.1, 0.55)) - dir(sh, at(M0, -1.1, 0.55))
            let A = CGAffineTransform(translationX: sh.x, y: sh.y).rotated(by: turn).translatedBy(x: -sh.x, y: -sh.y)
                .translatedBy(x: c.x, y: c.y).scaledBy(x: 1, y: -1).translatedBy(x: -c.x, y: -c.y)
            return M0.concatenating(A)
        }
        let wingPath = S.scaled(S.wing, R)
        let traceWings = !L.wings.isEmpty
        // While it turns over, its two faces cross-fade; otherwise one is drawn.
        func drawWing(_ ctx: GraphicsContext, _ w: Wing, front: Bool) {
            let k = cos(.pi * S.smooth(S.clamp(w.lift / 0.45, 0, 1))), v = w.cup ? 0 : S.smooth(S.clamp((0.25 - k) / 0.5, 0, 1))
            for over in [1, -1] as [CGFloat] {
                let a = over > 0 ? 1 - v : v
                if a < 0.01 { continue }
                var c = ctx
                c.opacity *= Double(a)
                let mx = -w.sd * over, my = over   // how the wing's x and y map to the screen's (light from the top right)
                let T = wingT(w, over)
                if full && front {
                    var s = c
                    s.clip(to: body)
                    s.concatenate(T)
                    KoruSheets.stamp(s, KoruSheets.get("wingShadow\(mx)\(my)", R: Rpx) { Rq in
                        let WB = CGRect(x: -Rq * 1.45, y: -Rq * 0.16, width: Rq * 0.51, height: Rq * 0.76)
                        return KoruSheets.render(box: WB.insetBy(dx: -Rq * 0.3, dy: -Rq * 0.3), R: Rq) { g, _ in
                            KoruSheets.drop(g, S.scaled(S.wing, Rq).cgPath, CGColor(srgbRed: 1 / 255, green: 22 / 255, blue: 27 / 255, alpha: 0.45),
                                            Rq * 0.12, Rq * 0.02 * mx, Rq * 0.035 * my)
                        }
                    }, R: R)
                }
                if traceWings { d.wings.addPath(wingPath, transform: T) }
                c.concatenate(T)
                c.fill(wingPath, with: lin([(P.wing[0], 0), (P.wing[1], 1)], CGPoint(x: -R * 1.3, y: -R * 0.1), CGPoint(x: -R * 1.0, y: R * 0.56)))
                if full {
                    KoruSheets.stamp(c, KoruSheets.get("wing\(mx)\(my)", R: Rpx) { Rq in
                        let WB = CGRect(x: -Rq * 1.45, y: -Rq * 0.16, width: Rq * 0.51, height: Rq * 0.76), wing = S.scaled(S.wing, Rq).cgPath
                        return KoruSheets.render(box: WB.insetBy(dx: -2, dy: -2), pad: Rq * 0.2, R: Rq) { g, room in
                            KoruSheets.inner(g, room: room, wing, CGColor(srgbRed: 80 / 255, green: 200 / 255, blue: 220 / 255, alpha: 0.6),
                                             Rq * 0.025, Rq * 0.008 * mx, Rq * 0.018 * my, box: WB)
                            KoruSheets.inner(g, room: room, wing, CGColor(srgbRed: 0, green: 20 / 255, blue: 25 / 255, alpha: 0.35),
                                             Rq * 0.06, -Rq * 0.03 * mx, 0, box: WB)
                        }
                    }, R: R)
                }
            }
        }
        layer(L.behind, b)
        // A wing goes behind the body as it folds back or rises.
        for w in wings where w.far > 0.35 || (w.lift > 0.02 && !w.cup) { drawWing(b, w, front: false) }

        // Body: key light from the top right, an elliptical gradient (filled in a stretched space).
        do {
            let kx = R * 0.18 + fx * 0.2, ky = -R * 0.92
            var c = b
            c.translateBy(x: kx, y: ky); c.scaleBy(x: 1.5, y: 1)
            let bp = body.applying(CGAffineTransform(scaleX: 1 / 1.5, y: 1).translatedBy(x: -kx, y: -ky))
            c.fill(bp, with: rad([(P.body[0], 0), (P.body[1], 0.12), (P.body[2], 0.3), (P.body[3], 0.56), (P.body[4], 1)], .zero, R * 1.45))
        }
        if full {
            grainStamp(b, body, KoruSheets.get("grainBody", R: Rpx) { Rq in
                let x = boxes(Rq)
                return KoruSheets.grain(box: x.SB, y0: -Rq * S.ryTop, y1: Rq * 0.2, R: Rq)
            }, alpha: 0.62 * grainK, R: R)
            KoruSheets.stamp(b, KoruSheets.get("shade", R: Rpx) { Rq in   // sides and base turn away; the top stays lit
                let x = boxes(Rq)
                return KoruSheets.render(box: x.SB, pad: Rq, clip: x.C1, R: Rq) { g, room in
                    KoruSheets.inner(g, room: room, x.body, CGColor(srgbRed: 4 / 255, green: 48 / 255, blue: 56 / 255, alpha: 0.38), Rq * 0.4, 0, -Rq * 0.12, box: x.BB)
                }
            }, R: R)
            var c = b
            c.clip(to: body)
            c.fill(rect(-R, -R * 1.1, R * 2, R * 1.3), with: rad([(koruRGBA(0, 62, 72, 0.22), 0), (koruRGBA(0, 62, 72, 0), 1)], CGPoint(x: fx, y: -R * 0.45), R * 0.38))
        }
        // Belly, fading into the body at the bottom.
        var belly = Path()
        belly.addEllipse(in: CGRect(x: fx * 0.75 - R * 0.532, y: R * 0.94 - R * 0.52, width: R * 1.064, height: R * 1.04))
        d.belly = belly
        do {
            var c = b
            c.clip(to: body)
            c.fill(belly, with: lin([(P.belly[0], 0), (P.belly[1], 0.75), (P.belly[2], 1)], CGPoint(x: 0, y: R * 0.42), CGPoint(x: 0, y: ryB)))
            // Bounce light at the base; blue-ish states tint the lower body.
            c.fill(rect(-rx, ryB - R * 0.1, rx * 2, R * 0.14),
                   with: lin([(KoruRGB(60, 180, 200).mix(col, min(1, 0.9 * tint)).color(0.3 + 0.2 * tint), 0), (koruRGBA(70, 195, 210, 0), 1)],
                             CGPoint(x: 0, y: ryB), CGPoint(x: 0, y: ryB - R * 0.1)))
            if P.isKoru {   // teal side light: Koru's own colours only
                c.fill(rect(-rx, -R * 0.2, rx * 2, ryB + R * 0.2),
                       with: lin([(koruRGBA(40, 150, 165, 0), 0.45), (koruRGBA(40, 150, 165, 0.16), 1)], CGPoint(x: -rx, y: 0), CGPoint(x: rx, y: 0)))
            }
        }
        if full {
            grainStamp(b, belly, KoruSheets.get("grainBelly", R: Rpx) { Rq in
                KoruSheets.grain(box: CGRect(x: -Rq * 0.72, y: Rq * 0.38, width: Rq * 1.44, height: Rq * S.ryBot + 2 - Rq * 0.38),
                                 y0: Rq * 0.4, y1: Rq * S.ryBot, R: Rq)
            }, alpha: 0.17 * grainK, R: R)
        }
        if tint > 0.3 {   // state light shining through the lower body
            var c = b
            c.clip(to: body)
            c.blendMode = .screen
            c.fill(rect(-rx, ryB - R * 0.6, rx * 2, R * 0.65),
                   with: lin([(col.color(0.4 * tint * (0.45 + 0.55 * cool)), 0), (col.color(0), 1)], CGPoint(x: 0, y: ryB), CGPoint(x: 0, y: ryB - R * 0.6)))
        }
        if full {
            KoruSheets.stamp(b, KoruSheets.get("rims", R: Rpx) { Rq in
                let x = boxes(Rq)
                return KoruSheets.render(box: x.SB, pad: Rq * 0.3, clip: x.C1, R: Rq) { g, room in
                    KoruSheets.inner(g, room: room, x.body, CGColor(srgbRed: 190 / 255, green: 240 / 255, blue: 248 / 255, alpha: 0.95), Rq * 0.06, 0, Rq * 0.035, box: x.BB)
                    KoruSheets.inner(g, room: room, x.body, CGColor(srgbRed: 214 / 255, green: 248 / 255, blue: 252 / 255, alpha: 0.6), Rq * 0.02, 0, Rq * 0.01, box: x.BB)
                    g.saveGState(); g.addPath(x.body); g.clip()   // broad soft sheen, no hard spot
                    KoruSheets.drop(g, CGPath(ellipseIn: CGRect(x: Rq * 0.16 - Rq * 0.29, y: -Rq * 0.92 - Rq * 0.08, width: Rq * 0.58, height: Rq * 0.16), transform: nil),
                                    CGColor(srgbRed: 220 / 255, green: 248 / 255, blue: 251 / 255, alpha: 0.38), Rq * 0.08)
                    g.restoreGState()
                    KoruSheets.inner(g, room: room, x.body, CGColor(srgbRed: 70 / 255, green: 190 / 255, blue: 215 / 255, alpha: 0.7), Rq * 0.09, -Rq * 0.06, 0, box: x.BB)
                    KoruSheets.inner(g, room: room, x.body, CGColor(srgbRed: 65 / 255, green: 172 / 255, blue: 200 / 255, alpha: 0.55), Rq * 0.08, Rq * 0.05, 0, box: x.BB)
                }
            }, R: R)
            // State light: a soft band of the state colour along the bottom and lower sides (a wide pass, and a
            // narrower one for the brighter bottom edge).
            func lower(_ g: CGContext, _ SB: CGRect, _ Rq: CGFloat) {
                g.setBlendMode(.destinationIn)
                KoruSheets.fillLinear(g, SB, [CGColor(gray: 0, alpha: 0), CGColor(gray: 0, alpha: 1)], [0, 1], from: .zero, to: CGPoint(x: 0, y: Rq * 0.65))
            }
            KoruSheets.stampTint(b, KoruSheets.get("state1", R: Rpx) { Rq in
                let x = boxes(Rq)
                return KoruSheets.render(box: x.SB, pad: Rq * 0.4, clip: x.C1, R: Rq) { g, room in
                    KoruSheets.inner(g, room: room, x.body, CGColor(gray: 1, alpha: 1), Rq * 0.15, 0, -Rq * 0.08, box: x.BB)
                    lower(g, x.SB, Rq)
                }
            }, R: R, color: col.color(min(1, 0.08 + 1.2 * max(0, tint - 0.2)) * upright))
            if tint > 0.3 {
                KoruSheets.stampTint(b, KoruSheets.get("state2", R: Rpx) { Rq in
                    let x = boxes(Rq)
                    return KoruSheets.render(box: x.SB, pad: Rq * 0.25, clip: x.C1, R: Rq) { g, room in
                        KoruSheets.inner(g, room: room, x.body, CGColor(gray: 1, alpha: 1), Rq * 0.05, 0, -Rq * 0.03, box: x.BB)
                        lower(g, x.SB, Rq)
                    }
                }, R: R, color: col.mix(.white, 0.1).color(0.9 * (tint - 0.3) / 0.7 * upright))
            }
        }
        layer(L.body, b)
        for w in wings {   // a cupped wing stays in front
            let a = (1 - S.smooth(S.clamp((w.far - 0.35) / 0.3, 0, 1))) * (w.cup || w.lift < 0.6 ? 1 : 0)
            if a > 0.01 { var c = b; c.opacity *= Double(a); drawWing(c, w, front: true) }
        }
        layer(L.wings, b)

        // Head: lower in busy states, tilts around the neck.
        var h = b
        h.concatenate(headT)
        let ex = S.eyeSp, ey = R * S.eyeY, shape = p.eye
        // eyes: each orange disc in the head's space, squeezed for the head turn
        struct Eye { let sd, far, x, y, r, kx, ky: CGFloat }
        let eyes: [Eye] = [-1, 1].map { (sd: CGFloat) in
            let far = max(0, sd * yawN), near = max(0, -sd * yawN)
            return Eye(sd: sd, far: far, x: sd * ex * R + fx - R * 0.013 * abs(yawN), y: ey,
                       r: R * S.disc * (shape == .wide ? 1.04 : 1) * p.es, kx: 1 + 0.057 * near - 0.085 * far, ky: 1 - far * 0.015)
        }
        d.eyes = eyes.map { KoruEyeDisc(sd: $0.sd, far: $0.far, x: $0.x, y: $0.y, r: $0.r, kx: $0.kx, ky: $0.ky) }
        layer(L.headBack, h)
        var face = Path(), tufts = Path()
        let badgeFold = p.cfg.fold ? p.badgeS : 0
        for sd in [-1, 1] as [CGFloat] {
            let far = max(0, sd * yawN), near = max(0, -sd * yawN)
            face.addPath(S.toPath(S.ringPts(sd * ex + f, S.eyeY, S.ring, 1 - 0.16 * far + 0.07 * near, sd, 0.05, 0.15 + 0.1 * far), R))
            face.addPath(S.outline(S.mirror(S.browSegs(-f * sd, far), -sd), R))
            face.addPath(S.toPath(S.pts([[f + sd * 0.002, -0.247], [f + sd * 0.05, -0.272], [f + sd * 0.035, -0.205], [f, -0.215]]), R))
            let tp = S.mirror(S.tuftPts(-f * sd * 0.15, p.ear + (sd < 0 ? 0.55 * badgeFold : 0), far), -sd)
            let tf = S.blob(S.pts(tp), R)
            tufts.addPath(tf); face.addPath(tf)
        }
        d.face = face; d.tufts = tufts
        if full { drop(h, tufts, koruRGBA(2, 40, 46, 0.35), R * 0.05, 0, R * 0.035) }
        h.fill(face, with: lin([(P.face[0], 0), (P.face[1], 0.35), (P.face[2], 1)],
                               CGPoint(x: 0, y: -R * 1.15), CGPoint(x: 0, y: ey + R * S.ring)))
        if full {
            do {   // light from the right
                var c = h
                c.clip(to: face)
                c.fill(rect(-R * 1.5, -R * 1.5, R * 3, R * 2.5),
                       with: lin([(koruRGBA(255, 255, 255, 0), 0), (koruRGBA(200, 245, 250, 0.1), 1)], CGPoint(x: -R * 1.2, y: 0), CGPoint(x: R * 1.2, y: 0)))
            }
            var c = h   // a soft clay tuft
            c.clip(to: tufts)
            for sd in [-1, 1] as [CGFloat] {
                let tx = -sd * 1.08 * R + fx * 0.15
                c.fill(rect(tx - R * 0.4, -R * 1.45, R * 0.8, R * 0.7), with: rad([(P.glow.color(0.4), 0), (P.glow.color(0), 1)], CGPoint(x: tx, y: -R * 1.1), R * 0.32))
                let lx = -sd * 1.12 * R + fx * 0.15
                c.fill(rect(lx - R * 0.3, -R * 1.0, R * 0.6, R * 0.6), with: rad([(P.glow.color(0.3), 0), (P.glow.color(0), 1)], CGPoint(x: lx, y: -R * 0.72), R * 0.22))
            }
            grainStamp(c, tufts, KoruSheets.get("grainTufts", R: Rpx) { Rq in
                KoruSheets.grain(box: CGRect(x: -Rq * 1.45, y: -Rq * 1.4, width: Rq * 2.9, height: Rq * 1.05),
                                 y0: -Rq * 1.2, y1: -Rq * 0.5, x0: Rq * 0.65, x1: Rq * 0.92, R: Rq)
            }, alpha: 0.45 * grainK, R: R)
            inner(c, face, koruRGBA(175, 238, 246, 0.8), R * 0.03, 0, R * 0.022)
            inner(c, face, koruRGBA(4, 50, 58, 0.35), R * 0.04, 0, -R * 0.025)
        }
        if p.blush > 0.01 && shape != .happy {   // love and proud: a blush on each ring
            var c = h
            c.clip(to: face)
            for e in eyes {
                let bx = e.x + e.sd * R * 0.22, by = ey + R * 0.43
                c.fill(rect(bx - R * 0.16, by - R * 0.16, R * 0.32, R * 0.32),
                       with: rad([(koruRGBA(255, 84, 128, 0.6 * p.blush), 0), (koruRGBA(255, 84, 128, 0), 1)], CGPoint(x: bx, y: by), R * 0.16))
            }
        }
        layer(L.face, h)
        for e in eyes {
            let dr = e.r
            var c = h
            c.translateBy(x: e.x, y: e.y); c.scaleBy(x: e.kx, y: e.ky)
            c.fill(S.circle(0, 0, dr), with: lin([(KoruRGB(hex: "#F8FAFA").color(), 0), (KoruRGB(hex: "#DAE2E4").color(), 1)], CGPoint(x: 0, y: -dr), CGPoint(x: 0, y: dr)))   // white eye discs (owner's choice)
            if full {   // shading drawn for the resting disc, scaled with it
                let d0 = R * S.disc
                var s = c
                s.scaleBy(x: dr / d0, y: dr / d0)
                KoruSheets.stamp(s, KoruSheets.get("disc", R: Rpx) { Rq in
                    let d = Rq * S.disc, box = CGRect(x: -d, y: -d, width: 2 * d, height: 2 * d)
                    return KoruSheets.render(box: box.insetBy(dx: -2, dy: -2), pad: Rq * 0.1, R: Rq) { g, room in
                        KoruSheets.inner(g, room: room, CGPath(ellipseIn: box, transform: nil),
                                         CGColor(srgbRed: 30 / 255, green: 70 / 255, blue: 80 / 255, alpha: 0.16), Rq * 0.035, 0, Rq * 0.012, box: box)
                    }
                }, R: R)
            }
            let dl = dr + R * 0.005   // a hair wider than the disc, so a lid covers its antialiased rim
            c.clip(to: S.circle(0, 0, dl))
            eye(c, shape: shape, dr: dr, sd: e.sd, yawN: yawN, pitN: pitN, far: e.far, R: R, pose: p, hooks: L.eye)
            let lid = 1 - p.open
            if lid > 0.01 {   // the lid comes down with a rounded edge and a thin lash line
                c.fill(S.lidPath(dl, lid), with: lin([(P.lid[0], 0), (P.lid[1], 1)],
                                                     CGPoint(x: 0, y: -dr), CGPoint(x: 0, y: dr * (2 * lid - 1))))
                if lid < 0.98 { c.stroke(S.lidEdge(dr, lid), with: .color(koruRGBA(22, 65, 73, 0.55)), lineWidth: R * 0.016) }
            }
        }
        // Beak: a matte teardrop lit from the right, unless a hook draws its own.
        var k = h
        k.translateBy(x: d.beakAt.x, y: d.beakAt.y)
        let br = R * 0.125, tip = R * 0.18, beak = S.beak(br, tip)
        d.br = br; d.tip = tip; d.beak = beak
        var custom = false
        for hook in L.beak where hook(k, d) { custom = true; break }
        if !custom { beakFinish(k, beak, br: br, tip: tip, R: R, Rpx: Rpx, full: full) }
        layer(L.headFront, h)
        layer(L.headTop, h)
    }

    /// Body space → canvas space, as draw() sets up the body's context (by: the base kept on the floor through the squash).
    private static func bodyTransform(cx: CGFloat, by: CGFloat, pose p: KoruPose, sx: CGFloat, sy: CGFloat, scale: CGFloat) -> CGAffineTransform {
        let t = !p.mini ? CGPoint(x: (cx * scale).rounded() / scale, y: (by * scale).rounded() / scale) : CGPoint(x: cx, y: by)
        var M = CGAffineTransform(scaleX: sx, y: sy)
        if p.rollSelf && p.roll != 0 { M = M.concatenating(CGAffineTransform(rotationAngle: p.roll)) }
        return M.concatenating(CGAffineTransform(translationX: t.x, y: t.y))
    }

    /// Koru's closed beak, in its own space: contact shadow, fill, inner shade and sheen.
    private static func beakFinish(_ k: GraphicsContext, _ beak: Path, br: CGFloat, tip: CGFloat, R: CGFloat, Rpx: CGFloat, full: Bool) {
        if full {
            KoruSheets.stamp(k, KoruSheets.get("beakShadow", R: Rpx) { Rq in
                KoruSheets.render(box: beakBox(Rq), R: Rq) { g, _ in
                    KoruSheets.drop(g, S.beak(Rq * 0.125, Rq * 0.18).cgPath, CGColor(srgbRed: 4 / 255, green: 45 / 255, blue: 52 / 255, alpha: 0.4), Rq * 0.03, Rq * 0.012, Rq * 0.02)
                }
            }, R: R)
        }
        k.fill(beak, with: lin([(KoruRGB(hex: "#FDB247").color(), 0), (KoruRGB(hex: "#E57D21").color(), 1)], CGPoint(x: 0, y: -br), CGPoint(x: 0, y: tip)))
        if full {
            KoruSheets.stamp(k, KoruSheets.get("beak", R: Rpx) { Rq in
                let bq = S.beak(Rq * 0.125, Rq * 0.18).cgPath, brq = Rq * 0.125, tq = Rq * 0.18
                let IB = CGRect(x: -brq * 1.7, y: -brq * 1.1, width: brq * 3.4, height: tq + Rq * 0.3 + brq * 1.1)
                return KoruSheets.render(box: beakBox(Rq), pad: Rq * 0.1, R: Rq) { g, room in
                    KoruSheets.inner(g, room: room, bq, CGColor(srgbRed: 160 / 255, green: 70 / 255, blue: 8 / 255, alpha: 0.35), Rq * 0.035, 0, -Rq * 0.02, box: IB)
                    g.saveGState(); g.addPath(bq); g.clip()
                    var t = CGAffineTransform(translationX: Rq * 0.035, y: -Rq * 0.06).rotated(by: 0.35)
                    KoruSheets.drop(g, CGPath(ellipseIn: CGRect(x: -Rq * 0.05, y: -Rq * 0.03, width: Rq * 0.1, height: Rq * 0.06), transform: &t),
                                    CGColor(srgbRed: 1, green: 236 / 255, blue: 200 / 255, alpha: 0.45), Rq * 0.03)
                    g.restoreGState()
                }
            }, R: R)
        }
    }

    /// Koru standing where a Mochi of half-height hh had his centre (drawings that place Mochi themselves, as the
    /// greeting): her size to his as in BotEngine's canvases. With a badge kind, her badge too.
    static func draw(_ context: GraphicsContext, centre: CGPoint, mochiHalfHeight hh: CGFloat, pose p: KoruPose,
                     badge: KoruBadgeKind? = nil, badgeColors: (KoruRGB, KoruRGB) = (.white, .white), layers: KoruLayers = .none) {
        let R = frame * hh / 0.88, W = R / (0.3 * p.frame)
        guard W > 1 else { return }
        var c = context
        c.translateBy(x: centre.x - W / 2, y: centre.y - W / 2 - KoruShape.cy * R)
        draw(c, size: CGSize(width: W, height: W), pose: p, layers: layers)
        if badge != nil || !layers.front.isEmpty {
            drawFront(c, size: CGSize(width: W, height: W), pose: p, badge: badge, badgeColors: badgeColors, particles: [], layers: layers)
        }
    }

    /// The beak's sheet box (core.js beakFinish KB), with room for an open beak.
    private static func beakBox(_ Rq: CGFloat) -> CGRect {
        let br = Rq * 0.125, tip = Rq * 0.18
        return CGRect(x: -br * 1.7 - Rq * 0.1, y: -br * 1.1 - Rq * 0.1, width: br * 3.4 + Rq * 0.2, height: tip + Rq * 0.3 + br * 1.1 + Rq * 0.2)
    }

    // MARK: - Eyes

    /// Inside one orange eye disc (radius dr), centred on 0,0 and clipped to it.
    private static func eye(_ c: GraphicsContext, shape: EyeShape, dr: CGFloat, sd: CGFloat, yawN: CGFloat, pitN: CGFloat,
                            far: CGFloat, R: CGFloat, pose p: KoruPose, hooks: [KoruLayers.EyeHook] = []) {
        let ink = KoruRGB(hex: "#164149").color(), cfg = p.cfg, t = p.t
        let pr = R * S.pupil, reach = dr - pr - R * 0.02
        var px = yawN * reach * (cfg.scan ? 1.15 : 0.8) * (1 - 0.08 * far)
        let py = -pitN * reach * 0.85 - far * R * 0.02 - R * 0.014
        if cfg.converge { px += -sd * reach * 0.35 }
        if !hooks.isEmpty {
            let info = KoruEyeInfo(shape: shape, dr: dr, sd: sd, far: far, px: px, py: py, pr: pr, R: R, t: t, yawN: yawN, pitN: pitN, pose: p)
            for hook in hooks where hook(c, info) { return }
        }
        func pupil(_ r: CGFloat) { Koru.pupil(c, at: CGPoint(x: px, y: py), r: r, far: far) }
        func happy() { c.fill(S.crescent(dr * 0.3, dr * 0.7, .pi * 1.1, .pi * 1.9, dr * 0.3), with: .color(ink)) }
        let round = StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round)
        func style(_ w: CGFloat) -> StrokeStyle { var s = round; s.lineWidth = w; return s }
        switch shape {
        case .wide, .cup: pupil(pr * 1.08)
        case .pill: pupil(pr * cfg.pupil)
        case .dot: pupil(pr * 0.55)
        case .flat:
            let w = R * 0.38, h = R * 0.11
            c.fill(S.roundRect(-w / 2 - sd * R * 0.07, -h / 2 + py * 0.2, w, h, h / 2), with: .color(ink))
        case .line:
            var q = c
            q.rotate(by: .radians(-sd * 0.25))
            q.fill(S.roundRect(-dr * 0.5, -R * 0.05, dr, R * 0.1, R * 0.05), with: .color(ink))
        case .happy:
            happy()
            for i in 0..<3 {
                let yy = dr * (0.42 + CGFloat(i) * 0.12), xo = sd * dr * (0.5 + CGFloat(i) * 0.05)
                var l = Path()
                l.move(to: CGPoint(x: xo, y: yy))
                l.addQuadCurve(to: CGPoint(x: xo + sd * dr * 0.2, y: yy - dr * 0.1), control: CGPoint(x: xo + sd * dr * 0.12, y: yy - dr * 0.02))
                c.stroke(l, with: .color(koruRGBA(232, 112, 104, 0.85)), style: style(R * 0.018))
            }
        case .closed:
            var a = Path()
            S.addArc(&a, 0, -dr * 0.18, dr * 0.58, .pi * 0.2, .pi * 0.8, start: true)
            c.stroke(a, with: .color(ink), style: style(R * 0.095))
        case .spiral:
            var s = Path(), qx: CGFloat = 0, qy: CGFloat = 0, aa: CGFloat = 0, a: CGFloat = 0
            while a <= 4 * .pi {
                let r = R * 0.03 + a / (4 * .pi) * R * 0.22
                aa = a + t * 6 * sd; qx = cos(aa) * r; qy = sin(aa) * r
                if a == 0 { s.move(to: CGPoint(x: qx, y: qy)) } else { s.addLine(to: CGPoint(x: qx, y: qy)) }
                a += 0.12
            }
            s.addLine(to: CGPoint(x: qx + cos(aa + 1.2) * R * 0.06, y: qy + sin(aa + 1.2) * R * 0.06))
            c.stroke(s, with: .color(ink), style: style(R * 0.07))
        case .heart:
            c.fill(S.heart(dr * 0.62), with: .color(KoruRGB(hex: "#FF4D6D").color()))
        case .star:
            var q = c
            q.rotate(by: .radians(t * 1.5 * sd))
            q.fill(S.star(dr * 0.6, dr * 0.27), with: .color(KoruRGB(hex: "#F7B32B").color()))
        case .tired:
            pupil(pr)
            c.fill(rect(-dr, -dr, dr * 2, dr * 0.95), with: .color(KoruRGB(hex: "#31A3AF").color()))
            c.fill(S.roundRect(-dr, -dr * 0.07, dr * 2, R * 0.05, R * 0.025), with: .color(ink))
        case .wink:
            if sd < 0 { pupil(pr) } else { happy() }
        }
    }

    /// Koru's pupil (ink with its catch light) of radius r at the pupil's place, for an eye hook drawing its own shape.
    static func pupil(_ c: GraphicsContext, _ info: KoruEyeInfo, r: CGFloat) {
        pupil(c, at: CGPoint(x: info.px, y: info.py), r: r, far: info.far)
    }

    private static func pupil(_ c: GraphicsContext, at q0: CGPoint, r: CGFloat, far: CGFloat) {
        var q = c
        q.translateBy(x: q0.x, y: q0.y); q.scaleBy(x: 1 - far * 0.07, y: 1)
        q.fill(S.circle(0, 0, r), with: .color(KoruRGB(hex: "#164149").color()))
        q.fill(S.circle(r * 0.57, -r * 0.39, r * 0.24), with: .color(koruRGBA(252, 243, 237, 1)))
    }

    // MARK: - Badge, aura, particles

    /// layers: their `front` hooks run last, in canvas space.
    static func drawFront(_ context: GraphicsContext, size: CGSize, pose p: KoruPose, badge: KoruBadgeKind?, badgeColors: (KoruRGB, KoruRGB),
                          particles: [Particle], layers L: KoruLayers = .none) {
        let fr = KoruFrame(size: size, pose: p)
        let R = fr.R, rx = fr.rx, cx = fr.cx, cy = fr.cy, sxE = fr.sx, syE = fr.sy, t = p.t
        guard R > 0.5 else { return }
        let glow: CGFloat = p.mini ? 0 : 1
        if let kind = badge, p.badgeS > 0.01 {
            let bs = p.badgeS * (p.mini ? 1.25 : 1)
            let bo = p.cfg.bo
            var x = context
            x.translateBy(x: cx + (-rx * 0.70 + bo.x * R) * sxE, y: cy + (-R * 0.80 + bo.y * R) * syE)
            x.rotate(by: .radians(p.cfg.brot))
            x.scaleBy(x: bs * p.cfg.bsc, y: bs * p.cfg.bsc)
            let (c0, c1) = badgeColors
            func shine(_ path: Path, _ h: CGFloat) {
                guard glow > 0 else { return }
                var q = x
                q.clip(to: path)
                q.fill(rect(-R, -h, R * 2, h * 1.1), with: lin([(koruRGBA(255, 255, 255, 0.32), 0), (koruRGBA(255, 255, 255, 0), 1)], CGPoint(x: 0, y: -h), CGPoint(x: 0, y: h * 0.1)))
            }
            func fillGlow(_ path: Path, _ r: CGFloat, _ bloom: CGFloat) {
                var q = x
                if glow > 0 { q.addFilter(.shadow(color: c1.color(0.7), radius: R * bloom * shadowK)) }
                q.fill(path, with: lin([(c0.color(), 0), (c1.color(), 1)], CGPoint(x: 0, y: -r), CGPoint(x: 0, y: r)))
            }
            switch kind {
            case .dots where p.mini:
                let ph = (t * 2.4).truncatingRemainder(dividingBy: 1), r = R * 0.22 * (1 + 0.25 * sin(ph * .pi * 2))
                x.fill(S.circle(0, 0, R * 0.2), with: .color(.black))
                x.fill(S.circle(0, 0, r * 0.5), with: .color(c0.color()))
            case .dots:
                let w = R * 0.58, h = R * 0.32, pill = S.roundRect(-w / 2, -h / 2, w, h, h / 2)
                fillGlow(pill, h / 2, 0.09); shine(pill, h / 2)
                var q = x
                q.addFilter(.shadow(color: koruRGBA(255, 255, 255, 0.6), radius: R * 0.02 * shadowK))
                for i in 0..<3 {
                    let ph = ((t * 2.4 - CGFloat(i) * 0.22).truncatingRemainder(dividingBy: 1) + 1).truncatingRemainder(dividingBy: 1)
                    let r = R * 0.04 * (1 + 0.4 * max(0, sin(ph * .pi * 2)))
                    q.fill(S.circle((CGFloat(i) - 1) * R * 0.135, 0, r), with: .color((p.cfg.dot ?? .white).color()))
                }
            case .bang, .q:
                let r = kind == .q ? R * 0.238 : R * 0.22, dot = S.circle(0, 0, r)
                fillGlow(dot, r, 0.1); shine(dot, r)
                if !p.mini { glyph(x, kind, R) }
            case .arrow:
                let r = R * 0.22, dot = S.circle(0, 0, r)
                fillGlow(dot, r, 0.1); shine(dot, r)
                if !p.mini {   // the arrow rises a little now and then
                    let ph = (t * 0.8).truncatingRemainder(dividingBy: 1), lift = ph < 0.25 ? -sin(ph / 0.25 * .pi) * R * 0.035 : 0
                    var a = Path()
                    a.move(to: CGPoint(x: 0, y: R * 0.12 + lift)); a.addLine(to: CGPoint(x: 0, y: -R * 0.11 + lift))
                    a.move(to: CGPoint(x: -R * 0.09, y: -R * 0.02 + lift)); a.addLine(to: CGPoint(x: 0, y: -R * 0.11 + lift))
                    a.addLine(to: CGPoint(x: R * 0.09, y: -R * 0.02 + lift))
                    x.stroke(a, with: .color(.white), style: StrokeStyle(lineWidth: R * 0.055, lineCap: .round, lineJoin: .round))
                }
            case .ring:
                var q = x
                if glow > 0 { q.addFilter(.shadow(color: c1.color(0.6), radius: R * 0.08 * shadowK)) }
                q.fill(S.circle(0, 0, R * 0.11), with: .color(KoruRGB(hex: "#060708").color()))
                x.fill(S.circle(0, 0, R * 0.087), with: .color(c0.color()))
            case .dot:
                let r = R * 0.15, dot = S.circle(0, 0, r)
                fillGlow(dot, r, 0.2); fillGlow(dot, r, 0.08); shine(dot, r)
            }
        }

        // Aura (the last one fades out with auraA after the state changes).
        if let aura = p.aura, p.auraA > 0.01, !p.mini {
            var x = context
            x.opacity = Double(S.clamp(p.auraA, 0, 1))
            switch aura {
            case .spark:
                let top = cy - R * 1.18 * syE
                for (ox, oy, sz, ph) in [(-0.03, -0.09, 0.17, 0.0), (-0.32, 0.01, 0.095, 1.7), (0.2, 0.04, 0.095, 3.1)] as [(CGFloat, CGFloat, CGFloat, CGFloat)] {
                    let k = 0.8 + 0.2 * sin(t * 3 + ph)
                    var q = x
                    q.translateBy(x: cx + ox * R, y: top + oy * R); q.scaleBy(x: k, y: k)
                    q.addFilter(.shadow(color: koruRGBA(70, 240, 170, 0.9), radius: R * 0.08 * shadowK))
                    q.fill(S.star(R * sz, R * sz * 0.22, 4), with: .color(KoruRGB(hex: "#DFFFEE").color()))
                }
            case .wobble:
                for sd in [-1, 1] as [CGFloat] {
                    for i in 0..<2 {
                        var q = x
                        q.opacity *= Double(0.65 + 0.35 * sin(t * 6 + CGFloat(i) * 1.4 + (sd > 0 ? 2 : 0)))
                        let bx = cx + sd * R * (sd < 0 ? 1.2 + CGFloat(i) * 0.11 : 1.31 + CGFloat(i) * 0.1)   // right: in the gap above the wing
                        let y0 = cy + R * (sd < 0 ? -0.6 : -0.42) + CGFloat(i) * R * 0.03, len = R * 0.28
                        var l = Path()
                        l.move(to: CGPoint(x: bx, y: y0))
                        l.addQuadCurve(to: CGPoint(x: bx, y: y0 + len), control: CGPoint(x: bx + sd * R * 0.08, y: y0 + len / 2))
                        q.stroke(l, with: .color(p.col.color()), style: StrokeStyle(lineWidth: R * 0.035, lineCap: .round))
                    }
                }
            }
        }

        // Particles: they fade out before the canvas top.
        for pt in particles where pt.age >= 0 {
            let age = CGFloat(pt.age), k = age / CGFloat(pt.life), a = k < 0.2 ? k / 0.2 : 1 - (k - 0.2) / 0.8
            let px = cx + (pt.x + pt.vx * age) * R * 1.3, py = cy + (pt.y + pt.vy * age) * R * 1.3
            let sz = R * pt.size * (1 + k * 0.4), edge = S.clamp((py - sz) / (R * 0.25), 0, 1)
            var x = context
            x.translateBy(x: px, y: py)
            x.opacity = Double(S.clamp(a, 0, 1) * edge)
            switch pt.type {
            case .heart:
                x.rotate(by: .radians(sin(age * 6) * 0.3))
                x.fill(S.heart(sz), with: .color(KoruRGB(hex: "#FF4D6D").color()))
            case .star:
                x.rotate(by: .radians(pt.rot + age * 2))
                x.fill(S.star(sz, sz * 0.45), with: .color(KoruRGB(hex: "#F7B32B").color()))
            case .spark:   // shrinks as it fades, near upright, mint glow
                x.addFilter(.shadow(color: koruRGBA(70, 240, 170, 0.9), radius: R * 0.06 * shadowK))
                x.rotate(by: .radians(pt.rot * 0.1))
                x.fill(S.star(sz * 0.8 * (1 - 0.6 * k), sz * 0.18 * (1 - 0.6 * k), 4), with: .color(KoruRGB(hex: "#DFFFEE").color()))
            case .sweat:
                var d = Path()
                d.move(to: CGPoint(x: 0, y: -sz))
                d.addQuadCurve(to: CGPoint(x: 0, y: sz * 0.6), control: CGPoint(x: sz * 0.8, y: sz * 0.2))
                d.addQuadCurve(to: CGPoint(x: 0, y: -sz), control: CGPoint(x: -sz * 0.8, y: sz * 0.2))
                x.fill(d, with: .color(KoruRGB(hex: "#7CC7FF").color()))
            case .z:   // a sleepy z, glowing
                let w = sz * 0.5
                var z = Path()
                z.move(to: CGPoint(x: -w, y: -w)); z.addLine(to: CGPoint(x: w, y: -w)); z.addLine(to: CGPoint(x: -w, y: w)); z.addLine(to: CGPoint(x: w, y: w))
                x.addFilter(.shadow(color: koruRGBA(120, 215, 240, 0.8), radius: sz * 0.6 * shadowK))
                x.stroke(z, with: .color(koruRGBA(206, 236, 246, 1)), style: StrokeStyle(lineWidth: sz * 0.28, lineCap: .round, lineJoin: .round))
            }
        }
        if !L.front.isEmpty {
            let d = KoruGeometry(size: size, R: R, rx: rx, ryB: fr.ryB, ryT: fr.ryT, cx: cx, cy: cy, sx: sxE, sy: syE, pose: p, col: p.col, tint: p.tint,
                                 yawN: S.clamp(p.yaw / 0.62, -1, 1), pitN: S.clamp(p.pitch / 0.5, -1, 1), f: sin(p.yaw) * S.face,
                                 fx: sin(p.yaw) * S.face * R, scale: max(1, context.environment.displayScale),
                                 head: CGAffineTransform(translationX: 0, y: p.hy * R - R * 0.15).scaledBy(x: 1 / sxE, y: 1 / syE)
                                    .rotated(by: p.tilt).scaledBy(x: sxE, y: syE).translatedBy(x: 0, y: R * 0.15),
                                 beakAt: CGPoint(x: sin(p.yaw) * S.face * R * 1.08, y: R * 0.096), body: S.scaled(S.body, R))
            var dd = d
            dd.bodyT = bodyTransform(cx: cx, by: cy + fr.ryB * (1 - syE), pose: p, sx: sxE, sy: syE, scale: d.scale)
            for hook in L.front { hook(context, dd) }
        }
    }

    /// Badge glyphs as paths, so they look the same everywhere.
    private static func glyph(_ ctx: GraphicsContext, _ kind: KoruBadgeKind, _ R: CGFloat) {
        var x = ctx
        x.addFilter(.shadow(color: koruRGBA(120, 40, 0, 0.35), radius: R * 0.02 * shadowK, x: 0, y: R * 0.01))
        if kind == .bang {
            var l = Path()
            l.move(to: CGPoint(x: 0, y: -R * 0.115)); l.addLine(to: CGPoint(x: 0, y: R * 0.02))
            x.stroke(l, with: .color(.white), style: StrokeStyle(lineWidth: R * 0.075, lineCap: .round, lineJoin: .round))
            x.fill(S.circle(0, R * 0.1, R * 0.042), with: .color(.white))
        } else {
            var q = Path()
            S.addArc(&q, 0, -R * 0.05, R * 0.08, .pi * 1.08, .pi * 2.3, start: true)
            q.addQuadCurve(to: CGPoint(x: 0, y: R * 0.03), control: CGPoint(x: 0, y: -R * 0.005))
            x.stroke(q, with: .color(.white), style: StrokeStyle(lineWidth: R * 0.068, lineCap: .round, lineJoin: .round))
            x.fill(S.circle(0, R * 0.105, R * 0.042), with: .color(.white))
        }
    }
}
