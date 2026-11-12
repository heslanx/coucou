import Foundation

// Koncluí: the languages "OK Koru" listens in and answers in (unit U5).
//
// Upstream speaks two languages through a Bool (`french`, `answersFrench`) and a two-argument helper `t(fr, en)`. Koncluí
// adds Brazilian Portuguese without touching those call sites: `t` now takes `VoiceText`, which remembers the English
// sentence with its blanks, and Portuguese is looked up by that sentence in KoncluiVoicePhrases.swift. French and English
// render exactly the text written at the call site.
//
// Pure Foundation: compiled by the voice test scripts with swiftc alone.

// MARK: - VoiceLanguage

/// A language Koru can answer in. Anything that is not French or Portuguese is English, like upstream's two-way switch.
enum VoiceLanguage: String, CaseIterable, Sendable {
    case en, fr, pt

    /// "fr", "fr-FR", "pt_BR", "pt" → the language. nil and unknown codes are English.
    init(code: String?) {
        let base = (code ?? "").lowercased()
            .split(whereSeparator: { $0 == "-" || $0 == "_" }).first.map(String.init) ?? ""
        self = VoiceLanguage(rawValue: base) ?? .en
    }

    init(locale: Locale?) {
        self.init(code: locale?.language.languageCode?.identifier)
    }

    /// The Mac's own language when Koru speaks it, else English. Used until the person picks one in Settings → Voice.
    static func macDefault(preferredLanguages: [String] = Locale.preferredLanguages) -> VoiceLanguage {
        guard let first = preferredLanguages.first else { return .en }
        return VoiceLanguage(code: first)
    }

    /// The locale of spoken answers: the Mac voice, the number and date formats, the Open-Meteo place names.
    var locale: Locale {
        switch self {
        case .en: return Locale(identifier: "en-US")
        case .fr: return Locale(identifier: "fr-FR")
        case .pt: return Locale(identifier: "pt-BR")
        }
    }

    /// How the model prompts name the language.
    var promptName: String {
        switch self {
        case .en: return "English"
        case .fr: return "French"
        case .pt: return "Brazilian Portuguese"
        }
    }

    /// The recognizers to try, in order, when the person picked this language to speak in Settings → Voice.
    var listenLocaleIdentifiers: [String] {
        switch self {
        case .en: return ["en-US", "en-GB", "en-AU"]
        case .fr: return ["fr-FR", "fr-CA"]
        case .pt: return ["pt-BR", "pt-PT"]
        }
    }

    /// The Settings → Voice sample sentence.
    var sample: String {
        switch self {
        case .en: return "Hi, I'm Koncluí. Say OK Koru whenever you need me."
        case .fr: return "Salut, c'est Koncluí. Dis OK Koru quand tu as besoin de moi."
        case .pt: return "Oi, aqui é Koncluí. Diga OK Koru sempre que precisar de mim."
        }
    }
}

// MARK: - VoiceText

/// A sentence as written at a `t(fr, en)` call site: its literal text with a blank for each `\( )`, and the values that
/// filled them. French and English render as written; Portuguese is found by the English template.
struct VoiceText: ExpressibleByStringInterpolation, Sendable {
    /// The literal text; every interpolation is "{}".
    let template: String
    let arguments: [String]

    init(stringLiteral value: String) {
        template = value
        arguments = []
    }

    init(stringInterpolation: StringInterpolation) {
        template = stringInterpolation.template
        arguments = stringInterpolation.arguments
    }

    struct StringInterpolation: StringInterpolationProtocol {
        var template = ""
        var arguments: [String] = []

        init(literalCapacity: Int, interpolationCount: Int) {
            template.reserveCapacity(literalCapacity)
            arguments.reserveCapacity(interpolationCount)
        }

        mutating func appendLiteral(_ literal: String) {
            template += literal
        }

        mutating func appendInterpolation<T>(_ value: T) {
            template += "{}"
            arguments.append("\(value)")
        }
    }

    /// The text as written: the blanks filled in order.
    var rendered: String {
        var out = ""
        var next = arguments.makeIterator()
        var rest = Substring(template)
        while let blank = rest.range(of: "{}") {
            out += rest[..<blank.lowerBound]
            out += next.next() ?? "{}"
            rest = rest[blank.upperBound...]
        }
        return out + rest
    }
}

/// `t(fr, en)` for any answer language: the text written at the call site, or its Portuguese sentence. A sentence that
/// has no Portuguese yet is said in English (scripts/konclui/voice-pt-templates.py --check lists those).
func voiceSay(_ language: VoiceLanguage, _ fr: VoiceText, _ en: VoiceText) -> String {
    switch language {
    case .fr: return fr.rendered
    case .en: return en.rendered
    case .pt: return KoncluiVoicePhrases.portuguese(en) ?? en.rendered
    }
}

// MARK: - Offering a language

/// "Want me to answer in French?": asked once when the person speaks another language than Koru answers in, and the
/// answers to it. The four French and English texts are upstream's, word for word.
enum VoiceLanguageSwitch {
    static func offer(to target: VoiceLanguage, currently current: VoiceLanguage) -> String {
        switch (target, current) {
        case (.fr, .fr): return "Tu veux que je te réponde en français ?"
        case (.fr, .pt): return "Aliás, você está falando francês. Quer que eu responda em francês?"
        case (.fr, _):   return "By the way, you're speaking French. Want me to answer in French?"
        case (.pt, .fr): return "Au fait, tu me parles en portugais. Tu veux que je te réponde en portugais ?"
        case (.pt, .pt): return "Quer que eu responda em português?"
        case (.pt, _):   return "By the way, you're speaking Portuguese. Want me to answer in Portuguese?"
        case (.en, .fr): return "Au fait, tu me parles en anglais. Tu veux que je te réponde en anglais ?"
        case (.en, .pt): return "Aliás, você está falando inglês. Quer que eu responda em inglês?"
        case (.en, _):   return "Want me to answer in English?"
        }
    }

    /// Said in the new language, right after "yes".
    static func switched(to target: VoiceLanguage) -> String {
        switch target {
        case .fr: return "D'accord, je te réponds en français maintenant."
        case .pt: return "Combinado, a partir de agora eu respondo em português."
        case .en: return "Sure, I'll answer in English from now on."
        }
    }

    /// Said in the current language, right after "no".
    static func kept(_ current: VoiceLanguage) -> String {
        switch current {
        case .fr: return "OK, je continue en français."
        case .pt: return "Tudo bem, continuo respondendo em português."
        case .en: return "Okay, I'll keep answering in English."
        }
    }
}

// MARK: - The Mac voice for a language

/// Which installed Mac voice speaks an answer. Upstream ranks by quality, then region (an Ava Premium beats a compact US
/// voice). Portuguese ranks the region first: a premium voice from Portugal must not read Brazilian answers. Between
/// equals, Luciana and Felipe (the Brazilian system voices) win.
enum KoncluiVoicePick {
    static func rank(language: String, quality: Int, exactRegion: Bool, name: String) -> (Int, Int, Int) {
        let region = exactRegion ? 1 : 0
        guard language == "pt" else { return (quality, region, 0) }
        let first = name.split(whereSeparator: { $0 == " " || $0 == "(" }).first.map(String.init) ?? name
        let brazilian = ["luciana", "felipe"].contains(first.lowercased()) ? 1 : 0
        return (region, quality, brazilian)
    }
}
