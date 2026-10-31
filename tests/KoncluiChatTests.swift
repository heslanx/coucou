import Foundation

// Koncluí chat: the pure parts (login parsing, CLI command lines, CLI output parsing, proxy request
// building) with samples captured from the real CLIs and proxy, and the subprocess runner on /bin/sh.

nonisolated(unsafe) var executedCaseCount = 0

func expect<T: Equatable>(_ actual: T, _ expected: T, _ name: String) {
    precondition(actual == expected, "\(name): expected \(String(reflecting: expected)), got \(String(reflecting: actual))")
    executedCaseCount += 1
}

func expectTrue(_ condition: Bool, _ name: String) { expect(condition, true, name) }

// MARK: - Samples (captured 2026-10-29 from claude 2.1.312, codex-cli 0.165.0 and the proxy)

let claudeStreamOK = [
    #"{"type":"system","subtype":"init","cwd":"/tmp/x","session_id":"8d6af1f6-e2ab-4672-8f91-f9bf41f63e27","model":"claude-opus-5-5"}"#,
    #"{"type":"system","subtype":"status","status":"requesting","session_id":"8d6af1f6-e2ab-4672-8f91-f9bf41f63e27"}"#,
    #"{"type":"stream_event","event":{"type":"message_start","message":{"role":"assistant","content":[]}}}"#,
    #"{"type":"stream_event","event":{"type":"content_block_start","index":0,"content_block":{"type":"thinking","thinking":""}}}"#,
    #"{"type":"stream_event","event":{"type":"content_block_delta","index":0,"delta":{"type":"thinking_delta","thinking":"secret"}}}"#,
    #"{"type":"stream_event","event":{"type":"content_block_stop","index":0}}"#,
    #"{"type":"stream_event","event":{"type":"content_block_start","index":1,"content_block":{"type":"text","text":""}}}"#,
    #"{"type":"stream_event","event":{"type":"content_block_delta","index":1,"delta":{"type":"text_delta","text":"O"}}}"#,
    #"{"type":"stream_event","event":{"type":"content_block_delta","index":1,"delta":{"type":"text_delta","text":"K"}}}"#,
    #"{"type":"assistant","message":{"content":[{"type":"text","text":"OK"}]},"session_id":"8d6af1f6-e2ab-4672-8f91-f9bf41f63e27"}"#,
    #"{"type":"stream_event","event":{"type":"message_stop"}}"#,
    #"{"type":"rate_limit_event"}"#,
    #"{"type":"result","subtype":"success","is_error":false,"result":"OK","session_id":"8d6af1f6-e2ab-4672-8f91-f9bf41f63e27"}"#,
]

let claudeSignedOut = [
    #"{"type":"system","subtype":"init","session_id":"s1"}"#,
    #"{"type":"assistant","message":{"content":[{"type":"text","text":"Not logged in · Please run /login"}]},"error":"authentication_failed"}"#,
    #"{"type":"result","subtype":"success","is_error":true,"result":"Not logged in · Please run /login","session_id":"s1"}"#,
]

let codexStreamOK = [
    #"{"type":"thread.started","thread_id":"01a18909-a10e-7521-9ebb-887431da758b"}"#,
    #"{"type":"turn.started"}"#,
    #"{"type":"item.completed","item":{"id":"item_0","type":"error","message":"Exceeded skills context budget."}}"#,
    #"{"type":"item.completed","item":{"id":"item_1","type":"agent_message","text":"OK"}}"#,
    #"{"type":"turn.completed","usage":{"input_tokens":22195,"output_tokens":5}}"#,
]

let codexSignedOut = [
    #"{"type":"thread.started","thread_id":"01a1890c-6cd4-7cc1-b31a-4105dfaa3394"}"#,
    #"{"type":"turn.started"}"#,
    #"{"type":"error","message":"Reconnecting... 2/5 (unexpected status 401 Unauthorized: Missing bearer or basic authentication in header)"}"#,
    #"{"type":"error","message":"unexpected status 401 Unauthorized: Missing bearer or basic authentication in header"}"#,
    #"{"type":"turn.failed","error":{"message":"unexpected status 401 Unauthorized: Missing bearer or basic authentication in header"}}"#,
]

let proxyStreamOK = [
    "event: message_start",
    #"data: {"type":"message_start","message":{"model":"claude-haiku-5-5","id":"msg_1","type":"message","role":"assistant","content":[]}}"#,
    "",
    "event: content_block_start",
    #"data: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}"#,
    "event: ping",
    #"data: {"type": "ping"}"#,
    "event: content_block_delta",
    #"data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"OK"}       }"#,
    "event: message_delta",
    #"data: {"type":"message_delta","delta":{"stop_reason":"end_turn"},"usage":{"input_tokens":149}}"#,
    "event: message_stop",
    #"data: {"type":"message_stop"   }"#,
]

let klaudeLauncher = """
#!/usr/bin/env bash
# klaude launcher (konclui/klaude)
repo=/Users/someone/Developments/konclui-project/klaude
proxy_url=https://private-cli-proxy-api.konclui.com
service_url=https://private-cli-proxy-api.konclui.com/v0/resource/plugins/konclui/klaude
set +x
key="$(security find-generic-password -a "$USER" -s klaude-api-key -w 2>/dev/null)" || key=""
export ANTHROPIC_BASE_URL="$proxy_url"
"""

func feedAll<S>(_ stream: inout S, _ lines: [String], _ feed: (inout S, String) -> Bool) -> [Bool] {
    lines.map { feed(&stream, $0) }
}

@main
enum KoncluiChatTests {
    static func main() async {
        loginParsing()
        commandLines()
        claudeStreams()
        codexStreams()
        proxyBuilding()
        proxyStreams()
        promptAndModels()
        migration()
        await subprocesses()
        print("KoncluiChatTests: \(executedCaseCount) cases passed")
    }

    // MARK: Detection

    static func loginParsing() {
        let home = "/Users/me"
        let present: Set<String> = ["/opt/homebrew/bin/codex", "/Users/me/.local/bin/claude", "/Users/me/.nvm/versions/node/v22.3.0/bin/codex"]
        expect(KoncluiCLI.find("claude", home: home, isExecutable: present.contains), "/Users/me/.local/bin/claude", "finds claude in ~/.local/bin")
        expect(KoncluiCLI.find("codex", home: home, isExecutable: present.contains), "/opt/homebrew/bin/codex", "homebrew before nvm")
        expect(KoncluiCLI.find("codex", home: home, nvmVersions: ["v20.1.0", "v22.3.0", "v9.0.0"],
                               isExecutable: { $0.contains(".nvm") }), "/Users/me/.nvm/versions/node/v22.3.0/bin/codex", "newest nvm node first")
        expect(KoncluiCLI.find("claude", home: home, isExecutable: { _ in false }), nil, "not installed")
        expect(KoncluiCLI.candidatePaths("claude", home: home).first, "/Users/me/.claude/local/claude", "claude's own folder first")
        expect(KoncluiCLI.candidatePaths("codex", home: home).contains("/Users/me/.claude/local/codex"), false, "only claude has ~/.claude/local")

        let env = KoncluiCLI.environment(base: [
            "PATH": "/usr/bin:/custom/bin", "HOME": "/Users/me", "ANTHROPIC_BASE_URL": "https://proxy", "ANTHROPIC_AUTH_TOKEN": "t",
            "CLAUDE_CONFIG_DIR": "/Users/me/.klaude", "OPENAI_API_KEY": "k", "CODEX_API_KEY": "k", "CLAUDECODE": "1",
        ], executable: "/Users/me/.npm-global/bin/claude", home: "/Users/me")
        for name in ["ANTHROPIC_BASE_URL", "ANTHROPIC_AUTH_TOKEN", "CLAUDE_CONFIG_DIR", "OPENAI_API_KEY", "CODEX_API_KEY", "CLAUDECODE"] {
            expect(env[name], nil, "environment drops \(name)")
        }
        expect(env["HOME"], "/Users/me", "environment keeps HOME")
        expectTrue(env["PATH"]!.hasPrefix("/Users/me/.npm-global/bin:/Users/me/.local/bin:"), "CLI folder leads PATH")
        expectTrue(env["PATH"]!.hasSuffix(":/usr/bin:/custom/bin"), "app PATH kept at the end")

        let claudeIn = #"{"loggedIn":true,"authMethod":"claude.ai","apiProvider":"firstParty","email":"x@example.com","subscriptionType":"max"}"#
        expect(KoncluiCLI.parseClaudeLogin(output: claudeIn, exitCode: 0), .signedIn("Max"), "claude signed in (plan)")
        expect(KoncluiCLI.parseClaudeLogin(output: #"{"loggedIn":true,"authMethod":"claude.ai"}"#, exitCode: 0), .signedIn(nil), "claude signed in (no plan)")
        expect(KoncluiCLI.parseClaudeLogin(output: #"{"loggedIn":false,"authMethod":"none"}"#, exitCode: 1), .signedOut, "claude signed out")
        expect(KoncluiCLI.parseClaudeLogin(output: #"{"loggedIn":true,"subscriptionType":"pro"}"#, exitCode: 1), .signedIn("Pro"), "loggedIn wins over exit code")
        expect(KoncluiCLI.parseClaudeLogin(output: "", exitCode: 1), .signedOut, "claude no output, failed")
        expect(KoncluiCLI.parseClaudeLogin(output: "ok", exitCode: 0), .signedIn(nil), "claude unknown format, exit 0")

        expect(KoncluiCLI.parseCodexLogin(output: "Logged in using ChatGPT", exitCode: 0), .signedIn("ChatGPT"), "codex ChatGPT")
        expect(KoncluiCLI.parseCodexLogin(output: "Logged in using an API key", exitCode: 0), .signedIn("API key"), "codex API key")
        expect(KoncluiCLI.parseCodexLogin(output: "Not logged in", exitCode: 1), .signedOut, "codex signed out")
        expect(KoncluiCLI.parseCodexLogin(output: "Not logged in", exitCode: 0), .signedOut, "codex signed out, any exit")
        expect(KoncluiCLI.parseCodexLogin(output: "Logged in", exitCode: 0), .signedIn(nil), "codex logged in, unknown method")
    }

    // MARK: Command lines

    static func commandLines() {
        let system = "You are Koru."
        let base = KoncluiClaudeCLI.arguments(model: "default", resume: nil, systemPrompt: system)
        expect(base.first, "-p", "claude -p first")
        expectTrue(base.contains("--safe-mode"), "safe mode on")
        expectTrue(!base.contains("--model"), "default model leaves --model out")
        expectTrue(!base.contains("--resume"), "first turn does not resume")
        expect(base[base.firstIndex(of: "--system-prompt")! + 1], system, "system prompt follows its flag")
        expect(base[base.firstIndex(of: "--output-format")! + 1], "stream-json", "stream-json")
        expectTrue(base.contains("--include-partial-messages") && base.contains("--verbose"), "partial messages need --verbose")
        expect(base[base.firstIndex(of: "--tools")! + 1], "WebSearch,WebFetch", "only web tools")
        let mail = KoncluiClaudeCLI.arguments(model: "default", resume: nil, systemPrompt: system, web: false)
        expect(mail[mail.firstIndex(of: "--tools")! + 1], "", "a conversation with email has no tool at all")
        expectTrue(!mail.contains("--allowedTools") && !mail.contains("WebFetch"), "no web tool is allowed with email")
        let file = KoncluiClaudeCLI.arguments(model: "default", resume: nil, systemPrompt: system, web: false,
                                              readDir: URL(fileURLWithPath: "/tmp/koncluí-file"))
        expect(file[file.firstIndex(of: "--tools")! + 1], "Read", "a dropped PDF: Read is the only tool")
        expect(file[file.firstIndex(of: "--add-dir")! + 1], "/tmp/koncluí-file", "and only in the copy's folder")
        expectTrue(!file.contains("WebFetch") && !file.contains("WebSearch"), "no web while the file is read")
        expect(base[base.firstIndex(of: "--permission-mode")! + 1], "dontAsk", "nothing asks for permission")
        let resumed = KoncluiClaudeCLI.arguments(model: "sonnet", resume: "abc-123", systemPrompt: system, safeMode: false)
        expect(resumed[resumed.firstIndex(of: "--model")! + 1], "sonnet", "model alias")
        expect(resumed[resumed.firstIndex(of: "--resume")! + 1], "abc-123", "resume the thread")
        expectTrue(!resumed.contains("--safe-mode"), "safe mode off for an older CLI")
        expect(KoncluiClaudeCLI.arguments(model: "", resume: "", systemPrompt: system).contains("--resume"), false, "empty ids ignored")
        expectTrue(KoncluiClaudeCLI.isUnknownSafeMode(stderr: "error: unknown option '--safe-mode'\n"), "older CLI detected")
        expectTrue(!KoncluiClaudeCLI.isUnknownSafeMode(stderr: "error: unknown option '--bogus'"), "other unknown option is not safe mode")

        let first = KoncluiCodexCLI.arguments(model: "default", resume: nil)
        expect(Array(first.prefix(2)), ["exec", "--json"], "codex exec --json")
        expect(first.last, "-", "prompt from stdin")
        expectTrue(!first.contains("-m") && !first.contains("resume"), "default model, first turn")
        let disabled = first.indices.filter { first[$0] == "--disable" }.map { first[$0 + 1] }
        expect(Set(disabled), ["hooks", "shell_tool", "unified_exec", "apps", "plugins"],
               "no hooks, shell, apps or plugins: it can only answer")
        let configs = first.indices.filter { first[$0] == "-c" }.map { first[$0 + 1] }
        expectTrue(configs.contains(#"sandbox_mode="read-only""#), "read-only sandbox")
        expectTrue(configs.contains(#"web_search="disabled""#), "no web search")
        let next = KoncluiCodexCLI.arguments(model: "gpt-6.1-sol", resume: "01a1-uuid", images: ["/tmp/a.png"])
        expect(Array(next.prefix(4)), ["exec", "resume", "01a1-uuid", "--json"], "codex exec resume <id>")
        expect(next[next.firstIndex(of: "-m")! + 1], "gpt-6.1-sol", "codex model")
        expect(next[next.firstIndex(of: "-i")! + 1], "/tmp/a.png", "codex image")
        expect(next.last, "-", "resume prompt from stdin")
    }

    // MARK: CLI output

    static func claudeStreams() {
        var s = KoncluiClaudeStream()
        let grew = claudeStreamOK.map { s.feed($0) }
        expect(s.text, "OK", "claude text from deltas (thinking left out)")
        expect(grew.filter { $0 }.count, 2, "text grew twice (O, K)")
        expect(s.sessionID, "8d6af1f6-e2ab-4672-8f91-f9bf41f63e27", "claude session id")
        expect(s.failure, nil, "no failure")
        expectTrue(s.finished && !s.needsSignIn, "finished, signed in")

        // A tool round between two texts keeps both, apart.
        var tool = KoncluiClaudeStream()
        for line in [
            #"{"type":"stream_event","event":{"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}}"#,
            #"{"type":"stream_event","event":{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"I'll look that up."}}}"#,
            #"{"type":"stream_event","event":{"type":"content_block_start","index":1,"content_block":{"type":"tool_use","name":"WebSearch"}}}"#,
            #"{"type":"stream_event","event":{"type":"content_block_start","index":2,"content_block":{"type":"text","text":""}}}"#,
            #"{"type":"stream_event","event":{"type":"content_block_delta","index":2,"delta":{"type":"text_delta","text":"It is 42."}}}"#,
            #"{"type":"result","is_error":false,"result":"It is 42.","session_id":"s2"}"#,
        ] { tool.feed(line) }
        expect(tool.text, "I'll look that up.\n\nIt is 42.", "texts around a tool call are separated")
        expect(tool.sessionID, "s2", "session id from the result")

        // An older CLI without partial messages: whole assistant messages.
        var old = KoncluiClaudeStream()
        for line in [
            #"{"type":"assistant","message":{"content":[{"type":"text","text":"Hello"}]}}"#,
            #"{"type":"assistant","message":{"content":[{"type":"tool_use","name":"x"}]}}"#,
            #"{"type":"assistant","message":{"content":[{"type":"text","text":"Done."}]}}"#,
            #"{"type":"result","is_error":false,"result":"Done."}"#,
        ] { old.feed(line) }
        expect(old.text, "Hello\n\nDone.", "assistant messages without partials")

        // Only a result.
        var bare = KoncluiClaudeStream()
        bare.feed(#"{"type":"result","is_error":false,"result":"Just the result"}"#)
        expect(bare.text, "Just the result", "result text when nothing streamed")

        var out = KoncluiClaudeStream()
        claudeSignedOut.forEach { out.feed($0) }
        expectTrue(out.needsSignIn, "signed out detected")
        expect(out.failure, "Not logged in · Please run /login", "the CLI's own words kept")
        expect(out.text, "", "an auth error is not chat text")

        var limit = KoncluiClaudeStream()
        limit.feed(#"{"type":"result","is_error":true,"result":"You've hit your limit · resets 3pm"}"#)
        expectTrue(!limit.needsSignIn && limit.failure == "You've hit your limit · resets 3pm", "a usage limit is not a sign-in problem")
        var silent = KoncluiClaudeStream()
        silent.feed(#"{"type":"result","subtype":"error_during_execution","is_error":true,"num_turns":0}"#)
        expectTrue(silent.failed && silent.failure == nil && !silent.needsSignIn, "an error with no text of its own: stderr speaks")
        expectTrue(KoncluiCLI.isLostThread(stderr: "No conversation found with session ID: 0000"), "claude lost thread")
        expectTrue(KoncluiCLI.isLostThread(stderr: "Error: thread/resume failed: no rollout found for thread id 0000 (code -32600)"), "codex lost thread")
        expectTrue(!KoncluiCLI.isLostThread(stderr: "Reading additional input from stdin..."), "other stderr is not a lost thread")
        var garbage = KoncluiClaudeStream()
        expect(garbage.feed("not json at all"), false, "non-JSON line ignored")
    }

    static func codexStreams() {
        var s = KoncluiCodexStream()
        let grew = codexStreamOK.map { s.feed($0) }
        expect(s.text, "OK", "codex agent_message text (the skills warning is not chat text)")
        expect(grew.filter { $0 }.count, 1, "one message")
        expect(s.threadID, "01a18909-a10e-7521-9ebb-887431da758b", "codex thread id")
        expectTrue(s.finished && s.failure == nil && !s.needsSignIn, "codex finished")

        var two = KoncluiCodexStream()
        two.feed(#"{"type":"item.completed","item":{"type":"agent_message","text":"First."}}"#)
        two.feed(#"{"type":"item.completed","item":{"type":"command_execution","command":"ls"}}"#)
        two.feed(#"{"type":"item.completed","item":{"type":"agent_message","text":"Second."}}"#)
        expect(two.text, "First.\n\nSecond.", "messages around a command")

        var out = KoncluiCodexStream()
        codexSignedOut.forEach { out.feed($0) }
        expectTrue(out.needsSignIn, "codex 401 means sign in")
        expectTrue(out.failure?.hasPrefix("unexpected status 401") == true, "codex failure is the final error, not a reconnect")
        expect(out.text, "", "no text")
        expectTrue(out.finished, "turn.failed finishes")
    }

    // MARK: Proxy

    static func proxyBuilding() {
        expect(KoncluiProxy.baseURL(fromLauncher: klaudeLauncher), "https://private-cli-proxy-api.konclui.com", "proxy_url from the launcher")
        expect(KoncluiProxy.baseURL(fromLauncher: "proxy_url=\"https://p.example.com/\"  # note\n"), "https://p.example.com", "quotes, slash and comment")
        expect(KoncluiProxy.baseURL(fromLauncher: "proxy_url=http://p.example.com"), nil, "plain http to a remote host refused")
        expect(KoncluiProxy.baseURL(fromLauncher: "proxy_url=http://127.0.0.1:8317"), "http://127.0.0.1:8317", "local http allowed")
        expect(KoncluiProxy.baseURL(fromLauncher: "echo hi\nservice_url=https://x.example.com"), nil, "no proxy_url")
        expect(KoncluiProxy.baseURL(fromLauncher: "proxy_url=not a url"), nil, "garbage refused")

        expect(KoncluiProxy.endpoint(base: "https://p.example.com", path: "messages")?.absoluteString, "https://p.example.com/v1/messages", "messages endpoint")
        expect(KoncluiProxy.endpoint(base: "https://p.example.com/v1/", path: "models")?.absoluteString, "https://p.example.com/v1/models", "base that already ends in /v1")

        let messages: [[String: Any]] = [["role": "user", "content": [["type": "text", "text": "Hi"]]]]
        let body = KoncluiProxy.messagesBody(model: "claude-sonnet-5-5", system: "You are Koru.", messages: messages)!
        let json = try! JSONSerialization.jsonObject(with: body) as! [String: Any]
        expect(json["model"] as? String, "claude-sonnet-5-5", "body model")
        expect(json["stream"] as? Bool, true, "body streams")
        expect(json["system"] as? String, "You are Koru.", "body system")
        expect(json["max_tokens"] as? Int, 4096, "body max_tokens")
        expect((json["messages"] as? [[String: Any]])?.count, 1, "body messages")
        expectTrue(json["tools"] == nil, "no web search tool for the proxy models")

        let token = "tok-NOT-A-REAL-KEY"
        let request = KoncluiProxy.messagesRequest(base: "https://p.example.com", token: token, body: body)!
        expect(request.url?.absoluteString, "https://p.example.com/v1/messages", "request URL")
        expect(request.httpMethod, "POST", "request method")
        expect(request.value(forHTTPHeaderField: "Authorization"), "Bearer \(token)", "bearer token")
        expect(request.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01", "anthropic-version")
        expect(request.value(forHTTPHeaderField: "content-type"), "application/json", "content type")
        expect(request.httpBody, body, "request body")
        expectTrue(String(decoding: request.httpBody!, as: UTF8.self).contains(token) == false, "the token is a header, never in the body")
        expect(request.url?.absoluteString.contains(token), false, "the token is not in the URL")
        let models = KoncluiProxy.modelsRequest(base: "https://p.example.com", token: token)!
        expectTrue(models.url?.absoluteString.hasPrefix("https://p.example.com/v1/models") == true, "models URL")
        expect(models.value(forHTTPHeaderField: "Authorization"), "Bearer \(token)", "models bearer")

        let list = #"{"data":[{"id":"claude-haiku-5-5","display_name":"Claude Haiku 5.5","type":"model"},{"id":"claude-fable-5-dd-4-inimeg","display_name":"Gemini 4"},{"id":"bare-id"},{"display_name":"no id"}],"has_more":false}"#
        expect(KoncluiProxy.parseModels(Data(list.utf8)), [
            KoncluiModel(id: "claude-haiku-5-5", label: "Claude Haiku 5.5"),
            KoncluiModel(id: "claude-fable-5-dd-4-inimeg", label: "Gemini 4"),
            KoncluiModel(id: "bare-id", label: "bare-id"),
        ], "model discovery")
        expect(KoncluiProxy.parseModels(Data("nope".utf8)), [], "bad model list")

        expect(KoncluiProxy.errorMessage(body: Data(#"{"type":"error","error":{"type":"authentication_error","message":"invalid key \#(token)"}}"#.utf8),
                                         status: 401, token: token), "invalid key •••", "server text, token wiped")
        expect(KoncluiProxy.errorMessage(body: Data("<html>".utf8), status: 502, token: token), "HTTP 502", "non-JSON body")
        expect(KoncluiProxy.redact("a \(token) b \(token)", token: token), "a ••• b •••", "every echo wiped")
        expect(KoncluiProxy.redact("unchanged", token: ""), "unchanged", "empty token")
    }

    static func proxyStreams() {
        var text = ""
        var done = false
        for line in proxyStreamOK {
            switch KoncluiProxy.streamEvent(line: line) {
            case .text(let piece): text += piece
            case .done: done = true
            case .failure, .ignored: break
            }
        }
        expect(text, "OK", "proxy SSE text (including JSON padded with spaces)")
        expectTrue(done, "message_stop ends the stream")
        expect(KoncluiProxy.streamEvent(line: "event: content_block_delta"), .ignored, "event lines carry nothing")
        expect(KoncluiProxy.streamEvent(line: #"data: {"type":"ping"}"#), .ignored, "ping")
        expect(KoncluiProxy.streamEvent(line: #"data: {"type":"error","error":{"type":"overloaded_error","message":"Overloaded"}}"#), .failure("Overloaded"), "stream error")
        expect(KoncluiProxy.streamEvent(line: #"data: {"type":"content_block_delta","delta":{"type":"input_json_delta","partial_json":"{"}}"#), .ignored, "tool deltas ignored")
        expect(KoncluiProxy.streamEvent(line: "data: not json"), .ignored, "bad JSON ignored")
    }

    static func migration() {
        let suite = "konclui-chat-migration-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("claude-code", forKey: "chatProvider")
        defaults.set("opus", forKey: "claudeCodeChatModel")
        KoncluiChatMigration.run(defaults)
        expect(defaults.string(forKey: "chatProvider"), "anthropic", "Claude Code became Anthropic")
        expect(defaults.object(forKey: "chat.useSubscription.anthropic") as? Bool, true, "with its subscription switch on")
        expectTrue(defaults.object(forKey: "claudeCodeChatModel") == nil, "the old model key is gone")
        defaults.set("codex", forKey: "chatProvider")
        KoncluiChatMigration.run(defaults)
        expect(defaults.string(forKey: "chatProvider"), "openai", "Codex became OpenAI")
        expect(defaults.object(forKey: "chat.useSubscription.openai") as? Bool, true, "with its subscription switch on")
        defaults.set("google", forKey: "chatProvider")
        defaults.set(false, forKey: "chat.useSubscription.google")
        KoncluiChatMigration.run(defaults)
        expect(defaults.string(forKey: "chatProvider"), "google", "any other choice stays")
        expect(defaults.object(forKey: "chat.useSubscription.google") as? Bool, false, "and its switch is not touched")
    }

    static func promptAndModels() {
        expect(KoncluiPrompt.turn(query: "Q", persona: "P", context: "C"), "P\n\nC\n\nQ", "first turn: persona, context, question")
        expect(KoncluiPrompt.turn(query: "Q", persona: nil, context: nil), "Q", "later turn: the question")
        expect(KoncluiPrompt.turn(query: "Q", persona: "", context: ""), "Q", "empty parts dropped")

        expect(KoncluiClaudeCLI.models.first?.id, "default", "claude aliases start with the default")
    }

    // MARK: Subprocesses

    static func subprocesses() async {
        var lines: [String] = []
        var exitCode: Int32 = -99
        var stderr = ""
        for await event in KoncluiProcess.stream("/bin/sh", ["-c", "printf 'a\\nb'; echo oops >&2; exit 3"], timeout: 10) {
            switch event {
            case .line(let l): lines.append(l)
            case .exit(let code, let err, _): exitCode = code; stderr = err
            case .failedToStart: break
            }
        }
        expect(lines, ["a", "b"], "lines, the last without a newline")
        expect(exitCode, 3, "exit code")
        expectTrue(stderr.contains("oops"), "stderr tail")

        let echoed = await KoncluiProcess.capture("/bin/cat", [], input: Data("from stdin\nline 2\n".utf8), timeout: 10)
        expect(echoed?.stdout, "from stdin\nline 2", "the prompt goes in through stdin")

        let many = await KoncluiProcess.capture("/bin/sh", ["-c", "i=0; while [ $i -lt 20000 ]; do echo line$i; i=$((i+1)); done"], timeout: 30)
        expect(many?.stdout.split(separator: "\n").count, 20000, "20000 lines, none lost")

        let env = await KoncluiProcess.capture("/bin/sh", ["-c", "echo \"${KONCLUI_PROBE:-unset}\""], environment: ["KONCLUI_PROBE": "yes", "PATH": "/usr/bin:/bin"], timeout: 10)
        expect(env?.stdout, "yes", "environment passed")

        let missing = await KoncluiProcess.capture("/nonexistent/claude", [], timeout: 5)
        expectTrue(missing == nil, "a missing binary is nil, not a hang")

        let started = Date()
        let slow = await KoncluiProcess.capture("/bin/sleep", ["30"], timeout: 0.5)
        expectTrue(slow?.timedOut == true, "timeout flagged")
        expectTrue(Date().timeIntervalSince(started) < 5, "timeout ends the process promptly")

        // Cancelling the consumer ends the subprocess.
        let pidFile = NSTemporaryDirectory() + "konclui-chat-test-\(getpid()).pid"
        try? FileManager.default.removeItem(atPath: pidFile)
        let consumer = Task {
            for await _ in KoncluiProcess.stream("/bin/sh", ["-c", "echo $$ > '\(pidFile)'; exec sleep 30"], timeout: 60) {}
        }
        var pid: Int32 = 0
        for _ in 0..<50 {
            if let text = try? String(contentsOfFile: pidFile, encoding: .utf8),
               let value = Int32(text.trimmingCharacters(in: .whitespacesAndNewlines)) { pid = value; break }
            try? await Task.sleep(for: .milliseconds(100))
        }
        expectTrue(pid > 0 && kill(pid, 0) == 0, "child running before cancel")
        consumer.cancel()
        var gone = false
        for _ in 0..<50 {
            try? await Task.sleep(for: .milliseconds(100))
            if kill(pid, 0) != 0 { gone = true; break }
        }
        expectTrue(gone, "cancelling the chat ends the subprocess")
        try? FileManager.default.removeItem(atPath: pidFile)
    }
}
