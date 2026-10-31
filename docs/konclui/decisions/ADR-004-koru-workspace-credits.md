# ADR-004: Cobrar a IA da Koru na carteira do workspace

## Status

**Accepted — direção de produto.** Consumo pela conta do workspace e possibilidade futura de limites/histórico por usuário foram solicitados em 2026-10-30. Tarifas, reserva e liquidação são **Proposed**, ainda não aprovadas para implementação.

## Date

2026-10-30.

## Context

A plataforma já tem carteira de IA, consumo idempotente e atribuição de ator. A Koru adiciona texto, áudio, análise e tarefas com custos variados. A regra existente de uma análise de evidência por crédito não precifica esses novos usos.

## Decision

Reutilizar a carteira oficial do workspace como fonte de saldo e consumo. Preservar atribuição por ator desde a primeira versão, mesmo que interfaces de histórico e limites individuais cheguem depois. Uso interno Koncluí precisa de workspace/centro de custo próprio definido.

Proposta técnica: teto por tarefa/sessão, consumo medido, preço versionado, controle de concorrência e reconciliação idempotente. Avaliar reserva e liquidação antes de streaming prolongado. Créditos de IA e pontos de gamificação são separados. Não alterar contratos financeiros existentes silenciosamente.

## Alternatives Considered

- **Carteira por dispositivo ou app:** facilita isolamento técnico, mas fragmenta a conta do cliente; rejeitada.
- **Chave de IA pessoal de cada funcionário:** transfere configuração/custo para a pessoa e não atende à cobrança do workspace; fora da direção atual.
- **Um crédito por mensagem ou chamada MCP:** simples, mas não representa variação de custo; não aprovada.
- **Limites pessoais já no primeiro release:** úteis, mas podem vir depois; atribuição e integridade do saldo não podem esperar.

## Consequences

Billing precisa definir unidade e tarifa antes da oferta comercial. Ledger inteiro/positivo atual exige estudo de compatibilidade para frações, reservas e estornos. Sem saldo ou sem direito são erros diferentes. Histórico financeiro não autoriza acesso ao conteúdo de conversas.

Detalhamento: [créditos](../../koru/CREDITS.md). Este ADR não substitui o ADR-0037 da plataforma.
