import SwiftUI
import CoreGraphics

// Koru, the Koncluí owl: shapes, colours and states, ported from design/prototype/koru/core.js.
// Shapes are in units of R (0.3 × canvas width × Koru.frame, as for Mochi) from the body centre, y down,
// with the prototype's numbers kept as they are so the two can be compared line by line.

// MARK: - Colour

/// An sRGB colour in 0…255 components, as the prototype's [r,g,b] arrays.
struct KoruRGB: Equatable, Sendable {
    var r: CGFloat, g: CGFloat, b: CGFloat

    init(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) { self.r = r; self.g = g; self.b = b }

    init(hex: String) {
        let v = UInt32(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0
        self.init(CGFloat((v >> 16) & 0xFF), CGFloat((v >> 8) & 0xFF), CGFloat(v & 0xFF))
    }

    init(_ c: CGColor) {
        let k = c.converted(to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil)?.components ?? []
        guard k.count >= 3 else { self.init(255, 255, 255); return }
        self.init(k[0] * 255, k[1] * 255, k[2] * 255)
    }

    static let white = KoruRGB(255, 255, 255)
    static let black = KoruRGB(0, 0, 0)

    func mix(_ o: KoruRGB, _ t: CGFloat) -> KoruRGB {
        KoruRGB(r + (o.r - r) * t, g + (o.g - g) * t, b + (o.b - b) * t)
    }
    /// The colour multiplied by itself (minis.js deep()): darker and more saturated.
    func deep(_ k: CGFloat) -> KoruRGB { KoruRGB(r * r / 255 * k, g * g / 255 * k, b * b / 255 * k) }

    func color(_ a: CGFloat = 1) -> Color {
        Color(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(min(1, max(0, a))))
    }
    func cg(_ a: CGFloat = 1) -> CGColor {
        CGColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: min(1, max(0, a)))
    }
}

/// rgba(r,g,b,a) of the prototype.
func koruRGBA(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat) -> Color { KoruRGB(r, g, b).color(a) }

// MARK: - Palette

/// The colours a whole Koru can swap (core.js PALETTE): body = the key-light ramp from the lit dome to the shaded base,
/// belly = top to bottom, wing = upper edge to tip. Minis and coloured pills take their colour this way (minis.js palette()).
struct KoruPalette: Sendable {
    var body: [Color]
    var belly: [Color]
    var wing: [Color]
    var isKoru = false

    static let koru = KoruPalette(
        body: ["#6CCAD5", "#3EA5B1", "#2A94A2", "#167E8A", "#0E6470"].map { KoruRGB(hex: $0).color() },
        belly: [KoruRGB(hex: "#3FAAB2").color(), KoruRGB(hex: "#268C98").color(), koruRGBA(38, 140, 152, 0.6)],
        wing: [KoruRGB(hex: "#124F5C").color(), KoruRGB(hex: "#09343E").color()],
        isKoru: true)

    /// minis.js palette(c): the ramp under Koru's key light from the colour, a paler belly, deeper wings.
    static func agent(_ c: KoruRGB) -> KoruPalette {
        let w = KoruRGB.white
        return KoruPalette(
            body: [c.mix(w, 0.8), c.mix(w, 0.6), c.mix(w, 0.32), c.mix(w, 0.08),
                   c.mix(c.deep(1), 0.3).mix(.black, 0.16)].map { $0.color() },
            belly: [c.mix(w, 0.3).color(), c.mix(w, 0.18).color(), c.mix(w, 0.12).color(0.75)],
            wing: [c.deep(0.78).mix(w, 0.15).color(), c.deep(0.5).color()])
    }
}

// MARK: - States

enum KoruBadgeKind: Sendable { case dots, bang, q, dot, ring, arrow }
enum KoruAura: Sendable { case spark, wobble }

/// One row of core.js STATES: what Mochi's state table says plus Koru's own pose (head height, squash, ear tufts,
/// wing fold under the badge, fixed look, state light) and where her badge sits.
struct KoruStateCfg: Sendable {
    var col: KoruRGB
    var tint: CGFloat
    var badge: (kind: KoruBadgeKind, c0: KoruRGB, c1: KoruRGB)? = nil
    var bo = CGPoint.zero          // badge offset (R) from its default spot
    var bsc: CGFloat = 1           // badge scale
    var brot: CGFloat = 0          // badge rotation
    var dot: KoruRGB? = nil        // colour of the dots in a dots badge
    var hy: CGFloat = 0            // head lowered (R)
    var sq: CGFloat = 1            // body squash target
    var dy: CGFloat = 0            // body offset (R)
    var fold = false               // the left tuft folds under the badge
    var look: CGPoint? = nil       // fixed look direction, mixed 70 % with the pointer
    var converge = false           // pupils turn in
    var pupil: CGFloat = 1         // pupil scale for the pill eyes
    var scan = false
    var ear: CGFloat = 0           // tufts drop (+) or rise (−)
    var aura: KoruAura? = nil
    var tilt: CGFloat = 0          // head tilt
    var go: CGFloat                // floor glow
}

enum KoruStates {
    private static func badge(_ k: KoruBadgeKind, _ a: String, _ b: String) -> (kind: KoruBadgeKind, c0: KoruRGB, c1: KoruRGB) {
        (k, KoruRGB(hex: a), KoruRGB(hex: b))
    }
    static let update = badge(.arrow, "#5B9BFF", "#3B82F6")

    static let table: [BotState: KoruStateCfg] = [
        .idle: KoruStateCfg(col: KoruRGB(hex: "#1EAAC8"), tint: 0.2, go: 0.6),
        .working: KoruStateCfg(col: KoruRGB(hex: "#1796E5"), tint: 0.85, badge: badge(.dots, "#3D8CFF", "#2F6CF5"),
                               bo: CGPoint(x: -0.083, y: -0.11), hy: 0.054, sq: 0.955, dy: 0.03, fold: true,
                               look: CGPoint(x: 0.05, y: -1.6), converge: true, pupil: 1.12, go: 1),
        .thinking: KoruStateCfg(col: KoruRGB(hex: "#8C50FF"), tint: 0.85, badge: badge(.dots, "#9A4DFF", "#7C3AED"),
                                bo: CGPoint(x: 0.125, y: 0.058), bsc: 0.9, brot: -0.09, dot: KoruRGB(hex: "#F0D8FF"),
                                hy: 0.022, sq: 0.932, dy: 0.03, fold: true, look: CGPoint(x: 1.25, y: 0.95), go: 1),
        .searching: KoruStateCfg(col: KoruRGB(hex: "#4A80F2"), tint: 0.85, badge: badge(.dots, "#4F5BFF", "#3A3DF0"),
                                 bo: CGPoint(x: -0.05, y: 0.058), sq: 0.967, dy: 0.03, scan: true, go: 1),
        .approval: KoruStateCfg(col: KoruRGB(hex: "#FFAA1E"), tint: 0.95, badge: badge(.bang, "#FFC23A", "#F07F00"),
                                bo: CGPoint(x: 0, y: 0.11), hy: 0.076, sq: 0.935, dy: 0.03, fold: true,
                                look: CGPoint(x: 0.75, y: -0.05), go: 0.75),
        .question: KoruStateCfg(col: KoruRGB(hex: "#28C8FF"), tint: 0.9, badge: badge(.q, "#22D0FF", "#0A9CF0"),
                                bo: CGPoint(x: -0.05, y: -0.015), hy: -0.04, dy: 0.03, look: CGPoint(x: 1.1, y: 0.85),
                                tilt: 0.26, go: 0.5),
        .error: KoruStateCfg(col: KoruRGB(hex: "#FF3C46"), tint: 0.95, badge: badge(.dot, "#FF5A5A", "#E8303C"),
                             bo: CGPoint(x: -0.058, y: -0.067), hy: 0.05, dy: 0.03, ear: 1.4, go: 0.5),
        .finished: KoruStateCfg(col: KoruRGB(hex: "#2EE6C0"), tint: 0.85, badge: badge(.ring, "#22F79E", "#18D888"),
                                bo: CGPoint(x: 0.17, y: -0.04), hy: 0.06, dy: 0.03, aura: .spark, go: 0.5),
        .sleeping: KoruStateCfg(col: KoruRGB(hex: "#1EAAC8"), tint: 0.1, hy: 0.06, dy: 0.03, ear: 0.45, go: 0.32),
        .dizzy: KoruStateCfg(col: KoruRGB(hex: "#FF5AAA"), tint: 0.95, hy: 0.01, dy: 0.03, aura: .wobble, tilt: 0.17, go: 1),
        .ratelimit: KoruStateCfg(col: KoruRGB(hex: "#FB923C"), tint: 0.85, badge: badge(.dot, "#FFA552", "#F07C1E"), go: 0.9),
    ]

    static subscript(_ s: BotState) -> KoruStateCfg { table[s] ?? table[.idle]! }
}

// MARK: - Shapes

enum KoruShape {
    // core.js G
    static let rx: CGFloat = 1.21, ryTop: CGFloat = 1.04, ryBot: CGFloat = 1.02, cy: CGFloat = 0.088
    static let nTop: CGFloat = 2.0, nBot: CGFloat = 3.5
    static let eyeSp: CGFloat = 0.518, eyeY: CGFloat = -0.117, ring: CGFloat = 0.558, disc: CGFloat = 0.386
    static let pupil: CGFloat = 0.152, face: CGFloat = 0.27

    static func clamp(_ v: CGFloat, _ a: CGFloat, _ b: CGFloat) -> CGFloat { max(a, min(b, v)) }
    static func smooth(_ t: CGFloat) -> CGFloat { t * t * (3 - 2 * t) }
    static func easeOut(_ t: CGFloat) -> CGFloat { 1 - pow(1 - t, 3) }

    static func scaled(_ p: Path, _ R: CGFloat) -> Path { p.applying(CGAffineTransform(scaleX: R, y: R)) }

    /// Body at R = 1: an ellipse dome on top, a flatter superellipse underneath.
    static let body: Path = {
        var pts: [CGPoint] = []
        for i in 0...120 {
            let a = CGFloat(i) / 120 * .pi * 2, ca = cos(a), sa = sin(a), top = sa < 0
            let n = top ? nTop : nBot, ry = top ? ryTop : ryBot
            pts.append(CGPoint(x: rx * (ca < 0 ? -1 : 1) * pow(abs(ca), 2 / n),
                               y: ry * (sa < 0 ? -1 : 1) * pow(abs(sa), 2 / n)))
        }
        var p = Path(); p.addLines(pts); p.closeSubpath(); return p
    }()

    /// Wing at R = 1, left side: two feathers, a rounded upper one leaning out and a lower lobe below a soft notch.
    static let wing: Path = blob(pts([[-1.27, -0.10], [-1.18, -0.07], [-1.09, 0.0], [-1.02, 0.13], [-0.98, 0.33], [-0.99, 0.48],
                                      [-1.06, 0.555], [-1.15, 0.54], [-1.26, 0.42], [-1.36, 0.27], [-1.41, 0.18], [-1.37, 0.10],
                                      [-1.31, 0.135], [-1.32, 0.02], [-1.31, -0.06]]), 1, n: 3)

    static func pts(_ a: [[CGFloat]]) -> [CGPoint] { a.map { CGPoint(x: $0[0], y: $0[1]) } }

    /// Point list (R units) to a path; every path winds the same way, so shapes merge into one fill.
    static func toPath(_ pts: [CGPoint], _ R: CGFloat) -> Path {
        var area: CGFloat = 0
        for i in pts.indices { let a = pts[i], b = pts[(i + 1) % pts.count]; area += a.x * b.y - b.x * a.y }
        let ordered = area < 0 ? pts.reversed() : pts
        var p = Path(); p.addLines(ordered.map { CGPoint(x: $0.x * R, y: $0.y * R) }); p.closeSubpath(); return p
    }

    /// Quadratic outline [[x0,y0],[cx,cy,x1,y1] or [x,y],…].
    static func outline(_ segs: [[CGFloat]], _ R: CGFloat) -> Path {
        var px = segs[0][0], py = segs[0][1]
        var out = [CGPoint(x: px, y: py)]
        for sg in segs.dropFirst() {
            if sg.count == 2 { px = sg[0]; py = sg[1]; out.append(CGPoint(x: px, y: py)); continue }
            let qx = sg[0], qy = sg[1], ex = sg[2], ey = sg[3]
            for i in 1...10 {
                let t = CGFloat(i) / 10, u = 1 - t
                out.append(CGPoint(x: u * u * px + 2 * u * t * qx + t * t * ex, y: u * u * py + 2 * u * t * qy + t * t * ey))
            }
            px = ex; py = ey
        }
        return toPath(out, R)
    }

    /// Rounded blob: Chaikin corner cutting on a control polygon, so no tip stays sharp.
    static func blob(_ pts0: [CGPoint], _ R: CGFloat, n: Int = 4) -> Path {
        var pts = pts0
        for _ in 0..<n {
            var o: [CGPoint] = []; o.reserveCapacity(pts.count * 2)
            for i in pts.indices {
                let a = pts[i], c = pts[(i + 1) % pts.count]
                o.append(CGPoint(x: 0.75 * a.x + 0.25 * c.x, y: 0.75 * a.y + 0.25 * c.y))
                o.append(CGPoint(x: 0.25 * a.x + 0.75 * c.x, y: 0.25 * a.y + 0.75 * c.y))
            }
            pts = o
        }
        return toPath(pts, R)
    }

    static func mirror(_ segs: [[CGFloat]], _ sd: CGFloat) -> [[CGFloat]] {
        segs.map { sg in sg.enumerated().map { $0.offset % 2 == 1 ? $0.element : $0.element * sd } }
    }

    /// Eye ring (side sd): a circle pulled in on its lower inner side so the two rings part under the beak;
    /// k scales the outer side for the head turn.
    static func ringPts(_ cxr: CGFloat, _ cyr: CGFloat, _ r: CGFloat, _ k: CGFloat, _ sd: CGFloat, _ pull: CGFloat,
                        _ up: CGFloat = 0.15) -> [CGPoint] {
        let li: CGFloat = sd < 0 ? .pi / 4 : .pi * 3 / 4, ui: CGFloat = sd < 0 ? -.pi / 4 : -.pi * 3 / 4
        return (0..<72).map { i in
            let a = CGFloat(i) / 72 * .pi * 2
            let rr = r - pull * pow(max(0, cos(a - li)), 2) * max(0, sin(a)) - up * pow(max(0, cos(a - ui)), 2) * max(0, -sin(a))
            var u = cos(a) * rr
            let v = sin(a) * rr
            if u * sd > 0 { u *= k }
            return CGPoint(x: cxr + u, y: cyr + v)
        }
    }

    /// Left brow; f = face offset for the head turn. The far brow drops with its tuft.
    static func browSegs(_ f: CGFloat, _ far: CGFloat) -> [[CGFloat]] {
        [[0 + f, -0.24], [-0.08 + f * 0.8, -0.80 + 0.06 * far, -0.75 + f * 0.5, -0.92 + 0.14 * far], [-0.72 + f * 0.6, -0.50], [-0.36 + f, -0.42]]
    }

    private static let tuft = pts([[-1.10, -1.16], [-1.14, -1.07], [-1.13, -0.92], [-1.05, -0.80], [-1.20, -0.79], [-1.16, -0.70],
                                   [-1.04, -0.62], [-0.86, -0.50], [-0.63, -0.56], [-0.55, -0.76], [-0.58, -0.86], [-0.66, -0.90],
                                   [-0.80, -0.965], [-0.95, -1.04]])

    /// Left ear tuft; e lowers the tip (sad, asleep) or raises it when negative (surprised).
    static func tuftPts(_ f: CGFloat, _ e: CGFloat, _ far: CGFloat) -> [[CGFloat]] {
        tuft.map { q in
            var u = q.x, v = q.y
            let bx: CGFloat = -0.6, by: CGFloat = -0.8
            let w = clamp(hypot(u - bx, v - by) / 0.45, 0, 1), a = -0.5 * e * w, c = cos(a), sn = sin(a)
            v += far * (0.05 + 0.12 * clamp((u + 1.0) / 0.45, 0, 1) + 0.04 * clamp((v + 0.75) / 0.25, 0, 1))
            u -= 0.03 * far * clamp((-u - 0.9) / 0.25, 0, 1)
            return [bx + (u - bx) * c - (v - by) * sn + f, by + (u - bx) * sn + (v - by) * c]
        }
    }

    /// The beak in its own space: a teardrop br wide each side, its tip at tip below the centre.
    static func beak(_ br: CGFloat, _ tip: CGFloat) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: -br * 0.92))
        p.addCurve(to: CGPoint(x: br * 0.98, y: br * 0.12), control1: CGPoint(x: br * 0.75, y: -br * 0.95), control2: CGPoint(x: br * 1.08, y: -br * 0.35))
        p.addCurve(to: CGPoint(x: 0, y: tip), control1: CGPoint(x: br * 0.88, y: br * 0.6), control2: CGPoint(x: br * 0.3, y: tip * 0.85))
        p.addCurve(to: CGPoint(x: -br * 0.98, y: br * 0.12), control1: CGPoint(x: -br * 0.3, y: tip * 0.85), control2: CGPoint(x: -br * 0.88, y: br * 0.6))
        p.addCurve(to: CGPoint(x: 0, y: -br * 0.92), control1: CGPoint(x: -br * 1.08, y: -br * 0.35), control2: CGPoint(x: -br * 0.75, y: -br * 0.95))
        p.closeSubpath()
        return p
    }

    static func circle(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
    }

    static func roundRect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> Path {
        Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: max(0, min(r, w / 2, h / 2)), style: .circular)
    }

    /// An arc as the canvas draws it: from a0 to a1 with the angle growing (clockwise on screen).
    static func addArc(_ p: inout Path, _ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat, _ a0: CGFloat, _ a1: CGFloat, start: Bool) {
        let n = max(8, Int(abs(a1 - a0) / (.pi / 24)))
        for i in 0...n {
            let a = a0 + (a1 - a0) * CGFloat(i) / CGFloat(n), q = CGPoint(x: cx + cos(a) * r, y: cy + sin(a) * r)
            if i == 0 && start { p.move(to: q) } else { p.addLine(to: q) }
        }
    }

    static func heart(_ s: CGFloat) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: s * 0.38))
        p.addCurve(to: CGPoint(x: 0, y: -s * 0.38), control1: CGPoint(x: -s * 1.05, y: -s * 0.15), control2: CGPoint(x: -s * 0.5, y: -s * 0.95))
        p.addCurve(to: CGPoint(x: 0, y: s * 0.38), control1: CGPoint(x: s * 0.5, y: -s * 0.95), control2: CGPoint(x: s * 1.05, y: -s * 0.15))
        p.closeSubpath()
        return p
    }

    static func star(_ ro: CGFloat, _ ri: CGFloat, _ n: Int = 5) -> Path {
        var p = Path()
        for i in 0..<(n * 2) {
            let r = i % 2 == 1 ? ri : ro, a = -.pi / 2 + CGFloat(i) * .pi / CGFloat(n)
            let q = CGPoint(x: cos(a) * r, y: sin(a) * r)
            if i == 0 { p.move(to: q) } else { p.addLine(to: q) }
        }
        p.closeSubpath()
        return p
    }

    /// Tapered crescent along a circle (centre 0,cy, radius r) from a0 to a1, th thick in the middle.
    static func crescent(_ cy: CGFloat, _ r: CGFloat, _ a0: CGFloat, _ a1: CGFloat, _ th: CGFloat) -> Path {
        var p = Path()
        let n = 24
        for i in 0...n {
            let a = a0 + (a1 - a0) * CGFloat(i) / CGFloat(n), q = CGPoint(x: cos(a) * r, y: cy + sin(a) * r)
            if i == 0 { p.move(to: q) } else { p.addLine(to: q) }
        }
        for i in stride(from: n, through: 0, by: -1) {
            let a = a0 + (a1 - a0) * CGFloat(i) / CGFloat(n), k = r - th * pow(sin(CGFloat.pi * CGFloat(i) / CGFloat(n)), 0.8)
            p.addLine(to: CGPoint(x: cos(a) * k, y: cy + sin(a) * k))
        }
        p.closeSubpath()
        return p
    }

    /// Eyelid inside an eye disc of radius dr (0…1 closed): its edge bows down in the middle like a real lid.
    static func lidPath(_ dr: CGFloat, _ lid: CGFloat) -> Path {
        let y = -dr + 2 * dr * lid, bow = dr * 0.28 * sin(.pi * lid)
        var p = Path()
        p.move(to: CGPoint(x: -dr, y: -dr)); p.addLine(to: CGPoint(x: dr, y: -dr))
        p.addLine(to: CGPoint(x: dr, y: y - bow * 0.6))
        p.addQuadCurve(to: CGPoint(x: -dr, y: y - bow * 0.6), control: CGPoint(x: 0, y: y + bow))
        p.closeSubpath()
        return p
    }

    static func lidEdge(_ dr: CGFloat, _ lid: CGFloat) -> Path {
        let y = -dr + 2 * dr * lid, bow = dr * 0.28 * sin(.pi * lid)
        var p = Path()
        p.move(to: CGPoint(x: -dr, y: y - bow * 0.6))
        p.addQuadCurve(to: CGPoint(x: dr, y: y - bow * 0.6), control: CGPoint(x: 0, y: y + bow))
        return p
    }
}
