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
    /// A muted group: it stays out of the notch's list (the preview draws it faded, so the option shows).
    var muted: Bool
    /// Listed, but arrives quietly because of the Focus.
    var quiet: Bool
    var id: String { conversation.id }
}

enum KoncluiWAPreviewContent: Equatable, Sendable {
    case samples([KoncluiWASample])
    /// Not connected: the notch shows the link's own status line.
    case status(KoncluiWALink)
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
    static func samples(options: KoncluiWAPreviewOptions, copy: KoncluiWASampleCopy = .english,
                        now: Date = Date()) -> [KoncluiWASample] {
        let filters = WAFilters(muteGroups: options.muteGroups)
        var inbox = WAInbox()
        var outcome: [String: WAInbox.Outcome] = [:]

        func add(_ id: String, chat: String, name: String?, from sender: String, _ text: String, media: WAMedia = .none,
                 ago: Double, mention: Bool = false) {
            var message = WAMessage(id: id, chat: chat, sender: sender, senderName: sender, text: text, media: media,
                                    date: now.addingTimeInterval(-ago), mentionsMe: mention)
            message.chatName = name
            outcome[chat] = inbox.add(message, filters: filters)
        }
        add("preview-d1", chat: directChat, name: nil, from: copy.directName, copy.directText, ago: 150)
        add("preview-d2", chat: directChat, name: nil, from: copy.directName, copy.directText, ago: 120)
        add("preview-m1", chat: mentionChat, name: copy.mentionName, from: copy.mentionSender, copy.mentionText,
            ago: 300, mention: true)
        add("preview-g1", chat: groupChat, name: copy.groupName, from: copy.groupSender, copy.groupText, ago: 760)
        add("preview-g2", chat: groupChat, name: copy.groupName, from: copy.groupSender, copy.groupText, ago: 740)
        add("preview-g3", chat: groupChat, name: copy.groupName, from: copy.groupSender, copy.groupText,
            media: .image, ago: 720)

        let listed = Set(inbox.visible(filters: filters).map(\.id))
        let kinds: [String: KoncluiWASample.Kind] = [directChat: .direct, mentionChat: .mention, groupChat: .group]
        return inbox.sorted.compactMap { conversation in
            guard let kind = kinds[conversation.id] else { return nil }
            let muted = !listed.contains(conversation.id)
            let announces = outcome[conversation.id] == .notify
            return KoncluiWASample(kind: kind, conversation: conversation, muted: muted,
                                   quiet: announces && options.quiet)
        }
    }

    /// The count in the card's header: what the notch's list holds, never a muted group.
    static func unread(_ samples: [KoncluiWASample]) -> Int {
        samples.filter { !$0.muted }.reduce(0) { $0 + $1.conversation.unread }
    }
}
