# 09. Aplicativos e continuidade entre dispositivos

**Status**: Partially Done
**Impact**: High
**Effort**: High
**Tier**: Build soon
**Updated**: 2026-10-30
**Ref**: [Documento dono](../../docs/koru/PLATFORMS.md) · [Avaliação](../review.md)

## Description

Levar a mesma tarefa autorizada a celular, tablet, desktop e web com interação adequada.

## Design Notes

**Evidência atual:** Existem clientes Swift, Kotlin e Tauri locais e Flutter externo; não há paridade funcional Koru demonstrada.

**Primeiro recorte:** Primeiro continuidade entre dois canais; contratos comuns e sessão revogável; pesquisa nativa paralela por capacidade, sem reescrita antecipada.

**Dependências:** 01, 02.

**Aceite proposto:** Retomar tarefa não duplica ação nem custo; logout remove acesso; versões antigas convivem; acessibilidade, instalação e atualização verificadas por canal.

**Limites:** Estimativa cobre uma fatia de dois canais, não todos os sistemas; expansão exige matriz de suporte e orçamento próprios.

**Estimativa preliminar:** 30–60 dias úteis de engenharia para o recorte descrito, com baixa confiança; exclui espera por acesso, negociação, participantes e homologação externa. Não é compromisso de entrega. As estimativas compartilham trabalho e não devem ser somadas como um cronograma.

## Our Position

Flutter inicial; homologar novos clientes conforme evidência de uso e benefício.

Demanda disponível: pedido explícito do responsável pelo produto; sem confirmação independente de clientes. Aprovação da base do radar não equivale a aprovação desta prioridade ou a autorização para implementar em outro repositório.

**Próxima evidência:** executar o recorte com participante representativo e confrontar os casos de aceite; definir baseline e limiares antes do piloto. Reavaliar na próxima rodada do radar, ou antes se mudar uma dependência.
