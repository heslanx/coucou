import SwiftUI
import CoreGraphics

// Drawing an outfit part (outfits.js part()): Core Graphics into a cached KoruSheets sheet, in R units (the context is
// scaled by the sheet's R px), with the canvas calls the parts use: gradients that pad past their ends, inner light and
// drop shadows in device px under any transform, velvet grain, and Koru's clay finish.

/// sRGB colour from #RRGGBB.
func koHex(_ hex: String, _ a: CGFloat = 1) -> CGColor { KoruRGB(hex: hex).cg(a) }
/// rgba(r,g,b,a).
func koRGBA(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat) -> CGColor { KoruRGB(r, g, b).cg(a) }

/// A fill or stroke: a colour or a canvas gradient (stops as offset, colour).
enum KoShade {
    case color(CGColor)
    case lin(CGFloat, CGFloat, CGFloat, CGFloat, [(CGFloat, CGColor)])
    case rad(CGFloat, CGFloat, CGFloat, [(CGFloat, CGColor)])
    /// createConicGradient(start, cx, cy): clockwise on screen from the start angle.
    case conic(CGFloat, CGFloat, CGFloat, [(CGFloat, CGColor)])

    var gradient: CGGradient? {
        let st: [(CGFloat, CGColor)]
        switch self {
        case .color: return nil
        case .lin(_, _, _, _, let s), .rad(_, _, _, let s), .conic(_, _, _, let s): st = s
        }
        return CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: st.map(\.1) as CFArray, locations: st.map(\.0))
    }
}

/// Paths in R units.
enum KoPath {
    static func ell(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat, _ rot: CGFloat = 0) -> CGMutablePath {
        let p = CGMutablePath()
        let T = CGAffineTransform(translationX: cx, y: cy).rotated(by: rot)
        p.addEllipse(in: CGRect(x: -rx, y: -ry, width: 2 * rx, height: 2 * ry), transform: T)
        return p
    }
    /// The canvas ellipse() call on a path: from the current point, a line to the arc start, then the arc (clockwise on screen).
    static func arc(_ p: CGMutablePath, _ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat, _ a0: CGFloat, _ a1: CGFloat, rot: CGFloat = 0) {
        let T = CGAffineTransform(translationX: cx, y: cy).rotated(by: rot).scaledBy(x: rx, y: ry)
        p.addArc(center: .zero, radius: 1, startAngle: a0, endAngle: a1, clockwise: false, transform: T)
    }
    static func rrect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> CGMutablePath {
        rrect(x, y, w, h, [r, r, r, r])
    }
    /// roundRect with corner radii top-left, top-right, bottom-right, bottom-left.
    static func rrect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: [CGFloat]) -> CGMutablePath {
        let p = CGMutablePath()
        add(p, rrect: CGRect(x: x, y: y, width: w, height: h), r)
        return p
    }
    static func add(_ p: CGMutablePath, rrect b: CGRect, _ r0: [CGFloat]) {
        let m = min(b.width, b.height) / 2, r = r0.map { min($0, m) }
        p.move(to: CGPoint(x: b.minX + r[0], y: b.minY))
        p.addLine(to: CGPoint(x: b.maxX - r[1], y: b.minY))
        p.addArc(tangent1End: CGPoint(x: b.maxX, y: b.minY), tangent2End: CGPoint(x: b.maxX, y: b.minY + r[1]), radius: r[1])
        p.addLine(to: CGPoint(x: b.maxX, y: b.maxY - r[2]))
        p.addArc(tangent1End: CGPoint(x: b.maxX, y: b.maxY), tangent2End: CGPoint(x: b.maxX - r[2], y: b.maxY), radius: r[2])
        p.addLine(to: CGPoint(x: b.minX + r[3], y: b.maxY))
        p.addArc(tangent1End: CGPoint(x: b.minX, y: b.maxY), tangent2End: CGPoint(x: b.minX, y: b.maxY - r[3]), radius: r[3])
        p.addLine(to: CGPoint(x: b.minX, y: b.minY + r[0]))
        p.addArc(tangent1End: CGPoint(x: b.minX, y: b.minY), tangent2End: CGPoint(x: b.minX + r[0], y: b.minY), radius: r[0])
        p.closeSubpath()
    }
    static func poly(_ pts: [CGPoint]) -> CGMutablePath {
        let p = CGMutablePath()
        p.addLines(between: pts)
        return p
    }
}

/// One outfit frame (outfits.js stage()'s k): R in px of what it draws into, the head turn, the lag, a scarf's rise and
/// the eye discs in R units.
struct KoruOutfitK {
    /// R in px of what is being drawn into (a sheet's R inside a part); Rpx the frame's R in px, Rpt in points.
    var R: CGFloat
    var Rpx: CGFloat
    var Rpt: CGFloat
    var full: Bool
    var simple: Bool
    /// Face offset (R) and the hats' share of it.
    var f: CGFloat, h: CGFloat
    var yaw: CGFloat
    /// The lag, quantised (KoruOutfits stage()) so a pose keeps one sheet.
    var dx: CGFloat, dy: CGFloat
    var rise: CGFloat = 0
    var eyes: [KoruEyeDisc] = []
    var lag: String { "\(Int((dx * 100).rounded())),\(Int((dy * 100).rounded()))" }
}

/// Core Graphics in R units inside a sheet: g's transform maps R units to the sheet; base maps the sheet's room (px) to
/// the device, so soft light and shadow (device px, as canvas shadows) land where the canvas puts them.
@MainActor
struct KoPen {
    let g: CGContext
    let room: CGRect
    let base: CGAffineTransform
    let k: KoruOutfitK
    var R: CGFloat { k.R }

    /// Current user space → room px.
    var toRoom: CGAffineTransform { g.ctm.concatenating(base.inverted()) }

    func save() { g.saveGState() }
    func restore() { g.restoreGState() }
    func translate(_ x: CGFloat, _ y: CGFloat) { g.translateBy(x: x, y: y) }
    func rotate(_ a: CGFloat) { g.rotate(by: a) }
    func scale(_ x: CGFloat, _ y: CGFloat) { g.scaleBy(x: x, y: y) }
    func clip(_ p: CGPath, eo: Bool = false) { g.addPath(p); g.clip(using: eo ? .evenOdd : .winding) }
    func alpha(_ a: CGFloat) { g.setAlpha(a) }
    func blend(_ m: CGBlendMode) { g.setBlendMode(m) }

    /// Fills the current clip region with a shading (for clipped fills and fillRect).
    private func paint(_ s: KoShade) {
        let opts: CGGradientDrawingOptions = [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        switch s {
        case .color(let c):
            g.setFillColor(c); g.fill(CGRect(x: -1e4, y: -1e4, width: 2e4, height: 2e4))
        case .lin(let x0, let y0, let x1, let y1, _):
            if let gr = s.gradient { g.drawLinearGradient(gr, start: CGPoint(x: x0, y: y0), end: CGPoint(x: x1, y: y1), options: opts) }
        case .rad(let cx, let cy, let r, _):
            if let gr = s.gradient {
                g.drawRadialGradient(gr, startCenter: CGPoint(x: cx, y: cy), startRadius: 0, endCenter: CGPoint(x: cx, y: cy), endRadius: r, options: opts)
            }
        case .conic(let a, let cx, let cy, let st):
            // Wedges of the interpolated colour, clockwise on screen from a (Core Graphics has no conic gradient here).
            let n = 120
            func at(_ t: CGFloat) -> CGColor {
                guard let j = st.firstIndex(where: { $0.0 >= t }), j > 0 else { return (t <= st[0].0 ? st.first : st.last)!.1 }
                let (t0, c0) = st[j - 1], (t1, c1) = st[j], u = t1 > t0 ? (t - t0) / (t1 - t0) : 0
                let p = KoruRGB(c0), q = KoruRGB(c1)
                return p.mix(q, u).cg(c0.alpha + (c1.alpha - c0.alpha) * u)
            }
            for i in 0..<n {
                let a0 = a + 2 * .pi * CGFloat(i) / CGFloat(n), a1 = a + 2 * .pi * CGFloat(i + 1) / CGFloat(n) + 0.004
                let w = CGMutablePath()
                w.move(to: CGPoint(x: cx, y: cy))
                w.addArc(center: CGPoint(x: cx, y: cy), radius: 1e3, startAngle: a0, endAngle: a1, clockwise: false)
                w.closeSubpath()
                g.addPath(w); g.setFillColor(at((CGFloat(i) + 0.5) / CGFloat(n))); g.fillPath()
            }
        }
    }

    func fill(_ p: CGPath, _ s: KoShade, eo: Bool = false) {
        if case .color(let c) = s { g.addPath(p); g.setFillColor(c); g.fillPath(using: eo ? .evenOdd : .winding); return }
        save(); clip(p, eo: eo); paint(s); restore()
    }
    func fillRect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ s: KoShade) {
        fill(CGPath(rect: CGRect(x: x, y: y, width: w, height: h), transform: nil), s)
    }
    func stroke(_ p: CGPath, _ w: CGFloat, _ s: KoShade, cap: CGLineCap = .butt, join: CGLineJoin = .miter) {
        save()
        g.addPath(p); g.setLineWidth(w); g.setLineCap(cap); g.setLineJoin(join)
        if case .color(let c) = s { g.setStrokeColor(c); g.strokePath() } else { g.replacePathWithStrokedPath(); g.clip(); paint(s) }
        restore()
    }
    /// outfits.js line(): a polyline stroke.
    func line(_ pts: [CGPoint], _ w: CGFloat, _ c: CGColor, cap: CGLineCap = .butt) {
        let p = CGMutablePath(); p.addLines(between: pts)
        stroke(p, w, .color(c), cap: cap, join: .miter)
    }

    /// The room px bounds of a box in user units.
    private func roomBox(_ box: CGRect) -> CGRect { box.applying(toRoom) }
    /// Runs body in the room's px space (y down), the clip kept.
    private func inRoom(_ body: () -> Void) {
        save(); g.concatenate(g.ctm.inverted()); g.concatenate(base); body(); restore()
    }

    /// core.js inner(): light or shade along the inside edges of p; blur, dx, dy in device px.
    func inner(_ p: CGPath, _ color: CGColor, _ blur: CGFloat, _ dx: CGFloat, _ dy: CGFloat, _ box: CGRect) {
        var M = toRoom
        guard let pr = p.copy(using: &M) else { return }
        let b = roomBox(box)
        inRoom { KoruSheets.inner(g, room: room, pr, color, blur, dx, dy, box: b) }
    }
    /// core.js drop(): the soft shadow of p without p; blur, dx, dy in device px.
    func drop(_ p: CGPath, _ color: CGColor, _ blur: CGFloat, _ dx: CGFloat = 0, _ dy: CGFloat = 0) {
        var M = toRoom
        guard let pr = p.copy(using: &M) else { return }
        inRoom { KoruSheets.drop(g, pr, color, blur, dx, dy) }
    }
    /// core.js grainOn(): velvet grain inside p, opaque at room y top, faint from bottom, laid with soft light.
    func grainOn(_ p: CGPath, _ top: CGFloat, _ bottom: CGFloat, _ a: CGFloat, _ box: CGRect) {
        let b = roomBox(box).insetBy(dx: -2, dy: -2).intersection(room).integral
        guard !b.isNull, b.width >= 1, b.height >= 1, let s = KoruSheets.grain(box: b, y0: top, y1: bottom, R: R) else { return }
        save()
        clip(p)
        inRoom {
            g.setBlendMode(.softLight); g.setAlpha(a)
            g.translateBy(x: 0, y: s.rect.maxY); g.scaleBy(x: 1, y: -1)   // a sheet's image is stored top row first
            g.draw(s.image, in: CGRect(x: s.rect.minX, y: 0, width: s.rect.width, height: s.rect.height))
        }
        restore()
    }
    /// outfits.js clay(): Koru's soft clay on an accessory (full size only): grain, a lit top-right rim, a shaded lower-left edge.
    func clay(_ p: CGPath, _ box: CGRect, _ lit: CGFloat = 0.38, _ dark: CGFloat = 0.3) {
        guard k.full else { return }
        let T = toRoom
        grainOn(p, CGPoint(x: 0, y: box.minY).applying(T).y, CGPoint(x: 0, y: box.maxY).applying(T).y, 0.32, box)
        inner(p, koRGBA(255, 250, 240, lit), R * 0.03, -R * 0.012, R * 0.022, box)
        inner(p, koRGBA(20, 8, 30, dark), R * 0.09, R * 0.03, -R * 0.05, box)
    }
    /// outfits.js cast(): a soft contact shadow on Koru (full size only).
    func cast(_ p: CGPath, _ a: CGFloat = 0.3) {
        if k.full { drop(p, koRGBA(2, 36, 42, a), R * 0.07, 0, R * 0.04) }
    }
}

/// A box [x0, y0, x1, y1] in R units.
func koBox(_ x0: CGFloat, _ y0: CGFloat, _ x1: CGFloat, _ y1: CGFloat) -> CGRect { CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0) }
