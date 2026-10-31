# ADR-003: Uma Koru multiplataforma com capacidades adaptadas por canal

## Status

**Complementado pelo [ADR-005](ADR-005-koru-mobile-evolution.md):** Flutter existente como caminho inicial provável no mobile e exploração nativa em paralelo. Preserva-se abaixo o contexto original da decisão multiplataforma.

**Accepted — direção de produto:** apps para macOS, iPadOS, iOS, Android, Windows, Linux e web; explorar voz em tempo real, alertas e ativação “Koru” onde possível. **Proposed:** estratégia de implementação, ordem, fornecedores e uso de skill oficial no Echo comercial.

## Date

2026-10-30.

## Context

A Koru precisa acompanhar trabalho individual e estações compartilhadas. Sistemas operacionais e Echo oferecem permissões diferentes de áudio, notificações, instalação e execução em segundo plano. Um protótipo de navegador ou skill não prova equivalência entre plataformas.

## Decision

Compartilhar contexto, ferramentas, autorização e cobrança; adaptar clientes ao dispositivo. Tratar ativação, sessão de voz e alertas como capacidades distintas. Garantir caminho de toque/texto e continuidade segura; ativação por palavra não é promessa universal nem método de autenticação.

Proposta comercial: começar o Echo pelo caminho oficial e vinculação de conta. Manter firmware modificado como pesquisa de hardware separada. Se controle permanente de tela e palavra própria forem essenciais, avaliar dispositivo dedicado com suporte sob controle da Koncluí.

## Alternatives Considered

- **Somente web:** alcance rápido, mas não cumpre sozinho apps instaláveis e integração de sistema em todos os alvos.
- **Mesmo comportamento em todos os sistemas:** simplifica comunicação, mas promete capacidades que não foram demonstradas; rejeitado.
- **Echo desbloqueado como base da distribuição:** oferece controle, porém depende de hardware e operação de firmware; não escolhido nesta proposta.
- **Um único framework ou clientes nativos:** decisão ainda aberta; avaliar reuso, recursos de plataforma e manutenção com provas curtas.

## Consequences

Criar matriz de suporte com versões e casos reais de background/áudio. Não anunciar “sempre ouvindo”, “offline” ou alertas instantâneos universais. Oferecer opt-in de microfone, controle de custo e entrega multicanal. Modificar aparelho de cliente exige decisão específica; este ADR não a concede.

Detalhamento: [plataformas](../koru/PLATFORMS.md).
