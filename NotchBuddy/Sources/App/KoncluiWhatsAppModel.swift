import Foundation

// Koncluí's WhatsApp block in Settings → Integrations (design/konclui/whatsapp, version 8 with version 7's live notch
// preview): the rules behind it, pure Foundation so scripts/konclui/test-whatsapp-preview.sh runs them without the app.
// Three things live here: how a phone number reads, which stage the block is in for the state of the install and the
// link, and which sample messages the preview shows for the options being edited. The views are in
// KoncluiWhatsAppSection.swift and KoncluiWhatsAppPreview.swift.

// MARK: - Phone number

enum KoncluiPhone {
    /// "5511912345678:12@s.whatsapp.net" → "+55 11 91234-5678". An id that is not a phone number (a linked-device id,
    /// a group) and a number of a country this does not know stay as `WAJID.displayNumber` writes them.
    static func format(_ jid: String) -> String {
        let plain = WAJID.displayNumber(jid)
        if let server = jid.split(separator: "@", maxSplits: 1).dropFirst().first,
           !["s.whatsapp.net", "c.us"].contains(String(server)) { return plain }
        guard plain.hasPrefix("+") else { return plain }
        let digits = String(plain.dropFirst())
        guard !digits.isEmpty, digits.allSatisfy(\.isNumber) else { return plain }
        // Longest country code first: 351 before 35…, 55 before 5….
        for length in [3, 2, 1] where digits.count > length {
            let code = String(digits.prefix(length))
            let national = String(digits.dropFirst(length))
            if let local = local(national, code: code) { return "+\(code) \(local)" }
        }
        return plain
    }

    private static func local(_ n: String, code: String) -> String? {
        switch code {
        case "55":   // Brazil: area code, then 4 or 5 digits, a hyphen and 4 digits
            guard n.count == 10 || n.count == 11 else { return nil }
            return "\(n.prefix(2)) \(n.dropFirst(2).dropLast(4))-\(n.suffix(4))"
        case "1":    // United States and Canada
            guard n.count == 10 else { return nil }
            return "\(n.prefix(3)) \(n.dropFirst(3).prefix(3))-\(n.suffix(4))"
        case "33":   // France: 6 12 34 56 78
            guard n.count == 9 else { return nil }
            return "\(n.prefix(1)) " + pairs(String(n.dropFirst()))
        case "351", "34":   // Portugal, Spain: 912 345 678
            guard n.count == 9 else { return nil }
            return "\(n.prefix(3)) \(n.dropFirst(3).prefix(3)) \(n.suffix(3))"
        case "44":   // United Kingdom: 7911 123456
            guard n.count == 10 else { return nil }
            return "\(n.prefix(4)) \(n.suffix(6))"
        default:
            return nil
        }
    }

    private static func pairs(_ s: String) -> String {
        stride(from: 0, to: s.count, by: 2).map { i in
            let start = s.index(s.startIndex, offsetBy: i)
            return String(s[start..<s.index(start, offsetBy: min(2, s.count - i))])
        }.joined(separator: " ")
    }
}

// MARK: - Doors: what a number or a chat offers

/// A WhatsApp number, or a chat, is a door (UX.md, 1.2): clicking it opens a small popover with a few likely actions.
/// The most likely action is first and the order is fixed per kind of data.
enum KoncluiWADoor {
    enum Action: Equatable, Sendable {
        case openChat, copyNumber, copyChatId, stopIgnoring
    }

    /// A person's chat id, not a group or a linked-device id: only those carry a phone number.
    static func isPerson(_ jid: String) -> Bool {
        let parts = jid.split(separator: "@", maxSplits: 1).map(String.init)
        guard parts.count == 2, ["s.whatsapp.net", "c.us"].contains(parts[1]) else { return false }
        let digits = parts[0].split(separator: ":").first.map(String.init) ?? parts[0]
        return (7...15).contains(digits.count) && digits.allSatisfy(\.isNumber)
    }

    static func actions(for jid: String, ignored: Bool) -> [Action] {
        var actions: [Action] = isPerson(jid) ? [.openChat, .copyNumber] : [.copyChatId]
        if ignored { actions.append(.stopIgnoring) }
        return actions
    }

    /// Opens WhatsApp on that person's chat. Nothing is sent: it only shows the chat.
    static func chatURL(_ jid: String) -> URL? {
        guard isPerson(jid) else { return nil }
        return URL(string: "whatsapp://send?phone=" + String(WAJID.displayNumber(jid).dropFirst()))
    }

    /// What "Copy" puts on the clipboard: the number with its plus sign for a person, else the chat id as it is.
    static func copyText(_ jid: String) -> String { isPerson(jid) ? WAJID.displayNumber(jid) : jid }
}

// MARK: - Validation while typing

enum KoncluiWAIgnore {
    enum Entry: Equatable, Sendable {
        case empty
        case invalid
        case chat(String)
    }

    /// A phone number ("+33 6 12…") or a full chat id ("…@g.us"), as WhatsAppSettingsSection accepted them, but a number
    /// needs at least 7 digits and an id needs something before its "@".
    static func parse(_ raw: String) -> Entry {
        let text = raw.trimmingCharacters(in: .whitespaces)
        if text.isEmpty { return .empty }
        if text.contains("@") {
            let parts = text.split(separator: "@", maxSplits: 1, omittingEmptySubsequences: false)
            return parts.count == 2 && !parts[0].isEmpty && !parts[1].isEmpty ? .chat(text) : .invalid
        }
        let digits = text.filter(\.isNumber)
        return digits.count >= 7 ? .chat(digits + "@s.whatsapp.net") : .invalid
    }
}

enum KoncluiWAAdvanced {
    /// The webhook port field: empty keeps the default; anything else must be a number Koncluí can listen on.
    static func portProblem(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return false }
        guard let port = Int(t) else { return true }
        return !(1024...65535).contains(port)
    }

    /// The gateway address field: empty means the default; otherwise an http(s) address with a host.
    static func addressProblem(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return false }
        guard let url = URL(string: t), let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) else { return true }
        return (url.host ?? "").isEmpty
    }
}

// MARK: - What the block is in

/// The install, as the installer reports it (WhatsAppGOWAInstaller.Step without its payloads).
enum KoncluiWAInstallPhase: Equatable, Sendable {
    case idle
    case checking
    case downloading(megabytes: Int)
    case verifying
    case installing
    case done
    case failed(String)

    var step: Int? {
        switch self {
        case .checking:    return 0
        case .downloading: return 1
        case .verifying:   return 2
        case .installing:  return 3
        default:           return nil
        }
    }
}

/// The link to the gateway, as the controller reports it (WhatsAppController.Link).
enum KoncluiWALink: Equatable, Sendable {
    case off
    case connecting
    case needsQR
    case connected
    case unreachable
    case unauthorized
    case failed(String)
}

/// Everything the block looks at. The view fills it from the live objects; the tests fill it by hand.
struct KoncluiWAInputs: Equatable, Sendable {
    /// "Show my WhatsApp messages".
    var enabled: Bool
    /// The WhatsApp pill is among the active ones (at most four fit).
    var hasRoom: Bool
    /// The saved gateway (not the one being edited under Advanced).
    var gateway: WAGatewayKind
    /// A GOWA binary Koncluí can start (the one it installed, or one the user picked).
    var installed: Bool
    /// The user saved a gateway address of their own.
    var addressSet: Bool
    var install: KoncluiWAInstallPhase
    var link: KoncluiWALink
}

enum KoncluiWAProblem: Equatable, Sendable {
    case stopped
    case unauthorized
    case other(String)
}

enum KoncluiWADot: Equatable, Sendable { case green, amber, red, gray }

/// Which of the block's shapes shows. The setup stages are a card that expands in place; the others are the calm line
/// (a problem adds its panel under the line).
enum KoncluiWAStage: Equatable, Sendable {
    /// Nothing to talk to yet: the unofficial-integration warning and "Install WhatsApp".
    case install
    /// The four install steps; `step` is the one running (0 to 3).
    case installing(step: Int)
    case installFailed(String)
    /// The gateway runs and WhatsApp is not linked: the QR.
    case scanning
    case problem(KoncluiWAProblem)
    case connected
    /// The gateway answers and is connecting to WhatsApp.
    case connecting
    /// Switched off.
    case off
    /// Switched on, but its pill is not among the active ones, so nothing would show.
    case noRoom

    var isSetup: Bool {
        switch self {
        case .install, .installing, .installFailed, .scanning: return true
        default: return false
        }
    }

    var dot: KoncluiWADot {
        switch self {
        case .connected:                         return .green
        case .installing, .scanning, .connecting: return .amber
        case .installFailed, .problem:           return .red
        case .install, .off, .noRoom:            return .gray
        }
    }
}

enum KoncluiWABlock {
    /// The install steps the card lists, in order (the installer's own labels).
    static let installSteps = 4

    /// Install in progress wins over everything; then no gateway to talk to yet (the old block's `showsLinkState`, unless
    /// a link already answers); then off, no room, and the link.
    static func stage(_ i: KoncluiWAInputs) -> KoncluiWAStage {
        if let step = i.install.step { return .installing(step: step) }
        let linked = i.link == .connected || i.link == .needsQR
        if i.gateway == .gowa, !i.installed, !i.addressSet, !linked {
            if case .failed(let why) = i.install { return .installFailed(why) }
            return .install
        }
        if !i.enabled { return .off }
        if !i.hasRoom { return .noRoom }
        switch i.link {
        case .connected:     return .connected
        case .needsQR:       return .scanning
        case .connecting, .off: return .connecting
        case .unreachable:   return .problem(.stopped)
        case .unauthorized:  return .problem(.unauthorized)
        case .failed(let m): return .problem(.other(m))
        }
    }
}

// MARK: - The live notch preview

/// The options the preview follows. `focusOn` is the preview's own "pretend a Focus is on" switch, not the Mac's state.
struct KoncluiWAPreviewOptions: Equatable, Sendable {
    var muteGroups: Bool
    var respectFocus: Bool
    var focusOn: Bool
    /// Opening a chat marks it read (and tells the sender).
    var markReadOnOpen = false

    /// A Focus is on and Koncluí respects it: new messages arrive without a reaction, a sound or a lit pill.
    var quiet: Bool { respectFocus && focusOn }
}

/// The words of the sample conversations (localized by the view; the English ones are the tests').
struct KoncluiWASampleCopy: Equatable, Sendable {
    var directName: String, directText: String
    var mentionName: String, mentionSender: String, mentionText: String
    var groupName: String, groupSender: String, groupText: String

    static let english = KoncluiWASampleCopy(
        directName: "Marina Costa", directText: "Dinner tonight?",
        mentionName: "Design team", mentionSender: "Carla", mentionText: "@you can you review the Figma?",
        groupName: "Family", groupSender: "Dad", groupText: "Sunday barbecue")
}

struct KoncluiWASample: Identifiable, Equatable, Sendable {
    enum Kind: Equatable, Sendable { case direct, mention, group }
    var kind: Kind
    var conversation: WAConversation
    /// A muted group: it stays out of the notch's list.
    var muted: Bool
    /// Listed, but arrives quietly because of the Focus.
    var quiet: Bool
    var id: String { conversation.id }

    /// The newest message typed in up to `count` characters, the way the preview shows a message arriving.
    func typed(_ count: Int) -> KoncluiWASample {
        var sample = self
        guard let last = sample.conversation.messages.indices.last else { return sample }
        sample.conversation.messages[last].text = String(sample.conversation.messages[last].text.prefix(max(0, count)))
        return sample
    }

    /// How many characters the newest message has: what `typed` goes through.
    var typingLength: Int { conversation.messages.last?.text.count ?? 0 }
}

enum KoncluiWAPreviewContent: Equatable, Sendable {
    case samples([KoncluiWASample])
    /// Not connected: the notch shows the link's own status line.
    case status(KoncluiWALink)
}

extension KoncluiWALink {
    /// The status line pulses while Koncluí is trying or has a problem to show; "off" is a choice, not a wait.
    var pulses: Bool { self != .off }
}

enum KoncluiWAPreview {
    static let directChat = "5511900000001@s.whatsapp.net"
    static let mentionChat = "120363000000000001@g.us"
    static let groupChat = "120363000000000002@g.us"

    static func content(link: KoncluiWALink, options: KoncluiWAPreviewOptions, copy: KoncluiWASampleCopy = .english,
                        now: Date = Date()) -> KoncluiWAPreviewContent {
        link == .connected ? .samples(samples(options: options, copy: copy, now: now)) : .status(link)
    }

    /// A direct message, a message in a group that mentions you, and one in a group that does not. They go through the
    /// real inbox with the real filters, so what is listed, muted or quiet here is what the notch does.
    /// `arrived` limits it to the conversations that already wrote, `fresh` stamps one conversation's newest message
    /// "just now", and `read` are the chats opened with "mark as read" on.
    static func samples(options: KoncluiWAPreviewOptions, copy: KoncluiWASampleCopy = .english,
                        now: Date = Date(), arrived: [KoncluiWASample.Kind] = [.direct, .mention, .group],
                        fresh: KoncluiWASample.Kind? = nil, read: Set<KoncluiWASample.Kind> = []) -> [KoncluiWASample] {
        let filters = WAFilters(muteGroups: options.muteGroups)
        var inbox = WAInbox()
        var outcome: [String: WAInbox.Outcome] = [:]

        func add(_ id: String, _ kind: KoncluiWASample.Kind, chat: String, name: String?, from sender: String, _ text: String,
                 media: WAMedia = .none, ago: Double, newest: Bool = false, mention: Bool = false) {
            guard arrived.contains(kind) else { return }
            let age = kind == fresh && newest ? justNow : ago
            var message = WAMessage(id: id, chat: chat, sender: sender, senderName: sender, text: text, media: media,
                                    date: now.addingTimeInterval(-age), mentionsMe: mention)
            message.chatName = name
            outcome[chat] = inbox.add(message, filters: filters)
        }
        add("preview-d1", .direct, chat: directChat, name: nil, from: copy.directName, copy.directText, ago: 150)
        add("preview-d2", .direct, chat: directChat, name: nil, from: copy.directName, copy.directText, ago: 120, newest: true)
        add("preview-m1", .mention, chat: mentionChat, name: copy.mentionName, from: copy.mentionSender, copy.mentionText,
            ago: 300, newest: true, mention: true)
        add("preview-g1", .group, chat: groupChat, name: copy.groupName, from: copy.groupSender, copy.groupText, ago: 760)
        add("preview-g2", .group, chat: groupChat, name: copy.groupName, from: copy.groupSender, copy.groupText, ago: 740)
        add("preview-g3", .group, chat: groupChat, name: copy.groupName, from: copy.groupSender, copy.groupText,
            media: .image, ago: 720, newest: true)

        let kinds: [String: KoncluiWASample.Kind] = [directChat: .direct, mentionChat: .mention, groupChat: .group]
        for kind in read { inbox.markRead(chat(of: kind)) }
        let listed = Set(inbox.visible(filters: filters).map(\.id))
        return inbox.sorted.compactMap { conversation in
            guard let kind = kinds[conversation.id] else { return nil }
            let muted = !listed.contains(conversation.id)
            let announces = outcome[conversation.id] == .notify
            return KoncluiWASample(kind: kind, conversation: conversation, muted: muted,
                                   quiet: announces && options.quiet)
        }
    }

    /// Seconds ago of a message that just arrived: the row reads "now".
    static let justNow = 4.0

    static func chat(of kind: KoncluiWASample.Kind) -> String {
        switch kind {
        case .direct:  return directChat
        case .mention: return mentionChat
        case .group:   return groupChat
        }
    }

    /// The count in the card's header: what the notch's list holds, never a muted group.
    static func unread(_ samples: [KoncluiWASample]) -> Int {
        samples.filter { !$0.muted }.reduce(0) { $0 + $1.conversation.unread }
    }
}

// MARK: - The preview's timeline

/// An option of the popover that changes what the preview shows (the beat that shows its effect starts over on a change).
enum KoncluiWAOption: Equatable, Sendable { case muteGroups, focus, markRead }

/// One moment of the loop the preview plays: what the notch is doing and what the card lists.
struct KoncluiWABeat: Equatable, Sendable {
    /// How the closed notch reacts to a message that just arrived.
    enum Reaction: Equatable, Sendable {
        case none
        /// Koru hops and the WhatsApp mini lights up.
        case lights
        /// A muted group: nothing moves.
        case muted
        /// A Focus holds the message: nothing moves.
        case held
    }

    /// What the line under the stage (and VoiceOver) says. The words are the view's; the rule is here.
    enum Note: Equatable, Sendable {
        case waiting
        case arrives(KoncluiWASample.Kind, String)
        case muted(String)
        case held(String)
        case opened
        case markedRead(String)
        case stillUnread(String)
        case waitingHere
        case status(KoncluiWALink)
    }

    /// The island is open on the card; otherwise it is the closed strip.
    var open: Bool
    var reaction: Reaction = .none
    var note: Note
    /// What the card lists, newest first. A closed beat keeps the rows the card already had, so a new row slides in when it opens.
    var rows: [KoncluiWASample] = []
    /// The conversation whose newest message types in while the card opens.
    var typing: KoncluiWASample.Kind?
    /// The conversation the pointer clicks on.
    var pointing: KoncluiWASample.Kind?
    /// The card shows the link's status line instead of conversations.
    var status: KoncluiWALink?
    /// The card says a Focus is on: messages wait here.
    var focusNote = false
    var seconds: Double
    var demonstrates: KoncluiWAOption?

    var unread: Int { KoncluiWAPreview.unread(rows) }

    /// Characters the typing goes through (0 when nothing types in).
    var typingLength: Int { rows.first { $0.kind == typing }?.typingLength ?? 0 }
}

enum KoncluiWATimeline {
    static let restSeconds = 1.8
    static let lightsSeconds = 1.3
    static let silentSeconds = 2.8
    static let cardSeconds = 3.8
    static let readSeconds = 2.8
    static let statusSeconds = 3.8
    /// Reduce Motion: every beat holds the same time and the stage crossfades between them.
    static let reducedMotionSeconds = 2.5

    /// When the closed notch's reaction starts (the island has begun to close) and when a card starts typing (it has opened).
    static let hopDelay = 0.35
    static let typingDelay = 0.55

    /// A message types in at 25 characters a second, faster when it is long, so it is always readable before the beat ends.
    static func typingInterval(length: Int) -> Double { min(0.04, 1.4 / Double(max(1, length))) }

    /// The beats for a link and a set of options: the loop starts at rest, plays each conversation's message in the order
    /// it arrives, and starts over. Not connected: the closed notch, then the card with the link's own status.
    static func beats(link: KoncluiWALink, options: KoncluiWAPreviewOptions, copy: KoncluiWASampleCopy = .english,
                      now: Date = Date()) -> [KoncluiWABeat] {
        let rest = KoncluiWABeat(open: false, note: .waiting, seconds: restSeconds)
        if case .status(let link) = KoncluiWAPreview.content(link: link, options: options, copy: copy, now: now) {
            return [rest, KoncluiWABeat(open: true, note: .status(link), status: link, seconds: statusSeconds)]
        }

        var beats = [rest]
        var arrived: [KoncluiWASample.Kind] = []
        var read: Set<KoncluiWASample.Kind> = []
        var held = false
        /// What the card lists once these have written, never a muted group.
        func listed(fresh: KoncluiWASample.Kind? = nil) -> [KoncluiWASample] {
            KoncluiWAPreview.samples(options: options, copy: copy, now: now, arrived: arrived, fresh: fresh, read: read)
                .filter { !$0.muted }
        }

        for kind in [KoncluiWASample.Kind.direct, .group, .mention] {
            let before = listed()
            arrived.append(kind)
            let all = KoncluiWAPreview.samples(options: options, copy: copy, now: now, arrived: arrived, fresh: kind, read: read)
            guard let sample = all.first(where: { $0.kind == kind }) else { continue }
            let name = sample.conversation.name
            let reaction: KoncluiWABeat.Reaction = sample.muted ? .muted : sample.quiet ? .held : .lights
            let note: KoncluiWABeat.Note = {
                switch reaction {
                case .muted: return .muted(name)
                case .held:  return .held(name)
                default:     return .arrives(kind, name)
                }
            }()
            beats.append(KoncluiWABeat(
                open: false, reaction: reaction, note: note, rows: before,
                seconds: reaction == .lights ? lightsSeconds : silentSeconds,
                demonstrates: kind == .group ? .muteGroups : kind == .direct ? .focus : nil))

            switch reaction {
            case .lights:
                beats.append(KoncluiWABeat(open: true, note: .opened, rows: all.filter { !$0.muted }, typing: kind, seconds: cardSeconds))
                if kind == .direct {
                    // Opening the chat: read on the spot and told to the sender, or left unread until a reply.
                    if options.markReadOnOpen { read.insert(.direct) }
                    beats.append(KoncluiWABeat(
                        open: true, note: options.markReadOnOpen ? .markedRead(name) : .stillUnread(name), rows: listed(),
                        pointing: .direct, seconds: readSeconds, demonstrates: .markRead))
                }
            case .held:
                held = true
            case .muted, .none:
                break
            }
        }
        if held {
            // Nothing opened by itself: open the notch and they are all there.
            beats.append(KoncluiWABeat(open: true, note: .waitingHere, rows: listed(fresh: arrived.last), focusNote: true,
                                       seconds: cardSeconds, demonstrates: .focus))
        }
        return beats
    }

    /// Where the loop starts over after the options changed: the beat that shows the changed option's effect. nil when
    /// the change shows nothing new (a Focus switch while the preview is not pretending a Focus, for instance).
    static func restartIndex(from old: KoncluiWAPreviewOptions, to new: KoncluiWAPreviewOptions,
                             in beats: [KoncluiWABeat]) -> Int? {
        let changed: KoncluiWAOption
        if old.muteGroups != new.muteGroups { changed = .muteGroups }
        else if old.quiet != new.quiet { changed = .focus }
        else if old.markReadOnOpen != new.markReadOnOpen { changed = .markRead }
        else { return nil }
        return beats.firstIndex { $0.demonstrates == changed } ?? 0
    }
}
