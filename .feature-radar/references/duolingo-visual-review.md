# Duolingo: revisão das imagens dos artigos

## 2026-10-30 — Revisão visual complementar

**Source**: 28 artigos oficiais e URLs de imagens identificados abaixo.

**Cobertura:** 149 ocorrências de imagens no corpo e nas capas dos artigos HTML catalogados. Todas foram abertas para inspeção visual, incluindo ilustrações, screenshots, gráficos, tabelas e diagramas. A contagem inclui imagens repetidas entre artigos. A revisão complementa o [catálogo de engenharia](duolingo-engineering.md) e a [pesquisa de gamificação](../../docs/koru/GAMIFICATION.md).

**Método e limites:** inspeção em pranchas com identificadores, considerando texto e contexto da pesquisa. Quatro GIFs foram amostrados em cinco quadros cada (início, quartos e fim); isso não constitui revisão temporal integral. Texto muito pequeno não foi usado para extrair números ou instruções. Dois vídeos incorporados não foram analisados. PDFs, imagens de repositórios GitHub e páginas dos portais não fazem parte desta contagem. A revisão visual não transforma triagem em reprodução dos estudos.

**Implications:** observações por artigo abaixo são evidências visuais; aplicações à Koru são propostas nossas, ainda sujeitas a validação. Capas e logos foram inspecionados, mas não sustentam conclusões de eficácia. Os arquivos de imagem não foram copiados para o repositório.

| Artigo / fonte | Imagens | Observação e aplicação candidata |
|---|---:|---|
| 01. [Scaling Engineering with Agentic Workflows](https://blog.duolingo.com/agentic-workflows/) | 3 | Formulário separa parâmetros, prompt e repositório; a linha do tempo mostra etapas com durações distintas. Para Koru: tornar execução e etapa atual visíveis; a duração ilustrada não é SLA. |
| 02. [How We Automated iOS Unit Test Generation with AI](https://blog.duolingo.com/ai-ios-unit-test-generation-pipeline/) | 9 | Diagramas mostram seleção, geração, CI, recuperação e revisão; gráficos distinguem PRs criados de integrados. Para Koru: estados, limites de tentativas e revisão explícitos; volume de testes não comprova qualidade. |
| 03. [Triage, Debug, and Ship Code From Slack](https://blog.duolingo.com/aislackbot/) | 8 | Telas mostram prévia com Aprovar/Cancelar, fontes e resultado rastreável. Gráficos de adoção e votos têm limites de interpretação. Para Koru: confirmação contextual; comandos exibidos numa conversa não são instruções validadas para execução local. |
| 04. [How we used AI to scale Golden Path upgrades](https://blog.duolingo.com/automating-jvm-golden-path/) | 3 | Receita e fluxo combinam transformação determinística, IA e build antes do PR. Para Koru: validar cada transformação e limitar recuperação; não importar a stack JVM. |
| 05. [How We Built an AI Agent to Remove Feature Flags](https://blog.duolingo.com/buildingaiagents/) | 5 | Ação contextual inicia fluxo que termina em PR atribuído; duas imagens são logos. Para Koru: entrada próxima da tarefa e resultado revisável; logos não demonstram superioridade técnica. |
| 06. [Duolingo Blog](https://blog.duolingo.com/core-tabs-redesign/) | 13 | Comparações mostram headers, agrupamentos, contribuições e variantes exploradas. Para Koru: avaliar hierarquia e clareza da tarefa; variantes não equivalem a telas publicadas nem justificam substituir a navegação Flutter. |
| 07. [Duolingo Blog](https://blog.duolingo.com/dataset-development/) | 6 | Diagrama diferencia eventos e dataset canônico; screenshots mostram nomenclatura, diferenças de dados e estados de atualização. Para Koru: granularidade, reconciliação e frescor explícitos; um pico isolado não prova causa. |
| 08. [Why Duolingo Switched From Hearts to a Battery](https://blog.duolingo.com/duolingo-energy/) | 2 | Telas explicam energia e recompensas. Para Koru: retorno compreensível; não condicionar trabalho obrigatório a energia de jogo ou confundir recompensa com créditos de IA. |
| 09. [How Duolingo Leaderboards and Leagues Work](https://blog.duolingo.com/duolingo-leagues-leaderboards/) | 4 | Telas distinguem entrada, classificação e espera de torneio. Para Koru: contexto e validade temporal claros; posição competitiva não mede qualidade operacional. |
| 10. [Friends Quests Are Duolingo’s Newest Social Feature](https://blog.duolingo.com/friends-quests/) | 4 | Convite, progresso por pessoa, mensagem e recompensa aparecem separados; GIF amostrado mostra celebração em etapas. Para Koru: colaboração voluntária e envio explícito; não transformar pontos em créditos. |
| 11. [Duolingo’s Best Social Features](https://blog.duolingo.com/friends-social-features/) | 3 | Convites pendentes e participantes ativos têm ações diferentes; escolha de parceiro antecede o próximo ciclo. Para Koru: tornar consentimento e momento da participação visíveis. |
| 12. [Frontend Prediction in Mobile Apps: Tradeoffs and Lessons](https://blog.duolingo.com/frontend-prediction/) | 14 | Diagramas diferenciam espera, atualização local e reconciliação; telas de mensagens incluem envio, falha e recuperação. Para Koru: resposta imediata com estado pendente; nunca antecipar confirmação de escrita ou cobrança. GIFs não medem latência. |
| 13. [How the Duolingo Owl Decides What Notification To Send](https://blog.duolingo.com/hi-its-duo-the-ai-behind-the-meme/) | 5 | Templates, ciclo de seleção e curvas mostram personalização e recência; o mesmo texto recebe resultados distintos conforme contexto. Para Koru: testar utilidade e resultado operacional, sem importar mensagens de culpa. |
| 14. [The Duolingo Streak Uses Habit Research to Keep You Motivated](https://blog.duolingo.com/how-duolingo-streak-builds-habit/) | 4 | Calendário, celebração e proteção da sequência explicam continuidade e recuperação. Para Koru: reconhecer turnos elegíveis; proteção paga de hábito não deve virar requisito de trabalho. |
| 15. [Duolingo Blog](https://blog.duolingo.com/improving-the-streak/) | 4 | Telas separam meta de atividade e sequência; gráfico compara variantes sem permitir inferir sozinho toda a metodologia. Para Koru: distinguir participação de conformidade e validar resultados localmente. |
| 16. [Engineering Lessons from Search and Rescue Incidents](https://blog.duolingo.com/incident-management-lessons/) | 2 | Capa e fotografia contextualizam o relato; não são diagramas de incidentes nem evidência de tempo de recuperação. Para Koru: não atribuir métricas a imagens ilustrativas. |
| 17. [Duolingo’s New Mini-Units Make Bite-Sized Learning Easier Than Ever](https://blog.duolingo.com/intermediate-mini-units/) | 2 | Caminho alterna prática, conteúdo e recompensas. Para Koru: aproximar ensino do uso; unidades menores não autorizam omitir etapas operacionais obrigatórias. |
| 18. [How to Practice a Language as an Introvert: 6 Tips](https://blog.duolingo.com/introvert-language-learning-tips/) | 14 | Telas mostram caminhos distintos de preferências no app, web móvel e desktop, incluindo opções sociais e privacidade. Para Koru: saída acessível e preferências por canal; não assumir paridade automática. |
| 19. [How Optimistic Locking Solved Our Database Contention](https://blog.duolingo.com/optimistic-locking/) | 10 | Diagramas mostram espera, versão e conflito de escrita; comparação de barras não oferece escala suficiente para calcular ganho. Para Koru: validar versão e reduzir duração de locks; retry não renova consentimento. |
| 20. [2025 Duolingo Highlights: our biggest leaps in learning, play, and connection](https://blog.duolingo.com/product-highlights/) | 6 | Telas mostram modalidades de exercícios, chamada com saída e legendas, além de interação musical. Para Koru: voz opcional com alternativas; screenshots não comprovam latência de áudio em tempo real. |
| 21. [How We Built the Friend Streak on Duolingo](https://blog.duolingo.com/product-lessons-friend-streak/) | 4 | Telas distinguem convite, aceite/recusa, sequência compartilhada e celebrações; funil explicita progressão de participação. Para Koru: medir convite aceito e colaboração útil, preservando opção de recusar e períodos de descanso. |
| 22. [How Duolingo Built a Production-Ready AI Agent Platform](https://blog.duolingo.com/production-ready-ai-agent-platform/) | 1 | A única imagem é uma capa ilustrativa. A arquitetura discutida no texto não está demonstrada por um diagrama nesta página; não inventar evidência visual. |
| 23. [Duolingo Blog](https://blog.duolingo.com/protecting-streaks-from-site-issues/) | 4 | Aviso explica manutenção e proteção; linhas do tempo distinguem dia sem atividade de sequência preservada. Para Koru: comunicar indisponibilidade e reparação sem registrar trabalho que não aconteceu. |
| 24. [How One Code Change Reduced CPU Usage by 97%](https://blog.duolingo.com/reduce-cpu-usage-97-percent/) | 4 | Painel mostra falhas e gráficos comparam CPU antes/depois, com janelas e escalas próprias. Para Koru: preservar unidade e contexto de medição; ganhos desse incidente não são previsão de economia local. |
| 25. [4 Learnings from Duolingo Efficacy Studies](https://blog.duolingo.com/results-duolingo-efficacy-studies/) | 3 | Gráficos separam leitura e escuta, referências A2 e comparação de currículos; há barras de erro e eixos com origem acima de zero. Para Koru: avaliar metodologia antes de transferir eficácia de aprendizagem para desempenho operacional. |
| 26. [Duolingo Blog](https://blog.duolingo.com/sped-up-android-ios-builds/) | 3 | Tabela separa Android build+testes de iOS build e distribui mudanças por iteração; mensagens trazem percepção da equipe. Para Koru: comparar escopos equivalentes; feedback qualitativo não substitui medições. |
| 27. [Duolingo Blog](https://blog.duolingo.com/streak-celebration-parties/) | 4 | Certificado, kit e peça humorística ampliam celebração para fora do app. Para Koru: reconhecimento opcional ligado a resultado; material de campanha não prova retenção ou produtividade. |
| 28. [Understanding Duolingo’s Time Spent Learning Well Metric](https://blog.duolingo.com/time-spent-learning-well/) | 5 | Fórmula pondera tipos de atividade; telas mostram incentivos e gráfico compara ajustes de XP. Para Koru: definir qualidade antes de premiar uso; tempo na ferramenta não equivale a tempo operacional bem empregado. |

### Inventário verificável

Cada ID corresponde a uma ocorrência inspecionada; o link aponta para o ativo original. “Estática” descreve o método de inspeção, não uma avaliação de acessibilidade ou reprodução da interface.

| ID | Fonte visual | Dimensões | Inspeção |
|---|---|---|---|
| 01-01 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2025/12/cover_Agentic-Workflows--Scale-AI-Prompts-Beyond-Cursor-----No-Code-Required-2.png) | 900 × 600 | Estática |
| 01-02 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2025/12/1-1.png) | 1948 × 1846 | Estática |
| 01-03 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2025/12/2-2.png) | 2000 × 786 | Estática |
| 02-01 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/06/cover_AI-iOS-unit-test-generation-pipeline.png) | 2042 × 1046 | Estática |
| 02-02 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/06/1-2.png) | 1794 × 682 | Estática |
| 02-03 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/06/2-1.png) | 1816 × 422 | Estática |
| 02-04 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/06/3-1.png) | 1752 × 1176 | Estática |
| 02-05 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/06/4.png) | 2000 × 442 | Estática |
| 02-06 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/06/5.png) | 1790 × 1022 | Estática |
| 02-07 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/06/data-src-image-eab18157-e294-44c7-9103-4618ac1bba18.png) | 2048 × 604 | Estática |
| 02-08 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/06/data-src-image-769559d5-584f-4fe1-b78a-728cfd5b8c4d.png) | 2000 × 861 | Estática |
| 02-09 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/06/data-src-image-9d055f4d-7a72-4118-8871-aac30979e789.png) | 1996 × 1352 | Estática |
| 03-01 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/05/cover_Triage--ship--debug---all-from-Slack.png) | 900 × 600 | Estática |
| 03-02 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/05/1.png) | 1440 × 814 | Estática |
| 03-03 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/05/2.png) | 1446 × 734 | Estática |
| 03-04 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/05/3.png) | 1430 × 1172 | Estática |
| 03-05 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/05/4.png) | 1426 × 1212 | Estática |
| 03-06 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/05/5.png) | 1418 × 800 | Estática |
| 03-07 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/05/6.png) | 1430 × 712 | Estática |
| 03-08 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/05/7.png) | 1454 × 720 | Estática |
| 04-01 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2025/12/cover_Automating-Golden-Path-upgrades-at-scale--a-journey-from-manual-upgrades-to-an-AI-powered-workflow.png) | 900 × 600 | Estática |
| 04-02 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2025/12/1-2.png) | 2000 × 772 | Estática |
| 04-03 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2025/12/2-3.png) | 2000 × 796 | Estática |
| 05-01 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2025/12/cover_Building-an-AI-Agent-to-Remove-Feature-Flags.png) | 900 × 600 | Estática |
| 05-02 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2025/12/1.png) | 1896 × 664 | Estática |
| 05-03 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2025/12/2.png) | 2000 × 265 | Estática |
| 05-04 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2025/12/3-1.png) | 1048 × 1046 | Estática |
| 05-05 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2025/12/4.png) | 1152 × 1192 | Estática |
| 06-01 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/01/cover_growth-tab-refresh.png) | 900 × 600 | Estática |
| 06-02 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/01/1.-Caption.-Refreshed-bottom-tabs.png) | 2778 × 3713 | Estática |
| 06-03 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/01/2.-Caption.-Inconsistent-headers--typography--and-spacing.png) | 2778 × 2024 | Estática |
| 06-04 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/01/3.-Option-2---Caption.-Initial-explorations.png) | 2778 × 3712 | Estática |
| 06-05 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/01/4.-Caption.-Punchy_-solid--vibrant-colored-headers-1.png) | 2000 × 1457 | Estática |
| 06-06 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/01/5.-Caption.-Soft_-calming-gradients-and-colors.-1.png) | 2000 × 1457 | Estática |
| 06-07 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/01/6.-Caption.-Modular_-card-based-flexible-layout-1.png) | 2778 × 2024 | Estática |
| 06-08 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/01/7.-Caption.-Flat_-minimal-layout-with-heavy-white-space-1.png) | 2000 × 1457 | Estática |
| 06-09 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/01/8.-Caption.-Inefficient-use-of-space-1.png) | 2778 × 2024 | Estática |
| 06-10 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/01/9.-Caption.-Lack-of-clarity.png) | 2000 × 1457 | Estática |
| 06-11 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/01/10.-Caption.-Consistent-header-size-and-title-placement-1.png) | 2778 × 2024 | Estática |
| 06-12 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/01/11.-Caption.-Cleaned-up-visual-spacing-1.png) | 2778 × 2024 | Estática |
| 06-13 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/01/12.-Caption.-Tab-Refresh.-Before-and-after-comparison-1.png) | 2000 × 1457 | Estática |
| 07-01 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2025/03/Screenshot-2025-03-14-at-5.18.13-PM.png) | 1774 × 1184 | Estática |
| 07-02 | [Imagem](https://lh7-rt.googleusercontent.com/docsz/AD_4nXc8A_2bebzc2J12dhz6WQ4RwwdCuhS0OUbTjlKutvvPaRS_e7kiWW_KWygT5Y51_9I2vlu_2wK1QfazhDA0LRedzZcvcK-TYc-S_xeGwIyKW0rI2Vc0rTwqcJyff7PQwx2LYnYeLg?key=C7AxJCtEG6Yh3dxAGTW-Iv4a) | 1600 × 1282 | Estática |
| 07-03 | [Imagem](https://lh7-rt.googleusercontent.com/docsz/AD_4nXcbfdcGSdkoLTabs6xQ1LTLG5509B2UiC4rtutk2Jn7H1h5mnK2UrzalH0rA0gwmoNZ3pwA8HsZwKpuunRAVr65ch8RJKUvLOIFdrenZYSNCS0OmB0l0SF4jJbGZDwm3u7ZjGrSPw?key=C7AxJCtEG6Yh3dxAGTW-Iv4a) | 1600 × 470 | Estática |
| 07-04 | [Imagem](https://lh7-rt.googleusercontent.com/docsz/AD_4nXfkoWw9w1iza2ZfMaOLcfg51JafvDH3XS9l_VQ5iGZGQM4eJ4KbqwyjoasSWSleUn7YYAymlmI7KfVyLaOwXx2HjLBa97y6HlzzaaEGKbi0SRbCZeCATNYuAwzRqqVMV5fy3h-mTg?key=C7AxJCtEG6Yh3dxAGTW-Iv4a) | 1600 × 1199 | Estática |
| 07-05 | [Imagem](https://lh7-rt.googleusercontent.com/docsz/AD_4nXfJY9dAelpXNiVe5fuU4STeXcRY11BVHPgYwIwrSgpbWuPBNWM16wOAaUjbk3ypsioSi3JW_5qT1zKqA16rOIerCMNqZzTafPDCN3jH4MXFWIo-dotlPhG31bAxyiC65NoHTE17lA?key=C7AxJCtEG6Yh3dxAGTW-Iv4a) | 1600 × 616 | Estática |
| 07-06 | [Imagem](https://lh7-rt.googleusercontent.com/docsz/AD_4nXdpRF2gj_EaVWW-XaJL4Xo_ZDjiNHC2I9WGh4TSX4Xa84te8x3bheEzBZKw1evMP0a_kRe8nf_iw0pxCJtzzcI3q4ANPSEC9hCu-n_uRzi-78ELB_tty-hVfJnN2xu7in2sKLHD?key=C7AxJCtEG6Yh3dxAGTW-Iv4a) | 1186 × 382 | Estática |
| 08-01 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2025/07/cover_DuolingoEnergy.png) | 1800 × 1200 | Estática |
| 08-02 | [Imagem](https://lh7-rt.googleusercontent.com/docsz/AD_4nXd0YuztXwxsNGMDnDRxOJRxTJO1sTg--kJibnRfFKrsLaVB_UYlRAYwHiQ3KYf9ZU-AzF6Ucm7jLqYyFwdGVoEMw2QYuLG25oVZspvAsVMKLtZBTN9sbNHayGYwnikw0ocP-G6exQ?key=O8IRLK1i3bqyJNL6PN3pmQ) | 1600 × 914 | Estática |
| 09-01 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2024/05/cover_howLeaderboardsWork.png) | 900 × 600 | Estática |
| 09-02 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2023/04/How-Do-We-Decide-Who-Gets-in-Which-League--1--2.png) | 676 × 260 | Estática |
| 09-03 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2023/04/diamond-tournie.png) | 1278 × 720 | Estática |
| 09-04 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2023/04/tournament-soon--1-.png) | 702 × 615 | Estática |
| 10-01 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2024/06/cover_Introducing-Friends-Quests-a-fun-way-to-team-up-and-learn.png) | 900 × 600 | Estática |
| 10-02 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2022/09/SHARE-CARD--1-.png) | 311 × 311 | Estática |
| 10-03 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2022/09/image.png) | 1712 × 1346 | Estática |
| 10-04 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2022/09/Friend_Quest_Chest_04.gif) | 375 × 500 | GIF: 5 de 142 quadros |
| 11-01 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2024/06/cover_4-reasons-duolingo-is-more-fun-with-friends.png) | 900 × 600 | Estática |
| 11-02 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2024/11/friend-streak-screen-drawer.png) | 2000 × 1143 | Estática |
| 11-03 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2023/05/pick-fq-partner--1-.png) | 451 × 492 | Estática |
| 12-01 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/04/cover_Seeing-the-Future_Frontend-Prediction-in-Duolingo---s-Mobile-App.png) | 900 × 600 | Estática |
| 12-02 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/04/data-src-image-b596a57f-59a3-4500-8962-c4544ac42ba0.png) | 1354 × 864 | Estática |
| 12-03 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/04/data-src-image-b1cda8d4-8161-4942-85f5-5c55412843bd.png) | 1600 × 984 | Estática |
| 12-04 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/04/data-src-image-014862aa-ba1b-4c51-a5ed-f4d2ee522cac-1.png) | 739 × 1600 | Estática |
| 12-05 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/04/data-src-image-78ed7da0-8f8c-4f92-a694-a131cf2f0ac6.png) | 1330 × 1304 | Estática |
| 12-06 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/04/data-src-image-dba3b326-da62-4b98-9b39-cc4325cad088-1.png) | 750 × 1334 | Estática |
| 12-07 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/04/6.png) | 1346 × 816 | Estática |
| 12-08 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/04/data-src-image-baaad55e-16e8-46bb-a774-83e6078b80ec.png) | 996 × 1174 | Estática |
| 12-09 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/04/data-src-image-40fb1181-4aa1-484e-b8ea-8ec5a84e0284.png) | 994 × 1032 | Estática |
| 12-10 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/04/9.png) | 854 × 904 | Estática |
| 12-11 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/04/10.gif) | 557 × 306 | GIF: 5 de 64 quadros |
| 12-12 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/04/11.gif) | 359 × 290 | GIF: 5 de 27 quadros |
| 12-13 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/04/12.png) | 302 × 510 | Estática |
| 12-14 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/04/13-1.png) | 800 × 890 | Estática |
| 13-01 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2024/06/cover_Hi-it-s-Duo-Meet-the-AI-behind-the-meme-1.png) | 900 × 600 | Estática |
| 13-02 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2020/09/SM_090320-small.png) | 523 × 523 | Estática |
| 13-03 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2020/09/Blog_Notifications_Steps.png) | 1149 × 1149 | Estática |
| 13-04 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2020/09/Blog_Notifications1_small.png) | 443 × 383 | Estática |
| 13-05 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2020/09/image--8-.png) | 1172 × 694 | Estática |
| 14-01 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2024/05/cover_streak-habit.png) | 900 × 600 | Estática |
| 14-02 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2022/01/build-a-learning-habit.png) | 622 × 296 | Estática |
| 14-03 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2022/01/streakanimation.gif) | 204 × 400 | GIF: 5 de 150 quadros |
| 14-04 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2022/01/Streak-Freeze--2-.png) | 640 × 403 | Estática |
| 15-01 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2024/06/cover_Improving-the-streak-Forming-habits-one-lesson-at-a-time.png) | 900 × 600 | Estática |
| 15-02 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2020/11/Screen-Shot-2020-11-13-at-5.28.46-PM.png) | 918 × 798 | Estática |
| 15-03 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2020/11/Screen-Shot-2020-11-13-at-5.19.05-PM.png) | 920 × 820 | Estática |
| 15-04 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2020/11/Screen-Shot-2020-11-13-at-5.21.37-PM-1.png) | 1894 × 1002 | Estática |
| 16-01 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/03/cover_What-I-learned-about-incident-management-from-search-and-rescue.png) | 900 × 600 | Estática |
| 16-02 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/03/badlands.png) | 1436 × 948 | Estática |
| 17-01 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/02/cover_mini-units.png) | 900 × 600 | Estática |
| 17-02 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/02/mini-unit_-ES_EN--2.png) | 750 × 2012 | Estática |
| 18-01 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/09/cover_enDDmailbox_gold.png) | 1350 × 900 | Estática |
| 18-02 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/09/ddLetter_introvert-language-learning-tips.png) | 1800 × 1200 | Estática |
| 18-03 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/09/Duo_PencilBoarding.png) | 1101 × 911 | Estática |
| 18-04 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/09/Duo_microphone.png) | 800 × 800 | Estática |
| 18-05 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/09/Duo_headphones_music4.png) | 516 × 440 | Estática |
| 18-06 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/09/DD-introvert-learning_profile.png) | 2160 × 4340 | Estática |
| 18-07 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/09/DD-introvert-learning_settings.png) | 2160 × 4340 | Estática |
| 18-08 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/09/DD-introvert-learning_preferences.png) | 2160 × 4340 | Estática |
| 18-09 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/09/DD-introvert-learning_Friends-Quests-Friend-Streaks.png) | 2160 × 4340 | Estática |
| 18-10 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/09/DD-introvert-learning_mobile-profile.png) | 366 × 759 | Estática |
| 18-11 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/09/DD-introvert-learning_mobile-settings--1--1.png) | 365 × 759 | Estática |
| 18-12 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/09/DD-introvert-learning_desktop-settings.png) | 1782 × 1214 | Estática |
| 18-13 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/09/DD-introvert-learning_desktop-privacy-settings.png) | 1782 × 1214 | Estática |
| 18-14 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/09/DD-introvert-learning_desktop-public-profile.png) | 1782 × 1214 | Estática |
| 19-01 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2025/12/cover_Solving-database-contention-with-optimistic-locking.png) | 900 × 600 | Estática |
| 19-02 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2025/12/1-3.png) | 2000 × 1084 | Estática |
| 19-03 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2025/12/2-4.png) | 1890 × 880 | Estática |
| 19-04 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2025/12/3-2.png) | 1308 × 776 | Estática |
| 19-05 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2025/12/4-1.png) | 1246 × 650 | Estática |
| 19-06 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2025/12/5.png) | 1718 × 1156 | Estática |
| 19-07 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2025/12/6.png) | 1736 × 1058 | Estática |
| 19-08 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2025/12/7.png) | 1738 × 580 | Estática |
| 19-09 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2025/12/8.png) | 1210 × 848 | Estática |
| 19-10 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2025/12/9.png) | 1932 × 1496 | Estática |
| 20-01 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2025/12/cover-DuolingoProductYIR.png) | 900 × 600 | Estática |
| 20-02 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2025/12/EN-DuolingoProductYIR-DuolingoChessPvP.png) | 1400 × 800 | Estática |
| 20-03 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2025/12/EN-DuolingoProductYIR-Score.png) | 1400 × 800 | Estática |
| 20-04 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2025/12/EN-DuolingoProductYIR-Learning.png) | 1400 × 800 | Estática |
| 20-05 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2025/12/EN-DuolingoProductYIR-Video-Call-1.png) | 1400 × 800 | Estática |
| 20-06 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2025/12/EN-DuolingoProductYIR-Math---Music-1.png) | 1400 × 800 | Estática |
| 21-01 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2024/09/cover_FriendStreak-2.png) | 900 × 600 | Estática |
| 21-02 | [Imagem](https://lh7-rt.googleusercontent.com/docsz/AD_4nXe0vwO-Iu8WM69Q3knOqveP2mbMQdlm0QJiNv4jAJsnYIqijVaurX7saCA3J4ZF7eYEEE0xej9zepb9tTfmch733HWRVYpwLebWr40ax5n1oCoEzQ1UA5km_ZwdniwZ7-FLLZGsWoNPTrrDkHwGSAZvCySU?key=A0zgt6iafIs2Uw1ZdFxVFw) | 1600 × 900 | Estática |
| 21-03 | [Imagem](https://lh7-rt.googleusercontent.com/docsz/AD_4nXchxNInjJJdxNgSpddNfrcA_-HPEPJwtM_ttsIx6C6HVaJ61Ejqcw36vLjvUprrv7c_LFA4Fg_jqObCQ8DZ9La4P89hfOIlpNo9pdkhQPYkpd8DTELbcT_4GoTf8mqjCrdGbqWJVGyvvJ1nUzjBwgiJ5ic?key=A0zgt6iafIs2Uw1ZdFxVFw) | 1600 × 900 | Estática |
| 21-04 | [Imagem](https://lh7-rt.googleusercontent.com/docsz/AD_4nXeIWLavIpzvrPLL1kourU6v9B_w0SU_ZClsxR5CXAi-t39fHwRL3mjbEUexX3F6XXnm9d9wiMIYVd5jNvZ3lI4a-qPgnUxfyNOXGUhtrT1OMizHMrLID8kxkrzEMeCIR3CBU-VrAVcVg1qIPGtlrZ-fiZ5y?key=A0zgt6iafIs2Uw1ZdFxVFw) | 1400 × 800 | Estática |
| 22-01 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/08/cover_Production-ready-agent-AI.png) | 900 × 600 | Estática |
| 23-01 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2024/06/cover_How-we-protect-learner-streaks-from-site-issuescover_streak-habit.png) | 901 × 600 | Estática |
| 23-02 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2021/10/BRB_maintenance-1.png) | 512 × 288 | Estática |
| 23-03 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2021/10/Frame-1.png) | 2040 × 376 | Estática |
| 23-04 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2021/10/Frame-2.png) | 2040 × 480 | Estática |
| 24-01 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/06/cover_How-a-simple-code-change-reduced-CPU-usage-by-97_.png) | 900 × 600 | Estática |
| 24-02 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/06/1.png) | 2000 × 592 | Estática |
| 24-03 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/06/2-2.png) | 1340 × 523 | Estática |
| 24-04 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/06/3-2.png) | 1340 × 537 | Estática |
| 25-01 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2024/09/cover_efficacy-lab.png) | 900 × 600 | Estática |
| 25-02 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2024/09/body_efficacy-graph-1-1.png) | 1400 × 800 | Estática |
| 25-03 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2024/09/body_efficacy-graph-2.png) | 1400 × 800 | Estática |
| 26-01 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2024/12/DuolingoBlogCover.png) | 900 × 600 | Estática |
| 26-02 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2024/12/image-4.png) | 1688 × 484 | Estática |
| 26-03 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2024/12/image-2.png) | 1998 × 670 | Estática |
| 27-01 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2024/05/cover_streak-celebration.png) | 900 × 600 | Estática |
| 27-02 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2023/12/streak-certificate--2-.png) | 2000 × 1081 | Estática |
| 27-03 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2024/01/20240110_0010_v3-Fix.png) | 2000 × 1600 | Estática |
| 27-04 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2023/12/doctor-s-note--3-.png) | 1322 × 779 | Estática |
| 28-01 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2024/06/behindthemetric_tslw.png) | 900 × 600 | Estática |
| 28-02 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2024/09/seconds-per-lesson--6-.png) | 1400 × 800 | Estática |
| 28-03 | [Imagem](https://lh7-us.googleusercontent.com/docsz/AD_4nXeoXq61OwR8_V0DxuPAJLd9aFrdaIxhFwzEB3zmpQSQOK27_-aaLz6SrRVoF-zvC0hzA0qhwOL0rBG7ClIKPd7ppPuzjOORRG5eRvEBWUB48NyBQta1eRWnesgVDjRz1IQm9XNbsHtZlps2_aJNL469EK2Z?key=XHNW4BX7oha4rR-m6Uvayg) | 1392 × 206 | Estática |
| 28-04 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2024/06/quests-leaderboards--1-.png) | 1400 × 800 | Estática |
| 28-05 | [Imagem](https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2024/06/image.png) | 2000 × 1114 | Estática |

### Mídia incorporada fora da revisão visual

- Artigo 08: [mídia incorporada](https://www.youtube.com/embed/4ekjWHhtrYM?feature=oembed) — não analisada.
- Artigo 09: [mídia incorporada](https://www.youtube.com/embed/oZeVj9wGUz4?feature=oembed) — não analisada.
