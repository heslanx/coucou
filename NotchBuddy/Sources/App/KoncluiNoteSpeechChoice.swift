#if !APPSTORE
import Foundation

// Koncluí: which speech engine writes a call (Notetaker). Pure: no Speech, no AppKit, no singleton, so
// scripts/konclui/test-note-speech.sh compiles it with swiftc alone. The Speech side is KoncluiNoteSpeech.swift,
// the Parakeet and screen glue is KoncluiNoteSpeechState.swift.

/// The engine that transcribes a call.
enum KoncluiNoteEngine: Equatable, Sendable {
    /// Parakeet and the speaker diarizer, installed: the call is written person by person, as in Coucou.
    case parakeet
    /// Apple's on-device speech (macOS 26): no download. The others in the call stay one voice.
    case apple
    /// Neither is there: the person downloads Parakeet first (Intel Mac or macOS before 26).
    case needsDownload
}

enum KoncluiNoteSpeechChoice {
    /// Recording never requires a download when the Mac has Apple's speech. Parakeet, once installed, is always
    /// used (it is the more accurate one and the only one that tells the people of a call apart).
    static func engine(parakeetReady: Bool, appleSpeechAvailable: Bool) -> KoncluiNoteEngine {
        if parakeetReady { return .parakeet }
        return appleSpeechAvailable ? .apple : .needsDownload
    }

    /// What the gates (the pill's button, Start, the relaunch that writes pending calls) say when they stop a
    /// recording: the key of the message, nil when the gate is open.
    static func gateMessageKey(_ engine: KoncluiNoteEngine) -> String? {
        engine == .needsDownload ? "notes.error.models" : nil
    }

    /// Only Parakeet's models include the diarizer. Without it the others' side is one speaker.
    static func tellsVoicesApart(_ engine: KoncluiNoteEngine) -> Bool {
        engine == .parakeet
    }
}

/// How far the Mac's own speech is from being able to write: its language may need a small install.
enum KoncluiNoteSpeechReadiness: Equatable, Sendable {
    /// Not looked at yet: treated as available, so the Record button never waits for it.
    case unknown
    case ready
    /// The Mac's language files are not installed: the first recording installs them.
    case missing
    /// The Mac's language files are being installed (0...1).
    case installing(Double)
    /// Neither the Mac's language nor English can be transcribed here.
    case unsupported
    case failed(String)

    /// Apple's speech may be offered: everything but a language that cannot be transcribed at all.
    var isOffered: Bool { self != .unsupported }

    /// The live lines can start (the recording itself never waits for this).
    var canTranscribe: Bool { self == .ready }
}

/// Words from the pieces of text a recognizer reports with their place in the audio.
enum KoncluiNoteSpeechWords {
    struct Piece: Equatable, Sendable {
        var text: String
        var start: Double
        var end: Double
    }

    /// A piece may be a word, a word with its punctuation, or a phrase. The transcript wants words, so a phrase
    /// is cut at its spaces with the time shared by length, and punctuation alone sticks to the word before it.
    static func words(from pieces: [Piece]) -> [TimedWord] {
        var out: [TimedWord] = []
        for piece in pieces.sorted(by: { $0.start < $1.start }) {
            let tokens = piece.text.split(whereSeparator: \.isWhitespace).map(String.init)
            guard !tokens.isEmpty else { continue }
            let start = piece.start, end = max(piece.start, piece.end)
            let total = Double(tokens.reduce(0) { $0 + $1.count })
            var cursor = start
            for token in tokens {
                let share = total > 0 ? (end - start) * Double(token.count) / total : 0
                defer { cursor += share }
                if !hasWordCharacter(token) {
                    if !out.isEmpty { out[out.count - 1].text += token }
                    continue
                }
                out.append(TimedWord(text: token, start: cursor, end: cursor + share))
            }
        }
        return out
    }

    /// The text of a live chunk: the reported pieces in one line, spaces tidied.
    static func line(from texts: [String]) -> String {
        texts.joined(separator: " ").split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private static func hasWordCharacter(_ token: String) -> Bool {
        token.contains { $0.isLetter || $0.isNumber }
    }
}
#endif
