# 01. Base de acesso, MCP e créditos

**Status**: Partially Done
**Impact**: High
**Effort**: High
**Tier**: Build next
**Updated**: 2026-10-30
**Ref**: [Documento dono](../../docs/koru/ARCHITECTURE.md) · [Avaliação](../review.md)

## Description

Unir sessão, workspace, ferramentas autorizadas e carteira numa consulta ponta a ponta.

## Design Notes

**Evidência atual:** A carteira externa recebe ator e idempotência; o MCP BI identifica admin, mas a chamada de consulta inspecionada não transporta escopo pessoal. Não existe evidência de runtime Koru integrado.

**Primeiro recorte:** Selecionar uma leitura operacional; derivar escopo no servidor; definir orçamento, atribuição e reconciliação sem carteira paralela.

**Dependências:** —.

**Aceite proposto:** Consulta permitida funciona; outro workspace é negado; revogação vale na próxima operação; retry não duplica débito.

**Limites:** Contrato operacional e regra de custo ainda precisam ser fechados na plataforma.

**Estimativa preliminar:** 10–20 dias úteis de engenharia para o recorte descrito, com baixa confiança; exclui espera por acesso, negociação, participantes e homologação externa. Não é compromisso de entrega. As estimativas compartilham trabalho e não devem ser somadas como um cronograma.

## Our Position

Fundação obrigatória, entregue junto da jornada 02 para evitar infraestrutura sem valor demonstrável.

Demanda disponível: pedido explícito do responsável pelo produto; sem confirmação independente de clientes. Aprovação da base do radar não equivale a aprovação desta prioridade ou a autorização para implementar em outro repositório.

**Próxima evidência:** executar o recorte com participante representativo e confrontar os casos de aceite; definir baseline e limiares antes do piloto. Reavaliar na próxima rodada do radar, ou antes se mudar uma dependência.
