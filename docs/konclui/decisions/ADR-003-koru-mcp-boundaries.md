# ADR-003: Integrar a Koru por MCP com autorização no sistema

## Status

**Accepted — direção de produto.** O pedido de 2026-10-30 define MCP para Koncluí, aplicativos externos e MCP interno do admin. A topologia e os controles detalhados são **Proposed**, sujeitos à revisão na plataforma. Não há implantação autorizada por este ADR.

## Date

2026-10-30.

## Context

A Koru atenderá donos, gestores, operadores e a equipe Koncluí. Precisa integrar ferramentas sem replicar permissões e regras de negócio em cada cliente. O MCP de BI encontrado é somente leitura e voltado a admins/líderes; o caminho inspecionado não demonstra recorte de consulta por funcionário/área. [Evidência](../../koru/SOURCES.md#l1-plataforma-koncluí).

## Decision

Usar MCP como fronteira de capacidades de negócio. Reutilizar o MCP interno no alcance já autorizado e ampliar sua política apenas após prova de segregação. Projetar um MCP operacional de clientes distinto do acesso de BI amplo, sobre contratos existentes da Koncluí. Adaptadores de terceiros preservam identidade, escopo, limites e autoridade do sistema de origem.

Proposta técnica: orquestração compartilhada, catálogo de ferramentas autorizado, confirmação de efeitos e dados filtrados antes de chegarem ao modelo. Memória e cache também respeitam workspace e acesso. MCP não substitui evento de negócio, autenticação, autorização ou auditoria.

## Alternatives Considered

- **Integrações diretas diferentes em cada app:** autonomia local, mas duplicação de contratos, segredos e regras; não atende à direção MCP escolhida.
- **Reutilizar o token de BI do admin para todos:** rápido, mas alcance incompatível com funcionário/cliente; rejeitado.
- **Filtrar por prompt depois da consulta:** simples, mas expõe dados ao modelo antes da decisão; rejeitado como controle de acesso.
- **MCP do fornecedor ou adaptador próprio:** ambos possíveis; escolher por capacidade comprovada e custo de manutenção.

## Consequences

Conectores precisam de dono, versão, contrato e homologação. O primeiro valor pode ser somente leitura; escritas dependem de idempotência e confirmação. Acesso interno por função é requisito de lançamento, não efeito automático de conectar o MCP existente. Nenhum MCP novo é implementado nesta tarefa.

Detalhamento: [arquitetura](../../koru/ARCHITECTURE.md).
