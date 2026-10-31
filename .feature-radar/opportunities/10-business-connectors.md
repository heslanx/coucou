# 10. MCPs dos aplicativos do negócio

**Status**: Open
**Impact**: High
**Effort**: High
**Tier**: Build soon
**Updated**: 2026-10-30
**Ref**: [Documento dono](../../docs/koru/ARCHITECTURE.md) · [Avaliação](../review.md)

## Description

Unir contexto operacional aos sistemas que já guardam vendas, estoque, financeiro ou relacionamento.

## Design Notes

**Evidência atual:** Direção MCP está documentada; não há inventário validado dos fornecedores de clientes nem conectores Koru homologados.

**Primeiro recorte:** Selecionar um aplicativo e uma leitura de alto valor; contrato de identidade, escopos, revogação, quotas, versões e suporte.

**Dependências:** 01, 02.

**Aceite proposto:** Fonte correta e atualizada responde; expiração/revogação são recuperáveis; credenciais não chegam ao modelo; mesmo nome em sistemas diferentes não mistura entidades.

**Limites:** Estimativa por conector simples com API autorizada; disponibilidade de MCP público não implica adequação ou direito de uso.

**Estimativa preliminar:** 10–25 dias úteis de engenharia para o recorte descrito, com baixa confiança; exclui espera por acesso, negociação, participantes e homologação externa. Não é compromisso de entrega. As estimativas compartilham trabalho e não devem ser somadas como um cronograma.

## Our Position

Escolher pela rotina do cliente piloto; não por catálogo de marcas.

Demanda disponível: pedido explícito do responsável pelo produto; sem confirmação independente de clientes. Aprovação da base do radar não equivale a aprovação desta prioridade ou a autorização para implementar em outro repositório.

**Próxima evidência:** executar o recorte com participante representativo e confrontar os casos de aceite; definir baseline e limiares antes do piloto. Reavaliar na próxima rodada do radar, ou antes se mudar uma dependência.
