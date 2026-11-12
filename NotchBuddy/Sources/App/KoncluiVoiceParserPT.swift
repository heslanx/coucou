import Foundation

// Koncluí: "OK Koru" understands Brazilian Portuguese (unit U5).
//
// Upstream's IntentParser reads French and English phrases with the same tables, whatever language is set. This file is
// the Portuguese side of it: the same intents (VoiceIntent) for natural Brazilian phrasings, behind one hook in
// IntentParser.parse and one in parseMultiAction. It answers nil unless a Portuguese word of its own (a verb such as
// "adiciona", "tira", "toca", a question word such as "quantas") is there, so French and English phrases reach upstream's
// parser exactly as before. Accents never matter: everything goes through IntentParser.normalise.
//
// Also here: the Portuguese lead-ins the guided e-mail strips from an answer ("é o Tana", "o assunto é…"), used by hooks in
// VoiceQuery. Pure Foundation (no AppKit, no state), compiled by the voice test scripts with swiftc alone.

enum KoncluiVoicePT {

    // MARK: Parsing

    /// The intent of a Portuguese phrase, nil when it is not one (the caller goes on with French and English).
    static func parse(_ raw: String, pills: [PillDefinition]) -> VoiceIntent? {
        let all = words(raw)
        // No Portuguese word, no Portuguese phrase: French and English go to upstream untouched.
        guard isPortuguese(all.n) else { return nil }
        let asks = raw.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("?")

        if let query = webQuery(raw) { return .webSearch(query: query) }
        if let request = mail(raw, all) { return .mail(request) }
        if let topic = topic(all.n, asks: asks) { return .query(topic) }

        let f = clean(all)
        guard !f.n.isEmpty else { return nil }
        if let app = appToOpen(f) { return .openApp(name: app) }
        if let volume = setVolume(f.n) { return .musicSetVolume(volume) }
        if let transport = transport(f.n) { return transport }
        if let pill = pillCommand(f, pills: pills) { return pill }
        return playCommand(f, pills: pills)
    }

    /// Several commands in one sentence: "pausa a música e adiciona o GitHub". nil unless two or more pieces each make a
    /// Portuguese command on their own.
    static func parseMulti(_ raw: String, pills: [PillDefinition]) -> [VoiceIntent]? {
        guard isPortuguese(words(raw).n), hasPortugueseVerb(words(raw).n) else { return nil }
        let commaParts = raw.split(whereSeparator: { $0 == "," || $0 == ";" })
            .map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        var intents: [VoiceIntent] = []
        for part in commaParts.flatMap({ splitOnVerbs($0) }) {
            let pieces = splitOnJoiners(part)
            let each = pieces.map { parse($0, pills: pills) }
            if pieces.count >= 2, each.allSatisfy(isCommand) {
                intents.append(contentsOf: each.compactMap { $0 })
                continue
            }
            guard let whole = parse(part, pills: pills), isCommand(whole) else { return nil }
            intents.append(whole)
        }
        return intents.count >= 2 ? intents : nil
    }

    // MARK: Words

    /// A phrase as parallel arrays: normalised words (no accents, no punctuation) and the words as said.
    struct Words {
        var n: [String]
        var r: [String]

        var isEmpty: Bool { n.isEmpty }
        func dropping(_ k: Int) -> Words { Words(n: Array(n.dropFirst(k)), r: Array(r.dropFirst(k))) }
        func slice(_ range: Range<Int>) -> Words { Words(n: Array(n[range]), r: Array(r[range])) }
    }

    static func words(_ raw: String) -> Words {
        var n = IntentParser.normalise(raw).split(separator: " ").map(String.init)
        var r = VoiceQuery.rawWords(raw)
        if r.count != n.count { r = n }
        // "e-mail" splits into "e", "mail" in the normaliser; "pra" is "para", "pro" is "para o".
        var outN: [String] = [], outR: [String] = []
        var i = 0
        while i < n.count {
            let w = n[i]
            if w == "e", i + 1 < n.count, n[i + 1] == "mail" || n[i + 1] == "mails" {
                outN.append(n[i + 1] == "mail" ? "email" : "emails"); outR.append("e-mail"); i += 2; continue
            }
            switch w {
            case "pra":  outN.append("para"); outR.append(r[i])
            case "pro":  outN += ["para", "o"]; outR += [r[i], r[i]]
            case "pras": outN += ["para", "as"]; outR += [r[i], r[i]]
            case "pros": outN += ["para", "os"]; outR += [r[i], r[i]]
            case "vc":   outN.append("voce"); outR.append(r[i])
            default:     outN.append(w); outR.append(r[i])
            }
            i += 1
        }
        n = outN; r = outR
        return Words(n: n, r: r)
    }

    private static let interjections: Set<String> = [
        "ok", "okay", "entao", "ta", "beleza", "olha", "bom", "bem", "ei", "opa", "ah", "hum", "tipo", "agora", "ne",
        "valeu", "obrigado", "obrigada", "pois", "bora", "vamos",
    ]

    private static let politePrefixes: [[String]] = [
        ["eu", "gostaria", "de", "que", "voce"], ["gostaria", "de", "que", "voce"], ["eu", "queria", "que", "voce"],
        ["queria", "que", "voce"], ["eu", "quero", "que", "voce"], ["quero", "que", "voce"],
        ["eu", "preciso", "que", "voce"], ["preciso", "que", "voce"],
        ["voce", "poderia"], ["voce", "pode"], ["voce", "consegue"], ["pode", "voce"], ["poderia", "voce"],
        ["da", "para", "voce"], ["da", "para"], ["tem", "como"], ["faz", "favor", "de"], ["faca", "o", "favor", "de"],
        ["por", "favor"], ["eu", "gostaria", "de"], ["gostaria", "de"], ["eu", "queria"], ["queria"],
        ["eu", "quero"], ["quero"], ["consegue"], ["poderia"], ["pode"],
    ]

    private static let trailingNoise: [[String]] = [
        ["por", "favor"], ["pfv"], ["pf"], ["valeu"], ["obrigado"], ["obrigada"], ["agora"], ["ai"], ["ja"],
        ["para", "mim"], ["pra", "mim"],
    ]

    /// The words of the command itself: interjections, politeness and the trailing "por favor" taken off.
    private static func clean(_ all: Words) -> Words {
        var w = all
        var changed = true
        while changed, !w.isEmpty {
            changed = false
            if let first = w.n.first, interjections.contains(first), w.n.count > 1 { w = w.dropping(1); changed = true; continue }
            for prefix in politePrefixes where w.n.count > prefix.count && Array(w.n.prefix(prefix.count)) == prefix {
                w = w.dropping(prefix.count); changed = true; break
            }
            if !changed, w.n.first == "me", w.n.count > 1, verbs.contains(w.n[1]) { w = w.dropping(1); changed = true }
            for tail in trailingNoise where w.n.count > tail.count && Array(w.n.suffix(tail.count)) == tail {
                w = w.slice(0..<(w.n.count - tail.count)); changed = true; break
            }
        }
        return w
    }

    // MARK: Verbs

    private static let addVerbs: Set<String> = ["adiciona", "adicione", "adicionar", "acrescenta", "acrescente", "inclui",
                                                "inclua", "ativa", "ative", "ativar", "mostra", "mostre", "exibe", "exiba"]
    private static let removeVerbs: Set<String> = ["remove", "remova", "remover", "tira", "tire", "tirar", "retira",
                                                   "retirar", "apaga", "apague", "exclui", "exclua", "esconde", "esconda",
                                                   "oculta", "oculte", "desativa", "desative", "desativar", "desliga",
                                                   "desligue"]
    private static let replaceVerbs: Set<String> = ["troca", "troque", "trocar", "substitui", "substitua", "substituir"]
    private static let keepVerbs: Set<String> = ["deixa", "deixe", "deixar", "mantem", "mantenha", "manter", "fica", "fique"]
    private static let putVerbs: Set<String> = ["poe", "ponha", "liga", "ligue", "coloca", "coloque", "colocar", "bota", "bote", "botar"]
    private static let playVerbs: Set<String> = ["toca", "toque", "tocar", "reproduz", "reproduza", "reproduzir", "ouvir",
                                                 "escutar", "escuta", "escute"]
    private static let resumeVerbs: Set<String> = ["continua", "continuar", "retoma", "retome", "retomar"]
    private static let otherVerbs: Set<String> = ["abre", "abra", "abrir", "manda", "mande", "mandar", "envia", "envie",
                                                  "enviar", "escreve", "escreva", "escrever", "pausa", "pausar",
                                                  "pare", "parar", "pula", "pule", "pular", "aumenta", "aumente", "sobe",
                                                  "suba", "abaixa", "abaixe", "diminui", "diminua", "baixa", "baixe",
                                                  "muda", "mude", "passa", "usa", "usar", "define",
                                                  "defina", "avanca", "avance", "volta", "volte", "pesquisa", "pesquise",
                                                  "procura", "procure"]

    /// Every Portuguese action verb: they decide that a phrase is a command, not a question.
    private static let verbs: Set<String> = addVerbs.union(removeVerbs).union(replaceVerbs).union(keepVerbs)
        .union(putVerbs).union(playVerbs).union(resumeVerbs).union(otherVerbs)

    /// Words that only Portuguese uses in these phrases: the verbs, the question words and the words of the topics.
    private static let cues: Set<String> = verbs.subtracting(["remove"]).union([
        "quanto", "quanta", "quantos", "quantas", "qual", "quais", "quem", "como", "cade", "algum", "alguma",
        "estrela", "estrelas", "vendas", "venda", "vendi", "vendeu", "vendido", "faturamento", "faturei", "receita",
        "receitas", "pagamento", "pagamentos", "cobranca", "cobrancas", "ganhei", "lucro", "reuniao", "reunioes",
        "compromisso", "compromissos", "agendamento", "agendamentos", "reserva", "reservas", "cota", "plano", "uso",
        "consumo", "agente", "agentes", "sessao", "sessoes", "automacao", "automacoes", "fluxo", "fluxos",
        "repositorio", "repositorios", "implantacao", "implantacoes", "enviados", "enviado", "entregues", "musica",
        "musicas", "cancao", "tocando", "artista", "aba", "abas", "previsao", "clima", "chover", "chuva", "chovendo",
        "calor", "amanha", "hoje", "proxima", "proximo", "anterior", "seguinte", "silencio", "alto", "baixo",
        "rolando", "rodando", "acontecendo", "fazendo", "indo", "dinheiro", "saldo", "rodou", "falhou", "falhando",
        "funcionou", "preciso", "da",
    ])

    /// "remove" is also English. It is Portuguese here only with a Portuguese article or "e" around it.
    private static func isPortuguese(_ n: [String]) -> Bool {
        if n.contains(where: { cues.contains($0) && $0 != "remove" }) { return true }
        return n.contains("remove") && n.contains(where: { ["o", "os", "as", "e", "dos", "das", "pelo", "pela", "nas"].contains($0) })
    }

    private static func hasPortugueseVerb(_ n: [String]) -> Bool {
        n.contains { verbs.contains($0) }
    }

    private static func isCommand(_ intent: VoiceIntent?) -> Bool {
        guard let intent else { return false }
        return intent != .unknown
    }

    // MARK: Questions

    private static let questionWords: [String] = ["quanto", "quanta", "quantos", "quantas", "qual", "quais", "quem", "como",
                                                  "o que", "cade", "me diz", "me fala", "me conta", "me mostra", "algum",
                                                  "alguma", "tem algum", "tem alguma", "ha algum", "ha alguma"]

    static func topic(_ n: [String], asks: Bool) -> VoiceTopic? {
        guard !n.isEmpty else { return nil }
        let text = " " + n.joined(separator: " ") + " "
        func has(_ s: String) -> Bool { text.contains(" " + s + " ") }
        func hasAny(_ list: [String]) -> Bool { list.contains(where: has) }

        let asksNow = asks || hasAny(questionWords)
        // "me mostra" asks; "mostra o GitHub" adds a tab.
        let commandVerbs = verbs.subtracting(["mostra", "mostre"])
        if n.contains(where: { commandVerbs.contains($0) }) { return nil }
        if !has("me mostra"), n.contains(where: { $0 == "mostra" || $0 == "mostre" }) { return nil }

        let weather = ["previsao", "previsao do tempo", "clima", "chover", "chuva", "chovendo", "temperatura",
                       "guarda chuva", "faz calor", "faz frio", "fazer calor", "fazer frio", "como esta o tempo", "como ta o tempo", "qual o tempo",
                       "tempo hoje", "tempo amanha", "que tempo faz"]
        if hasAny(weather) { return hasAny(["amanha"]) ? .weatherTomorrow : .weatherToday }
        guard asksNow else { return nil }

        if has("stripe") { return .stripe }
        if hasAny(["github", "git hub", "gt"]) { return .github }
        if has("vercel") { return .vercel }
        if has("resend") { return .resend }
        if hasAny(["n8n", "n 8 n", "workflow", "workflows", "automacao", "automacoes", "fluxo", "fluxos"]) { return .n8n }
        if has("notion") { return .notion }
        if hasAny(["cal com", "calcom", "reuniao", "reunioes", "agenda", "compromisso", "compromissos", "agendamento",
                   "agendamentos", "reserva", "reservas"]) { return .calcom }
        if hasAny(["cota", "quota", "limite", "limites", "plano", "uso", "consumo"]) {
            return has("codex") ? .codexPlan : .claudePlan
        }
        if hasAny(["claude", "codex", "cursor", "gemini", "copilot", "vs code", "vscode", "visual studio", "agente",
                   "agentes", "sessao", "sessoes", "o que esta acontecendo", "o que ta acontecendo", "o que esta rolando",
                   "o que ta rolando", "o que esta rodando", "o que ta rodando", "o que esta fazendo", "o que ta fazendo",
                   "como esta indo", "como ta indo"]) { return .agents }
        if hasAny(["dinheiro", "vendas", "venda", "vendi", "vendeu", "vendido", "faturamento", "faturei", "receita",
                   "receitas", "saldo", "pagamento", "pagamentos", "cobranca", "cobrancas", "ganhei", "lucro"]) { return .stripe }
        if hasAny(["estrela", "estrelas", "pull request", "pull requests", "pr", "prs", "repo", "repos", "repositorio",
                   "repositorios", "ci"]) { return .github }
        if hasAny(["deploy", "deploys", "deployment", "implantacao", "implantacoes", "publicacao"]) { return .vercel }
        if hasAny(["email", "emails", "mail", "mails"]),
           hasAny(["quantos", "ultimos", "ultimo", "enviados", "enviado", "entregues"]) { return .resend }
        if hasAny(["musica", "musicas", "cancao", "faixa", "tocando", "artista"]) { return .music }
        if hasAny(["aba", "abas"]) { return .pills }
        return nil
    }

    // MARK: Opening an app, the volume, the transport

    private static func appToOpen(_ f: Words) -> String? {
        guard let verb = f.n.first, ["abre", "abra", "abrir"].contains(verb), f.n.count > 1 else { return nil }
        let skip: Set<String> = ["o", "a", "os", "as", "app", "aplicativo", "aplicacao", "programa", "para", "mim", "de", "do",
                                 "da"]
        var i = 1
        while i < f.n.count, skip.contains(f.n[i]) { i += 1 }
        guard i < f.n.count else { return nil }
        let name = f.r[i...].joined(separator: " ").trimmingCharacters(in: .punctuationCharacters)
        return name.isEmpty ? nil : name
    }

    /// "volume 50", "põe o volume em 30", "volume para 80 por cento".
    private static func setVolume(_ n: [String]) -> Int? {
        // "volume 50" is upstream's; here it takes a Portuguese verb or preposition around it.
        let volumeCues: Set<String> = ["coloca", "coloque", "poe", "ponha", "bota", "bote", "define", "defina", "muda", "mude",
                                       "deixa", "deixe", "ajusta", "ajuste", "para", "em", "no", "cento", "aumenta", "aumente",
                                       "abaixa", "abaixe", "baixa", "baixe", "diminui", "diminua"]
        guard n.contains(where: { volumeCues.contains($0) }), let v = n.firstIndex(of: "volume"),
              let at = n.indices.last(where: { $0 > v && Int(n[$0]) != nil }),
              let pct = Int(n[at]), (0...100).contains(pct) else { return nil }
        return pct
    }

    private static let filler: Set<String> = ["o", "a", "os", "as", "um", "uma", "essa", "esse", "esta", "este", "de", "ai", "por",
                                              "favor", "agora", "mais", "pouco", "pouquinho", "tudo", "isso", "para", "do", "da"]
    private static let musicNouns: Set<String> = ["musica", "musicas", "cancao", "cancoes", "faixa", "som", "audio",
                                                  "reproducao"]

    private static func transport(_ n: [String]) -> VoiceIntent? {
        guard let first = n.first else { return nil }
        let rest = Set(n.dropFirst())
        func only(_ extra: Set<String> = []) -> Bool { rest.isSubset(of: filler.union(musicNouns).union(extra)) }

        if n == ["silencio"] || n == ["chega", "de", "musica"] { return .musicPause }
        if ["pausa", "pausar", "pare", "parar", "interrompe", "interrompa"].contains(first), only(["tocar", "tocando"]) {
            return .musicPause
        }
        if first == "para", only(["tocar", "tocando"]) { return .musicPause }
        if putVerbs.union(["da", "dar"]).contains(first),
           n.suffix(2) == ["em", "pausa"] || n.suffix(2) == ["um", "pause"] || n.suffix(1) == ["pause"] { return .musicPause }
        if n == ["da", "play"] { return .musicPlay(target: nil) }
        if ["desliga", "desligue"].contains(first), only(), rest.contains(where: { musicNouns.contains($0) }) {
            return .musicPause
        }

        if ["pula", "pule", "pular", "passa", "avanca", "avance", "proxima", "proximo", "seguinte"].contains(first),
           only(["proxima", "proximo", "seguinte", "avancar"]) { return .musicNext }
        if n == ["musica", "seguinte"] || n == ["outra", "musica"] || n == ["troca", "de", "musica"]
            || n == ["muda", "de", "musica"] || n == ["muda", "a", "musica"] || n == ["troca", "a", "musica"] {
            return .musicNext
        }
        if ["volta", "volte", "voltar", "retorna", "retorne", "anterior"].contains(first),
           only(["anterior", "atras", "uma"]) { return .musicPrevious }
        if n == ["musica", "anterior"] || n == ["faixa", "anterior"] { return .musicPrevious }

        if ["aumenta", "aumente", "sobe", "suba", "levanta"].contains(first), only(["volume"]) { return .musicVolumeUp }
        if n == ["mais", "alto"] || n == ["volume", "mais", "alto"] || n == ["som", "mais", "alto"]
            || n == ["mais", "volume"] || n == ["mais", "som"] { return .musicVolumeUp }
        if ["abaixa", "abaixe", "diminui", "diminua", "baixa", "baixe", "reduz", "reduza"].contains(first),
           only(["volume"]) { return .musicVolumeDown }
        if n == ["mais", "baixo"] || n == ["volume", "mais", "baixo"] || n == ["som", "mais", "baixo"]
            || n == ["menos", "volume"] || n == ["menos", "som"] { return .musicVolumeDown }
        return nil
    }

    // MARK: Tabs ("abas")

    private static let articles: Set<String> = ["o", "a", "os", "as", "um", "uma", "uns", "umas", "de", "do", "da", "dos", "das",
                                                "aba", "abas", "pilula", "aquela", "aquele"]
    private static let places: Set<String> = ["abas", "aba", "notch", "barra", "lista", "ilha", "encoche"]
    private static let inPrepositions: Set<String> = ["nas", "na", "no", "nos", "das", "da", "do", "dos", "em", "de"]

    private static func stripArticles(_ w: [String]) -> [String] {
        var out = w
        while let f = out.first, articles.contains(f) { out.removeFirst() }
        return out
    }

    /// "…o GitHub nas abas" → "…o GitHub"; a trailing "também" goes too.
    private static func stripTail(_ w: [String]) -> [String] {
        var out = w
        var changed = true
        while changed, !out.isEmpty {
            changed = false
            if let l = out.last, l == "tambem" || l == "ai" { out.removeLast(); changed = true; continue }
            if out.count >= 2, places.contains(out[out.count - 1]), inPrepositions.contains(out[out.count - 2]) {
                out.removeLast(2); changed = true
            }
        }
        return out
    }

    /// The tabs named in a list: "o GitHub e a Vercel" → both ids; nil when one of them is not a tab. Names of several words
    /// ("Apple Music") are found by their longest match; a comma the recognizer dropped costs nothing.
    private static func tabs(_ w: [String], pills: [PillDefinition], category: PillCategory? = nil) -> [String]? {
        var ids: [String] = []
        for group in stripTail(w).split(separator: "e", omittingEmptySubsequences: true) {
            let g = Array(group)
            var i = 0
            var found = 0
            while i < g.count {
                if articles.contains(g[i]) { i += 1; continue }
                var matched = false
                for size in stride(from: min(3, g.count - i), through: 1, by: -1) {
                    let name = g[i..<(i + size)].joined(separator: " ")
                    if let id = EntityResolver.resolve(name, from: pills, category: category) {
                        ids.append(id); i += size; found += 1; matched = true; break
                    }
                }
                if !matched { return nil }
            }
            if found == 0 { return nil }
        }
        return ids.isEmpty ? nil : ids
    }

    private static func pillCommand(_ f: Words, pills: [PillDefinition]) -> VoiceIntent? {
        let n = f.n
        guard let verb = n.first else { return nil }

        // "o Cursor como aba principal", "muda a aba principal para o Cursor", "usa o Cursor".
        if n.contains("principal") {
            var entity: [String] = []
            let start = verbs.contains(verb) || ["define", "defina", "marca", "marque"].contains(verb) ? 1 : 0
            if let como = n.firstIndex(of: "como"), como >= start {
                entity = Array(n[start..<como])
            } else if let p = n.firstIndex(of: "principal"),
                      let sep = n.indices.last(where: { $0 > p && ["para", "pelo", "pela", "com", "em"].contains(n[$0]) }) {
                entity = Array(n[(sep + 1)...])
            }
            if let id = tabs(entity, pills: pills, category: .workspace)?.first { return .pillSetMain(id: id) }
        }
        if ["usa", "usar"].contains(verb), n.count > 1,
           let id = tabs(Array(n.dropFirst()), pills: pills, category: .workspace)?.first {
            return .pillSetMain(id: id)
        }
        if ["muda", "mude", "troca", "troque", "passa", "vai"].contains(verb),
           let to = n.indices.first(where: { $0 > 0 && n[$0] == "para" }), to <= 4,
           n[1..<to].allSatisfy({ ["de", "da", "a", "o", "aba", "principal"].contains($0) }), to + 1 < n.count,
           let id = tabs(Array(n[(to + 1)...]), pills: pills, category: .workspace)?.first {
            return .pillSetMain(id: id)
        }

        // "X no lugar do Y", "X em vez de Y": X replaces Y.
        for marker in [["no", "lugar"], ["em", "vez"], ["ao", "inves"]] {
            guard let m = indexOf(marker, in: n), m > 0, m + 2 < n.count, ["de", "do", "da", "dos", "das"].contains(n[m + 2]),
                  m + 3 < n.count else { continue }
            let leadVerbs = putVerbs.union(addVerbs).union(["usa", "quero", "prefiro"])
            let left = Array(n[..<m]).filter { !leadVerbs.contains($0) }
            if let new = tabs(left, pills: pills)?.first, let old = tabs(Array(n[(m + 3)...]), pills: pills)?.first, new != old {
                return .pillReplace(old: old, new: new)
            }
        }

        // "troca o n8n pelo GitHub".
        if replaceVerbs.contains(verb),
           let sep = n.indices.first(where: { $0 > 1 && ["por", "pelo", "pela", "com"].contains(n[$0]) }), sep + 1 < n.count,
           let old = tabs(Array(n[1..<sep]), pills: pills)?.first, let new = tabs(Array(n[(sep + 1)...]), pills: pills)?.first {
            return .pillReplace(old: old, new: new)
        }

        // "deixa só o GitHub e a Vercel", "mantém apenas o Stripe".
        if keepVerbs.contains(verb),
           let only = n.indices.first(where: { ["so", "apenas", "somente"].contains(n[$0]) }), only + 1 < n.count {
            var rest = Array(n[(only + 1)...])
            if rest.first == "com" { rest.removeFirst() }
            if let ids = tabs(rest, pills: pills), !ids.isEmpty { return .pillOnly(ids) }
        }

        // "não preciso mais do Vercel".
        var removeRest: [String]? = nil
        if n.starts(with: ["nao", "preciso", "mais"]) { removeRest = Array(n.dropFirst(3)) }
        if removeVerbs.contains(verb) { removeRest = Array(n.dropFirst()) }
        if let rest = removeRest {
            guard let ids = tabs(rest, pills: pills) else { return stripTail(rest).isEmpty ? nil : .unknown }
            return ids.count > 1 ? .pillRemoveMultiple(ids: ids) : .pillRemove(id: ids[0])
        }

        if addVerbs.contains(verb), n.count > 1 {
            guard let ids = tabs(Array(n.dropFirst()), pills: pills) else { return .unknown }
            return ids.count > 1 ? .pillAddMultiple(ids: ids) : .pillAdd(id: ids[0])
        }
        return nil
    }

    // MARK: Music with a name ("toca …") and the verbs that also mean "put a tab"

    private static let genericMusic: Set<String> = ["musica", "musicas", "som", "cancao", "cancoes", "audio", "algo", "qualquer",
                                                    "coisa", "alguma", "umas", "uns", "tocar", "tocando"]

    private static func playCommand(_ f: Words, pills: [PillDefinition]) -> VoiceIntent? {
        let n = f.n
        guard let verb = n.first else { return nil }
        let plays = playVerbs.contains(verb)
        guard plays || resumeVerbs.contains(verb) || putVerbs.contains(verb) else { return nil }

        // After the verb: articles off, "de/da" of "uma música de…" kept for the name.
        var start = 1
        let lead: Set<String> = ["o", "a", "os", "as", "um", "uma", "uns", "umas", "aquela", "aquele"]
        while start < n.count, lead.contains(n[start]) { start += 1 }
        var object = Array(n[min(start, n.count)...])
        var objectRaw = Array(f.r[min(start, f.r.count)...])

        // "toca a próxima", "toca a música anterior".
        let kind = object.filter { !musicNouns.contains($0) }
        if plays || resumeVerbs.contains(verb) {
            if kind == ["proxima"] || kind == ["proximo"] || kind == ["seguinte"] { return .musicNext }
            if kind == ["anterior"] { return .musicPrevious }
        }
        // "uma música do Djavan" → "Djavan".
        while let first = object.first, genericMusic.contains(first) || musicNouns.contains(first), object.count > 2,
              ["de", "do", "da", "dos", "das"].contains(object[1]) {
            object.removeFirst(2); objectRaw.removeFirst(min(2, objectRaw.count))
        }

        // A playlist: "toca a playlist Foco", "toca minha playlist".
        if let p = object.firstIndex(where: { $0 == "playlist" || $0 == "playlists" }) {
            var from = p + 1
            while from < object.count, ["de", "do", "da", "dos", "das", "chamada", "chamado"].contains(object[from]) { from += 1 }
            let name = from < objectRaw.count ? objectRaw[from...].joined(separator: " ") : ""
            if plays || resumeVerbs.contains(verb) || putVerbs.contains(verb) { return .musicPlayPlaylist(name: name) }
        }
        // A streaming service: "toca no Spotify", "coloca a música no Apple Music". Like upstream's "… sur Spotify", the
        // service is what is played; a name before it is not searched there.
        if let target = musicTarget(object) { return .musicPlay(target: target) }
        if let suffix = serviceSuffix(object) { return .musicPlay(target: suffix) }

        let words = object.filter { !["para", "mim", "de", "do", "da"].contains($0) }
        if words.isEmpty || words.allSatisfy({ genericMusic.contains($0) }) { return .musicPlay(target: nil) }
        if resumeVerbs.contains(verb) { return nil }

        if plays {
            let name = objectRaw.joined(separator: " ").trimmingCharacters(in: .punctuationCharacters.union(.whitespaces))
            return name.isEmpty ? .musicPlay(target: nil) : .musicPlaySearch(name: name)
        }

        // "coloca o GitHub": a tab or a song. A workspace tab becomes the main one, like upstream's "mets Cursor".
        if let ids = tabs(object, pills: pills), !ids.isEmpty {
            if ids.count > 1 { return .pillAddMultiple(ids: ids) }
            if let workspace = tabs(object, pills: pills, category: .workspace)?.first { return .pillSetMain(id: workspace) }
            return .pillAdd(id: ids[0])
        }
        let name = objectRaw.joined(separator: " ").trimmingCharacters(in: .punctuationCharacters.union(.whitespaces))
        return name.isEmpty ? nil : .musicPlaySearch(name: name)
    }

    /// "Pitty no Spotify" → Spotify.
    private static func serviceSuffix(_ object: [String]) -> MusicTarget? {
        let prepositions: Set<String> = ["no", "na", "pelo", "pela"]
        if object.count >= 2, prepositions.contains(object[object.count - 2]),
           let target = musicTarget([object[object.count - 1]]) { return target }
        if object.count >= 3, prepositions.contains(object[object.count - 3]),
           let target = musicTarget(Array(object.suffix(2))) { return target }
        return nil
    }

    private static func musicTarget(_ object: [String]) -> MusicTarget? {
        let words = object.filter { !["no", "na", "pelo", "pela", "do", "da", "em", "o", "a", "musica", "app", "aplicativo"].contains($0) }
        if words == ["spotify"] { return .spotify }
        if words == ["apple", "music"] || words == ["music"] || words == ["applemusic"] { return .appleMusic }
        return nil
    }

    // MARK: Web search ("pesquisa na internet quem ganhou ontem")

    static func webQuery(_ raw: String) -> String? {
        let toks = VoiceQuery.tokens(raw)
        let n = toks.map { $0.norm }
        guard !n.isEmpty else { return nil }
        let joined = " " + n.joined(separator: " ") + " "
        let webWords = [" internet ", " web ", " google ", " online ", " na rede "]
        guard webWords.contains(where: { joined.contains($0) }) else { return nil }
        let searchVerbs: Set<String> = ["pesquisa", "pesquise", "pesquisar", "procura", "procure", "procurar", "busca", "busque",
                                        "buscar", "googla", "googlar", "consulta", "consulte", "descobre", "descubra"]
        guard n.contains(where: { searchVerbs.contains($0) }) || ["google", "googla"].contains(n[0]) else { return nil }

        let heads: [[String]] = [
            ["voce", "poderia"], ["voce", "pode"], ["quero", "que", "voce"], ["pode"], ["poderia"], ["da", "para"],
            ["ok"], ["okay"], ["koru"], ["ei"], ["entao"], ["por", "favor"], ["me"],
            ["pesquisa", "para", "mim"], ["pesquisa"], ["pesquise"], ["pesquisar"], ["procura", "para", "mim"],
            ["procura"], ["procure"], ["procurar"], ["busca"], ["busque"], ["buscar"], ["googla"], ["googlar"], ["google"],
            ["consulta"], ["consulte"], ["descobre"], ["descubra"],
            ["na", "internet"], ["na", "web"], ["no", "google"], ["na", "rede"], ["online"], ["internet"], ["web"],
            ["para", "mim"], ["por", "mim"], ["sobre"],
        ]
        let tails: [[String]] = [
            ["na", "internet"], ["na", "web"], ["no", "google"], ["na", "rede"], ["online"], ["por", "favor"],
            ["para", "mim"], ["pra", "mim"], ["obrigado"], ["obrigada"], ["valeu"],
        ]
        var h = 0, t = n.count
        var changed = true
        while changed && h < t {
            changed = false
            for seq in heads where h + seq.count <= t && Array(n[h..<(h + seq.count)]) == seq {
                h += seq.count; changed = true; break
            }
            for seq in tails where t - seq.count >= h && Array(n[(t - seq.count)..<t]) == seq {
                t -= seq.count; changed = true; break
            }
        }
        guard h < t else { return "" }
        return String(raw[toks[h].range.lowerBound..<toks[t - 1].range.upperBound])
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
    }

    /// A question rather than a command, for the web fallback: true for "quem ganhou ontem", false for "você pode…",
    /// nil when the phrase is not Portuguese (upstream decides).
    static func looksLikeQuestion(_ n: [String], endsWithQuestionMark: Bool) -> Bool? {
        guard let first = n.first else { return nil }
        let requests = ["voce pode", "voce poderia", "voce consegue", "pode voce", "da para", "por favor", "pode", "poderia"]
        let joined = n.joined(separator: " ")
        if requests.contains(where: { joined == $0 || joined.hasPrefix($0 + " ") }) { return false }
        let starters: Set<String> = ["quem", "qual", "quais", "quanto", "quanta", "quantos", "quantas", "onde", "porque", "quando"]
        let opensWithQuestion = starters.contains(first) || joined.hasPrefix("o que ") || joined.hasPrefix("por que ")
        if opensWithQuestion || (joined.hasPrefix("como ") && endsWithQuestionMark) { return true }
        return nil
    }

    // MARK: E-mail ("manda um e-mail para a Tana")

    private static let sendVerbs: Set<String> = ["manda", "mande", "mandar", "envia", "envie", "enviar", "escreve", "escreva",
                                                "escrever", "redige", "redija"]
    private static let mailWords: Set<String> = ["email", "emails", "mail", "mails"]
    private static let fileMap: [String: String] = [
        "arquivo": "file", "arquivos": "file", "imagem": "image", "foto": "photo", "documento": "document", "pdf": "pdf",
        "video": "video", "captura": "screenshot", "print": "screenshot",
    ]

    /// The request of a Portuguese e-mail phrase. It is said in English to upstream's `VoiceQuery.mail(of:)`: the verbs,
    /// the file words and the subject and text markers are translated, whatever the person dictated stays as said.
    private static func mail(_ raw: String, _ all: Words) -> VoiceQuery.MailRequest? {
        guard all.n.contains(where: { sendVerbs.contains($0) }),
              all.n.contains(where: { mailWords.contains($0) || fileMap[$0] != nil }) else { return nil }
        // Only when the verb opens the phrase (after politeness): "escreve" inside a sentence is not a mail.
        guard clean(all).n.first.map({ sendVerbs.contains($0) }) == true else { return nil }

        let toks = VoiceQuery.tokens(raw)
        guard !toks.isEmpty else { return nil }
        let markers: [(words: [String], english: String)] = [
            (["para", "dizer", "que"], "saying that"), (["pra", "dizer", "que"], "saying that"),
            (["dizendo", "que"], "saying that"), (["falando", "que"], "saying that"), (["avisando", "que"], "saying that"),
            (["dizendo"], "saying"), (["que", "diz"], "that says"), (["diz", "que"], "saying that"),
            (["com", "o", "texto"], "with the text"), (["texto"], "body"), (["corpo"], "body"), (["descricao"], "body"),
            (["assunto"], "subject"), (["titulo"], "subject"),
        ]
        var found: [(start: Int, end: Int, english: String)] = []
        var i = 0
        let tn = toks.map { $0.norm }
        while i < tn.count {
            var hit = false
            for m in markers where i + m.words.count <= tn.count && Array(tn[i..<(i + m.words.count)]) == m.words {
                found.append((i, i + m.words.count, m.english)); i += m.words.count; hit = true; break
            }
            if !hit { i += 1 }
        }

        let headEnd = found.first?.start ?? tn.count
        var head: [String] = []
        for k in 0..<headEnd {
            let w = tn[k]
            let said = String(raw[toks[k].range])
            if sendVerbs.contains(w) { head.append("send") }
            else if mailWords.contains(w) { head.append("email") }
            else if ["para", "pra", "pro"].contains(w) { head.append("to") }
            else if let f = fileMap[w] { head.append(f) }
            else if ["o", "a", "os", "as", "um", "uma", "uns", "umas"].contains(w) { continue }
            else if ["baixados", "downloads", "download"].contains(w) { head.append("downloads") }
            else if ["documentos"].contains(w) { head.append("documents") }
            else if ["imagens", "fotos"].contains(w) { head.append("pictures") }
            else if ["mesa", "desktop"].contains(w) { head.append("desktop") }
            else if ["de", "do", "da", "dos", "das", "dentro"].contains(w) { head.append("from") }
            else if w == "e", k + 1 < headEnd, mailWords.contains(tn[k + 1]) { continue }
            else { head.append(said) }
        }
        var built = head.joined(separator: " ")
        for (idx, marker) in found.enumerated() {
            let from = toks[marker.end - 1].range.upperBound
            let to = idx + 1 < found.count ? toks[found[idx + 1].start].range.lowerBound : raw.endIndex
            built += " " + marker.english + " " + raw[from..<to]
        }
        return VoiceQuery.mail(of: built)
    }

    // MARK: Splitting one sentence into several commands

    private static func splitOnVerbs(_ segment: String) -> [String] {
        let toks = segment.split(separator: " ").map(String.init)
        var parts: [[String]] = []
        var cur: [String] = []
        var curHasVerb = false
        for w in toks {
            let isVerb = verbs.contains(IntentParser.normalise(w))
            // "bota pra tocar": the second verb belongs to the first.
            let infinitive = cur.last.map { ["para", "pra", "pro", "a", "de"].contains(IntentParser.normalise($0)) } ?? false
            if isVerb && curHasVerb && !infinitive { parts.append(cur); cur = []; curHasVerb = false }
            cur.append(w)
            if isVerb { curHasVerb = true }
        }
        if !cur.isEmpty { parts.append(cur) }
        let joiners: Set<String> = ["e", "depois", "entao", "ai", "dai", "seguida", "tambem"]
        return parts.compactMap { p in
            var p = p
            while let l = p.last, joiners.contains(IntentParser.normalise(l)) { p.removeLast() }
            while let f = p.first, joiners.contains(IntentParser.normalise(f)) { p.removeFirst() }
            return p.isEmpty ? nil : p.joined(separator: " ")
        }
    }

    private static func splitOnJoiners(_ piece: String) -> [String] {
        let joiners: Set<String> = ["e", "depois", "entao", "dai"]
        var parts: [[String]] = []
        var cur: [String] = []
        for w in piece.split(separator: " ").map(String.init) {
            if joiners.contains(IntentParser.normalise(w)) {
                if !cur.isEmpty { parts.append(cur); cur = [] }
            } else { cur.append(w) }
        }
        if !cur.isEmpty { parts.append(cur) }
        return parts.map { $0.joined(separator: " ") }
    }

    // MARK: Follow-ups ("e o Vercel também", "desfaz")

    /// A Portuguese follow-up said as upstream's French form, for ConversationContext. Other phrases come back as given.
    static func relativeForm(_ norm: String) -> String {
        let w = norm.split(separator: " ").map(String.init)
        guard let first = w.first else { return norm }
        if ["desfaz", "desfaca", "desfazer", "anula", "anule", "reverte", "reverta"].contains(first)
            || w.starts(with: ["volta", "atras"]) || w.starts(with: ["cancela", "isso"]) || w.starts(with: ["cancela", "essa"]) {
            return "annule ca"
        }
        // A phrase with its own verb is a command ("adiciona o Stripe também"), not a follow-up.
        guard !hasPortugueseVerb(w) else { return norm }
        let lead: Set<String> = ["o", "a", "os", "as"]
        func entity(_ words: ArraySlice<String>) -> String {
            words.filter { !lead.contains($0) && $0 != "tambem" }.joined(separator: " ")
        }
        if first == "e", w.count > 1, w.contains("tambem") || w.count <= 3 { return "et " + entity(w.dropFirst()) + " aussi" }
        if first == "tambem", w.count > 1 { return "aussi " + entity(w.dropFirst()) }
        if w.last == "tambem", w.count > 1 { return entity(w.dropLast()) + " aussi" }
        if ["igual", "mesmo", "mesma", "idem"].contains(first) {
            let rest = w.drop(while: { ["igual", "mesmo", "mesma", "coisa", "idem", "para", "com", "de"].contains($0) })
            if !rest.isEmpty { return "pareil pour " + entity(rest) }
        }
        return norm
    }

    // MARK: Hooks for the guided e-mail (VoiceQuery)

    static let recipientLeads: [String] = [
        "é para o", "é para a", "é pra", "é pro", "é o", "é a", "é", "para o", "para a", "para", "pra", "pro",
        "ele se chama", "ela se chama", "se chama", "o nome dele é", "o nome dela é", "o nome é", "o e-mail dele é",
        "o e-mail dela é", "o email dele é", "o email dela é", "meu amigo", "minha amiga", "meu irmão", "minha irmã",
        "manda para", "manda pra", "envia para", "envia pra",
    ]
    static let contactStopWords: Set<String> = [
        "o", "a", "os", "as", "do", "da", "dos", "das", "meu", "minha", "amigo", "amiga", "e", "se", "chama", "para", "pra",
    ]
    static let noSubject: Set<String> = ["sem assunto", "nenhum assunto", "nao precisa de assunto", "nao tem assunto",
                                         "nada", "nenhum", "sem titulo", "sem assunto obrigado"]
    static let subjectLeads: [String] = ["o assunto é", "o assunto", "assunto", "o título é", "título", "titulo", "coloca", "põe", "é"]
    static let literalLeads: [String] = ["palavra por palavra", "texto exato", "o texto exato é", "escreve exatamente",
                                         "exatamente"]
    static let instructionLeads: [String] = [
        "diz que", "fala que", "avisa que", "avisa ela que", "avisa ele que", "escreve que", "escreve pra ela que",
        "escreve pra ele que", "diz pra ela que", "diz pra ele que", "fala pra ela que", "fala pra ele que",
        "para dizer que", "pra dizer que", "dizendo que", "falando que", "precisa dizer que", "tem que dizer que",
        "a mensagem é", "a mensagem", "é",
    ]
    static let attachmentLeads: [String] = ["sim", "claro", "é o", "é a", "é", "o arquivo", "a imagem", "a foto", "o documento",
                                            "anexa", "anexe", "junta", "o arquivo chamado", "a imagem chamada"]

    /// Whether free text (the e-mail the person wants written) is Portuguese rather than French or English.
    static func looksPortuguese(_ text: String) -> Bool {
        let w = IntentParser.normalise(text).split(separator: " ").map(String.init)
        let pt: Set<String> = ["nao", "uma", "uns", "umas", "voce", "voces", "ontem", "amanha", "obrigado", "obrigada", "pronto",
                               "pronta", "meu", "minha", "meus", "minhas", "pelo", "pela", "dos", "das", "foi", "tambem", "isso",
                               "essa", "esse", "estou", "estamos", "com", "para", "pra", "ja", "muito", "oi", "ola", "reuniao",
                               "arquivo", "imagem", "esta", "sao", "ser", "mais"]
        let fr: Set<String> = ["le", "les", "est", "sont", "des", "du", "pour", "je", "tu", "il", "elle", "nous", "vous", "avec",
                               "pas", "merci", "demain", "hier", "une", "et"]
        let en: Set<String> = ["the", "is", "are", "to", "of", "for", "and", "with", "not", "thanks", "it", "my", "your", "ready"]
        let p = w.filter { pt.contains($0) }.count
        return p > 0 && p > w.filter { fr.contains($0) }.count && p > w.filter { en.contains($0) }.count
    }

    // MARK: Helpers

    private static func indexOf(_ seq: [String], in words: [String]) -> Int? {
        guard !seq.isEmpty, seq.count <= words.count else { return nil }
        for i in 0...(words.count - seq.count) where Array(words[i..<(i + seq.count)]) == seq { return i }
        return nil
    }
}
