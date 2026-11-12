# Duolingo: produto e engenharia

> Registro inicial das fontes enviadas pelo usuário; observações externas não são decisões de adoção.

## 2026-10-30 — Corpus de produto, agentes e confiabilidade

**Source**: https://blog.duolingo.com/ e URLs individuais abaixo.

As 21 URLs enviadas correspondem a **20 fontes únicas**: 15 artigos e 5 repositórios. `automating-jvm-golden-path` apareceu duas vezes; o parâmetro de referência do link de slack-ai-agent foi removido da URL canônica. Todos foram abertos. Esta é uma triagem temática das páginas/artigos e apresentações públicas dos repositórios, não auditoria do código, reprodução de experimentos ou revisão exaustiva das referências citadas. A data acima é de consulta, não de publicação. Antes de adoção, registrar data de publicação/atualização e versão/commit pertinentes.

| ID | Fonte primária | Observação da fonte | Aplicação candidata à Koru / limite |
|---|---|---|---|
| DE01 | [Streak e hábito](https://blog.duolingo.com/how-duolingo-streak-builds-habit/) | Continuidade contextual e proteção fazem parte do desenho de hábito | Adaptar a turnos elegíveis; não importar pressão diária para empregados. Já catalogado como D03 |
| DE02 | [Dataset development](https://blog.duolingo.com/dataset-development/) | Práticas de engenharia de serviços são aplicadas a datasets | Contratos e comparação de dados para indicadores e créditos; já catalogado como D19 |
| DE03 | [Builds Android/iOS](https://blog.duolingo.com/sped-up-android-ios-builds/) | Iterações medidas reduzem espera de CI; relata também tentativa de cache que não funcionou | Medir o CI Flutter e o nativo separadamente; não instalar ferramenta nem importar percentuais de ganho |
| DE04 | [AI Slack bot](https://blog.duolingo.com/aislackbot/) | Integração de ferramentas/MCP evolui de experimentos locais a acesso por Slack | Avaliar conveniência e contexto da equipe interna; Slack não substitui autorização por pessoa/área |
| DE05 | [slack-ai-agent](https://github.com/duolingo/slack-ai-agent) | README separa roteamento, sessões, MCP, processamento e políticas de ferramentas | Estudar fronteiras de canal/orquestração e aprovação; isolamento multiworkspace e adequação do código ainda não auditados |
| DE06 | [pre-commit-hooks](https://github.com/duolingo/pre-commit-hooks) | Repositório de padronização de ferramentas de qualidade | Comparar com verificações já existentes; não duplicar runners nem instalar hooks por esta referência |
| DE07 | [pulldozer](https://github.com/duolingo/pulldozer) | CLI para editar múltiplos repositórios em lote | Estudar se houver migração repetitiva comprovada; não concede autorização para editar outros projetos |
| DE08 | [splinter](https://github.com/duolingo/splinter) | Linter simples baseado em pares de mensagem e regex | Regras mecânicas pequenas podem virar checks; regex não substitui análise semântica ou teste de comportamento |
| DE09 | [whosaidit](https://github.com/duolingo/whosaidit) | Dataset multilíngue para rotular atributos de falantes a partir de texto | Relevância exploratória para pesquisa; não é autenticação por voz nem solução comprovada de diarização de áudio |
| DE10 | [Plataforma de agentes em produção](https://blog.duolingo.com/production-ready-ai-agent-platform/) | Plataforma compartilhada evita reconstruir execução, orquestração, observação e avaliação por agente | Contratos comuns para Koru interna e cliente, com isolamento; não copiar infraestrutura de escala sem necessidade |
| DE11 | [Geração de testes iOS por IA](https://blog.duolingo.com/ai-ios-unit-test-generation-pipeline/) | Pipeline automatiza geração de testes e acompanhamento de PRs | Estudar verificações úteis e revisão dos resultados; quantidade de testes/linhas não é qualidade, e Swift não substitui testes Flutter |
| DE12 | [Redução de CPU](https://blog.duolingo.com/reduce-cpu-usage-97-percent/) | Caso de saturação em lote expõe criação repetida de sessões HTTP; reuso de conexão resolve o gargalo descrito | Investigar pooling e saturação só com evidência local; o ganho do título pertence ao incidente descrito |
| DE13 | [Golden Path JVM](https://blog.duolingo.com/automating-jvm-golden-path/) | Padronização de upgrades com automação e IA | Migrar padrões de forma verificável quando necessário; versões JVM e ferramentas do caso não são decisão para Dart/Swift/TypeScript |
| DE14 | [Frontend prediction](https://blog.duolingo.com/frontend-prediction/) | Atualizações antecipadas podem reduzir latência percebida, mas têm custos de coerência | Mostrar pendência/reconciliação; não antecipar confirmação de crédito, permissão ou conclusão operacional |
| DE15 | [Incident management](https://blog.duolingo.com/incident-management-lessons/) | Coordenação e continuidade importam em incidentes prolongados e incertos | Linha do tempo, responsável e passagem de contexto para operação; não anunciar resolução sem confirmação |
| DE16 | [Mini-units](https://blog.duolingo.com/intermediate-mini-units/) | Unidades menores e focadas aproximam conteúdo novo da prática | Microaprendizagem ligada a procedimentos; fracionar ensino não elimina evidência obrigatória do trabalho |
| DE17 | [Core tabs redesign](https://blog.duolingo.com/core-tabs-redesign/) | Revisão busca coerência entre abas, hierarquia e espaçamento | Integrar Koru à navegação Flutter existente antes de criar experiência desconectada; não copiar aparência |
| DE18 | [Optimistic locking](https://blog.duolingo.com/optimistic-locking/) | Controle de concorrência aplicado ao armazenamento de notificações | Complementa precondições de escrita da Koru; lock otimista não é atualização otimista de UI nem substituto universal de transação |
| DE19 | [Agentic workflows](https://blog.duolingo.com/agentic-workflows/) | Fluxos repetitivos de engenharia são encapsulados em agentes reutilizáveis | Começar por tarefas delimitadas e resultados verificáveis; não dar autoridade irrestrita ao agente operacional |
| DE20 | [Building AI agents](https://blog.duolingo.com/buildingaiagents/) | Agente de remoção de feature flags serve como caso de automação delimitada e orquestrada | Extrair padrão de execução recuperável; Temporal/Codex no caso não obriga adoção desses componentes |

**Implications**:

- Produto: estudar hábito, microaprendizagem e consistência com as restrições de trabalho, permissões e turno.
- Plataforma: definir execução, identidade, avaliação, custo e recuperação compartilhados entre canais, sem criar uma plataforma genérica antes de provar uma jornada útil.
- Mobile: preservar o Flutter como caminho inicial provável e testar capacidades nativas em paralelo com cenários comparáveis.
- Engenharia: diagnosticar gargalos e riscos locais antes de escolher ferramentas por prestígio da empresa de origem.
- Pesquisa: nenhuma dessas referências instala dependências, habilita automações, muda políticas ou prova demanda de clientes Koncluí.

### Próxima leitura dirigida

Antes de desenhar execução de agentes, aprofundar DE05/DE10/DE19/DE20 e registrar contratos, avaliação, isolamento e limites de adoção. Antes de escritas concorrentes ou modo offline, aprofundar DE14/DE18 junto dos contratos locais. Antes de ampliar gamificação, seguir o plano de pesquisa já documentado. Estas são dependências de estudo, não ranking aprovado de funcionalidades.

## 2026-10-30 — Complemento visual

**Source**: [inventário e observações das imagens](duolingo-visual-review.md).

**Implications**: as imagens destes artigos foram incluídas na revisão retroativa de 28 artigos. Consultar cobertura, limites de animação e achados por artigo antes de usar esta triagem em decisões. A leitura das imagens passa a integrar o [protocolo de pesquisa](engineering-watchlist.md).
