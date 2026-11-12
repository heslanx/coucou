// OutfitRender.swift — K5's modes on K2's harness (KoruRender.swift helpers): the hooks' before/after proof and the outfits.
// Build and run: bash scripts/konclui/render/k5/outfits.sh <mode> [out dir]
//   poses   fixed poses drawn bare, no engine and no clock, at 600 px (1×) and the island size (2×); raw RGBA dumps too
//   (the outfit modes are listed in main below)

import SwiftUI
import AppKit
import ImageIO
import UniformTypeIdentifiers

// MARK: - Fixed poses

/// A pose for state s, its values at rest (the eased ones at their targets), on a fixed clock.
@MainActor
func restPose(_ s: BotState, eye: EyeShape = .pill, yaw: CGFloat = 0.3, pitch: CGFloat = -0.05) -> KoruPose {
    let c = KoruStates[s]
    var p = KoruPose()
    p.cfg = c; p.col = c.col; p.tint = c.tint; p.go = c.go; p.hy = c.hy; p.ear = c.ear; p.tilt = c.tilt
    p.sy = c.sq; p.oy = c.dy; p.eye = eye; p.yaw = yaw; p.pitch = pitch
    p.badgeS = c.badge != nil ? 1 : 0
    p.aura = c.aura; p.auraA = c.aura != nil ? 1 : 0
    p.t = 1.25; p.now = 100; p.frame = 0.8
    return p
}

@MainActor
func fixedPoses() -> [(String, KoruPose)] {
    var out: [(String, KoruPose)] = []
    out.append(("idle", restPose(.idle)))
    out.append(("working", restPose(.working)))
    out.append(("thinking dot", restPose(.thinking, eye: .dot, yaw: -0.4)))
    var a = restPose(.approval, eye: .wide); a.hands = 1; a.handSide = -1; a.waveStart = 99.5; a.waveUntil = 101
    out.append(("approval waving", a))
    var q = restPose(.question); q.hands = 1; q.cup = true; q.handSide = -1
    out.append(("question cup", q))
    out.append(("error flat", restPose(.error, eye: .flat)))
    out.append(("finished happy", restPose(.finished, eye: .happy)))
    var z = restPose(.sleeping, eye: .closed); z.open = 0.4
    out.append(("sleeping lid", z))
    var d = restPose(.dizzy, eye: .spiral); d.roll = 0.4
    out.append(("dizzy roll", d))
    var h = restPose(.idle, eye: .heart); h.blush = 1
    out.append(("heart blush", h))
    out.append(("star", restPose(.idle, eye: .star, yaw: 0)))
    out.append(("tired", restPose(.ratelimit, eye: .tired)))
    out.append(("wink", restPose(.idle, eye: .wink, yaw: -0.62)))
    var m = restPose(.working); m.mini = true; m.palette = .agent(KoruRGB(hex: "#F5F6F8"))
    out.append(("mini agent", m))
    var r = restPose(.idle, yaw: -0.62); r.hands = 0.3; r.handSide = 1
    out.append(("raising", r))
    var s = restPose(.working, eye: .line); s.sx = 1.16; s.sy = 0.78
    out.append(("squash line", s))
    return out
}

@MainActor
func drawPose(_ p: KoruPose, _ ctx: GraphicsContext, _ size: CGSize, layers: KoruLayers? = nil) {
    let badge: KoruBadgeKind? = p.cfg.badge?.kind
    let colors = p.cfg.badge.map { ($0.c0, $0.c1) } ?? (.white, .white)
    #if K5_BASELINE
    Koru.draw(ctx, size: size, pose: p)
    Koru.drawFront(ctx, size: size, pose: p, badge: badge, badgeColors: colors, particles: [])
    #else
    if let layers {
        Koru.draw(ctx, size: size, pose: p, layers: layers)
        Koru.drawFront(ctx, size: size, pose: p, badge: badge, badgeColors: colors, particles: [], layers: layers)
    } else {
        Koru.draw(ctx, size: size, pose: p)
        Koru.drawFront(ctx, size: size, pose: p, badge: badge, badgeColors: colors, particles: [])
    }
    #endif
}

/// Raw premultiplied RGBA bytes of an image (for exact comparisons).
func rgba(_ img: CGImage) -> [UInt8] {
    let W = img.width, H = img.height
    var buf = [UInt8](repeating: 0, count: W * H * 4)
    buf.withUnsafeMutableBytes { raw in
        let g = CGContext(data: raw.baseAddress, width: W, height: H, bitsPerComponent: 8, bytesPerRow: W * 4,
                          space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        g.draw(img, in: CGRect(x: 0, y: 0, width: W, height: H))
    }
    return buf
}

/// The poses at 600 px (1×) and at the island size (97 pt, 2×), on the shot backdrop; each also written as raw bytes.
@MainActor
func poses(_ out: String) {
    var cells: [(CGImage, String)] = []
    for (px, scale, tag) in [(600.0, 1.0, "600"), (58 / 0.6, 2.0, "island")] as [(CGFloat, CGFloat, String)] {
        for (i, (name, p)) in fixedPoses().enumerated() {
            let img = render(width: px, height: px, scale: scale, bg: bgShot) { ctx, sz in drawPose(p, ctx, sz) }
            let bytes = rgba(img)
            try? Data(bytes).write(to: URL(fileURLWithPath: "\(out)/pose-\(tag)-\(i).rgba"))
            if tag == "600" { cells.append((img, name)) }
        }
    }
    savePNG(compose(cells, cols: 6, w: 240, h: 240), "\(out)/poses.png")
}

/// Max and mean per-channel difference between two pose dumps folders.
func comparePoses(_ a: String, _ b: String) {
    let fm = FileManager.default
    let files = ((try? fm.contentsOfDirectory(atPath: a)) ?? []).filter { $0.hasSuffix(".rgba") }.sorted()
    var worst = 0
    for f in files {
        guard let x = fm.contents(atPath: "\(a)/\(f)"), let y = fm.contents(atPath: "\(b)/\(f)"), x.count == y.count else {
            print("\(f): missing or size differs"); worst = 255; continue
        }
        var mx = 0, sum = 0
        for i in 0..<x.count { let d = abs(Int(x[i]) - Int(y[i])); mx = max(mx, d); sum += d }
        worst = max(worst, mx)
        print(String(format: "%@: max |diff| %d, mean %.4f", f, mx, Double(sum) / Double(x.count)))
    }
    print("files \(files.count), worst max |diff| \(worst)")
}

@main
struct OutfitRenderMain {
    @MainActor static func main() {
        let args = CommandLine.arguments
        let mode = args.count > 1 ? args[1] : "poses"
        let out = args.count > 2 ? args[2] : FileManager.default.currentDirectoryPath
        try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)
        switch mode {
        case "poses": poses(out)
        case "compare": comparePoses(out, args.count > 3 ? args[3] : out)
        default:
            #if !K5_BASELINE
            outfitMode(mode, out, args.count > 3 ? args[3] : "")
            #else
            print("baseline build: poses only")
            #endif
        }
    }
}

#if !K5_BASELINE
/// Every hook marks its z-point: floor a red pool, behind a yellow disc, body a green band, wings recoloured magenta
/// through geometry.wings, headBack a blue bar over the crown, face a white ring, the beak replaced by a red dot, the
/// eyes by squares, headFront a black bar on the eyes, headTop a small white disc, front a frame round the canvas.
@MainActor
func hookTest(_ out: String) {
    var L = KoruLayers()
    L.floor = [{ c, d in c.fill(Path(ellipseIn: CGRect(x: d.cx - d.R, y: d.cy + d.ryB - d.R * 0.1, width: d.R * 2, height: d.R * 0.2)), with: .color(.red)) }]
    L.behind = [{ c, d in c.fill(KoruShape.circle(0, -d.R * 0.2, d.R * 1.5), with: .color(.yellow)) }]
    L.body = [{ c, d in var q = c; q.clip(to: d.body); q.fill(Path(CGRect(x: -d.R * 2, y: d.R * 0.3, width: d.R * 4, height: d.R * 0.2)), with: .color(.green)) }]
    L.wings = [{ c, d in var q = c; q.clip(to: d.wings); q.blendMode = .color; q.fill(Path(CGRect(x: -d.R * 3, y: -d.R * 3, width: d.R * 6, height: d.R * 6)), with: .color(.pink)) }]
    L.headBack = [{ c, d in c.fill(Path(CGRect(x: -d.R * 0.9, y: -d.R * 1.35, width: d.R * 1.8, height: d.R * 0.25)), with: .color(.blue)) }]
    L.face = [{ c, d in c.stroke(KoruShape.circle(d.fx, -d.R * 0.5, d.R * 0.2), with: .color(.white), lineWidth: d.R * 0.04) }]
    L.beak = [{ c, d in c.fill(KoruShape.circle(0, 0, d.br), with: .color(.red)); return true }]
    L.eye = [{ c, e in c.fill(Path(CGRect(x: e.px - e.pr, y: e.py - e.pr, width: e.pr * 2, height: e.pr * 2)), with: .color(.black)); return true }]
    L.headFront = [{ c, d in for e in d.eyes { c.fill(Path(CGRect(x: e.x - e.r, y: e.y + e.r * 0.6, width: e.r * 2, height: e.r * 0.15)), with: .color(.black)) } }]
    L.headTop = [{ c, d in
        c.fill(KoruShape.circle(d.beakAt.x, d.beakAt.y + d.R * 0.3, d.R * 0.06), with: .color(.white))
    }]
    L.front = [{ c, d in
        c.stroke(Path(CGRect(origin: .zero, size: d.size).insetBy(dx: 2, dy: 2)), with: .color(.orange), lineWidth: 3)
        // bodyT and head bring the beak's place (head space) to the canvas: a cyan ring round the red beak dot.
        let q = d.beakAt.applying(d.head.concatenating(d.bodyT))
        c.stroke(KoruShape.circle(q.x, q.y, d.R * 0.22), with: .color(.cyan), lineWidth: d.R * 0.06)
    }]
    var cells: [(CGImage, String)] = []
    for (name, p) in fixedPoses().prefix(6) + fixedPoses().filter({ ["dizzy roll", "squash line", "mini agent"].contains($0.0) }) {
        cells.append((render(width: 400, height: 400, scale: 1, bg: bgShot) { ctx, sz in drawPose(p, ctx, sz, layers: L) }, name))
    }
    savePNG(compose(cells, cols: 5, w: 240, h: 240), "\(out)/hooks-smoke.png")
}

let wardrobe: [Outfit] = [.none, .partyHat, .beanie, .crown, .sunglasses, .roundGlasses, .bow, .scarf, .witchHat, .pumpkin, .santaHat, .bunnyEars]

func loadPNG(_ path: String) -> CGImage? {
    guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(src, 0, nil)
}

/// Mean |diff| (0…255, RGB) and the share of pixels off by more than 25, both images drawn at w × h; with a mask image,
/// only where the mask differs from b by more than 10 (the outfit's own pixels: Swift with it against Swift without).
func meanDiff(_ a: CGImage, _ b: CGImage, w: Int, h: Int, maskOff: CGImage? = nil) -> (Double, Double) {
    func px(_ i: CGImage) -> [UInt8] {
        var buf = [UInt8](repeating: 0, count: w * h * 4)
        buf.withUnsafeMutableBytes { raw in
            let g = CGContext(data: raw.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                              space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            g.interpolationQuality = .high
            g.draw(i, in: CGRect(x: 0, y: 0, width: w, height: h))
        }
        return buf
    }
    let x = px(a), y = px(b), z = maskOff.map(px)
    var sum = 0, off = 0, n = 0
    for i in stride(from: 0, to: x.count, by: 4) {
        if let z, (0..<3).allSatisfy({ abs(Int(z[i + $0]) - Int(y[i + $0])) <= 10 }) { continue }
        n += 1
        var m = 0
        for c in 0..<3 { let d = abs(Int(x[i + c]) - Int(y[i + c])); sum += d; m = max(m, d) }
        if m > 25 { off += 1 }
    }
    return (Double(sum) / Double(max(1, n) * 3), Double(off) / Double(max(1, n)) * 100)
}

/// Every outfit at rest on Koru, idle, as koru.html?shot=idle&outfit=<id>&px=600; next to the prototype's still when it
/// is in <out>/../proto, with the mean difference per outfit.
@MainActor
func outfitSheet(_ out: String) {
    Koru.frame = 1
    let proto = (out as NSString).deletingLastPathComponent + "/proto"
    var cells: [(CGImage, String)] = [], lines: [String] = []
    let cases: [(String, Outfit)] = wardrobe.map { ($0.rawValue, $0) } + [("auto", Outfit.resolved(selection: .auto, date: DateComponents(calendar: .current, year: 2026, month: 12, day: 24, hour: 12).date!, calendar: .current))]
    var bare: CGImage? = nil
    for (id, o) in cases {
        let e = stillEngine(.idle)
        e.setOutfit(o, animated: false)
        run([e], seconds: 2.2)
        let img = render(width: 600, height: 600, scale: 1, bg: bgShot) { ctx, sz in drawEngine(e, ctx, sz) }
        savePNG(img, "\(out)/\(id).png")
        if o == .none { bare = img }
        if let p = loadPNG("\(proto)/\(id).png") {
            let (m, off) = meanDiff(p, img, w: 600, h: 600)
            let (mo, offo) = o == .none || bare == nil ? (m, off) : meanDiff(p, img, w: 600, h: 600, maskOff: bare)
            let line = String(format: "%-13@ frame mean |diff| %5.2f/255, off by >25 %5.2f %%;  outfit pixels mean |diff| %5.2f/255, off by >25 %5.2f %%",
                              id as NSString, m, off, mo, offo)
            print(line); lines.append(line)
            cells.append((p, "\(id) prototype")); cells.append((img, String(format: "\(id) Swift (mean %.2f)", m)))
        } else {
            cells.append((img, "\(id) Swift"))
        }
    }
    try? lines.joined(separator: "\n").appending("\n").write(toFile: "\(out)/outfit-diff.txt", atomically: true, encoding: .utf8)
    for (i, chunk) in stride(from: 0, to: cells.count, by: 10).enumerated() {
        savePNG(compose(Array(cells[chunk..<min(cells.count, chunk + 10)]), cols: 4, w: 300, h: 300), "\(out)/compare-\(i + 1).png")
    }
}

/// Enter, change and exit films (BotEngine.setOutfit timing), 300 px at frame .82, a frame every 40 ms.
@MainActor
func outfitFilm(_ out: String) {
    Koru.frame = 0.82
    let px: CGFloat = 300, step = 0.04
    var rows: [(CGImage, String)] = []
    for (label, from, to) in [("enter witchHat", Outfit.none, Outfit.witchHat), ("change witchHat > pumpkin", .witchHat, .pumpkin),
                              ("exit pumpkin", .pumpkin, .none), ("enter sunglasses", .none, .sunglasses), ("enter scarf", .none, .scarf),
                              ("enter bow", .none, .bow), ("enter bunnyEars", .none, .bunnyEars)] {
        let e = stillEngine(.idle)
        e.setOutfit(from, animated: false)
        run([e], seconds: 1.0)
        e.setOutfit(to)
        let t0 = CACurrentMediaTime()
        var next = 0
        let n = label.hasPrefix("change") ? 16 : 12
        run([e], seconds: Double(n) * step + 0.05) {
            guard next < n, CACurrentMediaTime() - t0 >= Double(next) * step else { return }
            rows.append((render(width: px, height: px, scale: 2, bg: bgShot) { ctx, sz in drawEngine(e, ctx, sz) },
                         "\(label) \(Int(Double(next) * step * 1000)) ms p=\(String(format: "%.2f", e.outfitPresence))"))
            next += 1
        }
        while rows.count % 8 != 0 { rows.append((render(width: 10, height: 10, scale: 1, bg: bgShot) { _, _ in }, "")) }
    }
    savePNG(compose(rows, cols: 8, w: 200, h: 200, caption: 26), "\(out)/film-outfits.png")
}

/// Per-frame cost at the island size (97 pt @2x, frame .8): bare Koru, the pumpkin and the witch hat, interleaved, sheets warm.
@MainActor
func outfitBench(_ out: String) {
    let W: CGFloat = 58 / 0.6, H = W + 40
    Koru.frame = 0.8
    let cases: [(String, Outfit)] = [("bare", .none), ("pumpkin", .pumpkin), ("witchHat", .witchHat), ("scarf", .scarf), ("santaHat", .santaHat)]
    let engines = cases.map { _, o -> BotEngine in
        let e = BotEngine(); e.particleOverhang = 40; e.t0 = CACurrentMediaTime(); e.setState(.working, force: true); e.setOutfit(o, animated: false); return e
    }
    run(engines, seconds: 2.2)
    for e in engines { _ = render(width: W, height: H, scale: 2, bg: nil) { ctx, sz in drawEngine(e, ctx, sz) } }   // warm the sheets
    var draw = Array(repeating: [Double](), count: cases.count), total = draw
    for _ in 0..<120 {
        for (i, e) in engines.enumerated() {
            e.update(dt: 0.05)
            var d = 0.0
            let a = CACurrentMediaTime()
            _ = render(width: W, height: H, scale: 2, bg: nil) { ctx, sz in
                let b = CACurrentMediaTime(); drawEngine(e, ctx, sz); d = CACurrentMediaTime() - b
            }
            total[i].append((CACurrentMediaTime() - a) * 1000); draw[i].append(d * 1000)
        }
    }
    var lines: [String] = []
    for (i, (name, _)) in cases.enumerated() {
        let d = draw[i].sorted(), t = total[i].sorted()
        let line = String(format: "%-9@ island %.1fx%.1f pt @2x, working, 120 frames: rendered frame (ImageRenderer) median %.2f ms, min %.2f ms; draw calls median %.3f ms, p90 %.3f ms",
                          name as NSString, W, H, t[60], t[0], d[60], d[108])
        print(line); lines.append(line)
    }
    // A swinging lag draws new sheets: the cost of a frame that has to (a new lag step each frame), santa hat, island size.
    let e = engines[4]
    var cold: [Double] = []
    for i in 0..<20 {
        e.physDx = -0.99 + CGFloat(i) * 0.1
        var d = 0.0
        _ = render(width: W, height: H, scale: 2, bg: nil) { ctx, sz in let b = CACurrentMediaTime(); drawEngine(e, ctx, sz); d = CACurrentMediaTime() - b }
        cold.append(d * 1000)
    }
    cold.sort()
    let line = String(format: "santaHat with a new lag every frame (bag sheet redrawn): median %.3f ms, max %.3f ms", cold[10], cold[19])
    print(line); lines.append(line)
    try? lines.joined(separator: "\n").appending("\n").write(toFile: "\(out)/bench-outfits.txt", atomically: true, encoding: .utf8)
}

/// Framing: every outfit at every canvas size the app uses, at rest and at the extremes of head turn, tilt, hop and lag;
/// margins from Koru's reach (alpha) to the canvas edges.
@MainActor
func outfitSizes(_ out: String) {
    let sizes: [(String, CGFloat, CGFloat, CGFloat, Bool)] = [
        ("compact notch", 20 / 0.6, 20 / 0.6 + 40, 40, false), ("island 44", 44 / 0.6, 44 / 0.6 + 40, 40, false),
        ("island 58", 58 / 0.6, 58 / 0.6 + 40, 40, false), ("island 66", 66 / 0.6, 66 / 0.6 + 40, 40, false),
        ("uploading 20", 20 / 0.6, 20 / 0.6, 0, false), ("desktop 120", 120, 120, 0, false), ("recap 200", 200, 200, 0, false),
        ("mini 22 pill", 22 / 0.6, 22 / 0.6, 0, true)]
    var poses: [(String, KoruPose)] = []
    for (name, yaw, tilt, oy) in [("rest", 0.3, 0.0, 0.0), ("look left", -0.62, 0.0, 0.0), ("look right", 0.62, 0.0, 0.0),
                                  ("question tilt", 0.3, 0.26, 0.0), ("approval hop", 0.3, 0.0, -0.2), ("surprised hop", 0.0, 0.0, -0.3)] as [(String, CGFloat, CGFloat, CGFloat)] {
        var p = restPose(.idle, yaw: yaw); p.tilt = tilt; p.oy = oy; p.ear = oy < -0.25 ? -0.35 : 0
        poses.append((name, p))
    }
    var lines: [String] = []
    var worstAll: CGFloat = .greatestFiniteMagnitude
    for (sname, W, H, over, mini) in sizes {
        var worst: CGFloat = .greatestFiniteMagnitude, tag = ""
        for o in wardrobe where o != .none {
            for lag in [-1.0, 0.0, 1.0] as [CGFloat] {
                for (pname, p0) in poses {
                    var p = p0; p.overhang = over; p.mini = mini
                    let L = Koru.outfitLayers(o, presence: 1, physDx: lag, physDy: lag * 0.5)
                    let big = render(width: W * 3, height: H * 3, scale: 2, bg: nil) { ctx, _ in
                        var c = ctx; c.translateBy(x: W, y: H)
                        Koru.draw(c, size: CGSize(width: W, height: H), pose: p, layers: L)
                    }
                    guard let b = alphaBox(big) else { continue }
                    let r = CGRect(x: b.minX / 2 - W, y: b.minY / 2 - H, width: b.width / 2, height: b.height / 2)
                    let m = min(r.minX, r.minY, W - r.maxX, H - r.maxY)
                    if m < worst { worst = m; tag = "\(o.rawValue), \(pname), lag \(lag)" }
                }
            }
        }
        worstAll = min(worstAll, worst)
        let line = String(format: "%-14@ canvas %.1f x %.1f pt: tightest margin %.1f pt at %@%@", sname as NSString, W, H, worst, tag, worst < 0 ? "  CLIPS" : "")
        print(line); lines.append(line)
    }
    try? lines.joined(separator: "\n").appending("\n").write(toFile: "\(out)/sizes-outfits.txt", atomically: true, encoding: .utf8)
}

/// The wardrobe swatches (30 pt @2x) as IslandViewContent draws them, Koru's versions, scaled up 4×.
@MainActor
func outfitIcons(_ out: String) {
    let seasonal = Outfit.seasonal(for: DateComponents(calendar: .current, year: 2026, month: 10, day: 31, hour: 12).date!, calendar: .current)
    var cells: [(CGImage, String)] = []
    for o in Outfit.allCases where o != .none {
        let img = render(width: 30, height: 30, scale: 8, bg: Color(.sRGB, red: 0.13, green: 0.135, blue: 0.15)) { ctx, sz in
            Koru.drawOutfitIcon(context: ctx, size: sz, outfit: o, seasonal: seasonal)
        }
        cells.append((img, o == .auto ? "auto (Oct 31)" : o.rawValue))
    }
    savePNG(compose(cells, cols: 6, w: 200, h: 200), "\(out)/icons.png")
}

@MainActor
func outfitMode(_ mode: String, _ out: String, _ arg: String) {
    switch mode {
    case "hooks": hookTest(out)
    case "sheet": outfitSheet(out)
    case "film": outfitFilm(out)
    case "bench": outfitBench(out)
    case "sizes": outfitSizes(out)
    case "icons": outfitIcons(out)
    default: print("modes: poses compare hooks sheet film bench sizes icons")
    }
}
#endif
