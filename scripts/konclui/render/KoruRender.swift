// KoruRender.swift — renders Koru through BotEngine (CoucouKit sources only) for side-by-side checks with the prototype.
// Build and run: bash scripts/konclui/render/render.sh <mode> [out dir]
//   grid   the ten states at 1254 px, frame 1, scaled to 400 px in a 5 × 2 sheet (as koru.html?grid=1)
//   greet  the greeting filmstrip (as koru.html?film=greet&state=idle&step=66&n=30&px=300, frame .82)
//   small  the ten states at the island size (96.7 pt, 2×, frame .8) on black
//   bench  per-frame cost at the island size, Koru and Mochi frames interleaved: median and min of 120 frames each
//   sizes  framing: every canvas size the app uses, through states, greet, emotes and squashes; margins to the edges
//   calib  GraphicsContext shadow radius against a canvas shadowBlur
//   greeting  the app's greeting view (GreetingCanvasView.swift, now drawing Koru) at 12 moments
//   shot   one state at 1254 px (as koru.html?shot=<state>)
// Real time: tweens and badges run on CACurrentMediaTime and the main queue, as in the app.

import SwiftUI
import AppKit
import ImageIO
import UniformTypeIdentifiers

// MARK: - Stand-ins for app-only pieces BotEngine calls

@MainActor
final class SoundEngine {
    static let shared = SoundEngine()
    func play(_ name: String) {}
}

extension Notification.Name {
    static let botDizzy = Notification.Name("notchBuddy.botDizzy")
}

// MARK: - Helpers

let order: [(String, BotState)] = [("01-idle", .idle), ("02-working", .working), ("03-thinking", .thinking), ("04-searching", .searching),
                                   ("05-approval", .approval), ("06-question", .question), ("07-error", .error), ("08-finished", .finished),
                                   ("09-sleeping", .sleeping), ("10-dizzy", .dizzy)]
// koru.html SHOT_LOOK and SHOT_T
let shotLook: [BotState: CGPoint] = [.idle: CGPoint(x: 1, y: -0.2), .working: CGPoint(x: 0.7, y: 0), .approval: CGPoint(x: 0.75, y: -0.05),
                                     .error: CGPoint(x: 0.4, y: 0), .finished: CGPoint(x: 0.55, y: 0), .dizzy: CGPoint(x: 0.55, y: 0)]
let shotT: [BotState: Double] = [.searching: 0.82]

@MainActor
func drawEngine(_ e: BotEngine, _ ctx: GraphicsContext, _ size: CGSize) {
    e.drawHandsBehind(context: ctx, size: size)
    e.drawOutfitBehind(context: ctx, size: size)
    e.draw(context: ctx, size: size)
    e.drawOutfitFront(context: ctx, size: size)
    e.drawHandsAndExtras(context: ctx, size: size)
}

@MainActor
func render(width: CGFloat, height: CGFloat, scale: CGFloat, bg: Color?, _ body: @escaping (GraphicsContext, CGSize) -> Void) -> CGImage {
    let view = Canvas { ctx, sz in
        if let bg { ctx.fill(Path(CGRect(origin: .zero, size: sz)), with: .color(bg)) }
        body(ctx, sz)
    }
    .frame(width: width, height: height)
    let r = ImageRenderer(content: view)
    r.scale = scale
    return r.cgImage!
}

func savePNG(_ img: CGImage, _ path: String) {
    let url = URL(fileURLWithPath: path) as CFURL
    let d = CGImageDestinationCreateWithURL(url, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(d, img, nil)
    CGImageDestinationFinalize(d)
    print("wrote \(path) \(img.width)x\(img.height)")
}

/// A sheet of cells: images scaled into w × h cells with a caption strip, cols per row.
func compose(_ cells: [(CGImage, String)], cols: Int, w: Int, h: Int, caption: Int = 30) -> CGImage {
    let rows = (cells.count + cols - 1) / cols
    let W = cols * w, H = rows * (h + caption)
    let g = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    g.setFillColor(CGColor(srgbRed: 16 / 255, green: 17 / 255, blue: 21 / 255, alpha: 1)); g.fill(CGRect(x: 0, y: 0, width: W, height: H))
    g.interpolationQuality = .high
    let ns = NSGraphicsContext(cgContext: g, flipped: false)
    for (i, (img, label)) in cells.enumerated() {
        let cx = (i % cols) * w, top = (i / cols) * (h + caption)
        let y = H - top - h
        g.setFillColor(CGColor(srgbRed: 20 / 255, green: 21 / 255, blue: 24 / 255, alpha: 1))
        g.fill(CGRect(x: cx, y: y - caption, width: w, height: caption))
        let k = min(CGFloat(w) / CGFloat(img.width), CGFloat(h) / CGFloat(img.height))   // keep the aspect
        let iw = CGFloat(img.width) * k, ih = CGFloat(img.height) * k
        g.draw(img, in: CGRect(x: CGFloat(cx) + (CGFloat(w) - iw) / 2, y: CGFloat(y) + (CGFloat(h) - ih) / 2, width: iw, height: ih))
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = ns
        (label as NSString).draw(at: NSPoint(x: CGFloat(cx + 10), y: CGFloat(y - caption + 10)),
                                 withAttributes: [.font: NSFont.systemFont(ofSize: 10), .foregroundColor: NSColor(white: 0.86, alpha: 1)])
        NSGraphicsContext.restoreGraphicsState()
    }
    return g.makeImage()!
}

/// Runs the engines in real time: one update(dt: 0.05) per 1/60 s, as MochiFrameClock in the app, the main queue served between.
@MainActor
func run(_ engines: [BotEngine], seconds: Double, noBlink: Bool = true, each: (() -> Void)? = nil) {
    let start = CACurrentMediaTime()
    var n = 0
    while CACurrentMediaTime() - start < seconds {
        n += 1
        let due = start + Double(n) / 60
        RunLoop.main.run(until: Date(timeIntervalSinceNow: max(0, due - CACurrentMediaTime())))
        for e in engines {
            if noBlink { e.nextBlink = .greatestFiniteMagnitude }   // stills never catch a blink, as the prototype's captures
            e.update(dt: 0.05)
        }
        each?()
    }
}

@MainActor
func stillEngine(_ s: BotState) -> BotEngine {
    let e = BotEngine()
    let l = shotLook[s] ?? .zero
    e.lookX = l.x; e.lookY = l.y
    e.t0 = CACurrentMediaTime()
    e.setState(s, force: true)
    return e
}

let bgShot = Color(.sRGB, red: 16 / 255, green: 17 / 255, blue: 21 / 255)

// MARK: - Modes

@MainActor
func grid(_ out: String, px: CGFloat, frame: CGFloat, scale: CGFloat, name: String, cell: Int) {
    Koru.frame = frame
    var cells: [(CGImage, String)] = []
    // One state at a time, each still taken 2.2 s (+ SHOT_T) after its state is set, right after its last update.
    for (label, s) in order {
        let e = stillEngine(s)
        run([e], seconds: 2.2 + (shotT[s] ?? 0))
        cells.append((render(width: px, height: px, scale: scale, bg: bgShot) { ctx, sz in drawEngine(e, ctx, sz) }, label))
    }
    savePNG(compose(cells, cols: 5, w: cell, h: cell), "\(out)/\(name).png")
}

/// One state at 1254 px, as koru.html?shot=<state>.
@MainActor
func shot(_ out: String, _ name: String) {
    Koru.frame = 1
    let s = BotState(rawValue: name) ?? .idle
    let e = stillEngine(s)
    run([e], seconds: 2.2 + (shotT[s] ?? 0))
    savePNG(render(width: 1254, height: 1254, scale: 1, bg: bgShot) { ctx, sz in drawEngine(e, ctx, sz) }, "\(out)/shot-\(name).png")
}

@MainActor
func greet(_ out: String) {
    Koru.frame = 0.82
    let px: CGFloat = 300, step = 0.066, n = 30
    let e = BotEngine()
    e.lookX = 1; e.lookY = -0.2
    e.t0 = CACurrentMediaTime()
    e.setState(.idle, force: true)
    run([e], seconds: 2.5)
    e.greet()
    let g0 = CACurrentMediaTime()
    var frames: [(CGImage, String)] = []
    var next = 0
    run([e], seconds: Double(n) * step + 0.05, noBlink: false) {
        guard next < n, CACurrentMediaTime() - g0 >= Double(next) * step else { return }
        frames.append((render(width: px * 2, height: px * 2, scale: 1, bg: bgShot) { ctx, sz in drawEngine(e, ctx, sz) }, "\(Int(Double(next) * step * 1000)) ms"))
        next += 1
    }
    savePNG(compose(frames, cols: 6, w: Int(px), h: Int(px)), "\(out)/greet-film.png")
}

@MainActor
func bench(_ out: String) {
    let W: CGFloat = 58 / 0.6, H = W + 40
    Koru.frame = 0.8
    // Koru and Mochi frames interleave, so load on the machine weighs on both alike.
    func engine(_ koru: Bool) -> BotEngine {
        Koru.enabled = koru
        let e = BotEngine()
        e.particleOverhang = 40
        e.t0 = CACurrentMediaTime()
        e.setState(.working, force: true)
        return e
    }
    let ek = engine(true), em = engine(false)
    run([ek, em], seconds: 2.2)
    var total: [Bool: [Double]] = [true: [], false: []], draw: [Bool: [Double]] = [true: [], false: []], empty: [Double] = []
    for _ in 0..<120 {
        for koru in [true, false] {
            Koru.enabled = koru
            let e = koru ? ek : em
            e.update(dt: 0.05)
            var d = 0.0
            let a = CACurrentMediaTime()
            _ = render(width: W, height: H, scale: 2, bg: nil) { ctx, sz in
                let b = CACurrentMediaTime()
                drawEngine(e, ctx, sz)
                d = CACurrentMediaTime() - b
            }
            total[koru]!.append((CACurrentMediaTime() - a) * 1000); draw[koru]!.append(d * 1000)
        }
        // An empty canvas through the same renderer: the share of a frame that is ImageRenderer's own.
        let a = CACurrentMediaTime()
        _ = render(width: W, height: H, scale: 2, bg: nil) { _, _ in }
        empty.append((CACurrentMediaTime() - a) * 1000)
    }
    Koru.enabled = true
    empty.sort()
    var lines: [String] = []
    for koru in [true, false] {
        let t = total[koru]!.sorted(), d = draw[koru]!.sorted()
        let line = String(format: "%@ island %.1fx%.1f pt @2x, working, 120 frames: rendered frame (ImageRenderer) median %.2f ms, min %.2f ms; draw calls median %.3f ms, min %.3f ms",
                          koru ? "Koru " : "Mochi", W, H, t[60], t[0], d[60], d[0])
        print(line); lines.append(line)
    }
    let line = String(format: "empty canvas through ImageRenderer: median %.2f ms, min %.2f ms", empty[60], empty[0])
    print(line); lines.append(line)
    try? lines.joined(separator: "\n").appending("\n").write(toFile: "\(out)/bench.txt", atomically: true, encoding: .utf8)
}

/// Alpha bounding box of an image (pixels with alpha > 8).
func alphaBox(_ img: CGImage) -> CGRect? {
    let W = img.width, H = img.height
    let g = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: W * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    g.draw(img, in: CGRect(x: 0, y: 0, width: W, height: H))
    let p = g.data!.assumingMemoryBound(to: UInt8.self)
    var x0 = W, y0 = H, x1 = -1, y1 = -1
    for y in 0..<H { for x in 0..<W where p[(y * W + x) * 4 + 3] > 8 { x0 = min(x0, x); x1 = max(x1, x); y0 = min(y0, y); y1 = max(y1, y) } }
    return x1 < 0 ? nil : CGRect(x: x0, y: y0, width: x1 - x0 + 1, height: y1 - y0 + 1)
}

@MainActor
func sizes(_ out: String) {
    Koru.frame = 0.8
    // (name, canvas width, height, overhang, mini)
    let cases: [(String, CGFloat, CGFloat, CGFloat, Bool)] = [
        ("compact notch", 20 / 0.6, 20 / 0.6 + 40, 40, false),
        ("island 44 (prompt)", 44 / 0.6, 44 / 0.6 + 40, 40, false),
        ("island 58 (overview)", 58 / 0.6, 58 / 0.6 + 40, 40, false),
        ("island 66 (confused)", 66 / 0.6, 66 / 0.6 + 40, 40, false),
        ("uploading 20", 20 / 0.6, 20 / 0.6, 0, false),
        ("desktop 120", 120, 120, 0, false),
        ("recap 200", 200, 200, 0, false),
        ("mini 22 pill", 22 / 0.6, 22 / 0.6, 0, true),
        ("mini 16 column", 16 / 0.6, 16 / 0.6, 0, true),
        ("mini 12 grid", 12 / 0.6, 12 / 0.6, 0, true),
    ]
    var lines: [String] = []
    var strips: [(CGImage, String)] = []
    for (name, W, H, over, mini) in cases {
        let e = BotEngine()
        e.isMini = mini
        if mini { e.bodyColor = cgColorFromHex("#F5F6F8"); e.setPermanentEmote(.happy) }
        e.particleOverhang = over
        e.t0 = CACurrentMediaTime()
        e.setState(.idle, force: true)
        var union: CGRect? = nil
        var worst = ""
        var worstM: CGFloat = .greatestFiniteMagnitude
        var shot: CGImage? = nil
        func sample(_ tag: String) {
            // The canvas edge is what clips: draw into a canvas three times larger and measure against the real one.
            let big = render(width: W * 3, height: H * 3, scale: 2, bg: nil) { ctx, _ in
                var c = ctx
                c.translateBy(x: W, y: H)
                // Particles and glows are allowed to leave; measure Koru herself: no particles, badge drawn.
                let saved = e.particles
                e.particles = []
                drawEngine(e, c, CGSize(width: W, height: H))
                e.particles = saved
            }
            guard let b = alphaBox(big) else { return }
            let r = CGRect(x: b.minX / 2 - W, y: b.minY / 2 - H, width: b.width / 2, height: b.height / 2)
            union = union.map { $0.union(r) } ?? r
            let m = min(r.minX, r.minY, W - r.maxX, H - r.maxY)
            if m < worstM { worstM = m; worst = tag; shot = render(width: W, height: H, scale: 4, bg: .black) { ctx, sz in drawEngine(e, ctx, sz) } }
        }
        let states: [BotState] = mini ? [.idle, .working, .approval, .finished, .dizzy, .sleeping]
            : [.idle, .working, .thinking, .searching, .approval, .question, .error, .finished, .sleeping, .dizzy, .ratelimit]
        for s in states {
            e.setState(s)
            var k = 0
            run([e], seconds: 1.6, noBlink: false) { k += 1; if k % 4 == 0 { sample("\(s)") } }
        }
        if !mini {
            e.setState(.idle)
            run([e], seconds: 0.5)
            for (lx, label) in [(1.0, "greet looking right"), (-1.0, "greet looking left")] as [(CGFloat, String)] {
                e.lookX = lx
                run([e], seconds: 0.6)
                e.greet()
                var k = 0
                run([e], seconds: 2.0, noBlink: false) { k += 1; if k % 2 == 0 { sample(label) } }
            }
            e.lookX = 0
            for em in [BotEmote.surprised, .proud, .love, .yawn] {
                e.triggerEmote(em)
                var k = 0
                run([e], seconds: 1.4, noBlink: false) { k += 1; if k % 3 == 0 { sample("emote \(em)") } }
            }
            e.squash()
            var k = 0
            run([e], seconds: 0.5) { k += 1; sample("squash") }
            e.enterListening()
            run([e], seconds: 0.8) { k += 1; if k % 3 == 0 { sample("listening (cupped wing)") } }
            e.exitListening(hadCommand: true)
            run([e], seconds: 0.6)
        }
        let u = union ?? .zero
        let line = String(format: "%@: canvas %.1f x %.1f pt; Koru's reach x %.1f…%.1f, y %.1f…%.1f; margins L %.1f T %.1f R %.1f B %.1f pt; tightest at %@ (%.1f pt)%@",
                          name, W, H, u.minX, u.maxX, u.minY, u.maxY, u.minX, u.minY, W - u.maxX, H - u.maxY, worst, worstM,
                          worstM < 0 ? "  CLIPS" : "")
        print(line); lines.append(line)
        if let shot { strips.append((shot, "\(name): \(worst)")) }
    }
    try? lines.joined(separator: "\n").appending("\n").write(toFile: "\(out)/sizes.txt", atomically: true, encoding: .utf8)
    savePNG(compose(strips, cols: 5, w: 300, h: 300), "\(out)/sizes-tightest.png")
}

@MainActor
func calib() {
    // A 40 px square, shadow only, radius r: fit the gaussian σ from the falloff outside its edge.
    for r in [10.0, 20.0] as [CGFloat] {
        let img = render(width: 200, height: 200, scale: 1, bg: nil) { ctx, _ in
            var c = ctx
            c.addFilter(.shadow(color: .black, radius: r, x: 0, y: 0, options: .shadowOnly))
            c.fill(Path(CGRect(x: 80, y: 80, width: 40, height: 40)), with: .color(.black))
        }
        let g = CGContext(data: nil, width: 200, height: 200, bitsPerComponent: 8, bytesPerRow: 800, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        g.draw(img, in: CGRect(x: 0, y: 0, width: 200, height: 200))
        let p = g.data!.assumingMemoryBound(to: UInt8.self)
        let row = (0..<200).map { Int(p[(100 * 200 + $0) * 4 + 3]) }
        let centre = Double(row[100])
        // value at distance d outside the edge, relative to the centre: ≈ ½ erfc(d / (σ√2)) / erf(20/(σ√2))
        var best = (0.0, 1e9)
        for s10 in 5...400 {
            let s = Double(s10) / 10
            var err = 0.0
            for d in stride(from: 2, through: 30, by: 2) {
                let model = 0.5 * erfc(Double(d) / (s * 2.0.squareRoot())) / erf(20 / (s * 2.0.squareRoot()))
                err += pow(Double(row[120 + d]) / centre - model, 2)
            }
            if err < best.1 { best = (s, err) }
        }
        print(String(format: "GraphicsContext shadow radius %.0f: sigma %.1f (canvas blur %.1f) -> shadowK = %.2f", r, best.0, best.0 * 2, r / (best.0 * 2)))
    }
}

@main
struct KoruRenderMain {
    @MainActor static func main() {
        let args = CommandLine.arguments
        let mode = args.count > 1 ? args[1] : "grid"
        let out = args.count > 2 ? args[2] : FileManager.default.currentDirectoryPath
        try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)
        switch mode {
        case "grid": grid(out, px: 1254, frame: 1, scale: 1, name: "grid", cell: 400)
        case "shot": shot(out, args.count > 3 ? args[3] : "idle")
        case "small": grid(out, px: 58 / 0.6, frame: 0.8, scale: 2, name: "grid-island", cell: 194)
        case "greet": greet(out)
        case "bench": bench(out)
        case "sizes": sizes(out)
        case "calib": calib()
        case "greeting": greetingFilm(out)
        default: print("modes: grid small greet bench sizes calib")
        }
    }
}
