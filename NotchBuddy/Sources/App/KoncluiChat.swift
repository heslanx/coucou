import AppKit
import Foundation

// Koncluí: the notch chat through what this Mac is already signed in to (unit K10).
//   Claude         Anthropic with Coucou's subscription switch on: the official `claude` CLI, the user's Claude
//                  login (`claude -p`, stream-json)
//   ChatGPT        OpenAI with the switch on: the official `codex` CLI, the user's ChatGPT login (`codex exec --json`)
//   Koncluí Proxy  the Anthropic Messages API of the proxy behind klaude, with klaude's key
// Coucou's relay (CLIRelay.swift) answers the other subscriptions (Gemini, Cursor, Copilot) with the whole answer at
// once; these two stream as they are written, keep the CLI's own thread, and stop when a new turn starts.
// The CLIs run as subprocesses and keep their own credentials: Koncluí never reads them. The proxy
// key is read from klaude's Keychain item when a request starts and lives in a local variable.

// MARK: - Proxy access (launcher URL, key)

enum KoncluiProxyAccess {
    /// A user-set proxy address (`defaults write … konclui.proxyURL`), else the one in the klaude launcher.
    static let urlDefaultsKey = "konclui.proxyURL"

    static var launcherPath: String {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".local/bin/klaude").path
    }

    static func baseURL() -> String? {
        if let custom = UserDefaults.standard.string(forKey: urlDefaultsKey), !custom.isEmpty {
            return KoncluiProxy.validBase(custom)
        }
        guard let script = try? String(contentsOfFile: launcherPath, encoding: .utf8) else { return nil }
        return KoncluiProxy.baseURL(fromLauncher: script)
    }

    #if !APPSTORE
    /// Whether klaude's Keychain item exists. Without `-w`, `security` prints attributes only.
    static func hasKey() async -> Bool {
        guard let out = await KoncluiProcess.capture("/usr/bin/security", keyArguments(reveal: false), timeout: 8)
        else { return false }
        return out.exitCode == 0
    }

    /// The key, read when a request starts the way klaude does. The caller keeps it in a local
    /// variable: it is never stored, logged or shown.
    static func readKey() async -> String? {
        guard let out = await KoncluiProcess.capture("/usr/bin/security", keyArguments(reveal: true), timeout: 8),
              out.exitCode == 0 else { return nil }
        let key = out.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return key.isEmpty ? nil : key
    }

    private static func keyArguments(reveal: Bool) -> [String] {
        ["find-generic-password", "-a", NSUserName(), "-s", KoncluiProxy.keychainService] + (reveal ? ["-w"] : [])
    }
    #else
    static func hasKey() async -> Bool { false }
    static func readKey() async -> String? { nil }
    #endif
}

// MARK: - CLI locations

enum KoncluiCLILocator {
    static func find(_ name: String) -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let nvm = (try? FileManager.default.contentsOfDirectory(atPath: "\(home)/.nvm/versions/node")) ?? []
        return KoncluiCLI.find(name, home: home, nvmVersions: nvm) {
            FileManager.default.isExecutableFile(atPath: $0)
        }
    }

    static func environment(for executable: String) -> [String: String] {
        KoncluiCLI.environment(base: ProcessInfo.processInfo.environment, executable: executable,
                               home: FileManager.default.homeDirectoryForCurrentUser.path)
    }

    /// Where the CLI turns run: one folder of their own, so the chat never reads a project's files.
    static var chatDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("Konclui/chat", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}

// MARK: - Models for the picker

enum KoncluiChatModels {
    enum Failure: Error { case message(String) }

    /// The models of the Koncluí Proxy (its /v1/models). Claude's come from AppState (KoncluiClaudeCLI.models);
    /// Codex uses the model chosen in Codex itself, as Coucou's relay does.
    static func load(_ provider: ChatProvider) async -> Result<[(id: String, label: String)], Failure> {
        let models: [KoncluiModel] = provider == .koncluiProxy ? await proxyModels() : []
        guard !models.isEmpty else {
            return .failure(.message(String(localized: "Couldn't load the models. Try again.")))
        }
        return .success(models.map { model in
            (id: model.id, label: model.id == "default" ? String(localized: "Default model") : model.label)
        })
    }

    private static func proxyModels() async -> [KoncluiModel] {
        guard let base = KoncluiProxyAccess.baseURL(), let key = await KoncluiProxyAccess.readKey(),
              let request = KoncluiProxy.modelsRequest(base: base, token: key),
              let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return [] }
        return KoncluiProxy.parseModels(data)
    }
}

// MARK: - The chat

@MainActor
final class KoncluiChat {
    static let shared = KoncluiChat()

    /// Each CLI's own memory of the conversation, so a turn continues the same thread.
    private var claudeSession: String?
    private var codexThread: String?
    /// The proxy is stateless: the whole conversation goes with every request (Anthropic format).
    private var proxyMessages: [[String: Any]] = []
    private var running: Task<Void, Never>?
    private var quitObserver: NSObjectProtocol?

    private init() {
        #if !APPSTORE
        quitObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { _ in
            KoncluiProcess.terminateAll()
        }
        #endif
    }

    /// The conversation carries text from outside (email with Mail on, a dropped file): no web tool until it is
    /// cleared, so that text cannot steer the model into sending what it read to a website.
    private var holdsOutsideText = false

    /// Who answers: Claude and ChatGPT once their subscription switch is on, and the Koncluí Proxy.
    enum Route: Equatable, Sendable { case claude, codex, proxy }

    /// The route for the chat's provider, or nil when Coucou's own code answers it (a key, a local server, the relay).
    static func route(for provider: ChatProvider, state: AppState) -> Route? {
        switch provider {
        case .koncluiProxy: return .proxy
        case .anthropic:    return state.usesSubscription(.anthropic) ? .claude : nil
        case .openai:       return state.usesSubscription(.openai) ? .codex : nil
        default:            return nil
        }
    }

    /// A new conversation: ends a running turn (and its subprocess) and forgets the threads.
    func clear() {
        running?.cancel()
        running = nil
        claudeSession = nil
        codexThread = nil
        proxyMessages = []
        holdsOutsideText = false
    }

    /// `extraSystem`: instructions added to the system prompt for this turn (Mail's plan format, MailAgentPrompt).
    func chat(_ route: Route, query: String, context: PromptContext?, state: AppState, extraSystem: String = "") async {
        running?.cancel()
        if state.chatMailMode { holdsOutsideText = true }
        if case .file = context { holdsOutsideText = true }
        // What this turn sends is fixed here: a later turn cannot change it under a cancelled one.
        let extra = extraSystem, web = !holdsOutsideText
        let turn = Task { @MainActor in
            switch route {
            case .claude: await self.claudeTurn(query: query, context: context, state: state, extra: extra, web: web)
            case .codex:  await self.codexTurn(query: query, context: context, state: state, extra: extra)
            case .proxy:  await self.proxyTurn(query: query, context: context, state: state, extra: extra)
            }
        }
        running = turn
        await withTaskCancellationHandler { await turn.value } onCancel: { turn.cancel() }
    }

    // MARK: Claude Code

    private func claudeTurn(query: String, context contextArgument: PromptContext?, state: AppState, extra: String,
                            web: Bool) async {
        #if !APPSTORE
        guard let claude = KoncluiCLILocator.find("claude") else {
            return fail(String(localized: "Claude Code is not installed. Install it to use your Claude subscription."), state: state)
        }
        // A dropped PDF or image: Claude Code reads a copy of that one file (Coucou's relay does the same).
        var readDir: URL?
        var context = claudeSession == nil ? Self.contextText(contextArgument) : nil
        if claudeSession == nil, case .file(let name, let url?) = contextArgument, Self.isBinary(url),
           let dir = try? CLIRelay.isolate(url) {
            readDir = dir
            context = "File: \(name) (read it at \(dir.appendingPathComponent(url.lastPathComponent).path))"
        }
        defer { if let readDir { try? FileManager.default.removeItem(at: readDir) } }
        let prompt = KoncluiPrompt.turn(query: query, persona: nil, context: context)
        let placeholder = beginAnswer(state: state)
        let model = state.activeChatModel
        let system = ClaudeService.makeSystemPrompt() + extra
        var stream = KoncluiClaudeStream()
        var ended: (code: Int32, stderr: String, timedOut: Bool) = (0, "", false)

        for safeMode in [true, false] {
            stream = KoncluiClaudeStream()
            ended = await consume(
                KoncluiProcess.stream(claude,
                                      KoncluiClaudeCLI.arguments(model: model, resume: claudeSession,
                                                                 systemPrompt: system, safeMode: safeMode,
                                                                 web: web, readDir: readDir),
                                      environment: KoncluiCLILocator.environment(for: claude),
                                      directory: KoncluiCLILocator.chatDirectory,
                                      input: Data(prompt.utf8), timeout: 300),
                placeholder: placeholder, state: state) { line in
                    stream.feed(line) ? stream.text : nil
                }
            // An older Claude Code does not know --safe-mode: once more without it.
            if safeMode, !Task.isCancelled, ended.code != 0, stream.text.isEmpty,
               KoncluiClaudeCLI.isUnknownSafeMode(stderr: ended.stderr) {
                continue
            }
            break
        }
        if Task.isCancelled { return abandon(placeholder, state: state) }

        if let id = stream.sessionID, !stream.failed { claudeSession = id }
        if claudeSession != nil, KoncluiCLI.isLostThread(stderr: ended.stderr) { claudeSession = nil }
        let text = stream.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !stream.failed, !text.isEmpty {
            return finish(text, placeholder: placeholder, state: state)
        }
        abandon(placeholder, state: state)
        if ended.timedOut { return fail(Self.tookTooLong, state: state) }
        if stream.needsSignIn { return fail(String(localized: "Sign in to Claude Code in Terminal: claude"), state: state) }
        fail(stream.failure ?? Self.stderrMessage(ended.stderr) ?? String(localized: "No response text."), state: state)
        #else
        fail(String(localized: "Not available in this build."), state: state)
        #endif
    }

    // MARK: Codex

    private func codexTurn(query: String, context: PromptContext?, state: AppState, extra: String) async {
        #if !APPSTORE
        guard let codex = KoncluiCLILocator.find("codex") else {
            return fail(String(localized: "Codex is not installed. Install it to use your ChatGPT subscription."), state: state)
        }
        let firstTurn = codexThread == nil
        var images: [String] = []
        if firstTurn, case .file(_, let url?) = context, KoncluiCodexCLI.imageExtensions.contains(url.pathExtension.lowercased()) {
            images = [url.path]
        }
        let prompt = KoncluiPrompt.turn(
            query: query,
            persona: firstTurn ? ClaudeService.makeSystemPrompt(webSearch: false) + extra
                               : (extra.isEmpty ? nil : extra),
            context: firstTurn ? Self.contextText(context) : nil)
        let placeholder = beginAnswer(state: state)
        var stream = KoncluiCodexStream()
        let ended = await consume(
            KoncluiProcess.stream(codex,
                                  KoncluiCodexCLI.arguments(model: "", resume: codexThread, images: images),
                                  environment: KoncluiCLILocator.environment(for: codex),
                                  directory: KoncluiCLILocator.chatDirectory,
                                  input: Data(prompt.utf8), timeout: 300),
            placeholder: placeholder, state: state) { line in
                stream.feed(line) ? stream.text : nil
            }
        if Task.isCancelled { return abandon(placeholder, state: state) }

        if let id = stream.threadID, stream.failure == nil { codexThread = id }
        if codexThread != nil, KoncluiCLI.isLostThread(stderr: ended.stderr) { codexThread = nil }
        let text = stream.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if stream.failure == nil, !text.isEmpty {
            return finish(text, placeholder: placeholder, state: state)
        }
        abandon(placeholder, state: state)
        if ended.timedOut { return fail(Self.tookTooLong, state: state) }
        if stream.needsSignIn { return fail(String(localized: "Sign in to Codex in Terminal: codex login"), state: state) }
        fail(stream.failure ?? Self.stderrMessage(ended.stderr) ?? String(localized: "No response text."), state: state)
        #else
        fail(String(localized: "Not available in this build."), state: state)
        #endif
    }

    /// Runs the subprocess stream to its end, showing the text each line grows to (15 times a second at most).
    #if !APPSTORE
    private func consume(_ events: AsyncStream<KoncluiProcess.Event>, placeholder: UUID, state: AppState,
                         feed: (String) -> String?) async -> (code: Int32, stderr: String, timedOut: Bool) {
        var last = Date.distantPast
        var pending: String?
        var result: (code: Int32, stderr: String, timedOut: Bool) = (-1, "", false)
        for await event in events {
            switch event {
            case .line(let line):
                guard let visible = feed(line) else { continue }
                pending = visible
                if Date().timeIntervalSince(last) >= 1.0 / 15.0 {
                    last = Date()
                    show(visible, placeholder: placeholder, state: state)
                    pending = nil
                }
            case .failedToStart(let message):
                result = (-1, message, false)
            case .exit(let code, let stderr, let timedOut):
                result = (code, stderr, timedOut)
            }
        }
        if let pending { show(pending, placeholder: placeholder, state: state) }
        return result
    }
    #endif

    // MARK: Koncluí Proxy

    private func proxyTurn(query: String, context: PromptContext?, state: AppState, extra: String) async {
        guard let base = KoncluiProxyAccess.baseURL() else {
            return fail(String(localized: "klaude is not installed. Install it to use the Koncluí Proxy."), state: state)
        }
        guard let key = await KoncluiProxyAccess.readKey() else {
            return fail(String(localized: "klaude has no key: run klaude doctor in Terminal"), state: state)
        }
        if Task.isCancelled { return }

        var content: [[String: Any]] = []
        if proxyMessages.isEmpty, let context {
            switch context {
            case .window:
                if let text = Self.contextText(context) { content.append(["type": "text", "text": text]) }
            case .file(let name, let url):
                if let url, let block = ClaudeService.shared.readFileAsBlock(url: url) { content.append(block) }
                content.append(["type": "text", "text": "File: \(name)"])
            }
        }
        content.append(["type": "text", "text": query])
        proxyMessages.append(["role": "user", "content": content])

        guard let body = KoncluiProxy.messagesBody(model: state.activeChatModel,
                                                   system: ClaudeService.makeSystemPrompt(webSearch: false) + extra,
                                                   messages: proxyMessages),
              let request = KoncluiProxy.messagesRequest(base: base, token: key, body: body) else {
            proxyMessages.removeLast()
            return fail(String(localized: "The Koncluí Proxy is unreachable. Check your connection."), state: state)
        }

        let placeholder = beginAnswer(state: state)
        var text = ""
        var last = Date.distantPast
        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if status != 200 {
                var raw = Data()
                for try await byte in bytes { raw.append(byte); if raw.count > 4096 { break } }
                throw ProxyFailure.http(status, KoncluiProxy.errorMessage(body: raw, status: status, token: key))
            }
            streaming: for try await line in bytes.lines {
                switch KoncluiProxy.streamEvent(line: line) {
                case .text(let piece):
                    text += piece
                    if Date().timeIntervalSince(last) >= 1.0 / 15.0 {
                        last = Date()
                        show(text, placeholder: placeholder, state: state)
                    }
                case .failure(let message):
                    throw ProxyFailure.http(0, KoncluiProxy.redact(message, token: key))
                case .done:
                    break streaming
                case .ignored:
                    continue
                }
            }
            let final = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !final.isEmpty else { throw ProxyFailure.empty }
            proxyMessages.append(["role": "assistant", "content": final])
            finish(final, placeholder: placeholder, state: state)
        } catch {
            proxyMessages.removeLast()
            abandon(placeholder, state: state)
            if Task.isCancelled || (error as? URLError)?.code == .cancelled { return }
            switch error {
            case ProxyFailure.http(let status, _) where status == 401 || status == 403:
                fail(String(localized: "The Koncluí Proxy refused the key. Run klaude doctor in Terminal."), state: state)
            case ProxyFailure.http(_, let message):
                fail(message, state: state)
            case ProxyFailure.empty:
                fail(String(localized: "No response text."), state: state)
            default:
                fail(String(localized: "The Koncluí Proxy is unreachable. Check your connection."), state: state)
            }
        }
    }

    private enum ProxyFailure: Error {
        case http(Int, String)
        case empty
    }

    // MARK: Shared pieces

    private static var tookTooLong: String { String(localized: "The chat took too long. Ask again.") }

    /// The window or file the user attached, as text for the first turn.
    /// A file Claude Code reads with its Read tool rather than as text in the prompt.
    private static func isBinary(_ url: URL) -> Bool {
        ["pdf", "jpg", "jpeg", "png", "gif", "webp"].contains(url.pathExtension.lowercased())
    }

    private static func contextText(_ context: PromptContext?) -> String? {
        switch context {
        case nil:
            return nil
        case .window(let app, let title, let url):
            var text = "Context — App: \(app), Window: \(title)"
            if let url { text += ", URL: \(url)" }
            return text
        case .file(let name, let fileURL):
            let ext = fileURL?.pathExtension.lowercased() ?? ""
            let binary = ["pdf", "jpg", "jpeg", "png", "gif", "webp"]
            if let fileURL, !binary.contains(ext), let text = try? String(contentsOf: fileURL, encoding: .utf8), !text.isEmpty {
                let shown = text.count > 24_000 ? String(text.prefix(24_000)) + "\n[truncated]" : text
                return "File: \(name)\n\n\(shown)"
            }
            return "File: \(name)"
        }
    }

    /// The last meaningful line of a CLI's stderr, when it printed one.
    private static func stderrMessage(_ stderr: String) -> String? {
        let lines = stderr.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("Reading additional input") }
        return lines.last.map { String($0.prefix(300)) }
    }

    /// An empty assistant bubble (hidden until the first text) and the typing dots.
    private func beginAnswer(state: AppState) -> UUID {
        let bubble = ChatMessage(role: .assistant, content: "")
        state.chatHistory.append(bubble)
        state.stateOverride = .thinking
        return bubble.id
    }

    private func show(_ text: String, placeholder: UUID, state: AppState) {
        if !text.isEmpty, state.stateOverride == .thinking { state.stateOverride = nil }
        if let index = state.chatHistory.firstIndex(where: { $0.id == placeholder }) {
            state.chatHistory[index].content = text
        }
    }

    private func finish(_ text: String, placeholder: UUID, state: AppState) {
        show(text, placeholder: placeholder, state: state)
        state.stateOverride = nil
        state.view = .prompt
        NotificationCenter.default.post(name: .triggerEmote, object: BotEmote.happy)
    }

    /// Drops the bubble of an answer that did not come.
    private func abandon(_ placeholder: UUID, state: AppState) {
        state.chatHistory.removeAll { $0.id == placeholder }
        if state.stateOverride == .thinking { state.stateOverride = nil }
    }

    private func fail(_ message: String, state: AppState) {
        state.stateOverride = .error
        state.noteMessage = message
        state.view = .note
    }
}
