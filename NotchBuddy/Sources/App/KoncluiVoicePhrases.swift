import Foundation

// Koncluí: what Koru says in Brazilian Portuguese (unit U5).
//
// Every spoken answer of upstream is written t("<French>", "<English>") (VoiceActionRunner, VoiceAnswer, VoiceDataSources).
// Portuguese is found here by the English sentence, each \( ) of it a "{}"; the Portuguese text names the values {1},
// {2}… in the order they appear in the English one, so a sentence may put them anywhere. A sentence with no entry is
// said in English. `scripts/konclui/voice-pt-templates.py --check` lists the sentences upstream added or reworded after
// a merge; this file is the only thing to extend.
//
// Voice of the texts: spoken Brazilian Portuguese, "você", short. The pills of the notch are "abas".

enum KoncluiVoicePhrases {

    /// The Portuguese of an English sentence with its values filled in, nil when it has no entry.
    static func portuguese(_ en: VoiceText) -> String? {
        guard let text = sentences[en.template] else { return nil }
        return fill(text, with: en.arguments.map { argumentWords[$0] ?? $0 })
    }

    /// "{1} está anexado." with ["Goku.png"] → "Goku.png está anexado."
    static func fill(_ text: String, with values: [String]) -> String {
        var out = ""
        var rest = Substring(text)
        while let open = rest.firstIndex(of: "{") {
            out += rest[..<open]
            let tail = rest[rest.index(after: open)...]
            if let close = tail.firstIndex(of: "}"), let n = Int(tail[..<close]), n >= 1, n <= values.count {
                out += values[n - 1]
                rest = tail[tail.index(after: close)...]
            } else {
                out += "{"
                rest = tail
            }
        }
        return out + rest
    }

    /// Words that upstream puts into a sentence as plain values (`\(r.ok ? "succeeded" : "failed")`).
    static let argumentWords: [String: String] = [
        "succeeded": "deu certo",
        "failed": "falhou",
    ]

    static let sentences: [String: String] = Dictionary(table, uniquingKeysWith: { first, _ in first })

    // BEGIN sentences
    static let table: [(String, String)] = [
        (" Active: {}.", " Ativas: {1}."),
        (" Balance: {}.", " Saldo: {1}."),
        (" Last one, “{}” to {}: {}.", " O último, “{1}” para {2}: {3}."),
        (" Last payment: {}, {} ago.", " Último pagamento: {1}, há {2}."),
        (" No other pill.", " Nenhuma outra aba."),
        (" Resets in {}.", " Reinicia em {1}."),
        (" The previous live one is from {} ago.", " O último que ficou no ar foi há {1}."),
        (" across {} repos", " em {1} repositórios"),
        (" and ", " e "),
        (" with {}", " com {1}"),
        (" {} in total.", " {1} no total."),
        (" {} recent failure{}.", " {1} falha{2} recente{2}."),
        (" {}% chance of rain.", " {1}% de chance de chuva."),
        (", {} with failing CI", ", {1} com a CI falhando"),
        ("A permission request is waiting for your click: {}.", "Um pedido de permissão está esperando o seu clique: {1}."),
        ("Any attachment? Drop it on the notch, or say no.", "Algum anexo? Arraste para o notch, ou diga não."),
        ("CI is red on {}.", "A CI de {1} está vermelha."),
        ("Done.", "Pronto."),
        ("Here's your email{}. Check it and click Send.", "Aqui está o seu e-mail{1}. Confira e clique em Enviar."),
        ("I can't find the app {}.", "Não encontro o app {1}."),
        ("I can't find {} in your contacts. What's the email address?", "Não encontro {1} nos seus contatos. Qual é o endereço de e-mail?"),
        ("I can't find “{}”. Drop it on the notch, or say no.", "Não encontro “{1}”. Arraste para o notch, ou diga não."),
        ("I can't get the weather right now.", "Não consegui ver a previsão do tempo agora."),
        ("I can't reach the web right now, try again in a moment.", "Não consegui acessar a internet agora, tente de novo daqui a pouco."),
        ("I don't have GitHub data yet.", "Ainda não tenho dados do GitHub."),
        ("I don't have Stripe data yet.", "Ainda não tenho dados do Stripe."),
        ("I don't have your {} plan usage yet.", "Ainda não tenho o uso do seu plano {1}."),
        ("In {}, {} degrees, {}. Between {} and {} today.", "Em {1}, {2} graus, {3}. Hoje, entre {4} e {5}."),
        ("It's {} by {}.", "É {1}, de {2}."),
        ("Last edited page: {}, {} ago.", "Última página editada: {1}, há {2}."),
        ("Last workflow: {}, {}, {} ago.", "Último workflow: {1}, {2}, há {3}."),
        ("Let me check.", "Deixa eu ver."),
        ("Main pill: {}.", "Aba principal: {1}."),
        ("Next booking: {}{}, {}.", "Próximo compromisso: {1}{2}, {3}."),
        ("No agent is working right now.", "Nenhum agente está trabalhando agora."),
        ("No recent Notion page.", "Nenhuma página recente no Notion."),
        ("No recent Vercel deployment.", "Nenhum deploy recente na Vercel."),
        ("No recent email sent with Resend.", "Nenhum e-mail enviado recentemente pelo Resend."),
        ("No recent n8n run.", "Nenhuma execução recente no n8n."),
        ("No sales yet today.", "Nenhuma venda hoje até agora."),
        ("No upcoming booking.", "Nenhum compromisso marcado."),
        ("Nothing is playing right now.", "Nada está tocando agora."),
        ("Nothing new on GitHub.", "Nada de novo no GitHub."),
        ("Okay, I cancelled the email.", "Tudo bem, cancelei o e-mail."),
        ("Opening {}.", "Abrindo {1}."),
        ("Set your city in Koncluí's settings, Voice section.", "Informe a sua cidade nos Ajustes do Koncluí, na seção Voz."),
        ("The last {} deployment {}, {} ago.", "O último deploy de {1} {2}, há {3}."),
        ("To search the web, add your Anthropic API key in Settings, then turn on web search in Voice.", "Para pesquisar na internet, adicione a sua chave de API da Anthropic nos Ajustes e ative a pesquisa na web em Voz."),
        ("Today in {}: {}, {} to {} degrees.", "Hoje em {1}: {2}, de {3} a {4} graus."),
        ("Today: {} from {} payment{}.", "Hoje: {1}, de {2} pagamento{3}."),
        ("Tomorrow in {}: {}, {} to {} degrees.", "Amanhã em {1}: {2}, de {3} a {4} graus."),
        ("Turn on weather in Koncluí's settings, Voice section.", "Ative a previsão do tempo nos Ajustes do Koncluí, na seção Voz."),
        ("Web search is off. Turn it on in Settings, Voice.", "A pesquisa na web está desligada. Ative em Ajustes, Voz."),
        ("What should I look up?", "O que eu pesquiso?"),
        ("What should the email say? I'll write it for you.", "O que o e-mail deve dizer? Eu escrevo para você."),
        ("What's the subject?", "Qual é o assunto?"),
        ("Who should I send it to? Say a name or an email address.", "Para quem eu envio? Diga um nome ou um endereço de e-mail."),
        ("You have {} star{}{}.", "Você tem {1} estrela{2}{3}."),
        ("Your Stripe balance is {}.", "Seu saldo no Stripe é de {1}."),
        ("failed", "falhou"),
        ("is in progress", "está em andamento"),
        ("is live", "está no ar"),
        ("was canceled", "foi cancelado"),
        ("{} emails sent in total.", "{1} e-mails enviados no total."),
        ("{} is attached. Just click Send.", "{1} está anexado. É só clicar em Enviar."),
        ("{} isn't connected in Koncluí's settings.", "{1} não está conectado nos Ajustes do Koncluí."),
        ("{} open PR{}", "{1} PR{2} aberta{2}"),
        ("{} plan: ", "Plano {1}: "),
        ("{} waiting for your review.", "{1} esperando a sua revisão."),
        ("{}% of the 5-hour window", "{1}% da janela de 5 horas"),
        ("{}% of the week", "{1}% da semana"),
    ]
    // END sentences
}

// MARK: - Words that are not a sentence

extension VoiceAnswer {

    /// What an agent session is doing, in French, English or Portuguese.
    static func stateText(_ state: String, language: VoiceLanguage) -> String {
        guard language == .pt else { return stateText(state, fr: language == .fr) }
        switch state {
        case "working":   return "está trabalhando"
        case "thinking":  return "está pensando"
        case "searching": return "está pesquisando"
        case "approval":  return "está esperando a sua autorização"
        case "question":  return "tem uma pergunta para você"
        case "error":     return "deu erro"
        case "finished":  return "terminou"
        case "ratelimit": return "atingiu o limite"
        default:          return "está ativo"
        }
    }

    /// WMO weather codes (Open-Meteo), in French, English or Portuguese.
    static func weatherText(_ code: Int, language: VoiceLanguage) -> String {
        guard language == .pt else { return weatherText(code, fr: language == .fr) }
        switch code {
        case 0:                  return "céu limpo"
        case 1, 2:               return "poucas nuvens"
        case 3:                  return "nublado"
        case 45, 48:             return "neblina"
        case 51, 53, 55, 56, 57: return "garoa"
        case 61, 63, 66:         return "chuva"
        case 65, 67:             return "chuva forte"
        case 71, 73, 75, 77:     return "neve"
        case 80, 81:             return "pancadas de chuva"
        case 82:                 return "pancadas fortes de chuva"
        case 85, 86:             return "pancadas de neve"
        case 95, 96, 99:         return "trovoadas"
        default:                 return "tempo variável"
        }
    }
}
