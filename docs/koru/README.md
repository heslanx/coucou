# Koru — gerente operacional no bolso

**Data:** 2026-10-30 · **Estado:** visão de produto documentada; implementação integrada ainda não entregue.

A Koru ajuda donos, gestores e equipes a mapear, executar, otimizar e consolidar processos. Conecta o conhecimento e os sistemas do negócio para fornecer inteligência operacional e apoiar decisões e ações. O resultado desejado é crescimento, lucro e liberdade, com menos erros, desperdício, retrabalho e dependência do dono. São objetivos a medir, não resultados garantidos.

Este conjunto registra a direção solicitada pelo Erick: uma assistente útil no trabalho diário, com a amplitude de ajuda esperada de Claude ou GPT, especializada no contexto operacional de cada negócio. A Koru atende clientes e a própria equipe Koncluí, respeitando os acessos de cada pessoa.

## Como ler

| Documento | Conteúdo |
|---|---|
| [Produto](PRODUCT.md) | Públicos, jornadas, funcionalidades e experiência da personagem |
| [Mensagem, hábito e indicação](ADOPTION.md) | Primeira experiência, ciclos por público, compartilhamento, diagnósticos e pontos cegos |
| [Usabilidade e microcopy](UX-AND-MICROCOPY.md) | Diagnóstico heurístico, navegação, vocabulário, estados, erros e textos para protótipos |
| [Arquitetura e acesso](ARCHITECTURE.md) | MCPs, integração com Koncluí e admin, permissões, memória e ações |
| [Créditos e histórico](CREDITS.md) | Carteira do workspace, consumo, auditoria e evolução por usuário |
| [Dispositivos, voz e alertas](PLATFORMS.md) | macOS, iPadOS, iOS, Android, Windows, Linux, web e Echo Show |
| [Gamificação e pesquisa](GAMIFICATION.md) | Fontes oficiais do Duolingo, adaptação para trabalho e requisitos antes de implementar |
| [Radar e prioridades propostas](../../.feature-radar/review.md) | Base aprovada, 13 oportunidades, dependências e três propostas iniciais |
| [Entrega e validação](DELIVERY.md) | Etapas, critérios de aceite, métricas e decisões pendentes |
| [Fontes e estado observado](SOURCES.md) | Evidências locais e externas, alcance e limites da pesquisa |
| [Pesquisa de engenharia](../../.feature-radar/references/duolingo-engineering.md) | 20 fontes Duolingo, aplicações candidatas e limites |
| [Acompanhamento de referências](../../.feature-radar/references/engineering-watchlist.md) | Fontes de outras empresas e protocolo para incorporar aprendizados |

## Decisões registradas

- [ADR-003: integração por MCP e autorização](../konclui/decisions/ADR-003-koru-mcp-boundaries.md).
- [ADR-004: créditos do workspace](../konclui/decisions/ADR-004-koru-workspace-credits.md).
- [ADR-005: produto multiplataforma e canais de voz](../konclui/decisions/ADR-005-koru-platforms-and-voice.md).
- [ADR-006: gamificação orientada à qualidade operacional](../konclui/decisions/ADR-006-koru-operational-gamification.md).
- [ADR-007: Flutter existente e evolução nativa paralela](../konclui/decisions/ADR-007-koru-mobile-evolution.md).

Os ADRs distinguem **direção de produto aceita pelo pedido do usuário** de **desenho técnico proposto**. Nenhum deles autoriza migrações, mudanças de cobrança, adoção de dependências ou instalação em dispositivos.

## O que está decidido pelo pedido

1. Atender dono do negócio, gestor e operador; incluir funcionários, líderes e direção da Koncluí.
2. Integrar os principais aplicativos do negócio por MCP; acessar o Koncluí atual também por MCP.
3. Reutilizar o MCP existente no admin para a equipe interna, condicionado às permissões e funções.
4. Consumir créditos de IA da conta do workspace. Limites e interfaces de histórico por usuário podem vir depois.
5. Oferecer aplicativos instaláveis para MacBook, iPad, iPhone, Android, Windows e Linux, além da web, adaptados a cada dispositivo.
6. Explorar voz em tempo real, alertas automáticos e ativação por “Koru” onde a plataforma permitir.
7. Desenvolver gamificação inspirada em ofensivas, continuidade e outros mecanismos estudados pelo Duolingo, pesquisando antes de implementar.
8. Considerar integração inicial ao Flutter já existente na plataforma; explorar nativo em paralelo, sem compromisso de reescrita.
9. Manter pesquisa recorrente em fontes primárias de empresas experientes e incorporar apenas aprendizados compatíveis e verificáveis; acompanhamento automático ainda não configurado.

## O que este material não afirma

- Não existe aqui uma Koru conectada e distribuída em todas essas plataformas.
- O protótipo Alexa em [alexa/README.md](../../alexa/README.md) exibe arte e reproduz sons sob comando; não implementa o produto completo.
- O MCP de BI interno não é automaticamente um MCP operacional seguro para qualquer cliente ou funcionário.
- “MCP disponível” não comprova que um aplicativo oferece todas as ações desejadas, nem que seu uso está contratado.
- Não foi feita uma coleta exaustiva de toda a pesquisa histórica do Duolingo. Há um corpus público inicial e um plano de fechamento das lacunas.

## Local de manutenção

Estes documentos foram criados no checkout ativo `coucou`, que contém o trabalho local da personagem e do Echo Show. Os repositórios `konclui-platform`, `koru`, `konclui-work` e a referência local do Grok Bot foram apenas consultados. Não substituir este material por uma especificação de implementação na plataforma sem primeiro reconciliar os contratos e ADRs que pertencem a ela.
