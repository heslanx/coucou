import Foundation

// "OK Koru" in Brazilian Portuguese (unit U5): the language type, the Portuguese sentences, the phrase parser, the spoken
// answers of the runner, the prompts and the small hooks in the voice files. Run by scripts/konclui/test-voice-pt.sh.
// `--table` prints the evidence table: utterance, parsed intent, spoken answer.

// MARK: - Fakes

final class PtMusic: MusicControlling, @unchecked Sendable {
    var calls: [String] = []
    var isMusicRunning: Bool { true }
    var isSpotifyRunning: Bool { true }
    @MainActor func play() { calls.append("play") }
    @MainActor func pause() { calls.append("pause") }
    @MainActor func nextTrack() { calls.append("next") }
    @MainActor func previousTrack() { calls.append("previous") }
    @MainActor func volumeUp() { calls.append("volumeUp") }
    @MainActor func volumeDown() { calls.append("volumeDown") }
    @MainActor func setVolume(_ pct: Int) { calls.append("volume:\(pct)") }
    @MainActor func playSearch(_ name: String) async -> Bool { calls.append("search:\(name)"); return true }
    @MainActor func playPlaylist(_ name: String) async -> Bool { calls.append("playlist:\(name)"); return true }
    @MainActor func launchAndPlay() async { calls.append("launch") }
    @MainActor func launchSpotify() async { calls.append("launchSpotify") }
    @MainActor func openSearch(_ name: String) { calls.append("openSearch:\(name)") }
}

@MainActor
final class PtPills: PillControlling {
    var active: Set<String> = ["integration_vercel", "integration_n8n"]
    var main = "integration_claude"
    func activeIds() -> Set<String> { active }
    func mainPillId() -> String { main }
    func activeCount() -> Int { active.count }
    func toggleIntegration(_ id: String) { if active.contains(id) { active.remove(id) } else { active.insert(id) } }
    func setMainPill(_ id: String) { main = id }
}

/// What the Mac side (LiveVoiceInfo) does, with sample data: VoiceAnswer in the language of the locale.
@MainActor
final class PtInfo: VoiceInfoProviding {
    var card: (to: String, subject: String, body: String)?
    static func snapshot(_ topic: VoiceTopic) -> VoiceSnapshot {
        var s = VoiceSnapshot()
        s.stripe = .init(balance: "R$ 1.240,00", today: "R$ 385,00", todayCount: 3)
        s.github = .init(stars: 128, repos: 12,
                         myPRs: [.init(title: "a", repo: "r", ci: "failure", review: "pending"),
                                 .init(title: "b", repo: "r", ci: "success", review: "approved")],
                         toReview: 1, failingRepos: ["koru"])
        s.deploys = [.init(project: "koru-site", state: "READY", ago: "5 minutos", commit: nil)]
        s.emailsTotal = 42
        s.emails = [(to: "tana@example.com", subject: "Fatura", state: "delivered")]
        s.runs = [(workflow: "Backup", ok: true, ago: "2 horas")]
        s.pages = [(title: "Roteiro", ago: "1 hora")]
        s.bookings = [.init(title: "Reunião de produto", when: "amanhã às 10:00", with: "Tana")]
        s.sessions = [.init(name: "Claude Code", state: "working", detail: "Edit IntentParser.swift")]
        s.plan = .init(fiveHourPct: 34, sevenDayPct: 12, resetsIn: "2 horas")
        s.nowPlaying = (title: "Aquarela", artist: "Toquinho")
        s.mainPill = "VS Code"; s.activePills = ["GitHub", "Vercel"]
        s.weather = .init(city: "São Paulo", nowTemp: 22, code: 61, min: 17, max: 25, rainChance: 70, wind: 12)
        return s
    }
    func answer(_ topic: VoiceTopic, locale: Locale?) async -> String {
        VoiceAnswer.text(topic, Self.snapshot(topic), language: VoiceLanguage(locale: locale))
    }
    func openApp(_ name: String, locale: Locale?) -> VoiceActionResult {
        .init(outcome: .success, message: voiceSay(VoiceLanguage(locale: locale), "J'ouvre \(name).", "Opening \(name)."))
    }
    func resolveEmail(_ recipient: String) async -> String? {
        VoiceQuery.spokenEmail(recipient) ?? (recipient == "Tana" ? "tana@example.com" : nil)
    }
    func findFile(_ name: String, folder: VoiceQuery.MailRequest.Folder?) -> URL? { nil }
    func draftBody(to recipient: String, about instruction: String) async -> String? { nil }
    func showMailCard(to address: String, subject: String, body: String, file: URL?) { card = (address, subject, body) }
    var webSearchEnabled: Bool { true }
    var hasWebKey: Bool { true }
    func webAnswer(_ question: String, history: [VoiceWebTurn], french: Bool) async -> String? { nil }
}

// MARK: - Harness

@main
@MainActor
enum KoncluiVoicePortugueseTests {
    static var pass = 0
    static var fail = 0
    static let pills = PillFixture.available

    static func check<T: Equatable>(_ label: String, _ got: T, _ want: T) {
        if got == want { pass += 1 } else { print("✗  \(label) — got \(got), want \(want)"); fail += 1 }
    }

    static func main() async {
        languageTests()
        voiceTextTests()
        parserTests()
        questionTests()
        englishAndFrenchUntouchedTests()
        multiActionTests()
        await answerTests()
        await runnerFlowTests()
        hookTests()
        if CommandLine.arguments.contains("--table") { await evidenceTable() }
        let total = pass + fail
        if fail == 0 { print("\(total)/\(total) passed.") } else { print("\n\(fail) FAILED / \(total) total"); exit(1) }
    }

    // MARK: Language

    static func languageTests() {
        check("code pt", VoiceLanguage(code: "pt"), .pt)
        check("code pt-BR", VoiceLanguage(code: "pt-BR"), .pt)
        check("code pt_BR", VoiceLanguage(code: "pt_BR"), .pt)
        check("code fr-CA", VoiceLanguage(code: "fr-CA"), .fr)
        check("code en-GB", VoiceLanguage(code: "en-GB"), .en)
        check("code de is English", VoiceLanguage(code: "de"), .en)
        check("code nil is English", VoiceLanguage(code: nil), .en)
        check("locale pt-BR", VoiceLanguage(locale: Locale(identifier: "pt-BR")), .pt)
        check("locale nil is English", VoiceLanguage(locale: nil), .en)
        check("answer locale pt", VoiceLanguage.pt.locale.identifier.replacingOccurrences(of: "_", with: "-"), "pt-BR")
        check("answer locale fr", VoiceLanguage.fr.locale.language.languageCode?.identifier, "fr")
        check("Mac pt-BR", VoiceLanguage.macDefault(preferredLanguages: ["pt-BR", "en-US"]), .pt)
        check("Mac fr", VoiceLanguage.macDefault(preferredLanguages: ["fr-FR"]), .fr)
        check("Mac en", VoiceLanguage.macDefault(preferredLanguages: ["en-US"]), .en)
        check("Mac de falls back to English", VoiceLanguage.macDefault(preferredLanguages: ["de-DE", "pt-BR"]), .en)
        check("Mac without languages", VoiceLanguage.macDefault(preferredLanguages: []), .en)
        check("listen pt first", VoiceLanguage.pt.listenLocaleIdentifiers.first, "pt-BR")
        check("prompt name", VoiceLanguage.pt.promptName, "Brazilian Portuguese")
        check("all codes", VoiceLanguage.allCases.map(\.rawValue), ["en", "fr", "pt"])
    }

    // MARK: VoiceText

    static func voiceTextTests() {
        let n = 3, s = "s"
        let en: VoiceText = "You have \(n) star\(s)."
        check("template", en.template, "You have {} star{}.")
        check("rendered as written", en.rendered, "You have 3 stars.")
        let plain: VoiceText = "Done."
        check("plain literal", plain.rendered, "Done.")
        check("fill reorders", KoncluiVoicePhrases.fill("{2} antes de {1}", with: ["a", "b"]), "b antes de a")
        check("fill keeps unknown braces", KoncluiVoicePhrases.fill("{9} {x} ok", with: ["a"]), "{9} {x} ok")
        check("say en", voiceSay(.en, "Fini.", "Done."), "Done.")
        check("say fr", voiceSay(.fr, "Fini.", "Done."), "Fini.")
        check("say pt", voiceSay(.pt, "Fini.", "Done."), "Pronto.")
        check("say pt with values", voiceSay(.pt, "Tu as \(n) étoile\(s).", "You have \(n) star\(s)\("")."), "Você tem 3 estrelas.")
        check("say pt, singular", voiceSay(.pt, "x", "You have \(1) star\("")\("")."), "Você tem 1 estrela.")
        check("unknown sentence is English", voiceSay(.pt, "Inconnu.", "Never translated."), "Never translated.")
        check("plain value passes", voiceSay(.pt, "x", "Opening \("Figma")."), "Abrindo Figma.")
        check("argument words", voiceSay(.pt, "x", "Last workflow: \("Backup"), \("failed"), \("2 horas") ago."),
              "Último workflow: Backup, falhou, há 2 horas.")
    }

    // MARK: Parser

    static func parserTests() {
        func cases(_ list: [(String, VoiceIntent)]) {
            for (said, want) in list { check("\"\(said)\"", IntentParser.parse(said, pills: pills), want) }
        }
        cases([
            // tabs ("abas")
            ("adiciona o GitHub", .pillAdd(id: "integration_github")),
            ("adiciona o GitHub nas abas", .pillAdd(id: "integration_github")),
            ("Adiciona a aba do Vercel", .pillAdd(id: "integration_vercel")),
            ("você pode adicionar o Stripe?", .pillAdd(id: "integration_stripe")),
            ("pode adicionar o Stripe e o Notion, por favor", .pillAddMultiple(ids: ["integration_stripe", "integration_notion"])),
            ("ativa o Spotify", .pillAdd(id: "integration_spotify")),
            ("tira o Vercel", .pillRemove(id: "integration_vercel")),
            ("tira o Vercel das abas", .pillRemove(id: "integration_vercel")),
            ("remove o GitHub e o Stripe", .pillRemoveMultiple(ids: ["integration_github", "integration_stripe"])),
            ("não preciso mais do Notion", .pillRemove(id: "integration_notion")),
            ("desativa o n8n", .pillRemove(id: "integration_n8n")),
            ("troca o n8n pelo GitHub", .pillReplace(old: "integration_n8n", new: "integration_github")),
            ("substitui a Vercel por Stripe", .pillReplace(old: "integration_vercel", new: "integration_stripe")),
            ("coloca o GitHub no lugar do n8n", .pillReplace(old: "integration_n8n", new: "integration_github")),
            ("deixa só o GitHub e a Vercel", .pillOnly(["integration_github", "integration_vercel"])),
            ("mantém apenas o Stripe", .pillOnly(["integration_stripe"])),
            ("coloca o Cursor como aba principal", .pillSetMain(id: "agent_cursor")),
            ("muda a aba principal para o Codex", .pillSetMain(id: "agent_codex")),
            ("usa o Cursor", .pillSetMain(id: "agent_cursor")),
            ("põe o Notion", .pillAdd(id: "integration_notion")),
            // music
            ("toca uma música", .musicPlay(target: nil)),
            ("toca música", .musicPlay(target: nil)),
            ("bota um som", .musicPlay(target: nil)),
            ("continua a música", .musicPlay(target: nil)),
            ("dá play", .musicPlay(target: nil)),
            ("bota pra tocar", .musicPlay(target: nil)),
            ("liga a música", .musicPlay(target: nil)),
            ("liga o Spotify", .musicPlay(target: .spotify)),
            ("toca Pitty no Spotify", .musicPlay(target: .spotify)),
            ("me toca uma música do Djavan", .musicPlaySearch(name: "Djavan")),
            ("toca a próxima", .musicNext),
            ("toca a música anterior", .musicPrevious),
            ("desliga a música", .musicPause),
            ("troca de aba para o Codex", .pillSetMain(id: "agent_codex")),
            ("adiciona o GitHub, o Vercel e o Stripe", .pillAddMultiple(ids: ["integration_github", "integration_vercel", "integration_stripe"])),
            ("adiciona o Apple Music e o Spotify", .pillAddMultiple(ids: ["integration_music", "integration_spotify"])),
            ("toca no Spotify", .musicPlay(target: .spotify)),
            ("toca música no Apple Music", .musicPlay(target: .appleMusic)),
            ("toca Anitta", .musicPlaySearch(name: "Anitta")),
            ("quero ouvir Djavan", .musicPlaySearch(name: "Djavan")),
            ("toca Aquarela do Brasil", .musicPlaySearch(name: "Aquarela do Brasil")),
            ("toca a playlist Foco", .musicPlayPlaylist(name: "Foco")),
            ("toca minha playlist de treino", .musicPlayPlaylist(name: "treino")),
            ("toca a playlist", .musicPlayPlaylist(name: "")),
            ("pausa a música", .musicPause),
            ("pause", .musicPause),
            ("pare", .musicPause),
            ("para a música", .musicPause),
            ("põe em pausa", .musicPause),
            ("pode pausar, por favor", .musicPause),
            ("próxima música", .musicNext),
            ("pula essa", .musicNext),
            ("passa para a próxima", .musicNext),
            ("troca de música", .musicNext),
            ("música anterior", .musicPrevious),
            ("volta uma música", .musicPrevious),
            ("aumenta o volume", .musicVolumeUp),
            ("sobe o som", .musicVolumeUp),
            ("mais alto", .musicVolumeUp),
            ("abaixa o volume", .musicVolumeDown),
            ("diminui o som", .musicVolumeDown),
            ("mais baixo", .musicVolumeDown),
            ("coloca o volume em 40", .musicSetVolume(40)),
            ("volume 80", .musicSetVolume(80)),
            ("volume para 100 por cento", .musicSetVolume(100)),
            // apps
            ("abre o Figma", .openApp(name: "Figma")),
            ("você pode abrir o app do Slack?", .openApp(name: "Slack")),
            ("abre o Google Chrome", .openApp(name: "Google Chrome")),
            // web search
            ("pesquisa na internet quem ganhou o jogo ontem", .webSearch(query: "quem ganhou o jogo ontem")),
            ("procura na web a cotação do dólar", .webSearch(query: "a cotação do dólar")),
            ("pesquisa na internet", .webSearch(query: "")),
        ])

        // Said with no accent, with fillers and with different politeness: the same intent.
        check("sem acento", IntentParser.parse("proxima musica", pills: pills), .musicNext)
        check("ok então toca", IntentParser.parse("então toca uma música aí", pills: pills), .musicPlay(target: nil))
        check("pra mim", IntentParser.parse("adiciona o GitHub pra mim", pills: pills), .pillAdd(id: "integration_github"))
        check("uppercase", IntentParser.parse("ADICIONA O GITHUB", pills: pills), .pillAdd(id: "integration_github"))
        check("unknown tab", IntentParser.parse("adiciona o Banana", pills: pills), .unknown)
        check("verb with no name is left to the runner", KoncluiVoicePT.parse("adiciona", pills: pills), nil)

        // The e-mail.
        let mail = KoncluiVoicePT.parse("manda um e-mail para a Tana", pills: pills)
        check("mail to a name", mail, .mail(.init(recipient: "Tana", file: nil, folder: nil)))
        let bare = KoncluiVoicePT.parse("quero mandar um e-mail", pills: pills)
        check("guided mail", bare, .mail(.init(recipient: "", file: nil, folder: nil)))
        if case .mail(let m)? = KoncluiVoicePT.parse("manda um e-mail pra Tana dizendo que a imagem está pronta", pills: pills) {
            check("mail: recipient", m.recipient, "Tana")
            check("mail: instruction", m.instruction, "a imagem está pronta")
        } else { check("mail with instruction", false, true) }
        if case .mail(let m)? = KoncluiVoicePT.parse("envia o arquivo fatura de outubro dos downloads para a Tana com assunto Fatura de outubro", pills: pills) {
            check("mail file: recipient", m.recipient, "Tana")
            check("mail file: name", m.file, "fatura")
            check("mail file: folder", m.folder, .downloads)
            check("mail file: subject", m.subject, "Fatura de outubro")
        } else { check("mail with a file", false, true) }
        if case .mail(let m)? = KoncluiVoicePT.parse("manda o e-mail para tana arroba gmail ponto com assunto Olá", pills: pills) {
            check("mail spoken address", m.recipient, "tana@gmail.com")
            check("mail subject keeps its words", m.subject, "Olá")
        } else { check("mail with a spoken address", false, true) }
        check("escreve alone is not a mail", KoncluiVoicePT.parse("escreve uma mensagem", pills: pills), nil)
    }

    // MARK: Questions

    static func questionTests() {
        func topic(_ said: String) -> VoiceIntent? { KoncluiVoicePT.parse(said, pills: pills) }
        let cases: [(String, VoiceTopic)] = [
            ("quantas estrelas eu tenho no GitHub?", .github),
            ("quantos PRs abertos eu tenho?", .github),
            ("quanto eu vendi hoje?", .stripe),
            ("como está o saldo do Stripe?", .stripe),
            ("algum deploy falhou?", .vercel),
            ("como está meu último deploy na Vercel?", .vercel),
            ("quantos e-mails eu enviei?", .resend),
            ("o workflow do n8n rodou?", .n8n),
            ("qual a última página do Notion?", .notion),
            ("qual é a minha próxima reunião?", .calcom),
            ("como está meu plano do Claude?", .claudePlan),
            ("quanto eu já usei do Codex? como está o plano?", .codexPlan),
            ("o que está rodando agora?", .agents),
            ("o que o Claude está fazendo?", .agents),
            ("como estão os meus agentes?", .agents),
            ("qual música está tocando?", .music),
            ("o que está tocando?", .music),
            ("quais abas estão ativas?", .pills),
            ("vai chover hoje?", .weatherToday),
            ("como está o tempo?", .weatherToday),
            ("qual a previsão do tempo para amanhã", .weatherTomorrow),
            ("vai fazer calor amanhã?", .weatherTomorrow),
        ]
        for (said, want) in cases { check("\"\(said)\"", topic(said), .query(want)) }
        check("a command is not a question", KoncluiVoicePT.parse("adiciona o GitHub", pills: pills), .pillAdd(id: "integration_github"))
        check("mostra o GitHub adds a tab", KoncluiVoicePT.parse("mostra o GitHub", pills: pills), .pillAdd(id: "integration_github"))
        check("me mostra asks", KoncluiVoicePT.parse("me mostra as estrelas do GitHub", pills: pills), .query(.github))
        check("question starter", KoncluiVoicePT.looksLikeQuestion(["quem", "ganhou", "ontem"], endsWithQuestionMark: false), true)
        check("o que", KoncluiVoicePT.looksLikeQuestion(["o", "que", "e", "um", "buraco", "negro"], endsWithQuestionMark: false), true)
        check("request is not a question", KoncluiVoicePT.looksLikeQuestion(["voce", "pode", "abrir", "o", "figma"], endsWithQuestionMark: true), false)
        check("not Portuguese", KoncluiVoicePT.looksLikeQuestion(["what", "is", "a", "black", "hole"], endsWithQuestionMark: false), nil)
        check("VoiceQuery sees it", VoiceQuery.looksLikeQuestion("quem ganhou o jogo ontem"), true)
        check("VoiceQuery request", VoiceQuery.looksLikeQuestion("você pode abrir o Figma"), false)
    }

    // MARK: French and English stay with upstream

    static func englishAndFrenchUntouchedTests() {
        let phrases = [
            "add GitHub", "remove Vercel", "pause", "stop", "next track", "play some music", "volume 50", "turn up",
            "open Figma", "can you add Stripe and Notion", "keep only GitHub and Vercel", "make Cursor my main pill",
            "search the web for the weather in Paris", "how many stars on GitHub?", "what's playing?", "will it rain tomorrow?",
            "ajoute GitHub", "enlève Vercel", "mets en pause", "morceau suivant", "monte le son", "ouvre Figma",
            "tu peux ajouter Stripe et Notion", "garde seulement GitHub et Vercel", "mets Cursor en principal",
            "cherche sur internet la météo à Paris", "combien d'étoiles sur GitHub ?", "il fait quoi Claude ?",
            "mets la playlist Workout", "lance Spotify", "joue Daft Punk", "remplace n8n par GitHub", "send an email to Tana",
            "envoie un mail à Tana", "what is the capital of France",
        ]
        for said in phrases { check("not Portuguese: \"\(said)\"", KoncluiVoicePT.parse(said, pills: pills), nil) }
        check("parseMulti leaves English alone", KoncluiVoicePT.parseMulti("pause and add GitHub", pills: pills), nil)
        check("relative English untouched", KoncluiVoicePT.relativeForm("also vercel"), "also vercel")
        check("relative French untouched", KoncluiVoicePT.relativeForm("et vercel aussi"), "et vercel aussi")
    }

    // MARK: Several commands

    static func multiActionTests() {
        func multi(_ s: String) -> [VoiceIntent]? { IntentParser.parseMultiAction(s, pills: pills) }
        check("pausa e adiciona", multi("pausa a música e adiciona o GitHub"), [.musicPause, .pillAdd(id: "integration_github")])
        check("vírgula", multi("tira o Vercel, adiciona o Stripe"), [.pillRemove(id: "integration_vercel"), .pillAdd(id: "integration_stripe")])
        check("verbo sem e", multi("adiciona o Stripe tira o n8n"), [.pillAdd(id: "integration_stripe"), .pillRemove(id: "integration_n8n")])
        check("depois", multi("toca uma música depois aumenta o volume"), [.musicPlay(target: nil), .musicVolumeUp])
        check("toca a próxima", multi("aumenta o volume e toca a próxima"), [.musicVolumeUp, .musicNext])
        check("bota pra tocar is one", multi("bota pra tocar"), nil)
        check("one multi-add is not several", multi("adiciona o GitHub e o Vercel"), nil)
        check("one search is not several", multi("toca Simon e Garfunkel"), nil)
        check("single command", multi("pausa a música"), nil)
        check("one part unknown", multi("pausa a música e fica quieta"), nil)
    }

    // MARK: Spoken answers

    @MainActor
    static func answerTests() async {
        let info = PtInfo()
        for topic in VoiceTopic.allCases {
            let pt = await info.answer(topic, locale: Locale(identifier: "pt-BR"))
            let en = await info.answer(topic, locale: Locale(identifier: "en-US"))
            check("\(topic) has a Portuguese answer", !pt.isEmpty && pt != en, true)
            check("\(topic) is not French", pt.contains("Aujourd") || pt.contains(" il y a "), false)
            check("\(topic) has no blank left", pt.contains("{"), false)
        }
        let stripe = await info.answer(.stripe, locale: Locale(identifier: "pt-BR"))
        check("stripe pt", stripe, "Hoje: R$ 385,00, de 3 pagamentos. Saldo: R$ 1.240,00.")
        let github = await info.answer(.github, locale: Locale(identifier: "pt-BR"))
        check("github pt", github, "Você tem 128 estrelas em 12 repositórios. 2 PRs abertas, 1 com a CI falhando. 1 esperando a sua revisão. A CI de koru está vermelha.")
        let agents = await info.answer(.agents, locale: Locale(identifier: "pt-BR"))
        check("agents pt", agents, "Claude Code está trabalhando : Edit IntentParser.swift.")
        let weather = await info.answer(.weatherTomorrow, locale: Locale(identifier: "pt-BR"))
        check("weather pt", weather, "Amanhã em São Paulo: chuva, de 17 a 25 graus. 70% de chance de chuva.")
        check("english untouched", await info.answer(.music, locale: Locale(identifier: "en-US")), "It's Aquarela by Toquinho.")
        check("french untouched", await info.answer(.music, locale: Locale(identifier: "fr-FR")), "C'est Aquarela, de Toquinho.")
        check("states", VoiceAnswer.stateText("approval", language: .pt), "está esperando a sua autorização")
        check("states en", VoiceAnswer.stateText("approval", language: .en), "is waiting for your approval")
        check("wmo pt", VoiceAnswer.weatherText(95, language: .pt), "trovoadas")
        check("wmo fr", VoiceAnswer.weatherText(95, language: .fr), "orages")
        check("not connected", VoiceAnswer.text(.stripe, { var s = VoiceSnapshot(); s.configured = false; return s }(), language: .pt),
              "Stripe não está conectado nos Ajustes do Koncluí.")
        check("french wrapper", VoiceAnswer.text(.music, PtInfo.snapshot(.music), french: true), "C'est Aquarela, de Toquinho.")
    }

    // MARK: The runner speaks Portuguese

    @MainActor
    static func runnerFlowTests() async {
        let runner = VoiceActionRunner()
        let music = PtMusic(), tabs = PtPills(), info = PtInfo()
        runner.music = music; runner.pills = tabs; runner.info = info
        runner.commandLocale = VoiceLanguage.pt.locale

        let start = await runner.run(.mail(.init(recipient: "", file: nil, folder: nil)), availablePills: pills)
        check("mail: who", start.message, "Para quem eu envio? Diga um nome ou um endereço de e-mail.")
        let unknown = await runner.handleAnswer("é o Fulano", availablePills: pills)
        check("mail: unknown contact", unknown.message, "Não encontro Fulano nos seus contatos. Qual é o endereço de e-mail?")
        let who = await runner.handleAnswer("é pra Tana", availablePills: pills)
        check("mail: subject", who.message, "Qual é o assunto?")
        let subject = await runner.handleAnswer("o assunto é Fatura de outubro", availablePills: pills)
        check("mail: text", subject.message, "O que o e-mail deve dizer? Eu escrevo para você.")
        let body = await runner.handleAnswer("diz que a fatura está pronta", availablePills: pills)
        check("mail: attachment", body.message, "Algum anexo? Arraste para o notch, ou diga não.")
        let done = await runner.handleAnswer("não", availablePills: pills)
        check("mail: card", done.message, "Aqui está o seu e-mail. Confira e clique em Enviar.")
        check("mail: card address", info.card?.to, "tana@example.com")
        check("mail: card subject", info.card?.subject, "Fatura de outubro")
        check("mail: card text", info.card?.body.contains("fatura está pronta"), true)

        _ = await runner.run(.mail(.init(recipient: "", file: nil, folder: nil)), availablePills: pills)
        let cancelled = await runner.handleAnswer("cancela", availablePills: pills)
        check("mail: cancelled", cancelled.message, "Tudo bem, cancelei o e-mail.")

        let web = await runner.run(.webSearch(query: ""), availablePills: pills)
        check("web: what", web.message, "O que eu pesquiso?")
        runner.pendingQuestion = nil

        check("yes", VoiceActionRunner.isYes("sim, claro"), true)
        check("yes: pode ser", VoiceActionRunner.isYes("pode ser"), true)
        check("no", VoiceActionRunner.isNo("não precisa"), true)
        check("no is not yes", VoiceActionRunner.isYes("não"), false)
        check("cancel", VoiceActionRunner.cancelsMail("deixa pra lá"), true)

        // Offering and switching the answer language.
        runner.commandLocale = VoiceLanguage.en.locale
        check("offer pt from en", runner.offerLanguageSwitch(to: "pt"), "By the way, you're speaking Portuguese. Want me to answer in Portuguese?")
        let yes = await runner.handleAnswer("yes", availablePills: pills)
        check("switched to pt", yes.message, "Combinado, a partir de agora eu respondo em português.")
        check("locale follows", VoiceLanguage(locale: runner.commandLocale), .pt)
        check("offer en from pt", runner.offerLanguageSwitch(to: "en"), "Aliás, você está falando inglês. Quer que eu responda em inglês?")
        let no = await runner.handleAnswer("não", availablePills: pills)
        check("kept pt", no.message, "Tudo bem, continuo respondendo em português.")
        runner.commandLocale = VoiceLanguage.fr.locale
        check("offer fr from fr", runner.offerLanguageSwitch(to: "fr"), "Tu veux que je te réponde en français ?")
        runner.commandLocale = VoiceLanguage.en.locale
        check("offer en from en", runner.offerLanguageSwitch(to: "en"), "Want me to answer in English?")
        check("incomplete add", runner.askIfIncomplete("adiciona")?.outcome != nil, true)
        runner.pendingQuestion = nil
        check("incomplete remove", runner.askIfIncomplete("tira")?.outcome != nil, true)
        runner.pendingQuestion = nil
        check("incomplete nothing", runner.askIfIncomplete("toca uma música")?.outcome == nil, true)

        // Web answers go through the language version of the provider; an older provider gets the Bool.
        let modern = TestWebInfo(), legacy = LegacyWebInfo()
        runner.info = modern
        runner.commandLocale = VoiceLanguage.pt.locale
        _ = await runner.run(.webSearch(query: "quem ganhou"), availablePills: pills)
        check("web: language reaches the provider", modern.languages, [.pt])
        runner.info = legacy
        runner.commandLocale = VoiceLanguage.fr.locale
        _ = await runner.run(.webSearch(query: "qui a gagné"), availablePills: pills)
        runner.commandLocale = VoiceLanguage.pt.locale
        _ = await runner.run(.webSearch(query: "quem ganhou"), availablePills: pills)
        check("web: an older provider gets a Bool", legacy.frenchFlags, [true, false])
    }

    // MARK: The small hooks

    @MainActor
    static func hookTests() {
        // Conversation: follow-ups and the end of a turn.
        var context = ConversationContext()
        context.update(.pillAdd(id: "integration_github"))
        check("e o Vercel também", context.resolveRelative("e o Vercel também", pills: pills), .pillAdd(id: "integration_vercel"))
        check("também o Stripe", context.resolveRelative("também o Stripe", pills: pills), .pillAdd(id: "integration_stripe"))
        check("igual para o Notion", context.resolveRelative("igual para o Notion", pills: pills), .pillAdd(id: "integration_notion"))
        check("desfaz", context.resolveRelative("desfaz", pills: pills), .pillRemove(id: "integration_github"))
        check("a command is not a follow-up", context.resolveRelative("adiciona o Stripe também", pills: pills), nil)
        for phrase in ["obrigado", "valeu", "tchau", "deixa pra lá", "esquece", "cancela", "pare"] {
            check("ends the turn: \(phrase)", TurnEndPolicy.conversationEndPhrases.contains(phrase), true)
        }
        check("waits after e", TurnEndPolicy.silenceDelay(for: "adiciona o github e"), TurnEndPolicy.extendedSilence)
        check("waits after adiciona", TurnEndPolicy.silenceDelay(for: "adiciona"), TurnEndPolicy.extendedSilence)
        check("does not wait after a name", TurnEndPolicy.silenceDelay(for: "adiciona o github"), TurnEndPolicy.baseSilence)

        // The wake word as a Brazilian recognizer writes it.
        check("ok koru", WakePhrase.split("ok koru adiciona o github").command, "adiciona o github")
        check("okei Kôru", WakePhrase.split("okei Kôru adiciona o github").matched, true)
        check("oquei Coru", WakePhrase.split("oquei Coru toca uma música").command, "toca uma música")
        check("hey Côru", WakePhrase.split("hey Côru pausa").command, "pausa")
        check("koru alone does not wake", WakePhrase.split("koru adiciona").matched, false)

        // The Mac voice and its gender.
        check("Luciana is a woman", VoiceGenderNames.gender(name: "Luciana", identifier: "x"), "female")
        check("Felipe is a man", VoiceGenderNames.gender(name: "Felipe (Aprimorado)", identifier: "x"), "male")
        let europeanPremium = KoncluiVoicePick.rank(language: "pt", quality: 3, exactRegion: false, name: "Joana")
        let brazilianCompact = KoncluiVoicePick.rank(language: "pt", quality: 1, exactRegion: true, name: "Eddy")
        let luciana = KoncluiVoicePick.rank(language: "pt", quality: 1, exactRegion: true, name: "Luciana (Compact)")
        check("Brazil beats a premium from Portugal", brazilianCompact > europeanPremium, true)
        check("Luciana beats the other Brazilian voices", luciana > brazilianCompact, true)
        let ava = KoncluiVoicePick.rank(language: "en", quality: 3, exactRegion: false, name: "Ava")
        let compactUS = KoncluiVoicePick.rank(language: "en", quality: 1, exactRegion: true, name: "Fred")
        check("English still ranks quality first", ava > compactUS, true)

        // Prompts.
        check("Apple Intelligence in Portuguese", KoncluiVoicePrompts.appleIntelligence.contains("português do Brasil"), true)
        check("Claude addendum: pt", KoncluiVoicePrompts.claudeAddendum(for: .pt).contains("Brazilian Portuguese"), true)
        check("Claude addendum: en is empty", KoncluiVoicePrompts.claudeAddendum(for: .en), "")
        check("Claude addendum: fr is empty", KoncluiVoicePrompts.claudeAddendum(for: .fr), "")
        check("web prompt carries the date", KoncluiVoicePrompts.webAnswer(today: "sexta-feira, 30 de outubro").contains("sexta-feira, 30 de outubro"), true)
        check("mail prompt", KoncluiVoicePrompts.mailRequest(to: "Tana", about: "agradecendo pela ontem"),
              "E-mail para Tana. O que eu quero dizer: agradecendo pela ontem")
        check("mail prompt without a name", KoncluiVoicePrompts.mailRequest(to: "", about: "x"), "E-mail. O que eu quero dizer: x")

        // E-mail text in Portuguese.
        check("Portuguese text", KoncluiVoicePT.looksPortuguese("avisa que a imagem está pronta e que amanhã eu envio o arquivo"), true)
        check("French text", KoncluiVoicePT.looksPortuguese("dis que l'image est prête pour demain"), false)
        check("English text", KoncluiVoicePT.looksPortuguese("tell her the image is ready for tomorrow"), false)
        check("simple mail in Portuguese", VoiceQuery.simpleMail(from: "avisa que a imagem está pronta"), "Olá,\n\nA imagem está pronta.\n\nAbraço,")
        check("simple mail in French", VoiceQuery.simpleMail(from: "faut dire que l'image est prête"), "Bonjour,\n\nL'image est prête.\n\nBonne journée !")
        check("recipient lead", VoiceQuery.recipientAnswer("é pro Tana"), "Tana")
        check("recipient: se chama", VoiceQuery.recipientAnswer("ela se chama Marina"), "Marina")
        check("subject lead", VoiceQuery.subjectAnswer("o assunto é Reunião de terça"), "Reunião de terça")
        check("no subject", VoiceQuery.subjectAnswer("sem assunto"), "")
        check("literal text", VoiceQuery.bodyAnswer("palavra por palavra: Oi Tana, tudo bem?").body, "Oi Tana, tudo bem?")
        check("instruction", VoiceQuery.bodyAnswer("avisa que a fatura está pronta").instruction, "a fatura está pronta")
        check("spoken address", VoiceQuery.spokenEmail("tana arroba gmail ponto com"), "tana@gmail.com")
        check("attachment answer", VoiceQuery.attachmentAnswer("sim, o arquivo fatura ponto pdf"), "fatura.pdf")
        check("contacts: o amigo Enzo", VoiceQuery.contactCandidates("o amigo Enzo").contains("Enzo"), true)
    }

    // MARK: Evidence

    @MainActor
    static func evidenceTable() async {
        let utterances = [
            "adiciona o GitHub nas abas", "tira o Vercel", "troca o n8n pelo GitHub", "deixa só o GitHub e a Vercel",
            "coloca o Cursor como aba principal", "você pode adicionar o Stripe e o Notion?", "toca uma música",
            "pausa a música", "próxima música", "aumenta o volume", "coloca o volume em 40", "abre o Figma", "pare",
            "quantas estrelas eu tenho no GitHub?", "o que está rodando agora?", "vai chover amanhã?",
            "quanto eu vendi hoje?", "como está meu plano do Claude?", "qual música está tocando?",
            "manda um e-mail para a Tana",
        ]
        print("\n| # | Disse | Intenção | Resposta falada |\n|---|---|---|---|")
        for (i, said) in utterances.enumerated() {
            let runner = VoiceActionRunner()
            runner.music = PtMusic(); runner.pills = PtPills(); runner.info = PtInfo()
            runner.commandLocale = VoiceLanguage.pt.locale
            let intent = IntentParser.parseMultiAction(said, pills: pills)?.first ?? IntentParser.parse(said, pills: pills)
            let result = await runner.run(intent, availablePills: pills, rawTranscript: said)
            let shown = "\(intent)".replacingOccurrences(of: "main.", with: "")
            print("| \(i + 1) | \(said) | `\(shown)` | \(result.message) |")
        }
    }
}

/// Knows the language, like LiveVoiceInfo.
@MainActor
final class TestWebInfo: VoiceInfoProviding {
    var languages: [VoiceLanguage] = []
    func answer(_ topic: VoiceTopic, locale: Locale?) async -> String { "" }
    func openApp(_ name: String, locale: Locale?) -> VoiceActionResult { .init(outcome: .failure, message: "") }
    func resolveEmail(_ recipient: String) async -> String? { nil }
    func findFile(_ name: String, folder: VoiceQuery.MailRequest.Folder?) -> URL? { nil }
    func draftBody(to recipient: String, about instruction: String) async -> String? { nil }
    func showMailCard(to address: String, subject: String, body: String, file: URL?) {}
    var webSearchEnabled: Bool { true }
    var hasWebKey: Bool { true }
    func webAnswer(_ question: String, history: [VoiceWebTurn], french: Bool) async -> String? { "ok" }
    func webAnswer(_ question: String, history: [VoiceWebTurn], language: VoiceLanguage) async -> String? {
        languages.append(language)
        return "ok"
    }
}

/// Only knows French and English, like the provider of upstream's tests: the default language version must reach it.
@MainActor
final class LegacyWebInfo: VoiceInfoProviding {
    var frenchFlags: [Bool] = []
    func answer(_ topic: VoiceTopic, locale: Locale?) async -> String { "" }
    func openApp(_ name: String, locale: Locale?) -> VoiceActionResult { .init(outcome: .failure, message: "") }
    func resolveEmail(_ recipient: String) async -> String? { nil }
    func findFile(_ name: String, folder: VoiceQuery.MailRequest.Folder?) -> URL? { nil }
    func draftBody(to recipient: String, about instruction: String) async -> String? { nil }
    func showMailCard(to address: String, subject: String, body: String, file: URL?) {}
    var webSearchEnabled: Bool { true }
    var hasWebKey: Bool { true }
    func webAnswer(_ question: String, history: [VoiceWebTurn], french: Bool) async -> String? {
        frenchFlags.append(french)
        return "ok"
    }
}
