# Créditos de IA, atribuição e histórico

[Índice](README.md) · 2026-10-30 · Consumir a carteira do workspace é decisão do produto. Tarifas e detalhes de reserva são propostas pendentes.

## 1. Fonte de cobrança

A Koru usa os créditos de IA da conta do workspace ativo, tanto para clientes quanto para um contexto interno Koncluí explicitamente provisionado. Não criar uma carteira paralela por dispositivo, por conversa ou por conector.

Na plataforma existem `ai_credit_packs`, `ai_credit_usage`, `fn_ai_credit_consume` e o serviço `ai_credit_wallet.py`. O consumo recebe workspace, quantidade, feature, referência, chave idempotente, metadados e `actor_user_id`; a tabela de uso inclui `created_by_user_id`. São bases reais para atribuição, não prova de uma interface de histórico individual pronta. [Fontes locais](SOURCES.md#l1-plataforma-koncluí).

O ADR existente de análise de evidência define **uma análise de evidência = um crédito**. Isso não define o preço de uma conversa, um minuto de áudio ou uma investigação com várias ferramentas. Preservar esse contrato até uma decisão explícita na plataforma; não mudar preços de funcionalidades existentes por este documento.

## 2. O que medir antes de precificar

| Trabalho | Unidade de medição proposta | Decisão pendente |
|---|---|---|
| Conversa textual | Tokens, modelo, contexto e execução | Regra de conversão em créditos e arredondamento |
| Voz em tempo real | Áudio de entrada/saída, tokens ou duração conforme fornecedor | Tarifa, limite de sessão e cobrança de interrupções |
| Imagem/documento | Páginas, imagens, tokens e modelo | Tarifa distinta da análise de evidência existente, quando necessária |
| Tarefa com ferramentas | Custo de IA por etapa e custo externo quando houver | Teto por tarefa e orçamento de execução |
| Resumo automático | Execução e modelo, com patrocinador do workspace | Frequência e orçamento recorrente |
| Detecção local, tela, timer e alerta fixo | Trabalho determinístico/local | Proposta: não debitar IA se não houve uso de IA |

MCP não é uma unidade de preço: uma chamada pode não consumir IA e uma resposta pode usar várias chamadas. Custos adicionais de terceiros não devem ser escondidos dentro de uma promessa de integração gratuita. Créditos, pontos de gamificação e moedas cosméticas são conceitos separados.

## 3. Fluxo proposto de orçamento

1. Resolver identidade, workspace, direito de uso da feature e orçamento antes de chamar o modelo.
2. Calcular uma estimativa ou teto com tabela de preços versionada; informar antes de tarefas materialmente mais caras.
3. Reservar orçamento de forma atômica quando a tarefa exigir. A carteira atual não foi confirmada como implementando reserva/liquidação; esse é um gap a projetar, não uma capacidade presumida.
4. Executar com limite de tempo, etapas, ferramentas e consumo. Sessões paralelas não podem gastar o mesmo saldo disponível.
5. Liquidar uma vez o uso confirmado e liberar a reserva não utilizada; retentativas mantêm a identidade da operação.
6. Registrar resultado, crédito debitado e vínculo com uso real. Não registrar sucesso de cobrança sem confirmação.
7. Reconciliar falhas parciais, cancelamento, reconexão e uso já cobrado pelo fornecedor. A regra de cobrança ao cliente precisa ser decidida explicitamente para cada caso.

O ledger atual tem `amount` inteiro e positivo. Se tarifas exigirem frações ou reserva, projetar unidade mínima/contabilidade compatível; não gravar valores negativos ou fracionários numa estrutura que não os suporta.

Saldo insuficiente não é a mesma coisa que ausência de direito ao recurso. A plataforma já distingue `insufficient_ai_credits` de `ai_not_entitled`; preservar essa diferença. Não orientar um workspace sem direito à feature a comprar créditos como se isso resolvesse o bloqueio.

Sem saldo, manter acessíveis caminhos operacionais já disponíveis que não dependem de IA, quando permitido pelo plano. Não prometer geração grátis ou apagar rascunhos. Informar à pessoa habilitada a administrar o orçamento.

## 4. Atribuição mínima desde o início

Mesmo que a interface individual venha depois, cada uso deve permitir identificar:

- Workspace, ator e identidade de automação quando aplicável.
- Feature, canal, dispositivo, sessão e operação.
- Modelo/provedor e versão da regra de preço.
- Consumo medido, estimativa quando não houver medição, créditos e estado.
- Origem manual ou agendada, patrocinador e chave idempotente.
- Correções/estornos com motivo e referência ao lançamento original, usando contrato contábil aprovado.

Não armazenar segredos ou conteúdo bruto de conversas em metadados financeiros. A equipe interna deve ter workspace/centro de custo definido; nunca cobrar um cliente porque uma análise interna consultou os dados dele.

## 5. Evolução por usuário dentro do workspace

O usuário solicitou esses recursos como possibilidade futura:

- Histórico de consumo por pessoa, feature, período e dispositivo.
- Teto individual mensal e limites por tarefa/sessão, além do saldo global.
- Orçamento por área ou função, avisos de aproximação e solicitação de ampliação.
- Histórico de conversas e tarefas do próprio usuário, com continuidade entre dispositivos.
- Visão administrativa de consumo; acesso ao conteúdo das conversas com política separada e explícita.

Proposta de precedência: permissão da ação → direito à feature → saldo global → teto individual/da área → teto da tarefa. Nenhum orçamento concede uma permissão. Identidade ausente em aparelho compartilhado não deve gerar uso pessoal atribuído por adivinhação: usar contexto de estação explicitamente autorizado ou pedir identificação.

## 6. Critérios de aceite

- Duas sessões concorrentes respeitam o saldo e os tetos sem cobrança duplicada.
- Retentativa/reconexão não produz novo débito para o mesmo trabalho já liquidado.
- Interrupção de áudio interrompe a produção desnecessária; uso já incorrido segue a regra publicada.
- Troca de workspace não muda o pagador de uma operação já iniciada.
- Usuário removido não inicia novos gastos, e automações delegadas são reavaliadas.
- Exibição distingue estimativa, consumo confirmado, reserva e crédito liberado quando essas categorias existirem.
- Métricas financeiras reconciliam com a carteira oficial e não dependem da memória do modelo.
