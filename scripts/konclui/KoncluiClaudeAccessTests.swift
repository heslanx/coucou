import Foundation

// Koncluí's Claude access (App/KoncluiClaudeAccess.swift and KoncluiClaudeSender.swift): which source answers each
// feature, the request each source gets (bearer or key, version, model), how a failure is told apart, and that no
// credential reaches a failure or a log line. The network is a stub; the tokens below are fakes.

final class StubProtocol: URLProtocol, @unchecked Sendable {
    enum Reply {
        case http(Int, String)
        case error(URLError.Code)
    }

    nonisolated(unsafe) static var replies: [Reply] = []
    nonisolated(unsafe) static var seen: [(request: URLRequest, body: [String: Any])] = []

    static func reset(_ replies: [Reply]) {
        self.replies = replies
        seen = []
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        var body: [String: Any] = [:]
        if let stream = request.httpBodyStream {
            stream.open()
            var data = Data()
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                data.append(buffer, count: count)
            }
            stream.close()
            body = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        } else if let data = request.httpBody {
            body = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        }
        Self.seen.append((request, body))
        let reply = Self.replies.isEmpty ? Reply.http(500, "{}") : Self.replies.removeFirst()
        switch reply {
        case .http(let status, let text):
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(text.utf8))
            client?.urlProtocolDidFinishLoading(self)
        case .error(let code):
            client?.urlProtocol(self, didFailWithError: URLError(code))
        }
    }

    override func stopLoading() {}
}

@main
@MainActor
enum KoncluiClaudeAccessTests {

    static var failures = 0

    static func check(_ label: String, _ got: Bool) {
        if got { print("  ✓ \(label)") }
        else   { print("  ✗ \(label)"); failures += 1 }
    }

    typealias Access = KoncluiClaudeAccess
    typealias Feature = Access.Feature
    typealias Source = Access.Source

    static let fakeToken = "tok-FAKE-0123456789"
    static let fakeKey = "sk-ant-FAKE-9876543210"
    static let proxyBase = "https://proxy.example.test"

    static var session: URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        return URLSession(configuration: configuration)
    }

    static func call(_ model: String = "m", timeout: TimeInterval = 4) -> Access.Call {
        .init(model: model, system: "SYSTEM TEXT", user: "USER TEXT", maxTokens: 321, temperature: 0, timeout: timeout)
    }

    static func answer(_ text: String) -> String {
        #"{"id":"msg_1","type":"message","role":"assistant","content":[{"type":"text","text":"\#(text)"}],"stop_reason":"end_turn"}"#
    }

    static func main() async {
        sourceChoice()
        models()
        requests()
        parsing()
        failureKinds()
        telling()
        await sending()
        printKeys()
        if failures > 0 {
            print("\(failures) check(s) failed")
            exit(1)
        }
        print("All checks passed")
    }

    // MARK: Which source answers

    static func sourceChoice() {
        print("The source of each feature, for every combination of klaude, the key and Apple Intelligence")
        // Columns: proxy, key, Apple Intelligence -> clean-up, prompt, translation, summary, correction.
        // Written by hand from the owner's rule: the subscription, else the key, else Apple's model for the clean-up only.
        typealias Row = (proxy: Bool, key: Bool, apple: Bool, expected: [Source])
        let table: [Row] = [
            (false, false, false, [.none,  .none,  .none,  .none,  .none]),
            (false, false, true,  [.apple, .none,  .none,  .none,  .none]),
            (false, true,  false, [.apiKey, .apiKey, .apiKey, .apiKey, .apiKey]),
            (false, true,  true,  [.apiKey, .apiKey, .apiKey, .apiKey, .apiKey]),
            (true,  false, false, [.proxy, .proxy, .proxy, .proxy, .proxy]),
            (true,  false, true,  [.proxy, .proxy, .proxy, .proxy, .proxy]),
            (true,  true,  false, [.proxy, .proxy, .proxy, .proxy, .proxy]),
            (true,  true,  true,  [.proxy, .proxy, .proxy, .proxy, .proxy]),
        ]
        let features: [Feature] = [.cleanup, .prompt, .translation, .summary, .correction]
        for row in table {
            let inputs = Access.Inputs(proxyAvailable: row.proxy, apiKeySaved: row.key, appleIntelligence: row.apple)
            for (feature, expected) in zip(features, row.expected) {
                let got = Access.source(for: feature, inputs)
                check("proxy \(row.proxy), key \(row.key), Apple \(row.apple), \(feature.rawValue) -> \(expected)",
                      got == expected)
            }
            let claude = Access.claudeSource(inputs)
            let expectedClaude: Source = row.proxy ? .proxy : (row.key ? .apiKey : .none)
            check("proxy \(row.proxy), key \(row.key), Apple \(row.apple), the Claude engine -> \(expectedClaude)",
                  claude == expectedClaude)
        }
        check("every feature is in the table", Set(features) == Set(Feature.allCases))
        check("only the clean-up falls back to Apple", Feature.allCases.filter(\.appleCanDoIt) == [.cleanup])
        check("dictation waits for the answer, the notes do not",
              Feature.allCases.filter(\.waitsForAnswer) == [.cleanup, .prompt, .translation])
    }

    static func models() {
        print("The models")
        check("dictation: the fast model only", Access.models(for: .cleanup, chosen: "sonnet-x") == [Access.fastModel])
        check("prompt mode: the fast model only", Access.models(for: .prompt, chosen: "sonnet-x") == [Access.fastModel])
        check("translation: the fast model only", Access.models(for: .translation, chosen: "sonnet-x") == [Access.fastModel])
        check("the summary: the chosen model, then the fast one",
              Access.models(for: .summary, chosen: "sonnet-x") == ["sonnet-x", Access.fastModel])
        check("the correction: the chosen model, then the fast one",
              Access.models(for: .correction, chosen: "sonnet-x") == ["sonnet-x", Access.fastModel])
        check("the chosen model is the fast one: no second try",
              Access.models(for: .summary, chosen: Access.fastModel) == [Access.fastModel])
        check("no chosen model: the fast one", Access.models(for: .summary, chosen: "") == [Access.fastModel])
        check("the fast model is haiku, as dictation clean-up has always used", Access.fastModel == "claude-haiku-4-5")
    }

    // MARK: The request

    static func requests() {
        print("The request through the proxy")
        let proxied = Access.request(call("claude-haiku-4-5", timeout: 4), route: .proxy(base: proxyBase, token: fakeToken))
        check("a request is built", proxied != nil)
        check("POST to the proxy's /v1/messages", proxied?.httpMethod == "POST" && proxied?.url?.absoluteString == "\(proxyBase)/v1/messages")
        check("the token is a bearer", proxied?.value(forHTTPHeaderField: "Authorization") == "Bearer \(fakeToken)")
        check("anthropic-version", proxied?.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")
        check("a JSON body and a JSON answer (not an event stream)",
              proxied?.value(forHTTPHeaderField: "content-type") == "application/json"
                && proxied?.value(forHTTPHeaderField: "accept") == "application/json")
        check("no x-api-key header", proxied?.value(forHTTPHeaderField: "x-api-key") == nil)
        check("the timeout is the call's", proxied?.timeoutInterval == 4)
        let body = (proxied?.httpBody).flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]
        check("the model", body["model"] as? String == "claude-haiku-4-5")
        check("max_tokens and temperature", body["max_tokens"] as? Int == 321 && body["temperature"] as? Double == 0)
        check("the system prompt", body["system"] as? String == "SYSTEM TEXT")
        let messages = body["messages"] as? [[String: Any]]
        check("one user message with the words", messages?.count == 1 && messages?.first?["role"] as? String == "user"
              && messages?.first?["content"] as? String == "USER TEXT")
        check("not streamed", body["stream"] == nil)
        check("the token is not in the body", !(String(data: proxied?.httpBody ?? Data(), encoding: .utf8) ?? "").contains(fakeToken))
        let trailing = Access.request(call(), route: .proxy(base: "\(proxyBase)/v1/", token: fakeToken))
        check("a base ending in /v1 does not double it", trailing?.url?.absoluteString == "\(proxyBase)/v1/messages")

        print("The request with the Anthropic key")
        let keyed = Access.request(call("claude-sonnet-4-6", timeout: 12), route: .apiKey(fakeKey))
        check("POST to api.anthropic.com", keyed?.httpMethod == "POST" && keyed?.url?.absoluteString == "https://api.anthropic.com/v1/messages")
        check("the key is x-api-key", keyed?.value(forHTTPHeaderField: "x-api-key") == fakeKey)
        check("no bearer", keyed?.value(forHTTPHeaderField: "Authorization") == nil)
        check("anthropic-version and JSON", keyed?.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01"
              && keyed?.value(forHTTPHeaderField: "content-type") == "application/json")
        let keyedBody = (keyed?.httpBody).flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]
        check("the model is the call's", keyedBody["model"] as? String == "claude-sonnet-4-6")
        check("the key is not in the body", !(String(data: keyed?.httpBody ?? Data(), encoding: .utf8) ?? "").contains(fakeKey))
        check("the timeout is the call's", keyed?.timeoutInterval == 12)

        var noTemperature = call()
        noTemperature.temperature = nil
        let plain = Access.body(noTemperature).flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]
        check("no temperature when none is asked (the Notetaker never set one)", plain["temperature"] == nil)
        check("a proxy address that is not a URL builds nothing",
              Access.request(call(), route: .proxy(base: "", token: fakeToken)) == nil)
    }

    static func parsing() {
        print("An answer")
        check("the text blocks, joined",
              Access.text(from: Data(#"{"content":[{"type":"text","text":"Hello "},{"type":"text","text":"there"}]}"#.utf8)) == "Hello there")
        check("a tool block is not text",
              Access.text(from: Data(#"{"content":[{"type":"tool_use","id":"t"}]}"#.utf8)) == nil)
        check("an empty text is no text", Access.text(from: Data(#"{"content":[{"type":"text","text":""}]}"#.utf8)) == nil)
        check("an error body is no text", Access.text(from: Data(#"{"type":"error","error":{"message":"x"}}"#.utf8)) == nil)
        check("garbage is no text", Access.text(from: Data("not json".utf8)) == nil)
    }

    // MARK: When it fails

    static func failureKinds() {
        print("The kind of failure")
        check("401 is a refused key", Access.failure(status: 401) == .refused(status: 401))
        check("403 is a refused key", Access.failure(status: 403) == .refused(status: 403))
        check("429 is the limit", Access.failure(status: 429) == .limit)
        check("529 is busy", Access.failure(status: 529) == .busy(status: 529))
        check("500 and 503 are busy", Access.failure(status: 500) == .busy(status: 500) && Access.failure(status: 503) == .busy(status: 503))
        check("400 is a request that was not accepted", Access.failure(status: 400) == .rejected(status: 400))
        check("404 is a request that was not accepted", Access.failure(status: 404) == .rejected(status: 404))
        check("a timeout is slow", Access.failure(urlError: .timedOut) == .slow)
        check("no connection is offline", Access.failure(urlError: .notConnectedToInternet) == .offline)
        check("a lost host is offline", Access.failure(urlError: .cannotFindHost) == .offline)

        print("What the person reads")
        let all: [Access.Failure] = [.noSource, .refused(status: 401), .limit, .busy(status: 529), .rejected(status: 400),
                                     .offline, .slow, .unusable, .apple]
        for source in [Source.proxy, .apiKey, .apple, .none] {
            for failure in all {
                let key = failure.messageKey(source: source)
                check("\(failure.logText) via \(Access.sourceName(source)) has a message", key.hasPrefix("konclui.claude.fail."))
            }
        }
        for source in [Source.proxy, .apiKey, .none] {
            for failure in all {
                for feature in [Access.Feature.summary, .correction] {
                    check("\(failure.logText) in the \(feature.rawValue) speaks of the notes",
                          failure.messageKey(source: source, feature: feature).hasPrefix("konclui.claude.fail.notes."))
                }
            }
        }
        check("prompt mode and translation keep the dictation sentence",
              Access.Failure.slow.messageKey(source: .proxy, feature: .prompt) == "konclui.claude.fail.slow"
                && Access.Failure.slow.messageKey(source: .proxy, feature: .translation) == "konclui.claude.fail.slow")
        check("a refused key in the notes points to the key in Chat",
              Access.Failure.refused(status: 401).messageKey(source: .apiKey, feature: .summary) == "konclui.claude.fail.notes.refused.key")
        check("a refused subscription points to klaude doctor",
              Access.Failure.refused(status: 401).messageKey(source: .proxy) == "konclui.claude.fail.refused.proxy")
        check("a refused key points to the key in Chat",
              Access.Failure.refused(status: 401).messageKey(source: .apiKey) == "konclui.claude.fail.refused.key")
        check("only a failure the person must fix opens Chat",
              all.filter(\.needsChat) == [.noSource, .refused(status: 401)])
        check("the log line keeps the feature, the source and the status",
              Access.logLine(feature: .cleanup, source: .proxy, failure: .refused(status: 401))
                == "[Claude] cleanup via subscription failed: HTTP 401")
        for failure in all {
            let line = Access.logLine(feature: .prompt, source: .apiKey, failure: failure)
            check("no key or token in: \(line)", !line.contains(fakeKey) && !line.contains(fakeToken) && !line.contains("Bearer"))
        }
    }

    static func telling() {
        print("The interface says where Claude comes from")
        check("the subscription's privacy line", Access.privacyKey(.proxy) == "konclui.claude.privacy.proxy")
        check("the key's privacy line", Access.privacyKey(.apiKey) == "konclui.claude.privacy.key")
        check("Apple's privacy line", Access.privacyKey(.apple) == "konclui.claude.privacy.apple")
        check("no source, no privacy line", Access.privacyKey(.none) == nil)
        check("clean-up can use Apple's model: its connect line says so",
              Access.connectKey(for: .cleanup) == "konclui.claude.connect.cleanup")
        check("prompt mode and translation need Claude: their connect line says so",
              Access.connectKey(for: .prompt) == "konclui.claude.connect.ai" && Access.connectKey(for: .translation) == "konclui.claude.connect.ai")
        check("the Notetaker's engine names the subscription", Access.notesEngineKey(.proxy) == "konclui.claude.notes.engine.proxy")
        check("the Notetaker's engine keeps upstream's label for the key", Access.notesEngineKey(.apiKey) == "notes.engine.claude")
        check("the Notetaker's transcript line names the subscription", Access.notesDetailKey(.proxy) == "konclui.claude.notes.proxy")
        check("the Notetaker's transcript line keeps upstream's for the key", Access.notesDetailKey(.apiKey) == "notes.engine-detail")

        print("A failure is told once per streak")
        var streak = Access.Streak()
        check("the first failure is told", streak.shouldAnnounce(.slow))
        check("the same kind again is quiet", !streak.shouldAnnounce(.slow))
        check("502 after 503 is the same kind", {
            var s = Access.Streak()
            _ = s.shouldAnnounce(.busy(status: 503))
            return !s.shouldAnnounce(.busy(status: 502))
        }())
        check("another kind is told", streak.shouldAnnounce(.offline))
        streak.succeeded()
        check("after a success the same failure is told again", streak.shouldAnnounce(.offline))
    }

    // MARK: Sending

    static func sending() async {
        print("Sending through the stub")
        StubProtocol.reset([.http(200, answer("Eu vou testar."))])
        var outcome = await KoncluiClaudeSender.send(call("claude-haiku-4-5"), route: .proxy(base: proxyBase, token: fakeToken), session: session)
        check("a 200 gives the text", outcome == .text("Eu vou testar."))
        let first = StubProtocol.seen.first
        check("it went to the proxy with the bearer and the model",
              first?.request.url?.absoluteString == "\(proxyBase)/v1/messages"
                && first?.request.value(forHTTPHeaderField: "Authorization") == "Bearer \(fakeToken)"
                && first?.body["model"] as? String == "claude-haiku-4-5")

        StubProtocol.reset([.http(200, answer("ok"))])
        outcome = await KoncluiClaudeSender.send(call("claude-haiku-4-5"), route: .apiKey(fakeKey), session: session)
        check("a 200 with the key gives the text", outcome == .text("ok"))
        check("it went to Anthropic with the key", StubProtocol.seen.first?.request.url?.host == "api.anthropic.com"
              && StubProtocol.seen.first?.request.value(forHTTPHeaderField: "x-api-key") == fakeKey)

        let statuses: [(Int, Access.Failure)] = [
            (401, .refused(status: 401)), (403, .refused(status: 403)), (429, .limit), (529, .busy(status: 529)),
            (500, .busy(status: 500)), (400, .rejected(status: 400)),
        ]
        for (status, expected) in statuses {
            // The server echoes the credential in its error body: the outcome and the log line must not carry it.
            StubProtocol.reset([.http(status, #"{"type":"error","error":{"message":"bad \#(fakeToken) and \#(fakeKey)"}}"#)])
            outcome = await KoncluiClaudeSender.send(call(), route: .proxy(base: proxyBase, token: fakeToken), session: session)
            check("HTTP \(status) -> \(expected)", outcome == .failed(expected))
            let described = "\(outcome)" + Access.logLine(feature: .cleanup, source: .proxy, failure: expected)
            check("HTTP \(status): the echoed credentials stay out of the outcome and the log line",
                  !described.contains(fakeToken) && !described.contains(fakeKey))
        }

        StubProtocol.reset([.http(200, #"{"content":[]}"#)])
        outcome = await KoncluiClaudeSender.send(call(), route: .apiKey(fakeKey), session: session)
        check("a 200 with no text is unusable", outcome == .failed(.unusable))

        StubProtocol.reset([.error(.timedOut)])
        outcome = await KoncluiClaudeSender.send(call(), route: .apiKey(fakeKey), session: session)
        check("a timeout is slow", outcome == .failed(.slow))
        StubProtocol.reset([.error(.notConnectedToInternet)])
        outcome = await KoncluiClaudeSender.send(call(), route: .apiKey(fakeKey), session: session)
        check("no connection is offline", outcome == .failed(.offline))
        StubProtocol.reset([.error(.cancelled)])
        outcome = await KoncluiClaudeSender.send(call(), route: .apiKey(fakeKey), session: session)
        check("a cancelled call tells nobody", outcome == .cancelled)

        print("Several models")
        StubProtocol.reset([.http(404, "{}"), .http(200, answer("second"))])
        outcome = await KoncluiClaudeSender.send(call(), models: ["chosen", "fast"], route: .proxy(base: proxyBase, token: fakeToken), session: session)
        check("a model the proxy does not serve: the next one answers", outcome == .text("second"))
        check("both models were asked, in order", StubProtocol.seen.map { $0.body["model"] as? String ?? "" } == ["chosen", "fast"])

        StubProtocol.reset([.http(401, "{}"), .http(200, answer("never"))])
        outcome = await KoncluiClaudeSender.send(call(), models: ["chosen", "fast"], route: .proxy(base: proxyBase, token: fakeToken), session: session)
        check("a refused key stops at the first model", outcome == .failed(.refused(status: 401)) && StubProtocol.seen.count == 1)

        StubProtocol.reset([.http(429, "{}"), .http(200, answer("never"))])
        outcome = await KoncluiClaudeSender.send(call(), models: ["chosen", "fast"], route: .apiKey(fakeKey), session: session)
        check("the limit stops at the first model", outcome == .failed(.limit) && StubProtocol.seen.count == 1)

        StubProtocol.reset([.error(.timedOut), .http(200, answer("never"))])
        outcome = await KoncluiClaudeSender.send(call(), models: ["chosen", "fast"], route: .apiKey(fakeKey), session: session)
        check("a timeout stops at the first model (dictation would wait twice)", outcome == .failed(.slow) && StubProtocol.seen.count == 1)

        StubProtocol.reset([.http(529, "{}"), .http(529, "{}")])
        outcome = await KoncluiClaudeSender.send(call(), models: ["chosen", "fast"], route: .apiKey(fakeKey), session: session)
        check("busy twice: the last failure is told", outcome == .failed(.busy(status: 529)) && StubProtocol.seen.count == 2)

        outcome = await KoncluiClaudeSender.send(call(), models: [], route: .apiKey(fakeKey), session: session)
        check("no model at all: nothing to ask", outcome == .failed(.noSource))
    }

    /// The message keys the pure file can produce, for the script that checks them against the catalog.
    static func printKeys() {
        var keys = Set<String>()
        let failures: [Access.Failure] = [.noSource, .refused(status: 401), .limit, .busy(status: 529), .rejected(status: 400),
                                          .offline, .slow, .unusable, .apple]
        for source in [Source.proxy, .apiKey, .apple, .none] {
            for failure in failures {
                keys.insert(failure.messageKey(source: source))
                keys.insert(failure.messageKey(source: source, feature: .summary))
            }
            if let key = Access.privacyKey(source) { keys.insert(key) }
            keys.insert(Access.notesEngineKey(source))
            keys.insert(Access.notesDetailKey(source))
        }
        keys.insert(Access.connectKey(for: .cleanup))
        keys.insert(Access.connectKey(for: .prompt))
        for key in keys.sorted() { print("KEY \(key)") }
    }
}
