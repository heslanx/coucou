#if !APPSTORE
import Foundation

// Koncluí: the live side of KoncluiVoiceBrain.swift (unit K13). It reads what this Mac has (Apple Intelligence, the
// Anthropic key, klaude) for the routing, and sends a voice turn through the Koncluí Proxy when that is the source.
//
// The proxy token is klaude's. It is read from the Keychain when a call starts, lives in a local variable for that call
// and is never stored, logged or shown (error text from the server is wiped of it before it is kept).
@MainActor
final class KoncluiVoiceBrainLive: ObservableObject {
    static let shared = KoncluiVoiceBrainLive()

    /// A Claude turn that got no answer. The detail is the reason in words, when there is one.
    struct Failure: Equatable {
        let detail: String?
    }

    /// klaude is set up: its launcher names a proxy and its Keychain item exists. Found in the background (asking the
    /// Keychain is a subprocess), so it reads false until the first check is done.
    @Published private(set) var proxyReady = false
    @Published private(set) var proxyChecked = false
    /// The last Claude turn that failed, until one succeeds. In memory only; Settings → Voice shows it.
    @Published private(set) var lastFailure: Failure?

    private var checkedAt = Date.distantPast
    private var checking = false
    /// What worked on this run, so a turn does not pay for requests that are known to fail.
    private var workingModel: String?
    private var proxyAcceptsWebSearch = true
    private var failureDetail: String?

    // MARK: Routing

    var apiKeySaved: Bool { !(ClaudeService.shared.apiKey ?? "").isEmpty }

    func inputs() -> KoncluiVoiceBrain.Inputs {
        .init(appleIntelligence: Self.appleIntelligence(),
              claudeEnabled: VoiceSettings.claudeBrainEnabled,
              proxyAvailable: proxyReady,
              apiKeySaved: apiKeySaved)
    }

    /// The brain for the next phrase. When Claude is on it also refreshes the proxy check in the background if it is old,
    /// so a klaude set up (or removed) while the app runs is noticed within a minute.
    func currentBrain() -> KoncluiVoiceBrain.Brain {
        if VoiceSettings.claudeBrainEnabled, !checking, Date().timeIntervalSince(checkedAt) > 60 {
            Task { await refreshProxy() }
        }
        return KoncluiVoiceBrain.brain(inputs())
    }

    /// Where Claude's answers would come from, whether or not the person turned Claude on.
    func claudeSource() -> KoncluiVoiceBrain.ClaudeSource? {
        KoncluiVoiceBrain.claudeSource(proxyAvailable: proxyReady, apiKeySaved: apiKeySaved)
    }

    func refreshProxy(maxAge: TimeInterval = 0) async {
        guard !checking, Date().timeIntervalSince(checkedAt) > maxAge else { return }
        checking = true
        let ready = KoncluiProxyAccess.baseURL() != nil ? await KoncluiProxyAccess.hasKey() : false
        proxyReady = ready
        proxyChecked = true
        checkedAt = Date()
        checking = false
    }

    static func appleIntelligence() -> KoncluiVoiceBrain.AppleIntelligence {
        switch VoiceBrain._checkStatus() {
        case .available:            return .available
        case .appleIntelligenceOff: return .off
        case .notMacOS26:           return .unsupported
        }
    }

    // MARK: The outcome of a Claude turn (ClaudeVoiceBrain.respond)

    func turnEnded(failed: Bool) {
        let next = failed ? Failure(detail: failureDetail) : nil
        failureDetail = nil
        if lastFailure != next { lastFailure = next }
    }

    // MARK: A turn through the Koncluí Proxy

    private enum Attempt {
        case answer(Data)
        case refused(status: Int, message: String)
        case unreachable
    }

    /// One non-streamed Messages call for a voice turn, with the same body the Anthropic API gets. The fast model first,
    /// then the one chosen for the chat. If the proxy refuses the web search tool, the same call is made once without
    /// it and, when that passes, the later turns leave it out. nil when no answer came; the reason is kept for Settings.
    func send(system: String, messages: [[String: Any]], tools: [[String: Any]], maxTokens: Int,
              fastModel: String) async -> Data? {
        failureDetail = nil
        guard let base = KoncluiProxyAccess.baseURL() else {
            return fail(String(localized: "klaude is not installed. Install it to use the Koncluí Proxy."))
        }
        guard let token = await KoncluiProxyAccess.readKey() else {
            return fail(String(localized: "klaude has no key: run klaude doctor in Terminal"))
        }
        let full = proxyAcceptsWebSearch ? (system: system, tools: tools)
                                         : KoncluiVoiceBrain.withoutWebSearch(system: system, tools: tools)
        let models = KoncluiVoiceBrain.modelOrder(fast: fastModel, chosen: AppState.shared.koncluiProxyChatModel,
                                                  remembered: workingModel)
        var refusal: String?
        for model in models {
            var attempt = await post(model: model, prompt: full, messages: messages, maxTokens: maxTokens,
                                     base: base, token: token)
            if case .refused(let status, let message) = attempt, KoncluiVoiceBrain.hasWebSearch(full.tools),
               KoncluiVoiceBrain.shouldRetryWithoutWebSearch(status: status, message: message) {
                let plain = KoncluiVoiceBrain.withoutWebSearch(system: system, tools: tools)
                attempt = await post(model: model, prompt: plain, messages: messages, maxTokens: maxTokens,
                                     base: base, token: token)
                if case .answer = attempt {
                    proxyAcceptsWebSearch = false
                    appendAppLog("nb.log", "[Voice] Koncluí Proxy refused the web search (HTTP \(status)): answering without it")
                }
            }
            switch attempt {
            case .answer(let data):
                workingModel = model
                return data
            case .refused(let status, let message):
                if status == 401 || status == 403 {
                    return fail(String(localized: "The Koncluí Proxy refused the key. Run klaude doctor in Terminal."))
                }
                appendAppLog("nb.log", "[Voice] Koncluí Proxy refused the call (HTTP \(status))")
                refusal = message
            case .unreachable:
                return fail(String(localized: "The Koncluí Proxy is unreachable. Check your connection."))
            }
        }
        return fail(refusal.map { String($0.prefix(200)) })
    }

    private func post(model: String, prompt: (system: String, tools: [[String: Any]]), messages: [[String: Any]],
                      maxTokens: Int, base: String, token: String) async -> Attempt {
        guard let body = KoncluiVoiceBrain.body(model: model, system: prompt.system, messages: messages,
                                                tools: prompt.tools, maxTokens: maxTokens),
              let request = KoncluiVoiceBrain.request(base: base, token: token, body: body) else { return .unreachable }
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse else { return .unreachable }
        if http.statusCode == 200 { return .answer(data) }
        return .refused(status: http.statusCode,
                        message: KoncluiProxy.errorMessage(body: data, status: http.statusCode, token: token))
    }

    private func fail(_ detail: String?) -> Data? {
        failureDetail = detail
        appendAppLog("nb.log", "[Voice] Koncluí Proxy turn failed")
        return nil
    }
}
#endif
