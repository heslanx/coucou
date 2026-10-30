#if !APPSTORE
import SwiftUI

// Koncluí: the live notch preview above the WhatsApp block in Settings. It plays what the notch does with the options
// being edited, as a loop of beats (KoncluiWATimeline, tested): the closed notch at rest, a message arriving, the island
// opening on the card with the message typed in, a muted group that changes nothing, a Focus that holds the message, a
// chat opened and marked read. Nothing in it is real: sample conversations through the real inbox, no network, no sound,
// and nothing on it can be clicked (a right click on a row would otherwise offer "Ignore this chat" on a sample).
//
// The pieces are the notch's own: the island shape and sizes (IslandShape, islandSize), its open and close motion, the
// character's place (botPosition), the rows (WhatsAppRow), the lit pill's badge (PillBadgeView). The card's header and the
// status layout repeat WhatsAppCardView's (that view reads the live controller, so it cannot take samples). Keep them in
// step when upstream changes the card.
//
// Cost: the loop is a task and Koru's two canvases tick only while the hub window is on screen and the preview is in it
// (`hubVisible`); hidden, nothing runs. Reduce Motion: no spring, no hop, no typing and no pulse; every beat holds 2.5 s
// and the stage crossfades between them.

struct KoncluiWhatsAppPreview: View {
    let link: KoncluiWALink
    let options: KoncluiWAPreviewOptions
    let copy: KoncluiWASampleCopy
    @Binding var simulateFocus: Bool

    @Environment(\.hubVisible) private var hubVisible
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var beats: [KoncluiWABeat]
    /// The beat on the stage.
    @State private var index: Int
    /// Where the loop (re)starts: the beat after a restart, the beat that was playing after the window comes back.
    @State private var startAt = 0
    @State private var restarts = 0
    @State private var onScreen = false
    /// Characters of the newest message typed in so far; nil shows it whole.
    @State private var typed: Int?
    @State private var pulse = false
    @StateObject private var koru = KoncluiWAStageKoru()

    private static let accent = Color(hex: whatsAppAccent)
    private static let margin: CGFloat = 12
    /// Biggest first: the stage hugs the island, and a narrow window gets a smaller island, not a cut one.
    private static let scales: [CGFloat] = [0.8, 0.66, 0.54]
    private static let closed = islandSize(mode: .compact, view: .overview)
    private static let expanded = islandSize(mode: .expanded, view: .overview)

    init(link: KoncluiWALink, options: KoncluiWAPreviewOptions, copy: KoncluiWASampleCopy, simulateFocus: Binding<Bool>) {
        self.link = link
        self.options = options
        self.copy = copy
        _simulateFocus = simulateFocus
        let beats = KoncluiWATimeline.beats(link: link, options: options, copy: copy)
        _beats = State(initialValue: beats)
        _index = State(initialValue: min(KoncluiWAPreviewDebug.frozenBeat ?? 0, beats.count - 1))
    }

    private struct Inputs: Equatable {
        var link: KoncluiWALink
        var options: KoncluiWAPreviewOptions
        var copy: KoncluiWASampleCopy
    }

    private struct LoopID: Equatable {
        var playing: Bool
        var restarts: Int
    }

    private var inputs: Inputs { Inputs(link: link, options: options, copy: copy) }
    private var shown: KoncluiWABeat { beats[min(index, beats.count - 1)] }
    private var visible: Bool { hubVisible && onScreen }
    private var ticking: Bool { visible && !reduceMotion }
    private var playing: Bool { visible && KoncluiWAPreviewDebug.frozenBeat == nil }
    private var pulsing: Bool { ticking && shown.open && shown.status?.pulses == true }

    // MARK: - Body

    var body: some View {
        ViewThatFits(in: .horizontal) {
            block(scale: Self.scales[0])
            block(scale: Self.scales[1])
            block(scale: Self.scales[2])
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            onScreen = true
            if KoncluiWAPreviewDebug.focus { simulateFocus = true }
            koru.show(shown, still: reduceMotion)
        }
        .onDisappear { onScreen = false }
        .onChange(of: inputs) { old, new in restart(from: old, to: new) }
        .onChange(of: pulsing) { _, on in
            withAnimation(on ? .easeInOut(duration: 1.2).repeatForever(autoreverses: true) : .easeOut(duration: 0.2)) { pulse = on }
        }
        .task(id: LoopID(playing: playing, restarts: restarts)) { await play() }
    }

    private func block(scale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            stage(scale: scale)
            footer
        }
        .frame(width: Self.expanded.0 * scale + 2 * Self.margin)
    }

    // MARK: - The loop

    /// The options or the link changed: the beats are rebuilt and the loop starts over at the beat that shows what changed.
    private func restart(from old: Inputs, to new: Inputs) {
        let fresh = KoncluiWATimeline.beats(link: new.link, options: new.options, copy: new.copy)
        defer { beats = fresh }
        if let frozen = KoncluiWAPreviewDebug.frozenBeat {
            index = min(frozen, fresh.count - 1)
            return
        }
        if old.link == new.link && old.copy == new.copy {
            // A change that shows nothing new keeps the loop where it is.
            guard let first = KoncluiWATimeline.restartIndex(from: old.options, to: new.options, in: fresh) else { return }
            startAt = first
        } else {
            startAt = 0
        }
        restarts += 1
    }

    @MainActor private func play() async {
        guard playing, !beats.isEmpty else { return }
        var next = min(startAt, beats.count - 1)
        while !Task.isCancelled {
            guard await perform(next) else { return }
            next = (next + 1) % beats.count
            // A new lap: the messages arrive "just now" again.
            if next == 0 { beats = KoncluiWATimeline.beats(link: link, options: options, copy: copy) }
        }
    }

    /// One beat: the stage moves to it, its reaction and typing happen at their times, and it holds until its time is up.
    /// False when the loop was cancelled meanwhile.
    @MainActor private func perform(_ at: Int) async -> Bool {
        let beat = beats[at]
        let wasOpen = shown.open
        startAt = at
        let motion: Animation = reduceMotion ? KoncluiWAMotion.crossfade
            : beat.open || !wasOpen ? KoncluiWAMotion.open : KoncluiWAMotion.close
        withAnimation(motion) {
            index = at
            typed = beat.typing == nil || reduceMotion ? nil : 0
        }
        koru.show(beat, still: reduceMotion)

        // Deadlines from the beat's start, so a late wake-up never stretches the beat.
        let clock = ContinuousClock()
        let begin = clock.now
        func wait(until time: Double) async -> Bool {
            do { try await clock.sleep(until: begin.advanced(by: .seconds(time))) } catch { return false }
            return true
        }
        if reduceMotion { return await wait(until: KoncluiWATimeline.reducedMotionSeconds) }
        if beat.reaction == .lights {
            guard await wait(until: KoncluiWATimeline.hopDelay) else { return false }
            koru.hop()
        }
        let length = beat.typingLength
        if length > 0 {
            guard await wait(until: KoncluiWATimeline.typingDelay) else { return false }
            let step = KoncluiWATimeline.typingInterval(length: length)
            for count in 1...length {
                typed = count
                guard await wait(until: KoncluiWATimeline.typingDelay + step * Double(count)) else { return false }
            }
            typed = nil
        }
        return await wait(until: beat.seconds)
    }

    // MARK: - The stage

    private func stage(scale: CGFloat) -> some View {
        let beat = shown
        return ZStack(alignment: .top) {
            ZStack(alignment: .top) {
                LinearGradient(colors: [Color(hex: "#2A3050"), Color(hex: "#171A2A"), Color(hex: "#10121C")],
                               startPoint: .top, endPoint: .bottom)
                menuBar(height: Self.closed.1 * scale)
                    .opacity(beat.open ? 0 : 1)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: beat.open)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.white.opacity(0.08))
            island(beat)
                .id(reduceMotion ? beat.open : false)   // Reduce Motion: a new island fades in, none grows
                .transition(.opacity)
                .frame(width: Self.expanded.0, height: Self.expanded.1, alignment: .top)
                .scaleEffect(scale, anchor: .top)
                .frame(width: Self.expanded.0 * scale, height: Self.expanded.1 * scale, alignment: .top)
            chip(beat)
                .padding(.top, Self.closed.1 * scale + 10)
        }
        .frame(width: Self.expanded.0 * scale + 2 * Self.margin, height: Self.expanded.1 * scale + Self.margin)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("konclui.whatsapp.preview.label"))
        .accessibilityValue(Text(verbatim: line(for: beat.note)))
    }

    /// The Mac's menu bar behind the notch, so the closed strip reads as a notch and not as a floating pill.
    private func menuBar(height: CGFloat) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "applelogo")
            ForEach([26.0, 34.0, 22.0], id: \.self) { width in
                Capsule().fill(Color.white.opacity(0.2)).frame(width: width, height: 4)
            }
            Spacer(minLength: 0)
            Image(systemName: "wifi")
            Image(systemName: "battery.100")
        }
        .font(.system(size: 9))
        .foregroundColor(Color.white.opacity(0.45))
        .padding(.horizontal, 10)
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.3))
    }

    /// The island in the size, corners and place for the beat: closed is the notch's compact strip, open is the overview.
    private func island(_ beat: KoncluiWABeat) -> some View {
        let open = beat.open
        let size = open ? Self.expanded : Self.closed
        let corner = open ? IslandConst.expandedCorner : IslandConst.roundedCorner
        let shape = IslandShape(width: size.0, height: size.1, cornerRadius: corner, topRadius: 0)
        let place = botPosition(mode: open ? .expanded : .compact, view: .overview, islandW: size.0, islandH: size.1,
                                uploadProgress: 0)
        return ZStack(alignment: .topLeading) {
            shape.fill(Color.black).shadow(color: .black.opacity(0.45), radius: 12, y: 6)
            card(beat)
                .frame(width: size.0, height: size.1, alignment: .topLeading)
                .clipShape(shape)
                .opacity(open ? 1 : 0)
                .animation(open ? .easeOut(duration: 0.22).delay(0.1) : .easeIn(duration: 0.12), value: open)
            closedStrip(beat, width: size.0, height: size.1)
                .opacity(open ? 0 : 1)
                .animation(open ? .easeIn(duration: 0.1) : .easeOut(duration: 0.2).delay(0.12), value: open)
            // Koru rides the island: the strip's left end when closed, the card's left when open (BotPlacement).
            KoncluiWAKoruCanvas(engine: koru.main, ticking: ticking, tint: open ? KoncluiWAStageKoru.green : nil)
                .frame(width: place.2 / 0.6, height: place.2 / 0.6)
                .position(x: place.0, y: place.1)
                .mask(alignment: .topLeading) { Rectangle().frame(width: size.0, height: open ? 320 : size.1) }
        }
        .frame(width: size.0, height: size.1, alignment: .topLeading)
        .foregroundColor(Color(hex: "#F5F6F8"))
    }

    /// The closed notch's right end: WhatsApp's mini Koru, lit while a message has just arrived (CompactMiniGrid).
    private func closedStrip(_ beat: KoncluiWABeat, width: CGFloat, height: CGFloat) -> some View {
        let lit = beat.reaction == .lights
        return ZStack {
            KoncluiWAKoruCanvas(engine: koru.mini, ticking: ticking, tint: KoncluiWAStageKoru.green)
                .frame(width: 12 / 0.6, height: 12 / 0.6)
                .frame(width: 12, height: 12)
            if lit {
                PillBadgeView(badge: .finished, taskColor: whatsAppAccent)
                    .offset(x: 8, y: -7)
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.2).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.6).delay(KoncluiWATimeline.hopDelay), value: lit)
        .position(x: width - 48, y: height / 2)
    }

    /// What the closed notch deliberately does not show, written beside it: a muted group, or a message a Focus holds.
    /// It waits for the island to finish closing before it shows.
    private func chip(_ beat: KoncluiWABeat) -> some View {
        ZStack {
            switch beat.note {
            case .muted(let name):
                annotation("speaker.slash.fill", "\(name) · \(String(localized: "konclui.whatsapp.preview.muted"))", color: KoncluiTheme.textBody)
            case .held(let name):
                annotation("moon.fill", "\(name) · \(String(localized: "konclui.whatsapp.preview.held"))", color: KoncluiTheme.attention)
            default:
                EmptyView()
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .animation(.easeOut(duration: 0.25).delay(reduceMotion ? 0 : 0.3), value: beat.note)
    }

    private func annotation(_ symbol: String, _ text: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol).font(.system(size: 9))
            Text(verbatim: text).font(.system(size: 11))
        }
        .foregroundColor(color)
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(Color.black.opacity(0.4), in: Capsule())
        .overlay(Capsule().strokeBorder(color.opacity(0.35)))
        .transition(.opacity)
    }

    // MARK: - Under the stage

    private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            // What the beat on the stage shows, in words (UX.md, habit 10): the stage's value says it for VoiceOver.
            Text(verbatim: line(for: shown.note))
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(KoncluiTheme.textBody)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: 15, alignment: .leading)
                .transaction { $0.animation = nil }   // the words change at once: two lines cross-fading overlap
                .help(line(for: shown.note))
                .accessibilityHidden(true)
            HStack(alignment: .top, spacing: 10) {
                Text("konclui.whatsapp.preview.caption")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#8E939C"))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if link == .connected {
                    Toggle(isOn: $simulateFocus) {
                        Label("konclui.whatsapp.preview.focus-chip", systemImage: "moon.fill")
                            .font(.system(size: 11))
                    }
                    .toggleStyle(.button)
                    .controlSize(.small)
                    .pointerStyle(.link)
                }
            }
        }
        .padding(.horizontal, 2)
    }

    /// The beat's note in the person's language.
    private func line(for note: KoncluiWABeat.Note) -> String {
        switch note {
        case .waiting:
            return String(localized: "konclui.whatsapp.preview.note.waiting")
        case .arrives(.direct, let name):
            return String(format: String(localized: "konclui.whatsapp.preview.note.arrives.direct %@"), name)
        case .arrives(.mention, let name):
            return String(format: String(localized: "konclui.whatsapp.preview.note.arrives.mention %@"), name)
        case .arrives(.group, let name):
            return String(format: String(localized: "konclui.whatsapp.preview.note.arrives.group %@"), name)
        case .muted(let name):
            return String(format: String(localized: "konclui.whatsapp.preview.cause.muted %@"), name)
        case .held(let name):
            return String(format: String(localized: "konclui.whatsapp.preview.note.held %@"), name)
        case .opened:
            return String(localized: "konclui.whatsapp.preview.note.opened")
        case .markedRead(let name):
            return String(format: String(localized: "konclui.whatsapp.preview.note.read %@"), name)
        case .stillUnread(let name):
            return String(format: String(localized: "konclui.whatsapp.preview.note.unread %@"), name)
        case .waitingHere:
            return String(localized: "konclui.whatsapp.preview.focus-note")
        case .status(let link):
            return WhatsAppStatus.label(link.real)
        }
    }

    // MARK: - The card

    @ViewBuilder private func card(_ beat: KoncluiWABeat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let status = beat.status {
                header(unread: 0)
                statusLine(status)
            } else {
                header(unread: beat.unread)
                if beat.focusNote { focusNote }
                list(beat)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, 4)
        .frame(width: Self.expanded.0 - 20, height: 98, alignment: .topLeading)
        .offset(x: 10, y: 42)
        .frame(width: Self.expanded.0, height: Self.expanded.1, alignment: .topLeading)
        .foregroundColor(Color(hex: "#F5F6F8"))
    }

    private func header(unread: Int) -> some View {
        HStack(spacing: 6) {
            Circle().fill(Self.accent).frame(width: 7, height: 7)
            Text(verbatim: "WhatsApp")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(hex: "#F5F6F8"))
            if unread > 0 {
                Text(String(format: String(localized: "%lld unread"), Int64(unread)))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Self.accent)
                    .monospacedDigit()
                    .padding(.horizontal, 6).padding(.vertical, 1)
                    .background(Self.accent.opacity(0.14))
                    .clipShape(Capsule())
            }
            Spacer(minLength: 2)
        }
        .padding(.top, 6)
        .padding(.leading, 108)
        .padding(.trailing, 36)
    }

    private var focusNote: some View {
        HStack(spacing: 5) {
            Image(systemName: "moon.fill").font(.system(size: 9))
            Text("konclui.whatsapp.preview.focus-note").font(.system(size: 11))
        }
        .foregroundColor(KoncluiTheme.attention)
        .padding(.top, 5)
        .padding(.leading, 108)
    }

    private func list(_ beat: KoncluiWABeat) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(beat.rows) { sample in
                let row = sample.kind == beat.typing ? sample.typed(typed ?? .max) : sample
                WhatsAppRow(conversation: row.conversation)
                    .background {
                        // The pointer on the row it opens, as the row does when hovered.
                        if beat.pointing == sample.kind { RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.06)) }
                    }
                    .overlay(alignment: .leading) {
                        if beat.pointing == sample.kind {
                            Image(systemName: "cursorarrow")
                                .font(.system(size: 13))
                                .foregroundColor(.white)
                                .shadow(color: .black, radius: 1.5)
                                .padding(.leading, 300)
                                .offset(y: 7)
                                .transition(reduceMotion ? .opacity : .scale(scale: 0.4).combined(with: .opacity))
                        }
                    }
                    .transition(reduceMotion ? .opacity
                                : .asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
            }
        }
        .padding(.top, 5)
        .padding(.leading, 108)
        .padding(.trailing, 12)
    }

    /// Not connected: the link's own words, pulsing while it is trying (UX.md, 1.1: the preview never fakes a message).
    private func statusLine(_ link: KoncluiWALink) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Circle().fill(WhatsAppStatus.dot(link.real)).frame(width: 5, height: 5)
                Text(WhatsAppStatus.label(link.real))
                    .font(.system(size: 11))
                    .foregroundColor(KoncluiTheme.textTertiary)
                    .lineLimit(1).truncationMode(.tail)
            }
            Text("Settings…")
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "#8E939C"))
        }
        .opacity(pulsing ? (pulse ? 1 : 0.45) : 1)
        .padding(.top, 8)
        .padding(.leading, 108)
    }
}

// MARK: - Motion

enum KoncluiWAMotion {
    /// The island's own: IslandContainer.openSpring and closeEase (IslandRootView.swift), private there. Keep them in step.
    static let open = Animation.spring(response: 0.5, dampingFraction: 0.72)
    static let close = Animation.timingCurve(0.45, 0, 0.2, 1, duration: 0.34)
    /// Reduce Motion: one island fades out as the next fades in.
    static let crossfade = Animation.easeInOut(duration: 0.35)
}

// MARK: - Koru

/// The two characters of the stage, drawn in a canvas each: Koru at the island's left, and WhatsApp's mini Koru at the
/// closed strip's right. Their engines persist, so a hop carries on while the island moves.
@MainActor
final class KoncluiWAStageKoru: ObservableObject {
    let main = BotEngine()
    let mini = BotEngine()
    static let green = cgColorFromHex(whatsAppAccent)

    init() {
        mini.isMini = true
        for engine in [main, mini] { for _ in 0..<12 { MochiFrameClock.advance(engine) } }
    }

    /// The beat starts: a message that just arrived puts the WhatsApp mini in its "finished" pose, as the controller
    /// does to its pill. `still`: Reduce Motion keeps the poses.
    func show(_ beat: KoncluiWABeat, still: Bool) {
        if !still { mini.setState(beat.reaction == .lights ? .finished : .idle) }
    }

    /// A message reaches you: the happy emote the controller posts, with a hop (WhatsAppController.announce).
    func hop() {
        main.triggerEmote(.happy, silent: true)
        main.squash()
    }
}

private struct KoncluiWAKoruCanvas: View {
    let engine: BotEngine
    let ticking: Bool
    /// WhatsApp's green once the card is open (WhatsApp is the focus); the notch's own colours otherwise.
    let tint: CGColor?

    var body: some View {
        TimelineView(.animation(paused: !ticking)) { timeline in
            // The canvas must capture the frame's date, or it is not redrawn (BotCanvasView).
            let frame = timeline.date
            Canvas { context, size in
                _ = frame
                engine.bodyColor = tint
                if ticking { MochiFrameClock.advance(engine) }
                engine.draw(context: context, size: size)
            }
        }
    }
}

// MARK: - Screenshots (DEBUG builds only)

/// `-konclui.debug.whatsappBeat <n>` freezes the preview on beat n (counted from 0, see KoncluiWATimeline.beats) and
/// `-konclui.debug.whatsappFocus 1` starts it with its own "Preview a Focus" chip on. Neither reads or writes a setting.
/// In a release build both are always off.
enum KoncluiWAPreviewDebug {
    static var frozenBeat: Int? {
        #if DEBUG
        UserDefaults.standard.string(forKey: "konclui.debug.whatsappBeat").flatMap { Int($0) }.map { max(0, $0) }
        #else
        nil
        #endif
    }

    static var focus: Bool {
        #if DEBUG
        UserDefaults.standard.string(forKey: "konclui.debug.whatsappFocus") == "1"
        #else
        false
        #endif
    }
}

extension KoncluiWALink {
    init(_ link: WhatsAppController.Link) {
        switch link {
        case .off:               self = .off
        case .connecting:        self = .connecting
        case .needsQR:           self = .needsQR
        case .connected:         self = .connected
        case .unreachable:       self = .unreachable
        case .unauthorized:      self = .unauthorized
        case .failed(let why):   self = .failed(why)
        }
    }

    var real: WhatsAppController.Link {
        switch self {
        case .off:               return .off
        case .connecting:        return .connecting
        case .needsQR:           return .needsQR
        case .connected:         return .connected
        case .unreachable:       return .unreachable
        case .unauthorized:      return .unauthorized
        case .failed(let why):   return .failed(why)
        }
    }
}
#endif
