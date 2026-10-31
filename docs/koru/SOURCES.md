# Fontes, observações e limites

[Índice](README.md) · Consultas realizadas em 2026-10-30.

As referências locais abaixo foram lidas sem acessar credenciais, `.env`, bases de produção ou dados pessoais de clientes. Hashes identificam o HEAD observado, não comprovam checkout limpo nem implantação em produção. Os caminhos são relativos ao repositório nomeado; eles não existem necessariamente dentro do checkout `coucou`.

<a id="l1-plataforma-konclui"></a>

## L1. Plataforma Koncluí

Repositório local: `konclui-project/konclui-platform`, HEAD observado `ba01f139e`.

| Caminho dentro da plataforma | Evidência usada |
|---|---|
| `README.md` | Apps web, admin, API, billing, agentes IA e Flutter em `apps/mobile` |
| `apps/bi-mcp/README.md` | MCP BI separado, somente leitura, grants, fontes e desenho `BYPASSRLS` |
| `apps/bi-mcp/src/mcp/mcp-server.factory.ts` | Quatro ferramentas; chamada de `run_query` para execução sem identidade no argumento de escopo |
| `apps/bi-mcp/src/datasources/query.service.ts` | `executar(datasource, sqlBruto)` e controles de consulta |
| `apps/bi-mcp/src/auth/bi-auth.service.ts` | Identidade administrativa e revalidação do vínculo |
| `specs/20260728-internal-bi-mcp/spec.md` | Intenção de acesso interno de líderes, somente leitura e OAuth |
| `docs/architecture/ADR-0037-ai-credit-wallet.md` | Contexto e decisão de carteira por workspace; contrato inicial por análise de evidência |
| `apps/ai-agents/src/services/ai_credit_wallet.py` | Consumo com idempotência e ator; distingue falta de saldo e falta de direito |
| `supabase/schema/tables/ai_credit_usage.sql` | Quantidade inteira positiva, workspace, feature, referência, idempotência e usuário |

**Limite:** inspeção localizada de contratos e código, não auditoria completa. Não comprova escopo fino por funcionário/área, implantação, esquema efetivo de produção, preços atuais de todos os recursos ou reserva financeira. O ADR histórico da plataforma não deve ser sobrescrito pelos ADRs deste checkout.

<a id="l2-personagem-koru"></a>

## L2. Personagem Koru

Repositório: `konclui-project/koru`, HEAD observado `1249875`.

`docs/playbook.md` define a Koru como guia calma, precisa e discreta; rejeita culpa, vigilância e papel punitivo. Define presença breve, som opcional e respeito à tarefa. A composição artística aprovada pelo dono continua sendo autoridade; esta documentação não muda identidade, geometria ou arte.

## L3. Coucou e protótipo Alexa

Checkout ativo: `study/coucou`, HEAD observado antes desta documentação `65c00b8`.

- [CLAUDE.md](../../CLAUDE.md): arquitetura e limites locais, inclusive ausência de telemetria e confirmação por clique para ações específicas.
- [README.md](../../README.md), [VOICE.md](../VOICE.md), [INTEGRATIONS.md](../INTEGRATIONS.md): referências de capacidades do Coucou, sem assumir integração com Koncluí.
- [Protótipo Alexa](../../alexa/README.md): skill local, sons e arte, testes descritos e ativação pendente.
- [Sons](../../design/prototype/koru/docs/SOUND.md): identidade sonora e importação de coruja/venda.

Não houve reexecução dos testes de implementação da Alexa nesta tarefa documental. Os resultados relatados anteriormente continuam históricos, não uma nova validação de dispositivo.

## L4. Escritório Koncluí

Repositório: `konclui-project/konclui-work`, `README.md`, seção de interações do campus. Documenta o sino de venda e a origem do áudio em `media/sounds/sale.mp3`, que já inclui coruja; gravações separadas estão em `art/sale-sounds`.

Serve de referência de identidade e celebração. O fluxo interno de venda não é automaticamente uma funcionalidade útil ou integrada a todo cliente Koncluí.

## L5. Grok Bot

O usuário indicou o Grok Bot como referência de experiência. O README local em `grok-bot/konclui/README.md` descreve organização de conhecimento e repositórios; não especifica a experiência de voz em tempo real. Não foi auditado o produto completo nem executado outro modelo.

A referência técnica pública consultada é [WebRTC Voice Agent, documentação xAI](https://docs.x.ai/cookbook/examples/voice-agent-webrtc): exemplo de áudio bidirecional, transcrição, interrupção e acompanhamento de conexão. O próprio exemplo exige trabalho adicional para produção. Não foi escolhido um fornecedor para a Koru.

## Fontes técnicas externas

| Fonte primária | Uso neste material |
|---|---|
| [MCP Security Best Practices](https://modelcontextprotocol.io/docs/2025-11-25/tutorials/security/security_best_practices) | Escopos, credenciais, token passthrough, servidores externos e risco de instruções maliciosas |
| [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) | Restrições de background e transparência no uso de microfone; não prova de uma arquitetura específica |
| [Android: background foreground-service restrictions](https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start) | Restrições de microfone e inicialização de serviços com exceções específicas |
| [Amazon: invocation](https://developer.amazon.com/en-US/docs/alexa/custom-skills/understanding-how-users-invoke-custom-skills.html) | Distinção entre ativar Alexa e abrir uma skill |
| [Amazon: sessions](https://developer.amazon.com/en-US/docs/alexa/custom-skills/manage-skill-session-and-session-attributes.html) | Sessão de skill e continuidade de interação |
| [Amazon: account linking](https://developer.amazon.com/en-US/docs/alexa/devconsole/build-your-skill.html) | Vinculação da conta Koncluí à experiência Alexa |
| [Amazon: proactive events](https://developer.amazon.com/en-US/docs/alexa/smapi/proactive-events-api.html) | Permissões, limites e categorias de notificações |
| [Amazon Silk](https://docs.aws.amazon.com/silk/latest/developerguide/) | Navegador como alternativa visual no Echo Show |

Os repositórios comunitários de Echo foram pesquisados na conversa anterior e estão ligados em [plataformas](PLATFORMS.md). São relatos e implementações dos respectivos autores; não são certificações da Amazon nem validação em hardware da Koncluí.

## Pesquisa Duolingo

O registro D01–D19 em [GAMIFICATION.md](GAMIFICATION.md) é o catálogo de fontes oficiais consultadas. Inclui material de produto, ajuda, engenharia e duas publicações de pesquisa: o relatório de método de 2023 e o artigo KDD 2020 de notificações.

As quatro referências enviadas pelo usuário foram incorporadas diretamente: `results-duolingo-efficacy-studies` (D17), `how-duolingo-streak-builds-habit` (D03), `research.duolingo.com` (D18) e `dataset-development` (D19). Eficácia, formação de hábito e engenharia de dados têm aplicações e limites separados na proposta.

Não foram copiados artigos integrais ou imagens. Os documentos sintetizam mecanismos e registram propostas próprias. Publicações históricas podem coexistir com funcionalidades mais novas: Hearts/Energy, pareamento de Friends Quests e nomes de recompensas são exemplos. O conteúdo mais recente não prova disponibilidade uniforme para toda a base.

## Atualização das evidências

Em 2026-10-30, `konclui-platform/apps/mobile/pubspec.yaml` e `apps/mobile/lib/main.dart` foram consultados em modo somente leitura, HEAD `ba01f139e`: confirmam base Dart/Flutter e entrada com inicialização de backend, sessão, conectividade e runtime offline. Não foi executado build nem comprovada integração Koru. A consequência está no [ADR-007](../konclui/decisions/ADR-007-koru-mobile-evolution.md).

As novas referências enviadas pelo usuário foram deduplicadas e triadas em [Duolingo: produto e engenharia](../../.feature-radar/references/duolingo-engineering.md): 15 artigos e 5 repositórios, sem auditoria integral de código ou reprodução dos resultados. Os portais de sete outras empresas e o protocolo de continuidade estão em [fontes de engenharia](../../.feature-radar/references/engineering-watchlist.md). Consultar uma fonte não equivale a adotar sua tecnologia; não há monitoramento automático ativo.

Antes de implementar, conferir HEAD e contratos dos repositórios donos; rever documentação dos sistemas-alvo, preços, disponibilidade de APIs e fontes Duolingo. Se uma fonte mudar, preservar o motivo da decisão anterior no ADR e registrar a revisão. A data de consulta não transforma uma hipótese em resultado validado.

## Revisão visual dos artigos

Por orientação do usuário, a pesquisa inclui todas as imagens dos artigos. O [inventário visual Duolingo](../../.feature-radar/references/duolingo-visual-review.md) registra 149 ocorrências em 28 artigos, observações e limites. O [protocolo de acompanhamento](../../.feature-radar/references/engineering-watchlist.md) exige inspeção visual, rastreabilidade e registro de pendências nas próximas leituras.
