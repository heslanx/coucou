#if !APPSTORE
import QuartzCore
import SwiftUI

// Koncluí: the Koru of the reminder's alert (KoncluiReminderAlert.swift) with her alarm clock beside her, both drawn in code
// in one canvas. Before the time the clock ticks and she waits; at the time it rings in bursts and she jumps, her "!" up;
// past it, it keeps ringing, turns amber as the "há 3 min" line does, and she sweats a drop a burst
// (KoncluiReminderAlertRules.cue, KoncluiAlarmClockMotion). The clock's hands show the reminder's time, as the headline.
//
// Cost: the display's rate while the alert shows (`koncluiMotion`), as the Koru alone drew before. Reduce Motion draws one
// still frame, her pose and badge already at the cue's end and the clock's ringing marks drawn, and again only when the cue
// changes (KoncluiReminderAlertRules.cueChanges).

/// The Koru and her clock. Lay it out as HubLiveMochi was: centred in the Koru's old frame, the canvas overflowing it; the
/// pair is centred where she stood alone.
struct KoncluiReminderKoru: View {
    let due: Date
    /// The Koru's size, as HubLiveMochi's (about the width of her body).
    let size: CGFloat

    @Environment(\.koncluiMotion) private var motion
    @StateObject private var stage = KoncluiReminderStage()

    var body: some View {
        let side = KoncluiReminderStage.koruSide(size)
        TimelineView(.explicit(KoncluiReminderAlertRules.cueChanges(due: due, after: Date()))) { tick in
            let cue = KoncluiReminderAlertRules.cue(KoncluiReminderAlertRules.when(due, now: max(tick.date, Date())))
            TimelineView(.animation(minimumInterval: motion.minimumInterval, paused: motion.paused)) { frame in
                let date = frame.date
                Canvas { context, canvas in
                    stage.draw(&context, size: canvas, cue: cue, due: due, date: date, live: !motion.paused,
                               now: CACurrentMediaTime())
                }
            }
        }
        .frame(width: side * (1 + KoncluiReminderStage.clockOffset), height: side)
    }
}

/// The Koru's engine and what the clock remembers between frames.
@MainActor
final class KoncluiReminderStage: ObservableObject {
    /// The Koru's square canvas for a HubLiveMochi size.
    static func koruSide(_ size: CGFloat) -> CGFloat { size / 0.68 }
    /// How far right of her centre the clock stands, and its size, in widths of her canvas.
    static let clockOffset: CGFloat = 0.56
    static let clockUnit: CGFloat = 0.5

    private let koru: BotEngine
    private var cue: KoncluiReminderAlertRules.Cue?
    private var ringStart: Double = 0
    private var lastBurst = -1
    /// 0 mint, 1 amber: eased while it runs, so the clock turns late instead of switching.
    private var lateMix: Double = 0
    private var settled = false
    /// Where she looks: at her clock, then at the person, in turns.
    private var atClock = false
    private var nextGlance: Double = 0

    init() {
        let engine = BotEngine()
        // Not a mini: at 52 to 84 pt she is as large as the notch's Koru, and only the full drawing writes the "!" in her
        // badge (a mini's is a plain disc). A full Koru follows `look` instead of wandering, so the stage moves her eyes.
        engine.isMini = false
        engine.bodyColor = cgColorFromHex("#F5F6F8")
        koru = engine
    }

    func draw(_ context: inout GraphicsContext, size: CGSize, cue: KoncluiReminderAlertRules.Cue, due: Date, date: Date,
              live: Bool, now: Double) {
        if cue != self.cue { enter(cue, live: live, now: now) }
        let ringing = cue != .waiting
        let elapsed = now - ringStart
        if live {
            if now >= nextGlance {
                look(atClock: !atClock)
                nextGlance = now + (atClock ? .random(in: 1.6...3.2) : .random(in: 1.2...2.4))
            }
            MochiFrameClock.advance(koru)
            settled = false
            lateMix += ((cue == .overdue ? 1 : 0) - lateMix) * 0.08
            let burst = KoncluiAlarmClockMotion.burstIndex(elapsed: elapsed)
            if cue == .overdue && burst != lastBurst { koru.emit(.sweat, count: 1) }
            lastBurst = burst
        } else if !settled {
            settle()
        }

        // Her canvas is square, as tall as the stage, at its left; she stands as HubMochiTroupe stands a lone Mochi.
        let side = size.height
        let lift = side - side * 0.92
        var her = context
        her.translateBy(x: 0, y: lift)
        let box = CGSize(width: side, height: side)
        koru.draw(context: her, size: box)
        koru.drawHandsAndExtras(context: her, size: box)

        let hands = KoncluiAlarmClockMotion.hands(at: due)
        let pose = KoncluiAlarmClock.Pose(
            hour: hands.hour, minute: hands.minute,
            second: live ? KoncluiAlarmClockMotion.secondHand(at: date) : nil,
            swing: ringing && live ? KoncluiAlarmClockMotion.swing(elapsed: elapsed) : 0,
            ring: ringing ? (live ? KoncluiAlarmClockMotion.strength(elapsed: elapsed) : 0.8) : 0,
            late: lateMix)
        KoncluiAlarmClock.draw(context, centerX: side * (0.5 + Self.clockOffset),
                               base: lift + KoruScenes.rest(canvasWidth: side).base,
                               unit: side * Self.clockUnit, pose: pose)
    }

    /// Her clock stands to her right, a little below her eyes; at the time, her state's own look turns her to it as well.
    private func look(atClock: Bool) {
        self.atClock = atClock
        koru.lookX = atClock ? 0.7 : 0
        koru.lookY = atClock ? 0.25 : 0
    }

    private func enter(_ new: KoncluiReminderAlertRules.Cue, live: Bool, now: Double) {
        let wasRinging = cue == .ringing || cue == .overdue
        cue = new
        settled = false
        koru.setState(new == .waiting ? .idle : .approval)
        guard new != .waiting, !wasRinging else { return }
        // The alarm starts: the first burst and her start are one beat.
        ringStart = now
        lastBurst = new == .overdue ? -1 : 0
        if live { koru.triggerEmote(.surprised, silent: true) }
    }

    /// Reduce Motion: no frame runs, so her eased values and badge jump to the state's (MOTION.md A11Y-03, "jump tweens to
    /// their end"); the tweens left half-way stay where they are, never drawn moving.
    private func settle() {
        look(atClock: true)
        for _ in 0..<60 { MochiFrameClock.advance(koru) }
        koru.badge = koru.cfg.badge
        koru.badgeS = 1
        lateMix = cue == .overdue ? 1 : 0
        settled = true
    }
}

/// The alarm clock, drawn in code as the Koru is: a dial on two feet, two bells and the hammer between them, in the accent
/// (amber once late) with the dial in the page's light text colour.
enum KoncluiAlarmClock {
    struct Pose {
        var hour: Double
        var minute: Double
        /// Nil draws no second hand (Reduce Motion, the editor's preview).
        var second: Double?
        /// −1 to 1: how far it rocks on its feet.
        var swing: Double = 0
        /// 0 to 1: the marks beside the bells.
        var ring: Double = 0
        /// 0 mint, 1 amber.
        var late: Double = 0
    }

    private static let ink = KoruRGB(hex: KoncluiPalette.onAccent)
    private static let mint = KoruRGB(hex: KoncluiPalette.accent)
    private static let amber = KoruRGB(hex: KoncluiPalette.attention)
    private static let paper = KoruRGB(hex: KoncluiPalette.textPrimary).color()

    /// `base` is the floor under its feet; the clock is about `unit` tall.
    static func draw(_ context: GraphicsContext, centerX: CGFloat, base: CGFloat, unit u: CGFloat, pose: Pose) {
        var c = context
        c.translateBy(x: centerX, y: base)
        c.rotate(by: .radians(pose.swing * 0.12))
        let ink = Self.ink
        let tone = Self.mint.mix(Self.amber, CGFloat(pose.late))
        let light = tone.mix(.white, 0.35), shade = tone.mix(ink, 0.4), deep = tone.mix(ink, 0.62)
        let dial = CGPoint(x: 0, y: -0.43 * u)
        let r = 0.3 * u

        for side: CGFloat in [-1, 1] {
            var foot = Path()
            foot.move(to: CGPoint(x: side * 0.15 * u, y: dial.y + r * 0.75))
            foot.addLine(to: CGPoint(x: side * 0.24 * u, y: -0.03 * u))
            c.stroke(foot, with: .color(deep.color()), style: StrokeStyle(lineWidth: 0.075 * u, lineCap: .round))
        }
        hammer(c, at: CGPoint(x: 0, y: dial.y - r), unit: u, swing: pose.swing, color: deep)
        for side: CGFloat in [-1, 1] {
            bell(c, side: side, dial: dial, radius: r, unit: u, ring: pose.ring, light: light, shade: shade, tone: tone)
        }
        face(c, center: dial, radius: r, unit: u, light: light, shade: shade, ink: ink)
        hands(c, center: dial, radius: r, unit: u, pose: pose, ink: ink, shade: shade, deep: deep)
    }

    private static func hammer(_ context: GraphicsContext, at top: CGPoint, unit u: CGFloat, swing: Double, color: KoruRGB) {
        var c = context
        c.translateBy(x: top.x, y: top.y)
        c.rotate(by: .radians(swing * 0.6))   // it beats between the bells, wider than the clock rocks
        var stem = Path()
        stem.move(to: .zero)
        stem.addLine(to: CGPoint(x: 0, y: -0.12 * u))
        c.stroke(stem, with: .color(color.color()), style: StrokeStyle(lineWidth: 0.04 * u, lineCap: .round))
        c.fill(Path(ellipseIn: CGRect(x: -0.04 * u, y: -0.17 * u, width: 0.08 * u, height: 0.08 * u)), with: .color(color.color()))
    }

    private static func bell(_ context: GraphicsContext, side: CGFloat, dial: CGPoint, radius r: CGFloat, unit u: CGFloat,
                             ring: Double, light: KoruRGB, shade: KoruRGB, tone: KoruRGB) {
        let angle = side * 0.72
        var c = context
        c.translateBy(x: dial.x + sin(angle) * r * 1.02, y: dial.y - cos(angle) * r * 1.02)
        c.rotate(by: .radians(angle))
        let dome = 0.15 * u
        var shell = Path()
        shell.addArc(center: .zero, radius: dome, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
        shell.closeSubpath()
        c.fill(shell, with: .linearGradient(Gradient(colors: [light.color(), shade.color()]),
                                            startPoint: CGPoint(x: -dome, y: -dome), endPoint: CGPoint(x: dome, y: 0)))
        c.fill(Path(ellipseIn: CGRect(x: -0.03 * u, y: -dome - 0.045 * u, width: 0.06 * u, height: 0.06 * u)),
               with: .color(shade.color()))
        guard ring > 0.01 else { return }
        for (index, reach) in [0.27, 0.37].enumerated() {
            var mark = Path()
            mark.addArc(center: .zero, radius: reach * u, startAngle: .degrees(-90 - 24), endAngle: .degrees(-90 + 24),
                        clockwise: false)
            c.stroke(mark, with: .color(tone.color(CGFloat(ring) * (index == 0 ? 0.95 : 0.6))),
                     style: StrokeStyle(lineWidth: 0.04 * u, lineCap: .round))
        }
    }

    private static func face(_ c: GraphicsContext, center: CGPoint, radius r: CGFloat, unit u: CGFloat,
                             light: KoruRGB, shade: KoruRGB, ink: KoruRGB) {
        let rim = Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: 2 * r, height: 2 * r))
        c.fill(rim, with: .linearGradient(Gradient(colors: [light.color(), shade.color()]),
                                          startPoint: CGPoint(x: center.x - r, y: center.y - r),
                                          endPoint: CGPoint(x: center.x + r, y: center.y + r)))
        let inner = 0.8 * r
        let dial = Path(ellipseIn: CGRect(x: center.x - inner, y: center.y - inner, width: 2 * inner, height: 2 * inner))
        c.fill(dial, with: .color(paper))
        c.stroke(dial, with: .color(ink.color(0.18)), lineWidth: 0.02 * u)
        for hour in 0..<12 {
            let a = Double(hour) / 12 * 2 * .pi
            let direction = CGPoint(x: sin(a), y: -cos(a))
            if hour % 3 == 0 {
                var tick = Path()
                tick.move(to: CGPoint(x: center.x + direction.x * inner * 0.72, y: center.y + direction.y * inner * 0.72))
                tick.addLine(to: CGPoint(x: center.x + direction.x * inner * 0.86, y: center.y + direction.y * inner * 0.86))
                c.stroke(tick, with: .color(ink.color(0.55)), style: StrokeStyle(lineWidth: 0.03 * u, lineCap: .round))
            } else {
                let dot = 0.012 * u, at = CGPoint(x: center.x + direction.x * inner * 0.8, y: center.y + direction.y * inner * 0.8)
                c.fill(Path(ellipseIn: CGRect(x: at.x - dot, y: at.y - dot, width: 2 * dot, height: 2 * dot)),
                       with: .color(ink.color(0.35)))
            }
        }
    }

    private static func hands(_ c: GraphicsContext, center: CGPoint, radius r: CGFloat, unit u: CGFloat, pose: Pose,
                              ink: KoruRGB, shade: KoruRGB, deep: KoruRGB) {
        func hand(_ angle: Double, length: CGFloat, tail: CGFloat = 0, width: CGFloat, color: Color) {
            let direction = CGPoint(x: sin(angle), y: -cos(angle))
            var path = Path()
            path.move(to: CGPoint(x: center.x - direction.x * tail, y: center.y - direction.y * tail))
            path.addLine(to: CGPoint(x: center.x + direction.x * length, y: center.y + direction.y * length))
            c.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round))
        }
        hand(pose.hour, length: 0.4 * r, width: 0.05 * u, color: ink.color(0.9))
        hand(pose.minute, length: 0.6 * r, width: 0.035 * u, color: ink.color(0.9))
        if let second = pose.second {
            hand(second, length: 0.66 * r, tail: 0.14 * r, width: 0.016 * u, color: shade.color())
        }
        let cap = 0.035 * u
        c.fill(Path(ellipseIn: CGRect(x: center.x - cap, y: center.y - cap, width: 2 * cap, height: 2 * cap)),
               with: .color(deep.color()))
    }
}
#endif
