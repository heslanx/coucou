import Foundation

// MARK: - WakePhrase tests (pure functions, no concurrency)

@main
enum WakePhraseTests {

    static var failures = 0

    static func main() {
        // MARK: split — should match

        // Basic wake phrases (no command)
        checkMatch("ok koru",              WakePhrase.split("ok koru"),              cmd: "")
        checkMatch("OK KORU",              WakePhrase.split("OK KORU"),              cmd: "")
        checkMatch("okay koru",            WakePhrase.split("okay koru"),            cmd: "")
        checkMatch("ok coru",                WakePhrase.split("ok coru"),                cmd: "")
        checkMatch("ok ko ru",             WakePhrase.split("ok ko ru"),             cmd: "")
        checkMatch("hey koru",             WakePhrase.split("hey koru"),             cmd: "")
        checkMatch("Hey Koru",             WakePhrase.split("Hey Koru"),             cmd: "")

        // Command extracted from original text (casing/punctuation preserved)
        checkMatch("Okay, Koru, ajoute GitHub",
                   WakePhrase.split("Okay, Koru, ajoute GitHub"),             cmd: "ajoute GitHub")
        checkMatch("ok kourou add github",
                   WakePhrase.split("ok kourou add github"),                    cmd: "add github")
        checkMatch("ok koru ouvre figma",
                   WakePhrase.split("ok koru ouvre figma"),                   cmd: "ouvre figma")

        // Apostrophes, hyphens and accents preserved in command
        checkMatch("OK Koru, mets l'album de Daft Punk",
                   WakePhrase.split("OK Koru, mets l'album de Daft Punk"),   cmd: "mets l'album de Daft Punk")
        checkMatch("ok koru qu'est-ce que fait Claude ?",
                   WakePhrase.split("ok koru qu'est-ce que fait Claude ?"),  cmd: "qu'est-ce que fait Claude ?")

        // Wake anywhere in transcript (word-boundary search)
        checkMatch("euh ok koru mets de la musique",
                   WakePhrase.split("euh ok koru mets de la musique"),        cmd: "mets de la musique")
        checkMatch("la chanson dit ok koru",
                   WakePhrase.split("la chanson dit ok koru"),                cmd: "") // accepted false positive

        // LAST occurrence wins
        checkMatch("ok koru search ok koru play music",
                   WakePhrase.split("ok koru search ok koru play music"),   cmd: "play music")

        // Partial word-by-word delivery
        checkNoMatch("ok alone",             WakePhrase.split("ok"))
        checkMatch("ok koru partial",      WakePhrase.split("ok koru"),              cmd: "")
        checkMatch("ok koru with more",    WakePhrase.split("ok koru mets"),         cmd: "mets")

        // Koncluí: how the recognizer may write Koru
        checkMatch("ok Corú",                WakePhrase.split("ok Corú"),                cmd: "")
        checkMatch("OK Koroo add github",    WakePhrase.split("OK Koroo add github"),    cmd: "add github")
        checkMatch("hey Kourou",             WakePhrase.split("hey Kourou"),             cmd: "")
        checkMatch("ok co ru mets",          WakePhrase.split("ok co ru mets"),          cmd: "mets")

        // MARK: split — should NOT match
        checkNoMatch("standalone koru",    WakePhrase.split("koru"))
        checkNoMatch("standalone KORU",    WakePhrase.split("KORU"))
        checkNoMatch("partial koru ça va", WakePhrase.split("koru ça va"))
        checkNoMatch("koru comment",       WakePhrase.split("koru comment tu vas"))
        checkNoMatch("ok google",            WakePhrase.split("ok google"))
        checkNoMatch("hey siri",             WakePhrase.split("hey siri"))
        checkNoMatch("okkkk koru",         WakePhrase.split("okkkk koru"))
        // Koncluí runs next to the original app: that app's wake phrase does not wake it
        checkNoMatch("other app's phrase, ok",  WakePhrase.split("ok " + "cou" + "cou"))
        checkNoMatch("other app's phrase, hey", WakePhrase.split("hey " + "cou" + "cou"))
        checkNoMatch("empty",                WakePhrase.split(""))

        // Summary
        if failures == 0 { print("\n\(total)/\(total) tests passed.") }
        else { print("\n\(failures) test(s) FAILED."); exit(1) }
    }

    static var total = 0

    static func checkMatch(_ label: String, _ r: WakePhrase.SplitResult, cmd: String) {
        total += 1
        if !r.matched {
            print("✗  \(label) — expected match, got no match"); failures += 1; return
        }
        if r.command != cmd {
            print("✗  \(label) — matched ✓ but command \"\(r.command)\" ≠ \"\(cmd)\""); failures += 1; return
        }
        print("✓  \(label)")
    }

    static func checkNoMatch(_ label: String, _ r: WakePhrase.SplitResult) {
        total += 1
        if r.matched { print("✗  \(label) — expected no match, got matched (cmd: \"\(r.command)\")"); failures += 1 }
        else         { print("✓  \(label)") }
    }
}
