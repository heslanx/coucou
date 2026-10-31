# 06. Alertas operacionais úteis

**Status**: Open
**Impact**: High
**Effort**: High
**Tier**: Build soon
**Updated**: 2026-10-30
**Ref**: [Documento dono](../../docs/koru/PLATFORMS.md) · [Avaliação](../review.md)

## Description

Avisar sobre exceções acionáveis sem obrigar a pessoa a consultar o app a todo momento.

## Design Notes

**Evidência atual:** Relay local encaminha Live Activities; não comprova pipeline genérico de eventos operacionais.

**Primeiro recorte:** Uma regra determinística inicial; patrocinador, horário, preferência, deduplicação, deep link e revalidação ao abrir; IA apenas quando agrega valor.

**Dependências:** 01, 02; 03 quando houver ação.

**Aceite proposto:** Evento repetido não duplica alerta; revogação impede conteúdo indevido; horário silencioso funciona; pessoa chega ao registro correto.

**Limites:** Fontes de eventos e entrega precisam ser validadas; push não garante leitura nem resolução.

**Estimativa preliminar:** 10–20 dias úteis de engenharia para o recorte descrito, com baixa confiança; exclui espera por acesso, negociação, participantes e homologação externa. Não é compromisso de entrega. As estimativas compartilham trabalho e não devem ser somadas como um cronograma.

## Our Position

Construir quando existir ação útil de destino e política de frequência.

Demanda disponível: pedido explícito do responsável pelo produto; sem confirmação independente de clientes. Aprovação da base do radar não equivale a aprovação desta prioridade ou a autorização para implementar em outro repositório.

**Próxima evidência:** executar o recorte com participante representativo e confrontar os casos de aceite; definir baseline e limiares antes do piloto. Reavaliar na próxima rodada do radar, ou antes se mudar uma dependência.
