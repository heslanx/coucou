import Foundation

// Koncluí: one chat engine (KoncluiChat.swift), one adapter per subscription CLI. An adapter is a pure value: it builds
// a turn's command line and the files the CLI reads for it, says how the CLI takes the system prompt and a dropped file,
// and reads the CLI's output, line by line, into the answer, its thread and its failure. The engine starts the process,
// stops it (and its helpers) when a new turn starts, streams the answer to the notch and retries; it knows no CLI.
// What each CLI gets, and how it was checked: docs/konclui/decisions/ADR-009-chat-cli-engine.md.
// Foundation only, so scripts/test-konclui-chat.sh compiles it with KoncluiChatCore.swift and CLIRelay.swift.

// MARK: - The contract

/// One turn, as the engine hands it to an adapter.
struct KoncluiCLITurn: Sendable, Equatable {
    /// What the CLI receives: on a thread's first turn the persona and the context come with the question.
    var prompt: String
    /// The system prompt, for `.flag` and `.everyTurn` adapters.
    var system = ""
    /// The CLI's own thread to continue.
    var resume: String?
    /// Web tools allowed. Off once the conversation holds email or a dropped file: that text could steer the model
    /// into sending what it read to a website.
    var web = true
    /// The folder holding a copy of the dropped file (`.readsCopy` adapters).
    var readDir: URL?
    /// A dropped image passed as a file (`.images` adapters).
    var images: [String] = []
}

/// One run of a CLI, as the engine starts it.
struct KoncluiCLIPlan: Sendable, Equatable {
    var arguments: [String]
    /// The prompt on stdin, where it stays out of `ps`; nil when the CLI only takes it as an argument.
    var stdin: String?
    /// Added to the CLI's environment, once `KoncluiCLI.routingVariables` are gone.
    var environment: [String: String] = [:]
    /// Files the CLI reads for this run (its permissions, its policy), path → contents. The run does not start if one
    /// cannot be written: it would run without them.
    var files: [String: String] = [:]
}

/// How the CLI gets Koru's system prompt.
enum KoncluiSystemPrompt: Sendable {
    /// A flag of its own, on every turn (Claude Code's `--system-prompt`).
    case flag
    /// On top of a thread's first message; the CLI's thread keeps it.
    case firstTurn
    /// No thread of its own: the system prompt and the whole conversation go with every turn (Coucou's relay format).
    case everyTurn
}

/// What the CLI can do with a dropped PDF or image; every other file goes in the prompt as text.
enum KoncluiDroppedFile: Sendable {
    /// Reads an isolated copy, with reads allowed in that folder only.
    case readsCopy
    /// Takes an image as an attachment.
    case images
    /// Text only.
    case text
}

/// Reads a CLI's stdout one line at a time.
protocol KoncluiCLIStream {
    /// Feeds one line; true when the visible answer changed.
    mutating func feed(_ line: String) -> Bool
    /// The process ended with this code (after its last line).
    mutating func end(exitCode: Int32)
    var text: String { get }
    var threadID: String? { get }
    /// The turn ended in an error; `failure` holds the CLI's own words when it gave any.
    var failed: Bool { get }
    var failure: String? { get }
    var needsSignIn: Bool { get }
}

extension KoncluiCLIStream {
    mutating func end(exitCode: Int32) {}
}

protocol KoncluiCLIAdapter: Sendable {
    associatedtype Stream: KoncluiCLIStream
    var cli: SubscriptionCLI { get }
    var systemPrompt: KoncluiSystemPrompt { get }
    var droppedFile: KoncluiDroppedFile { get }
    /// Whether the CLI has a web tool to tell the model about (Codex's is always off).
    var searchesWeb: Bool { get }
    func plan(_ turn: KoncluiCLITurn) -> KoncluiCLIPlan
    /// A second run for a first one that failed in a way one known change fixes (an older CLI lacking a flag).
    func fallback(_ turn: KoncluiCLITurn, stderr: String) -> KoncluiCLIPlan?
    func stream() -> Stream
    /// A failure only stderr names (no JSON came) is a sign-in problem.
    func needsSignIn(stderr: String) -> Bool
    /// The resumed thread is gone from the CLI: the next turn starts a new one.
    func lostThread(stderr: String) -> Bool
    /// The answer of a run the stream could not read (a CLI older or newer than its format) that still ended with 0.
    /// Nil: nothing to show, and the engine says there was no answer rather than showing a blank one.
    func fallbackAnswer(stdout: [String], exitCode: Int32) -> String?
    var notInstalledMessage: String { get }
    var signInMessage: String { get }
}

extension KoncluiCLIAdapter {
    var searchesWeb: Bool { true }
    func fallback(_ turn: KoncluiCLITurn, stderr: String) -> KoncluiCLIPlan? { nil }
    func needsSignIn(stderr: String) -> Bool { CLIRelay.needsSignIn(stderr) }
    func lostThread(stderr: String) -> Bool { KoncluiCLI.isLostThread(stderr: stderr) }
    /// As Coucou's relay reads the CLI (its JSON result for this CLI), else the plain lines.
    func fallbackAnswer(stdout: [String], exitCode: Int32) -> String? {
        guard exitCode == 0 else { return nil }
        if case .success(let text) = CLIRelay.parse(cli, stdout: Data(stdout.joined(separator: "\n").utf8),
                                                    stderr: Data(), exitCode: 0) {
            return text
        }
        return KoncluiPlainStream.answer(stdout)
    }
    var notInstalledMessage: String {
        String(format: String(localized: "chat.subscriptions.error.missing"), cli.displayName)
    }
    var signInMessage: String { String(format: String(localized: "chat.subscriptions.sign-in"), cli.signIn) }
}

extension SubscriptionCLI {
    /// Every tool of the CLI that reaches the web can be switched off for one run, so it can answer a conversation
    /// that holds email. Antigravity has no switch for it (its permissions are the user's settings).
    var koncluiTurnsWebOff: Bool { self != .antigravity }
}

// MARK: - Engine rules that hold for every CLI

enum KoncluiChatEngine {
    /// A dropped file as a turn carries it, in the relay's words: its text whole when it has one
    /// (`CLIRelay.inlineText`: up to 200 KB of UTF-8), else its name. Every CLI takes it: Claude Code, Codex and Cursor
    /// on stdin, the others as the `-p` argument (the Mac's argument space is 1 MiB).
    static func fileContext(name: String, text: String?) -> String {
        guard let text, !text.isEmpty else { return "File: \(name)" }
        return "File: \(name)\nFile contents:\n\(text)"
    }

    /// The tool that answers a provider's turn: the first installed one, or, for a conversation that holds email,
    /// the first installed one that can answer with no web at all.
    static func cli(_ candidates: [SubscriptionCLI], offline: Bool,
                    installed: (SubscriptionCLI) -> Bool) -> SubscriptionCLI? {
        candidates.first { installed($0) && (!offline || $0.koncluiTurnsWebOff) }
    }
}

// MARK: - Claude Code and Codex (KoncluiChatCore.swift builds their command lines and reads their streams)

struct KoncluiClaudeAdapter: KoncluiCLIAdapter {
    var model: String
    let cli = SubscriptionCLI.claude
    let systemPrompt = KoncluiSystemPrompt.flag
    let droppedFile = KoncluiDroppedFile.readsCopy

    func plan(_ turn: KoncluiCLITurn) -> KoncluiCLIPlan { plan(turn, safeMode: true) }

    /// An older Claude Code does not know --safe-mode: once more without it, the rest of the isolation kept.
    func fallback(_ turn: KoncluiCLITurn, stderr: String) -> KoncluiCLIPlan? {
        KoncluiClaudeCLI.isUnknownSafeMode(stderr: stderr) ? plan(turn, safeMode: false) : nil
    }

    private func plan(_ turn: KoncluiCLITurn, safeMode: Bool) -> KoncluiCLIPlan {
        KoncluiCLIPlan(arguments: KoncluiClaudeCLI.arguments(model: model, resume: turn.resume, systemPrompt: turn.system,
                                                             safeMode: safeMode, web: turn.web, readDir: turn.readDir),
                       stdin: turn.prompt)
    }

    func stream() -> KoncluiClaudeStream { KoncluiClaudeStream() }
    /// The stream says it (an "authentication_failed" notice); stderr is not read for it.
    func needsSignIn(stderr: String) -> Bool { false }
    var notInstalledMessage: String {
        String(localized: "Claude Code is not installed. Install it to use your Claude subscription.")
    }
    var signInMessage: String { String(localized: "Sign in to Claude Code in Terminal: claude") }
}

struct KoncluiCodexAdapter: KoncluiCLIAdapter {
    /// The model chosen in Codex (`KoncluiCodexCLI.configuredModel`), passed on since its config is not read.
    var model: String
    let cli = SubscriptionCLI.codex
    let systemPrompt = KoncluiSystemPrompt.firstTurn
    let droppedFile = KoncluiDroppedFile.images
    var searchesWeb: Bool { false }

    func plan(_ turn: KoncluiCLITurn) -> KoncluiCLIPlan {
        KoncluiCLIPlan(arguments: KoncluiCodexCLI.arguments(model: model, resume: turn.resume, images: turn.images),
                       stdin: turn.prompt)
    }

    func stream() -> KoncluiCodexStream { KoncluiCodexStream() }
    func needsSignIn(stderr: String) -> Bool { false }
    var notInstalledMessage: String {
        String(localized: "Codex is not installed. Install it to use your ChatGPT subscription.")
    }
    var signInMessage: String { String(localized: "Sign in to Codex in Terminal: codex login") }
}

extension KoncluiClaudeStream: KoncluiCLIStream {
    var threadID: String? { sessionID }
}

extension KoncluiCodexStream: KoncluiCLIStream {
    var failed: Bool { failure != nil }
}

// MARK: - Cursor CLI (checked live on cursor-agent 2026.10.19)

/// `cursor-agent -p` in ask mode, the prompt on stdin, in Koncluí's chat folder. Its config folder is Koncluí's own
/// (`CURSOR_CONFIG_DIR`): the user's permissions, approval mode and web auto-accept are not loaded, and the chats it keeps
/// stay there. The permissions (the config's and the chat folder's `.cursor/cli.json`; deny always wins) refuse every
/// read, write, shell command and MCP tool, so it can only answer: ask mode alone still reads the whole disk. Web search
/// and fetch are allowed only while the conversation holds no outside text. Cursor has no switch for the user's hooks
/// (`~/.cursor/hooks.json`) or rules.
struct KoncluiCursorAdapter: KoncluiCLIAdapter {
    /// Where the turns run (Koncluí's chat folder).
    var workDir: String
    /// Koncluí's config folder for Cursor and the config Cursor left there (it keeps its caches in it).
    var configDir: String
    var currentConfig: String?
    /// The user's own `cli-config.json`: only the model chosen there is carried over.
    var userConfig: String?
    let cli = SubscriptionCLI.cursor
    let systemPrompt = KoncluiSystemPrompt.firstTurn
    let droppedFile = KoncluiDroppedFile.text

    func plan(_ turn: KoncluiCLITurn) -> KoncluiCLIPlan {
        var args = ["-p", "--output-format", "stream-json", "--stream-partial-output", "--mode", "ask", "--trust"]
        if let id = turn.resume, !id.isEmpty { args += ["--resume", id] }
        return KoncluiCLIPlan(
            arguments: args, stdin: turn.prompt,
            environment: ["CURSOR_CONFIG_DIR": configDir, "NO_COLOR": "1"],
            files: ["\(workDir)/.cursor/cli.json": KoncluiCursorCLI.projectConfig(web: turn.web),
                    "\(configDir)/cli-config.json": KoncluiCursorCLI.config(current: currentConfig, user: userConfig,
                                                                            web: turn.web)])
    }

    func stream() -> KoncluiCursorStream { KoncluiCursorStream() }
}

enum KoncluiCursorCLI {
    /// Deny wins over allow in Cursor's permissions. `/**` is every absolute path, `**` the workspace's.
    static func permissions(web: Bool) -> [String: [String]] {
        var deny = ["Read(/**)", "Read(**)", "Write(/**)", "Write(**)", "Shell(*)", "Mcp(*:*)"]
        if !web { deny.append("WebFetch(*)") }
        return ["allow": web ? ["WebFetch(*)"] : [], "deny": deny]
    }

    /// The chat folder's `.cursor/cli.json` (the project level holds permissions only).
    static func projectConfig(web: Bool) -> String {
        json(["permissions": permissions(web: web)])
    }

    /// The model keys of the user's config Koncluí carries over, so the chat uses the model chosen in Cursor.
    static let modelKeys = ["model", "selectedModel", "modelParameters", "hasChangedDefaultModel", "maxMode"]

    /// Koncluí's `cli-config.json`: what Cursor keeps there, the user's model, then Koncluí's rules on top. Web search
    /// has no permission of its own: in print mode it runs only when `autoAcceptWebSearch` is on.
    static func config(current: String?, user: String?, web: Bool) -> String {
        var config = current.flatMap(KoncluiCLI.jsonObject) ?? [:]
        if let user = user.flatMap(KoncluiCLI.jsonObject) {
            for key in modelKeys { config[key] = user[key] }
        }
        config["version"] = 1
        if config["editor"] == nil { config["editor"] = ["vimMode": false] }
        config["permissions"] = permissions(web: web)
        config["approvalMode"] = "allowlist"
        config["autoAcceptWebSearch"] = web
        return json(config)
    }

    /// The user's own config: `$CURSOR_CONFIG_DIR`, else `~/.cursor`.
    static func userConfigPath(environment: [String: String], home: String) -> String {
        let dir = environment["CURSOR_CONFIG_DIR"].flatMap { $0.isEmpty ? nil : $0 } ?? "\(home)/.cursor"
        return "\(dir)/cli-config.json"
    }

    /// `cursor-agent about --format json`: `userEmail` (null when signed out) and `subscriptionTier` ("Ultra"…);
    /// `status --format json`: `isAuthenticated`. Nil when the output says neither.
    static func parseLogin(output: String) -> KoncluiLogin? {
        guard let object = KoncluiCLI.jsonObject(output) else { return nil }
        if let signedIn = object["isAuthenticated"] as? Bool { return signedIn ? .signedIn(nil) : .signedOut }
        guard object.keys.contains("userEmail") else { return nil }
        guard object["userEmail"] is String else { return .signedOut }
        let tier = (object["subscriptionTier"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        return .signedIn(tier)
    }

    private static func json(_ object: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        else { return "{}" }
        return String(decoding: data, as: UTF8.self) + "\n"
    }
}

/// Reads `cursor-agent -p --output-format stream-json --stream-partial-output`. An assistant event with `timestamp_ms`
/// and no `model_call_id` is new text; the others repeat what was streamed (the flush before a tool call, the one at the
/// end of the turn). Without partial output (an older CLI) each assistant event is a whole message.
struct KoncluiCursorStream: KoncluiCLIStream {
    private(set) var threadID: String?
    private(set) var text = ""
    private(set) var failed = false
    private(set) var failure: String?
    private(set) var finished = false
    private var sawDelta = false
    private var gapBeforeNextText = false

    var needsSignIn: Bool { failed && CLIRelay.needsSignIn(failure ?? "") }

    mutating func feed(_ line: String) -> Bool {
        guard let object = KoncluiCLI.jsonObject(line) else { return false }
        if let id = object["session_id"] as? String, !id.isEmpty { threadID = id }
        switch object["type"] as? String {
        case "assistant":
            let content = (object["message"] as? [String: Any])?["content"] as? [[String: Any]] ?? []
            let piece = content.filter { $0["type"] as? String == "text" }.compactMap { $0["text"] as? String }.joined()
            guard !piece.isEmpty else { return false }
            if object["timestamp_ms"] != nil, object["model_call_id"] == nil {
                sawDelta = true
            } else {
                guard !sawDelta else { return false }
                if !text.isEmpty { gapBeforeNextText = true }
            }
            append(piece)
            return true
        case "tool_call":
            if !text.isEmpty { gapBeforeNextText = true }
        case "result":
            finished = true
            let result = (object["result"] as? String) ?? ""
            if object["is_error"] as? Bool == true {
                failed = true
                failure = result.isEmpty ? nil : result
            } else if text.isEmpty, !result.isEmpty {
                text = result
                return true
            }
        default: break
        }
        return false
    }

    /// On a failure Cursor writes to stderr and may end the stream with no result event.
    mutating func end(exitCode: Int32) {
        if exitCode != 0, !finished { failed = true }
    }

    private mutating func append(_ piece: String) {
        if gapBeforeNextText {
            if !text.hasSuffix("\n") { text += "\n\n" }
            gapBeforeNextText = false
        }
        text += piece
    }
}

// MARK: - Gemini CLI (from its source: google-gemini/gemini-cli, stream-json since v0.11.0; not run here)

/// `gemini -p` with `--output-format stream-json`, as Coucou's relay runs it (plan mode, no extensions, no MCP server,
/// folder trust skipped for Koncluí's chat folder) plus a policy file on every turn: no file tool, no shell, no
/// `exit_plan_mode` (in a run with no one to ask it is allowed and leaves plan mode for one that runs everything), and
/// no web tool while the conversation holds outside text. Reads were confined to the workspace already.
/// Gemini CLI has no switch for the user's hooks or GEMINI.md.
struct KoncluiGeminiAdapter: KoncluiCLIAdapter {
    /// Where Koncluí writes the policy for each turn.
    var policyPath: String
    let cli = SubscriptionCLI.gemini
    let systemPrompt = KoncluiSystemPrompt.firstTurn
    let droppedFile = KoncluiDroppedFile.text

    func plan(_ turn: KoncluiCLITurn) -> KoncluiCLIPlan {
        var args = ["-p", turn.prompt, "--output-format", "stream-json", "--approval-mode", "plan", "--skip-trust",
                    "--extensions", "none", "--allowed-mcp-server-names", "coucou-none", "--policy", policyPath]
        if let id = turn.resume, !id.isEmpty { args += ["--resume", id] }
        return KoncluiCLIPlan(arguments: args, stdin: nil, environment: ["NO_COLOR": "1"],
                              files: [policyPath: KoncluiGeminiCLI.policy(web: turn.web)])
    }

    func stream() -> KoncluiGeminiStream { KoncluiGeminiStream() }
}

enum KoncluiGeminiCLI {
    /// Tools a chat turn never needs: files (a dropped file comes as text), the shell, memory, leaving plan mode.
    static let deniedTools = ["exit_plan_mode", "run_shell_command", "write_file", "replace", "save_memory",
                              "read_file", "read_many_files", "glob", "grep_search", "list_directory"]
    static let webTools = ["google_web_search", "web_fetch"]

    /// The policy engine's TOML (`--policy`, the format of `CLIRelay.noWebPolicyTOML`).
    static func policy(web: Bool) -> String {
        let tools = (deniedTools + (web ? [] : webTools)).map { "\"\($0)\"" }.joined(separator: ", ")
        return """
        [[rule]]
        toolName = [\(tools)]
        decision = "deny"
        priority = 900
        denyMessage = "Not available in Koncluí's chat."

        """
    }
}

/// Reads `gemini -p --output-format stream-json` (`packages/core/src/output/types.ts`): `init` (session_id),
/// `message` (role, content, delta), `tool_use`, `tool_result`, `error` (severity, message) and `result`
/// (status, error). A fatal error ends with a `result` whose status is "error"; a missing sign-in only on stderr.
struct KoncluiGeminiStream: KoncluiCLIStream {
    private(set) var threadID: String?
    private(set) var text = ""
    private(set) var failed = false
    private(set) var failure: String?
    private(set) var finished = false
    private var sawDelta = false
    private var gapBeforeNextText = false

    var needsSignIn: Bool { failed && CLIRelay.needsSignIn(failure ?? "") }

    mutating func feed(_ line: String) -> Bool {
        guard let object = KoncluiCLI.jsonObject(line) else { return false }
        switch object["type"] as? String {
        case "init":
            if let id = object["session_id"] as? String, !id.isEmpty { threadID = id }
        case "message":
            guard object["role"] as? String == "assistant", let piece = object["content"] as? String,
                  !piece.isEmpty else { return false }
            if object["delta"] as? Bool == true {
                sawDelta = true
            } else {
                // A whole message after its deltas repeats them.
                guard !sawDelta else { return false }
                if !text.isEmpty { gapBeforeNextText = true }
            }
            append(piece)
            return true
        case "tool_use":
            if !text.isEmpty { gapBeforeNextText = true }
        case "error":
            if object["severity"] as? String == "error", failure == nil,
               let message = object["message"] as? String, !message.isEmpty {
                failure = message
            }
        case "result":
            finished = true
            if object["status"] as? String == "error" {
                failed = true
                if let message = (object["error"] as? [String: Any])?["message"] as? String, !message.isEmpty {
                    failure = message
                }
            }
        default: break
        }
        return false
    }

    mutating func end(exitCode: Int32) {
        if exitCode != 0, !finished { failed = true }
    }

    private mutating func append(_ piece: String) {
        if gapBeforeNextText {
            if !text.hasSuffix("\n") { text += "\n\n" }
            gapBeforeNextText = false
        }
        text += piece
    }
}

// MARK: - Antigravity CLI (from antigravity.google/docs/cli/headless, stream-json since v1.1.8; not run here)

/// `agy -p` with `--output-format stream-json`, as Coucou's relay runs it (plan mode, no slash commands or skills),
/// continuing its conversation with `--conversation`. Antigravity has no per-run switch for MCP servers, hooks, plugins
/// or web tools: its headless defaults refuse commands, the web and MCP, unless the user's own settings allow them.
struct KoncluiAntigravityAdapter: KoncluiCLIAdapter {
    let cli = SubscriptionCLI.antigravity
    let systemPrompt = KoncluiSystemPrompt.firstTurn
    let droppedFile = KoncluiDroppedFile.text

    func plan(_ turn: KoncluiCLITurn) -> KoncluiCLIPlan {
        var args = ["-p", turn.prompt, "--output-format", "stream-json", "--mode", "plan", "--disable-slash-commands"]
        if let id = turn.resume, !id.isEmpty { args += ["--conversation", id] }
        return KoncluiCLIPlan(arguments: args, stdin: nil, environment: ["NO_COLOR": "1"])
    }

    func stream() -> KoncluiAntigravityStream { KoncluiAntigravityStream() }
}

/// Reads `agy -p --output-format stream-json`: `{"event": "init" | "step_update" | "result", …}`. Text comes as the
/// `text_delta` of `agent_response` steps; the `result` carries the whole `response` (what the relay shows), which
/// replaces the streamed text when they differ, or `error` (a string) with a status other than SUCCESS.
struct KoncluiAntigravityStream: KoncluiCLIStream {
    private(set) var threadID: String?
    private(set) var text = ""
    private(set) var failed = false
    private(set) var failure: String?
    private(set) var finished = false
    private var gapBeforeNextText = false

    var needsSignIn: Bool { failed && CLIRelay.needsSignIn(failure ?? "") }

    mutating func feed(_ line: String) -> Bool {
        guard let object = KoncluiCLI.jsonObject(line) else { return false }
        if let id = object["conversation_id"] as? String, !id.isEmpty { threadID = id }
        switch object["event"] as? String {
        case "step_update":
            guard let step = object["step_update"] as? [String: Any] else { return false }
            if let id = step["conversation_id"] as? String, !id.isEmpty { threadID = id }
            switch step["step_type"] as? String {
            case "agent_response":
                guard let piece = step["text_delta"] as? String, !piece.isEmpty else { return false }
                if gapBeforeNextText {
                    if !text.hasSuffix("\n") { text += "\n\n" }
                    gapBeforeNextText = false
                }
                text += piece
                return true
            case "tool":
                if !text.isEmpty { gapBeforeNextText = true }
            default: break
            }
        case "result":
            guard let result = object["result"] as? [String: Any] else { return false }
            finished = true
            if let id = result["conversation_id"] as? String, !id.isEmpty { threadID = id }
            guard result["status"] as? String == "SUCCESS" else {
                failed = true
                failure = (result["error"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                return false
            }
            let response = ((result["response"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !response.isEmpty, response != text.trimmingCharacters(in: .whitespacesAndNewlines) {
                text = response
                return true
            }
        default: break
        }
        return false
    }

    mutating func end(exitCode: Int32) {
        if exitCode != 0, !finished { failed = true }
    }
}

// MARK: - Copilot CLI (Coucou's relay format: its -p JSON events are not documented)

/// `copilot -p` exactly as Coucou's relay builds it (`CLIRelay.arguments`): plain text out, no thread, the conversation
/// sent again each turn. Run by the engine, a new message stops it, and the answer shows line by line if Copilot
/// prints it as it writes (`--stream`, on by default).
struct KoncluiCopilotAdapter: KoncluiCLIAdapter {
    let cli = SubscriptionCLI.copilot
    let systemPrompt = KoncluiSystemPrompt.everyTurn
    let droppedFile = KoncluiDroppedFile.text

    func plan(_ turn: KoncluiCLITurn) -> KoncluiCLIPlan {
        let request = CLIRequest(model: nil, system: turn.system, prompt: turn.prompt, web: turn.web, readDir: nil,
                                 noWebPolicy: nil, timeout: 0)
        return KoncluiCLIPlan(arguments: CLIRelay.arguments(.copilot, request), stdin: nil,
                              environment: ["NO_COLOR": "1"])
    }

    func stream() -> KoncluiPlainStream { KoncluiPlainStream() }

    /// The relay takes Copilot's whole stdout as the answer: only plain lines, never JSON ones.
    func fallbackAnswer(stdout: [String], exitCode: Int32) -> String? {
        exitCode == 0 ? KoncluiPlainStream.answer(stdout) : nil
    }
}

/// Plain text out: every line is the answer; a run that does not end with 0 failed.
struct KoncluiPlainStream: KoncluiCLIStream {
    private(set) var text = ""
    private(set) var failed = false
    let threadID: String? = nil
    let failure: String? = nil
    var needsSignIn: Bool { false }

    mutating func feed(_ line: String) -> Bool {
        let clean = Self.withoutColors(line)
        guard !text.isEmpty || !clean.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        text += text.isEmpty ? clean : "\n" + clean
        return true
    }

    mutating func end(exitCode: Int32) {
        if exitCode != 0 { failed = true }
    }

    static func withoutColors(_ line: String) -> String {
        line.replacingOccurrences(of: "\u{1B}\\[[0-9;]*[A-Za-z]", with: "", options: .regularExpression)
    }

    /// The lines that are not JSON, without colours; nil when none has text.
    static func answer(_ lines: [String]) -> String? {
        let plain = lines.filter { KoncluiCLI.jsonObject($0) == nil }.map(withoutColors).joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return plain.isEmpty ? nil : plain
    }
}
