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

// Captured live 2026-10-31 from cursor-agent 2026.10.19-6bbf2c4 (`-p --output-format stream-json
// --stream-partial-output --mode ask`): a streamed answer, then a turn with a file read between two texts.
let cursorStreamOK = [
    #"{"type":"system","subtype":"init","apiKeySource":"login","cwd":"/private/tmp/kchat-cursor","session_id":"61ca2569-182e-4b68-b456-cf598d41592c","model":"Auto","permissionMode":"default"}"#,
    #"{"type":"user","message":{"role":"user","content":[{"type":"text","text":"Count from 1 to 15 in words, one per line."}]},"session_id":"61ca2569-182e-4b68-b456-cf598d41592c"}"#,
    #"{"type":"thinking","subtype":"delta","text":"I","session_id":"61ca2569-182e-4b68-b456-cf598d41592c","timestamp_ms":1793484125434}"#,
    #"{"type":"thinking","subtype":"completed","session_id":"61ca2569-182e-4b68-b456-cf598d41592c","timestamp_ms":1793484125436}"#,
    #"{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"one\ntwo\nthree"}]},"session_id":"61ca2569-182e-4b68-b456-cf598d41592c","timestamp_ms":1793484125436}"#,
    #"{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"\nfour\nfive"}]},"session_id":"61ca2569-182e-4b68-b456-cf598d41592c","timestamp_ms":1793484125437}"#,
    #"{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"one\ntwo\nthree\nfour\nfive"}]},"session_id":"61ca2569-182e-4b68-b456-cf598d41592c"}"#,
    #"{"type":"result","subtype":"success","duration_ms":5875,"duration_api_ms":5875,"is_error":false,"result":"one\ntwo\nthree\nfour\nfive","session_id":"61ca2569-182e-4b68-b456-cf598d41592c","request_id":"4b0f2abe-b261-4e6d-8ada-0f77ab2a90cc"}"#,
]

let cursorStreamWithTool = [
    #"{"type":"system","subtype":"init","session_id":"46257452-a900-4204-848c-5ec6e1dfdf13","model":"Auto"}"#,
    #"{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"I'll read that file."}]},"session_id":"46257452-a900-4204-848c-5ec6e1dfdf13","timestamp_ms":1793484230289}"#,
    #"{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"I'll read that file."}]},"session_id":"46257452-a900-4204-848c-5ec6e1dfdf13","model_call_id":"9d28ab44-0-l7ba","timestamp_ms":1793484230290}"#,
    #"{"type":"tool_call","subtype":"started","call_id":"c1","tool_call":{"readToolCall":{"args":{"path":"/tmp/secret.txt"}}},"model_call_id":"9d28ab44-0-l7ba","session_id":"46257452-a900-4204-848c-5ec6e1dfdf13","timestamp_ms":1793484230369}"#,
    #"{"type":"tool_call","subtype":"completed","call_id":"c1","tool_call":{"readToolCall":{"args":{"path":"/tmp/secret.txt"},"result":{"error":{"errorMessage":"Permission denied"}}}},"model_call_id":"9d28ab44-0-l7ba","session_id":"46257452-a900-4204-848c-5ec6e1dfdf13","timestamp_ms":1793484230400}"#,
    #"{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"CANNOT"}]},"session_id":"46257452-a900-4204-848c-5ec6e1dfdf13","timestamp_ms":1793484237247}"#,
    #"{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"CANNOT"}]},"session_id":"46257452-a900-4204-848c-5ec6e1dfdf13"}"#,
    #"{"type":"result","subtype":"success","is_error":false,"result":"I'll read that file.CANNOT","session_id":"46257452-a900-4204-848c-5ec6e1dfdf13"}"#,
]

/// Cursor signed out: nothing on stdout, exit 1, this on stderr (captured with an empty HOME).
let cursorSignedOutStderr = "Error: Authentication required. Please run 'agent login' first, or set CURSOR_API_KEY environment variable.\n"

// Gemini CLI `-p --output-format stream-json`: the event types of packages/core/src/output/types.ts and the example
// lines of google-gemini/gemini-cli PR #10883 (v0.11.0). Not captured: gemini is not installed here.
let geminiStreamOK = [
    #"{"type":"init","timestamp":"2026-10-31T10:00:00.000Z","session_id":"5f0c3a52-1d6e-4c1b-9a43-2b8c1f0e7d10","model":"gemini-3-pro"}"#,
    #"{"type":"message","timestamp":"2026-10-31T10:00:00.010Z","role":"user","content":"What is new in Swift?"}"#,
    #"{"type":"message","timestamp":"2026-10-31T10:00:01.000Z","role":"assistant","content":"Let me search.","delta":true}"#,
    #"{"type":"tool_use","timestamp":"2026-10-31T10:00:01.100Z","tool_name":"google_web_search","tool_id":"t1","parameters":{"query":"Swift news"}}"#,
    #"{"type":"tool_result","timestamp":"2026-10-31T10:00:02.000Z","tool_id":"t1","status":"success","output":"…"}"#,
    #"{"type":"message","timestamp":"2026-10-31T10:00:03.000Z","role":"assistant","content":"Swift 7 ","delta":true}"#,
    #"{"type":"message","timestamp":"2026-10-31T10:00:03.100Z","role":"assistant","content":"is out.","delta":true}"#,
    #"{"type":"result","timestamp":"2026-10-31T10:00:03.200Z","status":"success","stats":{"total_tokens":120,"input_tokens":100,"output_tokens":20,"duration_ms":3200,"tool_calls":1}}"#,
]

let geminiStreamFailed = [
    #"{"type":"init","timestamp":"2026-10-31T10:00:00.000Z","session_id":"s-err","model":"gemini-3-pro"}"#,
    #"{"type":"error","timestamp":"2026-10-31T10:00:01.000Z","severity":"warning","message":"Loop detected, stopping execution"}"#,
    #"{"type":"result","timestamp":"2026-10-31T10:00:01.100Z","status":"error","error":{"type":"FatalTurnLimitedError","message":"Maximum session turns exceeded"},"stats":{"total_tokens":0}}"#,
]

/// Gemini CLI with no sign-in, stream-json: stderr only, exit 41 (packages/cli/src/validateNonInterActiveAuth.ts).
let geminiSignedOutStderr = "Please set an Auth method in your /Users/me/.gemini/settings.json or specify one of the following environment variables before running: GEMINI_API_KEY, GOOGLE_GENAI_USE_VERTEXAI, GOOGLE_GENAI_USE_GCA\n"

// Antigravity CLI `-p --output-format stream-json`: the lines of antigravity.google/docs/cli/headless (v1.1.8+).
// Not captured: agy is not installed here.
let antigravityStreamOK = [
    #"{"event":"init","conversation_id":"c3b6e2a4-7d1f-4f7a-9a52-1f6d0b9e8c21","init":{"cwd":"/Users/me/Library/Application Support/Konclui/chat","tools":["view_file"],"permission_mode":"request-review"}}"#,
    #"{"event":"step_update","step_update":{"conversation_id":"c3b6e2a4-7d1f-4f7a-9a52-1f6d0b9e8c21","step_index":1,"state":"DONE","step_type":"user_input"}}"#,
    #"{"event":"step_update","step_update":{"conversation_id":"c3b6e2a4-7d1f-4f7a-9a52-1f6d0b9e8c21","step_index":2,"state":"ACTIVE","step_type":"agent_response","text_delta":"app"}}"#,
    #"{"event":"step_update","step_update":{"conversation_id":"c3b6e2a4-7d1f-4f7a-9a52-1f6d0b9e8c21","step_index":2,"state":"ACTIVE","step_type":"agent_response","text_delta":"le"}}"#,
    #"{"event":"result","result":{"conversation_id":"c3b6e2a4-7d1f-4f7a-9a52-1f6d0b9e8c21","status":"SUCCESS","response":"apple\n","duration_seconds":1.43,"num_turns":1,"usage":{}}}"#,
]

let antigravityStreamFailed = [
    #"{"event":"result","result":{"conversation_id":"","status":"ERROR","response":"","error":"invalid model selection","duration_seconds":0.2,"num_turns":0}}"#,
]

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
        adapterCommandLines()
        adapterStreams()
        engineRules()
        conversationThreads()
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
                                              readDir: URL(fileURLWithPath: "/Users/test/koncluí-file"))
        expect(file[file.firstIndex(of: "--tools")! + 1], "Read", "a dropped PDF: Read is the only tool")
        expect(file[file.firstIndex(of: "--allowedTools")! + 1], "Read(//Users/test/koncluí-file/**)",
               "allowed only inside the copy's folder (dontAsk refuses the rest)")
        expect(file[file.firstIndex(of: "--add-dir")! + 1], "/Users/test/koncluí-file", "the copy's folder is added")
        expectTrue(!file.contains("WebFetch") && !file.contains("WebSearch"), "no web while the file is read")
        expect(base[base.firstIndex(of: "--permission-mode")! + 1], "dontAsk", "nothing asks for permission")
        expect(base[base.firstIndex(of: "--setting-sources")! + 1], "", "no settings file: no user hooks or permissions")
        expectTrue(base.contains("--strict-mcp-config") && base.contains("--disable-slash-commands"), "no MCP, no slash commands")
        let older = KoncluiClaudeCLI.arguments(model: "default", resume: nil, systemPrompt: system, safeMode: false)
        expectTrue(older.contains("--strict-mcp-config") && older.contains("--setting-sources"),
                   "an older CLI retried without --safe-mode keeps the isolation")
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
        expectTrue(first.contains("--ignore-user-config") && first.contains("--ignore-rules"),
                   "the user's config (its MCP servers) and rules are not loaded")
        expect(KoncluiCodexCLI.model(fromConfig: "model = \"gpt-6-astra\"\nmodel_reasoning_effort = \"medium\"\n"),
               "gpt-6-astra", "the model chosen in Codex's config")
        expect(KoncluiCodexCLI.model(fromConfig: "# x\n[profiles.fast]\nmodel = \"gpt-mini\"\n"), nil,
               "a profile's model is not the top-level choice")
        expect(KoncluiCodexCLI.model(fromConfig: "model_provider = \"openai\"\n"), nil, "model_provider is not model")
        expect(KoncluiCodexCLI.model(fromConfig: "model = 'gpt-6.1-sol' # chosen\n"), "gpt-6.1-sol", "a TOML literal string")
        expect(KoncluiCodexCLI.model(fromConfig: "  model=\"gpt-6-luna\"   # x\n"), "gpt-6-luna", "spaces and a comment")
        expect(KoncluiCodexCLI.model(fromConfig: "# model = \"old\"\nmodel = \"new\"\n"), "new", "a commented line is skipped")
        let next = KoncluiCodexCLI.arguments(model: "gpt-6.1-sol", resume: "01a1-uuid", images: ["/tmp/a.png"])
        expect(Array(next.prefix(4)), ["exec", "resume", "01a1-uuid", "--json"], "codex exec resume <id>")
        expect(next[next.firstIndex(of: "-m")! + 1], "gpt-6.1-sol", "codex model")
        expect(next[next.firstIndex(of: "-i")! + 1], "/tmp/a.png", "codex image")
        expect(next.last, "-", "resume prompt from stdin")
    }

    // MARK: Adapters

    static func adapterCommandLines() {
        let turn = KoncluiCLITurn(prompt: "Q", system: "S", resume: nil, web: true)
        let resumed = KoncluiCLITurn(prompt: "Q2", resume: "thread-1", web: true)

        let claude = KoncluiClaudeAdapter(model: "opus")
        let claudePlan = claude.plan(turn)
        expect(claudePlan.stdin, "Q", "claude: the prompt on stdin")
        expect(claudePlan.arguments[claudePlan.arguments.firstIndex(of: "--system-prompt")! + 1], "S", "claude: system prompt flag")
        expectTrue(claudePlan.arguments.contains("--safe-mode"), "claude: safe mode first")
        let older = claude.fallback(turn, stderr: "error: unknown option '--safe-mode'")
        expectTrue(older != nil && !older!.arguments.contains("--safe-mode") && older!.arguments.contains("--strict-mcp-config"),
                   "claude: an older CLI runs again without --safe-mode, isolation kept")
        expect(claude.fallback(turn, stderr: "error: unknown option '--bogus'"), nil, "claude: no retry for another error")
        expect(claude.needsSignIn(stderr: "please log in"), false, "claude: its stream says sign-in, not stderr")

        let codex = KoncluiCodexAdapter(model: "gpt-6")
        let codexPlan = codex.plan(KoncluiCLITurn(prompt: "Q", resume: "t1", images: ["/tmp/a.png"]))
        expect(Array(codexPlan.arguments.prefix(3)), ["exec", "resume", "t1"], "codex: resume")
        expect(codexPlan.arguments[codexPlan.arguments.firstIndex(of: "-i")! + 1], "/tmp/a.png", "codex: image")
        expect(codexPlan.stdin, "Q", "codex: the prompt on stdin")
        expect(codex.searchesWeb, false, "codex: no web tool to tell the model about")

        let cursor = KoncluiCursorAdapter(workDir: "/K/chat", configDir: "/K/cursor", currentConfig: nil, userConfig: nil)
        let cursorPlan = cursor.plan(turn)
        expect(Array(cursorPlan.arguments.prefix(6)), ["-p", "--output-format", "stream-json", "--stream-partial-output", "--mode", "ask"],
               "cursor: print mode, streamed text deltas, ask mode")
        expectTrue(cursorPlan.arguments.contains("--trust"), "cursor: trusts Koncluí's chat folder without asking")
        for flag in ["--force", "--yolo", "--approve-mcps", "--auto-review"] {
            expectTrue(!cursorPlan.arguments.contains(flag), "cursor: never \(flag)")
        }
        expect(cursorPlan.stdin, "Q", "cursor: the prompt on stdin")
        expectTrue(!cursorPlan.arguments.contains("Q"), "cursor: the prompt is not in the arguments")
        expect(cursorPlan.environment["CURSOR_CONFIG_DIR"], "/K/cursor", "cursor: Koncluí's own config folder")
        expect(Set(cursorPlan.files.keys), ["/K/chat/.cursor/cli.json", "/K/cursor/cli-config.json"], "cursor: both permission files")
        expect(Array(cursor.plan(resumed).arguments.suffix(2)), ["--resume", "thread-1"], "cursor: resume its chat")

        let open = KoncluiCLI.jsonObject(KoncluiCursorCLI.projectConfig(web: true))?["permissions"] as? [String: [String]]
        expect(open?["deny"], ["Read(/**)", "Read(**)", "Write(/**)", "Write(**)", "Shell(*)", "Mcp(*:*)"],
               "cursor: no read, write, shell or MCP tool, anywhere")
        expect(open?["allow"], ["WebFetch(*)"], "cursor: web fetch for the chat")
        let closed = KoncluiCLI.jsonObject(KoncluiCursorCLI.projectConfig(web: false))?["permissions"] as? [String: [String]]
        expectTrue(closed?["deny"]?.contains("WebFetch(*)") == true && closed?["allow"] == [], "cursor: no web fetch with outside text")

        let user = #"{"model":{"modelId":"gpt-6","displayName":"GPT-6"},"selectedModel":{"modelId":"gpt-6"},"approvalMode":"unrestricted","autoAcceptWebSearch":true,"permissions":{"allow":["Read(**)","Shell(*)"],"deny":[]}}"#
        let current = #"{"version":1,"serverConfigCache":{"k":1},"model":{"modelId":"old"}}"#
        let config = KoncluiCLI.jsonObject(KoncluiCursorCLI.config(current: current, user: user, web: false))
        expect((config?["model"] as? [String: Any])?["modelId"] as? String, "gpt-6", "cursor: the model chosen in Cursor is kept")
        expect((config?["selectedModel"] as? [String: Any])?["modelId"] as? String, "gpt-6", "cursor: and its selection")
        expectTrue(config?["serverConfigCache"] != nil, "cursor: what Cursor keeps in Koncluí's config stays")
        expect(config?["approvalMode"] as? String, "allowlist", "cursor: the user's approval mode is not carried")
        expect(config?["autoAcceptWebSearch"] as? Bool, false, "cursor: no web search with outside text, whatever the user chose")
        expect((config?["permissions"] as? [String: [String]])?["allow"], [], "cursor: the user's allow list is not carried")
        let fresh = KoncluiCLI.jsonObject(KoncluiCursorCLI.config(current: "not json", user: nil, web: true))
        expect(fresh?["autoAcceptWebSearch"] as? Bool, true, "cursor: web search for the chat")
        expect(fresh?["version"] as? Int, 1, "cursor: a config Cursor accepts (version)")
        expectTrue(fresh?["model"] == nil, "cursor: no model chosen, Cursor's default")
        expect(KoncluiCursorCLI.userConfigPath(environment: [:], home: "/Users/me"), "/Users/me/.cursor/cli-config.json", "cursor: user config")
        expect(KoncluiCursorCLI.userConfigPath(environment: ["CURSOR_CONFIG_DIR": "/x"], home: "/Users/me"), "/x/cli-config.json",
               "cursor: user config under CURSOR_CONFIG_DIR")

        // `cursor-agent about --format json`, captured signed in and with an empty HOME (signed out).
        expect(KoncluiCursorCLI.parseLogin(output: #"{"cliVersion":"2026.10.19-6bbf2c4","model":"Auto","subscriptionTier":"Ultra","userEmail":"me@example.com"}"#),
               .signedIn("Ultra"), "cursor: signed in, its plan")
        expect(KoncluiCursorCLI.parseLogin(output: #"{"cliVersion":"2026.10.19-6bbf2c4","subscriptionTier":null,"userEmail":null}"#),
               .signedOut, "cursor: signed out")
        expect(KoncluiCursorCLI.parseLogin(output: #"{"userEmail":"me@example.com","subscriptionTier":""}"#), .signedIn(nil), "cursor: no plan")
        expect(KoncluiCursorCLI.parseLogin(output: #"{"status":"unauthenticated","isAuthenticated":false,"message":"Not logged in"}"#),
               .signedOut, "cursor: status --format json, signed out")
        expect(KoncluiCursorCLI.parseLogin(output: "✓ Logged in"), nil, "cursor: text output is not read as a status")

        let gemini = KoncluiGeminiAdapter(policyPath: "/K/gemini/chat-policy.toml")
        let geminiPlan = gemini.plan(turn)
        expect(Array(geminiPlan.arguments.prefix(2)), ["-p", "Q"], "gemini: the prompt as the relay passes it")
        for (flag, value) in [("--output-format", "stream-json"), ("--approval-mode", "plan"), ("--extensions", "none"),
                              ("--allowed-mcp-server-names", "coucou-none"), ("--policy", "/K/gemini/chat-policy.toml")] {
            expect(geminiPlan.arguments[geminiPlan.arguments.firstIndex(of: flag)! + 1], value, "gemini: \(flag) \(value)")
        }
        expectTrue(geminiPlan.arguments.contains("--skip-trust"), "gemini: Koncluí's folder needs no trust prompt")
        expectTrue(!geminiPlan.arguments.contains("--yolo") && !geminiPlan.arguments.contains("--resume"), "gemini: first turn")
        expect(Array(gemini.plan(resumed).arguments.suffix(2)), ["--resume", "thread-1"], "gemini: resume its session")
        let policy = geminiPlan.files["/K/gemini/chat-policy.toml"] ?? ""
        for tool in ["exit_plan_mode", "run_shell_command", "write_file", "read_file"] {
            expectTrue(policy.contains("\"\(tool)\""), "gemini: \(tool) denied on every turn")
        }
        expectTrue(policy.contains(#"decision = "deny""#) && !policy.contains("google_web_search"), "gemini: web for the chat")
        let noWebPolicy = gemini.plan(KoncluiCLITurn(prompt: "Q", web: false)).files["/K/gemini/chat-policy.toml"] ?? ""
        expectTrue(noWebPolicy.contains(#""google_web_search""#) && noWebPolicy.contains(#""web_fetch""#), "gemini: no web with outside text")

        let agyPlan = KoncluiAntigravityAdapter().plan(turn)
        expect(Array(agyPlan.arguments.prefix(2)), ["-p", "Q"], "antigravity: the prompt as the relay passes it")
        expect(agyPlan.arguments[agyPlan.arguments.firstIndex(of: "--output-format")! + 1], "stream-json", "antigravity: stream-json")
        expect(agyPlan.arguments[agyPlan.arguments.firstIndex(of: "--mode")! + 1], "plan", "antigravity: plan mode")
        expectTrue(agyPlan.arguments.contains("--disable-slash-commands"), "antigravity: no slash commands or skills")
        expect(Array(KoncluiAntigravityAdapter().plan(resumed).arguments.suffix(2)), ["--conversation", "thread-1"],
               "antigravity: continue its conversation")

        let copilot = KoncluiCopilotAdapter()
        let copilotPlan = copilot.plan(KoncluiCLITurn(prompt: "Q", system: "S", web: false))
        expect(copilotPlan.arguments[1], "<instructions>\nS\n</instructions>\n\nQ", "copilot: the relay's prompt, system on top")
        expect(copilotPlan.arguments[copilotPlan.arguments.firstIndex(of: "--available-tools")! + 1], "view",
               "copilot: no web tool with outside text (the relay's rule)")
        for flag in ["--silent", "--no-custom-instructions", "--disable-builtin-mcps", "--no-ask-user"] {
            expectTrue(copilotPlan.arguments.contains(flag), "copilot: \(flag), as the relay")
        }
        expectTrue(copilot.plan(turn).arguments.contains("web_fetch"), "copilot: web fetch for the chat")
        expect(copilot.systemPrompt, .everyTurn, "copilot: no thread, the conversation goes with every turn")
    }

    static func adapterStreams() {
        var cursor = KoncluiCursorStream()
        let grew = cursorStreamOK.map { cursor.feed($0) }
        expect(cursor.text, "one\ntwo\nthree\nfour\nfive", "cursor: text from the deltas, the end-of-turn flush not repeated")
        expect(grew.filter { $0 }.count, 2, "cursor: grew once per delta")
        expect(cursor.threadID, "61ca2569-182e-4b68-b456-cf598d41592c", "cursor: its chat id")
        expectTrue(!cursor.failed && cursor.finished, "cursor: finished")

        var tool = KoncluiCursorStream()
        cursorStreamWithTool.forEach { _ = tool.feed($0) }
        expect(tool.text, "I'll read that file.\n\nCANNOT", "cursor: texts around a tool call, apart, flushes skipped")

        var whole = KoncluiCursorStream()
        for line in [#"{"type":"assistant","message":{"content":[{"type":"text","text":"Hello"}]}}"#,
                     #"{"type":"assistant","message":{"content":[{"type":"text","text":"Done."}]}}"#] { _ = whole.feed(line) }
        expect(whole.text, "Hello\n\nDone.", "cursor: without partial output, whole messages")

        var bare = KoncluiCursorStream()
        _ = bare.feed(#"{"type":"result","subtype":"success","is_error":false,"result":"Only this"}"#)
        expect(bare.text, "Only this", "cursor: the result when nothing streamed")

        var refused = KoncluiCursorStream()
        _ = refused.feed(#"{"type":"result","is_error":true,"result":"You've hit your usage limit"}"#)
        expectTrue(refused.failed && refused.failure == "You've hit your usage limit" && !refused.needsSignIn,
                   "cursor: an error result is a failure in its own words")

        var signedOut = KoncluiCursorStream()
        signedOut.end(exitCode: 1)
        expectTrue(signedOut.failed && signedOut.text.isEmpty, "cursor: exit 1 with no result failed")
        expectTrue(KoncluiCursorAdapter(workDir: "", configDir: "", currentConfig: nil, userConfig: nil)
                    .needsSignIn(stderr: cursorSignedOutStderr), "cursor: its stderr asks for a sign-in")
        var cut = KoncluiCursorStream()
        _ = cut.feed(cursorStreamOK[4])
        cut.end(exitCode: 1)
        expectTrue(cut.failed, "cursor: a stream cut before its result failed, partial text not shown as the answer")

        var gemini = KoncluiGeminiStream()
        let geminiGrew = geminiStreamOK.map { gemini.feed($0) }
        expect(gemini.text, "Let me search.\n\nSwift 7 is out.", "gemini: assistant deltas, apart around a tool, the user's message left out")
        expect(geminiGrew.filter { $0 }.count, 3, "gemini: grew once per delta")
        expect(gemini.threadID, "5f0c3a52-1d6e-4c1b-9a43-2b8c1f0e7d10", "gemini: session id from init")
        expectTrue(!gemini.failed, "gemini: success")
        var repeated = KoncluiGeminiStream()
        _ = repeated.feed(geminiStreamOK[2])
        _ = repeated.feed(#"{"type":"message","role":"assistant","content":"Let me search."}"#)
        expect(repeated.text, "Let me search.", "gemini: a whole message after its deltas is not repeated")
        var geminiFailed = KoncluiGeminiStream()
        geminiStreamFailed.forEach { _ = geminiFailed.feed($0) }
        expectTrue(geminiFailed.failed && geminiFailed.failure == "Maximum session turns exceeded",
                   "gemini: an error result, its message (the warning before it is not the failure)")
        var geminiOut = KoncluiGeminiStream()
        geminiOut.end(exitCode: 41)
        expectTrue(geminiOut.failed, "gemini: exit 41 with no result failed")
        expectTrue(KoncluiGeminiAdapter(policyPath: "").needsSignIn(stderr: geminiSignedOutStderr), "gemini: its stderr asks for a sign-in")

        var agy = KoncluiAntigravityStream()
        let agyGrew = antigravityStreamOK.map { agy.feed($0) }
        expect(agy.text, "apple", "antigravity: text deltas; the result's response matches")
        expect(agyGrew.filter { $0 }.count, 2, "antigravity: grew once per delta")
        expect(agy.threadID, "c3b6e2a4-7d1f-4f7a-9a52-1f6d0b9e8c21", "antigravity: conversation id")
        var agyDone = KoncluiAntigravityStream()
        _ = agyDone.feed(antigravityStreamOK[2])
        _ = agyDone.feed(#"{"event":"result","result":{"conversation_id":"c","status":"SUCCESS","response":"apple pie"}}"#)
        expect(agyDone.text, "apple pie", "antigravity: the result's response is the answer the relay would show")
        var agyFailed = KoncluiAntigravityStream()
        antigravityStreamFailed.forEach { _ = agyFailed.feed($0) }
        expectTrue(agyFailed.failed && agyFailed.failure == "invalid model selection", "antigravity: error is a string")
        var agyCut = KoncluiAntigravityStream()
        agyCut.end(exitCode: 3)
        expectTrue(agyCut.failed, "antigravity: exit 3 (AGY_ERROR on stderr) failed")

        var plain = KoncluiPlainStream()
        for line in ["", "\u{1B}[1mHello\u{1B}[0m", "", "world"] { _ = plain.feed(line) }
        plain.end(exitCode: 0)
        expect(plain.text, "Hello\n\nworld", "copilot: plain lines, colours and leading blank lines dropped")
        expectTrue(!plain.failed, "copilot: exit 0 answered")
        var plainFailed = KoncluiPlainStream()
        _ = plainFailed.feed("partial")
        plainFailed.end(exitCode: 1)
        expectTrue(plainFailed.failed, "copilot: exit 1 is no answer, as the relay")
    }

    static func engineRules() {
        let google: [SubscriptionCLI] = [.antigravity, .gemini]
        expect(KoncluiChatEngine.cli(google, offline: false) { _ in true }, .antigravity, "Google: Antigravity first")
        expect(KoncluiChatEngine.cli(google, offline: true) { _ in true }, .gemini, "Google with email: Gemini CLI turns the web off")
        expect(KoncluiChatEngine.cli(google, offline: true) { $0 == .antigravity }, nil, "only Antigravity: no tool for email")
        expect(KoncluiChatEngine.cli([.cursor], offline: true) { _ in true }, .cursor, "Cursor with email: its web is off in Koncluí's config")
        expect(KoncluiChatEngine.cli([.copilot], offline: false) { _ in false }, nil, "nothing installed")

        // A dropped file counts like email, from the turn that brings it to the end of the conversation.
        expectTrue(KoncluiChatEngine.offline(holdsOutsideText: false, mailMode: false, attachesFile: true),
                   "the turn that attaches a file is offline before the conversation records it")
        expectTrue(KoncluiChatEngine.offline(holdsOutsideText: true, mailMode: false, attachesFile: false),
                   "the turns after a file stay offline")
        expectTrue(!KoncluiChatEngine.offline(holdsOutsideText: false, mailMode: false, attachesFile: false), "a plain conversation has the web")
        let both: (SubscriptionCLI) -> Bool = { _ in true }
        let onlyAgy: (SubscriptionCLI) -> Bool = { $0 == .antigravity }
        let attach = KoncluiChatEngine.offline(holdsOutsideText: false, mailMode: false, attachesFile: true)
        expect(KoncluiChatEngine.route(google, offline: attach, installed: both), .cli(.gemini), "a dropped file: Gemini CLI, not Antigravity")
        let followUp = KoncluiChatEngine.offline(holdsOutsideText: true, mailMode: false, attachesFile: false)
        expect(KoncluiChatEngine.route(google, offline: followUp, installed: both), .cli(.gemini), "its follow-up turns: Gemini CLI too")
        expect(KoncluiChatEngine.route(google, offline: attach, installed: onlyAgy), .refused(.antigravity),
               "only Antigravity installed: the turn is refused, nothing sent")
        expect(KoncluiChatEngine.route(google, offline: followUp, installed: onlyAgy), .refused(.antigravity),
               "and so are its follow-ups")
        expect(KoncluiChatEngine.route(google, offline: false, installed: onlyAgy), .cli(.antigravity), "no outside text: Antigravity answers")
        expect(KoncluiChatEngine.route(google, offline: true) { _ in false }, .cli(.antigravity),
               "nothing installed: its first tool, to say how to install it")
        expect(KoncluiChatEngine.route([.cursor], offline: true, installed: both), .cli(.cursor), "Cursor turns its web off")
        expect(KoncluiChatEngine.route([], offline: false, installed: both), nil, "no tool: Coucou's own code")

        // The refusal for a file says so in every language of the catalog.
        let catalogURL = URL(fileURLWithPath: "NotchBuddy/Resources/Localizable.xcstrings")
        let catalog = (try? JSONSerialization.jsonObject(with: Data(contentsOf: catalogURL))) as? [String: Any]
        let strings = catalog?["strings"] as? [String: Any]
        let languages = ((strings?["chat.subscriptions.use"] as? [String: Any])?["localizations"] as? [String: Any])?.keys.sorted()
        let refusal = (strings?["konclui.file.needs-offline %@"] as? [String: Any])?["localizations"] as? [String: [String: [String: String]]]
        expect(refusal?.keys.sorted(), languages, "the file refusal is in Coucou's 16 languages")
        expectTrue(refusal?.values.allSatisfy { $0["stringUnit"]?["value"]?.components(separatedBy: "%@").count == 2 } == true,
                   "each names the tool once")

        // A dropped text file goes whole up to the relay's 200 KB (it was cut at 24,000 characters).
        let dropDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("konclui-drop-\(getpid())")
        try? FileManager.default.createDirectory(at: dropDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dropDir) }
        let big = String(repeating: "word ", count: 30_000) + "THE-END"   // 150,007 bytes
        let bigURL = dropDir.appendingPathComponent("notes.txt")
        try? big.write(to: bigURL, atomically: true, encoding: .utf8)
        let carried = KoncluiChatEngine.fileContext(name: "notes.txt", text: CLIRelay.inlineText(bigURL))
        expectTrue(carried.hasPrefix("File: notes.txt\nFile contents:\nword ") && carried.hasSuffix("THE-END"),
                   "a 150 KB text file goes whole")
        let huge = dropDir.appendingPathComponent("huge.txt")
        try? String(repeating: "x", count: 200_001).write(to: huge, atomically: true, encoding: .utf8)
        expect(KoncluiChatEngine.fileContext(name: "huge.txt", text: CLIRelay.inlineText(huge)), "File: huge.txt",
               "over the relay's 200 KB: its name only, as the relay")
        let png = dropDir.appendingPathComponent("a.png")
        try? Data([0x89, 0x50, 0x4E, 0x47, 0x00, 0x01]).write(to: png)
        expect(KoncluiChatEngine.fileContext(name: "a.png", text: CLIRelay.inlineText(png)), "File: a.png", "a binary file: its name")

        // The fallback is the adapter's: the relay's reading of its own CLI, else the plain lines.
        let gemini = KoncluiGeminiAdapter(policyPath: "")
        expect(gemini.fallbackAnswer(stdout: ["Plain answer", "second line"], exitCode: 0),
               "Plain answer\nsecond line", "an unread format: the plain lines, as the relay")
        expect(KoncluiAntigravityAdapter().fallbackAnswer(stdout: [#"{"response":"From the JSON object"}"#], exitCode: 0),
               "From the JSON object", "an older CLI that printed the relay's JSON: the relay's own reading")
        let cursorAdapter = KoncluiCursorAdapter(workDir: "", configDir: "", currentConfig: nil, userConfig: nil)
        expect(cursorAdapter.fallbackAnswer(stdout: [#"{"type":"something_new"}"#, #"{"type":"result","is_error":false,"result":"OK"}"#], exitCode: 0),
               "OK", "cursor: the relay reads the last result object")
        expect(gemini.fallbackAnswer(stdout: ["Some text"], exitCode: 1), nil, "a failed run has no fallback answer")
        expect(KoncluiCopilotAdapter().fallbackAnswer(stdout: [#"{"response":"x"}"#, #"{"type":"assistant.message"}"#], exitCode: 0), nil,
               "copilot: JSON lines are never shown as an answer")
        expect(KoncluiCopilotAdapter().fallbackAnswer(stdout: ["Hello", #"{"type":"x"}"#], exitCode: 0), "Hello",
               "copilot: its plain lines")
        expect(gemini.fallbackAnswer(stdout: [#"{"type":"unknown"}"#, ""], exitCode: 0), nil,
               "only unknown JSON: no answer rather than a blank one")

        let env = KoncluiCLI.environment(base: [
            "PATH": "/usr/bin", "CURSOR_API_KEY": "k", "CURSOR_API_ENDPOINT": "https://x", "GH_TOKEN": "t", "GITHUB_TOKEN": "t",
            "COPILOT_GITHUB_TOKEN": "t", "GOOGLE_GENAI_USE_VERTEXAI": "true", "GOOGLE_CLOUD_PROJECT": "p",
        ], executable: "/usr/local/bin/cursor-agent", home: "/Users/me")
        for name in ["CURSOR_API_KEY", "CURSOR_API_ENDPOINT", "GH_TOKEN", "GITHUB_TOKEN", "COPILOT_GITHUB_TOKEN", "GOOGLE_GENAI_USE_VERTEXAI"] {
            expect(env[name], nil, "environment drops \(name): the CLI's own login answers")
        }
        expect(env["GOOGLE_CLOUD_PROJECT"], "p", "a Code Assist project is the login's, kept")
        expectTrue(!SubscriptionCLI.antigravity.koncluiTurnsWebOff && SubscriptionCLI.cursor.koncluiTurnsWebOff,
                   "only Antigravity cannot turn its web off")
    }

    // MARK: Threads and the visible conversation

    static func conversationThreads() {
        // The chat as shown: two answered turns, a turn that failed, and the turn now starting.
        let visible: [(fromUser: Bool, text: String)] = [
            (true, "Hi"), (false, "Hello!"), (true, "Lost?"), (true, "Weather?"), (false, "Sunny."), (true, "Now?"),
        ]
        let transcript = KoncluiChatEngine.transcript(visible)
        expect(transcript, [KoncluiExchange(user: "Hi", assistant: "Hello!"), KoncluiExchange(user: "Weather?", assistant: "Sunny.")],
               "the answered turns, without the failed one or the one now starting")

        expect(KoncluiChatEngine.shape(.flag, thread: KoncluiThread(id: "t", answers: 2), transcript: transcript),
               KoncluiTurnShape(resume: "t", history: []), "a thread that holds every answered turn continues")
        expect(KoncluiChatEngine.shape(.firstTurn, thread: KoncluiThread(id: "t", answers: 1), transcript: transcript),
               KoncluiTurnShape(resume: nil, history: transcript),
               "another provider answered in between: a new thread with the conversation so far")
        expect(KoncluiChatEngine.shape(.firstTurn, thread: nil, transcript: transcript),
               KoncluiTurnShape(resume: nil, history: transcript), "a CLI picked mid-conversation starts with it")
        expect(KoncluiChatEngine.shape(.everyTurn, thread: KoncluiThread(id: "t", answers: 2), transcript: transcript),
               KoncluiTurnShape(resume: nil, history: transcript), "the relay format never continues a thread")
        expect(KoncluiChatEngine.shape(.flag, thread: KoncluiThread(id: "t", answers: 2), transcript: []),
               KoncluiTurnShape(resume: nil, history: []), "a cleared chat never continues an old thread")

        let resumed = KoncluiChatEngine.compose(query: "Now?", context: "Context — App: Mail", persona: "P", extra: "",
                                                systemPrompt: .firstTurn, shape: KoncluiTurnShape(resume: "t", history: []))
        expect(resumed.prompt, "Now?", "a continued thread gets the question alone")
        let mailExtra = KoncluiChatEngine.compose(query: "Now?", context: nil, persona: "P", extra: "PLAN",
                                                  systemPrompt: .firstTurn, shape: KoncluiTurnShape(resume: "t", history: []))
        expect(mailExtra.prompt, "PLAN\n\nNow?", "and Mail's plan format when it is on")
        let first = KoncluiChatEngine.compose(query: "Q", context: "CTX", persona: "P", extra: "", systemPrompt: .firstTurn,
                                              shape: KoncluiTurnShape(resume: nil, history: []))
        expect(first.prompt, "P\n\nCTX\n\nQ", "a first turn: persona, context, question")
        let seeded = KoncluiChatEngine.compose(query: "Now?", context: "CTX", persona: "P", extra: "", systemPrompt: .flag,
                                               shape: KoncluiTurnShape(resume: nil, history: transcript))
        expect(seeded.prompt, """
        The conversation so far:
        <conversation>
        <user>
        CTX

        Hi
        </user>
        <assistant>
        Hello!
        </assistant>
        <user>
        Weather?
        </user>
        <assistant>
        Sunny.
        </assistant>
        </conversation>

        The user's new message:
        Now?
        """, "a new thread mid-conversation gets it as the relay sends it, the context on its first message")
        expect(seeded.system, "P", "Claude Code's system prompt stays a flag")
        let seededCodex = KoncluiChatEngine.compose(query: "Now?", context: nil, persona: "P", extra: "", systemPrompt: .firstTurn,
                                                    shape: KoncluiTurnShape(resume: nil, history: transcript))
        expectTrue(seededCodex.prompt.hasPrefix("P\n\nThe conversation so far:\n<conversation>\n<user>\nHi\n"),
                   "a new Codex-style thread: the persona, then the conversation")
        let relay = KoncluiChatEngine.compose(query: "Q", context: nil, persona: "P", extra: "X", systemPrompt: .everyTurn,
                                              shape: KoncluiTurnShape(resume: nil, history: []))
        expect(relay.prompt, "Q", "relay format: the prompt")
        expect(relay.system, "PX", "relay format: its system prompt beside it")
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
        expectTrue(KoncluiCLI.isLostThread(stderr: "Invalid session identifier \"5f0c3a52\".\n  Searched for sessions in /x."), "gemini lost session")
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
        expect(defaults.string(forKey: "claudeModel"), "opus", "and its Claude model is Anthropic's model now")
        expect(defaults.object(forKey: "chat.useSubscription.anthropic") as? Bool, true, "with its subscription switch on")
        expectTrue(defaults.object(forKey: "claudeCodeChatModel") == nil, "the old model key is gone")
        defaults.set("claude-code", forKey: "chatProvider")
        defaults.set("default", forKey: "claudeCodeChatModel")
        defaults.set("claude-sonnet-5-5", forKey: "claudeModel")
        KoncluiChatMigration.run(defaults)
        expect(defaults.string(forKey: "claudeModel"), "claude-sonnet-5-5", "\"default\" leaves Anthropic's model alone")
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

        // Gemini CLI, Antigravity and Copilot take the prompt as an argument: a 200 KB file fits in it.
        let longArgument = String(repeating: "a", count: 210_000)
        let counted = await KoncluiProcess.capture("/bin/sh", ["-c", "printf %s \"$1\" | /usr/bin/wc -c", "sh", longArgument], timeout: 10)
        expect(counted?.stdout.trimmingCharacters(in: .whitespaces), "210000", "a 210 KB argument reaches the CLI whole")

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
