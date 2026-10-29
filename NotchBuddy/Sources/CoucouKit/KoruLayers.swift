import SwiftUI
import CoreGraphics

// Koru's draw hooks: what core.js features plug in through layers, beak() and eyeShapes, as values passed to Koru.draw.
//
//   Koru.draw(context, size: size, pose: pose, layers: layers)          // body, wings, head (+ the hooks below)
//   Koru.drawFront(context, size: size, pose: pose, ..., layers: layers) // badge, aura, particles, then `front`
//
// A KoruLayers holds hooks per z-point; `a + b` runs a's hooks before b's (core.js script order). The default, `.none`,
// draws Koru exactly as without hooks. Every hook gets a copy of the context (its transforms, clips and opacity stay
// local, as core.js layer() save/restore) in the space its layer is named after, and the frame's KoruGeometry:
//
//   floor      canvas space, after the floor glow, before anything of the body
//   behind     body space (origin at the base of the body, rolled and squashed with it), before the wings that fold
//              or rise behind the body: things behind Koru
//   body       body space, over the body's shading, under the near wings (a scarf)
//   wings      body space, over the near wings; geometry.wings is the outline of every wing drawn (to recolour them)
//   headBack   head space (origin at the body centre, turned with the head), behind the facial disc and tufts (hats)
//   face       head space, over the facial disc, under the eye discs
//   headFront  head space, over the eyes and beak (glasses)
//   headTop    head space, above everything on the head (what the beak holds)
//   front      canvas space, last thing drawFront draws (after badge, aura and particles)
//
// Two hooks replace a part instead of adding one:
//   beak  (GraphicsContext, KoruGeometry) -> Bool   beak space (origin at geometry.beakAt): return true when it drew the
//                                                   beak itself; the first one that does wins, else Koru's beak is drawn
//   eye   (GraphicsContext, KoruEyeInfo) -> Bool    inside one eye disc (centred, clipped to it), before Koru's own eye
//                                                   shapes: return true when it drew the eye (a feature's own shape);
//                                                   Koru.pupil(ctx, info, r) draws her pupil for it
//
// Coordinates are px of the context at Koru's size R (geometry.R); the prototype's R units times R. geometry.bodyT and
// geometry.head place things given in canvas space (core.js setTransform) into the body or the head. Hooks are
// @MainActor closures held by value: no global state, so two canvases can draw two Korus with different hooks.

/// One eye disc in head space (core.js d.eyes): centre, radius and its squeeze for the head turn.
struct KoruEyeDisc: Sendable {
    var sd, far, x, y, r, kx, ky: CGFloat
}

/// What a draw hook gets (core.js draw()'s d). Fields fill in as the frame is drawn: body from `floor` on, belly from
/// `body`, wings complete from `wings`, eyes from `headBack`, face and tufts from `face`, beak from `beak`.
struct KoruGeometry {
    var size: CGSize
    /// Koru's radius (px) and her body's half-width and half-heights below and above the centre.
    var R, rx, ryB, ryT: CGFloat
    /// Body centre in canvas space, and the body's squash.
    var cx, cy, sx, sy: CGFloat
    var pose: KoruPose
    var full: Bool { !pose.mini }
    var mini: Bool { pose.mini }
    /// State colour (eased) and how much it lights her.
    var col: KoruRGB, tint: CGFloat
    /// Head turn and tilt, -1…1; face offset for the turn in R units (f) and px (fx).
    var yawN, pitN, f, fx: CGFloat
    /// The display scale of the context (px per point).
    var scale: CGFloat
    /// Maps head-space points to body space: concatenate it in a body-space context to draw with the head (core.js d.head).
    var head: CGAffineTransform
    /// Maps body-space points to canvas space (the context draw() got): Koru's base on whole pixels at full size, her roll
    /// (when she turns herself) and squash. A canvas point in head space: point.applying(head.concatenating(bodyT).inverted()).
    var bodyT: CGAffineTransform = .identity
    /// Where the beak sits in head space.
    var beakAt: CGPoint
    /// Body outline (body space).
    var body: Path
    var belly = Path()
    /// Outline of the wings drawn so far (body space).
    var wings = Path()
    var eyes: [KoruEyeDisc] = []
    /// Facial disc (rings, brows, tufts) and the tufts alone, head space.
    var face = Path(), tufts = Path()
    /// The closed beak in beak space, its half-width and its tip below the centre.
    var beak = Path()
    var br: CGFloat = 0, tip: CGFloat = 0
}

/// What an eye hook gets: one disc of radius dr, its side, where the pupil would sit (px, py) and its radius (pr).
struct KoruEyeInfo {
    var shape: EyeShape
    var dr, sd, far, px, py, pr, R, t, yawN, pitN: CGFloat
    var pose: KoruPose
}

struct KoruLayers {
    typealias Hook = @MainActor (GraphicsContext, KoruGeometry) -> Void
    typealias BeakHook = @MainActor (GraphicsContext, KoruGeometry) -> Bool
    typealias EyeHook = @MainActor (GraphicsContext, KoruEyeInfo) -> Bool

    var floor: [Hook] = [], behind: [Hook] = [], body: [Hook] = [], wings: [Hook] = []
    var headBack: [Hook] = [], face: [Hook] = [], headFront: [Hook] = [], headTop: [Hook] = [], front: [Hook] = []
    var beak: [BeakHook] = []
    var eye: [EyeHook] = []

    static let none = KoruLayers()

    var isEmpty: Bool {
        floor.isEmpty && behind.isEmpty && body.isEmpty && wings.isEmpty && headBack.isEmpty && face.isEmpty
            && headFront.isEmpty && headTop.isEmpty && front.isEmpty && beak.isEmpty && eye.isEmpty
    }

    /// a's hooks run before b's.
    static func + (a: KoruLayers, b: KoruLayers) -> KoruLayers {
        var c = a
        c.floor += b.floor; c.behind += b.behind; c.body += b.body; c.wings += b.wings
        c.headBack += b.headBack; c.face += b.face; c.headFront += b.headFront; c.headTop += b.headTop; c.front += b.front
        c.beak += b.beak; c.eye += b.eye
        return c
    }
}

extension BotEngine {
    /// The hooks BotEngine's Koru draws with (KoruEngine.koruDraw and koruDrawExtras), in script order: outfits first,
    /// as outfits.js loads before the other features. Other features add theirs here with `+`.
    func koruLayers() -> KoruLayers {
        koruOutfitLayers()
    }
}
