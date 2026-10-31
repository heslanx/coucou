# Radar Koru — avaliação inicial

**Date**: 2026-10-30
**Mode**: full
**Status**: fases 1–6 concluídas como análise documental; prioridades propostas, implementação não iniciada.

## Aprovação e reconciliação

O usuário aprovou a base com “aprovo o radar”. A aprovação incorpora Flutter inicial provável, exploração nativa paralela e leitura de todas as imagens dos artigos. Estado inicial conferido: archive 0, opportunities 0, specs 0, references 3; sem extrações pendentes.

A instrução anterior de continuar com autonomia foi aplicada aos checkpoints desta análise. Não cria autorização para implementação na plataforma, dependências, publicação ou gastos. Nenhuma nova sessão de pesquisa externa foi necessária: classificação baseada no pedido, documentos e código local. Disponibilidade atual de plataformas e conectores permanece condição de revalidação antes da implementação; não foram promovidas referências históricas a fatos atuais.

## Fase 1 — Classificação

| Classification | Count | Items |
|---|---:|---|
| Archive | 0 | Nenhum recurso integrado comprovadamente encerrado |
| Opportunity | 13 | 01–13, inventário abaixo |
| Spec | 3 | Autorização/orçamento; estado confirmado; evolução mobile |
| Reference | 3 | Catálogo Duolingo; revisão visual; acompanhamento de fontes (já existentes) |

Fontes: [base aprovada](base.md), [produto](../docs/koru/PRODUCT.md), [entrega](../docs/koru/DELIVERY.md), contratos e fontes vinculados em cada oportunidade. Leitura confirmatória do handler Alexa, entrada Flutter, fábrica MCP BI e assinaturas da carteira externa. A chamada de QueryService não recebe identidade para escopo na interface inspecionada; isso é uma lacuna a investigar, não uma auditoria de toda a segurança da plataforma.

O código Alexa comprova o protótipo visual/sonoro; faltam implantação e validação no aparelho. Clientes existentes não comprovam Koru integrada. Documentar uma ideia não encerra sua oportunidade.

## Fase 2 — Arquivamento

Sem candidatos a arquivamento. Nenhum item marcado Done, Covered ou Rejected sem evidência; nenhum checklist de extração aplicável. Recursos em Monitor permanecem abertos com condição de reavaliação, evitando confundir baixa prioridade com rejeição.

## Fase 3 — Oportunidades organizadas

Treze fichas persistidas com evidência, recorte, dependências, aceite, impacto, esforço e posição. Todas têm esforço High porque abrangem integração de produção, não apenas mockups. Estimativas têm baixa confiança e não incluem espera externa; validação técnica curta deve refiná-las. Os temas de voz, gamificação e nativo podem ser pesquisados em paralelo sem antecipar entrega comercial.

| # | Opportunity | Impact | Effort | Our Position |
|---|---|---|---|---|
| [01](opportunities/01-trusted-runtime.md) | Base de acesso, MCP e créditos | High | High | Fundação obrigatória, entregue junto da jornada 02 para evitar infraestrutura sem valor demonstrável. |
| [02](opportunities/02-operational-briefing.md) | Resumo operacional no Flutter | High | High | Principal entrega de valor inicial; ampliar para dono e operador sem inventar métricas financeiras. |
| [03](opportunities/03-assisted-operation.md) | Registro e checklist assistidos | High | High | Próximo incremento após 01–02; uma ação bem concluída vale mais que muitas ferramentas expostas. |
| [04](opportunities/04-process-improvement.md) | Mapeamento e melhoria de processos | High | High | Parte central da promessa; começar com um processo que já tenha dor observada. |
| [05](opportunities/05-internal-indicators.md) | Indicadores da equipe Koncluí | High | High | Bom piloto interno, condicionado ao escopo demonstrado; não é atalho para ignorar autorização. |
| [06](opportunities/06-operational-alerts.md) | Alertas operacionais úteis | High | High | Construir quando existir ação útil de destino e política de frequência. |
| [07](opportunities/07-realtime-voice.md) | Conversa de voz em tempo real | High | High | Pesquisar em paralelo; entregar após fluxo textual correto. Palavra de ativação permanece Monitor dentro desta oportunidade. |
| [08](opportunities/08-echo-show.md) | Koru operacional no Echo Show | Medium | High | Manter laboratório existente; subir prioridade se cliente piloto demonstrar vantagem sobre tablet/celular. |
| [09](opportunities/09-multiplatform-continuity.md) | Aplicativos e continuidade entre dispositivos | High | High | Flutter inicial; homologar novos clientes conforme evidência de uso e benefício. |
| [10](opportunities/10-business-connectors.md) | MCPs dos aplicativos do negócio | High | High | Escolher pela rotina do cliente piloto; não por catálogo de marcas. |
| [11](opportunities/11-operational-gamification.md) | Continuidade e aprendizagem de qualidade | Medium | High | Pesquisar agora; implementar depois de demonstrar tarefas úteis e eventos confiáveis. Não adotar ranking punitivo. |
| [12](opportunities/12-user-budgets-history.md) | Histórico e limites por usuário | Medium | High | Interface avançada pode esperar; adiar identificação de consumo produziria dívida que queremos evitar. |
| [13](opportunities/13-adoption-sharing.md) | Primeiro valor e compartilhamento de processos | Medium | High | Onboarding mínimo acompanha 02; distribuição social e indicação vêm após valor demonstrado. |

## Fase 4 — Lacunas documentais

A pasta docs existe; fase executada no inventário Koru aprovado, sem auditar funcionalidades não relacionadas do Coucou.

| Implementação observada | Documento responsável | Resultado |
|---|---|---|
| Handler, sons, APL e limites do protótipo | [Alexa](../alexa/README.md) | Coberto; ativação não confirmada |
| Entradas dos clientes e ausência de paridade Koru comprovada | [Base](base.md) e [plataformas](../docs/koru/PLATFORMS.md) | Coberto no nível de inventário |
| Bootstrap Flutter externo | [Fontes](../docs/koru/SOURCES.md) e ADR-005 | Coberto como evidência localizada |
| MCP BI e carteira externos | [Arquitetura](../docs/koru/ARCHITECTURE.md), [créditos](../docs/koru/CREDITS.md) | Cobertos como bases existentes, não integração pronta |

Sem nova funcionalidade implementada e não documentada identificada nesse recorte. Lacuna de organização encontrada: faltava índice de prioridades ligando propostas a dependências e aceites; preenchido por este relatório e pelas fichas. Não converter essa ausência de achados numa afirmação de cobertura completa dos repositórios.

## Fase 5 — Avaliação e prioridades propostas

H/M/L são julgamento ordinal, não medição. Demand=M em todas: direção explícita do dono do produto, sem entrevistas ou sinais independentes. Value considera resultado operacional; Innovation considera integração contextual; Effort/Impact avalia benefício relativo ao custo (H é mais favorável); Fit considera contratos e filosofia; Timing considera prontidão local e dependências, não certificação atual do ecossistema.

| Tier | # | Opportunity | Demand | Value | Innovation | Effort/Impact | Fit | Timing |
|---|---|---|---|---|---|---|---|---|
| Build next | [01](opportunities/01-trusted-runtime.md) | Base de acesso, MCP e créditos | M | H | M | M | H | M |
| Build next | [02](opportunities/02-operational-briefing.md) | Resumo operacional no Flutter | M | H | M | H | H | M |
| Build next | [03](opportunities/03-assisted-operation.md) | Registro e checklist assistidos | M | H | H | M | H | M |
| Build soon | [04](opportunities/04-process-improvement.md) | Mapeamento e melhoria de processos | M | H | H | M | H | M |
| Build soon | [05](opportunities/05-internal-indicators.md) | Indicadores da equipe Koncluí | M | H | M | M | H | M |
| Build soon | [06](opportunities/06-operational-alerts.md) | Alertas operacionais úteis | M | H | M | M | H | M |
| Build soon | [07](opportunities/07-realtime-voice.md) | Conversa de voz em tempo real | M | H | H | M | H | L |
| Monitor | [08](opportunities/08-echo-show.md) | Koru operacional no Echo Show | M | M | M | L | M | L |
| Build soon | [09](opportunities/09-multiplatform-continuity.md) | Aplicativos e continuidade entre dispositivos | M | H | M | L | H | M |
| Build soon | [10](opportunities/10-business-connectors.md) | MCPs dos aplicativos do negócio | M | H | H | M | H | L |
| Monitor | [11](opportunities/11-operational-gamification.md) | Continuidade e aprendizagem de qualidade | M | M | H | L | H | L |
| Monitor | [12](opportunities/12-user-budgets-history.md) | Histórico e limites por usuário | M | M | M | M | H | M |
| Build soon | [13](opportunities/13-adoption-sharing.md) | Primeiro valor e compartilhamento de processos | M | M | M | M | H | M |

**Ordem recomendada:** 01 e 02 formam uma entrega vertical; 03 segue após essa base. Não executar os três como projetos independentes. Em Build soon, 05 pode ser piloto interno assim que autorização fina estiver demonstrada; 04 e 06 dependem de fonte e ação úteis; 07 e 09 começam com experimentos delimitados; 10 depende dos aplicativos reais do piloto; onboarding mínimo de 13 entra com 02.

**Monitor:** 08 sobe quando houver estação e rotina piloto que justifiquem o canal; 11 sobe após regras e eventos confiáveis; 12 sobe quando consumo real justificar controles individuais. Atribuição mínima de 12 já pertence a 01. Palavra de ativação em background fica em Monitor, separada da voz iniciada explicitamente de 07. Reescrita nativa completa não é proposta de entrega.

**Skip:** nenhum requisito solicitado foi descartado. Rankings punitivos, gasto de IA como pontuação, acesso por token compartilhado e IA fingindo sucesso estão fora do desenho por incompatibilidade com os contratos documentados.

## Fase 6 — Propostas para detalhamento

### 01. Base de acesso, MCP e créditos

**Pitch:** fazer uma consulta da Koru chegar ao dado autorizado e atribuir corretamente o custo, sem abrir acesso amplo a cliente ou funcionário.

**Effort:** 10–20 dias úteis, baixa confiança, para uma leitura vertical e seus casos de autorização/concorrência. Exclui espera por acessos e decisão comercial.

**Key decisions:** escolher ferramenta operacional mínima; reutilizar identidade e ledger; fechar regra de preço/teto para o piloto; resolver autorização no servidor. Explorar primeiro os contratos existentes, sem inventar um segundo backend de negócio.

### 02. Resumo operacional no Flutter

**Pitch:** ao abrir a Koru no app existente, o gestor entende uma pendência real, sua fonte e o próximo passo. O dono e o operador recebem recortes compatíveis com seus papéis.

**Effort:** 10–20 dias úteis, baixa confiança, com 01 compartilhando integração. Não somar as faixas mecanicamente.

**Key decisions:** proposta de primeiro recorte: gestor de uma unidade, consulta textual de pendências e procedimento aprovado. Selecionar participante, fonte e critérios de sucesso antes do piloto. Entrada respeita navegação e sessão existentes; sem depender de voz, Alexa ou migração nativa.

### 03. Registro e checklist assistidos

**Pitch:** fechar o ciclo entre entender e agir com uma ocorrência ou atualização confirmada no sistema de origem, preservando autoria e evidência.

**Effort:** 10–20 dias úteis, baixa confiança, após os contratos de 01–02; API sem precondições seguras pode alterar o escopo.

**Key decisions:** selecionar uma escrita reversível; implementar revisão e confirmação; definir conflito e reconciliação; manter foto ou outra evidência exigida. Publicação de processo e comunicação externa continuam capacidades separadas.

## Próximo passo recomendado

Detalhar 01+02 como uma única entrega vertical no repositório dono da plataforma, começando pela leitura de suas instruções e reconciliação dos contratos. Este radar recomenda o recorte; não o implementa nem compromete prazo, preço, clientes ou equipe. O plano deve registrar o que bloqueia produção e o que pode ser validado com dados sintéticos autorizados.

Critério de avanço: participante consegue resolver uma dúvida operacional com fonte correta; isolamento, revogação, estado e custo passam nos casos de aceite. Definir baseline e limiares antes da avaliação. A regra deste checkout continua sem telemetria; usar avaliação controlada nesta fase.

## Verificação

Conferir contagens, IDs únicos, campos obrigatórios, links locais, dependências e coerência com os ADRs. Mudança exclusivamente documental; não executar suites do produto nem tratar resultados históricos como verificação nova.
