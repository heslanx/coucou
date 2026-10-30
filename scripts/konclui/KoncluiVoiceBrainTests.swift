import Foundation

// Koncluí's voice brain (App/KoncluiVoiceBrain.swift): which brain answers "OK Koru" for every combination of Apple
// Intelligence, the Claude opt-in, the Koncluí Proxy and the Anthropic key, and the proxy request of a voice turn.
// Pure: no network, no Keychain; the token below is a fake.

@main
@MainActor
enum KoncluiVoiceBrainTests {

    static var failures = 0

    static func check(_ label: String, _ got: Bool) {
        if got { print("  ✓ \(label)") }
        else   { print("  ✗ \(label)"); failures += 1 }
    }

    typealias Brain = KoncluiVoiceBrain.Brain
    typealias AI = KoncluiVoiceBrain.AppleIntelligence

    /// The decision table, written by hand from the owner's rule (D13): Apple Intelligence by default, Claude only when
    /// turned on and a source exists (the subscription before the key), phrases when there is no model at all.
    /// Columns: Apple Intelligence, Claude on, proxy, key -> brain.
    static let table: [(AI, Bool, Bool, Bool, Brain)] = [
        (.available,   false, false, false, .appleIntelligence),
        (.available,   false, false, true,  .appleIntelligence),
        (.available,   false, true,  false, .appleIntelligence),
        (.available,   false, true,  true,  .appleIntelligence),
        (.available,   true,  false, false, .appleIntelligence),
        (.available,   true,  false, true,  .claude(.apiKey)),
        (.available,   true,  true,  false, .claude(.proxy)),
        (.available,   true,  true,  true,  .claude(.proxy)),
        (.off,         false, false, false, .phrases),
        (.off,         false, false, true,  .phrases),
        (.off,         false, true,  false, .phrases),
        (.off,         false, true,  true,  .phrases),
        (.off,         true,  false, false, .phrases),
        (.off,         true,  false, true,  .claude(.apiKey)),
        (.off,         true,  true,  false, .claude(.proxy)),
        (.off,         true,  true,  true,  .claude(.proxy)),
        (.unsupported, false, false, false, .phrases),
        (.unsupported, false, false, true,  .phrases),
        (.unsupported, false, true,  false, .phrases),
        (.unsupported, false, true,  true,  .phrases),
        (.unsupported, true,  false, false, .phrases),
        (.unsupported, true,  false, true,  .claude(.apiKey)),
        (.unsupported, true,  true,  false, .claude(.proxy)),
        (.unsupported, true,  true,  true,  .claude(.proxy)),
    ]

    static func name(_ brain: Brain) -> String {
        switch brain {
        case .appleIntelligence:   return "Apple Intelligence"
        case .claude(.proxy):      return "Claude by the proxy"
        case .claude(.apiKey):     return "Claude by the key"
        case .phrases:             return "phrases"
        }
    }

    static let fakeToken = "tok-FAKE-0123456789"
    static let base = "https://proxy.example.test"

    static let clientTool: [String: Any] = [
        "name": "music",
        "description": "Control the music.",
        "input_schema": ["type": "object", "properties": ["action": ["type": "string"]], "required": ["action"]],
    ]
    static let webSearch: [String: Any] = [
        "type": "web_search_20250305", "name": "web_search", "max_uses": 3,
        "user_location": ["type": "approximate", "timezone": "America/Sao_Paulo"],
    ]
    static let messages: [[String: Any]] = [["role": "user", "content": "what is the weather in Lisbon"]]

    static func object(_ data: Data?) -> [String: Any] {
        guard let data, let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return [:] }
        return json
    }

    static func main() {
        print("Routing table — every combination (\(table.count))")
        for (ai, on, proxy, key, expected) in table {
            let got = KoncluiVoiceBrain.brain(.init(appleIntelligence: ai, claudeEnabled: on,
                                                    proxyAvailable: proxy, apiKeySaved: key))
            check("\(ai), Claude \(on ? "on" : "off"), proxy \(proxy ? "yes" : "no"), key \(key ? "yes" : "no") -> \(name(expected))",
                  got == expected)
        }
        let sources: [(Bool, Bool, KoncluiVoiceBrain.ClaudeSource?)] =
            [(false, false, nil), (false, true, .apiKey), (true, false, .proxy), (true, true, .proxy)]
        check("the Claude source is the subscription, else the key, else none",
              sources.allSatisfy { KoncluiVoiceBrain.claudeSource(proxyAvailable: $0.0, apiKeySaved: $0.1) == $0.2 })
        check("only a Claude brain has a source", Brain.appleIntelligence.claudeSource == nil
              && Brain.phrases.claudeSource == nil && Brain.claude(.proxy).claudeSource == .proxy)

        print("A voice turn through the proxy — the request")
        let tools = [clientTool, webSearch]
        let body = KoncluiVoiceBrain.body(model: "claude-haiku-4-5", system: "You are Koncluí.", messages: messages,
                                          tools: tools, maxTokens: 2048)
        let request = body.flatMap { KoncluiVoiceBrain.request(base: base, token: fakeToken, body: $0) }
        check("the request exists", request != nil)
        check("POST to /v1/messages of the proxy", request?.httpMethod == "POST"
              && request?.url?.absoluteString == "https://proxy.example.test/v1/messages")
        check("bearer token header", request?.value(forHTTPHeaderField: "Authorization") == "Bearer \(fakeToken)")
        check("anthropic-version header", request?.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")
        check("JSON in, JSON out (not an event stream)", request?.value(forHTTPHeaderField: "content-type") == "application/json"
              && request?.value(forHTTPHeaderField: "accept") == "application/json")
        check("no x-api-key header", request?.value(forHTTPHeaderField: "x-api-key") == nil)
        let sent = object(request?.httpBody)
        check("the body names the model, the limit and the system prompt", sent["model"] as? String == "claude-haiku-4-5"
              && sent["max_tokens"] as? Int == 2048 && sent["system"] as? String == "You are Koncluí.")
        let sentTools = sent["tools"] as? [[String: Any]] ?? []
        check("the tools array keeps the client tool and the web search", sentTools.count == 2
              && sentTools.contains { $0["name"] as? String == "music" }
              && sentTools.contains { $0["type"] as? String == "web_search_20250305" })
        check("the web search keeps its location", ((sentTools.last?["user_location"] as? [String: Any])?["timezone"] as? String) == "America/Sao_Paulo")
        check("not streamed", sent["stream"] == nil)
        check("the messages go as they are", (sent["messages"] as? [[String: Any]])?.first?["content"] as? String == "what is the weather in Lisbon")
        check("the token is in the header only, never in the body", !(String(data: request?.httpBody ?? Data(), encoding: .utf8) ?? "").contains(fakeToken))
        check("a turn can take a while but not forever", request?.timeoutInterval == 45)

        print("A voice turn through the proxy: one deadline for every try (A3-29)")
        let start = Date(timeIntervalSince1970: 1_000)
        let deadline = start.addingTimeInterval(KoncluiVoiceBrain.turnDeadline)
        check("a failing proxy never holds a turn past about ten seconds", KoncluiVoiceBrain.turnDeadline <= 10)
        check("the first try gets the whole deadline", KoncluiVoiceBrain.timeLeft(until: deadline, now: start) == KoncluiVoiceBrain.turnDeadline)
        check("a retry gets only what is left", KoncluiVoiceBrain.timeLeft(until: deadline, now: start.addingTimeInterval(6)) == 4)
        check("no try is worth sending with a second left", KoncluiVoiceBrain.timeLeft(until: deadline, now: start.addingTimeInterval(9)) == nil)
        check("none after the deadline", KoncluiVoiceBrain.timeLeft(until: deadline, now: start.addingTimeInterval(12)) == nil)
        check("a long deadline never lifts a request past its own limit",
              KoncluiVoiceBrain.timeLeft(until: start.addingTimeInterval(300), now: start) == KoncluiVoiceBrain.requestLimit)
        let timed = KoncluiVoiceBrain.request(base: base, token: fakeToken, body: Data("{}".utf8), timeout: 4)
        check("the request carries the time left", timed?.timeoutInterval == 4)

        print("A voice turn through the proxy — the retry without the web search")
        check("the tools hold the web search", KoncluiVoiceBrain.hasWebSearch(tools))
        let plain = KoncluiVoiceBrain.withoutWebSearch(system: "You are Koncluí.", tools: tools)
        check("the retry has only the client tool", plain.tools.count == 1 && plain.tools.first?["name"] as? String == "music")
        check("the retry says web search is unavailable", plain.system.hasPrefix("You are Koncluí.") && plain.system.contains("Web search is not available"))
        let retryBody = KoncluiVoiceBrain.body(model: "claude-haiku-4-5", system: plain.system, messages: messages,
                                               tools: plain.tools, maxTokens: 2048)
        let retryRequest = retryBody.flatMap { KoncluiVoiceBrain.request(base: base, token: fakeToken, body: $0) }
        let retryText = String(data: retryRequest?.httpBody ?? Data(), encoding: .utf8) ?? ""
        check("the retry request has no web_search at all", !retryText.contains("web_search") && !retryText.contains("web search tool"))
        check("the retry request still has the bearer and the version", retryRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer \(fakeToken)"
              && retryRequest?.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")
        check("the retry request still has the tools array", (object(retryRequest?.httpBody)["tools"] as? [[String: Any]])?.count == 1)
        let alone = KoncluiVoiceBrain.withoutWebSearch(system: "S", tools: [webSearch])
        let aloneBody = KoncluiVoiceBrain.body(model: "m", system: alone.system, messages: messages, tools: alone.tools, maxTokens: 700)
        check("a turn that only had the web search sends no tools key", alone.tools.isEmpty && object(aloneBody)["tools"] == nil)
        let untouched = KoncluiVoiceBrain.withoutWebSearch(system: "S", tools: [clientTool])
        check("without a web search there is nothing to take out", untouched.system == "S" && untouched.tools.count == 1)

        print("A voice turn through the proxy — when to retry, which model")
        let retryCases: [(Int, String, Bool)] = [
            (400, "tools.1: Input tag 'web_search_20250305' does not match", true),
            (400, "Bad Request", true), (422, "", true), (501, "", true),
            (404, "tool type not found", true), (404, "model: claude-haiku-4-5 not found", false),
            (401, "invalid token", false), (403, "", false), (429, "rate limit", false),
            (500, "", false), (502, "", false), (0, "", false),
        ]
        for (status, message, expected) in retryCases {
            check("HTTP \(status) \"\(message)\" -> \(expected ? "retry without the web search" : "no retry")",
                  KoncluiVoiceBrain.shouldRetryWithoutWebSearch(status: status, message: message) == expected)
        }
        check("fast model, then the chosen one", KoncluiVoiceBrain.modelOrder(fast: "fast", chosen: "chat", remembered: nil) == ["fast", "chat"])
        check("the model that worked goes first", KoncluiVoiceBrain.modelOrder(fast: "fast", chosen: "chat", remembered: "chat") == ["chat", "fast"])
        check("no model twice, none empty", KoncluiVoiceBrain.modelOrder(fast: "same", chosen: "same", remembered: "") == ["same"])

        print("An answer from the proxy")
        let answer = #"{"id":"msg_1","type":"message","role":"assistant","content":[{"type":"text","text":"Sunny, 24 degrees."}],"stop_reason":"end_turn"}"#
        let turn = KoncluiVoiceBrain.parseTurn(Data(answer.utf8))
        check("content blocks and stop reason", turn?.content.first?["text"] as? String == "Sunny, 24 degrees." && turn?.stopReason == "end_turn")
        let toolUse = #"{"content":[{"type":"tool_use","id":"t1","name":"music","input":{"action":"pause"}}],"stop_reason":"tool_use"}"#
        check("a tool call keeps its stop reason", KoncluiVoiceBrain.parseTurn(Data(toolUse.utf8))?.stopReason == "tool_use")
        check("a missing stop reason reads end_turn", KoncluiVoiceBrain.parseTurn(Data(#"{"content":[]}"#.utf8))?.stopReason == "end_turn")
        check("an error body is not a turn", KoncluiVoiceBrain.parseTurn(Data(#"{"type":"error","error":{"message":"x"}}"#.utf8)) == nil)
        check("garbage is not a turn", KoncluiVoiceBrain.parseTurn(Data("not json".utf8)) == nil)

        if failures > 0 {
            print("\(failures) check(s) failed")
            exit(1)
        }
        print("All checks passed")
    }
}
