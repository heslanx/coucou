# Mensagem, hábito e indicação

[Índice](README.md) · 2026-10-30 · Proposta revisada, ainda sem validação com usuários.

Este documento aplica Made to Stick, Hooked e Contagious à visão da Koru. As notas são julgamento editorial sobre a especificação, não métricas de uso, eficácia ou probabilidade de crescimento. A revisão final usa o método de pontos cegos do PostHog sobre os achados anteriores; não houve PR, revisores paralelos ou consulta a dados do PostHog.

## 1. Mensagem que queremos tornar lembrável

**Koru, seu gerente operacional no bolso. Saiba o que precisa de atenção e acompanhe o próximo passo.**

Explicação curta proposta: “Converse com a Koru para entender as pendências, consultar como fazer e acompanhar a solução com sua equipe.” Conectores, modelos e MCP são meios para entregar isso, explicados quando a pessoa conecta uma fonte ou precisa entender uma limitação.

| Público | Mensagem proposta | Primeira demonstração |
|---|---|---|
| Dono | “Veja o que ainda precisa de você e o que sua equipe já resolveu.” | Abrir uma decisão pendente, sua fonte e o responsável atual |
| Gestor | “Comece o turno sabendo onde agir.” | Ver uma pendência e preparar o próximo passo para revisão |
| Operador | “Veja como fazer e peça ajuda quando precisar.” | Consultar um procedimento aprovado e voltar à tarefa |
| Colaborador interno | “Entenda sua meta e o que você pode fazer agora.” | Consultar um indicador próprio com definição e período |
| Líder ou direção interna | “Veja o que mudou na sua área e quais decisões estão pendentes.” | Comparar períodos equivalentes no recorte autorizado |

Gancho de demonstração: “Qual pendência de ontem ainda depende de você?” Responder logo com um registro verificável; sem suspense artificial ou alerta de risco inventado. Sem pendência relevante, dizer isso e encerrar.

### História de demonstração, fictícia

Na passagem de turno, uma gestora encontra uma ocorrência ainda aberta. Ela pergunta à Koru o que aconteceu. A Koru mostra o registro, o responsável e o procedimento aprovado. A gestora revisa a próxima ação; o operador registra a evidência necessária. Quando a resolução é confirmada no sistema, a Koru a inclui no resumo. O dono consegue consultar o resultado sem pedir que todos contem a história novamente.

Essa história demonstra uma jornada desejada; não é depoimento, caso real ou prova de economia. Em uma demonstração, dados simulados permanecem identificados como demonstração, inclusive em áudio e artefatos exportados. A Koru participa de passos concretos, mas a atuação humana continua visível.

### Diagnóstico SUCCESs

Base: PRODUCT.md antes desta revisão. Cada dimensão vai de 1 a 10; a coluna proposta avalia o texto acima, não uma melhoria medida.

| Dimensão | Base | Proposta | Correção / evidência faltante |
|---|---|---|---|
| Simples | 8 | 9 | Uma promessa principal e uma primeira demonstração por público |
| Inesperada | 4 | 6 | Abrir com uma pendência reconhecível; testar se gera curiosidade relevante |
| Concreta | 8 | 9 | Mostrar registro, responsável, revisão e evidência |
| Crível | 7 | 7 | Fontes sustentam a resposta; benefício comercial ainda depende de piloto |
| Emocional | 6 | 8 | Relacionar clareza e autonomia a situações pessoais, sem culpa |
| Histórias | 5 | 8 | Jornada curta recontável; substituir por caso real somente com evidência e autorização |
| **Total** | **38/60** | **47/60** | **8/10 → 8/10**, ambos na faixa 35–49 |

Os pontos mais fracos eram surpresa útil e narrativa. A revisão os desenvolve, mas não sustenta 10/10: faltam teste de compreensão, lembrança e credibilidade com cada público. Não elevar a nota por inventar números, clientes ou garantias.

## 2. Primeiro valor antes de pedir configuração extensa

1. Identificar pessoa, workspace e acesso. Quando houver mais de um workspace, tornar a escolha explícita.
2. Apresentar uma tarefa compatível com o papel: ver pendências, consultar procedimento ou entender um indicador. Pedir somente o contexto ausente necessário.
3. Entregar resposta curta, fonte, atualização e próximo passo. A primeira recompensa é conseguir entender ou avançar no trabalho.
4. Depois desse valor, oferecer um investimento pequeno: salvar a rotina, escolher o próximo acompanhamento ou corrigir um contexto pessoal.
5. Perguntar se deseja lembrete, mostrando frequência e canal. A configuração inicial não autoriza alertas ilimitados ou ações recorrentes.

Sem fonte conectada, oferecer exemplo claramente simulado ou orientação para a pessoa habilitada conectar a fonte. Um operador não precisa conectar sistemas empresariais para conhecer a proposta. Demo não conta como tarefa real concluída. Custo e condições de consumo ficam visíveis antes da ação cobrada, conforme [créditos](CREDITS.md).

## 3. Hábito associado ao trabalho real

| Público | Gatilho interno a validar | Ação mínima | Retorno útil variável | Investimento que prepara a próxima ocasião |
|---|---|---|---|---|
| Dono | Dúvida sobre o que depende dele | Abrir resumo das decisões | Exceções e decisões reais mudam com a operação | Salvar critérios pessoais de acompanhamento e cadência de revisão |
| Gestor | Incerteza ao assumir o turno | Ver a próxima pendência | Descobrir o contexto e progresso daquela pendência | Registrar próximo passo autorizado e prazo para retomada |
| Operador | Dúvida sobre como executar | Abrir o procedimento da tarefa | Aprender a orientação relevante para a situação | Salvar ponto de retomada ou dúvida para acompanhamento |
| Equipe interna | Dúvida sobre evolução da meta | Consultar indicador autorizado | Entender mudanças reais no período | Salvar recorte pessoal e próxima revisão |

O próximo gatilho pode ser a própria passagem de turno ou uma revisão semanal. Um lembrete externo é opcional. O dono não precisa entrar diariamente para receber valor. A variabilidade vem do contexto real, aprendizagem e progresso; confirmação de salvamento, critérios de pontos, permissões e custos continuam previsíveis. Não introduzir sorteios, suspense sobre falhas ou recompensa intermitente por tarefa obrigatória.

Salvar preferências pessoais não publica procedimento nem altera a rotina da equipe. Investimento coletivo exige o fluxo de aprovação do processo. Exportar trabalho e sair da gamificação não apaga contribuições nem bloqueia o trabalho. Usar menos a Koru, mantendo resultado e qualidade, pode ser sinal de sucesso.

### Diagnóstico Hooked

| Critério (0 ausente, 1 parcial, 2 completo no desenho) | Base | Proposta | Limite |
|---|---|---|---|
| Gatilho interno identificado | 1 | 1 | Hipóteses por público; faltam entrevistas |
| Ação simples | 1 | 2 | Primeiro passo explícito; usabilidade ainda precisa de teste |
| Recompensa variável útil | 1 | 1 | Contexto variável especificado; relevância ainda não observada |
| Investimento prepara próximo gatilho | 1 | 2 | Preferência/retomada ligadas à próxima ocasião |
| **Total** | **4/8** | **6/8** | **round(total / 8 × 10): 5/10 → 8/10** |

Bloqueios para 10/10: validar gatilhos e retorno útil em uso real. O enquadramento desejado na matriz ética é facilitador, mas não há evidência nesta revisão de benefício comprovado nem de uso recorrente pela equipe criadora. A nota é condicional: se o piloto mostrar extração de atenção, prejuízo ou dependência de arrependimento, limitar a avaliação a 3/10 e interromper a mecânica. Não adotar “30 dias” ou “5%” como prova universal de hábito.

Ofensivas, folgas, incidentes e contribuição válida seguem [gamificação](GAMIFICATION.md). Retorno por obrigação do emprego não demonstra hábito voluntário. Participação social e gamificação devem poder ser recusadas sem efeito disciplinar.

## 4. Indicação por algo que ajuda outra pessoa

Primeiro artefato proposto: **um modelo de passagem de turno preparado com a Koru**, revisado por quem conhece o processo. Contém objetivo, passos, evidências esperadas, exceções e espaço para responsáveis. O padrão para compartilhamento externo é um modelo genérico sem registros do negócio; não a conversa completa nem um relatório privado.

Quem recebe deve conseguir entender para que serve e adaptar o modelo sem criar conta apenas para lê-lo. A atribuição “Preparado com a Koru — Koncluí” pode acompanhar o artefato com controle do autor; não é condição para exportar. O modelo não carrega marca de aprovação operacional da Koncluí e precisa de revisão antes de virar procedimento local.

Gatilho de conversa: um gestor pede ajuda para organizar a troca de turno. O colega pode apresentar o modelo e contar como o preparou com a Koru. A hipótese de indicação combina utilidade, orgulho pelo trabalho bem organizado e uma história concreta. Validar se o destinatário lembra da Koru ao recontar a história; um logotipo isolado não passa esse teste.

Compartilhar e convidar são ações diferentes. Ver um modelo não concede acesso ao workspace. O autor escolhe público, revisa a prévia e confirma o envio/publicação. Não enviar mensagens automaticamente, importar contatos, exigir indicação para liberar trabalho ou recompensar exposição de dados. Leitura autorizada não implica permissão de publicação.

### Diagnóstico STEPPS

| Dimensão (0–2) | Base | Proposta | Próxima evidência |
|---|---|---|---|
| Moeda social | 1 | 2 | Colega se sente útil ao compartilhar trabalho revisado |
| Gatilhos | 2 | 2 | Passagem de turno/revisão recorrente evoca a solução |
| Emoção | 1 | 1 | Testar orgulho e descoberta sem forçar euforia ou ansiedade |
| Público/visível | 0 | 1 | Compartilhamento deliberado existe no desenho; adoção não observada |
| Valor prático | 2 | 2 | Destinatário consegue adaptar o modelo |
| Histórias | 1 | 1 | Testar reconto espontâneo com identificação da Koru |
| **Total** | **7/12** | **9/12** | **7/10 → 8/10** pelas faixas 6–8 e 9–10 |

Para chegar a 10/10 faltam visibilidade voluntária comprovada, emoção relevante e história que preserve a marca ao ser recontada. Três dimensões fortes não bastam para afirmar propagação. Não comprometer privacidade ou a personalidade calma para aumentar a nota.

## 5. Validação proposta

| Pergunta | Observação no piloto | Critério de interpretação |
|---|---|---|
| A promessa é compreendida? | Pedir que cada público explique a Koru com suas palavras e escolha uma tarefa | Reconhece utilidade e limites, sem supor autoridade ou resultados garantidos |
| A primeira tarefa entrega valor? | Observar tentativa, fonte consultada, correções e resultado confirmado | Medir tempo até resultado útil; separar demo, falha, bloqueio e sucesso |
| A pessoa volta porque precisa? | Entrevista contextual e retorno em ocasião elegível, distinguindo lembrete e cobrança da chefia | Retorno acompanhado de tarefa válida; ausência pode significar trabalho já resolvido |
| O investimento ajuda depois? | Retomar a rotina salva e conferir se reduz contexto repetido | Não confundir quantidade de preferências com benefício |
| O artefato merece indicação? | Destinatário tenta adaptar e depois reconta sua origem | Uso compreensível, compartilhamento voluntário e Koru lembrada sem indução |
| Há efeitos indesejados? | Registrar interrupções, pressão, custo, exposição e trabalho fora de escala | Pausar mecânica quando houver dano; investigar antes de expandir |

Definir população, período, baseline e limiares antes do piloto, com representação dos públicos. Não há metas numéricas aprovadas. Relatos e observação controlada bastam para começar; esta revisão não adiciona telemetria nem autoriza session replay ou captura de conversas. Resultados agregados não devem identificar equipes pequenas por inferência. Ver [entrega e validação](DELIVERY.md).

## 6. Revisão final de pontos cegos

Achados já cobertos pelas três lentes: mensagem abstrata, primeira tarefa pouco delimitada, investimento sem próximo gatilho claro, falta de artefato de indicação e evidência de hábito/propagação ausente. A varredura abaixo não os repete. São dois problemas adicionais encontrados na proposta, com correções incorporadas como requisitos; não são bugs de código corrigidos.

### BS-01 — Revogação depois de compartilhar

**Gatilho:** publicar um modelo derivado de dados internos e depois revogar o acesso do destinatário ou apagar a origem. **Consequência:** link, cache ou arquivo exportado pode continuar expondo informações, apesar do controle do workspace. A proposta de compartilhamento da seção 4 precisa distinguir acesso gerenciado de cópia entregue.

**Requisito:** modelos externos genéricos não incluem nomes, IDs, fotos, links internos, metadados ou valores confidenciais. Revisão humana da prévia é obrigatória; anonimização automática não garante ausência de segredos. Links privados exigem identidade, destinatários permitidos, expiração e revalidação a cada acesso. Revogar invalida acesso gerenciado e caches sob controle do serviço. Download, captura de tela e encaminhamento de uma cópia não podem ser recolhidos: informar essa consequência antes de exportar. Exportação depende de permissão específica e registra autoria/versão/público, sem prometer revogação de cópias.

**Aceite futuro:** destinatário revogado não abre link privado; exportação sem concessão é negada; demo mantém rótulo; prévia não carrega anexos/metadados ocultos. Falha bloqueia compartilhamento, não a consulta operacional autorizada.

### BS-02 — Confirmação válida sobre estado que mudou

**Gatilho:** gestor prepara atribuição de pendência; outro gestor a resolve ou muda seu responsável antes da confirmação. **Consequência:** executar os campos previamente confirmados pode sobrescrever trabalho recente. Idempotência evita duplicatas, mas não resolve conflito de versão.

**Requisito:** escritas dependentes do estado carregam versão/precondição da origem, revalidada no sistema responsável de forma atômica com a alteração. Se o conector não oferece garantia equivalente, restringir a ação a rascunho/encaminhamento até definir alternativa segura. Em conflito, mostrar estado atual, invalidar confirmação anterior e solicitar nova revisão; nunca reaplicar silenciosamente a intenção antiga. Esse requisito complementa [execução e recuperação](ARCHITECTURE.md#5-execução-confirmação-e-recuperação).

**Aceite futuro:** duas sessões alterando a mesma pendência não sobrescrevem mudança recente; confirmação antiga expirada é recusada; nova confirmação identifica a revisão apresentada.

Após incorporar esses requisitos, não foram identificados outros achados concretos nesta varredura documental. Isso não equivale a auditoria de implementação, segurança ou produção.
