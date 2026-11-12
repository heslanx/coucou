# 03. Registro e checklist assistidos

**Status**: Open
**Impact**: High
**Effort**: High
**Tier**: Build next
**Updated**: 2026-10-30
**Ref**: [Documento dono](../../docs/koru/ARCHITECTURE.md) · [Avaliação](../review.md)

## Description

Transformar orientação em uma ocorrência ou atualização de checklist verificável, sem perder evidências.

## Design Notes

**Evidência atual:** O protótipo Alexa não grava operações. O MCP BI é somente leitura; escrita operacional é contrato proposto.

**Primeiro recorte:** Uma escrita estreita: prévia, confirmação, versão, chave idempotente, estado durável e consulta do resultado; preservar câmera/evidência do Flutter.

**Dependências:** 01, 02.

**Aceite proposto:** Mesmo retry gera um registro; conflito exige nova revisão; timeout aparece como resultado desconhecido até reconciliação; evidência obrigatória permanece obrigatória.

**Limites:** API de origem precisa oferecer operação segura e precondições; sem isso, limitar a rascunho.

**Estimativa preliminar:** 10–20 dias úteis de engenharia para o recorte descrito, com baixa confiança; exclui espera por acesso, negociação, participantes e homologação externa. Não é compromisso de entrega. As estimativas compartilham trabalho e não devem ser somadas como um cronograma.

## Our Position

Próximo incremento após 01–02; uma ação bem concluída vale mais que muitas ferramentas expostas.

Demanda disponível: pedido explícito do responsável pelo produto; sem confirmação independente de clientes. Aprovação da base do radar não equivale a aprovação desta prioridade ou a autorização para implementar em outro repositório.

**Próxima evidência:** executar o recorte com participante representativo e confrontar os casos de aceite; definir baseline e limiares antes do piloto. Reavaliar na próxima rodada do radar, ou antes se mudar uma dependência.
