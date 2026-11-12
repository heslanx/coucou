# 07. Conversa de voz em tempo real

**Status**: Open
**Impact**: High
**Effort**: High
**Tier**: Build soon
**Updated**: 2026-10-30
**Ref**: [Documento dono](../../docs/koru/PLATFORMS.md) · [Avaliação](../review.md)

## Description

Ajudar quem está com as mãos ocupadas a conversar, corrigir e retomar tarefas.

## Design Notes

**Evidência atual:** Há clientes locais e intenção documentada; não há sessão de voz Koru integrada comprovada.

**Primeiro recorte:** Primeiro pressionar para falar ou iniciar sessão explícita; transcrição, interrupção, texto alternativo e custo limitado; comparar Flutter e ponte nativa.

**Dependências:** 01, 02; 03 para ações.

**Aceite proposto:** Medir sucesso da mesma tarefa com ruído, latência p50/p95, correções, interrupção e bateria; nenhuma confirmação crítica decorre só de transcrição ambígua.

**Limites:** Fornecedor, tarifa, retenção e capacidade por SO pendentes. Palavra Koru em background não está garantida.

**Estimativa preliminar:** 15–30 dias úteis de engenharia para o recorte descrito, com baixa confiança; exclui espera por acesso, negociação, participantes e homologação externa. Não é compromisso de entrega. As estimativas compartilham trabalho e não devem ser somadas como um cronograma.

## Our Position

Pesquisar em paralelo; entregar após fluxo textual correto. Palavra de ativação permanece Monitor dentro desta oportunidade.

Demanda disponível: pedido explícito do responsável pelo produto; sem confirmação independente de clientes. Aprovação da base do radar não equivale a aprovação desta prioridade ou a autorização para implementar em outro repositório.

**Próxima evidência:** executar o recorte com participante representativo e confrontar os casos de aceite; definir baseline e limiares antes do piloto. Reavaliar na próxima rodada do radar, ou antes se mudar uma dependência.
