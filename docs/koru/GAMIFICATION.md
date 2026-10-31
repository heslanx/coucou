# Gamificação: pesquisa Duolingo e proposta para a Koru

[Índice](README.md) · Pesquisa em 2026-10-30 · Intenção de gamificar aceita; regras e implementação ainda propostas.

## 1. Objetivo e limite da pesquisa

Criar continuidade, domínio do trabalho e colaboração que melhorem a operação. Estudar o sistema do Duolingo antes de implementar: entrada, compromisso, ação significativa, feedback, ofensiva, metas, recompensa, socialização, lembretes, recuperação e experimentação.

O [desenho de hábito por público](ADOPTION.md#3-hábito-associado-ao-trabalho-real) liga dúvida contextual, ação mínima, retorno útil e preparação da próxima ocasião. A variabilidade vem do trabalho real; regras, custos e confirmação permanecem previsíveis. Esse desenho complementa a pesquisa Duolingo e ainda precisa de validação própria.

Foi consultado um corpus público oficial inicial, com artigos de produto/engenharia, central de ajuda e publicações de pesquisa. Isso não é “todas as pesquisas” nem uma reconstrução do algoritmo proprietário completo. Detalhes variam com data, idioma, plataforma, plano e experimento. Artigos antigos são evidência histórica; não devem virar automaticamente regras atuais de produto.

Os IDs D01–D19 abaixo ligam para fontes oficiais. A adaptação à Koru é uma proposta nossa, não uma recomendação do Duolingo para ambientes de trabalho.

## 2. Mapa de mecanismos e evidências

| ID / fonte | Achado público | Adaptação proposta à Koru | Limite |
|---|---|---|---|
| D01 [Definição de streak](https://www.duolingo.com/help/what-is-a-streak) | Continuidade de dias com atividade; proteção e reparo aparecem na ajuda | Continuidade de participação válida em turnos elegíveis | Dia de trabalho não equivale a dia de estudo |
| D02 [Separação entre meta e streak](https://blog.duolingo.com/improving-the-streak/) | Duolingo experimentou separar continuidade de uma meta diária maior | Separar hábito pessoal de conclusão/conformidade de toda a operação | Não tornar um único clique prova de trabalho completo |
| D03 [Hábito e flexibilidade](https://blog.duolingo.com/how-duolingo-streak-builds-habit/) | Repetição contextual e proteção de continuidade fazem parte do desenho | Rotina associada ao começo/fim do turno, com folgas e ausências justificadas | Adaptação precisa ser validada com equipes |
| D04 [Proteção durante incidentes](https://blog.duolingo.com/protecting-streaks-from-site-issues/) | O serviço descreve reparação de streaks afetadas por indisponibilidade | Não punir a pessoa por falha da Koncluí; recalcular com trilha | Proteção de ofensiva não regulariza uma tarefa operacional |
| D05 [Friends Quests](https://blog.duolingo.com/friends-quests/) | Missões cooperativas e reconhecimento entre pares | Missão semanal de equipe com objetivo comum e contribuição atribuível | Regras de pareamento no artigo são históricas |
| D06 [Construção do Friend Streak](https://blog.duolingo.com/product-lessons-friend-streak/) | Continuidade compartilhada foi explorada como mecanismo de compromisso social | Cooperação voluntária, sem transferir culpa por ausência de colega | Relação de trabalho difere de amizade voluntária |
| D07 [Ligas e rankings](https://blog.duolingo.com/duolingo-leagues-leaderboards/) | Comparação e progressão competitiva recorrente | Avaliar depois; grupos equivalentes e opt-in, priorizando evolução própria | Volume bruto favorece funções/turnos com mais tarefas |
| D08 [Time Spent Learning Well](https://blog.duolingo.com/time-spent-learning-well/) | Métrica de qualidade corrige incentivos de simplesmente acumular sessões/XP | Medir qualidade operacional, não tempo gasto com a Koru | Eficiência operacional pode significar usar menos o aplicativo |
| D09 [Lembretes personalizados](https://blog.duolingo.com/hi-its-duo-the-ai-behind-the-meme/) | Mensagens predefinidas e experimentos apoiam personalização | Primeiro regras simples de contexto/horário; testar lembretes úteis | Não adotar culpa ou insistência como personalidade |
| D10 [Artigo KDD 2020](https://research.duolingo.com/papers/yancey.kdd20.pdf) | Pesquisa sobre otimização recorrente de notificações com bandits | Referência metodológica futura para aprender preferências sob limites | Não demonstra que esse algoritmo é necessário no MVP |
| D11 [Duolingo Method, 2023](https://duolingo-papers.s3.amazonaws.com/reports/Duolingo_whitepaper_duolingo_method_2023.pdf) | Visão de aprendizagem por prática, personalização e motivação | Microaprendizagem ligada ao procedimento e prática real | Aprendizagem de idioma não comprova resultado operacional |
| D12 [Marcos e Streak Society](https://blog.duolingo.com/streak-celebration-parties/) | Celebração de continuidade e marcos | Reconhecimento discreto por constância e evolução verificada | Números e recompensas da Koru ainda não definidos |
| D13 [Energy e Hearts](https://blog.duolingo.com/duolingo-energy/) | O artigo discute a substituição de penalidade por erro em parte da base | Não bloquear orientação ou registro porque a pessoa errou | Não confundir energia de jogo com créditos de IA |
| D14 [Destaques de 2025](https://blog.duolingo.com/product-highlights/) | Registra mudanças em pareamento, recompensas e celebrações | Manter regras versionadas e revalidar documentação histórica | Retrato de um período, não especificação completa atual |
| D15 [Recursos sociais](https://blog.duolingo.com/friends-social-features/) | Feed de conquistas, colaboração e continuidade social | Reconhecimento voluntário dentro do escopo da equipe | Dados de funcionários não viram feed público por padrão |
| D16 [Opções para introvertidos](https://blog.duolingo.com/introvert-language-learning-tips/) | Documenta saída de funcionalidades sociais | Preferências para ocultar ranking, celebrações e sons | Desabilitar jogo não remove obrigações do processo |
| D17 [Resultados de estudos de eficácia](https://blog.duolingo.com/results-duolingo-efficacy-studies/) | Síntese de avaliações de aprendizagem, comparações e relatos de confiança | Avaliar habilidade operacional e transferência para a rotina, além de retenção | Resultados educacionais não comprovam efeito da gamificação isoladamente |
| D18 [Duolingo Research](https://research.duolingo.com/) | Catálogo de publicações, dados e ferramentas de pesquisa | Organizar revisão por eficácia, personalização, repetição, notificações e avaliação | Índice consultado não equivale a todos os estudos lidos ou catálogo histórico completo |
| D19 [Dataset development](https://blog.duolingo.com/dataset-development/) | Engenharia de datasets: convenções, comparação de versões, publicação e atualização | Tratar indicadores, ofensivas e consumo como dados com contratos verificáveis | Artigo de engenharia, não estudo de eficácia de gamificação |

### Como interpretar os resultados

D02 relata aumento de **3,3% na retenção do dia 14** no experimento descrito; a publicação não fornece aqui os dados brutos para reanálise. D03 relata **+0,38% relativo em usuários ativos diários** ao ampliar a proteção descrita. São resultados do Duolingo em contextos específicos, não previsão de efeito na Koncluí.

D06 relata associação entre Friend Streak e conclusão diária; não tratar essa associação isolada como causalidade. Métricas divulgadas em blog não substituem análise do desenho experimental, população e período. Não prometer ganho de lucro com base em retenção num app de idiomas.

## 3. Ciclo completo proposto

1. **Entrada:** pessoa identifica função e rotina; entende o que conta e escolhe preferências.
2. **Compromisso:** uma meta pequena e significativa, compatível com sua escala e autoridade.
3. **Ação:** execução ou aprendizagem válida confirmada pelo sistema dono.
4. **Feedback:** resultado e próxima ação; explicar o motivo de não contar quando aplicável.
5. **Continuidade:** atualizar ofensiva uma vez por período elegível, com calendário compreensível.
6. **Progressão:** reconhecer competência e qualidade, sem recompensar tarefas artificiais.
7. **Cooperação:** missão de equipe com objetivos claros, contribuições justas e adesão à camada social.
8. **Lembrete:** oportunidade útil antes do prazo, respeitando horário, silêncio e saturação.
9. **Recuperação:** recomeço acolhedor, proteção por folga/incidente e revisão de registros contestados.
10. **Aprendizagem do produto:** medir comportamento e resultado operacional, corrigindo incentivos ruins.

## 4. Duas medidas que não podem se misturar

**Ofensiva de participação:** sequência de períodos de trabalho elegíveis com uma contribuição válida, definida e verificável. Pode reconhecer aprender ou reportar corretamente um desvio; não exige fingir que não houve problema.

**Qualidade/conformidade operacional:** situação real dos processos, itens obrigatórios, evidências, prazos e ocorrências. Não muda porque alguém ganhou pontos, protegeu uma ofensiva ou comprou créditos.

Exemplo: uma pessoa identifica corretamente uma falha, registra a evidência e aciona o responsável. Essa participação pode contar para o hábito. A falha continua aberta até resolução comprovada.

Não usar “dias sem acidentes”, “nenhuma ocorrência registrada” ou “tudo verde” como incentivo isolado: isso pode desencorajar a comunicação dos problemas que a Koncluí precisa tornar visíveis.

## 5. Regras propostas de ofensiva

- Contar **dias/turnos elegíveis**, não exigir uso em todos os dias do calendário.
- Fonte do calendário: escala/rotina do workspace, timezone da unidade e regra de fechamento de turno. Não usar apenas o relógio do celular.
- Folga, férias, afastamento e unidade fechada não quebram nem incrementam a sequência por si sós.
- Definir uma ação elegível por função e processo; abrir o app, enviar mensagens e gastar créditos não contam.
- Exigir resultado confirmado; rascunho, retry e envio duplicado não pontuam novamente.
- Offline aparece como provisório; reconciliar horário da execução, evidência e chegada do evento. Janela de tolerância e revisão precisam de decisão.
- Incidente do serviço pode proteger a continuidade, com justificativa auditável; não registrar trabalho inexistente.
- Mudança de escala, fuso, vínculo ou função tem política de transição; não recalcular de forma punitiva sem explicação.
- Perder uma sequência não apaga aprendizado, conquistas históricas ou trabalho realizado.
- Alteração fraudulenta/inválida pode exigir recomputação, com motivo e revisão; não manter prêmio por resultado anulado.
- Marcos, quantidade de proteções e janela de recuperação ainda não têm valores aprovados.

### Modelo conceitual de eventos

Não é schema de banco aprovado. É uma lista do que uma implementação precisará representar:

`event_id`, `workspace_id`, `actor_user_id`, `source_record_id`, `event_type`, `occurred_at`, `received_at`, `eligible_period_id`, `rule_version`, `verification_status`, `reversal_of`.

Um evento de negócio gera uma contribuição elegível no máximo uma vez. A projeção de sequência e recompensas precisa ser reconstruível; revisões preservam motivo e autoria. O modelo não concede pontos por conta própria: o motor determinístico avalia eventos autorizados.

## 6. Metas, recompensas e colaboração

| Persona | Proposta de hábito/objetivo | Evitar |
|---|---|---|
| Operador | Registrar corretamente, aprender procedimento e pedir ajuda quando necessário | Pressa, fotos repetidas, omissão de falhas e comparação injusta |
| Gestor | Revisar exceções, concluir ações corretivas verificadas e melhorar processos | “Fechar” problema sem resolver ou pressionar para tudo ficar verde |
| Dono | Revisão semanal, decisões delegadas e melhoria de um gargalo | Pontuar faturamento sem contexto ou exigir presença diária no app |
| Equipe interna | Rotina de indicadores, qualidade dos registros e melhoria da área | Exposição de métricas fora do acesso, competição entre funções diferentes |

Priorizar progresso pessoal, marcos e missões cooperativas. Badges, personalização da Koru e reconhecimento são propostas de recompensa. Não definir remuneração, avaliação disciplinar ou promoção por um score de IA.

Rankings públicos, ligas, boosts e moeda própria ficam fora do primeiro piloto. Estudar valor e efeitos antes de adotá-los. Não vender reparo de ofensiva nem misturar acesso ao trabalho com mecânica de energia. Créditos de IA pagam uso de IA; pontos não compram autorização nem conformidade.

## 7. Plano de pesquisa antes da implementação

| Etapa | Entregável | Condição para concluir |
|---|---|---|
| Inventário oficial | Lista de artigos, ajuda, papers e referências com data, versão e mecanismo | Cobertura de todas as categorias da seção 2; lacunas explícitas |
| Leitura crítica | Fichas de método, amostra disponível, métrica, resultado e limitações | Separar experimento, associação, explicação de produto e hipótese |
| Experiência atual | Mapa de estados de entrada, ganho, perda, proteção, recuperação, social e opt-out | Observação permitida por plataforma/plano; divergências documentadas |
| Adaptação ao trabalho | Entrevistas e protótipos com donos, gestores, operadores e equipe interna | Validar escala, justiça, utilidade e situações de falha |
| Contrato de regras | Calendário, eventos elegíveis, replay, correção, privacidade e preferências | Tabela de casos aprovada por produto e operação |
| Experimento piloto | Protocolo, população, baseline, métricas e critérios de interrupção | Não liberar para todos apenas por aumentar acessos |

**Pendente nesta documentação:** inventário exaustivo, revisão integral de todos os papers e suas referências, observação autenticada do app atual, entrevistas, experimentos e desenho estatístico. As duas publicações de pesquisa foram localizadas e consultadas como referência inicial, não reproduzidas experimentalmente.

## 8. Validação e decisão de expansão

Comparar qualidade e continuidade com baseline e grupo de comparação quando viável, controlando sazonalidade, função, volume e escala. Selecionar janela e amostra antes da análise.

Métricas principais: execução válida no prazo, qualidade de evidência, resolução de recorrências, aprendizagem e retorno voluntário no próximo período elegível. Guardrails: registros artificiais, redução suspeita de relatos, trabalho fora da escala, contestação, distração e custo.

Não usar DAU, minutos de conversa ou créditos consumidos como principal evidência de benefício. Interromper ou ajustar o piloto se o incentivo melhorar a pontuação e piorar a qualidade ou a transparência.

Casos de teste futuros: turno atravessando meia-noite; folga entre turnos; mudança de timezone; evento offline tardio; duplicata; reversão; dois dispositivos; perda de acesso; indisponibilidade; pessoa sem tarefas elegíveis; mudança de regra; missão coletiva com afastamento; aviso desativado. Esta tarefa não implementa nem cria testes de produto para esses casos.


## 9. Referências indicadas pelo usuário: consequências para o plano

As quatro URLs enviadas foram abertas e incorporadas: hábito em D03, eficácia em D17, catálogo de pesquisa em D18 e engenharia de datasets em D19.

### Eficácia, hábito e resultado de negócio são eixos diferentes

A síntese de eficácia [D17](https://blog.duolingo.com/results-duolingo-efficacy-studies/) reúne resultados de habilidades, comparações de aprendizagem e percepção dos participantes. Isso exige ler os estudos de origem antes de adotar conclusões: habilidade medida, confiança declarada e comportamento fora do aplicativo não são a mesma variável. Nenhum desses resultados prova que uma ofensiva causará aumento de lucro na Koncluí.

Proposta de avaliação própria, ainda não executada:

| Eixo | Pergunta | Evidência a obter |
|---|---|---|
| Hábito | A pessoa retorna no próximo turno elegível? | Continuidade ajustada à escala e participação válida |
| Aprendizagem | Entendeu como executar o procedimento? | Avaliação de cenários com rubrica, antes/depois, revisada por especialista do processo |
| Transferência | Executa melhor na situação real? | Observação e evidências do trabalho, não apenas resposta correta no app |
| Operação | Diminuiu recorrência, desperdício ou retrabalho? | Indicadores com baseline, período e comparação adequados |
| Sustentação | O efeito permanece sem incentivo crescente? | Acompanhamento após o período inicial e análise de dependência de lembretes |

Esses critérios são propostas Koncluí. A pesquisa de eficácia de idiomas informa a disciplina de avaliação, não os valores-alvo nem a rubrica operacional.

### Usar o catálogo de pesquisa como fila de leitura

O [portal D18](https://research.duolingo.com/) oferece publicações e dados de notificações, avaliação, aprendizagem e repetição espaçada. Criar fichas por estudo, identificar versões e evitar somar duas publicações do mesmo experimento como evidências independentes. A prioridade é aprofundar notificações e avaliação, depois repetição espaçada para treinamento de procedimentos. Licença, finalidade e adequação devem ser conferidas antes de baixar ou reutilizar dados. Nenhum dataset foi importado ou modelo treinado nesta tarefa.

### Qualidade dos dados antes de personalização

A referência de [engenharia D19](https://blog.duolingo.com/dataset-development/) sustenta investigar contratos, comparação entre versões e visibilidade de falhas/atrasos. Para a Koru, propomos testar primeiro eventos, calendário e atribuição. Um dado atrasado não deve quebrar a ofensiva, gerar alerta falso ou distorcer um indicador. Essa aplicação ao produto é nossa proposta, detalhada em [arquitetura](ARCHITECTURE.md#7-qualidade-dos-dados-e-evolução-de-indicadores).
