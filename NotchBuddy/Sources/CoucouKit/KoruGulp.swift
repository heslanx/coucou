import SwiftUI
import QuartzCore

// Koru swallows with her beak (prototype features/gulp.js; decision D5: she never becomes a box, her beak is the slot).
// The upper mandible is her beak, a little wider, its tip drawn up into a hook; the lower one hinges at the mouth corners
// and drops, the mouth shows between. Cup eyes while it is open, happy ones while she chews. Hooks for Koru.draw
// (KoruLayers.swift): BotEngine's gulp() and the upload view's slot (koruGulpLayers), and the upload scene's file going
// into the beak (UploadCanvasView.swift).

@MainActor
enum KoruGulp {
    /// Slot levels in R (BotEngine.swift gulp(), UploadSequenceEngine.swift): open, and wide for the drop.
    static let open: CGFloat = 0.42, wide: CGFloat = 0.50
    /// A chew lasts 0.14 s; the beak parts a little on each.
    static let chew = 0.14, bite: CGFloat = 0.065

    /// The opening in steps of wide / 32, so the finish of each step is drawn once and cached.
    static func step(_ o: CGFloat) -> CGFloat {
        let q = 32 / wide
        return (o * q).rounded() / q
    }

    /// 0…1…0 through each chew, e seconds into the chewing.
    static func chewing(_ e: Double) -> CGFloat {
        CGFloat(sin(.pi * e.truncatingRemainder(dividingBy: chew) / chew))
    }

    // MARK: - The open beak

    /// The open beak in the beak's own space, R the size of Koru, o the opening.
    struct Shape {
        var o, ty, gap, cw: CGFloat
        var upper, lower, mouth: Path
        /// Everything above the lower lip (what the beak holds sinks behind it).
        var above: Path
    }

    /// A symmetric path from its right half: cubic segments [c1x, c1y, c2x, c2y, x, y] from (0, y0) down to the centre line.
    private static func sym(_ y0: CGFloat, _ segs: [[CGFloat]]) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: y0))
        for s in segs { p.addCurve(to: CGPoint(x: s[4], y: s[5]), control1: CGPoint(x: s[0], y: s[1]), control2: CGPoint(x: s[2], y: s[3])) }
        for i in stride(from: segs.count - 1, through: 0, by: -1) {
            let s = segs[i], q = i > 0 ? CGPoint(x: segs[i - 1][4], y: segs[i - 1][5]) : CGPoint(x: 0, y: y0)
            p.addCurve(to: CGPoint(x: -q.x, y: q.y), control1: CGPoint(x: -s[2], y: s[3]), control2: CGPoint(x: -s[0], y: s[1]))
        }
        p.closeSubpath()
        return p
    }

    static func shape(R: CGFloat, o: CGFloat) -> Shape {
        let br = R * 0.125, tip = R * 0.18
        let k = o / open, k1 = KoruShape.clamp(k, 0, 1)
        let ty = tip + (br * 1.25 - tip) * k1, gap = R * 0.18 * k, f = 1 + 0.18 * k1, cw = br * 0.98 * f, yc = br * 0.12
        let c1 = min(br * 0.6, ty * 0.8), th = br * 0.36 * KoruShape.smooth(KoruShape.clamp(k / 0.2, 0, 1)), fl = br * 0.06 * k1
        let lip: [CGFloat] = [cw * 0.92, c1 + gap * 0.6, cw * 0.65, ty * 0.85 + gap, 0, ty + gap]
        let upper = KoruShape.beak(br, ty).applying(CGAffineTransform(scaleX: f, y: 1))
        let lower = sym(yc - br * 0.3, [[cw * 0.95 + fl, yc - br * 0.3, cw + fl, yc - br * 0.12, cw + fl, yc],
                                        [cw * 0.95 + fl, c1 + gap * 0.6 + th * 0.8, cw * 0.7, ty * 0.85 + gap + th, 0, ty + gap + th]])
        let mouth = sym(yc, [[cw / 3, yc, cw * 2 / 3, yc, cw, yc], lip])   // its top edge lies under the upper mandible
        let L = R * 20
        var above = Path()
        above.move(to: CGPoint(x: -L, y: -L)); above.addLine(to: CGPoint(x: L, y: -L)); above.addLine(to: CGPoint(x: L, y: yc))
        above.addLine(to: CGPoint(x: cw, y: yc))
        above.addCurve(to: CGPoint(x: lip[4], y: lip[5]), control1: CGPoint(x: lip[0], y: lip[1]), control2: CGPoint(x: lip[2], y: lip[3]))
        above.addCurve(to: CGPoint(x: -cw, y: yc), control1: CGPoint(x: -lip[2], y: lip[3]), control2: CGPoint(x: -lip[0], y: lip[1]))
        above.addLine(to: CGPoint(x: -L, y: yc))
        above.closeSubpath()
        return Shape(o: o, ty: ty, gap: gap, cw: cw, upper: upper, lower: lower, mouth: mouth, above: above)
    }

    private static func box(_ x0: CGFloat, _ y0: CGFloat, _ x1: CGFloat, _ y1: CGFloat) -> CGRect {
        CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)
    }
    private static func lin(_ stops: [(Color, CGFloat)], _ a: CGPoint, _ b: CGPoint) -> GraphicsContext.Shading {
        .linearGradient(Gradient(stops: stops.map { .init(color: $0.0, location: $0.1) }), startPoint: a, endPoint: b)
    }
    private static func rgba(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat) -> CGColor {
        CGColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
    }

    /// The open beak in the beak's space (gulp.js drawBeak): lower mandible, mouth, then the upper mandible with Koru's beak
    /// finish (core.js beakFinish). Shading is cached per opening step.
    static func drawBeak(_ k: GraphicsContext, _ s: Shape, R: CGFloat, full: Bool, scale: CGFloat) {
        let Rpx = R * scale, br = R * 0.125, bot = s.ty + s.gap, key = "\(s.o)"
        // The sheets are drawn at the sheet's own size Rq, from the same shape at that size.
        func lowBox(_ Rq: CGFloat, _ q: Shape) -> CGRect {
            box(-q.cw * 1.4, -Rq * 0.125 * 0.5, q.cw * 1.4, q.ty + q.gap + Rq * 0.125 * 0.36 + Rq * 0.1)
        }
        if full {
            KoruSheets.stamp(k, KoruSheets.get("gulpLowShadow" + key, R: Rpx) { Rq in
                let q = shape(R: Rq, o: s.o)
                return KoruSheets.render(box: lowBox(Rq, q), R: Rq) { g, _ in
                    KoruSheets.drop(g, q.lower.cgPath, rgba(4, 45, 52, 0.4), Rq * 0.03, Rq * 0.012, Rq * 0.02)
                }
            }, R: R)
        }
        k.fill(s.lower, with: lin([(KoruRGB(hex: "#F7A43C").color(), 0), (KoruRGB(hex: "#D06A1C").color(), 1)], .zero, CGPoint(x: 0, y: bot + br * 0.4)))
        k.fill(s.mouth, with: lin([(KoruRGB(hex: "#24070A").color(), 0), (KoruRGB(hex: "#6B1D1D").color(), 1)], CGPoint(x: 0, y: s.ty), CGPoint(x: 0, y: bot)))
        if full {
            KoruSheets.stamp(k, KoruSheets.get("gulpMouth" + key, R: Rpx) { Rq in   // the upper mandible's shade in the mouth
                let q = shape(R: Rq, o: s.o)
                return KoruSheets.render(box: lowBox(Rq, q), R: Rq) { g, _ in
                    g.saveGState(); g.addPath(q.mouth.cgPath); g.clip()
                    KoruSheets.drop(g, q.upper.cgPath, rgba(12, 0, 2, 0.7), Rq * 0.03, 0, Rq * 0.018)
                    g.restoreGState()
                }
            }, R: R)
            KoruSheets.stamp(k, KoruSheets.get("gulpLow" + key, R: Rpx) { Rq in
                let q = shape(R: Rq, o: s.o), brq = Rq * 0.125
                return KoruSheets.render(box: lowBox(Rq, q), pad: Rq * 0.1, R: Rq) { g, room in
                    KoruSheets.inner(g, room: room, q.lower.cgPath, rgba(150, 60, 8, 0.4), Rq * 0.03, 0, -Rq * 0.02,
                                     box: box(-q.cw * 1.3, 0, q.cw * 1.3, q.ty + q.gap + brq * 0.5))
                }
            }, R: R)
        }
        finish(k, s, R: R, Rpx: Rpx, full: full)
    }

    /// core.js beakFinish for the upper mandible: contact shadow, fill, inner shade and sheen.
    private static func finish(_ k: GraphicsContext, _ s: Shape, R: CGFloat, Rpx: CGFloat, full: Bool) {
        let br = R * 0.125, tip = R * 0.18
        func KB(_ Rq: CGFloat) -> CGRect {
            let b = Rq * 0.125
            return box(-b * 1.7 - Rq * 0.1, -b * 1.1 - Rq * 0.1, b * 1.7 + Rq * 0.1, Rq * 0.18 + Rq * 0.3 + Rq * 0.1)
        }
        let key = "gulp\(s.o)"
        if full {
            KoruSheets.stamp(k, KoruSheets.get("beakShadow" + key, R: Rpx) { Rq in
                let q = shape(R: Rq, o: s.o)
                return KoruSheets.render(box: KB(Rq), R: Rq) { g, _ in
                    KoruSheets.drop(g, q.upper.cgPath, rgba(4, 45, 52, 0.4), Rq * 0.03, Rq * 0.012, Rq * 0.02)
                }
            }, R: R)
        }
        k.fill(s.upper, with: lin([(KoruRGB(hex: "#FDB247").color(), 0), (KoruRGB(hex: "#E57D21").color(), 1)], CGPoint(x: 0, y: -br), CGPoint(x: 0, y: tip)))
        if full {
            KoruSheets.stamp(k, KoruSheets.get("beak" + key, R: Rpx) { Rq in
                let q = shape(R: Rq, o: s.o), b = Rq * 0.125
                let IB = box(-b * 1.7, -b * 1.1, b * 1.7, Rq * 0.18 + Rq * 0.3)
                return KoruSheets.render(box: KB(Rq), pad: Rq * 0.1, R: Rq) { g, room in
                    KoruSheets.inner(g, room: room, q.upper.cgPath, rgba(160, 70, 8, 0.35), Rq * 0.035, 0, -Rq * 0.02, box: IB)
                    g.saveGState(); g.addPath(q.upper.cgPath); g.clip()
                    var t = CGAffineTransform(translationX: Rq * 0.035, y: -Rq * 0.06).rotated(by: 0.35)
                    KoruSheets.drop(g, CGPath(ellipseIn: CGRect(x: -Rq * 0.05, y: -Rq * 0.03, width: Rq * 0.1, height: Rq * 0.06), transform: &t),
                                    rgba(255, 236, 200, 0.45), Rq * 0.03)
                    g.restoreGState()
                }
            }, R: R)
        }
    }

    // MARK: - Eyes

    /// BotEngine's cup eye on Koru (gulp.js eyeShapes.cup): a flat top and a round bottom at the pupil's place and about its
    /// size, with its catchlight; the two converge a little on the beak and their tops slope down outward. `down` 0…1 turns
    /// the pupils from where they look to down into the beak (the file going in).
    static func cupEye(_ c: GraphicsContext, _ e: KoruEyeInfo, down: CGFloat = 0) {
        let pr = e.pr, sd = e.sd, w = pr * 2.1, hh = w * 0.78, cr = w / 2, f = w * 0.22
        let reach = e.dr - pr - e.R * 0.02
        let px = e.px + (0 - e.px) * down, py = e.py + (1.1 * reach - e.py) * down
        var x = c
        x.translateBy(x: px - sd * pr * 0.3, y: py); x.rotate(by: .radians(sd * 0.12)); x.scaleBy(x: 1 - e.far * 0.07, y: 1)
        var p = Path()
        p.move(to: CGPoint(x: -w / 2, y: -hh / 2 + f))
        p.addQuadCurve(to: CGPoint(x: -w / 2 + f, y: -hh / 2), control: CGPoint(x: -w / 2, y: -hh / 2))
        p.addLine(to: CGPoint(x: w / 2 - f, y: -hh / 2))
        p.addQuadCurve(to: CGPoint(x: w / 2, y: -hh / 2 + f), control: CGPoint(x: w / 2, y: -hh / 2))
        p.addLine(to: CGPoint(x: w / 2, y: hh / 2 - cr))
        p.addQuadCurve(to: CGPoint(x: w / 2 - cr, y: hh / 2), control: CGPoint(x: w / 2, y: hh / 2))
        p.addLine(to: CGPoint(x: -w / 2 + cr, y: hh / 2))
        p.addQuadCurve(to: CGPoint(x: -w / 2, y: hh / 2 - cr), control: CGPoint(x: -w / 2, y: hh / 2))
        p.closeSubpath()
        x.fill(p, with: .color(KoruRGB(hex: "#164149").color()))
        var l = x
        l.addFilter(.shadow(color: koruRGBA(255, 245, 235, 0.8), radius: e.R * 0.012 * Koru.shadowK))
        l.fill(KoruShape.circle(w * 0.24, -hh * 0.2, pr * 0.24), with: .color(koruRGBA(252, 243, 237, 1)))
    }

    // MARK: - Hooks

    /// The beak open by o (already stepped); none when shut.
    static func beakLayers(opening o: CGFloat) -> KoruLayers {
        var L = KoruLayers()
        guard o > 0 else { return L }
        L.beak.append { k, d in
            drawBeak(k, shape(R: d.R, o: o), R: d.R, full: d.full, scale: d.scale)
            return true
        }
        return L
    }

    /// Koru's cup eyes (gulp.js registers eyeShapes.cup): every .cup eye is drawn this way; `down` as in cupEye.
    static func cupLayers(down: CGFloat = 0) -> KoruLayers {
        var L = KoruLayers()
        L.eye.append { c, e in
            guard e.shape == .cup else { return false }
            cupEye(c, e, down: down)
            return true
        }
        return L
    }

    /// Draws a document centred on the origin, docWidth wide and 42/34 × docWidth × hsc tall (the upload view's file).
    typealias DocDrawer = @MainActor (GraphicsContext, _ hsc: CGFloat) -> Void

    /// The file going into the beak (gulp.js drawFile, the suck): from `from` (the cursor, in the space `toScene` maps Koru's
    /// canvas to), whole and opaque, tilting and shrinking, it sinks behind the lower lip, only its last sliver fading; four
    /// green motes follow it in and are gone where they would cross her face. It is held in the beak: drawn behind the upper
    /// mandible and above the lower lip, over what the head wears. docWidth: the file's width as `doc` draws it (the upload
    /// view's is 34 pt); the motes keep their distances in proportion.
    static func fileLayers(suck s: CGFloat, opening o: CGFloat, from: CGPoint, docWidth: CGFloat = 34, toScene: CGAffineTransform,
                           doc: @escaping DocDrawer) -> KoruLayers {
        var L = KoruLayers()
        guard s > 0, s < 1 else { return L }
        L.headTop.append { h, d in
            guard !d.mini else { return }
            let sh = shape(R: d.R, o: o)
            // The scene from the head's space: the head's turn, her body's place, roll and squash, then her canvas's place.
            let headToScene = d.head.concatenating(d.koruBodyToCanvas).concatenating(toScene)
            let at = CGAffineTransform(translationX: d.beakAt.x, y: d.beakAt.y)
            // Where it sinks to: the lower lip (the dark mouth shows above it, its bottom is behind the lip).
            let m = CGPoint(x: 0, y: sh.ty + sh.gap).applying(at.concatenating(headToScene))
            var x = h
            var out = Path(CGRect(x: -d.size.width * 4, y: -d.size.height * 4, width: d.size.width * 8, height: d.size.height * 8))
            out.addPath((o <= 0 ? d.beak : sh.upper).applying(at))
            x.clip(to: out, style: FillStyle(eoFill: true))
            x.clip(to: sh.above.applying(at))
            x.concatenate(headToScene.inverted())
            let sceneToHead = headToScene.inverted()
            func onFace(_ p: CGPoint) -> Bool { d.face.contains(p.applying(sceneToHead)) }

            let q = easeOut(s), io = easeInOut(s)
            // Its last size: the prototype's file (0.42 R wide) at 0.45, in scene points.
            let R = d.R * hypot(headToScene.a, headToScene.b)
            let sc = 1 + (0.42 * 0.45 * R / docWidth - 1) * io, u = docWidth / 34
            var f = x
            f.opacity *= Double(1 - KoruShape.smooth(KoruShape.clamp((s - 0.88) / 0.12, 0, 1)))
            f.translateBy(x: from.x + (m.x - from.x) * q, y: from.y + (m.y - from.y) * io)
            f.rotate(by: .radians(-0.14 * q))
            f.scaleBy(x: sc, y: sc)
            f.drawLayer { l in doc(l, 1 + 0.08 * q) }   // a layer, so a doc drawn through Core Graphics fades too
            for i in 0..<4 {
                let an = CGFloat(i) / 4 * 2 * .pi + 0.6, k = KoruShape.clamp((s - CGFloat(i) * 0.08) / 0.7, 0, 1)
                guard k > 0 && k < 1 else { continue }
                let kk = pow(k, 0.7)
                let p = CGPoint(x: from.x + cos(an) * 24 * u + (m.x - from.x - cos(an) * 24 * u) * kk,
                                y: from.y + sin(an) * 24 * u + (m.y - from.y - sin(an) * 24 * u) * kk - sin(.pi * k) * 6 * u)
                if onFace(p) { continue }
                x.fill(KoruShape.circle(p.x, p.y, 2.2 * u * (1 - k * 0.5)), with: .color(koruRGBA(52, 212, 153, 1 - k)))
            }
        }
        return L
    }

    private static func easeOut(_ t: CGFloat) -> CGFloat { 1 - pow(1 - t, 3) }
    private static func easeInOut(_ t: CGFloat) -> CGFloat { t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2 }
}

extension BotEngine {
    /// gulp() on Koru (and the upload view's slot): her beak opens as gulp.js's slot spring would (ω = 2π/0.25, ζ = 0.6) for
    /// the 0.46 s gulp() keeps it open, and parts on each chew; a file dragged over the box of the upload view
    /// (slotHTarget 0.2) leaves it ajar. Her eyes for it come from koruGulpEye, through her pose.
    /// BotEngine's own slot spring (slotH) is not read: stepped at 0.05 s per frame it diverges, and BotCanvasView sets
    /// slotHTarget every frame, so gulp()'s 0.42 never reaches a drawn frame. The gulp is read from its squash instead.
    func koruGulpLayers() -> KoruLayers {
        var o = koruGulpOpening ?? 0
        if isChewing { o = max(o, KoruGulp.bite * KoruGulp.chewing(CACurrentMediaTime())) }
        return KoruGulp.beakLayers(opening: KoruGulp.step(o)) + KoruGulp.cupLayers()
    }

    /// The gulp's eyes (gulp.js modify): cup while the beak is open, happy while she chews; an emote's eyes stay over them.
    var koruGulpEye: EyeShape? {
        if koruGulpOpening != nil { return .cup }
        return isChewing ? .happy : nil
    }

    /// The slot while gulp() holds it open or a file hovers over the upload view's box, nil when shut.
    private var koruGulpOpening: CGFloat? {
        if let e = koruGulpElapsed, e < 0.46 {
            let w = 2 * Double.pi / 0.25, z = 0.6, wd = w * (1 - z * z).squareRoot()
            return KoruGulp.open * CGFloat(1 - exp(-z * w * e) * (cos(wd * e) + z / (1 - z * z).squareRoot() * sin(wd * e)))
        }
        return slotHTarget > 0.05 ? slotHTarget : nil
    }

    /// Seconds since gulp() while its squash runs (the gulp's own keys: sy 0.78 over 80 ms, then 1.18), nil otherwise.
    private var koruGulpElapsed: Double? {
        guard let tw = tweens["sy"], tw.keys.count == 3, tw.keys[0].target == 0.78, tw.keys[0].duration == 80,
              tw.keys[1].target == 1.18 else { return nil }
        let before = tw.keys[..<tw.keyIndex].reduce(0) { $0 + Double($1.duration) }
        return max(0, CACurrentMediaTime() - (tw.startTime - before) / 1000)
    }
}
