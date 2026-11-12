import Foundation

// Koncluí: who understands "OK Koru", and how Claude is reached when the person asks for it (unit K13).
//
// No API key is needed. By default the words are understood on this Mac: the phrase parser first, then Apple
// Intelligence for whatever it does not know. Claude takes over only when the person turns it on in Settings → Voice,
// through the Koncluí Proxy (the subscription behind klaude) when klaude is set up, else through the Anthropic key of
// Settings → Chat.
//
// Pure: no UI, no Keychain, no network, so `scripts/konclui/test-voice-brain.sh` checks it with swiftc alone. The
// live inputs and the call itself are in KoncluiVoiceBrainLive.swift.
enum KoncluiVoiceBrain {

    // MARK: Which brain answers

    /// What the Mac's on-device model can do now (`VoiceBrain._checkStatus()` mapped by the live side).
    enum AppleIntelligence: Equatable, Sendable {
        case available
        /// Supported, but switched off in System Settings.
        case off
        /// macOS before 26 or a Mac that cannot run it.
        case unsupported
    }

    /// Where Claude's answers come from: the subscription behind klaude, or the Anthropic key.
    enum ClaudeSource: Equatable, Sendable {
        case proxy
        case apiKey
    }

    enum Brain: Equatable, Sendable {
        case appleIntelligence
        case claude(ClaudeSource)
        /// No model at all: only the phrases the parser knows.
        case phrases

        var claudeSource: ClaudeSource? {
            if case .claude(let source) = self { return source }
            return nil
        }
    }

    struct Inputs: Equatable, Sendable {
        var appleIntelligence: AppleIntelligence
        /// "Claude answers open questions and searches the web" (`VoiceSettings.claudeBrainEnabled`, off by default).
        var claudeEnabled: Bool
        /// klaude is set up: its launcher names a proxy and its key exists.
        var proxyAvailable: Bool
        var apiKeySaved: Bool
    }

    /// The subscription comes before the key: nothing to paste, nothing billed per token.
    static func claudeSource(proxyAvailable: Bool, apiKeySaved: Bool) -> ClaudeSource? {
        if proxyAvailable { return .proxy }
        return apiKeySaved ? .apiKey : nil
    }

    /// Claude only when the person turned it on and a source exists; otherwise this Mac's own model, otherwise phrases.
    static func brain(_ inputs: Inputs) -> Brain {
        if inputs.claudeEnabled,
           let source = claudeSource(proxyAvailable: inputs.proxyAvailable, apiKeySaved: inputs.apiKeySaved) {
            return .claude(source)
        }
        return inputs.appleIntelligence == .available ? .appleIntelligence : .phrases
    }

    // MARK: A voice turn through the Koncluí Proxy

    /// Anthropic's server-side tool: the proxy may not know it.
    static let webSearchToolType = "web_search_20250305"

    private static let webSearchUnavailableNote =
        "Web search is not available right now: say so if the user asks for something current."

    static func hasWebSearch(_ tools: [[String: Any]]) -> Bool {
        tools.contains { $0["type"] as? String == webSearchToolType }
    }

    /// The same turn without the server tool; the prompt says so, so Claude does not promise a search.
    static func withoutWebSearch(system: String, tools: [[String: Any]]) -> (system: String, tools: [[String: Any]]) {
        guard hasWebSearch(tools) else { return (system, tools) }
        return (system + "\n" + webSearchUnavailableNote,
                tools.filter { $0["type"] as? String != webSearchToolType })
    }

    /// Whether a refusal may be the server tool. The retry without it is the proof: only when it passes is web search
    /// blamed. Authentication, quota and server failures are not about tools.
    static func shouldRetryWithoutWebSearch(status: Int, message: String) -> Bool {
        switch status {
        case 400, 422, 501: return true
        case 404:           return !message.lowercased().contains("model")
        default:            return false
        }
    }

    /// The models to try, in order: the one that worked before, else the fast one, then the one chosen for the chat.
    static func modelOrder(fast: String, chosen: String, remembered: String?) -> [String] {
        var order: [String] = []
        for model in [remembered, fast, chosen] {
            guard let model, !model.isEmpty, !order.contains(model) else { continue }
            order.append(model)
        }
        return order
    }

    /// The Messages body of a voice turn. Not streamed: a spoken answer is short. No `tools` key when none is left.
    static func body(model: String, system: String, messages: [[String: Any]], tools: [[String: Any]],
                     maxTokens: Int) -> Data? {
        var object: [String: Any] = ["model": model, "max_tokens": maxTokens, "system": system, "messages": messages]
        if !tools.isEmpty { object["tools"] = tools }
        return try? JSONSerialization.data(withJSONObject: object)
    }

    /// The most one request may take.
    static let requestLimit: TimeInterval = 45

    /// A failing proxy never keeps the person waiting longer than this for one turn, across every model and the retry
    /// without the web search tool (A3-29). After it the phrase parser answers and Settings → Voice shows the failure.
    static let turnDeadline: TimeInterval = 10

    /// How long the next request may take: the time left until `deadline`, at most a request's own limit. nil when too little
    /// is left for another try to be worth sending.
    static func timeLeft(until deadline: Date, now: Date, atLeast floor: TimeInterval = 1.5) -> TimeInterval? {
        let left = deadline.timeIntervalSince(now)
        return left >= floor ? min(left, requestLimit) : nil
    }

    /// The proxy request: the token as a bearer and `anthropic-version`, like the notch chat sends them, with a plain
    /// JSON answer instead of an event stream.
    static func request(base: String, token: String, body: Data, timeout: TimeInterval = requestLimit) -> URLRequest? {
        guard var request = KoncluiProxy.messagesRequest(base: base, token: token, body: body) else { return nil }
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.timeoutInterval = timeout
        return request
    }

    /// The content blocks and the stop reason of an answer, as `ClaudeService.voiceTurn` returns them.
    static func parseTurn(_ data: Data) -> (content: [[String: Any]], stopReason: String)? {
        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let content = json["content"] as? [[String: Any]] else { return nil }
        return (content, json["stop_reason"] as? String ?? "end_turn")
    }
}
