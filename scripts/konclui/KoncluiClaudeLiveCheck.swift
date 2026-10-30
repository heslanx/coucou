import Foundation

// One live call through the Koncluí Proxy, for `scripts/konclui/claude-live-check.sh`. It compiles the real FlowCleanup.swift
// (its prompt, its reply handling), the real request builder and sender, and replaces only KoncluiClaudeLive (the app's
// live side, which needs the whole app) with a stand-in that does what its proxy route does: the proxy address from the
// klaude launcher, klaude's token read from the Keychain for this call, the fast model.
//
// The token lives in one local variable of one call. It is never printed, logged or stored: the only output is the
// words before and after, the source, the model and the time.

enum FlowStyle: String { case verbatim, natural, polished }

@MainActor
final class KoncluiClaudeLive {
    static let shared = KoncluiClaudeLive()
    var lastModels: [String] = []
    var lastSource = "none"
    var lastFailure: String?

    func claudeSource() -> KoncluiClaudeAccess.Source { launcherBase() == nil ? .none : .proxy }
    func source(for feature: KoncluiClaudeAccess.Feature) -> KoncluiClaudeAccess.Source { claudeSource() }

    func complete(_ feature: KoncluiClaudeAccess.Feature, system: String, user: String, maxTokens: Int,
                  temperature: Double? = nil, timeout: TimeInterval) async -> String? {
        guard let base = launcherBase(), let token = readToken() else { lastFailure = "no klaude"; return nil }
        let call = KoncluiClaudeAccess.Call(model: KoncluiClaudeAccess.fastModel, system: system, user: user,
                                            maxTokens: maxTokens, temperature: temperature, timeout: timeout)
        let models = KoncluiClaudeAccess.models(for: feature, chosen: "claude-sonnet-5-5")
        lastModels = models
        lastSource = "Koncluí Proxy (subscription)"
        switch await KoncluiClaudeSender.send(call, models: models, route: .proxy(base: base, token: token)) {
        case .text(let text):
            return text.contains(token) ? nil : text
        case .failed(let failure):
            lastFailure = failure.logText
            return nil
        case .cancelled:
            return nil
        }
    }

    private func launcherBase() -> String? {
        let path = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".local/bin/klaude").path
        guard let script = try? String(contentsOfFile: path, encoding: .utf8) else { return nil }
        return KoncluiProxy.baseURL(fromLauncher: script)
    }

    /// klaude's own Keychain item, read the way klaude and the app read it (`security ... -w`).
    private func readToken() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-a", NSUserName(), "-s", KoncluiProxy.keychainService, "-w"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        let token = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        return token.isEmpty ? nil : token
    }
}

@main
@MainActor
enum KoncluiClaudeLiveCheck {
    static func main() async {
        let spoken = CommandLine.arguments.dropFirst().first ?? "eh tipo assim né vamo testar"
        let started = Date()
        let cleaned = await FlowCleanup.clean(spoken, style: .natural, app: "Notes", words: [])
        let seconds = Date().timeIntervalSince(started)
        let live = KoncluiClaudeLive.shared
        print("source: \(live.lastSource)")
        print("models: \(live.lastModels.joined(separator: ", "))")
        print("before: \(spoken)")
        print("after:  \(cleaned)")
        print(String(format: "time:   %.2f s (timeout %.0f s)", seconds, FlowCleanup.timeout))
        if let failure = live.lastFailure {
            print("FAILED: \(failure)")
            exit(1)
        }
        if cleaned == spoken {
            print("FAILED: the words came back unchanged")
            exit(1)
        }
        print("OK")
    }
}
