import SwiftUI
import QuartzCore

// BotEngine drives Koru: Mochi's motion engine (states, tweens, blinks, greet, particles) with Koru's own pose per state
// (core.js STATES and update()), drawn by KoruDrawing. BotEngine routes to these when Koru.enabled.

/// Koru's values that Mochi's engine has no slot for, eased every update as core.js does.
struct KoruMotion {
    var hy: CGFloat = 0, ear: CGFloat = 0, go: CGFloat = 0.3, tint: CGFloat = 0, dy: CGFloat = 0, auraA: CGFloat = 0
    var col = KoruStates[.idle].col
    var aura: KoruAura? = nil
    /// The wing that rises: the near one, picked when it starts up (looking right, the left wing waves).
    var handSide: CGFloat = -1
    /// The state the shown badge belongs to (the badge swaps 100 ms after the state).
    var badgeState: BotState = .idle
    var badgeKey = "none"
    var paletteHex: CGColor? = nil
    var palette: KoruPalette? = nil
}

extension BotEngine {
    /// Called by update() before the mood and the smoothing: Koru's look, head tilt and squash targets, then her own values.
    func koruStep(dt: Double, now: Double, t: CGFloat) {
        guard Koru.enabled else { return }
        let c = KoruStates[state]
        // Her state's look, 70 % over the pointer's (minis wander; listening and voice keep theirs).
        if !isMini && !isInListeningMode && !isInVoiceCompact && !cfg.scans {
            if let l = c.look {
                tgYaw = lookX * 0.62 * 0.3 + l.x * 0.62 * 0.7
                tgPitch = lookY * 0.5 * 0.3 + l.y * 0.5 * 0.7
            }
            if state == .sleeping { tgYaw = 0.2 }
        }
        if hands < 0.05 && listenHandRaise < 0.05 { koru.handSide = yaw > 0 ? -1 : 1 }
        // Her tilt is the head's: the state's, or swaying with the wave towards the waving wing.
        if now > waveStart && now < waveUntil {
            tgTilt = koru.handSide * (-0.06 + sin(2 * .pi * 1.2 * CGFloat(now - waveStart)) * 0.07)
        } else {
            tgTilt = c.tilt
        }
        tgSy *= c.sq
        let k = CGFloat(1 - pow(0.0008, dt))
        koru.hy += (c.hy - koru.hy) * k
        koru.ear += (c.ear - koru.ear) * k
        koru.tint += (c.tint - koru.tint) * k
        koru.go += (c.go - koru.go) * k
        koru.dy += (c.dy - koru.dy) * k
        koru.auraA += ((c.aura != nil ? 1 : 0) - koru.auraA) * k
        if let a = c.aura { koru.aura = a }
        let kc = CGFloat(1 - pow(0.002, dt))
        koru.col = koru.col.mix(c.col, kc)
        let key = koruBadgeKey(badge)
        if key != koru.badgeKey { koru.badgeKey = key; koru.badgeState = state }
        // A new sleepy z drifts up beside her head, slowly (core.js zz(); the engine ages particles 3× real time).
        for i in particles.indices where particles[i].type == .z && particles[i].vy < -0.3 {
            particles[i].x = 0.3 + .random(in: 0...0.25); particles[i].y = -0.85
            particles[i].vx = (0.1 + .random(in: 0...0.1)) / 3; particles[i].vy = -(0.18 + .random(in: 0...0.06)) / 3
            particles[i].life = 1.6 * 3
        }
    }

    /// This frame of Koru, from the engine's values.
    func koruPose(size: CGSize) -> KoruPose {
        var p = KoruPose()
        p.yaw = yaw; p.pitch = pitch; p.tilt = tilt
        p.roll = roll
        // BotCanvasView (and the desktop Koru) already turn the canvas when an outfit rolls with her.
        p.rollSelf = !(outfit != .none && outfitPresence > 0.05)
        p.open = open; p.sx = sx; p.sy = sy; p.ox = ox; p.oy = oy + koru.dy
        p.hy = koru.hy; p.ear = koru.ear; p.tint = koru.tint; p.go = koru.go
        p.hands = max(hands, listenHandRaise); p.cup = listenHandRaise > 0.01
        p.blush = max(blush, moodHot * 0.85)
        p.es = es; p.badgeS = badgeS; p.auraA = koru.auraA; p.aura = koru.aura
        p.col = koru.col
        // Koru's teal is her own colour: a neutral body colour (Mochi's white #F5F6F8, greys) leaves her as she is,
        // a real colour (an agent's, an integration's, the update blue) still tints her.
        if let bc = bodyColor, Koru.tints(KoruRGB(bc)) {
            if koru.paletteHex != bc { koru.paletteHex = bc; koru.palette = .agent(KoruRGB(bc)) }
            p.palette = koru.palette
        }
        p.mini = isMini
        var shape = eyeOverride ?? koruGulpEye ?? cfg.eye   // a gulp's cup or happy eyes (KoruGulp.swift), under an emote's
        if isDancing && dancingLevel > 0.15 && !isMini && (state == .idle || state == .finished) { shape = .happy }
        p.eye = shape
        p.cfg = KoruStates[state]
        let now = CACurrentMediaTime()
        p.now = now; p.t = CGFloat(now - t0)
        p.waveStart = waveStart; p.waveUntil = waveUntil
        p.handSide = koru.handSide
        p.overhang = particleOverhang
        p.frame = Koru.frame
        return p
    }

    func koruDraw(context: GraphicsContext, size: CGSize) {
        Koru.draw(context, size: size, pose: koruPose(size: size), layers: koruLayers())
    }

    /// Badge, aura and particles, outside the body's turn (the mood's sweat and heat are KoruMood.swift's hooks).
    func koruDrawExtras(context: GraphicsContext, size: CGSize) {
        let p = koruPose(size: size)
        var kind: KoruBadgeKind? = nil
        var colors = (KoruRGB.white, KoruRGB.white)
        if let b = badge {
            (kind, colors) = koruBadge(b)
        }
        if morph >= 0.25 { kind = nil }
        Koru.drawFront(context, size: size, pose: p, badge: kind, badgeColors: colors, particles: particles, layers: koruLayers())
    }

    func koruBodyCenter(size: CGSize) -> CGPoint {
        let fr = KoruFrame(size: size, pose: koruPose(size: size))
        return CGPoint(x: fr.cx, y: fr.cy)
    }

    /// Koru's badge for Mochi's: the state it was set for gives its kind and colours (finished wears a ring); an update
    /// waiting is a blue arrow; anything else keeps Mochi's kind in its own colour.
    private func koruBadge(_ b: BadgeType) -> (KoruBadgeKind, (KoruRGB, KoruRGB)) {
        if case .arrow = b { return (KoruStates.update.kind, (KoruStates.update.c0, KoruStates.update.c1)) }
        for s in [koru.badgeState, state] {
            if let kb = KoruStates[s].badge, Self.koruSameKind(kb.kind, b) { return (kb.kind, (kb.c0, kb.c1)) }
        }
        switch b {
        case .dots(let c): return (.dots, (KoruRGB(c).mix(.white, 0.15), KoruRGB(c)))
        case .bang(let c): return (.bang, (KoruRGB(c).mix(.white, 0.15), KoruRGB(c)))
        case .question(let c): return (.q, (KoruRGB(c).mix(.white, 0.15), KoruRGB(c)))
        case .dot(let c), .arrow(let c): return (.dot, (KoruRGB(c).mix(.white, 0.15), KoruRGB(c)))
        }
    }

    private static func koruSameKind(_ k: KoruBadgeKind, _ b: BadgeType) -> Bool {
        switch (k, b) {
        case (.dots, .dots), (.bang, .bang), (.q, .question), (.dot, .dot), (.ring, .dot): return true
        default: return false
        }
    }

    private func koruBadgeKey(_ b: BadgeType?) -> String {
        guard let b else { return "none" }
        switch b {
        case .dots(let c): return "dots\(c.components ?? [])"
        case .bang(let c): return "bang\(c.components ?? [])"
        case .question(let c): return "q\(c.components ?? [])"
        case .dot(let c): return "dot\(c.components ?? [])"
        case .arrow(let c): return "arrow\(c.components ?? [])"
        }
    }
}

extension Koru {
    /// Whether a body colour recolours Koru: only a saturated one does (HSV saturation above 0.25), so white and greys keep her teal.
    static func tints(_ c: KoruRGB) -> Bool {
        let hi = max(c.r, c.g, c.b), lo = min(c.r, c.g, c.b)
        return hi > 0 && (hi - lo) / hi > 0.25
    }
}
