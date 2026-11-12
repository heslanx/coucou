# 05. Indicadores da equipe Koncluí

**Status**: Partially Done
**Impact**: High
**Effort**: High
**Tier**: Build soon
**Updated**: 2026-10-30
**Ref**: [Documento dono](../../docs/koru/ARCHITECTURE.md) · [Avaliação](../review.md)

## Description

Permitir que colaborador, líder e direção consultem seus indicadores no escopo concedido.

## Design Notes

**Evidência atual:** McpServerFactory.criar recebe identidade; run_query usa QueryService.executar sem identidade como argumento de escopo. Auditoria não comprova autorização por pessoa/área.

**Primeiro recorte:** Reutilizar admin MCP após resolver segregação efetiva; definir métricas, workspace pagador e recusas; não distribuir token amplo.

**Dependências:** 01.

**Aceite proposto:** Colaborador não lê colegas; líder só acessa área concedida; direção vê agregado permitido; revogação invalida resultados derivados.

**Limites:** Não confundir BI interno com interface segura para clientes; regras finas exigem avaliação do repositório dono.

**Estimativa preliminar:** 10–20 dias úteis de engenharia para o recorte descrito, com baixa confiança; exclui espera por acesso, negociação, participantes e homologação externa. Não é compromisso de entrega. As estimativas compartilham trabalho e não devem ser somadas como um cronograma.

## Our Position

Bom piloto interno, condicionado ao escopo demonstrado; não é atalho para ignorar autorização.

Demanda disponível: pedido explícito do responsável pelo produto; sem confirmação independente de clientes. Aprovação da base do radar não equivale a aprovação desta prioridade ou a autorização para implementar em outro repositório.

**Próxima evidência:** executar o recorte com participante representativo e confrontar os casos de aceite; definir baseline e limiares antes do piloto. Reavaliar na próxima rodada do radar, ou antes se mudar uma dependência.
