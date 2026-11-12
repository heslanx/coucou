# Autorização e orçamento no sistema responsável

## Context

A Koru atende clientes e equipe interna por vários canais.

## Pattern

Proposta transversal: resolver identidade e escopo no backend, aplicar autorização em cada ferramenta e manter a carteira do workspace como autoridade financeira. Atribuir ator e operação desde o primeiro piloto. Saldo não concede acesso; dispositivo não prova identidade. Referências donas: [arquitetura](../../docs/koru/ARCHITECTURE.md) e [créditos](../../docs/koru/CREDITS.md).

## Why It Matters

Evita que cada cliente ou conector implemente regras incompatíveis. A composição técnica ainda precisa ser verificada na plataforma.
