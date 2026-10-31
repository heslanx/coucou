# Fontes de engenharia a acompanhar

> Lista de fontes primárias e protocolo de atualização; não há monitoramento automático ativado.

## 2026-10-30 — Fontes iniciais além do Duolingo

**Source**: portais oficiais vinculados na tabela; todos abertos nesta consulta.

| Organização / fonte | Temas a procurar conforme a tarefa | Profundidade desta consulta |
|---|---|---|
| [Spotify Engineering](https://engineering.atspotify.com/) | Experiência de desenvolvimento, qualidade, experimentação, personalização | Portal consultado; nenhum case novo adotado |
| [Shopify Engineering](https://shopify.engineering/) | Apps de negócio, desempenho, plataforma e evolução de arquitetura | Portal consultado; leitura dirigida pendente |
| [Google SRE](https://sre.google/books/) | Confiabilidade, incidentes, operação e limites de serviço | Catálogo consultado; livros não integralmente revisados |
| [Amazon Builders’ Library](https://builder.aws.com/learn/topics/builders-library) | Sistemas distribuídos, retries, idempotência e operação | Catálogo consultado; URL antiga da AWS redireciona para este endereço |
| [Anthropic Engineering](https://www.anthropic.com/engineering) | Agentes, contexto, ferramentas e avaliações | Portal consultado; selecionar artigo conforme decisão |
| [OpenAI Engineering](https://openai.com/news/engineering/) | Operação de IA, infraestrutura e experiências de produto | Portal consultado; não define provedor da Koru |
| [Engineering at Meta](https://engineering.fb.com/) | Mobile, desempenho, dados, infraestrutura e qualidade | Portal consultado; não extrapolar escala para a Koncluí |

**Implications**:

O tamanho da empresa é um critério para encontrar experiências relevantes, não uma prova de que sua solução serve ao nosso contexto. Cada leitura deve responder a um problema nomeado da Koru/Flutter/plataforma. Incluir resultados negativos, alternativas descartadas e custo de operação, além de ganhos divulgados.

### Cadência proposta e gatilhos

- Em cada nova sessão de planejamento do radar: revisar referências relacionadas ao escopo e itens adiados com condição de reavaliação.
- Antes de decisão de arquitetura, novo conector, mudança de plataforma ou otimização: fazer leitura dirigida atualizada e confrontar com o código dono.
- Revisão mensal sugerida para produto e engenharia: triar novidades dos portais, deduplicar URLs e selecionar poucas leituras relevantes. Responsáveis e agenda ainda não foram atribuídos.
- Após incidente ou experimento: atualizar o que foi aprendido e registrar quando a referência não se transferiu ao nosso caso.

Não há cron, assinatura, bot, coleta contínua ou notificação externa configurados. A continuidade depende de executar esse protocolo nas próximas sessões ou de implementar uma automação específica depois.

### Ficha mínima de aprendizado

Registrar: URL canônica; organização/autor; data de publicação e atualização quando disponível; data de consulta; versão/commit se relevante; profundidade (triagem, leitura técnica, reprodução local); problema original; contexto/escala; evidência e limites; hipótese para Koncluí; alternativas; experimento mínimo; medida de sucesso/falha; responsável; decisão e próxima revisão.

Estados de pesquisa: **capturada → triada → estudada → experimentada → adotada ou descartada**. Adiada mantém justificativa e gatilho de revisão. Triagem não vira automaticamente uma oportunidade de produto. Somente após demonstrar relevância, vincular oportunidade, contrato ou ADR; não sobrescrever decisões anteriores silenciosamente.

### Critério para incorporar

1. Existe problema local e sua origem foi observada?
2. A fonte primária explica mecanismo, contexto e limitações?
3. A solução respeita Flutter existente, clientes antigos, autorização, dados e créditos?
4. Há alternativa menor com os componentes atuais?
5. Podemos medir a hipótese e reverter se não funcionar?
6. A pessoa responsável aprovou a mudança quando ela envolve dependência, operação ou contrato novo?

Nenhuma quantidade de posts lidos substitui entrevistas, testes com usuários ou resultados operacionais. Não criar uma nova regra global de desenvolvimento a partir deste catálogo: os repositórios donos mantêm suas instruções e verificações.

### Leitura obrigatória de todas as imagens

Por orientação explícita do usuário, analisar **todas as imagens de cada artigo**, junto com o texto: capas, ilustrações, screenshots, diagramas, gráficos, tabelas e respectivas legendas. Não substituir inspeção visual por texto alternativo, OCR, resumo da página ou leitura apenas do corpo textual.

1. Inventariar as imagens do artigo e registrar URL, identificador, data e quantidade; conferir também conteúdo carregado sob demanda quando houver.
2. Abrir cada imagem; ampliar diagramas, eixos, unidades, legendas e microcopy quando necessários para entender a evidência. Relacionar a imagem à passagem do artigo.
3. Distinguir resultado publicado, variante explorada, ilustração e interpretação nossa. Registrar alternativas descartadas e contradições com o texto.
4. Registrar observações e implicações para a Koru, com links rastreáveis. Não inferir causalidade, números ou desempenho a partir de uma imagem que não os sustenta.
5. Declarar imagens indisponíveis ou ilegíveis como pendentes. Em animações, informar se a inspeção foi integral ou por amostragem; vídeos e figuras de PDFs têm cobertura própria.
6. Só declarar a revisão visual completa no escopo efetivamente inspecionado. Uma pendência visual relevante mantém a pesquisa parcialmente estudada.

Revisão retroativa inicial: [149 imagens de 28 artigos Duolingo](duolingo-visual-review.md), com método e limitações registrados. Aplicar este protocolo às próximas leituras de qualquer organização, incluindo as fontes desta lista.
