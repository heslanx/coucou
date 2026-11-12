// SceneRender.swift — K6's scenes, drawn through BotEngine and CoucouKit's Koru files, next to the prototype's captures.
// Build and run: bash scripts/konclui/render/k6/scenes.sh <mode> [out dir]
//   minis    mini Korus: stills (as koru.html?shot=<state>&mini=1&agent=claude&px=300), the happy hop and love films
//            (as ?film=perm&state=idle&mini=1&perm=happy|love), and the framing of the hop at the app's mini sizes,
//            Mochi's constants against Koru's
//   desktop  the desktop panel (120 pt): how much of Koru Mochi's hit circle and Koru's ellipse cover, and what they add
//   flowhub  a FlowHub hero strip (340 × 128) with its floor shadows, Mochi's placement and Koru's
//   gulp     BotEngine.gulp() on Koru (as koru.html?film=gulp&state=idle, without the file: the island draws none), and the
//            suck of the upload scene on its own clock (as ?film=suck&state=idle), framed as the prototype's films
//   mood     Koru with the Mac's mood (busy, hot, busy+hot, tired, asleep, full) as koru.html?shot=idle&mood=…, before
//            and after K6, and a busy + hot film
//   bench    per-frame cost of the hooks (bare, mood, gulp) at the island size and of the upload scene's Koru
//   upload   the app's upload scene (UploadSequenceEngine + KoruUploadScene): hover, lock, drop, suck, chew, shrink onto the
//            bar, ride it, grow back at the choice; strips of the island and crops round Koru
// Helpers (render, run, compose, savePNG, alphaBox, drawEngine, bgShot) come from KoruRender.swift.

import SwiftUI
import AppKit

// MARK: - Shared

/// Pixels of an image, RGBA premultiplied, row 0 at the top.
func pixels(_ img: CGImage) -> (w: Int, h: Int, p: [UInt8]) {
    let W = img.width, H = img.height
    var buf = [UInt8](repeating: 0, count: W * H * 4)
    buf.withUnsafeMutableBytes { raw in
        let g = CGContext(data: raw.baseAddress, width: W, height: H, bitsPerComponent: 8, bytesPerRow: W * 4,
                          space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        g.draw(img, in: CGRect(x: 0, y: 0, width: W, height: H))
    }
    return (W, H, buf)
}

func writeLines(_ lines: [String], _ path: String) {
    try? lines.joined(separator: "\n").appending("\n").write(toFile: path, atomically: true, encoding: .utf8)
    print("wrote \(path)")
}

/// A film of an engine: frames every `step` s after `start()` runs, at px × px (scale 1), on the shots' background.
@MainActor
func film(_ e: BotEngine, px: CGFloat, step: Double, n: Int, start: () -> Void, draw: ((GraphicsContext, CGSize) -> Void)? = nil) -> [(CGImage, String)] {
    start()
    let g0 = CACurrentMediaTime()
    var frames: [(CGImage, String)] = []
    var next = 0
    run([e], seconds: Double(n) * step + 0.05, noBlink: true) {
        guard next < n, CACurrentMediaTime() - g0 >= Double(next) * step else { return }
        frames.append((render(width: px, height: px, scale: 1, bg: bgShot) { ctx, sz in
            if let draw { draw(ctx, sz) } else { drawEngine(e, ctx, sz) }
        }, "\(Int((Double(next) * step * 1000).rounded())) ms"))
        next += 1
    }
    return frames
}

@MainActor
func miniEngine(_ hex: String, state: BotState = .idle) -> BotEngine {
    let e = BotEngine()
    e.isMini = true
    e.bodyColor = cgColorFromHex(hex)
    e.lookX = 1; e.lookY = -0.2
    e.t0 = CACurrentMediaTime()
    e.setState(state, force: true)
    return e
}

// MARK: - Minis

@MainActor
func minis(_ out: String) {
    var lines: [String] = []
    // Stills, frame 1 at 300 px, as the prototype's ?shot=…&mini=1&agent=claude&px=300.
    Koru.frame = 1
    for s in [BotState.idle, .working] {
        let e = miniEngine("#F5F6F8", state: s)
        e.miniNextBehavior = .greatestFiniteMagnitude
        run([e], seconds: 2.2)
        savePNG(render(width: 300, height: 300, scale: 1, bg: bgShot) { ctx, sz in drawEngine(e, ctx, sz) }, "\(out)/mini-\(s).png")
    }
    // Films, frame .82 at 600 px shown at 300, as ?film=perm&state=idle&mini=1&perm=…&px=300.
    Koru.frame = 0.82
    for (emote, hex, step, n) in [(BotEmote.happy, "#F5F6F8", 0.05, 18), (.love, "#2DD4BF", 0.1, 18)] {
        for koruLoop in [true, false] {
            let e = miniEngine(hex)
            e.setPermanentEmote(emote)
            e.miniNextBehavior = .greatestFiniteMagnitude
            run([e], seconds: 2.5)
            let frames = film(e, px: 600, step: step, n: n) {
                // Mochi's constants on Koru: the loop with Koru's routing switched off for this one call.
                if !koruLoop { Koru.enabled = false }
                e.doMiniBehaviorLoop()
                Koru.enabled = true
                e.miniNextBehavior = .greatestFiniteMagnitude
            }
            savePNG(compose(frames, cols: 6, w: 300, h: 300), "\(out)/mini-\(emote)-film\(koruLoop ? "" : "-mochi-constants").png")
        }
    }
    // Framing at the app's mini canvases (frame .8): the reach of the hop and squash (happy) and of the hearts (love).
    Koru.frame = 0.8
    for (name, W) in [("mini 22 pill", 22 / 0.6), ("mini 16 column", 16 / 0.6), ("mini 12 grid", 12 / 0.6), ("prototype 48 px, frame 1", 48)] as [(String, CGFloat)] {
        Koru.frame = name.hasPrefix("prototype") ? 1 : 0.8
        for koruLoop in [true, false] {
            let e = miniEngine("#F5F6F8")
            e.setPermanentEmote(.happy)
            e.miniNextBehavior = .greatestFiniteMagnitude
            run([e], seconds: 1)
            var worst = CGFloat.greatestFiniteMagnitude
            for _ in 0..<3 {
                if !koruLoop { Koru.enabled = false }
                e.doMiniBehaviorLoop()
                Koru.enabled = true
                e.miniNextBehavior = .greatestFiniteMagnitude
                var k = 0
                run([e], seconds: 0.75) {
                    k += 1
                    guard k % 2 == 0 else { return }
                    let big = render(width: W * 3, height: W * 3, scale: 2, bg: nil) { ctx, _ in
                        var c = ctx
                        c.translateBy(x: W, y: W)
                        drawEngine(e, c, CGSize(width: W, height: W))
                    }
                    guard let b = alphaBox(big) else { return }
                    let r = CGRect(x: b.minX / 2 - W, y: b.minY / 2 - W, width: b.width / 2, height: b.height / 2)
                    worst = min(worst, r.minX, r.minY, W - r.maxX, W - r.maxY)
                }
            }
            let line = String(format: "happy hop, %@ constants, %@ (%.1f pt canvas): tightest margin %.2f pt%@",
                              koruLoop ? "Koru's " : "Mochi's", name, W, worst, worst < 0 ? "  CLIPS" : "")
            print(line); lines.append(line)
        }
    }
    Koru.frame = 0.8
    writeLines(lines, "\(out)/minis-framing.txt")
}

// MARK: - Desktop

/// Mochi's hit circle and Koru's ellipse against Koru's opaque pixels in the 120 pt desktop panel, over several states.
@MainActor
func desktop(_ out: String) {
    Koru.frame = 0.8
    let s: CGFloat = 120, k: CGFloat = 4
    var lines: [String] = []
    var cells: [(CGImage, String)] = []
    func mochiHit(_ p: CGPoint) -> Bool { hypot(p.x - s / 2, p.y - s / 2) <= s * 0.24 }
    func koruHit(_ p: CGPoint) -> Bool { KoruScenes.isOverBody(localPoint: p, panelSize: s) }
    for st in [BotState.idle, .working, .approval, .sleeping] {
        let e = BotEngine()
        e.t0 = CACurrentMediaTime()
        e.setState(st, force: true)
        run([e], seconds: 2.2)
        let img = render(width: s, height: s, scale: k, bg: nil) { ctx, sz in
            var c = ctx
            e.particles = []
            c.opacity = 1
            e.draw(context: c, size: sz)   // the body only: no badge or particles (they are not hit)
        }
        let (W, H, p) = pixels(img)
        var koru = 0, inM = 0, inK = 0, mOut = 0, kOut = 0, mArea = 0, kArea = 0
        for y in 0..<H { for x in 0..<W {
            // AppKit y-up local point of this pixel's centre
            let pt = CGPoint(x: (CGFloat(x) + 0.5) / k, y: s - (CGFloat(y) + 0.5) / k)
            let opaque = p[(y * W + x) * 4 + 3] > 128
            let m = mochiHit(pt), q = koruHit(pt)
            if opaque { koru += 1; if m { inM += 1 }; if q { inK += 1 } }
            if m { mArea += 1; if !opaque { mOut += 1 } }
            if q { kArea += 1; if !opaque { kOut += 1 } }
        } }
        let line = String(format: "%@: Koru covers %d px²(@%.0fx); Mochi's circle hits %.1f %% of her, %.1f %% of the circle is off her; Koru's ellipse hits %.1f %%, %.1f %% off her",
                          "\(st)", koru, k, 100 * Double(inM) / Double(koru), 100 * Double(mOut) / Double(mArea),
                          100 * Double(inK) / Double(koru), 100 * Double(kOut) / Double(kArea))
        print(line); lines.append(line)
        // The two areas over her: Mochi's circle in red, Koru's ellipse in green.
        cells.append((render(width: s, height: s, scale: k, bg: bgShot) { ctx, sz in
            e.draw(context: ctx, size: sz)
            ctx.stroke(Path(ellipseIn: CGRect(x: s / 2 - s * 0.24, y: s / 2 - s * 0.24, width: s * 0.48, height: s * 0.48)),
                       with: .color(.red), lineWidth: 1)
            var q = Path()
            for i in 0...180 {   // KoruScenes.isOverBody's boundary, sampled
                let a = CGFloat(i) / 180 * 2 * .pi
                var lo: CGFloat = 0, hi: CGFloat = s
                for _ in 0..<30 { let m = (lo + hi) / 2; if koruHit(CGPoint(x: s / 2 + cos(a) * m, y: s / 2 + sin(a) * m)) { lo = m } else { hi = m } }
                let pt = CGPoint(x: s / 2 + cos(a) * lo, y: s / 2 - sin(a) * lo)   // y down for drawing
                if i == 0 { q.move(to: pt) } else { q.addLine(to: pt) }
            }
            ctx.stroke(q, with: .color(.green), lineWidth: 1)
        }, "\(st): red Mochi's circle, green Koru's ellipse"))
    }
    writeLines(lines, "\(out)/desktop-hit.txt")
    savePNG(compose(cells, cols: 4, w: 480, h: 480), "\(out)/desktop-hit.png")
}

// MARK: - FlowHub

/// HubMochiTroupe.draw for the Insights hero (340 × 128): Mochi's floor shadow under Koru, then Koru's.
@MainActor
func flowhub(_ out: String) {
    Koru.frame = 0.8
    let size = CGSize(width: 340, height: 128)
    let cast: [(String, CGFloat, CGFloat)] = [("#F7B32B", 62, 0.3), ("#34D399", 48, 0.75), ("#F5F6F8", 40, 1)]
    let engines = cast.map { c -> BotEngine in
        let e = miniEngine(c.0)
        e.miniNextBehavior = .greatestFiniteMagnitude
        return e
    }
    run(engines, seconds: 2.2)
    var cells: [(CGImage, String)] = []
    for (koru, label) in [(false, "Mochi's floor shadow (as in main)"), (true, "Koru's floor shadow (KoruScenes.floorShadow)")] {
        cells.append((render(width: size.width, height: size.height, scale: 3, bg: Color(.sRGB, red: 0.13, green: 0.2, blue: 0.17)) { ctx, _ in
            for (i, c) in cast.enumerated().sorted(by: { $0.element.1 < $1.element.1 }) {
                let w = c.1, cx = w / 2 + c.2 * (size.width - w)
                let top = size.height - w * 0.92
                let shadow = koru ? KoruScenes.floorShadow(centreX: cx, canvasTop: top, width: w)
                                  : CGRect(x: cx - w * 0.26, y: size.height - w * 0.12, width: w * 0.52, height: w * 0.09)
                ctx.fill(Path(ellipseIn: shadow), with: .color(.black.opacity(0.28)))
                var e = ctx
                e.translateBy(x: cx - w / 2, y: top)
                engines[i].draw(context: e, size: CGSize(width: w, height: w))
            }
        }, label))
    }
    savePNG(compose(cells, cols: 1, w: 1020, h: 384), "\(out)/flowhub-floor.png")
}


// MARK: - Gulp

/// The prototype's file (UploadCanvasView's drawDoc), drawn centred, docWidth wide, its shadow in proportion.
@MainActor
func genericDoc(_ docWidth: CGFloat) -> KoruGulp.DocDrawer {
    { c, hsc in
        let u = docWidth / 34, w = docWidth, h = 42 * u * hsc, x0 = -w / 2, y0 = -h / 2, f = 8 * u * min(1, hsc), r = 2 * u
        var p = Path()
        p.move(to: CGPoint(x: x0 + r, y: y0)); p.addLine(to: CGPoint(x: x0 + w - f, y: y0)); p.addLine(to: CGPoint(x: x0 + w, y: y0 + f))
        p.addLine(to: CGPoint(x: x0 + w, y: y0 + h - r)); p.addQuadCurve(to: CGPoint(x: x0 + w - r, y: y0 + h), control: CGPoint(x: x0 + w, y: y0 + h))
        p.addLine(to: CGPoint(x: x0 + r, y: y0 + h)); p.addQuadCurve(to: CGPoint(x: x0, y: y0 + h - r), control: CGPoint(x: x0, y: y0 + h))
        p.addLine(to: CGPoint(x: x0, y: y0 + r)); p.addQuadCurve(to: CGPoint(x: x0 + r, y: y0), control: CGPoint(x: x0, y: y0))
        p.closeSubpath()
        var b = c
        b.addFilter(.shadow(color: .black.opacity(0.45), radius: 8 * u * Koru.shadowK, x: 0, y: 3 * u))
        b.fill(p, with: .linearGradient(Gradient(colors: [KoruRGB(hex: "#FBFBFC").color(), KoruRGB(hex: "#E4E5EA").color()]),
                                        startPoint: CGPoint(x: x0, y: y0), endPoint: CGPoint(x: x0 + w, y: y0 + h)))
        var fold = Path()
        fold.move(to: CGPoint(x: x0 + w - f, y: y0)); fold.addLine(to: CGPoint(x: x0 + w - f, y: y0 + f)); fold.addLine(to: CGPoint(x: x0 + w, y: y0 + f))
        c.fill(fold, with: .color(KoruRGB(hex: "#D5D6DB").color()))
        c.fill(Path(roundedRect: CGRect(x: x0 + w * 0.18, y: y0 + h * 0.58, width: w * 0.64, height: h * 0.16), cornerRadius: 2 * u),
               with: .color(KoruRGB(hex: "#3B82F5").color()))
    }
}

func seg(_ t: Double, _ a: Double, _ b: Double) -> Double { max(0, min(1, (t - a) / (b - a))) }
func lerpD(_ a: Double, _ b: Double, _ k: Double) -> Double { a + (b - a) * k }

/// gulp.js squeeze(t): the suck's [sx, sy] on its own clock (UploadSequenceEngine's t_ref).
func suckSqueeze(_ t: Double) -> (Double, Double) {
    let drop = 1.95, suckIn = 2.03, suckOut = 2.33, chew = 2.60, chewEnd = 2.88
    if t < drop { return (1, 1) }
    if t < suckIn { let k = usEOut(seg(t, drop, suckIn)); return (lerpD(1, 1.06, k), lerpD(1, 0.92, k)) }
    if t < suckOut { let k = usEInOut(seg(t, suckIn, suckOut)); return (lerpD(1.06, 0.97, k), lerpD(0.92, 1.06, k)) }
    let t1 = suckOut + 0.07, t2 = suckOut + 0.2
    if t <= t1 { let k = usEOut(seg(t, suckOut, t1)); return (lerpD(0.97, 1.14, k), lerpD(1.06, 0.82, k)) }
    if t <= t2 { let k = usEOut(seg(t, t1, t2)); return (lerpD(1.14, 0.95, k), lerpD(0.82, 1.1, k)) }
    if t < chew { let k = usEInOut(seg(t, t2, chew)); return (lerpD(0.95, 1, k), lerpD(1.1, 1, k)) }
    if t < chewEnd { let c = sin(.pi * (t - chew).truncatingRemainder(dividingBy: 0.14) / 0.14); return (1 + 0.03 * c, 1 - 0.05 * c) }
    return (1, 1)
}

@MainActor
func gulp(_ out: String) {
    Koru.frame = 0.82
    let px: CGFloat = 600, step = 0.066, n = 30
    // BotEngine.gulp(): the beak opens to the slot and chews (no file in the island).
    do {
        let e = stillEngine(.idle)
        run([e], seconds: 2.5)
        let frames = film(e, px: px, step: step, n: n, start: { e.gulp() })   // the app's path: koruLayers() has the gulp's hooks
        savePNG(compose(frames, cols: 6, w: 300, h: 300), "\(out)/gulp-film.png")
    }
    // The suck on its own clock, as gulp.js suck(): slot spring to OPEN, MAX from the drop, the shut curve; squeeze, chews,
    // cup eyes following the file, happy ones to 2.98 s; the file from where it waits (DOC.rest) into the beak.
    do {
        let e = stillEngine(.idle)
        run([e], seconds: 2.5)
        var h: CGFloat = 0, v: CGFloat = 0, lastT = 1.55
        let W = 2 * CGFloat.pi / 0.25, Z: CGFloat = 0.6
        let g0 = CACurrentMediaTime()
        let frames = film(e, px: px, step: step, n: n, start: {}) { ctx, sz in
            let t = 1.55 + (CACurrentMediaTime() - g0)
            // the slot (gulp.js update)
            if t >= 2.33 { h = 0.5 * CGFloat(1 - usEIn(seg(t, 2.33, 2.42))); v = 0 } else {
                let to: CGFloat = t < 1.95 ? 0.42 : 0.5, dt = t - lastT
                let k = max(1, Int((dt * 240).rounded(.up)))
                for _ in 0..<k { v += (W * W * (to - h) - 2 * Z * W * v) * CGFloat(dt / Double(k)); h = max(0, h + v * CGFloat(dt / Double(k))) }
            }
            lastT = t
            var p = e.koruPose(size: sz)
            let (sx, sy) = suckSqueeze(t)
            p.sx *= sx; p.sy *= sy
            let chewing = t >= 2.60 && t < 2.88
            let o = KoruGulp.step(max(h, chewing ? KoruGulp.bite * KoruGulp.chewing(t - 2.60) : 0))
            var L = e.koruLayers() + KoruGulp.beakLayers(opening: o)
            let s = CGFloat(seg(t, 2.03, 2.33))
            L = L + KoruGulp.cupLayers(down: CGFloat(usEInOut(Double(s))))
            if t < 2.33 { p.eye = .cup } else if t < 2.98 { p.eye = .happy }
            // The file waits at DOC.rest (0.66, -1.3 R from the body centre), 0.42 R wide.
            let fr = KoruFrame(size: sz, pose: p)
            let R = fr.R, rest = CGPoint(x: sz.width / 2 + 0.66 * R, y: sz.height / 2 + (KoruShape.cy - 1.3) * R)
            if t < 2.33 { L = L + KoruGulp.fileLayers(suck: s, opening: o, from: rest, docWidth: 0.42 * R, toScene: .identity, doc: genericDoc(0.42 * R)) }
            Koru.draw(ctx, size: sz, pose: p, layers: L)
            if s <= 0 {   // waiting, as the upload view draws it before the suck
                var c = ctx
                c.opacity = 0.92
                c.translateBy(x: rest.x, y: rest.y)
                genericDoc(0.42 * R)(c, 1)
            }
        }
        savePNG(compose(frames, cols: 6, w: 300, h: 300), "\(out)/suck-film.png")
    }
}


// MARK: - Upload

/// The app's upload scene: UploadSequenceEngine's frames drawn as UploadCanvasView draws them (card, the waiting file),
/// with Koru by KoruUploadScene. The cursor enters next to her, so she locks at once; the drop comes 0.4 s later.
@MainActor
func upload(_ out: String) {
    Koru.frame = 0.8
    let eng = UploadSequenceEngine()
    eng.enterZone(x: 150, y: 42)
    let T0 = Date()
    var shots: [(USFrame, String)] = []
    for tau in [0.0, 0.12, 0.25, 0.38] { shots.append((eng.frame(at: T0.addingTimeInterval(tau)), String(format: "hover %.0f ms", tau * 1000))) }
    let wait = T0.addingTimeInterval(0.4).timeIntervalSinceNow
    if wait > 0 { Thread.sleep(forTimeInterval: wait) }
    eng.performDrop(uploadDuration: 1.2)
    let D0 = Date()
    for d in [0.04, 0.1, 0.16, 0.22, 0.3, 0.36, 0.41, 0.47, 0.56, 0.69, 0.76, 0.86, 1.0, 1.12, 1.28, 1.6, 2.1, 2.5, 2.62, 2.8, 2.95, 3.1, 3.3, 3.8] {
        shots.append((eng.frame(at: D0.addingTimeInterval(d)), String(format: "drop + %.0f ms", d * 1000)))
    }
    func scene(_ f: USFrame) -> CGImage {
        render(width: 640, height: 176, scale: 2, bg: .black) { ctx, _ in
            ctx.fill(Path(roundedRect: CGRect(x: USC.CARD_X, y: USC.CARD_Y, width: USC.CARD_W, height: USC.CARD_H), cornerRadius: USC.CARD_R),
                     with: .color(Color(red: 0.051, green: 0.055, blue: 0.063)))
            KoruUploadScene.draw(ctx, f: f, doc: genericDoc(34))
            if f.fileVisible && f.suck <= 0 {   // UploadCanvasView.drawFile: the file waits at the cursor
                var c = ctx
                c.opacity = 0.92
                c.translateBy(x: f.cursorX, y: f.cursorY + 14)
                genericDoc(34)(c, 1)
            }
        }
    }
    var crops: [(CGImage, String)] = [], wide: [(CGImage, String)] = []
    for (f, label) in shots {
        let img = scene(f)
        let cx = max(100, min(540, f.x)) * 2
        if let c = img.cropping(to: CGRect(x: cx - 200, y: 0, width: 400, height: 352)) {
            crops.append((c, String(format: "%@  t %.2f  mouth %.2f  suck %.2f  eye %@", label, f.t, f.mouth, f.suck, "\(f.eye)")))
        }
        if label.hasPrefix("hover 0") || ["drop + 360 ms", "drop + 1280 ms", "drop + 2100 ms", "drop + 2620 ms", "drop + 3300 ms", "drop + 3800 ms"].contains(label) {
            wide.append((img, label))
        }
    }
    savePNG(compose(crops, cols: 7, w: 400, h: 352), "\(out)/upload-film.png")
    savePNG(compose(wide, cols: 1, w: 1280, h: 352), "\(out)/upload-island.png")
}


// MARK: - Mood

/// Koru with the Mac's mood, as koru.html?shot=idle&mood=<levels>&px=600 (levels set at once, the still 2.2 s later), drawn
/// as the app draws her (koruLayers() has KoruMood's hooks). mood-sheet-before-after-K6.png kept the app's drawing before
/// K6 (Mochi's sweat and heat waves placed on Koru, no flush) next to the hooks.
@MainActor
func mood(_ out: String) {
    Koru.frame = 1
    let cases: [(String, MochiMood)] = [
        ("busy", MochiMood(busy: 1)), ("hot", MochiMood(hot: 1)), ("busyhot", MochiMood(busy: 1, hot: 0.6)),
        ("tired", MochiMood(tired: 1)), ("asleep", MochiMood(asleep: true)), ("full", MochiMood(full: 1)),
    ]
    var cells: [(CGImage, String)] = []
    for (name, m) in cases {
        let e = stillEngine(.idle)
        e.moodTarget = m
        e.moodBusy = m.busy; e.moodHot = m.hot; e.moodFull = m.full; e.moodTired = m.tired
        run([e], seconds: 2.2)
        let img = render(width: 600, height: 600, scale: 1, bg: bgShot) { ctx, sz in drawEngine(e, ctx, sz) }
        savePNG(img, "\(out)/mood-\(name).png")
        cells.append((img, name))
    }
    savePNG(compose(cells, cols: 6, w: 300, h: 300), "\(out)/mood-sheet.png")
    // Busy over time: the hops, darting looks and the sweat, every 120 ms.
    Koru.frame = 0.82
    let e = stillEngine(.idle)
    e.moodTarget = MochiMood(busy: 1, hot: 0.6)
    e.moodBusy = 1; e.moodHot = 0.6
    run([e], seconds: 1)
    let frames = film(e, px: 600, step: 0.12, n: 18, start: {})
    savePNG(compose(frames, cols: 6, w: 300, h: 300), "\(out)/mood-busyhot-film.png")
    // Which side the drops leave from, over 8 s of full load (each drop counted once, by its birth).
    var seen = Set<Double>(), left = 0, right = 0, bursts = 0
    run([e], seconds: 8) {
        let ds = KoruMood.drops(e.moodDrops)
        for (m, k) in zip(e.moodDrops, ds) where !seen.contains(k.born) {
            seen.insert(k.born)
            if k.x < 0 { left += 1 } else { right += 1 }
            if k.born != m.born { bursts += 1 }
        }
    }
    writeLines([String(format: "busy 1 for 8 s: %d drops, %d left, %d right; %d second drops of a burst (other side, a beat later)", left + right, left, right, bursts)],
               "\(out)/mood-drop-sides.txt")
}


// MARK: - Bench

/// Per-frame cost at the island size (58 pt, 2×, frame .8), idle: bare Koru, with the mood's hooks at their heaviest (busy
/// and hot, with drops), during a gulp; and the upload scene's Koru mid-suck (640 × 176 scene, 2×). Interleaved, 120 frames.
@MainActor
func sceneBench(_ out: String) {
    Koru.frame = 0.8
    let W: CGFloat = 58 / 0.6, H = W + 40
    func engine() -> BotEngine {
        let e = BotEngine()
        e.particleOverhang = 40
        e.t0 = CACurrentMediaTime()
        e.setState(.idle, force: true)
        return e
    }
    let bare = engine(), hot = engine(), gul = engine()
    hot.moodTarget = MochiMood(busy: 1, hot: 1); hot.moodBusy = 1; hot.moodHot = 1
    run([bare, hot, gul], seconds: 2.2)
    let eng = UploadSequenceEngine()
    eng.enterZone(x: 150, y: 42)
    let T0 = Date()
    _ = eng.frame(at: T0.addingTimeInterval(0.39))
    eng.performDrop(uploadDuration: 1.2)
    let f = eng.frame(at: Date().addingTimeInterval(0.2))   // mid-suck: open beak, cup eyes, the file in it
    let cases = ["bare Koru", "mood busy + hot", "gulp (open beak)", "upload scene mid-suck"]
    var times: [[Double]] = Array(repeating: [], count: cases.count), totals: [[Double]] = Array(repeating: [], count: cases.count)
    for i in 0..<120 {
        if i % 30 == 0 { gul.gulp() }
        for e in [bare, hot, gul] { e.update(dt: 0.05) }
        for (k, _) in cases.enumerated() {
            var d = 0.0
            let t0 = CACurrentMediaTime()
            defer { totals[k].append((CACurrentMediaTime() - t0) * 1000) }
            if k == 3 {
                _ = render(width: 640, height: 176, scale: 2, bg: nil) { ctx, _ in
                    let a = CACurrentMediaTime(); KoruUploadScene.draw(ctx, f: f, doc: genericDoc(34)); d = CACurrentMediaTime() - a
                }
            } else {
                let e = [bare, hot, gul][k]
                _ = render(width: W, height: H, scale: 2, bg: nil) { ctx, sz in
                    let a = CACurrentMediaTime()
                    drawEngine(e, ctx, sz)   // the app's path: koruLayers() has the outfit, gulp and mood hooks
                    d = CACurrentMediaTime() - a
                }
            }
            times[k].append(d * 1000)
        }
    }
    var lines: [String] = []
    for (k, name) in cases.enumerated() {
        let t = times[k].sorted(), r = totals[k].sorted()
        let line = String(format: "%@: rendered frame (ImageRenderer) median %.2f ms, min %.2f ms; draw calls median %.3f ms, min %.3f ms (120 frames)",
                          name, r[60], r[0], t[60], t[0])
        print(line); lines.append(line)
    }
    writeLines(lines, "\(out)/bench.txt")
}

// MARK: - Main

@main
struct K6SceneMain {
    @MainActor static func main() {
        let args = CommandLine.arguments
        let mode = args.count > 1 ? args[1] : "minis"
        let out = args.count > 2 ? args[2] : FileManager.default.currentDirectoryPath
        try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)
        switch mode {
        case "minis": minis(out)
        case "desktop": desktop(out)
        case "flowhub": flowhub(out)
        case "gulp": gulp(out)
        case "upload": upload(out)
        case "mood": mood(out)
        case "bench": sceneBench(out)
        default: print("modes: minis desktop flowhub gulp upload mood bench")
        }
    }
}
