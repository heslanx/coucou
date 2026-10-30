#if !APPSTORE
import Foundation

// Koncluí: the Notetaker's speech as the app sees it. Which engine writes a call, whether Apple's language files
// are there (and their install, with progress), and the two calls the Notetaker makes (the words of a recording,
// the text of a live stretch). NoteTaker.swift and the Notetaker screens only ask this; Parakeet stays untouched.

@MainActor
final class KoncluiNoteSpeech: ObservableObject {
    static let shared = KoncluiNoteSpeech()

    @Published private(set) var readiness: KoncluiNoteSpeechReadiness = .unknown

    private var locale: Locale?
    private var preparing: Task<Void, Never>?
    private var looking = false

    private init() {}

    // MARK: - The choice

    /// Apple's speech can write here: macOS 26, a Mac that runs the transcriber, a language it can transcribe.
    static var appleSpeechAvailable: Bool {
        if #available(macOS 26, *) { return KoncluiAppleSpeech.isAvailable && shared.readiness.isOffered }
        return false
    }

    /// The engine for the next recording or transcript. Read by the gates, so it is cheap and never waits.
    static var engine: KoncluiNoteEngine {
        KoncluiNoteSpeechChoice.engine(parakeetReady: Parakeet.shared.isReady, appleSpeechAvailable: appleSpeechAvailable)
    }

    /// The live lines can start. With Parakeet always; with Apple's speech once its language is installed (the
    /// stretches wait in the recorder meanwhile, nothing is lost).
    static var canTranscribeLive: Bool {
        engine != .apple || shared.readiness.canTranscribe
    }

    // MARK: - Language files

    /// Looks at the Mac's language without installing anything: the Notetaker screen says what the first
    /// recording will do.
    func refresh() {
        guard #available(macOS 26, *), !looking, preparing == nil, readiness == .unknown || readiness == .missing,
              KoncluiAppleSpeech.isAvailable else { return }
        looking = true
        Task { @MainActor in
            defer { looking = false }
            let locale = await KoncluiAppleSpeech.locale()
            let installed = if let locale { await KoncluiAppleSpeech.isInstalled(locale) } else { false }
            // A recording started meanwhile and is installing: its state is the newer one.
            guard preparing == nil else { return }
            self.locale = locale
            readiness = locale == nil ? .unsupported : (installed ? .ready : .missing)
        }
    }

    /// Makes Apple's speech ready for a recording that starts: installs the language files when they are
    /// missing, with progress. Safe to call again; a failed install is tried again. Nothing happens while
    /// Parakeet is the engine (it never installs anything it will not use).
    func prepare() {
        guard #available(macOS 26, *), Self.engine == .apple, preparing == nil, readiness != .ready,
              readiness != .unsupported, KoncluiAppleSpeech.isAvailable else { return }
        preparing = Task { @MainActor in
            defer { preparing = nil }
            await install()
        }
    }

    @available(macOS 26, *)
    private func install() async {
        guard let locale = await KoncluiAppleSpeech.locale() else { readiness = .unsupported; return }
        self.locale = locale
        if await KoncluiAppleSpeech.isInstalled(locale) { readiness = .ready; return }
        readiness = .installing(0)
        do {
            try await KoncluiAppleSpeech.install(locale) { fraction in
                Task { @MainActor in KoncluiNoteSpeech.shared.report(fraction) }
            }
            readiness = .ready
            appendAppLog("nb.log", "[Notetaker] Apple speech ready for \(locale.identifier(.bcp47))")
        } catch {
            appendAppLog("nb.log", "[Notetaker] Apple speech could not install \(locale.identifier(.bcp47)): \(error.localizedDescription)")
            readiness = .failed(String(localized: "konclui.notes.speech.install-failed"))
        }
    }

    private func report(_ fraction: Double) {
        if case .installing(let shown) = readiness, fraction > shown { readiness = .installing(min(1, fraction)) }
    }

    /// The language, once the files are there; waits for an install in progress and fails with a message a
    /// person can act on.
    @available(macOS 26, *)
    private func readyLocale() async throws -> Locale {
        if readiness != .ready { prepare() }
        await preparing?.value
        switch readiness {
        case .ready:
            if let locale { return locale }
            throw KoncluiAppleSpeech.Failure.noLanguage
        case .failed(let message):
            throw NSError(domain: "Notetaker", code: 2, userInfo: [NSLocalizedDescriptionKey: message])
        default:
            throw KoncluiAppleSpeech.Failure.noLanguage
        }
    }

    // MARK: - What the Notetaker calls

    /// The words of a recording with their times, by Apple's speech (Parakeet reads its own, in NoteTaker).
    static func words(in url: URL) async throws -> [TimedWord] {
        guard #available(macOS 26, *) else {
            throw NSError(domain: "Notetaker", code: 3, userInfo: [NSLocalizedDescriptionKey: String(localized: "notes.error.models")])
        }
        let locale = try await shared.readyLocale()
        return try await KoncluiAppleSpeech.words(in: url, locale: locale)
    }

    /// The text of a live stretch (16 kHz mono samples), by the engine the Notetaker chose. Empty when Apple's
    /// speech is not ready yet.
    static func text(of samples: [Float]) async throws -> String {
        if Parakeet.shared.isReady { return try await Parakeet.shared.transcribe(samples) }
        guard #available(macOS 26, *), let locale = shared.locale, shared.readiness.canTranscribe else { return "" }
        return try await KoncluiAppleSpeech.text(of: samples, locale: locale)
    }
}
#endif
