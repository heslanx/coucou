import SwiftUI

// Koru wears the Coucou wardrobe (MochiWardrobe.swift: 11 accessories and Auto), drawn through her layer hooks as the
// prototype's outfits.js: hats sit behind the tufts (headBack), glasses on the eye discs and the bow on the right tuft
// (headFront), the scarf at the neck line under the near wings (body, with the head), the bunny ears behind the body; the
// pumpkin tints the body (body) and the wings (wings), peeks out behind (behind) and grows a stem (headBack).
// BotEngine's setOutfit() timing drives `presence`: hats stay opaque and grow from the crown (Ease.back); the others fade in,
// opaque at 40 %, glasses rising .25 ry, the scarf .3 ry, the bow scaling from Koru's centre; the pumpkin only fades. Pompoms,
// hat tips and the scarf end lag with physDx/physDy. Minis and anything under 16 pt R (Mochi's `simplified`) drop the details.

extension BotEngine {
    /// This frame's outfit hooks (KoruLayers.swift composes them into koruLayers()).
    func koruOutfitLayers() -> KoruLayers {
        guard outfit != .none, outfitPresence > 0.001 else { return .none }
        return Koru.outfitLayers(outfit, presence: outfitPresence, physDx: physDx, physDy: physDy)
    }
}

extension Koru {
    private enum Kind { case hat, glasses, bow, scarf, fade }
    private enum Layer { case behind, body, wings, headBack, headFront }
    private typealias Art = KoruOutfitArt
    private typealias Draw = @MainActor (GraphicsContext, KoruOutfitK, KoruGeometry) -> Void

    /// Where each outfit draws (outfits.js DRAW).
    private static func plan(_ o: Outfit) -> (Kind, [(Layer, Draw)])? {
        switch o {
        case .partyHat: return (.hat, [(.headBack, { x, k, _ in Art.partyHat(x, k) })])
        case .beanie: return (.hat, [(.headBack, { x, k, _ in Art.beanie(x, k) })])
        case .crown: return (.hat, [(.headBack, { x, k, _ in Art.crown(x, k) })])
        case .witchHat: return (.hat, [(.headBack, { x, k, _ in Art.witchHat(x, k) })])
        case .santaHat: return (.hat, [(.headBack, { x, k, _ in Art.santaHat(x, k) })])
        case .bunnyEars: return (.hat, [(.behind, { x, k, _ in Art.bunnyEars(x, k) })])
        case .sunglasses: return (.glasses, [(.headFront, { x, k, _ in Art.sunglasses(x, k) })])
        case .roundGlasses: return (.glasses, [(.headFront, { x, k, _ in Art.roundGlasses(x, k) })])
        case .bow: return (.bow, [(.headFront, { x, k, _ in Art.bow(x, k) })])
        case .scarf: return (.scarf, [(.body, { x, k, d in Art.scarf(x, k, d) })])
        case .pumpkin: return (.fade, [(.behind, { x, k, _ in Art.pumpkinLobes(x, k) }), (.body, { x, k, d in Art.pumpkinBody(x, k, d) }),
                                       (.wings, { x, k, d in Art.pumpkinWings(x, k, d) }), (.headBack, { x, k, _ in Art.pumpkinStem(x, k) })])
        case .auto, .none: return nil
        }
    }

    private static let crownY: CGFloat = -0.9

    /// The hooks that dress Koru in outfit o (resolved, not .auto) at presence 0…1, with the lag of things hanging off her head.
    static func outfitLayers(_ o: Outfit, presence p: CGFloat, physDx: CGFloat, physDy: CGFloat) -> KoruLayers {
        guard let (kind, draws) = plan(o), p > 0.001 else { return .none }
        // Hats are opaque from the start; the rest is opaque at 40 %.
        let a: CGFloat = kind == .hat ? 1 : min(1, p * 2.5)
        guard a >= 0.005 else { return .none }
        var L = KoruLayers()
        for (name, fn) in draws {
            // Below full opacity an accessory is drawn as one group, so its parts never show through each other; the
            // pumpkin's tint blends with what is under it, so it fades in place.
            let group = a < 1 && !(kind == .fade && (name == .body || name == .wings))
            // The bunny ears (behind the body) and the scarf (on the body) move with the head.
            let withHead = (name == .behind && kind == .hat) || (name == .body && kind == .scarf)
            let hook: KoruLayers.Hook = { ctx, d in
                var x = ctx
                if withHead { x.concatenate(d.head) }
                @MainActor func dress(_ c: GraphicsContext) {
                    var c = c
                    let k = stage(kind, &c, d, presence: p, physDx: physDx, physDy: physDy)
                    fn(c, k, d)
                }
                if group {
                    x.opacity *= Double(a)
                    x.drawLayer { l in dress(l) }
                } else {
                    x.opacity *= Double(kind == .hat ? 1 : a)
                    dress(x)
                }
            }
            switch name {
            case .behind: L.behind.append(hook)
            case .body: L.body.append(hook)
            case .wings: L.wings.append(hook)
            case .headBack: L.headBack.append(hook)
            case .headFront: L.headFront.append(hook)
            }
        }
        return L
    }

    /// outfits.js stage(): the presence motion of each kind, then R units; the frame's view for the parts.
    private static func stage(_ kind: Kind, _ x: inout GraphicsContext, _ d: KoruGeometry, presence p: CGFloat,
                              physDx: CGFloat, physDy: CGFloat) -> KoruOutfitK {
        let pos = Ease.back(p), h = d.f * 0.3, R = d.R, ryT = KoruShape.ryTop
        if kind == .glasses {   // the beak stays in front
            var nb = Path(CGRect(x: -d.size.width * 2, y: -d.size.height * 2, width: d.size.width * 4, height: d.size.height * 4))
            nb.addPath(d.beak, transform: CGAffineTransform(translationX: d.beakAt.x, y: d.beakAt.y))
            x.clip(to: nb, style: FillStyle(eoFill: true))
        }
        x.scaleBy(x: R, y: R)
        switch kind {
        case .hat:
            let s = max(0.001, pos)
            x.translateBy(x: h, y: crownY); x.scaleBy(x: s, y: s); x.translateBy(x: 0, y: -crownY)
        case .glasses: x.translateBy(x: 0, y: (1 - p) * 0.25 * ryT)
        case .scarf: x.translateBy(x: 0, y: (1 - p) * 0.3 * ryT)
        case .bow: let s = max(0.001, pos); x.scaleBy(x: s, y: s)
        case .fade: break
        }
        // The lag in steps of 1/20 (under half a point at the app's sizes): a swing reuses the sheets of earlier ones.
        let q = { (v: CGFloat) in (v * 20).rounded() / 20 }
        let Rpx = R * d.scale
        return KoruOutfitK(R: Rpx, Rpx: Rpx, Rpt: R, full: d.full, simple: d.mini || R < 16, f: d.f, h: h, yaw: d.pose.yaw,
                           dx: q(physDx), dy: q(physDy), rise: kind == .scarf ? (1 - p) * 0.3 * ryT : 0,
                           eyes: kind == .glasses ? d.eyes.map { KoruEyeDisc(sd: $0.sd, far: $0.far, x: $0.x / R, y: $0.y / R, r: $0.r / R, kx: $0.kx, ky: $0.ky) } : [])
    }

    // MARK: - Wardrobe icon

    /// A small Koru wearing the outfit, for the wardrobe's 30 pt swatches (IslandViewContent.swift); Auto wears the
    /// seasonal one and an AUTO tag. The none swatch stays the app's.
    static func drawOutfitIcon(context: GraphicsContext, size: CGSize, outfit: Outfit, seasonal: Outfit = .none) {
        let worn = outfit == .auto ? seasonal : outfit
        // R leaves room for the tallest accessories (witch hat, bunny ears) above and the wings on the sides.
        let R = min(size.width, size.height) * 0.285, W = R / 0.3
        let centre = CGPoint(x: size.width / 2, y: size.height / 2 + R * 0.45)
        var p = KoruPose()
        p.frame = 1; p.yaw = 0; p.go = 0.3; p.tint = 0.2; p.t = 1; p.now = 0
        var c = context
        c.translateBy(x: centre.x - W / 2, y: centre.y - W / 2 - KoruShape.cy * R)
        let layers = worn == .none || worn == .auto ? KoruLayers.none : outfitLayers(worn, presence: 1, physDx: 0, physDy: 0)
        draw(c, size: CGSize(width: W, height: W), pose: p, layers: layers)
        if outfit == .auto {
            var b = context
            b.translateBy(x: size.width / 2, y: centre.y + R * 0.72)
            let bw: CGFloat = 14, bh: CGFloat = 6.5
            b.fill(Path(roundedRect: CGRect(x: -bw / 2, y: -bh / 2, width: bw, height: bh), cornerRadius: bh / 2), with: .color(.black.opacity(0.6)))
            b.draw(Text("AUTO").font(.system(size: 4.2, weight: .semibold)).foregroundColor(.white), at: .zero)
        }
    }
}
