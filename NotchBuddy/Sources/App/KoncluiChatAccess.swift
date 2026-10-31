import SwiftUI

// Koncluí: the chat through what this Mac is already signed in to (Claude Code, Codex with ChatGPT,
// the Koncluí Proxy behind klaude) instead of API keys. Owned by unit K10. Settings → Chat (unit K9)
// codes against these names: K10 keeps the signatures and fills the bodies.
//
// Detection is status only. It asks each CLI whether it is signed in (`claude auth status`,
// `codex login status`: no login is started) and asks the Keychain whether klaude's item exists
// (without -w). No credential is read or kept here.
@MainActor
final class ChatAccess: ObservableObject {
    static let shared = ChatAccess()

    enum Status: Equatable, Sendable {
        /// Usable now; the detail says how ("Signed in to Claude Code").
        case ready(String)
        /// Not usable yet; the detail says what is missing ("API key not set").
        case missing(String)

        var isReady: Bool {
            if case .ready = self { return true }
            return false
        }

        /// The detail line, whichever the state.
        var detail: String {
            switch self {
            case .ready(let text), .missing(let text): return text
            }
        }
    }

    @Published private(set) var statuses: [ChatProvider: Status] = [:]

    /// The last detected status: cheap, safe in a view body.
    func status(_ provider: ChatProvider) -> Status {
        statuses[provider] ?? .missing("")
    }

    private var lastRefresh = Date.distantPast

    /// For views that appear often (the model picker): skips a detection made a moment ago.
    func refreshIfStale(maxAge: TimeInterval = 30) async {
        if Date().timeIntervalSince(lastRefresh) > maxAge { await refresh() }
    }

    /// Detects again: API keys, CLI logins, the proxy key. Views call it when they appear.
    func refresh() async {
        lastRefresh = Date()
        var next = statuses
        for provider in ChatProvider.allCases where !provider.isSubscription {
            next[provider] = Self.keyStatus(provider)
        }
        statuses = next

        async let claude = Self.claudeStatus()
        async let codex = Self.codexStatus()
        async let proxy = Self.proxyStatus()
        let found = await (claude, codex, proxy)
        next[.claudeCode] = found.0
        next[.codex] = found.1
        next[.koncluiProxy] = found.2
        statuses = next
    }

    // MARK: API keys and local servers (the existing providers)

    private static func keyStatus(_ provider: ChatProvider) -> Status {
        let state = AppState.shared
        switch provider {
        case .ollama:
            return state.ollamaServerURL.isEmpty ? .missing(String(localized: "Not connected"))
                                                 : .ready(String(localized: "Connected"))
        case .lmstudio:
            return state.lmstudioServerURL.isEmpty ? .missing(String(localized: "Not connected"))
                                                   : .ready(String(localized: "Connected"))
        default:
            let key = KeychainStore.shared.get(provider.keychainKey) ?? ""
            return key.isEmpty ? .missing(String(localized: "Key not configured"))
                               : .ready(String(localized: "Key configured"))
        }
    }

    // MARK: Subscription routes

    #if !APPSTORE
    private nonisolated static func claudeStatus() async -> Status {
        guard let claude = KoncluiCLILocator.find("claude") else {
            return .missing(String(localized: "Claude Code is not installed. Install it to use your Claude subscription."))
        }
        guard let out = await KoncluiProcess.capture(claude, ["auth", "status", "--json"],
                                                     environment: KoncluiCLILocator.environment(for: claude),
                                                     timeout: 10), !out.timedOut else {
            return .missing(String(format: String(localized: "Couldn't check %@. Try again."), "Claude Code"))
        }
        switch KoncluiCLI.parseClaudeLogin(output: out.stdout, exitCode: out.exitCode) {
        case .signedIn(let plan?):
            return .ready(String(localized: "Signed in to Claude Code · \(plan)"))
        case .signedIn(nil):
            return .ready(String(localized: "Signed in to Claude Code"))
        case .signedOut:
            return .missing(String(localized: "Sign in to Claude Code in Terminal: claude"))
        }
    }

    private nonisolated static func codexStatus() async -> Status {
        guard let codex = KoncluiCLILocator.find("codex") else {
            return .missing(String(localized: "Codex is not installed. Install it to use your ChatGPT subscription."))
        }
        guard let out = await KoncluiProcess.capture(codex, ["login", "status"],
                                                     environment: KoncluiCLILocator.environment(for: codex),
                                                     timeout: 10), !out.timedOut else {
            return .missing(String(format: String(localized: "Couldn't check %@. Try again."), "Codex"))
        }
        // `codex login status` prints its answer on stderr.
        switch KoncluiCLI.parseCodexLogin(output: out.stdout + "\n" + out.stderr, exitCode: out.exitCode) {
        case .signedIn("ChatGPT"):
            return .ready(String(localized: "Signed in to Codex with ChatGPT"))
        case .signedIn("API key"):
            return .ready(String(localized: "Signed in to Codex with an API key"))
        case .signedIn:
            return .ready(String(localized: "Signed in to Codex"))
        case .signedOut:
            return .missing(String(localized: "Sign in to Codex in Terminal: codex login"))
        }
    }

    private nonisolated static func proxyStatus() async -> Status {
        guard KoncluiProxyAccess.baseURL() != nil else {
            return .missing(String(localized: "klaude is not installed. Install it to use the Koncluí Proxy."))
        }
        guard await KoncluiProxyAccess.hasKey() else {
            return .missing(String(localized: "klaude has no key: run klaude doctor in Terminal"))
        }
        return .ready(String(localized: "Koncluí Proxy key found (klaude)"))
    }
    #else
    private nonisolated static func claudeStatus() async -> Status { .missing(String(localized: "Not available in this build.")) }
    private nonisolated static func codexStatus() async -> Status { .missing(String(localized: "Not available in this build.")) }
    private nonisolated static func proxyStatus() async -> Status { .missing(String(localized: "Not available in this build.")) }
    #endif
}

/// The rows of the subscription providers, at the top of Settings → Chat (K10 fills it).
struct KoncluiChatSubscriptionsSection: View {
    @ObservedObject private var access = ChatAccess.shared
    @ObservedObject private var state = AppState.shared
    @State private var checking = false

    private static let routes: [ChatProvider] = [.claudeCode, .codex, .koncluiProxy]

    var body: some View {
        GroupBox(String(localized: "Use what this Mac is signed in to")) {
            VStack(alignment: .leading, spacing: 12) {
                Text(String(localized: "Chat through your Claude or ChatGPT subscription, or the Koncluí Proxy. Koncluí keeps no API key for them."))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(Self.routes, id: \.self) { provider in
                    Divider()
                    row(provider)
                }

                Divider()
                Button(String(localized: "Check again")) { check() }
                    .buttonStyle(.koncluiSecondary)
                    .disabled(checking)
            }
            .padding(6)
        }
        .task { await access.refresh() }
    }

    private func row(_ provider: ChatProvider) -> some View {
        let status = access.status(provider)
        return HStack(alignment: .top, spacing: 8) {
            Circle().fill(Color(hex: provider.accentHex)).frame(width: 8, height: 8).padding(.top, 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(provider.displayName).font(.system(size: 12, weight: .semibold))
                Text(status.detail)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if status.isReady {
                if state.chatProvider == provider {
                    Text(String(localized: "In use")).font(.system(size: 11)).foregroundColor(.secondary)
                } else {
                    Button(String(localized: "Use for chat")) { state.chatProvider = provider }
                        .buttonStyle(.koncluiSecondary)
                }
            }
        }
    }

    private func check() {
        checking = true
        Task {
            await access.refresh()
            checking = false
        }
    }
}

extension ChatProvider {
    /// Coucou's "Your AI subscriptions" rows that Koncluí shows under its own section: Claude and ChatGPT are already
    /// there as Claude Code and Codex, so only the rest (Gemini, Cursor, Copilot) is listed again.
    static var koncluiUpstreamSubscriptions: [ChatProvider] {
        subscriptionProviders.filter { $0 != .anthropic && $0 != .openai }
    }
}
