# ADR-007: Evolução mobile a partir do Flutter existente

## Status

**Accepted — direção esclarecida pelo usuário:** considerar `konclui-platform/apps/mobile` como base existente e caminho inicial provável para integrar a Koru no mobile, enquanto o trabalho nativo continua em paralelo como exploração. **Proposed:** desenho da integração, experimentos e critérios de eventual migração. Não há decisão de reescrever ou descontinuar Flutter.

## Date

2026-10-30.

## Context

O [ADR-005](ADR-005-koru-platforms-and-voice.md) deixou a estratégia de clientes aberta. O usuário esclareceu que o app Flutter já existe na plataforma e pode hospedar a Koru por um período. A inspeção de `apps/mobile/pubspec.yaml` e `lib/main.dart` confirma Dart/Flutter e inicialização de autenticação, conectividade e runtime offline; isso não comprova que a Koru já esteja integrada. A revisão foi somente leitura, no HEAD `ba01f139e`.

## Decision

Usar a integração ao Flutter existente como hipótese inicial preferida de entrega mobile. Evoluir experimentos nativos neste checkout em paralelo, sem torná-los condição para entregar valor no app atual. Este ADR especializa a estratégia mobile do ADR-005; os demais canais e limites continuam válidos.

Compartilhar contratos de identidade/workspace, permissões, ferramentas, histórico, execução e cobrança no backend. Não pressupor compartilhamento de código UI entre Flutter, Swift e Kotlin. Navegação, deep links, sessão e acessibilidade devem respeitar o app hospedeiro; protótipos isolados não mudam seu comportamento de produção.

Comparar três alternativas por capacidade: Flutter existente, Flutter com integração nativa delimitada e cliente nativo separado. Uma limitação específica de áudio ou background não demonstra necessidade de reescrita integral.

## Alternatives Considered

- **Reescrita nativa imediata:** não escolhida; ainda não há evidência de ganho que compense duplicação e migração.
- **Somente Flutter para sempre:** não decidido; manter liberdade para aprender e usar recursos nativos quando justificados.
- **Protótipos nativos em paralelo com contratos compartilhados:** direção compatível com o pedido; controlar custo e evitar divergência de regras de negócio.

## Consequences

Antes de integrar, ler instruções e contratos da plataforma e inventariar entradas existentes, sessão, permissões, rascunhos, fila offline, notificações e feature flags. Preservar versões antigas durante mudanças de contrato. Checklist offline existente não implica geração de IA offline.

Antes de ampliar ou migrar para nativo, comparar a mesma jornada em aparelhos representativos: sucesso de tarefa, acessibilidade, latência, consumo/bateria, confiabilidade offline, custo de suporte, builds e releases. Definir limiares antes do experimento. Exigir benefício comprovado, plano de coexistência, migração de dados/sessão e rollback. Não estabelecer data de abandono do Flutter.

Usar pesquisa primária de empresas experientes como insumo, conforme [catálogo Duolingo](../../../.feature-radar/references/duolingo-engineering.md) e [protocolo de acompanhamento](../../../.feature-radar/references/engineering-watchlist.md), sem copiar stacks por associação. Este registro não implementa integração nem autoriza modificar o repositório da plataforma.
