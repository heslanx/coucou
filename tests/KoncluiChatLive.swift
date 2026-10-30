import Foundation

// Live probe of the three chat routes through the same command lines and requests the app builds
// (KoncluiChatCore + KoncluiChatProcess). Two turns each: the second checks the thread is continued.
// Prints answers and statuses only; the proxy key stays in a local variable and is never printed.

@main
enum KoncluiChatLive {
    static let persona = "You are Koru, a concise assistant in a Mac's notch. Answer in at most one short sentence."
    static let first = "Remember this word: PINEAPPLE. Reply with just: noted."
    static let second = "What word did I ask you to remember? Reply with just that word."

    static func main() async {
        signal(SIGPIPE, SIG_IGN)
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("konclui-chat-live", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var failures = 0

        func locate(_ name: String) -> String? {
            KoncluiCLI.find(name, home: home) { FileManager.default.isExecutableFile(atPath: $0) }
        }
        func report(_ route: String, _ turn: Int, _ text: String, _ note: String = "") {
            print("[\(route)] turn \(turn): \(text.replacingOccurrences(of: "\n", with: " ⏎ "))\(note.isEmpty ? "" : "  (\(note))")")
        }

        // Claude Code
        if let claude = locate("claude") {
            let env = KoncluiCLI.environment(base: ProcessInfo.processInfo.environment, executable: claude, home: home)
            let status = await KoncluiProcess.capture(claude, ["auth", "status", "--json"], environment: env, timeout: 15)
            print("[claude-code] login:", KoncluiCLI.parseClaudeLogin(output: status?.stdout ?? "", exitCode: status?.exitCode ?? -1))
            var session: String?
            for (turn, prompt) in [first, second].enumerated() {
                var stream = KoncluiClaudeStream()
                var code: Int32 = -1
                for await event in KoncluiProcess.stream(
                    claude, KoncluiClaudeCLI.arguments(model: "haiku", resume: session, systemPrompt: persona),
                    environment: env, directory: dir, input: Data(prompt.utf8), timeout: 120) {
                    switch event {
                    case .line(let line): stream.feed(line)
                    case .exit(let c, _, _): code = c
                    case .failedToStart: break
                    }
                }
                session = stream.sessionID
                report("claude-code", turn + 1, stream.text, "exit \(code), failure \(stream.failure ?? "none")")
                if stream.text.isEmpty || stream.failure != nil { failures += 1 }
                if turn == 1, !stream.text.uppercased().contains("PINEAPPLE") { failures += 1; print("[claude-code] thread NOT continued") }
            }
        } else { print("[claude-code] not installed"); failures += 1 }

        // Codex
        if let codex = locate("codex") {
            let env = KoncluiCLI.environment(base: ProcessInfo.processInfo.environment, executable: codex, home: home)
            let status = await KoncluiProcess.capture(codex, ["login", "status"], environment: env, timeout: 15)
            print("[codex] login:", KoncluiCLI.parseCodexLogin(output: (status?.stdout ?? "") + "\n" + (status?.stderr ?? ""), exitCode: status?.exitCode ?? -1))
            var thread: String?
            for (turn, prompt) in [persona + "\n\n" + first, second].enumerated() {
                var stream = KoncluiCodexStream()
                var code: Int32 = -1
                for await event in KoncluiProcess.stream(
                    codex, KoncluiCodexCLI.arguments(model: "default", resume: thread),
                    environment: env, directory: dir, input: Data(prompt.utf8), timeout: 180) {
                    switch event {
                    case .line(let line): stream.feed(line)
                    case .exit(let c, _, _): code = c
                    case .failedToStart: break
                    }
                }
                thread = stream.threadID
                report("codex", turn + 1, stream.text, "exit \(code), failure \(stream.failure ?? "none")")
                if stream.text.isEmpty || stream.failure != nil { failures += 1 }
                if turn == 1, !stream.text.uppercased().contains("PINEAPPLE") { failures += 1; print("[codex] thread NOT continued") }
            }
        } else { print("[codex] not installed"); failures += 1 }

        // Koncluí Proxy
        let launcher = home + "/.local/bin/klaude"
        if let script = try? String(contentsOfFile: launcher, encoding: .utf8),
           let base = KoncluiProxy.baseURL(fromLauncher: script) {
            print("[konclui-proxy] base:", base)
            let user = NSUserName()
            let has = await KoncluiProcess.capture("/usr/bin/security", ["find-generic-password", "-a", user, "-s", KoncluiProxy.keychainService], timeout: 10)
            print("[konclui-proxy] key item present:", has?.exitCode == 0)
            let read = await KoncluiProcess.capture("/usr/bin/security", ["find-generic-password", "-a", user, "-s", KoncluiProxy.keychainService, "-w"], timeout: 10)
            if let key = read?.stdout.trimmingCharacters(in: .whitespacesAndNewlines), read?.exitCode == 0, !key.isEmpty {
                if let list = modelsRequest(base, key) {
                    let (data, response) = (try? await URLSession.shared.data(for: list)) ?? (Data(), URLResponse())
                    let models = KoncluiProxy.parseModels(data)
                    print("[konclui-proxy] /v1/models: HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0), \(models.count) models, first: \(models.first?.id ?? "-")")
                    if models.isEmpty { failures += 1 }
                }
                var history: [[String: Any]] = []
                for (turn, prompt) in [first, second].enumerated() {
                    history.append(["role": "user", "content": [["type": "text", "text": prompt]]])
                    var text = ""
                    var note = ""
                    if let body = KoncluiProxy.messagesBody(model: "claude-haiku-5-5", system: persona, messages: history),
                       let request = KoncluiProxy.messagesRequest(base: base, token: key, body: body) {
                        do {
                            let (bytes, response) = try await URLSession.shared.bytes(for: request)
                            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                            note = "HTTP \(status)"
                            for try await line in bytes.lines {
                                if case .text(let piece) = KoncluiProxy.streamEvent(line: line) { text += piece }
                            }
                        } catch { note = "error: \(KoncluiProxy.redact(error.localizedDescription, token: key))" }
                    }
                    history.append(["role": "assistant", "content": text])
                    report("konclui-proxy", turn + 1, text, note)
                    if text.isEmpty { failures += 1 }
                    if turn == 1, !text.uppercased().contains("PINEAPPLE") { failures += 1; print("[konclui-proxy] conversation NOT continued") }
                }
            } else { print("[konclui-proxy] no key"); failures += 1 }
        } else { print("[konclui-proxy] klaude launcher not found"); failures += 1 }

        print(failures == 0 ? "KoncluiChatLive: all routes answered" : "KoncluiChatLive: \(failures) problem(s)")
        exit(failures == 0 ? 0 : 1)
    }

    static func modelsRequest(_ base: String, _ key: String) -> URLRequest? {
        KoncluiProxy.modelsRequest(base: base, token: key)
    }
}
