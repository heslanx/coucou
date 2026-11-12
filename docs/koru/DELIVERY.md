# Entrega, validação e decisões pendentes

[Índice](README.md) · 2026-10-30 · Sequência proposta, sem prazo ou orçamento comprometido.

## 1. Estado de partida

Esta tarefa entrega documentação, não integração de produção. As bases encontradas são descritas em [fontes](SOURCES.md): carteira de IA, MCP interno de leitura, apps existentes da plataforma, personagem e protótipo Alexa. A existência isolada desses componentes não prova o funcionamento conjunto.

## 2. Sequência proposta

| Etapa | Resultado verificável | Pré-requisitos / critério de saída |
|---|---|---|
| 0. Contratos e descoberta | Jornadas, fonte de cada indicador, atores, política de dados e cobrança | Decidir gaps do MCP interno e inventariar capacidades Koncluí; selecionar clientes/área piloto |
| 1. Koru útil em um canal | Login, workspace, texto, contexto, resumo e procedimentos via MCP | Fontes reais autorizadas, negações e débito rastreável; Flutter existente é hipótese preferida para mobile, sem depender de reescrita |
| 2. Operação assistida | Ocorrência e processo em rascunho; uma escrita confirmada e um checklist curto | Preservar evidência obrigatória, autoria, confirmação, idempotência e recuperação |
| 3. Equipe interna | Indicadores próprios, de área e empresariais conforme concessão | Escopo efetivo demonstrado no servidor; não expandir token de BI amplo |
| 4. Apps e continuidade | Instalação/atualização e mesmas tarefas em todos os canais alvo | Matriz homologada por SO; handoff sem vazamento de contexto ou duplicata |
| 5. Voz e alertas | Conversa em tempo real, notificações úteis e controles | Latência, áudio, custo e interrupção medidos; ativação “Koru” continua estudo por plataforma |
| 6. Ecossistema | MCPs dos aplicativos com demanda comprovada | Autenticação, permissões, manutenção, preço e limites de cada conector |
| 7. Gamificação | Piloto de continuidade e progresso de qualidade | Pesquisa e contrato de regras aprovados antes de implementar; medir efeitos adversos |
| 8. Administração avançada | Limites e interfaces de histórico por usuário/área | Atribuição já existente desde a primeira entrega, política de visibilidade e concorrência |

A pesquisa de voz, plataforma e gamificação pode ocorrer durante as primeiras etapas. Isso não dispensa as dependências de acesso, cobrança e qualidade antes de entregar cada recurso.

A exploração nativa ocorre em paralelo ao caminho Flutter, conforme [ADR-007](../konclui/decisions/ADR-007-koru-mobile-evolution.md). Comparar benefícios e manutenção antes de migrar. Pesquisa externa segue o [protocolo de acompanhamento](../../.feature-radar/references/engineering-watchlist.md); incluir resultados negativos e distinguir triagem de experimento reproduzido.

## 3. Casos de aceite do produto

### Valor e correção

- Busca e navegação permitem encontrar um procedimento sem memorizar comandos; voltar preserva contexto autorizado.
- Erros oferecem recuperação compatível com o papel; mensagens não confundem falha, ausência de dados e resultado desconhecido. Ver [usabilidade e microcopy](UX-AND-MICROCOPY.md).
- Dono recebe um resumo com fontes/período e distingue fato, estimativa e hipótese.
- Gestor consulta um setor e abre o registro que explica a prioridade.
- Operador retoma um checklist sem perder contexto, corrige uma medição e completa a evidência exigida.
- Um processo novo fica como rascunho até revisão/publicação por pessoa habilitada.
- Koru informa fonte atrasada ou indisponível em vez de preencher com zero ou inventar resultado.

### Acesso e multiempresa

- Pessoa de um workspace não consulta outro por prompt, argumento de ferramenta, link, histórico, busca, cache ou exportação.
- Colaborador interno vê só o próprio recorte; líder vê a área concedida; direção vê o agregado permitido.
- Revogação, desligamento, troca de papel e redução de escopo passam a valer nas próximas operações e invalidam acesso derivado incompatível.
- Aparelho compartilhado não reaproveita sessão pessoal anterior nem revela conteúdo privado em notificações.
- Conector malicioso ou documento com instruções não amplia ferramentas nem obtém credenciais.

### Ação e custo

- Conteúdo confirmado é o conteúdo executado, com ID no sistema de origem.
- Alteração concorrente invalida confirmação antiga; versão/precondição impede sobrescrita silenciosa na origem.
- Timeout depois de escrita entra em reconciliação; retry não duplica registro.
- Consumo é atribuído à pessoa/automação e ao workspace corretos; concorrência respeita orçamento.
- Cancelamento e reconexão seguem regra explícita de custo e preservam o estado confirmado.
- Contagem de pontos não altera saldo de créditos e saldo não concede acesso.
- Compartilhamento exige concessão específica; revogação bloqueia links privados e exportação informa que cópias entregues não podem ser recolhidas.

### Dispositivos e voz

- Instalação, atualização, logout, revogação de microfone e falha de rede verificados nos sistemas suportados.
- Voz funciona em cenário de ruído representativo, com alternativa de texto/toque e transcrição revisável.
- Interrupção para a fala; ação já executada é informada, não fingidamente desfeita.
- Alerta respeita escopo, horário e preferência; abertura revalida o acesso.
- Echo Show é testado no aparelho, não apenas no simulador ou em JSON.

## 4. Medir os resultados desejados

| Objetivo | Medida possível | Cuidados |
|---|---|---|
| Menos erros | Incidência e recorrência por volume de operações | Melhor detecção pode aumentar relatos inicialmente |
| Menos desperdício | Quantidade/custo registrado com fonte definida | Não inferir economia apenas por checklist concluído |
| Menos retrabalho | Horas/eventos de refação e tempo até resolução | Baseline e definições consistentes |
| Liberdade do dono | Decisões rotineiras delegadas e tempo de supervisão declarado | Confirmar que qualidade se mantém |
| Crescimento e lucro | Indicadores financeiros autorizados e sustentação de capacidade | Não atribuir causalidade à Koru sem desenho adequado |
| Utilidade da assistente | Tarefas concluídas corretamente, correções e retorno por período elegível | Não otimizar por quantidade de mensagens |
| Voz | Latência p50/p95, falhas, correções, falsos acionamentos e bateria | Diferenciar consulta de ação; segmentar dispositivo/ambiente |
| Viabilidade econômica | Custo por tarefa útil e margem do pacote | Incluir áudio, ferramentas, suporte e falhas |

Não existe meta numérica aprovada neste documento. Definir baseline, limiares de qualidade e critérios de interrupção antes do piloto. A regra atual deste checkout é não adicionar telemetria; esta proposta de medição não autoriza instrumentá-lo. Usar avaliação controlada e aprovar a política de dados do produto Koncluí antes de instrumentação persistente.

A [validação de adoção](ADOPTION.md#5-validação-proposta) acrescenta compreensão da mensagem, primeiro resultado útil, retorno por ocasião elegível, utilidade de preferências salvas e indicação voluntária. Separar retorno espontâneo, lembrete e cobrança da chefia. As notas editoriais dos frameworks não são métricas de produto nem critérios suficientes para expansão.

## 5. Decisões que ainda precisam de dono

| Questão | Responsável sugerido | Bloqueia |
|---|---|---|
| Canal e público do primeiro piloto | Produto + operação | Priorização de implementação |
| Contrato do MCP operacional Koncluí | Engenharia da plataforma | Escritas e dados de clientes |
| Segregação do MCP BI por pessoa/área | Engenharia + responsáveis pelos dados | Ampliação interna |
| Conectores iniciais e suporte | Produto + clientes piloto | Promessa comercial de integração |
| Preço de texto, voz e tarefas | Produto + financeiro | Cobrança comercial |
| Reserva/liquidação e compatibilidade do ledger | Engenharia + billing | Controle seguro de sessões concorrentes |
| Workspace pagador para uso interno | Financeiro + administração | Cobrança interna |
| Visibilidade/retenção de histórico e áudio | Produto + responsáveis pelos dados | Histórico compartilhado e voz em produção |
| Matriz de sistemas, frameworks e distribuição | Engenharia de clientes | Apps instaláveis suportados |
| Provedor e qualidade de voz | Engenharia + produto | Voz em tempo real |
| Calendário, ação elegível e recuperação da ofensiva | Produto + clientes/equipe piloto | Gamificação |
| Equipamento compartilhado ou dedicado | Produto + suporte | Distribuição de hardware |

Não é necessário resolver todas essas questões para continuar a descoberta. Elas precisam estar resolvidas antes da entrega dependente.

## 6. Verificação desta documentação

Checar links locais e âncoras, referências a fontes, coerência de status dos ADRs e cobertura do pedido. Rever principalmente as fronteiras: existente versus proposto, cliente versus interno, identidade versus dispositivo, crédito versus ponto, hábito versus conformidade e sessão de voz versus escuta permanente.

Não executar suites do produto para esta mudança exclusivamente documental. Não publicar, instalar, alterar billing, criar MCPs nem modificar os repositórios usados como referência nesta tarefa.
