import Foundation

// Which speech engine writes a call (App/KoncluiNoteSpeechChoice.swift) and how the pieces a recognizer reports become the
// words a transcript is built from. Pure: no Speech framework, no Parakeet, no audio.

@main
enum KoncluiNoteSpeechTests {

    nonisolated(unsafe) static var failures = 0

    static func check(_ label: String, _ got: Bool) {
        if got { print("  ✓ \(label)") }
        else   { print("  ✗ \(label)"); failures += 1 }
    }

    static func piece(_ text: String, _ start: Double, _ end: Double) -> KoncluiNoteSpeechWords.Piece {
        .init(text: text, start: start, end: end)
    }

    static func near(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 0.0001 }

    static func main() {
        print("Engine choice: every (Parakeet installed, Apple speech available)")
        let table: [(parakeet: Bool, apple: Bool, engine: KoncluiNoteEngine)] = [
            (true, true, .parakeet), (true, false, .parakeet), (false, true, .apple), (false, false, .needsDownload),
        ]
        for row in table {
            let got = KoncluiNoteSpeechChoice.engine(parakeetReady: row.parakeet, appleSpeechAvailable: row.apple)
            check("parakeet \(row.parakeet), apple \(row.apple) -> \(row.engine)", got == row.engine)
        }

        print("Gates: the pill's button, Start and the relaunch that writes pending calls")
        check("Parakeet installed: open", KoncluiNoteSpeechChoice.gateMessageKey(.parakeet) == nil)
        check("Apple speech: open, no download asked", KoncluiNoteSpeechChoice.gateMessageKey(.apple) == nil)
        check("neither: closed with the download message", KoncluiNoteSpeechChoice.gateMessageKey(.needsDownload) == "notes.error.models")

        print("Diarizer: only with Parakeet's models")
        check("Parakeet tells the voices apart", KoncluiNoteSpeechChoice.tellsVoicesApart(.parakeet))
        check("Apple speech keeps the others as one speaker", !KoncluiNoteSpeechChoice.tellsVoicesApart(.apple))
        check("nothing records, nothing to tell apart", !KoncluiNoteSpeechChoice.tellsVoicesApart(.needsDownload))

        print("The Mac's language files")
        check("not looked at yet: offered, so Record never waits", KoncluiNoteSpeechReadiness.unknown.isOffered)
        check("missing: offered, installs at the first recording", KoncluiNoteSpeechReadiness.missing.isOffered)
        check("installing: offered", KoncluiNoteSpeechReadiness.installing(0.4).isOffered)
        check("failed: offered (it can be tried again)", KoncluiNoteSpeechReadiness.failed("x").isOffered)
        check("unsupported language: not offered", !KoncluiNoteSpeechReadiness.unsupported.isOffered)
        check("only ready writes live lines", KoncluiNoteSpeechReadiness.ready.canTranscribe
              && !KoncluiNoteSpeechReadiness.unknown.canTranscribe && !KoncluiNoteSpeechReadiness.missing.canTranscribe
              && !KoncluiNoteSpeechReadiness.installing(1).canTranscribe && !KoncluiNoteSpeechReadiness.failed("x").canTranscribe
              && !KoncluiNoteSpeechReadiness.unsupported.canTranscribe)

        print("Words from the recognizer's pieces")
        let plain = KoncluiNoteSpeechWords.words(from: [piece("Olá", 0, 0.42), piece("pessoal", 0.42, 1.44)])
        check("one word per piece keeps its times", plain.map(\.text) == ["Olá", "pessoal"]
              && near(plain[0].start, 0) && near(plain[0].end, 0.42) && near(plain[1].start, 0.42) && near(plain[1].end, 1.44))

        let phrase = KoncluiNoteSpeechWords.words(from: [piece("hello big world", 10, 13)])
        check("a phrase is cut at its spaces", phrase.map(\.text) == ["hello", "big", "world"])
        check("the time is shared by length and stays inside the phrase",
              near(phrase[0].start, 10) && near(phrase[2].end, 13) && near(phrase[0].end, phrase[1].start)
              && near(phrase[1].end, phrase[2].start) && phrase[0].end - phrase[0].start > phrase[1].end - phrase[1].start)

        let comma = KoncluiNoteSpeechWords.words(from: [piece("pessoal", 0, 1), piece(",", 1, 1), piece("hoje", 1.2, 1.6), piece("…", 1.6, 1.6)])
        check("punctuation alone sticks to the word before", comma.map(\.text) == ["pessoal,", "hoje…"])
        check("punctuation adds no word and moves no time", comma.count == 2 && near(comma[0].end, 1) && near(comma[1].end, 1.6))

        let first = KoncluiNoteSpeechWords.words(from: [piece("—", 0, 0.1), piece("ok", 0.1, 0.4)])
        check("punctuation with no word before it is dropped", first.map(\.text) == ["ok"])

        let spoken = KoncluiNoteSpeechWords.words(from: [piece("two", 2, 3), piece("one", 0, 1)])
        check("words come out in the order they were said", spoken.map(\.text) == ["one", "two"])

        check("empty and blank pieces give nothing", KoncluiNoteSpeechWords.words(from: [piece("", 0, 1), piece("  \n ", 1, 2)]).isEmpty)
        check("no pieces, no words", KoncluiNoteSpeechWords.words(from: []).isEmpty)

        let backwards = KoncluiNoteSpeechWords.words(from: [piece("odd", 5, 4)])
        check("an end before the start never makes a negative word", backwards.count == 1 && backwards[0].end >= backwards[0].start)

        let numbers = KoncluiNoteSpeechWords.words(from: [piece("R$", 0, 0.2), piece("1.500,00", 0.2, 1)])
        check("numbers and symbols with a digit or letter stay words", numbers.map(\.text) == ["R$", "1.500,00"])

        check("a live stretch is one tidy line", KoncluiNoteSpeechWords.line(from: ["Olá  pessoal,", " hoje\n", "sim."]) == "Olá pessoal, hoje sim.")
        check("a silent stretch is an empty line", KoncluiNoteSpeechWords.line(from: []).isEmpty && KoncluiNoteSpeechWords.line(from: ["  "]).isEmpty)

        print(failures == 0 ? "\nAll passed." : "\n\(failures) failed.")
        exit(failures == 0 ? 0 : 1)
    }
}
