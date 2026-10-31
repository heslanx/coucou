import Foundation

// Koncluí: the pure parts of the chat through what this Mac is signed in to (Claude Code, Codex,
// the Koncluí Proxy behind klaude). Foundation only, so scripts/test-konclui-chat.sh compiles it
// alone. Nothing here reads a credential: the CLIs keep their own login and are run as
// subprocesses, and the proxy key is handed in by the caller at request time.

// MARK: - Login detection

enum KoncluiLogin: Equatable, Sendable {
    /// Signed in; the detail names the plan or the method ("Max", "ChatGPT", "API key") when known.
    case signedIn(String?)
    case signedOut
}

enum KoncluiCLI {

    /// Variables that would send a CLI somewhere other than its own login: a shell started from
    /// klaude, Orca or an API-key setup leaves them behind, and the subscription route must not
    /// follow them.
    static let routingVariables = [
        "ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN", "ANTHROPIC_BASE_URL", "ANTHROPIC_CUSTOM_HEADERS",
        "CLAUDE_CONFIG_DIR", "CLAUDE_CODE_OAUTH_TOKEN", "CLAUDE_CODE_OAUTH_TOKEN_FILE_DESCRIPTOR",
        "CLAUDE_CODE_USE_BEDROCK", "CLAUDE_CODE_USE_VERTEX", "CLAUDE_CODE_USE_FOUNDRY",
        "CLAUDE_CODE_USE_ANTHROPIC_AWS", "CLAUDECODE", "CLAUDE_CODE_SESSION_ID",
        "CLAUDE_CODE_MESSAGING_SOCKET", "CLAUDE_CODE_MESSAGING_TOKEN",
        "OPENAI_API_KEY", "OPENAI_BASE_URL", "CODEX_API_KEY",
        "GEMINI_API_KEY", "GOOGLE_API_KEY", "GOOGLE_GEMINI_BASE_URL",
    ]

    /// Where the app looks for a CLI: it does not get the shell's PATH.
    static func candidatePaths(_ name: String, home: String, nvmVersions: [String] = []) -> [String] {
        var paths = [
            "\(home)/.local/bin/\(name)",
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
            "\(home)/.npm-global/bin/\(name)",
            "\(home)/.volta/bin/\(name)",
            "\(home)/.bun/bin/\(name)",
            "\(home)/Library/pnpm/\(name)",
        ]
        if name == "claude" { paths.insert("\(home)/.claude/local/claude", at: 0) }
        // nvm keeps one bin folder per Node version, newest first.
        let sorted = nvmVersions.sorted { $0.compare($1, options: .numeric) == .orderedDescending }
        paths += sorted.map { "\(home)/.nvm/versions/node/\($0)/bin/\(name)" }
        return paths
    }

    static func find(_ name: String, home: String, nvmVersions: [String] = [],
                     isExecutable: (String) -> Bool) -> String? {
        candidatePaths(name, home: home, nvmVersions: nvmVersions).first(where: isExecutable)
    }

    /// The environment a CLI runs with: the app's own, minus the routing variables, with the
    /// CLI's folder and the usual tool folders on PATH (an npm-installed CLI starts `node` from there).
    static func environment(base: [String: String], executable: String, home: String) -> [String: String] {
        var env = base
        for key in routingVariables { env[key] = nil }
        let folder = URL(fileURLWithPath: executable).deletingLastPathComponent().path
        let path = [folder, "\(home)/.local/bin", "/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin",
                    "/usr/sbin", "/sbin", base["PATH"] ?? ""].filter { !$0.isEmpty }
        env["PATH"] = path.joined(separator: ":")
        return env
    }

    /// `claude auth status --json`: `{"loggedIn": true, "subscriptionType": "max", …}`; exit 1 when signed out.
    static func parseClaudeLogin(output: String, exitCode: Int32) -> KoncluiLogin {
        if let object = jsonObject(output), let loggedIn = object["loggedIn"] as? Bool {
            guard loggedIn else { return .signedOut }
            let plan = (object["subscriptionType"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            return .signedIn(plan.map { $0.prefix(1).uppercased() + $0.dropFirst() })
        }
        return exitCode == 0 ? .signedIn(nil) : .signedOut
    }

    /// `codex login status`: "Logged in using ChatGPT" / "Logged in using an API key" / "Not logged in".
    static func parseCodexLogin(output: String, exitCode: Int32) -> KoncluiLogin {
        guard exitCode == 0, output.contains("Logged in") else { return .signedOut }
        if output.contains("ChatGPT") { return .signedIn("ChatGPT") }
        if output.contains("API key") { return .signedIn("API key") }
        return .signedIn(nil)
    }

    /// A resumed thread the CLI no longer has (its session file is gone): the next turn must start a new one.
    static func isLostThread(stderr: String) -> Bool {
        stderr.contains("No conversation found") || stderr.contains("no rollout found")
    }

    static func jsonObject(_ text: String) -> [String: Any]? {
        guard let data = text.data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }
}

// MARK: - Claude Code

enum KoncluiClaudeCLI {
    /// The model aliases `claude --model` takes; "default" leaves the choice to Claude Code.
    static let models: [KoncluiModel] = [
        KoncluiModel(id: "default", label: "Default"),
        KoncluiModel(id: "fable", label: "Claude Fable"),
        KoncluiModel(id: "opus", label: "Claude Opus"),
        KoncluiModel(id: "sonnet", label: "Claude Sonnet"),
        KoncluiModel(id: "haiku", label: "Claude Haiku"),
    ]

    /// `claude -p` with the prompt on stdin. Only web search and fetch are on, so nothing asks for a
    /// permission and nothing touches the disk; `--safe-mode` keeps the user's hooks (Koncluí's own
    /// would show this chat as a session in the notch), skills and MCP servers out of a chat turn.
    /// `web: false` (the conversation holds email or a dropped file) turns the web tools off: that text could
    /// otherwise steer the model into sending what it read to a website. `readDir`: the folder holding a copy of the
    /// dropped file (CLIRelay.isolate, as Coucou's relay does); Read is the only tool then, limited to that folder.
    static func arguments(model: String, resume sessionID: String?, systemPrompt: String,
                          safeMode: Bool = true, web: Bool = true, readDir: URL? = nil) -> [String] {
        var args = ["-p", "--output-format", "stream-json", "--verbose", "--include-partial-messages",
                    "--permission-mode", "dontAsk",
                    // As Coucou's relay, and kept when an older CLI is retried without --safe-mode: no settings
                    // file (so no hooks or permissions of the user's), no MCP server, no slash command.
                    "--setting-sources", "", "--strict-mcp-config", "--disable-slash-commands"]
        if let readDir {
            // `--add-dir` only adds a folder; the rule is what keeps Read inside it (`//` = an absolute path), and
            // dontAsk refuses everything else. Checked live on Claude Code 2.1.314: a read outside is denied.
            let dir = readDir.resolvingSymlinksInPath().path
            args += ["--tools", "Read", "--allowedTools", "Read(/\(dir)/**)", "--add-dir", dir]
        } else {
            args += web ? ["--tools", "WebSearch,WebFetch", "--allowedTools", "WebSearch,WebFetch"] : ["--tools", ""]
        }
        args += ["--system-prompt", systemPrompt]
        if safeMode { args.append("--safe-mode") }
        if !model.isEmpty, model != "default" { args += ["--model", model] }
        if let sessionID, !sessionID.isEmpty { args += ["--resume", sessionID] }
        return args
    }

    static func isUnknownSafeMode(stderr: String) -> Bool {
        stderr.contains("--safe-mode") && (stderr.contains("unknown option") || stderr.contains("Unknown"))
    }
}

/// Reads `claude -p --output-format stream-json --include-partial-messages` line by line.
struct KoncluiClaudeStream {
    private(set) var sessionID: String?
    private(set) var text = ""
    /// The turn ended in an error; `failure` holds the CLI's own words when it gave any (a sign-in
    /// request, a usage limit…).
    private(set) var failed = false
    private(set) var failure: String?
    private(set) var finished = false
    private var sawPartial = false
    private var gapBeforeNextText = false
    private var assistantAuthError = false

    /// A sign-in problem rather than any other failure.
    var needsSignIn: Bool {
        guard failed else { return false }
        if assistantAuthError { return true }
        let lower = (failure ?? "").lowercased()
        return lower.contains("/login") || lower.contains("not logged in")
    }

    /// Feeds one stdout line; true when the visible text grew.
    @discardableResult
    mutating func feed(_ line: String) -> Bool {
        guard let object = KoncluiCLI.jsonObject(line) else { return false }
        switch object["type"] as? String {
        case "system":
            if let id = object["session_id"] as? String { sessionID = id }
        case "stream_event":
            sawPartial = true
            guard let event = object["event"] as? [String: Any] else { return false }
            switch event["type"] as? String {
            case "content_block_start":
                if (event["content_block"] as? [String: Any])?["type"] as? String == "text", !text.isEmpty {
                    gapBeforeNextText = true
                }
            case "content_block_delta":
                if let delta = event["delta"] as? [String: Any], delta["type"] as? String == "text_delta",
                   let piece = delta["text"] as? String, !piece.isEmpty {
                    append(piece)
                    return true
                }
            default: break
            }
        case "assistant":
            // An assistant message with an "error" is the CLI's own notice (not logged in, rate limit…),
            // not the model's answer: the result event carries it as the failure.
            if let error = object["error"] as? String {
                if error == "authentication_failed" { assistantAuthError = true }
                return false
            }
            // Without partial messages (an older CLI) the whole message is the stream.
            guard !sawPartial, let message = object["message"] as? [String: Any],
                  let content = message["content"] as? [[String: Any]] else { return false }
            var grew = false
            for block in content where block["type"] as? String == "text" {
                if let piece = block["text"] as? String, !piece.isEmpty {
                    if !text.isEmpty { gapBeforeNextText = true }
                    append(piece)
                    grew = true
                }
            }
            return grew
        case "result":
            finished = true
            if let id = object["session_id"] as? String { sessionID = id }
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

    private mutating func append(_ piece: String) {
        if gapBeforeNextText {
            if !text.hasSuffix("\n") { text += "\n\n" }
            gapBeforeNextText = false
        }
        text += piece
    }
}

// MARK: - Codex

enum KoncluiCodexCLI {
    /// `codex exec --json` with the prompt on stdin. It can only answer: the user's config and rules are not loaded
    /// (so none of their MCP servers either), no shell (a read-only sandbox still reads the whole disk), no apps,
    /// plugins or web search, and hooks off so the chat does not show up as a Codex session in the notch. `model`:
    /// the one chosen in Codex (`configuredModel`), passed on since its config is not read.
    static func arguments(model: String, resume threadID: String?, images: [String] = []) -> [String] {
        var args = ["exec"]
        if let threadID, !threadID.isEmpty { args += ["resume", threadID] }
        args += ["--json", "--skip-git-repo-check", "--ignore-user-config", "--ignore-rules"]
        for feature in ["hooks", "shell_tool", "unified_exec", "apps", "plugins"] { args += ["--disable", feature] }
        args += ["-c", #"sandbox_mode="read-only""#, "-c", #"web_search="disabled""#]
        if !model.isEmpty, model != "default" { args += ["-m", model] }
        for image in images { args += ["-i", image] }
        args.append("-")
        return args
    }

    static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "gif", "webp"]

    /// The top-level `model = "…"` of Codex's config.toml (`$CODEX_HOME`, else `~/.codex`), nil when it sets none.
    static func configuredModel(environment: [String: String] = ProcessInfo.processInfo.environment,
                                home: String = NSHomeDirectory()) -> String? {
        let dir = environment["CODEX_HOME"].flatMap { $0.isEmpty ? nil : $0 } ?? "\(home)/.codex"
        guard let text = try? String(contentsOfFile: "\(dir)/config.toml", encoding: .utf8) else { return nil }
        return model(fromConfig: text)
    }

    static func model(fromConfig text: String) -> String? {
        for raw in text.split(whereSeparator: \.isNewline) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("[") { return nil }   // a table starts: the top level is over
            guard line.hasPrefix("model"), let eq = line.firstIndex(of: "=") else { continue }
            guard line[..<eq].trimmingCharacters(in: .whitespaces) == "model" else { continue }
            let value = line[line.index(after: eq)...].trimmingCharacters(in: .whitespaces)
            guard value.hasPrefix("\""), let end = value.dropFirst().firstIndex(of: "\"") else { return nil }
            let model = String(value[value.index(after: value.startIndex)..<end])
            return model.isEmpty ? nil : model
        }
        return nil
    }
}

/// Reads `codex exec --json` (JSONL) line by line. Codex gives each message whole, not token by token.
struct KoncluiCodexStream {
    private(set) var threadID: String?
    private(set) var text = ""
    private(set) var failure: String?
    private(set) var finished = false

    var needsSignIn: Bool {
        guard let failure else { return false }
        let lower = failure.lowercased()
        return lower.contains("401") || lower.contains("unauthorized") || lower.contains("not logged in")
            || lower.contains("log in") || lower.contains("sign in")
    }

    @discardableResult
    mutating func feed(_ line: String) -> Bool {
        guard let object = KoncluiCLI.jsonObject(line) else { return false }
        switch object["type"] as? String {
        case "thread.started":
            threadID = object["thread_id"] as? String
        case "item.completed":
            guard let item = object["item"] as? [String: Any], item["type"] as? String == "agent_message",
                  let piece = item["text"] as? String, !piece.isEmpty else { return false }
            text += text.isEmpty ? piece : "\n\n" + piece
            return true
        case "turn.completed":
            finished = true
        case "turn.failed":
            finished = true
            failure = (object["error"] as? [String: Any])?["message"] as? String ?? "Codex stopped without an answer."
        case "error":
            // Codex retries a failing connection five times and says so on the way.
            if let message = object["message"] as? String, !message.hasPrefix("Reconnecting"), failure == nil {
                failure = message
            }
        default: break
        }
        return false
    }
}

// MARK: - Koncluí Proxy

struct KoncluiModel: Equatable, Sendable {
    let id: String
    let label: String
}

enum KoncluiProxy {
    /// The generic-password service klaude keeps its key under (account: the user name).
    static let keychainService = "klaude-api-key"
    static let anthropicVersion = "2023-06-01"

    /// `proxy_url=…` from the klaude launcher (`~/.local/bin/klaude`): the proxy the user installed.
    /// Only https (or a local http server) counts.
    static func baseURL(fromLauncher script: String) -> String? {
        for line in script.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("proxy_url=") else { continue }
            var value = String(trimmed.dropFirst("proxy_url=".count))
            if let hash = value.range(of: " #") { value = String(value[..<hash.lowerBound]) }
            value = value.trimmingCharacters(in: CharacterSet(charactersIn: "\"' ").union(.whitespaces))
            while value.hasSuffix("/") { value.removeLast() }
            return validBase(value)
        }
        return nil
    }

    static func validBase(_ value: String) -> String? {
        guard let url = URL(string: value), let host = url.host, !host.isEmpty else { return nil }
        let local = host == "localhost" || host == "127.0.0.1"
        guard url.scheme == "https" || (url.scheme == "http" && local) else { return nil }
        return value
    }

    static func endpoint(base: String, path: String) -> URL? {
        var root = base
        while root.hasSuffix("/") { root.removeLast() }
        if root.hasSuffix("/v1") { root.removeLast(3) }
        return URL(string: root + "/v1/" + path)
    }

    /// The Messages API body; `messages` use the Anthropic content-block format.
    static func messagesBody(model: String, system: String, messages: [[String: Any]],
                             maxTokens: Int = 4096) -> Data? {
        let body: [String: Any] = [
            "model": model, "max_tokens": maxTokens, "stream": true,
            "system": system, "messages": messages,
        ]
        return try? JSONSerialization.data(withJSONObject: body)
    }

    /// The proxy takes the token as a bearer, like Claude Code sends `ANTHROPIC_AUTH_TOKEN`.
    static func messagesRequest(base: String, token: String, body: Data) -> URLRequest? {
        guard let url = endpoint(base: base, path: "messages") else { return nil }
        var request = URLRequest(url: url, timeoutInterval: 120)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(anthropicVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("text/event-stream", forHTTPHeaderField: "accept")
        request.httpBody = body
        return request
    }

    static func modelsRequest(base: String, token: String) -> URLRequest? {
        guard let url = endpoint(base: base, path: "models?limit=200") else { return nil }
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(anthropicVersion, forHTTPHeaderField: "anthropic-version")
        return request
    }

    /// `{"data": [{"id", "display_name"}…]}`: the gateway's model discovery (Claude, Gemini and GPT).
    static func parseModels(_ data: Data) -> [KoncluiModel] {
        guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let items = object["data"] as? [[String: Any]] else { return [] }
        return items.compactMap { item in
            guard let id = item["id"] as? String, !id.isEmpty else { return nil }
            let name = item["display_name"] as? String
            return KoncluiModel(id: id, label: (name?.isEmpty == false ? name : nil) ?? id)
        }
    }

    enum StreamEvent: Equatable {
        case text(String)
        case failure(String)
        case done
        case ignored
    }

    /// One line of the Anthropic server-sent events (`data: {…}`; the `event:` lines carry nothing more).
    static func streamEvent(line: String) -> StreamEvent {
        guard line.hasPrefix("data:") else { return .ignored }
        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
        guard let object = KoncluiCLI.jsonObject(payload) else { return .ignored }
        switch object["type"] as? String {
        case "content_block_delta":
            if let delta = object["delta"] as? [String: Any], delta["type"] as? String == "text_delta",
               let piece = delta["text"] as? String, !piece.isEmpty { return .text(piece) }
            return .ignored
        case "error":
            let message = (object["error"] as? [String: Any])?["message"] as? String
            return .failure(message ?? "The proxy stopped the answer.")
        case "message_stop":
            return .done
        default:
            return .ignored
        }
    }

    /// The server's error text from a non-200 body, with the token wiped in case the server echoes it.
    static func errorMessage(body: Data, status: Int, token: String) -> String {
        var message = "HTTP \(status)"
        if let object = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any] {
            if let nested = (object["error"] as? [String: Any])?["message"] as? String, !nested.isEmpty {
                message = nested
            } else if let plain = object["message"] as? String, !plain.isEmpty {
                message = plain
            }
        }
        return redact(message, token: token)
    }

    static func redact(_ text: String, token: String) -> String {
        token.isEmpty ? text : text.replacingOccurrences(of: token, with: "•••")
    }
}

// MARK: - Prompt for a CLI turn

enum KoncluiPrompt {
    /// The text of one CLI turn. On the first turn it carries the persona (Codex has no system
    /// prompt option) and the window or file context; later turns are just the question, the CLI's
    /// session already holds the rest.
    static func turn(query: String, persona: String?, context: String?) -> String {
        var parts: [String] = []
        if let persona, !persona.isEmpty { parts.append(persona) }
        if let context, !context.isEmpty { parts.append(context) }
        parts.append(query)
        return parts.joined(separator: "\n\n")
    }
}

// MARK: - Migration

/// Koncluí had chat providers of its own for Claude Code and Codex until 2026-10-31; they are Coucou's Anthropic and
/// OpenAI with the subscription switch on now (ChatSubscription.swift). A Mac that chatted through one keeps doing so.
enum KoncluiChatMigration {
    static let moved = ["claude-code": "anthropic", "codex": "openai"]

    static func run(_ defaults: UserDefaults = .standard) {
        if let old = defaults.string(forKey: "chatProvider"), let provider = moved[old] {
            defaults.set(provider, forKey: "chatProvider")
            // ChatSubscription.swift's key for the provider's switch
            defaults.set(true, forKey: "chat.useSubscription.\(provider)")
            // The Claude model chosen for Claude Code is Anthropic's model now ("default" leaves Anthropic's as it is).
            if old == "claude-code", let model = defaults.string(forKey: "claudeCodeChatModel"),
               !model.isEmpty, model != "default" {
                defaults.set(model, forKey: "claudeModel")
            }
        }
        defaults.removeObject(forKey: "claudeCodeChatModel")
        defaults.removeObject(forKey: "codexChatModel")
    }
}
