import AppKit
import Combine
import Foundation

// Koncluí: the notch chat through what this Mac is already signed in to (unit K10).
//   Subscriptions  a provider with Coucou's "Use my subscription" switch on: its official CLI, signed in with the
//                  user's own account (Claude Code, Codex, Gemini CLI or Antigravity, Cursor, Copilot), one adapter
//                  each (KoncluiChatAdapters.swift)
//   Koncluí Proxy  the Anthropic Messages API of the proxy behind klaude, with klaude's key
// The answer streams as it is written where the CLI can, the CLI keeps its own thread where it can, and a new turn,
// Clear or Quit stops the running CLI and its helpers (ADR-009). Coucou's relay (CLIRelay.swift) still says when no
// installed tool can answer a conversation that holds email.
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
    /// Where Settings found the tool (Coucou's CLILocator: asdf, fnm, the login shell…) is where it runs from;
    /// Koncluí's own folders are the fallback.
    static func find(_ cli: SubscriptionCLI) -> String? {
        #if !APPSTORE
        if let path = CLILocator.shared.path(cli) { return path }
        #endif
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let nvm = (try? FileManager.default.contentsOfDirectory(atPath: "\(home)/.nvm/versions/node")) ?? []
        for name in cli.binaries {
            if let path = KoncluiCLI.find(name, home: home, nvmVersions: nvm, isExecutable: {
                FileManager.default.isExecutableFile(atPath: $0)
            }) { return path }
        }
        return nil
    }

    static func environment(for executable: String) -> [String: String] {
        KoncluiCLI.environment(base: ProcessInfo.processInfo.environment, executable: executable,
                               home: FileManager.default.homeDirectoryForCurrentUser.path)
    }

    /// Where the CLI turns run: one folder of their own, so the chat never reads a project's files.
    static var chatDirectory: URL { folder("chat") }

    /// A folder of Koncluí's own under Application Support (the chat's, a CLI's config or policy).
    static func folder(_ name: String) -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("Konclui/\(name)", isDirectory: true)
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

    /// Each CLI's own memory of the conversation, so a turn continues the same thread while it holds every turn.
    private var threads: [SubscriptionCLI: KoncluiThread] = [:]
    /// The proxy is stateless: the whole conversation goes with every request (Anthropic format).
    private var proxyMessages: [[String: Any]] = []
    /// How many answered turns of the visible conversation `proxyMessages` holds.
    private var proxyAnswers = 0
    private var running: Task<Void, Never>?
    /// The provider whose turn is running: picking another one stops it.
    private var runningProvider: ChatProvider?
    private var quitObserver: NSObjectProtocol?
    private var providerObserver: AnyCancellable?

    private init() {
        #if !APPSTORE
        quitObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { _ in
            KoncluiProcess.terminateAll()
        }
        #endif
        Self.removeCursorChats()
        providerObserver = AppState.shared.$chatProvider.removeDuplicates().dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] provider in
                MainActor.assumeIsolated { self?.stop(unless: provider) }
            }
    }

    /// Another provider was picked: the old one's turn (and its CLI) stops, so it cannot keep writing to the chat.
    private func stop(unless provider: ChatProvider) {
        guard running != nil, provider != runningProvider else { return }
        running?.cancel()
        running = nil
    }

    /// The conversation carries text from outside (email with Mail on, a dropped file): no web tool until it is
    /// cleared, so that text cannot steer the model into sending what it read to a website.
    private var holdsOutsideText = false
    /// The conversation carries email: only a tool that can answer with no web at all takes it.
    private var holdsMail = false

    /// Who answers: a provider's subscription tool once its switch is on, and the Koncluí Proxy.
    enum Route: Equatable, Sendable {
        case cli(SubscriptionCLI)
        /// The conversation holds email or a dropped file and the provider's installed tool cannot turn its web off.
        case refused(SubscriptionCLI)
        case proxy
    }

    /// The route for the chat's provider, or nil when Coucou's own code answers it (a key, a local server).
    /// `context`: the turn's own window or file, which reaches the conversation only once this turn starts.
    static func route(for provider: ChatProvider, state: AppState, context: PromptContext?) -> Route? {
        if provider == .koncluiProxy { return .proxy }
        #if APPSTORE
        return nil
        #else
        guard state.usesSubscription(provider) else { return nil }
        var attachesFile = false
        if case .file = context { attachesFile = true }
        let offline = KoncluiChatEngine.offline(holdsOutsideText: shared.holdsOutsideText, mailMode: state.chatMailMode,
                                                attachesFile: attachesFile)
        switch KoncluiChatEngine.route(provider.subscriptionCLIs, offline: offline,
                                       installed: { CLILocator.shared.isInstalled($0) }) {
        case .cli(let cli)?:     return .cli(cli)
        case .refused(let cli)?: return .refused(cli)
        case nil:                return nil
        }
        #endif
    }

    /// A new conversation: ends a running turn (and its subprocess) and forgets the threads.
    func clear() {
        running?.cancel()
        running = nil
        threads = [:]
        proxyMessages = []
        proxyAnswers = 0
        holdsOutsideText = false
        holdsMail = false
        Self.removeCursorChats()
    }

    /// Koncluí's own config folder for Cursor (`CURSOR_CONFIG_DIR`), where Cursor keeps the chats Koncluí starts.
    private static var cursorConfig: URL { KoncluiCLILocator.folder("cursor") }

    /// A thread lives as long as the conversation: Cursor's copies of Koncluí's chats go when it is cleared and when
    /// Koncluí starts. They are Koncluí's to remove; what other CLIs keep in their own stores is not (ADR-009).
    private static func removeCursorChats() {
        #if !APPSTORE
        let chats = cursorConfig.appendingPathComponent("chats")
        if FileManager.default.fileExists(atPath: chats.path) { try? FileManager.default.removeItem(at: chats) }
        #endif
    }

    /// `extraSystem`: instructions added to the system prompt for this turn (Mail's plan format, MailAgentPrompt).
    func chat(_ route: Route, query: String, context: PromptContext?, state: AppState, extraSystem: String = "") async {
        running?.cancel()
        runningProvider = state.chatProvider
        if state.chatMailMode { holdsOutsideText = true; holdsMail = true }
        if case .file = context { holdsOutsideText = true }
        // What this turn sends is fixed here: a later turn cannot change it under a cancelled one.
        let extra = extraSystem, web = !holdsOutsideText, sensitive = holdsOutsideText
        if case .refused(let cli) = route {
            // Nothing is sent: the conversation keeps saying so until it is cleared, as with email on Coucou's relay.
            let format = holdsMail ? String(localized: "konclui.mail.needs-offline %@")
                                   : String(localized: "konclui.file.needs-offline %@")
            return fail(String(format: format, cli.displayName), state: state)
        }
        let turn = Task { @MainActor in
            switch route {
            case .cli(let cli):  await self.cliTurn(cli, query: query, context: context, state: state, extra: extra,
                                                    web: web, sensitive: sensitive)
            case .proxy:         await self.proxyTurn(query: query, context: context, state: state, extra: extra)
            case .refused:       break
            }
        }
        running = turn
        await withTaskCancellationHandler { await turn.value } onCancel: { turn.cancel() }
    }

    // MARK: Subscription CLIs

    private func cliTurn(_ cli: SubscriptionCLI, query: String, context: PromptContext?, state: AppState, extra: String,
                         web: Bool, sensitive: Bool) async {
        #if !APPSTORE
        await run(Self.adapter(for: cli, state: state), query: query, context: context, state: state, extra: extra,
                  web: web, sensitive: sensitive)
        #else
        fail(String(localized: "Not available in this build."), state: state)
        #endif
    }

    #if !APPSTORE
    /// Each CLI's adapter, with what it needs from this Mac (the model chosen, Koncluí's folders, Cursor's config).
    private static func adapter(for cli: SubscriptionCLI, state: AppState) -> any KoncluiCLIAdapter {
        switch cli {
        case .claude:
            return KoncluiClaudeAdapter(model: state.activeChatModel)
        case .codex:
            return KoncluiCodexAdapter(model: KoncluiCodexCLI.configuredModel() ?? "")
        case .cursor:
            let config = cursorConfig
            let user = KoncluiCursorCLI.userConfigPath(environment: ProcessInfo.processInfo.environment,
                                                       home: FileManager.default.homeDirectoryForCurrentUser.path)
            return KoncluiCursorAdapter(
                workDir: KoncluiCLILocator.chatDirectory.path, configDir: config.path,
                currentConfig: try? String(contentsOf: config.appendingPathComponent("cli-config.json"), encoding: .utf8),
                userConfig: try? String(contentsOfFile: user, encoding: .utf8))
        case .gemini:
            return KoncluiGeminiAdapter(policyPath: KoncluiCLILocator.folder("gemini").appendingPathComponent("chat-policy.toml").path)
        case .antigravity:
            return KoncluiAntigravityAdapter()
        case .copilot:
            return KoncluiCopilotAdapter()
        }
    }

    /// One turn through a CLI: its thread when it has one, the dropped file as it can take it, the answer streamed.
    /// `sensitive`: the conversation holds email or a dropped file; a CLI that can run without saving does.
    private func run<A: KoncluiCLIAdapter>(_ adapter: A, query: String, context contextArgument: PromptContext?,
                                           state: AppState, extra: String, web: Bool, sensitive: Bool) async {
        let cli = adapter.cli
        guard let executable = KoncluiCLILocator.find(cli) else { return fail(adapter.notInstalledMessage, state: state) }
        let transcript = Self.transcript(state)
        let shape = KoncluiChatEngine.shape(adapter.systemPrompt, thread: threads[cli], transcript: transcript,
                                            keepsNothing: sensitive && adapter.turnsPersistenceOff)
        var context = Self.contextText(contextArgument)
        var turn = KoncluiCLITurn(prompt: "", resume: shape.resume, web: web)
        turn.persist = shape.persist
        if shape.resume == nil, case .file(let name, let url?) = contextArgument {
            switch adapter.droppedFile {
            case .readsCopy where Self.isBinary(url):
                // A dropped PDF or image: the CLI reads a copy of that one file (Coucou's relay does the same).
                if let dir = try? CLIRelay.isolate(url) {
                    turn.readDir = dir
                    context = "File: \(name) (read it at \(dir.appendingPathComponent(url.lastPathComponent).path))"
                }
            case .images where KoncluiCodexCLI.imageExtensions.contains(url.pathExtension.lowercased()):
                turn.images = [url.path]
            default:
                break
            }
        }
        defer { if let dir = turn.readDir { try? FileManager.default.removeItem(at: dir) } }
        (turn.prompt, turn.system) = KoncluiChatEngine.compose(
            query: query, context: context, persona: ClaudeService.makeSystemPrompt(webSearch: adapter.searchesWeb && web),
            extra: extra, systemPrompt: adapter.systemPrompt, shape: shape)

        let placeholder = beginAnswer(state: state)
        var plan = adapter.plan(turn)
        var stream = adapter.stream()
        var stdout: [String] = []
        var ended: (code: Int32, stderr: String, timedOut: Bool) = (0, "", false)
        for attempt in 0..<2 {
            do {
                try Self.write(plan.files)
            } catch {
                abandon(placeholder, state: state)
                return fail(error.localizedDescription, state: state)
            }
            stream = adapter.stream()
            stdout = []
            ended = await consume(
                KoncluiProcess.stream(executable, plan.arguments,
                                      environment: KoncluiCLILocator.environment(for: executable)
                                          .merging(plan.environment) { _, added in added },
                                      directory: KoncluiCLILocator.chatDirectory,
                                      input: plan.stdin.map { Data($0.utf8) }, timeout: 300),
                placeholder: placeholder, state: state) { line in
                    if stdout.count < 5000 { stdout.append(line) }
                    return stream.feed(line) ? stream.text : nil
                }
            stream.end(exitCode: ended.code)
            if attempt == 0, !Task.isCancelled, ended.code != 0, stream.text.isEmpty,
               let next = adapter.fallback(turn, stderr: ended.stderr) {
                plan = next
                continue
            }
            break
        }
        if Task.isCancelled { return abandon(placeholder, state: state) }

        if adapter.systemPrompt != .everyTurn, shape.persist, let id = stream.threadID, !stream.failed {
            threads[cli] = KoncluiThread(id: id, answers: transcript.count + 1)
        }
        if threads[cli] != nil, adapter.lostThread(stderr: ended.stderr) { threads[cli] = nil }
        var text = stream.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty, !stream.failed,
           let read = adapter.fallbackAnswer(stdout: stdout, exitCode: ended.code) {
            text = read
        }
        if !stream.failed, !text.isEmpty { return finish(text, placeholder: placeholder, state: state) }
        abandon(placeholder, state: state)
        if ended.timedOut { return fail(Self.tookTooLong, state: state) }
        if stream.needsSignIn || adapter.needsSignIn(stderr: ended.stderr) { return fail(adapter.signInMessage, state: state) }
        fail(stream.failure ?? Self.stderrMessage(ended.stderr) ?? String(localized: "No response text."), state: state)
    }

    /// The answered turns of the chat as the person sees it (the turn now starting is left out).
    private static func transcript(_ state: AppState) -> [KoncluiExchange] {
        KoncluiChatEngine.transcript(state.chatHistory.map { (fromUser: $0.role == .user, text: $0.content) })
    }

    /// The files a CLI reads for its run. A file that cannot be written stops the run: the CLI would run without it.
    private static func write(_ files: [String: String]) throws {
        for (path, contents) in files {
            let url = URL(fileURLWithPath: path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try contents.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    /// Runs the subprocess stream to its end, showing the text each line grows to (15 times a second at most).
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

        // Another provider answered in between: the proxy gets the conversation as the person sees it.
        let transcript = Self.transcript(state)
        if proxyAnswers != transcript.count {
            proxyMessages = transcript.flatMap { exchange -> [[String: Any]] in
                [["role": "user", "content": [["type": "text", "text": exchange.user]]],
                 ["role": "assistant", "content": exchange.assistant]]
            }
        }
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
            proxyAnswers = transcript.count + 1
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
            // Coucou's relay reads the file (up to 200 KB of UTF-8 text): one limit for every CLI.
            #if !APPSTORE
            return KoncluiChatEngine.fileContext(name: name, text: fileURL.flatMap(CLIRelay.inlineText))
            #else
            return KoncluiChatEngine.fileContext(name: name, text: nil)
            #endif
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
