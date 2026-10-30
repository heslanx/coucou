import Foundation

// Koncluí: Claude for dictation clean-up, prompt mode, translation and the Notetaker (unit U3a).
//
// No API key is needed. Claude is reached through the Koncluí Proxy (the subscription behind klaude) when klaude is set up,
// else through the Anthropic key of Chat, and Apple Intelligence on this Mac does what it can do well (clean-up and
// summaries) when neither is there. Prompt mode, translation and the transcript correction need Claude: Apple's small
// on-device model is not good enough at them, and the interface says so.
//
// Pure: no UI, no Keychain, no network, so `scripts/konclui/test-claude-access.sh` checks it with swiftc alone. The live
// inputs and the sending are in KoncluiClaudeLive.swift and KoncluiClaudeSender.swift.
enum KoncluiClaudeAccess {

    // MARK: Which source answers

    enum Feature: String, CaseIterable, Sendable {
        case cleanup, prompt, translation, summary, correction

        /// Apple's on-device model cleans up a sentence well. A prompt, a translation or the correction of a whole transcript
        /// (JSON, line by line, long) is not what it is good at. The Notetaker's summary has its own Apple engine, chosen by
        /// the person in the picker, so "Claude" there never quietly means Apple.
        var appleCanDoIt: Bool { self == .cleanup }

        /// Dictation waits for the answer: the fast model, one try. A call's notes can take their time.
        var waitsForAnswer: Bool { self == .cleanup || self == .prompt || self == .translation }
    }

    enum Source: Equatable, Sendable {
        /// The subscription behind klaude.
        case proxy
        /// The Anthropic key saved in Chat.
        case apiKey
        /// This Mac's own model (macOS 26).
        case apple
        /// Nothing to ask: the interface says what to connect.
        case none
    }

    struct Inputs: Equatable, Sendable {
        /// klaude is set up: its launcher names a proxy and its key exists.
        var proxyAvailable: Bool
        var apiKeySaved: Bool
        /// Apple Intelligence is on and ready on this Mac.
        var appleIntelligence: Bool
    }

    /// The subscription comes before the key (nothing to paste, nothing billed per token), and both before Apple's model.
    static func source(for feature: Feature, _ inputs: Inputs) -> Source {
        let claude = claudeSource(inputs)
        if claude != .none { return claude }
        return feature.appleCanDoIt && inputs.appleIntelligence ? .apple : .none
    }

    /// Where Claude itself would come from, whatever Apple's model could do (the Notetaker's "Claude" engine).
    static func claudeSource(_ inputs: Inputs) -> Source {
        if inputs.proxyAvailable { return .proxy }
        return inputs.apiKeySaved ? .apiKey : .none
    }

    // MARK: Models

    /// The fast model, as dictation clean-up has always used it.
    static let fastModel = "claude-haiku-4-5"

    /// The models to try, in order. Dictation tries the fast one only: a second try would double the wait. A call's notes
    /// try the model the person chose first, then the fast one.
    static func models(for feature: Feature, chosen: String) -> [String] {
        guard !feature.waitsForAnswer else { return [fastModel] }
        return chosen.isEmpty || chosen == fastModel ? [fastModel] : [chosen, fastModel]
    }

    // MARK: The request

    /// One Messages call, not streamed.
    struct Call: Sendable {
        var model: String
        var system: String
        var user: String
        var maxTokens: Int
        /// nil leaves the model's own default (the Notetaker never set one).
        var temperature: Double?
        var timeout: TimeInterval
    }

    enum Route: Sendable {
        /// The Koncluí Proxy takes klaude's key as a bearer token.
        case proxy(base: String, token: String)
        /// Anthropic's own API takes the key in `x-api-key`.
        case apiKey(String)
    }

    static let anthropicEndpoint = "https://api.anthropic.com/v1/messages"

    static func body(_ call: Call) -> Data? {
        var object: [String: Any] = [
            "model": call.model,
            "max_tokens": call.maxTokens,
            "system": call.system,
            "messages": [["role": "user", "content": call.user]],
        ]
        if let temperature = call.temperature { object["temperature"] = temperature }
        return try? JSONSerialization.data(withJSONObject: object)
    }

    static func request(_ call: Call, route: Route) -> URLRequest? {
        guard let body = body(call) else { return nil }
        var request: URLRequest
        switch route {
        case .proxy(let base, let token):
            guard KoncluiProxy.validBase(base) != nil,
                  var proxied = KoncluiProxy.messagesRequest(base: base, token: token, body: body) else { return nil }
            proxied.setValue("application/json", forHTTPHeaderField: "accept")
            request = proxied
        case .apiKey(let key):
            guard let url = URL(string: anthropicEndpoint) else { return nil }
            request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue(key, forHTTPHeaderField: "x-api-key")
            request.setValue(KoncluiProxy.anthropicVersion, forHTTPHeaderField: "anthropic-version")
            request.setValue("application/json", forHTTPHeaderField: "content-type")
            request.httpBody = body
        }
        request.timeoutInterval = call.timeout
        return request
    }

    /// The text blocks of an answer, joined. nil when there is none.
    static func text(from data: Data) -> String? {
        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let content = json["content"] as? [[String: Any]] else { return nil }
        let text = content.compactMap { $0["text"] as? String }.joined()
        return text.isEmpty ? nil : text
    }

    // MARK: When it fails

    /// Why a call gave no text. Only a status or a kind: never a body, a header or a key.
    enum Failure: Equatable, Sendable {
        /// Nothing to ask (no klaude, no key, no Apple Intelligence for this feature).
        case noSource
        /// 401 or 403: the key or the subscription was refused.
        case refused(status: Int)
        /// 429: the plan's limit or the key's rate.
        case limit
        /// 5xx, including Anthropic's 529: Claude is busy.
        case busy(status: Int)
        /// Any other 4xx: the request was not accepted (a model the proxy does not serve, a body too large).
        case rejected(status: Int)
        /// No connection, or the server could not be reached.
        case offline
        /// Past the timeout; dictation pastes the words as heard rather than keep the person waiting.
        case slow
        /// A 200 with no text in it.
        case unusable
        /// This Mac's model refused or could not answer.
        case apple

        /// The catalog key of the sentence that tells the person: what happened, what it means, what to do. Dictation says its
        /// words were pasted as heard; the Notetaker's summary and correction say the notes were left as they were.
        func messageKey(source: Source, feature: Feature = .cleanup) -> String {
            guard feature.waitsForAnswer else { return notesMessageKey(source: source) }
            switch self {
            case .noSource:  return "konclui.claude.fail.none"
            case .refused:   return source == .apiKey ? "konclui.claude.fail.refused.key" : "konclui.claude.fail.refused.proxy"
            case .limit:     return "konclui.claude.fail.limit"
            case .busy:      return "konclui.claude.fail.busy"
            case .rejected, .unusable: return "konclui.claude.fail.reply"
            case .offline:   return "konclui.claude.fail.offline"
            case .slow:      return "konclui.claude.fail.slow"
            case .apple:     return "konclui.claude.fail.apple"
            }
        }

        private func notesMessageKey(source: Source) -> String {
            switch self {
            case .noSource:  return "konclui.claude.fail.notes.none"
            case .refused:   return source == .apiKey ? "konclui.claude.fail.notes.refused.key" : "konclui.claude.fail.notes.refused.proxy"
            case .limit:     return "konclui.claude.fail.notes.limit"
            case .busy:      return "konclui.claude.fail.notes.busy"
            case .offline:   return "konclui.claude.fail.notes.offline"
            case .slow:      return "konclui.claude.fail.notes.slow"
            case .rejected, .unusable, .apple: return "konclui.claude.fail.notes.reply"
            }
        }

        /// Whether the person must do something (connect, fix a key) rather than wait. Those get a button to Chat.
        var needsChat: Bool {
            switch self {
            case .noSource, .refused: return true
            default: return false
            }
        }

        /// For the app log: the kind and the HTTP status, nothing else.
        var logText: String {
            switch self {
            case .noSource:            return "no source"
            case .refused(let status), .busy(let status), .rejected(let status): return "HTTP \(status)"
            case .limit:               return "HTTP 429"
            case .offline:             return "offline"
            case .slow:                return "timed out"
            case .unusable:            return "empty answer"
            case .apple:               return "on-device model failed"
            }
        }
    }

    static func failure(status: Int) -> Failure {
        switch status {
        case 401, 403: return .refused(status: status)
        case 429:      return .limit
        case 500...599: return .busy(status: status)
        default:       return .rejected(status: status)
        }
    }

    static func failure(urlError code: URLError.Code) -> Failure {
        code == .timedOut ? .slow : .offline
    }

    /// The one line the app log keeps for a failed call.
    static func logLine(feature: Feature, source: Source, failure: Failure) -> String {
        "[Claude] \(feature.rawValue) via \(sourceName(source)) failed: \(failure.logText)"
    }

    static func sourceName(_ source: Source) -> String {
        switch source {
        case .proxy:  return "subscription"
        case .apiKey: return "key"
        case .apple:  return "Apple Intelligence"
        case .none:   return "no source"
        }
    }

    // MARK: What the interface says

    /// The privacy sentence for clean-up, prompt mode and translation: where the words go, and what a late answer does.
    static func privacyKey(_ source: Source) -> String? {
        switch source {
        case .proxy:  return "konclui.claude.privacy.proxy"
        case .apiKey: return "konclui.claude.privacy.key"
        case .apple:  return "konclui.claude.privacy.apple"
        case .none:   return nil
        }
    }

    /// What to connect when there is nothing to ask. Prompt mode and translation need Claude; clean-up can use Apple's model.
    static func connectKey(for feature: Feature) -> String {
        feature.appleCanDoIt ? "konclui.claude.connect.cleanup" : "konclui.claude.connect.ai"
    }

    /// The Notetaker's engine picker names the Claude engine after where Claude comes from.
    static func notesEngineKey(_ source: Source) -> String {
        source == .proxy ? "konclui.claude.notes.engine.proxy" : "notes.engine.claude"
    }

    /// The Notetaker's sentence about where a transcript goes with the Claude engine.
    static func notesDetailKey(_ source: Source) -> String {
        source == .proxy ? "konclui.claude.notes.proxy" : "notes.engine-detail"
    }

    // MARK: Telling the person once

    /// A failure is announced on the pill once per streak: the same kind again, with no success between, stays quiet (the
    /// log and the Settings line keep it). A different kind, or the first one after a success, is announced.
    struct Streak: Equatable, Sendable {
        private(set) var announced: Failure?

        mutating func shouldAnnounce(_ failure: Failure) -> Bool {
            let kind = Streak.kind(failure)
            if let announced, Streak.kind(announced) == kind { return false }
            announced = failure
            return true
        }

        mutating func succeeded() { announced = nil }

        /// 502 and 503 are one kind of failure; 401 and 403 too.
        private static func kind(_ failure: Failure) -> String {
            switch failure {
            case .refused:  return "refused"
            case .busy:     return "busy"
            case .rejected: return "rejected"
            default:        return failure.logText
            }
        }
    }
}
