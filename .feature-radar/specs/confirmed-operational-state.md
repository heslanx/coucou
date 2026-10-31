# Estado operacional confirmado

## Context

Conversas, retries e redes instáveis podem apresentar sucesso antes da confirmação real.

## Pattern

Proposta transversal: distinguir rascunho, aguardando confirmação, em execução, confirmado, falhou e resultado desconhecido. Escritas usam idempotência, versão/precondição e reconciliação na origem. Uma animação de sucesso não pode adiantar confirmação. Ver [arquitetura](../../docs/koru/ARCHITECTURE.md) e [revisão visual](../references/duolingo-visual-review.md).

## Why It Matters

Protege tarefas, cobrança e futura gamificação contra duplicatas e sucesso inventado; não define uma nova máquina de estados aprovada.
