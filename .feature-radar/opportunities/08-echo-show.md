# 08. Koru operacional no Echo Show

**Status**: Partially Done
**Impact**: Medium
**Effort**: High
**Tier**: Monitor
**Updated**: 2026-10-30
**Ref**: [Documento dono](../../docs/koru/PLATFORMS.md) · [Avaliação](../review.md)

## Description

Oferecer consulta e orientação numa estação com tela, com continuidade no celular pessoal.

## Design Notes

**Evidência atual:** alexa/lambda/index.js responde a intents de sons, ajuda e parada e renderiza APL; não contém MCP, account linking ou cobrança. Implantação e aparelho ainda não verificados.

**Primeiro recorte:** Validar protótipo no aparelho; depois vinculação, sessão de estação com escopo limitado, conteúdo público apropriado e handoff de aprovações pessoais.

**Dependências:** 01, 02, 09 para continuidade.

**Aceite proposto:** Invocação e APL funcionam no modelo real; estação não revela sessão pessoal anterior; continuidade exige autenticação e conserva tarefa.

**Limites:** Conta Amazon e implantação são dependências reais; notificações e disponibilidade precisam ser revalidadas nas fontes oficiais antes de implementar.

**Estimativa preliminar:** 10–20 dias úteis de engenharia para o recorte descrito, com baixa confiança; exclui espera por acesso, negociação, participantes e homologação externa. Não é compromisso de entrega. As estimativas compartilham trabalho e não devem ser somadas como um cronograma.

## Our Position

Manter laboratório existente; subir prioridade se cliente piloto demonstrar vantagem sobre tablet/celular.

Demanda disponível: pedido explícito do responsável pelo produto; sem confirmação independente de clientes. Aprovação da base do radar não equivale a aprovação desta prioridade ou a autorização para implementar em outro repositório.

**Próxima evidência:** executar o recorte com participante representativo e confrontar os casos de aceite; definir baseline e limiares antes do piloto. Reavaliar na próxima rodada do radar, ou antes se mudar uma dependência.
