import SwiftUI
import CoreGraphics

// Koru's cached shading (core.js sheet/stamp/drop/inner/grainSheet). Shading that depends only on a shape is drawn once
// with Core Graphics into a sheet, cached per size, and stamped through the current transform every frame, so a frame
// redraws none of its blurs. Sheets are in the shape's space, in device pixels for a given R (px).

@MainActor
enum KoruSheets {
    struct Sheet {
        let image: CGImage
        /// Extent in the shape's space, in px for radius R.
        let rect: CGRect
        let R: CGFloat
    }

    private struct Entry { var sheet: Sheet?; var used: Int }
    private static var cache: [String: Entry] = [:]
    private static var sizes: [String: [CGFloat]] = [:]
    private static var tick = 0
    private static var budget = 0
    /// The most recently used sheets kept (a dozen per size; a resize leaves the old ones to age out).
    static let capacity = 160
    /// New sheets drawn per frame while a cached size can stand in (the island resizing: the old size, scaled, until it settles).
    static let perFrame = 4

    static func beginFrame() { budget = perFrame }

    /// The sheet `base` for radius R (px), drawn by make(R) when missing. While the frame's budget is spent and another
    /// size of it is cached, that one stands in (scaled when stamped).
    static func get(_ base: String, R: CGFloat, make: (CGFloat) -> Sheet?) -> Sheet? {
        let Rq = (R * 4).rounded() / 4
        let key = base + "@" + String(describing: Rq)
        tick += 1
        if var e = cache[key] { e.used = tick; cache[key] = e; return e.sheet }
        if budget <= 0, let near = sizes[base]?.min(by: { abs($0 - Rq) < abs($1 - Rq) }),
           let e = cache[base + "@" + String(describing: near)] {
            return e.sheet
        }
        budget -= 1
        let s = make(Rq)
        cache[key] = Entry(sheet: s, used: tick)
        sizes[base, default: []].append(Rq)
        if cache.count > capacity, let old = cache.min(by: { $0.value.used < $1.value.used })?.key {
            cache.removeValue(forKey: old)
            if let at = old.range(of: "@", options: .backwards) {
                let b = String(old[..<at.lowerBound]), r = CGFloat(Double(old[at.upperBound...]) ?? 0)
                sizes[b]?.removeAll { $0 == r }
            }
        }
        return s
    }

    static func clear() { cache.removeAll(); sizes.removeAll() }

    // MARK: Stamping

    /// Draws a sheet where it belongs in the current (shape) space, whose radius is R (points).
    static func stamp(_ ctx: GraphicsContext, _ s: Sheet?, R: CGFloat) {
        guard let s else { return }
        ctx.draw(Image(decorative: s.image, scale: 1), in: rect(s, R))
    }

    /// A white mask sheet, tinted.
    static func stampTint(_ ctx: GraphicsContext, _ s: Sheet?, R: CGFloat, color: Color) {
        guard let s else { return }
        var img = ctx.resolve(Image(decorative: s.image, scale: 1).renderingMode(.template))
        img.shading = .color(color)
        ctx.draw(img, in: rect(s, R))
    }

    private static func rect(_ s: Sheet, _ R: CGFloat) -> CGRect {
        let k = R / s.R
        return CGRect(x: s.rect.minX * k, y: s.rect.minY * k, width: s.rect.width * k, height: s.rect.height * k)
    }

    // MARK: Drawing a sheet

    static let srgb = CGColorSpace(name: CGColorSpace.sRGB)!

    /// Draws `draw` in a room of box ± pad (within clip, as the canvas edge limited the original), y down, then keeps the box.
    static func render(box: CGRect, pad: CGFloat = 0, clip: CGRect? = nil, R: CGFloat, draw: (CGContext, CGRect) -> Void) -> Sheet? {
        var room = box.insetBy(dx: -pad, dy: -pad)
        if let clip { room = room.intersection(clip) }
        guard !room.isNull, room.width >= 1, room.height >= 1 else { return nil }
        let r0 = floor(room.minX), q0 = floor(room.minY)
        let W = Int(ceil(room.maxX) - r0), H = Int(ceil(room.maxY) - q0)
        guard W > 0, H > 0, W < 8192, H < 8192, let g = context(W, H) else { return nil }
        g.translateBy(x: 0, y: CGFloat(H)); g.scaleBy(x: 1, y: -1)
        g.translateBy(x: -r0, y: -q0)
        draw(g, CGRect(x: r0, y: q0, width: CGFloat(W), height: CGFloat(H)))
        guard let big = g.makeImage() else { return nil }
        let x0 = floor(box.minX), y0 = floor(box.minY)
        let want = CGRect(x: x0 - r0, y: y0 - q0, width: max(1, ceil(box.maxX) - x0), height: max(1, ceil(box.maxY) - y0))
        let crop = want.intersection(CGRect(x: 0, y: 0, width: W, height: H))
        guard !crop.isNull, let img = big.cropping(to: crop) else { return nil }
        return Sheet(image: img, rect: CGRect(x: crop.minX + r0, y: crop.minY + q0, width: crop.width, height: crop.height), R: R)
    }

    static func context(_ W: Int, _ H: Int) -> CGContext? {
        CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0, space: srgb,
                  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
    }

    // MARK: Soft light and shade (core.js drop / inner)

    /// Canvas shadowBlur → CGContext shadow blur: a canvas blur b is a gaussian of σ = b/2, CG's blur b is σ ≈ 0.44 b.
    static let blurK: CGFloat = 1.13
    private static let OFF: CGFloat = 20000

    /// A soft shadow (or glow) of a shape, without the shape: it is drawn far off and only its shadow lands.
    static func drop(_ g: CGContext, _ path: CGPath, _ color: CGColor, _ blur: CGFloat, _ dx: CGFloat = 0, _ dy: CGFloat = 0) {
        g.saveGState()
        // Shadow offsets are in base space (y up); the room is y down.
        g.setShadow(offset: CGSize(width: OFF + dx, height: -dy), blur: blur * blurK, color: color)
        g.translateBy(x: -OFF, y: 0)
        g.addPath(path)
        g.setFillColor(CGColor(gray: 0, alpha: 1))
        g.fillPath()
        g.restoreGState()
    }

    /// Inner light or shade along the edges of a shape: the outside (within box + the blur's reach, inside the room) is
    /// rasterised first, so overlapping sub-shapes act as one union, and its blurred shadow is laid inside the shape.
    static func inner(_ g: CGContext, room: CGRect, _ path: CGPath, _ color: CGColor, _ blur: CGFloat,
                      _ dx: CGFloat = 0, _ dy: CGFloat = 0, box: CGRect? = nil) {
        let W = Int(room.width), H = Int(room.height)
        guard let m = context(W, H) else { return }
        m.translateBy(x: 0, y: CGFloat(H)); m.scaleBy(x: 1, y: -1)
        m.translateBy(x: -room.minX, y: -room.minY)
        let reach = blur * 2 + abs(dx) + abs(dy) + 2
        let area = (box.map { $0.insetBy(dx: -reach, dy: -reach) } ?? room).intersection(room)
        m.setFillColor(CGColor(gray: 0, alpha: 1))
        m.fill(area)
        m.setBlendMode(.clear)
        m.addPath(path)
        m.fillPath()
        guard let mask = m.makeImage() else { return }
        g.saveGState()
        g.addPath(path)
        g.clip()
        g.setShadow(offset: CGSize(width: OFF + dx, height: -dy), blur: blur * blurK, color: color)
        g.concatenate(g.ctm.inverted())          // base space, where the mask lines up pixel for pixel
        g.draw(mask, in: CGRect(x: -OFF, y: 0, width: CGFloat(W), height: CGFloat(H)))
        g.restoreGState()
    }

    // MARK: Velvet grain

    /// 1 px monochrome noise (core.js grainPattern, same generator and seed), laid with soft-light.
    static let noise: CGImage? = {
        let n = 128
        var q: Int32 = 7
        var bytes = [UInt8](repeating: 0, count: n * n)
        for i in 0..<(n * n) {
            q = Int32(truncatingIfNeeded: Int64(q) &* 48271) % 2147483647   // Math.imul then %, as the prototype
            let v = 128 + (Double(q) / 2147483647 - 0.5) * 90
            bytes[i] = UInt8(max(0, min(255, v.rounded(.toNearestOrEven))))
        }
        guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
        return CGImage(width: n, height: n, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: n,
                       space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }()

    /// Grain in a shape's space (box, px): opaque at y0, faint from y1; with x1, it also fades out towards the middle,
    /// gone inside |x| < x0 and full beyond x1.
    static func grain(box: CGRect, y0: CGFloat, y1: CGFloat, x0: CGFloat = 0, x1: CGFloat = 0, R: CGFloat) -> Sheet? {
        render(box: box, R: R) { g, room in
            if let noise {
                g.saveGState()
                g.concatenate(g.ctm.inverted())
                g.interpolationQuality = .low
                g.draw(noise, in: CGRect(x: 0, y: 0, width: 128 * 1.6, height: 128 * 1.6), byTiling: true)
                g.restoreGState()
            }
            let r = box.insetBy(dx: -1, dy: -1)
            g.saveGState()
            g.setBlendMode(.destinationIn)
            g.clip(to: r)
            let v = CGGradient(colorsSpace: srgb, colors: [CGColor(gray: 0, alpha: 1), CGColor(gray: 0, alpha: 0.35), CGColor(gray: 0, alpha: 0.2)] as CFArray,
                               locations: [0, 0.5, 1])!
            g.drawLinearGradient(v, start: CGPoint(x: 0, y: y0), end: CGPoint(x: 0, y: y1), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            g.restoreGState()
            if x1 > 0 {
                let a = (x1 - x0) / (2 * x1)
                let h = CGGradient(colorsSpace: srgb, colors: [CGColor(gray: 0, alpha: 1), CGColor(gray: 0, alpha: 0), CGColor(gray: 0, alpha: 0), CGColor(gray: 0, alpha: 1)] as CFArray,
                                   locations: [0, a, 1 - a, 1])!
                g.saveGState()
                g.setBlendMode(.destinationIn)
                g.clip(to: r)
                g.drawLinearGradient(h, start: CGPoint(x: -x1, y: 0), end: CGPoint(x: x1, y: 0), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
                g.restoreGState()
            }
        }
    }

    /// Fills a rect with a gradient under the current clip and blend mode (a canvas fillRect with a gradient).
    static func fillLinear(_ g: CGContext, _ rect: CGRect, _ colors: [CGColor], _ locations: [CGFloat], from: CGPoint, to: CGPoint) {
        guard let gr = CGGradient(colorsSpace: srgb, colors: colors as CFArray, locations: locations) else { return }
        g.saveGState()
        g.clip(to: rect)
        g.drawLinearGradient(gr, start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        g.restoreGState()
    }
}
