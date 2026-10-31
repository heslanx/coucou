# Feature Radar — Koru

**Status**: Base aprovada pelo usuário em 2026-10-30; prioridades propostas para detalhamento
**Mode**: full
**Updated**: 2026-10-30
**Workflow**: Fases 1–6 concluídas na análise documental; ver [avaliação e propostas](review.md). Implementação não iniciada.

## Project Context

### Escopo de produto

O radar acompanha a **Koru como gerente operacional no bolso**, para donos, gestores, operadores e equipe interna Koncluí. Sua fonte de direção é [a documentação de produto](../docs/koru/README.md) e o pedido do usuário. O checkout ativo é Coucou, em `study/coucou`: hospeda referências de aplicativos, personagem, protótipo Alexa e a documentação da futura Koru. O objetivo não é priorizar indiscriminadamente todas as funcionalidades do Coucou.

O produto pretendido conecta processos e aplicativos por MCP, respeita acesso por pessoa/workspace, consome créditos de IA do workspace e oferece interação adaptada a desktop, celular, tablet, web e Echo Show. Voz em tempo real, ativação por palavra, alertas e gamificação têm dependências e validações próprias. Não estão comprovados como experiência integrada.

### Linguagens e arquitetura observadas

**Esclarecimento do usuário:** o app mobile existente em `konclui-platform/apps/mobile` é Flutter e deve ser considerado como caminho inicial provável para integrar a Koru. Experimentos nativos continuam em paralelo neste checkout. Não existe compromisso de reescrita nem prazo de abandono do Flutter. Ver [ADR-007](../docs/konclui/decisions/ADR-007-koru-mobile-evolution.md).

| Área | Manifesto / entrada consultados | Arquitetura observada |
|---|---|---|
| macOS | `NotchBuddy/project.yml`, `NotchBuddy/Sources/App/NotchBuddyApp.swift` | Swift 6, SwiftUI/AppKit; AppDelegate e Settings; geração por XcodeGen |
| iPhone | `NotchBuddy/Sources/Phone/CoucouPhoneApp.swift` | SwiftUI, PhoneLink, CloudKit e notificações; atualização ao ativar a cena |
| Windows/Linux | `windows/package.json`, `windows/src-tauri/Cargo.toml`, `windows/src/main.ts` | TypeScript/Vite e Tauri 2/Rust; ponte nativa, ilha, eventos e integrações |
| Android | `android/app/build.gradle.kts`, `android/app/src/main/kotlin/com/coucou/android/MainActivity.kt` | Kotlin, Jetpack Compose, Gradle; cliente separado |
| Relay iPhone | `relay/package.json`, `relay/src/index.ts` | Worker TypeScript; rota de Live Activity para APNs |
| Alexa | `alexa/package.json`, `alexa/lambda/index.js` | Handler Node.js CommonJS, APL e modelo de interação pt-BR |
| Produto Koncluí | Evidências anteriores em [SOURCES.md](../docs/koru/SOURCES.md) | Plataforma externa com API, agentes, carteira e MCP BI; não é backend integrado deste checkout |
| Mobile Koncluí existente | `konclui-platform/apps/mobile/pubspec.yaml`, `apps/mobile/lib/main.dart`, HEAD `ba01f139e` | Dart/Flutter; entrada inicializa backend, sessão, conectividade e runtime offline. Inspeção somente leitura; Koru ainda não comprovada nesse fluxo |

Não há manifesto raiz único que descreva todo o produto. A presença de dependências já existentes não autoriza adicionar novas. O uso desses componentes não decide o framework da futura Koru.

### Mapa do checkout

| Diretório | Responsabilidade / evidência |
|---|---|
| `NotchBuddy/Sources/App/` | Entrada macOS, UI, servidor de hooks e integrações |
| `NotchBuddy/Sources/CoucouKit/` | Código compartilhado, incluindo estados/animações de BotEngine |
| `NotchBuddy/Sources/Phone/` | Entrada iPhone, vínculo, sessões e decisões |
| `windows/src/`, `windows/src-tauri/`, `windows/hook/` | UI desktop, backend nativo e relay de hooks |
| `android/` | App e configuração Android; relay próprio em `android/relay/` |
| `relay/` | Worker de Live Activities, separado do relay Android |
| `alexa/` | Handler, APL, modelo de fala, mídia, empacotamento e testes Node |
| `design/` | Arte e protótipos, incluindo referências da Koru |
| `docs/koru/`, `docs/konclui/decisions/` (ADR-003 to ADR-007) | Visão, contratos propostos, pesquisa, UX e ADRs da Koru |
| `docs/` | Especificações e guias existentes do Coucou |
| `scripts/`, `windows/tests/`, `alexa/test/` | Verificações existentes; não executadas neste bootstrap documental |

### Filosofia e limites

- Entregar clareza e avanço operacional; crescimento, lucro e liberdade são objetivos a medir.
- Koru calma e útil, sem pressão por uso, vigilância punitiva ou exposição de funcionários.
- Permissão é imposta no servidor; identidade de dispositivo não substitui identidade de pessoa.
- Créditos de IA não são pontos; gasto não prova valor, hábito nem trabalho realizado.
- Não declarar sucesso de ação sem confirmação na origem; preservar recuperação e autoria.
- Respeitar regras locais do Coucou: sem telemetria adicionada, preservar interfaces existentes e exigir clique para envio de e-mail/aprovação de permissões.
- Não alterar outros repositórios, instalar no Echo, publicar, modificar cobrança ou escolher dependências ao priorizar.

### Fontes de inspiração e demanda

README e CONTRIBUTING apresentam Coucou/Mochi, integrações, hooks e referências de ditado como Wispr Flow e FluidAudio. São referências locais; este bootstrap não verificou versões externas ou superioridade comercial.

Os documentos da Koru registram Duolingo (hábito e pesquisa), Grok Bot (referência desejada de fluidez), Alexa/APL e projetos comunitários EchoLocal, TECHO5 e echo-show-claude. Os links e limites estão em [SOURCES.md](../docs/koru/SOURCES.md), [PLATFORMS.md](../docs/koru/PLATFORMS.md) e [GAMIFICATION.md](../docs/koru/GAMIFICATION.md). Revalidar fontes externas quando fundamentarem uma decisão atual de prioridade ou implementação.

A demanda disponível é o pedido do responsável pelo produto nesta conversa. Não foram coletadas entrevistas, tickets, métricas ou solicitações independentes de clientes. Várias mensagens da mesma pessoa não contam como várias fontes independentes.

O [catálogo Duolingo](references/duolingo-engineering.md) registra 20 fontes únicas indicadas pelo usuário, com aplicação candidata e limites. A [lista de acompanhamento](references/engineering-watchlist.md) reúne Spotify, Shopify, Google, Amazon, Anthropic, OpenAI e Meta, com protocolo de leitura e incorporação. Portais consultados não significam estudos integralmente revisados; nenhuma automação recorrente está ativada.

## Feature Inventory

### Implemented Features

Inventário inicial e limitado ao código consultado. “Implementado” nesta tabela significa comportamento presente no código; não comprova instalação, integração Koncluí, teste recente ou funcionamento em produção.

| Feature | Code Path | Docs Coverage |
|---|---|---|
| Protótipo Alexa responde a abertura, ajuda, sons e parada; emite APL quando disponível e valida ID/timestamp | `alexa/lambda/index.js`, `alexa/lambda/koru.json` | Documentado em `alexa/README.md`; implantação não confirmada |
| Sons locais de coruja/venda referenciados pelo handler; venda explicitamente demonstrativa | `alexa/assets/owl.mp3`, `alexa/assets/sale.mp3`, `alexa/lambda/index.js` | Documentado em `alexa/README.md`; não é evento real de venda |
| Entrada macOS liga AppDelegate e ajustes; personagem possui transições de estado | `NotchBuddy/Sources/App/NotchBuddyApp.swift`, `NotchBuddy/Sources/CoucouKit/BotEngine.swift` | Cobertura geral em `README.md`; não é motor operacional Koru |
| Entrada desktop conecta estado, ilha, ponte nativa, sons e handlers | `windows/src/main.ts` | Cobertura geral em `windows/README.md`; paridade não auditada |
| Entrada iPhone atualiza vínculo quando ativa e registra notificações/Live Activity | `NotchBuddy/Sources/Phone/CoucouPhoneApp.swift` | Cobertura geral em `README.md`; não demonstra continuidade de tarefas Koncluí |
| Relay recebe POST de Live Activity, valida corpo e encaminha payload ao APNs | `relay/src/index.ts` | Documentado em `relay/README.md`; não é serviço genérico de alertas Koru |
| App Flutter Koncluí tem bootstrap com backend, sessão, conectividade e runtime offline | Repositório de referência: `konclui-platform/apps/mobile/lib/main.dart`, `pubspec.yaml` | Registrado em `docs/koru/SOURCES.md`; não equivale à Koru integrada ou homologação mobile |

### Value & Innovation Landscape

“Best-in-Class Reference” é o campo do formato da skill; abaixo registra inspiração, sem afirmar liderança comprovada. Oportunidades nesta tabela são áreas de investigação detalhadas nas fichas e na [avaliação](review.md); o ranking é uma recomendação, não uma ordem de implementação aprovada.

| Capability | Current State | Best-in-Class Reference | Opportunity |
|---|---|---|---|
| Resumo operacional e consulta de procedimentos | Proposto em docs; fluxo integrado não comprovado | Jornadas solicitadas por donos/gestores/operadores | Primeiro resultado útil com fonte, acesso e custo corretos |
| Mapeamento e melhoria de processos | Proposto | Conhecimento operacional Koncluí | Transformar conversa em rascunho revisável e processo versionado |
| Ações via MCP | Contratos propostos; MCP BI externo é somente leitura | MCP e sistemas donos dos registros | Escrita confirmada, idempotente e protegida contra conflitos |
| Indicadores internos por pessoa/área | MCP existente como referência; segregação fina não comprovada | Admin Koncluí | Recortes autorizados antes de chegar ao modelo |
| Créditos por workspace | Carteira externa documentada; integração Koru não demonstrada | Contratos da plataforma | Atribuição desde o início, preço e reserva a definir |
| Aplicativos adaptados e continuidade | Flutter existente na plataforma; clientes Coucou como laboratório paralelo | Implementações locais e experiências de engenharia mobile | Integrar inicialmente no Flutter como hipótese preferida; comparar capacidades nativas sem presumir migração |
| Echo Show | Protótipo local de arte/som | Skill oficial e laboratório comunitário | Piloto operacional com identidade e handoff |
| Voz em tempo real e ativação | Direção documentada; capacidades distintas | Experiência Grok Bot indicada pelo usuário | Provar fluidez, custo, ruído e limites por sistema |
| Alertas automáticos | Proposta; relay existente tem finalidade diferente | Eventos e notificações das plataformas | Alertas úteis, permitidos, agrupados e rastreáveis |
| Gamificação | Pesquisa inicial e regras propostas | Duolingo, sem extrapolar eficácia | Continuidade por turno elegível e qualidade verificável |
| Adoção e compartilhamento | Mensagens/UX/modelos propostos | Frameworks já aplicados à documentação | Validar primeiro valor, recuperação e indicação voluntária |

## Tracking Summary

| Category | Count | Description |
|---|---|---|
| archive/ | 0 | Estados terminais, incluindo adiamentos com condição de revisão |
| opportunities/ | 13 | Itens abertos ou parcialmente implementados |
| specs/ | 3 | Padrões, decisões, armadilhas e técnicas transversais |
| references/ | 3 | Corpus Duolingo, revisão visual e fontes de acompanhamento contínuo |

Contagens representam arquivos nessas pastas, não as capacidades do inventário. As referências foram registradas por solicitação explícita durante o refinamento. A base foi aprovada; a avaliação inicial gerou 13 oportunidades e três temas transversais.

## Directory Layout

```text
.feature-radar/
├── base.md
├── review.md
├── archive/
├── opportunities/
├── specs/
└── references/
```

## Classification Rules

- `archive/{nn}-{slug}.md`: `Done`, `Covered`, `Rejected`, `N/A` ou `Deferred`. Done requer evidência de implementação e funcionamento no escopo declarado. Deferred exige justificativa e condição de reavaliação. Um protótipo Alexa pode estar concluído como protótipo sem encerrar a oportunidade de produto Alexa.
- `opportunities/{nn}-{slug}.md`: `Open`, `Partially Done` ou `Low Priority`; campos Impact e Effort com High/Medium/Low. Esforço Low: menos de um dia; Medium: 1–3 dias; High: uma semana ou mais. Lacunas de estimativa devem ser explicitadas, sem encaixar artificialmente trabalhos entre faixas. Separar esforço técnico de dependências, descoberta e homologação.
- IDs de dois dígitos são sequenciais e compartilhados entre archive e opportunities. Preservar ID ao mover; nunca reutilizar ID já atribuído.
- `specs/{topic}.md`: um assunto e uma classificação por arquivo — Pattern, Decision, Pitfall ou Technique. Não promover proposta a decisão aceita sem evidência.
- `references/{topic}.md`: um assunto por arquivo, observações cronológicas com data YYYY-MM-DD, URL, fonte e implicações. Catálogo consultado não equivale a estudos integralmente revisados.
- Documentação é evidência de intenção; código é evidência de comportamento possível; teste e produção exigem evidências próprias. Não arquivar funcionalidade do produto porque sua especificação foi escrita.

## Maintenance Workflow

1. Validar esta base com o usuário antes das fases do radar; registrar correções sem apagar o histórico relevante.
2. Classificar evidências e apresentar o checkpoint da fase 1; só então arquivar e organizar oportunidades conforme o fluxo da skill.
3. Ao arquivar, preservar ID e executar os cinco itens de extração abaixo, com achados explícitos.
4. Analisar lacunas de documentação, depois avaliar demanda, valor, inovação, esforço/impacto, encaixe e momento do ecossistema.
5. Apresentar ranking e propostas conforme checkpoints. Priorizar não autoriza implementação, commit ou publicação.
6. Em novas execuções, ler esta base, reconciliar arquivos/contagens/extrações e reavaliar Deferred conforme condições. Enquanto o status for bootstrap pendente, obter validação antes de avançar ao workflow.

`.gitignore` permanece inalterado. O radar é versionado no repositório privado `konclui/konclui-notch` desde 2026-10-30 (PR #6). Material interno sensível que surgir depois pede decisão própria antes de entrar aqui.

## Archive Extraction Checklist

Cada arquivamento registra explicitamente todos os resultados, inclusive quando não há achados:

- [ ] Criar `archive/{nn}-{slug}.md` com status correto e evidência.
- [ ] Extrair aprendizados para `specs/{topic}.md`, ou registrar ausência de aprendizado novo.
- [ ] Derivar oportunidades com novos IDs, ou registrar que não foram encontradas.
- [ ] Atualizar referências relevantes, ou registrar que nenhuma atualização é necessária.
- [ ] Atualizar `specs/ecosystem-trends.md` quando pertinente, ou registrar ausência de mudança de tendência.
