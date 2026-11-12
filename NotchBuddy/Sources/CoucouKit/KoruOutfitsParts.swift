import SwiftUI
import CoreGraphics

// The accessories of outfits.js, shape for shape, in R units from Koru's body centre (y down). Each part is drawn once
// into a cached sheet (KoPen, Core Graphics) and stamped through the live context; the few live touches (a bridge, the
// scarf's white stripes, the pumpkin's tint and ribs) are drawn straight into the GraphicsContext.

@MainActor
enum KoruOutfitArt {
    typealias K = KoruOutfitK
    nonisolated private static func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

    // MARK: Live helpers

    static func shading(_ s: KoShade) -> GraphicsContext.Shading {
        func grad(_ st: [(CGFloat, CGColor)]) -> Gradient { Gradient(stops: st.map { .init(color: Color(cgColor: $0.1), location: $0.0) }) }
        switch s {
        case .color(let c): return .color(Color(cgColor: c))
        case .lin(let x0, let y0, let x1, let y1, let st): return .linearGradient(grad(st), startPoint: P(x0, y0), endPoint: P(x1, y1))
        case .rad(let cx, let cy, let r, let st): return .radialGradient(grad(st), center: P(cx, cy), startRadius: 0, endRadius: r)
        case .conic(let a, let cx, let cy, let st): return .conicGradient(grad(st), center: P(cx, cy), angle: .radians(a))
        }
    }

    /// outfits.js part(): drawn once into a sheet at the frame's R px (box in R units, pad the room inner() needs round it)
    /// and stamped through x's transform (R units); key names the part and everything its drawing depends on.
    static func part(_ x: GraphicsContext, _ k: K, _ key: String, _ box: CGRect, pad: CGFloat = 0.15, _ draw: (KoPen) -> Void) {
        let s = KoruSheets.get("outfits:\(key):\(k.full ? 1 : 0)\(k.simple ? 1 : 0)", R: k.Rpx) { Rq in
            var kq = k
            kq.R = Rq; kq.Rpx = Rq
            let b = CGRect(x: box.minX * Rq, y: box.minY * Rq, width: box.width * Rq, height: box.height * Rq)
            return KoruSheets.render(box: b, pad: pad * Rq, R: Rq) { g, room in
                let base = g.ctm
                g.scaleBy(x: Rq, y: Rq)
                draw(KoPen(g: g, room: room, base: base, k: kq))
            }
        }
        var c = x
        c.scaleBy(x: 1 / k.Rpt, y: 1 / k.Rpt)
        KoruSheets.stamp(c, s, R: k.Rpt)
    }

    /// drawPompom(): fluffy bumps around a round centre, lit as one ball so it reads as wool.
    static func pompom(_ x: GraphicsContext, _ k: K, _ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat,
                       _ base: String = "#FFFFFF", _ shade: String = "#D5D9E2") {
        var x = x
        x.translateBy(x: cx, y: cy)
        part(x, k, "pompom\(r)\(base)", koBox(-r * 1.1, -r * 1.1, r * 1.1, r * 1.1), pad: 0) { g in
            let p = CGMutablePath()
            p.addEllipse(in: CGRect(x: -r * 0.9, y: -r * 0.9, width: r * 1.8, height: r * 1.8))
            for i in 0..<30 {
                let a = CGFloat(i) / 30 * .pi * 2, br = r * (0.13 + 0.03 * sin(CGFloat(i) * 2.3)), bx = cos(a) * r * 0.87, by = sin(a) * r * 0.87
                p.addEllipse(in: CGRect(x: bx - br, y: by - br, width: br * 2, height: br * 2))
            }
            g.fill(p, .rad(-r * 0.3, -r * 0.35, r * 1.35, [(0, koHex(base)), (0.55, koHex(base)), (1, koHex(shade))]))
        }
    }

    // MARK: Hats

    /// Party hat: a tall cone worn askew on the crown, polka dots, a yellow rim and pompom; the lean lags with physDx.
    static func partyHat(_ x0: GraphicsContext, _ k: K) {
        var x = x0
        let c = P(0.02, -0.87)
        x.translateBy(x: c.x, y: c.y); x.rotate(by: .radians(0.2)); x.translateBy(x: -c.x, y: -c.y)
        let rw: CGFloat = 0.45, rh: CGFloat = 0.1, lean = 0.22 + k.dx * 0.12, ht: CGFloat = 0.68
        let ap = P(c.x + sin(lean) * ht, c.y - cos(lean) * ht), L = P(c.x - rw, c.y), Rt = P(c.x + rw, c.y)
        part(x, k, "partyCone" + k.lag, koBox(-0.7, -1.65, 0.75, -0.55)) { g in
            let cone = CGMutablePath()
            cone.move(to: L)
            cone.addQuadCurve(to: P(ap.x - 0.05, ap.y + 0.06), control: P((L.x + ap.x) / 2 - 0.06, (L.y + ap.y) / 2))
            cone.addQuadCurve(to: P(ap.x + 0.05, ap.y + 0.06), control: P(ap.x, ap.y - 0.03))
            cone.addQuadCurve(to: Rt, control: P((Rt.x + ap.x) / 2 + 0.06, (Rt.y + ap.y) / 2))
            KoPath.arc(cone, c.x, c.y, rw, rh, 0, .pi)
            cone.closeSubpath()
            let box = koBox(L.x - 0.1, ap.y - 0.1, Rt.x + 0.1, c.y + 0.12)
            g.cast(cone, 0.35)
            g.fill(cone, .lin(L.x, ap.y, Rt.x, L.y, [(0, koHex("#FCA5B5")), (0.5, koHex("#F7758F")), (1, koHex("#DE3360"))]))
            g.save(); g.clip(cone)
            if !k.simple {
                for (t, u) in [(0.32, -0.3), (0.52, 0.5), (0.8, -0.48), (0.84, 0.18)] as [(CGFloat, CGFloat)] {
                    let bx = L.x + (Rt.x - L.x) * (0.5 + u * 0.5), by = L.y + (Rt.y - L.y) * (0.5 + u * 0.5), r = 0.086 * (0.6 + t * 0.6)
                    g.fill(KoPath.ell(bx + (ap.x - bx) * (1 - t), by + (ap.y - by) * (1 - t), r, r * 0.9), .color(koRGBA(255, 255, 255, 0.92)))
                }
            }
            g.fill(cone, .lin(L.x, 0, Rt.x, 0, [(0, koRGBA(255, 255, 255, 0.28)), (0.35, koRGBA(255, 255, 255, 0)), (1, koRGBA(90, 0, 30, 0.3))]))
            g.restore()
            g.clay(cone, box, 0.3, 0.25)
        }
        part(x, k, "partyRim", koBox(-0.65, -1.1, 0.7, -0.55)) { g in   // a plump tube
            let rim = CGMutablePath(); KoPath.arc(rim, c.x, c.y, rw, rh, 0, .pi)
            g.stroke(rim, 0.15, .lin(0, c.y - 0.06, 0, c.y + rh + 0.08, [(0, koHex("#FFF1A8")), (0.45, koHex("#FFD84D")), (1, koHex("#D98E0B"))]), cap: .round)
            let hi = CGMutablePath(); KoPath.arc(hi, c.x, c.y - 0.03, rw, rh, .pi * 0.15, .pi * 0.7)
            g.stroke(hi, 0.035, .color(koRGBA(255, 250, 215, 0.85)), cap: .round)
        }
        pompom(x, k, ap.x, ap.y - 0.04, 0.18, "#FFD54A", "#E0960B")
    }

    /// Beanie: knit cap and ribbed cuff on the crown; the pompom sits on a short spring.
    static func beanie(_ x: GraphicsContext, _ k: K) {
        part(x, k, "beanie", koBox(-0.95, -1.6, 0.95, -0.6)) { g in
            let knit = CGMutablePath()
            knit.move(to: P(-0.64, -1.0))
            knit.addCurve(to: P(0, -1.41), control1: P(-0.66, -1.29), control2: P(-0.36, -1.41))
            knit.addCurve(to: P(0.64, -1.0), control1: P(0.36, -1.41), control2: P(0.66, -1.29))
            knit.closeSubpath()
            let cuff = CGMutablePath()
            cuff.move(to: P(-0.7, -1.03))
            cuff.addQuadCurve(to: P(0.7, -1.03), control: P(0, -1.16))
            cuff.addQuadCurve(to: P(0.7, -0.82), control: P(0.77, -0.93))
            cuff.addQuadCurve(to: P(-0.7, -0.82), control: P(0, -0.95))
            cuff.addQuadCurve(to: P(-0.7, -1.03), control: P(-0.77, -0.93))
            cuff.closeSubpath()
            let KB = koBox(-0.68, -1.48, 0.68, -1), CB = koBox(-0.8, -1.18, 0.8, -0.8)
            g.cast(cuff, 0.35)
            g.fill(knit, .lin(0.42, -1.42, -0.5, -0.6, [(0, koHex("#8CC2FF")), (1, koHex("#3B82F6"))]))
            g.save(); g.clip(knit)
            if !k.simple {
                for i in -5...5 {
                    let u = CGFloat(i)
                    g.line([P(u * 0.11, -1.04), P(u * 0.1, -1.17), P(u * 0.07, -1.3), P(u * 0.025, -1.4)], 0.045, koRGBA(20, 50, 140, 0.12))
                }
            }
            g.fillRect(-1, -1.5, 2, 0.6, .rad(0.22, -1.3, 0.4, [(0, koRGBA(255, 255, 255, 0.35)), (1, koRGBA(255, 255, 255, 0))]))
            g.restore()
            g.clay(knit, KB)
            g.fill(cuff, .lin(0, -1.1, 0, -0.82, [(0, koHex("#4A8CF0")), (1, koHex("#2563EB"))]))
            if !k.simple {
                g.save(); g.clip(cuff)
                for i in -8...8 { g.line([P(CGFloat(i) * 0.086, -1.14), P(CGFloat(i) * 0.086, -0.76)], 0.035, koRGBA(10, 30, 100, 0.16)) }
                g.restore()
            }
            g.clay(cuff, CB, 0.3, 0.25)
        }
        pompom(x, k, k.dx * 0.29, -1.47 + k.dy * 0.13, 0.18)
    }

    /// Santa hat: a tall red bag slouching to the right, its tip hanging past the tuft, a thick fuzzy trim; the tip lags.
    static func santaHat(_ x: GraphicsContext, _ k: K) {
        let L = P(-0.76, -1.03), Rt = P(0.72, -0.86), C = P(-0.04, -1.25), pk = P(0.06, -1.6), tip = P(1.22 + k.dx * 0.3, -0.46 + k.dy * 0.15)
        part(x, k, "santaBag" + k.lag, koBox(-1.0, -1.8, 1.65, -0.05)) { g in
            let bag = CGMutablePath()
            bag.move(to: P(L.x + 0.04, L.y))
            bag.addCurve(to: pk, control1: P(L.x + 0.04, L.y - 0.42), control2: P(pk.x - 0.4, pk.y))
            bag.addCurve(to: P(tip.x + 0.08, tip.y - 0.04), control1: P(pk.x + 0.62, pk.y - 0.02), control2: P(tip.x + 0.14, tip.y - 0.78))
            bag.addQuadCurve(to: P(tip.x - 0.08, tip.y - 0.04), control: P(tip.x, tip.y + 0.06))
            bag.addCurve(to: P(Rt.x - 0.02, Rt.y - 0.1), control1: P(tip.x - 0.12, tip.y - 0.3), control2: P(Rt.x + 0.22, Rt.y - 0.1))
            bag.addQuadCurve(to: P(L.x + 0.04, L.y), control: C)
            bag.closeSubpath()
            let box = koBox(L.x - 0.1, pk.y - 0.1, tip.x + 0.25, tip.y + 0.1)
            g.cast(bag, 0.25)
            g.fill(bag, .lin(-0.7, -1.7, 1.1, -0.4, [(0, koHex("#F24343")), (0.5, koHex("#D81F26")), (1, koHex("#9C0F17"))]))
            g.save(); g.clip(bag)
            for (a, w) in [(0.15, 0.1), (0.45, 0.08)] as [(CGFloat, CGFloat)] {   // soft folds where it bends
                let f = CGMutablePath()
                f.move(to: P(pk.x + 0.1 + a * 0.4, pk.y + 0.2 + a * 0.3))
                f.addCurve(to: P(tip.x - 0.04 - a * 0.08, tip.y - 0.22), control1: P(pk.x + 0.6, pk.y + 0.15 + a * 0.2), control2: P(tip.x - 0.05 - a * 0.1, tip.y - 0.6))
                g.stroke(f, w, .color(koRGBA(90, 0, 0, 0.07)), cap: .round)
            }
            g.fillRect(-1, -1.8, 2.6, 1.6, .rad(pk.x - 0.2, pk.y + 0.18, 0.6, [(0, koRGBA(255, 255, 255, 0.1)), (1, koRGBA(255, 255, 255, 0))]))
            g.restore()
            g.clay(bag, box, 0.14, 0.3)
        }
        part(x, k, "santaTrim", koBox(-1.1, -1.5, 1.1, -0.5)) { g in   // drawFuzzyBand(): a cream roll with round ends, fuzz along both edges
            let arc: [CGPoint] = (0...32).map { i in
                let t = CGFloat(i) / 32
                return P((1 - t) * (1 - t) * L.x + 2 * (1 - t) * t * C.x + t * t * Rt.x, (1 - t) * (1 - t) * L.y + 2 * (1 - t) * t * C.y + t * t * Rt.y)
            }
            let th: CGFloat = 0.3, TB = koBox(L.x - 0.2, -1.4, Rt.x + 0.2, -0.65), tb = CGMutablePath()
            tb.addLines(between: arc.map { P($0.x, $0.y - th / 2) })
            tb.addArc(center: arc[32], radius: th / 2, startAngle: -.pi / 2, endAngle: .pi / 2, clockwise: false)
            for i in stride(from: 31, through: 0, by: -1) { tb.addLine(to: P(arc[i].x, arc[i].y + th / 2)) }
            tb.addArc(center: arc[0], radius: th / 2, startAngle: .pi / 2, endAngle: .pi * 1.5, clockwise: false)
            tb.closeSubpath()
            if k.full { g.drop(tb, koRGBA(2, 36, 42, 0.4), g.R * 0.06, 0, g.R * 0.03) }
            g.fill(tb, .lin(0, -1.28, 0, -0.74, [(0, koHex("#FFFDF8")), (0.5, koHex("#F3EEE5")), (1, koHex("#CFC5B6"))]))
            if !k.simple {
                for (i, q) in arc.enumerated() {
                    let s = sin(CGFloat(i) * 2.7), r = 0.026 + 0.012 * s * s
                    g.fill(KoPath.ell(q.x, q.y - th * 0.45, r, r * 0.8), .color(koHex("#FCF9F3")))
                    g.fill(KoPath.ell(q.x + 0.02, q.y + th * 0.43, r * 0.85, r * 0.7), .color(koHex("#D3CABD")))
                }
            }
            if k.full { g.inner(tb, koRGBA(120, 100, 80, 0.35), g.R * 0.06, 0, -g.R * 0.035, TB); g.clay(tb, TB, 0.2, 0.2) }
        }
        pompom(x, k, tip.x + 0.02, tip.y + 0.06, 0.26, "#FCF9F3", "#D3C9BB")
    }

    /// Witch hat: a wide floppy brim drooping beside the head, a tall cone whose tip bends to the right (it lags), an
    /// orange band and a big buckle.
    static func witchHat(_ x0: GraphicsContext, _ k: K) {
        let by: CGFloat = -0.9
        var x = x0
        x.translateBy(x: 0, y: by); x.rotate(by: .radians(-0.04)); x.translateBy(x: 0, y: -by)
        part(x, k, "witchBrim", koBox(-1.6, -1.2, 1.6, -0.25)) { g in
            let Wb: CGFloat = 1.3, D: CGFloat = 0.3
            var top: [CGPoint] = [], bot: [CGPoint] = []
            for i in 0...40 {
                let u = -1 + CGFloat(i) / 20, v = by + D * pow(abs(u), 3) + 0.012 * sin(u * 9), q = 1 - u * u
                top.append(P(Wb * u, v - 0.1 - 0.12 * q)); bot.append(P(Wb * u, v + 0.07 + 0.03 * q))
            }
            func cap(_ sd: CGFloat) -> CGPoint {   // a rounded end along the arch
                let e = sd > 0 ? 40 : 0
                return P(top[e].x + sd * 0.8 * 0.12, (top[e].y + bot[e].y) / 2 + 0.6 * 0.12)
            }
            let brim = CGMutablePath()
            brim.addLines(between: top)
            brim.addQuadCurve(to: bot[40], control: cap(1))
            for i in stride(from: 39, through: 0, by: -1) { brim.addLine(to: bot[i]) }
            brim.addQuadCurve(to: top[0], control: cap(-1))
            brim.closeSubpath()
            let BB = koBox(-Wb - 0.15, by - 0.2, Wb + 0.15, by + D + 0.15)
            if k.full { g.drop(brim, koRGBA(2, 36, 42, 0.65), g.R * 0.07, 0, g.R * 0.045) }
            g.fill(brim, .lin(0, by - 0.18, 0, by + D, [(0, koHex("#9A55DA")), (0.5, koHex("#7B30C2")), (1, koHex("#5E1FA0"))]))
            g.save(); g.clip(brim)   // the rolled lip
            g.stroke(KoPath.poly(Array(bot[2..<39])), 0.09, .color(koRGBA(50, 8, 95, 0.45)), cap: .round, join: .round)
            g.restore()
            g.clay(brim, BB, 0.25, 0.3)
        }
        part(x, k, "witchCone" + k.lag, koBox(-0.9, -1.85, 1.45, -0.65)) { g in
            let bl = P(-0.64, by - 0.05), br = P(0.64, by - 0.05), pk = P(0.1 + k.dx * 0.05, -1.6), tip = P(1.0 + k.dx * 0.25, -1.34 + k.dy * 0.1)
            let cone = CGMutablePath()
            cone.move(to: bl)
            cone.addCurve(to: P(pk.x - 0.12, pk.y + 0.06), control1: P(bl.x + 0.14, bl.y - 0.42), control2: P(pk.x - 0.32, pk.y + 0.34))
            cone.addQuadCurve(to: P(pk.x + 0.14, pk.y - 0.02), control: P(pk.x - 0.02, pk.y - 0.04))
            cone.addCurve(to: P(tip.x - 0.04, tip.y), control1: P(pk.x + 0.45, pk.y + 0.02), control2: P(tip.x - 0.2, tip.y - 0.12))
            cone.addQuadCurve(to: P(tip.x + 0.07, tip.y - 0.07), control: P(tip.x + 0.04, tip.y - 0.02))   // the bent tip flicks up
            cone.addQuadCurve(to: P(tip.x - 0.08, tip.y + 0.08), control: P(tip.x + 0.08, tip.y + 0.06))
            cone.addCurve(to: P(pk.x + 0.3, pk.y + 0.34), control1: P(tip.x - 0.3, tip.y + 0.05), control2: P(pk.x + 0.42, pk.y + 0.2))
            cone.addCurve(to: br, control1: P(br.x - 0.18, by - 0.5), control2: P(br.x - 0.03, br.y - 0.2))
            KoPath.arc(cone, 0, by - 0.05, 0.64, 0.1, 0, .pi)
            cone.closeSubpath()
            let box = koBox(bl.x - 0.1, pk.y - 0.15, tip.x + 0.15, by + 0.1)
            g.cast(cone, 0.3)
            g.fill(cone, .lin(bl.x, pk.y, br.x, bl.y, [(0, koHex("#A15BE0")), (0.5, koHex("#7A2FC0")), (1, koHex("#561A94"))]))
            g.save(); g.clip(cone)
            g.fillRect(-0.8, -1.8, 2.2, 1.2, .lin(bl.x, 0, br.x, 0, [(0, koRGBA(255, 255, 255, 0.2)), (0.4, koRGBA(255, 255, 255, 0)), (1, koRGBA(0, 0, 0, 0.18))]))
            let fold = CGMutablePath()   // the fold of the bend
            fold.move(to: P(pk.x + 0.2, pk.y + 0.3)); fold.addQuadCurve(to: P(pk.x + 0.52, pk.y + 0.18), control: P(pk.x + 0.34, pk.y + 0.16))
            g.stroke(fold, 0.05, .color(koRGBA(30, 0, 60, 0.3)))
            let band = CGMutablePath()
            band.move(to: P(bl.x - 0.05, by - 0.2)); band.addQuadCurve(to: P(br.x + 0.05, by - 0.2), control: P(0, by))
            g.stroke(band, 0.26, .lin(0, by - 0.3, 0, by + 0.06, [(0, koHex("#FF9348")), (0.5, koHex("#F26A1B")), (1, koHex("#C9480C"))]))
            let lip = CGMutablePath()
            lip.move(to: P(bl.x + 0.02, by - 0.29)); lip.addQuadCurve(to: P(br.x - 0.02, by - 0.29), control: P(0, by - 0.12))
            g.stroke(lip, 0.03, .color(koRGBA(255, 215, 170, 0.55)))
            g.restore()
            g.clay(cone, box, 0.3, 0.3)
        }
        part(x, k, "witchBuckle", koBox(-0.3, -1.35, 0.4, -0.7)) { g in
            let bx: CGFloat = 0.05, bY = by - 0.13
            let buckle = KoPath.rrect(bx - 0.18, bY - 0.16, 0.36, 0.31, 0.07)
            KoPath.add(buckle, rrect: CGRect(x: bx - 0.086, y: bY - 0.07, width: 0.172, height: 0.13), [0.03, 0.03, 0.03, 0.03])
            let UB = koBox(bx - 0.22, bY - 0.2, bx + 0.22, bY + 0.2)
            if k.full { g.drop(buckle, koRGBA(90, 30, 0, 0.4), g.R * 0.03, 0, g.R * 0.015) }
            g.fill(buckle, .lin(0, bY - 0.16, 0, bY + 0.15, [(0, koHex("#FFE680")), (0.5, koHex("#FFC21A")), (1, koHex("#E08A0B"))]), eo: true)
            g.clay(buckle, UB, 0.45, 0.35)
            if k.full {
                g.save(); g.clip(buckle, eo: true)
                g.fill(KoPath.poly([P(bx - 0.17, bY - 0.02), P(bx - 0.08, bY - 0.16), P(bx - 0.01, bY - 0.16), P(bx - 0.1, bY - 0.02)]),
                       .color(koRGBA(255, 255, 240, 0.6)))
                g.restore()
                g.inner(KoPath.rrect(bx - 0.086, bY - 0.07, 0.172, 0.13, 0.03), koRGBA(90, 30, 0, 0.55), g.R * 0.025, 0, g.R * 0.015, UB)
            }
        }
    }

    /// Crown: a molded golden crown, five rounded lobes with ball tips, a red gem between two blue ones.
    static func crown(_ x: GraphicsContext, _ k: K) {
        part(x, k, "crown", koBox(-0.65, -1.65, 0.65, -0.55)) { g in
            let Pk = [P(-0.46, -1.22), P(-0.23, -1.32), P(0, -1.44), P(0.23, -1.32), P(0.46, -1.22)], vy: CGFloat = -1.15
            let F = CGMutablePath()
            F.move(to: P(-0.42, -0.86)); F.addLine(to: Pk[0])
            for i in 1..<Pk.count {
                let a = Pk[i - 1], b = Pk[i]
                F.addQuadCurve(to: b, control: P((a.x + b.x) / 2, 2 * vy - (a.y + b.y) / 2))
            }
            F.addLine(to: P(0.42, -0.86)); F.addQuadCurve(to: P(-0.42, -0.86), control: P(0, -0.8)); F.closeSubpath()
            let box = koBox(-0.5, -1.48, 0.5, -0.78)
            g.cast(F, 0.3)
            g.fill(F, .lin(0, -1.42, 0, -0.82, [(0, koHex("#FFDD73")), (0.5, koHex("#F8BC2A")), (1, koHex("#E39A12"))]))
            g.save(); g.clip(F); g.fillRect(-0.5, -0.92, 1, 0.1, .color(koRGBA(150, 90, 0, 0.16))); g.restore()
            g.clay(F, box, 0.42, 0.32)
            let balls = CGMutablePath()
            for q in Pk { balls.addPath(KoPath.ell(q.x, q.y - 0.04, 0.09, 0.09)) }
            g.fill(balls, .lin(0, -1.54, 0, -1.12, [(0, koHex("#FFE48A")), (1, koHex("#EBA61C"))]))
            g.clay(balls, koBox(-0.56, -1.54, 0.56, -1.12), 0.4, 0.28)
            if k.simple { return }
            let gems = CGMutablePath()
            for (gx, gy, rx, ry, c, e) in [(-0.22, -1.06, 0.06, 0.06, "#4F8EF7", "#2A5FC9"), (0, -1.12, 0.086, 0.11, "#F25555", "#B8262B"),
                                           (0.22, -1.06, 0.06, 0.06, "#4F8EF7", "#2A5FC9")] as [(CGFloat, CGFloat, CGFloat, CGFloat, String, String)] {
                let gp = KoPath.ell(gx, gy, rx, ry)
                g.fill(gp, .lin(0, gy - ry, 0, gy + ry, [(0, koHex(c)), (1, koHex(e))]))
                gems.addPath(gp)
            }
            g.clay(gems, koBox(-0.3, -1.24, 0.3, -0.99), 0.5, 0.3)
        }
    }

    /// Bunny ears: behind the head, between the tufts (the body hides their roots).
    static func bunnyEars(_ x: GraphicsContext, _ k: K) {
        part(x, k, "bunny", koBox(-1.0, -1.95, 1.0, -0.3)) { g in
            let eh: CGFloat = 1.32, ew: CGFloat = 0.35
            for sd in [-1, 1] as [CGFloat] {
                g.save()
                g.translate(sd * 0.44, -0.86); g.rotate(sd * 0.32); g.translate(0, -eh * 0.17)
                let o = KoPath.ell(0, 0, ew, eh / 2), B = koBox(-ew, -eh / 2, ew, eh / 2)
                g.fill(o, .lin(0, -eh / 2, 0, eh / 2, [(0, koHex("#FFFDFB")), (1, koHex("#EADDDD"))]))
                g.clay(o, B, 0.3, 0.18)
                g.stroke(o, 0.8 / g.R, .color(koRGBA(0, 0, 0, 0.06)))
                let ie = KoPath.ell(0, -eh / 2 + 0.1 + eh * 0.4, ew * 0.56, eh * 0.4)
                g.fill(ie, .color(koRGBA(250, 160, 168, 0.85)))
                if k.full { g.inner(ie, koRGBA(150, 50, 60, 0.35), g.R * 0.04, 0, g.R * 0.025, B) }
                g.restore()
            }
        }
    }

    // MARK: Face

    /// Lens frames centred on the eye discs, foreshortened with them as the head turns.
    private static func lenses(_ x: GraphicsContext, _ k: K, _ fn: (GraphicsContext, CGFloat) -> Void) {
        for e in k.eyes {
            var c = x
            c.translateBy(x: e.x, y: e.y); c.scaleBy(x: e.kx, y: e.ky)
            fn(c, e.sd)
        }
    }

    /// Sunglasses: dark rounded lenses tall enough to cover the discs, joined by one solid arched bridge.
    static func sunglasses(_ x: GraphicsContext, _ k: K) {
        guard k.eyes.count == 2 else { return }
        let w: CGFloat = 0.88, hh: CGFloat = 0.76, oy: CGFloat = -0.02, l = k.eyes[0], r = k.eyes[1]
        let y = l.y + oy - hh * 0.36, a = l.x + (w / 2 - 0.12) * l.kx, b = r.x - (w / 2 - 0.12) * r.kx, m = (l.x + r.x) / 2
        var bridge = Path()
        bridge.move(to: P(a, y - 0.05)); bridge.addQuadCurve(to: P(b, y - 0.05), control: P(m, y - 0.1))
        bridge.addLine(to: P(b, y + 0.07)); bridge.addQuadCurve(to: P(a, y + 0.07), control: P(m, y - 0.03)); bridge.closeSubpath()
        x.fill(bridge, with: shading(.lin(0, y - 0.08, 0, y + 0.02, [(0, koHex("#3A404B")), (0.5, koHex("#181B21")), (1, koHex("#0A0B0E"))])))
        lenses(x, k) { c, _ in
            part(c, k, "sunLens", koBox(-w / 2 - 0.15, oy - hh / 2 - 0.15, w / 2 + 0.15, oy + hh / 2 + 0.15)) { g in
                let lens = KoPath.rrect(-w / 2, oy - hh / 2, w, hh, [0.2, 0.2, 0.32, 0.32])
                let B = koBox(-w / 2 - 0.05, oy - hh / 2 - 0.05, w / 2 + 0.05, oy + hh / 2 + 0.05)
                g.fill(lens, .lin(0, oy - hh / 2, 0, oy + hh / 2, [(0, koHex("#2E333C")), (1, koHex("#0A0B0E"))]))
                g.stroke(lens, 0.06, .color(koHex("#121419")))
                g.clay(lens, B, 0.32, 0.25)
                if !k.simple { g.line([P(-w * 0.2, oy + hh * 0.24), P(w * 0.04, oy - hh * 0.26)], 0.045, koRGBA(255, 255, 255, 0.72), cap: .round) }   // one thin glare
            }
        }
    }

    /// Round glasses: thin tortoise wire around each disc, clear lenses, an arched bridge leaving both rims at the same angle.
    static func roundGlasses(_ x: GraphicsContext, _ k: K) {
        guard k.eyes.count == 2 else { return }
        let r: CGFloat = 0.41, a: CGFloat = 0.45
        lenses(x, k) { c, sd in
            part(c, k, "roundLens\(sd)", koBox(-r - 0.2, -r - 0.2, r + 0.2, r + 0.2)) { g in
                let ring = KoPath.ell(0, 0, r, r)
                let tortoise: [(CGFloat, CGColor)] = [(0, "#4A230B"), (0.07, "#A65E22"), (0.13, "#5A2E0E"), (0.24, "#C27A35"), (0.33, "#4A230B"), (0.47, "#9A5420"),
                                                      (0.56, "#3E1E0A"), (0.68, "#B86E2C"), (0.8, "#55290D"), (0.9, "#A65E22"), (1, "#4A230B")].map { ($0.0, koHex($0.1)) }
                g.stroke(ring, 0.08, .conic(0.4, 0, 0, tortoise), cap: .round)
                let rim = CGMutablePath(); KoPath.arc(rim, 0, 0, r + 0.01, r + 0.01, .pi * 1.1, .pi * 1.9)
                g.stroke(rim, 0.024, .lin(-r, 0, r, 0, [(0, koRGBA(255, 230, 190, 0)), (0.4, koRGBA(255, 236, 205, 0.6)), (1, koRGBA(255, 230, 190, 0))]), cap: .round)
                if !k.simple {   // a glint on the glass, clear of the pupil
                    let gl = CGMutablePath(); KoPath.arc(gl, 0, 0, r - 0.07, r - 0.07, .pi * 1.12, .pi * 1.38)
                    g.stroke(gl, 0.03, .color(koRGBA(255, 255, 255, 0.22)), cap: .round)
                }
                let hs = KoPath.rrect(sd > 0 ? r - 0.01 : -r - 0.07, -0.065, 0.08, 0.13, 0.03)   // hinge studs
                g.fill(hs, .lin(0, -0.065, 0, 0.065, [(0, koHex("#B86E2C")), (1, koHex("#3E1E0A"))]))
                g.clay(hs, koBox(-r - 0.1, -0.1, r + 0.1, 0.1), 0.35, 0.3)
            }
        }
        let l = k.eyes[0], rt = k.eyes[1]
        let p0 = P(l.x + cos(a) * r * l.kx, l.y - sin(a) * r * l.ky), p1 = P(rt.x - cos(a) * r * rt.kx, rt.y - sin(a) * r * rt.ky)
        var br = Path()
        br.move(to: p0); br.addQuadCurve(to: p1, control: P((p0.x + p1.x) / 2, p0.y - 0.13))
        x.stroke(br, with: shading(.lin(0, p0.y - 0.1, 0, p0.y + 0.05, [(0, koHex("#9A5420")), (1, koHex("#4A230B"))])),
                 style: StrokeStyle(lineWidth: 0.065, lineCap: .round))
    }

    /// Bow: pink satin at the base of the right tuft, squeezed as the head turns away; two crisp folds run from the knot.
    static func bow(_ x0: GraphicsContext, _ k: K) {
        let s: CGFloat = 0.42, sq = max(0.45, cos(0.3 + k.yaw * 0.6))
        var x = x0
        x.translateBy(x: 0.6 + k.f * 0.5, y: -0.98); x.rotate(by: .radians(0.35 + k.yaw * 0.3)); x.scaleBy(x: sq, y: 1)
        part(x, k, "bow", koBox(-s * 1.6, -s * 1.2, s * 1.6, s * 1.2)) { g in
            for sd in [-1, 1] as [CGFloat] {
                let w = CGMutablePath()
                w.move(to: .zero)
                w.addCurve(to: P(sd * s * 1.15, 0), control1: P(sd * s * 0.6, -s * 0.85), control2: P(sd * s * 1.35, -s * 0.55))
                w.addCurve(to: .zero, control1: P(sd * s * 1.35, s * 0.55), control2: P(sd * s * 0.6, s * 0.85))
                w.closeSubpath()
                g.cast(w, 0.22)
                g.fill(w, .lin(0, -s * 0.8, 0, s * 0.8, [(0, koHex("#FFA3D2")), (0.55, koHex("#F25CA6")), (1, koHex("#C9246F"))]))
                if !k.simple {
                    g.save(); g.clip(w)
                    for v in [-0.3, 0.26] as [CGFloat] {
                        let f = CGMutablePath()
                        f.move(to: P(sd * s * 0.22, v * s * 0.25)); f.addQuadCurve(to: P(sd * s * 1.02, v * s * 0.7), control: P(sd * s * 0.6, v * s * 0.95))
                        g.stroke(f, s * 0.05, .color(koRGBA(150, 15, 75, 0.32)), cap: .round)
                    }
                    g.restore()
                }
                g.clay(w, koBox(-s * 1.4, -s, s * 1.4, s), 0.42, 0.28)
            }
            let kn = CGMutablePath()   // pinched at the waist
            kn.move(to: P(0, -s * 0.3))
            for sd in [1, -1] as [CGFloat] {
                kn.addCurve(to: P(sd * s * 0.17, 0), control1: P(sd * s * 0.27, -s * 0.32 * sd), control2: P(sd * s * 0.27, -s * 0.12 * sd))
                kn.addCurve(to: P(0, s * 0.3 * sd), control1: P(sd * s * 0.27, s * 0.12 * sd), control2: P(sd * s * 0.27, s * 0.32 * sd))
            }
            if k.full { g.drop(kn, koRGBA(110, 10, 55, 0.35), g.R * 0.03, 0, 0) }
            g.fill(kn, .lin(0, -s * 0.3, 0, s * 0.3, [(0, koHex("#FF9DCF")), (1, koHex("#D23A82"))]))
            g.clay(kn, koBox(-s * 0.3, -s * 0.35, s * 0.3, s * 0.35), 0.4, 0.28)
        }
    }

    // MARK: Body

    nonisolated private static let SW: CGFloat = 1.24, KS: CGFloat = 0.05
    nonisolated private static func yTop(_ u: CGFloat) -> CGFloat { 0.2 + 0.17 * sqrt(max(0, 1 - (u / SW) * (u / SW))) }
    nonisolated private static func yBot(_ u: CGFloat) -> CGFloat { 0.5 + 0.21 * sqrt(max(0, 1 - (u / SW) * (u / SW))) }

    /// Stockinette: V stitches at (u, v, z) (z narrows them where the band turns away), the yarn lit over darker gaps.
    private static func knit(_ g: KoPen, _ at: [(CGFloat, CGFloat, CGFloat)], _ sz: CGFloat) {
        let leg = CGMutablePath(), hi = CGMutablePath()
        for (u, v, z) in at {
            let w = sz * z
            for sd in [-1, 1] as [CGFloat] {
                let cx = u + sd * w * 0.24, a = sd * 0.45
                for (p, kk, dy) in [(leg, 1, 0), (hi, 0.5, -sz * 0.14)] as [(CGMutablePath, CGFloat, CGFloat)] {
                    let rx = w * 0.15 * kk, ry = sz * 0.62 * kk
                    p.addEllipse(in: CGRect(x: -rx, y: -ry, width: 2 * rx, height: 2 * ry), transform: CGAffineTransform(translationX: cx, y: v + dy).rotated(by: a))
                }
            }
        }
        g.fillRect(-2, -2, 4, 4, .color(koRGBA(70, 0, 0, 0.34)))   // the gaps (inside the caller's clip)
        g.fill(leg, .color(koRGBA(240, 60, 55, 0.6)))
        g.fill(hi, .color(koRGBA(255, 190, 180, 0.18)))
    }

    /// The scarf band: the front half of an ellipse round Koru at each edge, with rounded ends where it turns away.
    nonisolated(unsafe) private static let scarfBand: CGPath = {
        let band = CGMutablePath(), n = 40
        func U(_ i: Int) -> CGFloat { -SW * cos(.pi * CGFloat(i) / CGFloat(n)) }   // points crowd at the ends
        band.addLines(between: (0...n).map { P(U($0), yTop(U($0))) })
        band.addCurve(to: P(SW, yBot(SW)), control1: P(SW + 0.07, yTop(SW) + 0.02), control2: P(SW + 0.07, yBot(SW) - 0.02))
        for i in stride(from: n, through: 0, by: -1) { band.addLine(to: P(U(i), yBot(U(i)))) }
        band.addCurve(to: P(-SW, yTop(SW)), control1: P(-SW - 0.07, yBot(SW) - 0.02), control2: P(-SW - 0.07, yTop(SW) + 0.02))
        band.closeSubpath()
        return band
    }()

    /// Scarf: a knitted band round the neck line under the facial disc; it turns with the head, its stitches crowding
    /// where it wraps away; on the left an end folds over the band and hangs, its fringe swinging with the lag.
    static func scarf(_ x0: GraphicsContext, _ k: K, _ d: KoruGeometry) {
        var x = x0
        let m = k.f * 0.75, ph = asin(max(-1, min(1, m / SW)))
        if k.rise > 0.001 { x.clip(to: bodyR(d, 1.1, head: true, rise: k.rise)) }   // while it rises it stays inside Koru's outline
        let band = scarfBand
        let BB = koBox(-1.32, 0.15, 1.32, 0.75), SB = koBox(-1.5, 0, 1.5, 0.95)
        part(x, k, "scarfBand", SB) { g in
            if k.full { g.drop(band, koRGBA(2, 36, 42, 0.45), g.R * 0.06, 0, g.R * 0.035) }
            g.fill(band, .lin(0, 0.18, 0, 0.72, [(0, koHex("#F04848")), (0.6, koHex("#D92B2B")), (1, koHex("#B01E1E"))]))
        }
        // The knit, the rolled tube, the wrap and the clay, for this phase (stitches repeat every KS: 16 phases cached).
        let q = ((Int((ph / KS * 16).rounded()) % 16) + 16) % 16
        part(x, k, "scarfKnit\(q)", SB, pad: 0.3) { g in
            g.clip(band)
            if !k.simple {
                var at: [(CGFloat, CGFloat, CGFloat)] = []
                let rows = 7, o = CGFloat(q) / 16 * KS
                var lon = -1.6 + o
                while lon <= 1.6 {
                    let z = cos(lon)
                    if z >= 0.25 {
                        let u = sin(lon) * SW
                        for j in 0..<rows { at.append((u, yTop(u) + (yBot(u) - yTop(u)) * (CGFloat(j) + 0.5) / CGFloat(rows), z)) }
                    }
                    lon += KS
                }
                knit(g, at, 0.046)
            }
            g.fillRect(-1.4, 0.1, 2.8, 0.8, .lin(0, 0.18, 0, 0.72, [(0, koRGBA(255, 240, 235, 0.14)), (0.3, koRGBA(255, 240, 235, 0)),
                                                                    (0.7, koRGBA(60, 0, 0, 0)), (1, koRGBA(60, 0, 0, 0.3))]))   // a rolled tube
            g.fillRect(-1.4, 0.1, 2.8, 0.8, .lin(-SW - 0.07, 0, SW + 0.07, 0, [(0, koRGBA(60, 0, 0, 0.5)), (0.16, koRGBA(60, 0, 0, 0)),
                                                                                (0.84, koRGBA(60, 0, 0, 0)), (1, koRGBA(60, 0, 0, 0.5))]))   // it wraps round
            g.clay(band, BB, 0.28, 0.3)
        }
        do {   // white stripes, live
            var c = x
            c.clip(to: Path(band))
            var stripes = Path()
            for lon in [-1.05, -0.5, 0.05, 0.6, 1.15] as [CGFloat] {
                let z = cos(lon + ph)
                if z > 0 { stripes.addRect(CGRect(x: sin(lon + ph) * SW - 0.06 * z, y: 0.1, width: 0.12 * z, height: 0.8)) }
            }
            whiteLive(c, stripes)
        }
        // The end: it folds over the band (a rounded fold on top, a soft crease where it bends down past the band) and hangs.
        x.translateBy(x: -0.74 + m, y: 0)
        part(x, k, "scarfEnd" + k.lag, koBox(-0.6, 0.05, 0.4, 1.3)) { g in
            let t0 = yTop(-0.74) - 0.03, yb: CGFloat = 1.0, sw = k.dx * 0.14, bx = sw * 1.4
            let end = CGMutablePath()
            end.move(to: P(-0.21, t0 + 0.09))
            end.addCurve(to: P(0.21, t0 + 0.06), control1: P(-0.21, t0 - 0.04), control2: P(0.19, t0 - 0.07))
            end.addQuadCurve(to: P(bx, yb), control: P(0.15 + sw, (t0 + yb) / 2))
            end.addLine(to: P(-0.38 + bx, yb - 0.03))
            end.addQuadCurve(to: P(-0.21, t0 + 0.09), control: P(-0.3 + sw, (t0 + yb) / 2))
            end.closeSubpath()
            let EB = koBox(-0.42, t0 - 0.06, 0.22, yb + 0.02)
            func X(_ s: CGFloat, _ t: CGFloat) -> CGFloat { let l = -0.2 + (bx - 0.18) * t, r = 0.2 + (bx - 0.2) * t; return l + (r - l) * s }
            g.cast(end, 0.32)
            g.fill(end, .lin(-0.4, 0, 0.2, 0, [(0, koHex("#F04848")), (0.6, koHex("#D92B2B")), (1, koHex("#B01E1E"))]))
            g.save(); g.clip(end)
            if !k.simple {
                var at: [(CGFloat, CGFloat, CGFloat)] = []
                for j in 0..<12 {
                    let t = (CGFloat(j) + 0.5) / 12, v = t0 + (yb - t0) * t
                    for i in 0..<6 { let s = (CGFloat(i) + 0.5) / 6; at.append((X(s, t), v + 0.02 * sin(s * .pi), 1)) }
                }
                knit(g, at, 0.058)
            }
            let yS = t0 + (yb - t0) * 0.38, stripe = CGMutablePath()   // one white stripe
            stripe.move(to: P(-0.5, yS - 0.05)); stripe.addQuadCurve(to: P(0.3, yS - 0.07), control: P(-0.1, yS))
            stripe.addLine(to: P(0.3, yS + 0.03)); stripe.addQuadCurve(to: P(-0.5, yS + 0.05), control: P(-0.1, yS + 0.1))
            whitePen(g, stripe)
            let yc = yBot(-0.74)   // the bend past the band
            g.fillRect(-0.5, yc - 0.07, 0.8, 0.16, .lin(0, yc - 0.07, 0, yc + 0.09, [(0, koRGBA(60, 0, 0, 0)), (0.55, koRGBA(60, 0, 0, 0.28)), (1, koRGBA(60, 0, 0, 0))]))
            g.fillRect(-0.5, t0 - 0.06, 0.8, 0.14, .lin(0, t0 - 0.05, 0, t0 + 0.08, [(0, koRGBA(255, 235, 230, 0.18)), (1, koRGBA(255, 235, 230, 0))]))   // the lit fold
            g.restore()
            g.clay(end, EB, 0.28, 0.3)
            if !k.simple {   // splayed yarn
                for i in 0..<9 {
                    let u = -0.36 + bx + CGFloat(i) * 0.042
                    g.line([P(u, yb - 0.02), P(u + CGFloat(i - 4) * 0.012 + sw * 0.3, yb + 0.13 + 0.02 * sin(CGFloat(i) * 2.2))], 0.036,
                           koHex(i % 2 == 1 ? "#F4EFEA" : "#C92525"), cap: .round)
                }
            }
        }
    }

    /// White yarn over red knit: the colour goes, its light and shade stay (lifted).
    private static func whiteLive(_ x: GraphicsContext, _ p: Path) {
        var c = x
        c.blendMode = .color; c.fill(p, with: .color(.white))
        c.blendMode = .screen; c.fill(p, with: .color(Color(cgColor: koRGBA(190, 185, 182, 1))))
    }
    private static func whitePen(_ g: KoPen, _ p: CGPath) {
        g.save()
        g.blend(.color); g.fill(p, .color(koHex("#FFFFFF")))
        g.blend(.screen); g.fill(p, .color(koRGBA(190, 185, 182, 1)))
        g.restore()
    }

    /// Koru's outline in R units (scaled by sc round the body centre); with head, in the head's space, risen by rise.
    static func bodyR(_ d: KoruGeometry, _ sc: CGFloat = 1, head: Bool = false, rise: CGFloat = 0) -> Path {
        var M = CGAffineTransform(scaleX: sc * d.R, y: sc * d.R)
        if head { M = M.concatenating(d.head.inverted()) }
        M = M.concatenating(CGAffineTransform(scaleX: 1 / d.R, y: 1 / d.R)).concatenating(CGAffineTransform(translationX: 0, y: -rise))
        return KoruShape.body.applying(M)
    }

    /// Half-width of Koru's outline at height y (R units from the body centre).
    private static func bodyW(_ y: CGFloat) -> CGFloat {
        let top = y < 0, n = top ? KoruShape.nTop : KoruShape.nBot
        return KoruShape.rx * pow(max(0, 1 - pow(abs(y / (top ? KoruShape.ryTop : KoruShape.ryBot)), n)), 1 / n)
    }

    /// Pumpkin lobes peeking out from behind the body.
    static func pumpkinLobes(_ x0: GraphicsContext, _ k: K) {
        var x = x0
        x.translateBy(x: k.h, y: 0)
        part(x, k, "pumpkinLobes", koBox(-1.4, -1.25, 1.4, 1.25)) { g in
            for (u, v, rx, ry) in [(0, -0.01, 0.42, 1.03), (-0.48, -0.06, 0.42, 1.07), (0.48, -0.06, 0.42, 1.07), (-0.92, -0.04, 0.36, 0.86),
                                   (0.92, -0.04, 0.36, 0.86)] as [(CGFloat, CGFloat, CGFloat, CGFloat)] {
                let l = KoPath.ell(u, v, rx, ry)
                g.fill(l, .lin(0, -1, 0, 1, [(0, koHex("#F7A04A")), (1, koHex("#CF4E14"))]))
                g.clay(l, koBox(u - rx, v - ry, u + rx, v + ry), 0.2, 0.35)
            }
        }
    }

    /// The body takes the pumpkin colours (its shading kept) and five ribs; warm rims stand in for Koru's cyan ones.
    static func pumpkinBody(_ x0: GraphicsContext, _ k: K, _ d: KoruGeometry) {
        var x = x0
        let S = KoruShape.self, Y = S.ryTop + 0.05, BB = koBox(-S.rx, -S.ryTop, S.rx, S.ryBot)
        x.clip(to: bodyR(d))
        let r = CGRect(x: -1.3, y: -Y, width: 2.6, height: Y + S.ryBot + 0.05)
        do {
            var c = x
            c.blendMode = .color; c.fill(Path(r), with: shading(.lin(0.85, -0.9, -0.95, 0.9, [(0, koHex("#FFA94D")), (1, koHex("#E8590C"))])))
            c.blendMode = .softLight; c.fill(Path(r), with: .color(Color(cgColor: koRGBA(255, 150, 60, 0.5))))
        }
        if k.full {
            part(x, k, "pumpkinBody", koBox(-S.rx - 0.02, -S.ryTop - 0.02, S.rx + 0.02, S.ryBot + 0.02), pad: 0.75) { g in
                let body = S.body.cgPath, R = g.R
                g.inner(body, koRGBA(255, 214, 160, 0.8), R * 0.06, 0, R * 0.035, BB)
                g.fillRect(-S.rx, -0.2, S.rx * 2, S.ryBot + 0.2, .lin(0, -0.2, 0, S.ryBot, [(0, koRGBA(250, 125, 40, 0)), (1, koRGBA(250, 125, 40, 0.62))]))
                g.inner(body, koRGBA(255, 150, 60, 0.55), R * 0.09, -R * 0.06, 0, BB)
                g.inner(body, koRGBA(255, 135, 45, 0.45), R * 0.08, R * 0.05, 0, BB)
                g.inner(body, koRGBA(255, 140, 50, 0.4), R * 0.28, 0, -R * 0.14, BB)   // and its lower sides
            }
        }
        if k.simple { return }
        for lon in [-1.15, -0.55, 0, 0.55, 1.15] as [CGFloat] {
            let z = cos(lon)
            var rib = Path()
            rib.addLines((0...30).map { i in let y = -0.98 + 1.96 * CGFloat(i) / 30; return P(sin(lon) * bodyW(y) + k.f * 0.5 * z, y) })
            for (w, c) in [(0.2, koRGBA(150, 50, 0, 0.16 * z)), (0.1, koRGBA(120, 35, 0, 0.22 * z)), (0.04, koRGBA(80, 20, 0, 0.45 * z))] as [(CGFloat, CGColor)] {
                x.stroke(rib, with: .color(Color(cgColor: c)), style: StrokeStyle(lineWidth: w, lineCap: .round))
            }
        }
    }

    /// The wings, recoloured as the body is (shading kept), a deeper orange.
    static func pumpkinWings(_ x0: GraphicsContext, _ k: K, _ d: KoruGeometry) {
        var x = x0
        x.clip(to: d.wings.applying(CGAffineTransform(scaleX: 1 / d.R, y: 1 / d.R)))
        let r = Path(CGRect(x: -2, y: -2, width: 4, height: 4))
        x.blendMode = .color; x.fill(r, with: shading(.lin(0, -1, 0, 1, [(0, koHex("#F08A2E")), (1, koHex("#B8460C"))])))
        x.blendMode = .softLight; x.fill(r, with: .color(Color(cgColor: koRGBA(255, 140, 50, 0.55))))
    }

    /// A thick stalk bending to the right with a cut end, a curly tendril and a three-lobed leaf.
    static func pumpkinStem(_ x0: GraphicsContext, _ k: K) {
        var x = x0
        x.translateBy(x: k.h, y: 0)
        part(x, k, "pumpkinStem", koBox(-0.35, -1.75, 1.0, -0.8)) { g in
            let t = P(0.02, -1.04)
            let stem = CGMutablePath()
            stem.move(to: P(t.x - 0.14, t.y + 0.05))
            stem.addCurve(to: P(t.x + 0.04, t.y - 0.47), control1: P(t.x - 0.14, t.y - 0.18), control2: P(t.x - 0.11, t.y - 0.42))
            stem.addQuadCurve(to: P(t.x + 0.23, t.y - 0.42), control: P(t.x + 0.17, t.y - 0.5))
            stem.addQuadCurve(to: P(t.x + 0.13, t.y - 0.33), control: P(t.x + 0.22, t.y - 0.31))
            stem.addCurve(to: P(t.x + 0.14, t.y + 0.05), control1: P(t.x + 0.06, t.y - 0.31), control2: P(t.x + 0.06, t.y - 0.12))
            stem.closeSubpath()
            let SB = koBox(t.x - 0.16, t.y - 0.52, t.x + 0.26, t.y + 0.08)
            g.cast(stem, 0.25)
            g.fill(stem, .lin(t.x - 0.14, 0, t.x + 0.16, 0, [(0, koHex("#7CBF2A")), (0.55, koHex("#559A12")), (1, koHex("#36650A"))]))
            if !k.simple {
                g.save(); g.clip(stem)
                for u in [-0.06, 0.03] as [CGFloat] {
                    g.line([P(t.x + u, t.y + 0.05), P(t.x + u + 0.01, t.y - 0.2), P(t.x + u + 0.06, t.y - 0.42)], 0.02, koRGBA(30, 70, 0, 0.3), cap: .round)
                }
                g.restore()
                g.fill(KoPath.ell(t.x + 0.18, t.y - 0.385, 0.045, 0.06, 0.5), .color(koHex("#A3D65C")))   // the cut end
            }
            g.clay(stem, SB, 0.35, 0.25)
            if !k.simple {
                let tendril = CGMutablePath()
                tendril.move(to: P(t.x + 0.1, t.y - 0.18))
                tendril.addCurve(to: P(t.x + 0.35, t.y - 0.2), control1: P(t.x + 0.2, t.y - 0.12), control2: P(t.x + 0.33, t.y - 0.1))
                tendril.addCurve(to: P(t.x + 0.28, t.y - 0.2), control1: P(t.x + 0.37, t.y - 0.3), control2: P(t.x + 0.25, t.y - 0.3))
                tendril.addCurve(to: P(t.x + 0.5, t.y - 0.17), control1: P(t.x + 0.31, t.y - 0.1), control2: P(t.x + 0.42, t.y - 0.12))
                g.stroke(tendril, 0.04, .color(koHex("#5E9E18")), cap: .round)
            }
            g.save()
            g.translate(t.x + 0.5, t.y - 0.17); g.rotate(0.15); g.scale(-0.95, 0.95)   // the leaf at the end of the tendril
            let leaf = CGMutablePath()
            for (u, v, a) in [(-0.13, -0.07, -0.6), (-0.26, -0.08, 0), (-0.18, 0.05, 0.6)] as [(CGFloat, CGFloat, CGFloat)] { leaf.addPath(KoPath.ell(u, v, 0.11, 0.075, a)) }
            g.fill(leaf, .lin(0, -0.15, -0.3, 0, [(0, koHex("#8FD14F")), (1, koHex("#4D8C12"))]))
            g.clay(leaf, koBox(-0.5, -0.3, 0.05, 0.15), 0.3, 0.2)
            let vein = CGMutablePath()
            vein.move(to: P(-0.02, -0.01)); vein.addQuadCurve(to: P(-0.32, -0.03), control: P(-0.18, -0.08))
            g.stroke(vein, 0.02, .color(koRGBA(30, 60, 0, 0.4)), cap: .round)
            g.restore()
        }
    }
}
