#if !APPSTORE
import Combine
import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// Koncluí: the live side of KoncluiClaudeAccess.swift (unit U3a). It reads what this Mac has (klaude, the Anthropic key,
// Apple Intelligence), picks the source for a feature, sends the call and, when it fails, tells the person once.
//
// The proxy token is klaude's. It is read from the Keychain when a call starts, lives in a local variable for that call and
// is never stored, logged or shown. A failure keeps its HTTP status and nothing else.
@MainActor
final class KoncluiClaudeLive: ObservableObject {
    static let shared = KoncluiClaudeLive()

    /// The last call of a feature that failed, until one of that feature succeeds. In memory only; the Settings pages show
    /// it under the switch it belongs to.
    struct Report: Equatable {
        let feature: KoncluiClaudeAccess.Feature
        let source: KoncluiClaudeAccess.Source
        let failure: KoncluiClaudeAccess.Failure
        let date: Date

        /// The sentence for the person, in their language.
        var message: String {
            String(localized: String.LocalizationValue(failure.messageKey(source: source, feature: feature)))
        }
    }

    @Published private(set) var failures: [KoncluiClaudeAccess.Feature: Report] = [:]

    private var streak = KoncluiClaudeAccess.Streak()
    private var lastCheck = Date.distantPast
    private var forwarding: AnyCancellable?

    private init() {
        // klaude is found a moment after launch: whoever shows the source (the Settings pages observe this object) redraws.
        forwarding = KoncluiVoiceBrainLive.shared.$proxyReady.removeDuplicates().dropFirst().sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        #if DEBUG
        // For screenshots: `-konclui.debug.claudeFail slow` (or refused, refused-key, limit, busy, offline, reply, none, apple)
        // shows that failure on the pill a moment after the first page reads the source (the Styles page does), with no call,
        // and keeps it under the switch of every feature on the Settings pages. `-konclui.debug.claudeSource none` (or proxy,
        // key, apple) pretends that is all this Mac has, to draw each state of the connect line.
        if let kind = UserDefaults.standard.string(forKey: "konclui.debug.claudeFail") {
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(1.5))
                self?.showSampleFailure(kind)
            }
        }
        #endif
    }

    #if DEBUG
    private func showSampleFailure(_ kind: String) {
        let samples: [String: (KoncluiClaudeAccess.Failure, KoncluiClaudeAccess.Source)] = [
            "refused": (.refused(status: 401), .proxy), "refused-key": (.refused(status: 401), .apiKey),
            "limit": (.limit, .proxy), "busy": (.busy(status: 529), .proxy), "offline": (.offline, .proxy),
            "slow": (.slow, .proxy), "reply": (.unusable, .proxy), "none": (.noSource, .none), "apple": (.apple, .apple),
        ]
        guard let (failure, source) = samples[kind] else { return }
        // Clean-up first: it is the one that tells on the pill; the others (same kind in a row) stay quiet.
        for feature in KoncluiClaudeAccess.Feature.allCases {
            record(failure, feature: feature, source: source)
        }
    }

    private static func debugInputs() -> KoncluiClaudeAccess.Inputs? {
        switch UserDefaults.standard.string(forKey: "konclui.debug.claudeSource") {
        case "none":  return .init(proxyAvailable: false, apiKeySaved: false, appleIntelligence: false)
        case "proxy": return .init(proxyAvailable: true, apiKeySaved: false, appleIntelligence: false)
        case "key":   return .init(proxyAvailable: false, apiKeySaved: true, appleIntelligence: false)
        case "apple": return .init(proxyAvailable: false, apiKeySaved: false, appleIntelligence: true)
        default:      return nil
        }
    }
    #endif

    func lastFailure(_ feature: KoncluiClaudeAccess.Feature) -> Report? { failures[feature] }

    // MARK: Which source

    func inputs() -> KoncluiClaudeAccess.Inputs {
        #if DEBUG
        if let forced = Self.debugInputs() { return forced }
        #endif
        return .init(proxyAvailable: KoncluiVoiceBrainLive.shared.proxyReady,
              apiKeySaved: !(KeychainStore.shared.get("anthropic-api-key") ?? "").isEmpty,
              appleIntelligence: KoncluiVoiceBrainLive.appleIntelligence() == .available)
    }

    /// Where this feature would be answered from now. Asking also refreshes the klaude check in the background (at most
    /// once a minute), so a klaude set up (or removed) while the app runs is noticed, as the voice brain does.
    func source(for feature: KoncluiClaudeAccess.Feature) -> KoncluiClaudeAccess.Source {
        refreshInBackground()
        return KoncluiClaudeAccess.source(for: feature, inputs())
    }

    /// Where Claude itself would come from (proxy, key or none), whatever Apple's model could do.
    func claudeSource() -> KoncluiClaudeAccess.Source {
        refreshInBackground()
        return KoncluiClaudeAccess.claudeSource(inputs())
    }

    private func refreshInBackground() {
        guard Date().timeIntervalSince(lastCheck) > 5 else { return }
        lastCheck = Date()
        Task { await KoncluiVoiceBrainLive.shared.refreshProxy(maxAge: 60) }
    }

    // MARK: What the interface says

    /// Where the words go and what a late answer does, for the source that would answer now. nil when there is none.
    func privacyLine(for feature: KoncluiClaudeAccess.Feature) -> String? {
        KoncluiClaudeAccess.privacyKey(source(for: feature)).map { String(localized: String.LocalizationValue($0)) }
    }

    /// What to connect for a feature that has no source now.
    func connectLine(for feature: KoncluiClaudeAccess.Feature) -> String {
        String(localized: String.LocalizationValue(KoncluiClaudeAccess.connectKey(for: feature)))
    }

    /// The Notetaker's sentence about where a transcript goes with the Claude engine.
    var notesDetail: String {
        String(localized: String.LocalizationValue(KoncluiClaudeAccess.notesDetailKey(claudeSource())))
    }

    // MARK: One call

    /// The text Claude (or this Mac's model, for what it does well) gave for a feature, or nil when none came. A nil has
    /// already been logged and kept in `failures`; dictation features also tell the person once on the pill.
    func complete(_ feature: KoncluiClaudeAccess.Feature, system: String, user: String, maxTokens: Int,
                  temperature: Double? = nil, timeout: TimeInterval) async -> String? {
        // Looking for klaude costs a Keychain query (about 0.3 s): paid here only while it is not known, never again on
        // the dictation's time. If it went away meanwhile, the call below finds no key and says so.
        if !KoncluiVoiceBrainLive.shared.proxyReady { await KoncluiVoiceBrainLive.shared.refreshProxy(maxAge: 60) }
        let source = KoncluiClaudeAccess.source(for: feature, inputs())
        let call = KoncluiClaudeAccess.Call(model: KoncluiClaudeAccess.fastModel, system: system, user: user,
                                            maxTokens: maxTokens, temperature: temperature, timeout: timeout)
        let outcome: KoncluiClaudeSender.Outcome
        switch source {
        case .proxy:
            outcome = await viaProxy(feature, call)
        case .apiKey:
            outcome = await viaKey(feature, call)
        case .apple:
            outcome = await Self.viaApple(system: system, user: user, timeout: timeout)
        case .none:
            outcome = .failed(.noSource)
        }
        switch outcome {
        case .text(let text):
            streak.succeeded()
            if failures[feature] != nil { failures[feature] = nil }
            return text
        case .failed(let failure):
            record(failure, feature: feature, source: source)
            return nil
        case .cancelled:
            return nil
        }
    }

    private func viaProxy(_ feature: KoncluiClaudeAccess.Feature,
                          _ call: KoncluiClaudeAccess.Call) async -> KoncluiClaudeSender.Outcome {
        guard let base = KoncluiProxyAccess.baseURL(), let token = await KoncluiProxyAccess.readKey() else {
            return .failed(.noSource)
        }
        let models = KoncluiClaudeAccess.models(for: feature, chosen: AppState.shared.koncluiProxyChatModel)
        return await KoncluiClaudeSender.send(call, models: models, route: .proxy(base: base, token: token))
    }

    private func viaKey(_ feature: KoncluiClaudeAccess.Feature,
                        _ call: KoncluiClaudeAccess.Call) async -> KoncluiClaudeSender.Outcome {
        guard let key = KeychainStore.shared.get("anthropic-api-key"), !key.isEmpty else { return .failed(.noSource) }
        let chosen = AppState.shared.claudeModel.isEmpty ? AppState.defaultClaudeModel : AppState.shared.claudeModel
        let models = KoncluiClaudeAccess.models(for: feature, chosen: chosen)
        return await KoncluiClaudeSender.send(call, models: models, route: .apiKey(key))
    }

    /// Apple's model on this Mac (macOS 26): a clean-up or a summary, within the same wait as Claude gets.
    nonisolated private static func viaApple(system: String, user: String,
                                             timeout: TimeInterval) async -> KoncluiClaudeSender.Outcome {
        #if canImport(FoundationModels)
        if #available(macOS 26, *) {
            guard SystemLanguageModel.default.availability == .available else { return .failed(.apple) }
            return await withTaskGroup(of: KoncluiClaudeSender.Outcome.self) { group in
                group.addTask {
                    do {
                        let session = LanguageModelSession(instructions: system)
                        let reply = try await session.respond(to: user, options: GenerationOptions(temperature: 0))
                        return reply.content.isEmpty ? .failed(.unusable) : .text(reply.content)
                    } catch is CancellationError {
                        return .cancelled
                    } catch {
                        return .failed(.apple)
                    }
                }
                group.addTask {
                    try? await Task.sleep(for: .seconds(timeout))
                    return .failed(.slow)
                }
                let first = await group.next() ?? .failed(.apple)
                group.cancelAll()
                return first
            }
        }
        #endif
        return .failed(.apple)
    }

    // MARK: When it fails

    private func record(_ failure: KoncluiClaudeAccess.Failure, feature: KoncluiClaudeAccess.Feature,
                        source: KoncluiClaudeAccess.Source) {
        appendAppLog("nb.log", KoncluiClaudeAccess.logLine(feature: feature, source: source, failure: failure))
        let report = Report(feature: feature, source: source, failure: failure, date: Date())
        failures[feature] = report
        // The notes of a call are written minutes later, with nobody waiting: only dictation tells on the pill.
        guard feature.waitsForAnswer, streak.shouldAnnounce(failure) else { return }
        let opensChat = failure.needsChat
        FlowDictation.shared.pill.announce(
            FlowAnnouncement(symbol: "exclamationmark.triangle.fill", tint: "#F5B83D", text: report.message,
                             action: opensChat ? String(localized: "hub.open-settings") : nil),
            for: 10) {
            if opensChat { Self.openChatForKey() }
        }
    }
}
#endif
