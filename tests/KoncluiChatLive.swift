import Foundation

// Live probe of the chat routes through the same adapters, command lines and requests the app builds
// (KoncluiChatAdapters + KoncluiChatCore + KoncluiChatProcess). Two turns each: the second checks the thread is
// continued. Cursor also: its sign-in, a read outside any allowed folder and a web search with outside text are refused,
// and stopping a turn ends the CLI and its helpers. Prints answers and statuses only; the proxy key stays in a local
// variable and is never printed. KONCLUI_CHAT_LIVE_ROUTES="cursor" (any of claude codex cursor proxy) narrows it.

@main
enum KoncluiChatLive {
    static let persona = "You are Koru, a concise assistant in a Mac's notch. Answer in at most one short sentence."
    static let first = "Remember this word: PINEAPPLE. Reply with just: noted."
    static let second = "What word did I ask you to remember? Reply with just that word."

    static let home = FileManager.default.homeDirectoryForCurrentUser.path
    static let routes = Set((ProcessInfo.processInfo.environment["KONCLUI_CHAT_LIVE_ROUTES"] ?? "claude codex cursor proxy")
        .split(separator: " ").map(String.init))
    nonisolated(unsafe) static var failures = 0

    static func main() async {
        signal(SIGPIPE, SIG_IGN)
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("konclui-chat-live-\(getpid())", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        if routes.contains("claude") { await claude(dir) }
        if routes.contains("codex") { await codex(dir) }
        if routes.contains("cursor") { await cursor(dir) }
        if routes.contains("proxy") { await proxy() }

        // exit() skips a defer: the chat folder (and Cursor's config in it) goes here.
        try? FileManager.default.removeItem(at: dir)
        print(failures == 0 ? "KoncluiChatLive: all routes answered" : "KoncluiChatLive: \(failures) problem(s)")
        exit(failures == 0 ? 0 : 1)
    }

    // MARK: One turn, as the engine runs it

    struct Outcome {
        var text: String
        var threadID: String?
        var failed: Bool
        var failure: String?
        var code: Int32
        var stderr: String
        var grew: Int
        var lines: [String]
    }

    static func turn<A: KoncluiCLIAdapter>(_ adapter: A, _ executable: String, _ turn: KoncluiCLITurn, in dir: URL,
                                         timeout: TimeInterval = 180) async -> Outcome {
        let plan = adapter.plan(turn)
        for (path, contents) in plan.files {
            let url = URL(fileURLWithPath: path)
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? contents.write(to: url, atomically: true, encoding: .utf8)
        }
        let env = KoncluiCLI.environment(base: ProcessInfo.processInfo.environment, executable: executable, home: home)
            .merging(plan.environment) { _, added in added }
        var stream = adapter.stream()
        var outcome = Outcome(text: "", failed: false, code: -1, stderr: "", grew: 0, lines: [])
        for await event in KoncluiProcess.stream(executable, plan.arguments, environment: env, directory: dir,
                                                 input: plan.stdin.map { Data($0.utf8) }, timeout: timeout) {
            switch event {
            case .line(let line):
                outcome.lines.append(line)
                if stream.feed(line) { outcome.grew += 1 }
            case .exit(let code, let stderr, _): outcome.code = code; outcome.stderr = stderr
            case .failedToStart(let why): outcome.stderr = why
            }
        }
        stream.end(exitCode: outcome.code)
        outcome.text = stream.text.trimmingCharacters(in: .whitespacesAndNewlines)
        outcome.threadID = stream.threadID
        outcome.failed = stream.failed
        outcome.failure = stream.failure
        return outcome
    }

    static func locate(_ name: String) -> String? {
        KoncluiCLI.find(name, home: home) { FileManager.default.isExecutableFile(atPath: $0) }
    }

    static func report(_ route: String, _ label: String, _ outcome: Outcome) {
        let text = outcome.text.replacingOccurrences(of: "\n", with: " ⏎ ")
        print("[\(route)] \(label): \(text)  (exit \(outcome.code), \(outcome.grew) updates, failure \(outcome.failure ?? "none"))")
    }

    static func check(_ ok: Bool, _ route: String, _ what: String) {
        print("[\(route)] \(ok ? "ok" : "FAILED"): \(what)")
        if !ok { failures += 1 }
    }

    /// Two turns on one thread: the second must remember the first.
    static func thread<A: KoncluiCLIAdapter>(_ route: String, _ adapter: A, _ executable: String, in dir: URL,
                                           firstTurn: KoncluiCLITurn) async {
        let one = await turn(adapter, executable, firstTurn, in: dir)
        report(route, "turn 1", one)
        check(!one.text.isEmpty && !one.failed && one.threadID != nil, route, "first turn answered, with a thread id")
        // A `.flag` CLI gets its system prompt on every turn, as the engine sends it.
        let two = await turn(adapter, executable, KoncluiCLITurn(prompt: second, system: firstTurn.system,
                                                                 resume: one.threadID), in: dir)
        report(route, "turn 2", two)
        check(two.text.uppercased().contains("PINEAPPLE"), route, "the thread is continued")
    }

    // MARK: Routes

    static func claude(_ dir: URL) async {
        guard let claude = locate("claude") else { return check(false, "claude-code", "installed") }
        let env = KoncluiCLI.environment(base: ProcessInfo.processInfo.environment, executable: claude, home: home)
        let status = await KoncluiProcess.capture(claude, ["auth", "status", "--json"], environment: env, timeout: 15)
        print("[claude-code] login:", KoncluiCLI.parseClaudeLogin(output: status?.stdout ?? "", exitCode: status?.exitCode ?? -1))
        await thread("claude-code", KoncluiClaudeAdapter(model: "haiku"), claude, in: dir,
                     firstTurn: KoncluiCLITurn(prompt: first, system: persona))
    }

    static func codex(_ dir: URL) async {
        guard let codex = locate("codex") else { return check(false, "codex", "installed") }
        let env = KoncluiCLI.environment(base: ProcessInfo.processInfo.environment, executable: codex, home: home)
        let status = await KoncluiProcess.capture(codex, ["login", "status"], environment: env, timeout: 15)
        print("[codex] login:", KoncluiCLI.parseCodexLogin(output: (status?.stdout ?? "") + "\n" + (status?.stderr ?? ""),
                                                           exitCode: status?.exitCode ?? -1))
        let adapter = KoncluiCodexAdapter(model: KoncluiCodexCLI.configuredModel() ?? "")
        await thread("codex", adapter, codex, in: dir, firstTurn: KoncluiCLITurn(prompt: persona + "\n\n" + first))

        // A conversation with email or a dropped file: --ephemeral. Nothing is kept, so its thread cannot be resumed
        // (Codex 0.166 keeps threads in its own database, not as files: resuming is the observable check).
        let unsaved = await turn(adapter, codex, KoncluiCLITurn(prompt: persona + "\n\n" + first, web: false, persist: false),
                                 in: dir)
        report("codex", "ephemeral", unsaved)
        check(!unsaved.text.isEmpty && !unsaved.failed, "codex", "an ephemeral turn answers")
        let again = await turn(adapter, codex, KoncluiCLITurn(prompt: second, resume: unsaved.threadID), in: dir)
        report("codex", "resume ephemeral", again)
        check(unsaved.threadID != nil && !again.text.uppercased().contains("PINEAPPLE"), "codex",
              "and keeps nothing: its thread cannot be continued\(KoncluiCLI.isLostThread(stderr: again.stderr) ? " (lost thread)" : "")")
    }

    static func cursor(_ dir: URL) async {
        guard let cursor = locate("cursor-agent") else { return check(false, "cursor", "installed") }
        let env = KoncluiCLI.environment(base: ProcessInfo.processInfo.environment, executable: cursor, home: home)
        let about = await KoncluiProcess.capture(cursor, ["about", "--format", "json"], environment: env, timeout: 20)
        let login = KoncluiCursorCLI.parseLogin(output: about?.stdout ?? "")
        print("[cursor] login:", login.map { "\($0)" } ?? "unknown")
        guard case .signedIn = login else {
            return check(false, "cursor", "signed in (sign in with cursor-agent login; the rest needs it)")
        }
        let configDir = dir.appendingPathComponent("cursor-config")
        let userConfig = try? String(contentsOfFile: KoncluiCursorCLI.userConfigPath(
            environment: ProcessInfo.processInfo.environment, home: home), encoding: .utf8)
        func adapter() -> KoncluiCursorAdapter {
            KoncluiCursorAdapter(workDir: dir.path, configDir: configDir.path,
                                 currentConfig: try? String(contentsOf: configDir.appendingPathComponent("cli-config.json"), encoding: .utf8),
                                 userConfig: userConfig)
        }
        await thread("cursor", adapter(), cursor, in: dir, firstTurn: KoncluiCLITurn(prompt: persona + "\n\n" + first))

        // A dropped text file (the route keeps the web off): its text in the prompt, as the engine composes it.
        let dropDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("konclui-drop-\(getpid())")
        try? FileManager.default.createDirectory(at: dropDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dropDir) }
        let code = "MAPLE-\(Int.random(in: 1000...9999))"
        let notes = dropDir.appendingPathComponent("notes.txt")
        try? (String(repeating: "Filler line about nothing.\n", count: 4000) + "The project code is \(code).\n")
            .write(to: notes, atomically: true, encoding: .utf8)
        let fileContext = KoncluiChatEngine.fileContext(name: "notes.txt", text: CLIRelay.inlineText(notes))
        let ask = "What is the project code in the file? Reply with just the code."
        let dropped = KoncluiChatEngine.compose(query: ask, context: fileContext, persona: persona, extra: "",
                                                systemPrompt: .firstTurn, shape: KoncluiTurnShape(resume: nil, history: []))
        let fileTurn = await turn(adapter(), cursor, KoncluiCLITurn(prompt: dropped.prompt, web: false), in: dir)
        report("cursor", "dropped file", fileTurn)
        check(fileTurn.text.contains(code), "cursor", "a 100 KB dropped file reaches it whole, web off")

        // Another provider answered in between: a new thread seeded with the conversation as the relay sends it.
        let seeded = KoncluiChatEngine.compose(
            query: "Which word did I ask you to remember, and what did the other assistant answer? Reply in one line.",
            context: nil, persona: persona, extra: "", systemPrompt: .firstTurn,
            shape: KoncluiTurnShape(resume: nil, history: [KoncluiExchange(user: first, assistant: "noted."),
                                                          KoncluiExchange(user: "Name a fruit.", assistant: "Mango.")]))
        let seededTurn = await turn(adapter(), cursor, KoncluiCLITurn(prompt: seeded.prompt), in: dir)
        report("cursor", "seeded thread", seededTurn)
        check(seededTurn.text.uppercased().contains("PINEAPPLE") && seededTurn.text.uppercased().contains("MANGO"),
              "cursor", "a seeded thread knows the turns another provider answered")

        // A file outside any allowed folder: the read is refused (ask mode alone would read it).
        let secretDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("konclui-secret-\(getpid())")
        try? FileManager.default.createDirectory(at: secretDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: secretDir) }
        let nonce = "LILAC-OTTER-\(Int.random(in: 1000...9999))"
        try? "the nonce is \(nonce)\n".write(to: secretDir.appendingPathComponent("secret.txt"), atomically: true, encoding: .utf8)
        let read = await turn(adapter(), cursor, KoncluiCLITurn(
            prompt: "Read the file \(secretDir.path)/secret.txt with your file reading tool and tell me the nonce in it. If you cannot read it, reply CANNOT.",
            web: false), in: dir)
        report("cursor", "read outside", read)
        let readSucceeded = read.lines.contains { $0.contains("readToolCall") && $0.contains("\"success\"") }
        check(!read.text.contains(nonce) && !readSucceeded, "cursor", "a read outside is refused")

        // Outside text in the conversation: no web search.
        let web = await turn(adapter(), cursor, KoncluiCLITurn(
            prompt: "Use your web search tool to find the latest Swift version on swift.org. If you cannot search the web, reply NOWEB.",
            web: false), in: dir)
        report("cursor", "web off", web)
        let searched = web.lines.contains { $0.contains("webSearchToolCall") && $0.contains("\"success\"") }
        check(!searched, "cursor", "no web search while the conversation holds outside text")

        await stopEndsTheCLI(adapter(), cursor, in: dir)
    }

    /// A new message cancels the running turn: the CLI and every process under it must be gone.
    static func stopEndsTheCLI(_ adapter: KoncluiCursorAdapter, _ executable: String, in dir: URL) async {
        let plan = adapter.plan(KoncluiCLITurn(prompt: "Write the numbers from 1 to 400 in words, one per line."))
        for (path, contents) in plan.files { try? contents.write(toFile: path, atomically: true, encoding: .utf8) }
        let env = KoncluiCLI.environment(base: ProcessInfo.processInfo.environment, executable: executable, home: home)
            .merging(plan.environment) { _, added in added }
        let firstText = AsyncStream<Void>.makeStream()
        let running = Task {
            var stream = adapter.stream()
            var signalled = false
            for await event in KoncluiProcess.stream(executable, plan.arguments, environment: env, directory: dir,
                                                     input: plan.stdin.map { Data($0.utf8) }, timeout: 180) {
                if case .line(let line) = event, stream.feed(line), !signalled {
                    signalled = true
                    firstText.continuation.yield()
                }
            }
            firstText.continuation.finish()
        }
        for await _ in firstText.stream { break }
        let before = descendants(of: getpid())
        print("[cursor] streaming; processes under the chat before the stop: \(before.count)")
        running.cancel()
        var left = before
        for _ in 0..<40 where !left.isEmpty {
            try? await Task.sleep(for: .milliseconds(250))
            left = left.filter { kill($0, 0) == 0 }
        }
        check(!before.isEmpty && left.isEmpty, "cursor", "stopping the turn ends the CLI and its helpers (\(left.count) left)")
    }

    static func descendants(of pid: pid_t) -> [pid_t] {
        let pipe = Pipe()
        let ps = Process()
        ps.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        ps.arguments = ["-P", "\(pid)"]
        ps.standardOutput = pipe
        try? ps.run()
        ps.waitUntilExit()
        let children = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            .split(separator: "\n").compactMap { pid_t($0) }
        return children.flatMap { [$0] + descendants(of: $0) }
    }

    static func proxy() async {
        let launcher = home + "/.local/bin/klaude"
        guard let script = try? String(contentsOfFile: launcher, encoding: .utf8),
              let base = KoncluiProxy.baseURL(fromLauncher: script) else {
            return check(false, "konclui-proxy", "klaude launcher found")
        }
        print("[konclui-proxy] base:", base)
        let user = NSUserName()
        let has = await KoncluiProcess.capture("/usr/bin/security", ["find-generic-password", "-a", user, "-s", KoncluiProxy.keychainService], timeout: 10)
        print("[konclui-proxy] key item present:", has?.exitCode == 0)
        let read = await KoncluiProcess.capture("/usr/bin/security", ["find-generic-password", "-a", user, "-s", KoncluiProxy.keychainService, "-w"], timeout: 10)
        guard let key = read?.stdout.trimmingCharacters(in: .whitespacesAndNewlines), read?.exitCode == 0, !key.isEmpty else {
            return check(false, "konclui-proxy", "key found")
        }
        if let list = KoncluiProxy.modelsRequest(base: base, token: key) {
            let (data, response) = (try? await URLSession.shared.data(for: list)) ?? (Data(), URLResponse())
            let models = KoncluiProxy.parseModels(data)
            print("[konclui-proxy] /v1/models: HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0), \(models.count) models, first: \(models.first?.id ?? "-")")
            check(!models.isEmpty, "konclui-proxy", "models listed")
        }
        var history: [[String: Any]] = []
        for (index, prompt) in [first, second].enumerated() {
            history.append(["role": "user", "content": [["type": "text", "text": prompt]]])
            var text = ""
            var note = ""
            if let body = KoncluiProxy.messagesBody(model: "claude-haiku-5-5", system: persona, messages: history),
               let request = KoncluiProxy.messagesRequest(base: base, token: key, body: body) {
                do {
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    note = "HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)"
                    for try await line in bytes.lines {
                        if case .text(let piece) = KoncluiProxy.streamEvent(line: line) { text += piece }
                    }
                } catch { note = "error: \(KoncluiProxy.redact(error.localizedDescription, token: key))" }
            }
            history.append(["role": "assistant", "content": text])
            print("[konclui-proxy] turn \(index + 1): \(text.replacingOccurrences(of: "\n", with: " ⏎ "))  (\(note))")
            check(!text.isEmpty, "konclui-proxy", "turn \(index + 1) answered")
            if index == 1 { check(text.uppercased().contains("PINEAPPLE"), "konclui-proxy", "the conversation is continued") }
        }
    }
}
