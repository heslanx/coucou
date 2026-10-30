#if !APPSTORE
import AVFoundation
import CoreMedia
import Foundation
import Speech

// Koncluí: the Notetaker's speech on a Mac with no Parakeet download. Apple's on-device SpeechAnalyzer and
// SpeechTranscriber (macOS 26); the language files are the system's own, installed through AssetInventory.
// Nothing here knows Parakeet, AppKit or the screens: the glue is KoncluiNoteSpeechState.swift, the choice
// is KoncluiNoteSpeechChoice.swift.

@available(macOS 26, *)
enum KoncluiAppleSpeech {
    enum Failure: LocalizedError {
        case noLanguage
        case unreadable

        var errorDescription: String? {
            switch self {
            case .noLanguage: return String(localized: "konclui.notes.speech.unsupported")
            case .unreadable: return String(localized: "konclui.notes.speech.unreadable")
            }
        }
    }

    /// This Mac can run the transcriber at all (the language is checked apart, by `locale()`).
    static var isAvailable: Bool { SpeechTranscriber.isAvailable }

    /// The Mac's language, or English when the Mac's is not supported; nil when neither is.
    static func locale() async -> Locale? {
        for candidate in [Locale.current, Locale(identifier: "en-US")] {
            if let supported = await SpeechTranscriber.supportedLocale(equivalentTo: candidate) { return supported }
        }
        return nil
    }

    private static func transcriber(_ locale: Locale) -> SpeechTranscriber {
        SpeechTranscriber(locale: locale, transcriptionOptions: [], reportingOptions: [], attributeOptions: [.audioTimeRange])
    }

    /// The language's files are on this Mac. (`AssetInventory.status` says "supported" for a language that is
    /// installed and works, so the installed list is the one to ask.)
    static func isInstalled(_ locale: Locale) async -> Bool {
        await SpeechTranscriber.installedLocales.contains { $0.identifier(.bcp47) == locale.identifier(.bcp47) }
    }

    /// Installs the language's files (small, the Mac's own), reporting the share done. Returns at once when
    /// they are there.
    static func install(_ locale: Locale, progress: @escaping @Sendable (Double) -> Void) async throws {
        let module = transcriber(locale)
        guard let request = try await AssetInventory.assetInstallationRequest(supporting: [module]) else { return }
        let watcher = Task {
            while !Task.isCancelled {
                progress(request.progress.fractionCompleted)
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
        defer { watcher.cancel() }
        try await request.downloadAndInstall()
        progress(1)
    }

    // MARK: - Transcribing

    /// The words of a 16 kHz recording, with their times in it.
    static func words(in url: URL, locale: Locale) async throws -> [TimedWord] {
        let module = transcriber(locale)
        let analyzer = SpeechAnalyzer(modules: [module], options: Self.options)
        let results = collect(module)
        do {
            let file = try AVAudioFile(forReading: url)
            if let last = try await analyzer.analyzeSequence(from: file) {
                try await analyzer.finalizeAndFinish(through: last)
            } else {
                await analyzer.cancelAndFinishNow()
            }
        } catch {
            await analyzer.cancelAndFinishNow()
            results.cancel()
            throw error
        }
        return KoncluiNoteSpeechWords.words(from: try await results.value.pieces)
    }

    /// 16 kHz mono samples (a stretch of a live call) to text.
    static func text(of samples: [Float], locale: Locale) async throws -> String {
        let module = transcriber(locale)
        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [module]),
              let buffer = buffer(samples, as: format) else { throw Failure.unreadable }
        let analyzer = SpeechAnalyzer(modules: [module], options: Self.options)
        let results = collect(module)
        let (input, feed) = AsyncStream.makeStream(of: AnalyzerInput.self)
        feed.yield(AnalyzerInput(buffer: buffer))
        feed.finish()
        do {
            if let last = try await analyzer.analyzeSequence(input) {
                try await analyzer.finalizeAndFinish(through: last)
            } else {
                await analyzer.cancelAndFinishNow()
            }
        } catch {
            await analyzer.cancelAndFinishNow()
            results.cancel()
            throw error
        }
        return KoncluiNoteSpeechWords.line(from: try await results.value.texts)
    }

    /// The model stays loaded a little after each stretch, so a live call does not reload it every few seconds.
    private static let options = SpeechAnalyzer.Options(priority: .userInitiated, modelRetention: .lingering)

    private struct Heard: Sendable {
        var pieces: [KoncluiNoteSpeechWords.Piece] = []
        var texts: [String] = []
    }

    private static func collect(_ module: SpeechTranscriber) -> Task<Heard, Error> {
        Task {
            var heard = Heard()
            for try await result in module.results {
                heard.texts.append(String(result.text.characters))
                for run in result.text.runs {
                    guard let range = run.audioTimeRange else { continue }
                    heard.pieces.append(.init(text: String(result.text[run.range].characters),
                                              start: range.start.seconds, end: range.end.seconds))
                }
            }
            return heard
        }
    }

    /// Samples as the analyzer wants them (its best format is usually 16 kHz Int16, so a conversion is rare).
    private static func buffer(_ samples: [Float], as format: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard let recorded = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false),
              let source = AVAudioPCMBuffer(pcmFormat: recorded, frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = source.floatChannelData?[0] else { return nil }
        source.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { channel.update(from: $0.baseAddress!, count: samples.count) }
        if format == source.format { return source }
        guard let converter = AVAudioConverter(from: source.format, to: format) else { return nil }
        let capacity = AVAudioFrameCount(Double(samples.count) * format.sampleRate / source.format.sampleRate) + 64
        guard let out = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return nil }
        nonisolated(unsafe) var fed = false
        nonisolated(unsafe) let input = source
        var error: NSError?
        let status = converter.convert(to: out, error: &error) { _, inputStatus in
            if fed { inputStatus.pointee = .endOfStream; return nil }
            fed = true
            inputStatus.pointee = .haveData
            return input
        }
        return status == .error ? nil : out
    }
}
#endif
