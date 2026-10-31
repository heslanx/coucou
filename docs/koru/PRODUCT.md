# Produto, públicos e jornadas

[Índice](README.md) · 2026-10-30 · Direção de produto aceita; funcionalidades abaixo são requisitos e propostas, não inventário do que está pronto.

## 1. Promessa e resultado

**Um gerente operacional no bolso:** a Koru transforma contexto disperso em entendimento, prioridades, processos claros e ações acompanhadas. Ela apoia a responsabilidade das pessoas, sem assumir autoridade para decidir tudo sozinha.

A experiência deve permitir conversar, investigar, organizar, criar e agir. Não deve se limitar a perguntas previamente decoradas ou a um painel de indicadores narrado. A inteligência geral precisa ser ancorada nos dados, procedimentos e permissões do negócio.

Mensagem curta proposta: **“Koru, seu gerente operacional no bolso. Saiba o que precisa de atenção e acompanhe o próximo passo.”** A [proposta de adoção](ADOPTION.md) detalha mensagens por público, primeira tarefa útil, história de demonstração e indicação voluntária por modelos de processo revisados.

O ciclo de valor é:

1. **Mapear:** entender o trabalho real por conversa, documentos e dados; registrar responsáveis, entradas, saídas, exceções e sistemas envolvidos.
2. **Consolidar:** propor procedimentos, checklists, rotinas, responsabilidades e indicadores; revisar com quem executa e aprovar com quem responde pelo processo.
3. **Executar:** orientar a próxima ação, registrar informações e facilitar a continuidade entre pessoas e turnos.
4. **Observar:** acompanhar resultados, desvios, recorrência, custo e qualidade, mostrando fonte e atualização.
5. **Otimizar:** levantar hipóteses, propor mudanças pequenas, medir antes/depois e versionar o processo aprovado.
6. **Sustentar:** treinar a equipe, lembrar no momento certo e reconhecer evolução com gamificação coerente.

## 2. Públicos externos

### Dono do negócio

Precisa saber se o negócio está saudável sem estar presente em cada detalhe. A Koru deve ajudar a reduzir dependência do dono e dar visibilidade sobre o que exige decisão dele.

| Necessidade | Pedido ilustrativo | Entrega desejada |
|---|---|---|
| Visão executiva | “O que eu preciso saber hoje?” | Resumo de operação, riscos, decisões pendentes e evolução dos objetivos |
| Lucro e custos | “Onde estamos perdendo dinheiro?” | Cruzamento autorizado de desperdícios, retrabalho e dados financeiros; separar custo medido de estimativa |
| Gestão de unidades | “Qual unidade precisa da minha ajuda?” | Comparação com períodos e definições equivalentes; aprofundamento por exceção |
| Delegação | “O que ainda depende de mim?” | Decisões sem responsável, gargalos de aprovação e oportunidades de delegar |
| Crescimento | “Estamos prontos para abrir outra unidade?” | Avaliação baseada em critérios definidos, lacunas e plano; não um parecer conclusivo inventado |
| Processos | “Me ajude a organizar a operação.” | Entrevista orientada, mapa do processo e propostas de rotinas para revisão |
| Liberdade | “Como ficou a operação enquanto estive fora?” | Histórico de resultados, problemas resolvidos e assuntos ainda pendentes |

Receita, margem, caixa, estoque e vendas dependem das fontes conectadas. O dado de checklist não permite inferir faturamento ou lucro por si só. Não duplicar ou misturar conceitos financeiros de sistemas diferentes.

### Gestor

Precisa transformar o plano em uma operação consistente. Quer saber onde agir, orientar a equipe e resolver problemas antes que se repitam.

- Resumo de abertura, fechamento e passagem de turno.
- Pendências e desvios por setor, unidade, responsável e prazo.
- Acompanhamento de ocorrências e ações corretivas, com evidências e status real.
- Consulta e proposta de atualização de procedimentos, com aprovação e versionamento.
- Preparação de reuniões curtas e revisão semanal com fatos, causas possíveis e próximos passos.
- Sugestão de distribuição de trabalho conforme função, disponibilidade e autorização; sem alterar escala automaticamente.
- Identificação de recorrência e comparação entre períodos; correlação apresentada como hipótese, não causa comprovada.
- Acompanhamento de treinamento e evolução do processo, sem rankings constrangedores de pessoas.

Exemplo: “Faltam dois itens para concluir a abertura. A verificação da câmara está pendente. Quer ver o item?” A Koru não transforma “sem registro” em “não realizado” ou “fora do padrão”.

### Operador

Precisa executar corretamente com pouco atrito, inclusive com as mãos ocupadas.

- Saber o que fazer agora e o que falta no seu setor.
- Consultar procedimento aprovado e ver imagem ou vídeo de referência quando existir.
- Executar checklist guiado: repetir, voltar, pausar, corrigir e retomar.
- Ditar observações e medições; confirmar equipamento, valor e unidade quando houver ambiguidade.
- Relatar ocorrência e pedir ajuda no fluxo configurado.
- Usar temporizador contextual sem confundir término do tempo com tarefa concluída.
- Continuar no celular quando forem necessárias foto, assinatura ou outra evidência.
- Receber orientação de aprendizagem e reconhecimento por trabalho válido, inclusive por reportar um problema real.

Exemplo: “Registre quatro graus na geladeira dois.” A Koru identifica o item, confirma o entendimento necessário, grava pelo sistema autorizado e só então confirma o salvamento. Foto obrigatória continua obrigatória.

## 3. Equipe interna Koncluí

A mesma Koru atende a operação interna em contexto separado. O vínculo de funcionário e a função atual governam o alcance; não basta pertencer à empresa.

| Público | Exemplos de uso | Limite |
|---|---|---|
| Colaborador | “Como estou em relação à minha meta?”; “O que tenho pendente?” | Indicadores próprios e informações compartilhadas com sua função |
| Líder de área | “Como está nossa área?”; “O que explica a mudança desta semana?” | Área e equipe autorizadas; detalhes pessoais apenas quando concedidos |
| Direção | “Como a empresa está evoluindo?”; “Quais decisões estão pendentes?” | Indicadores empresariais autorizados, com definições consistentes |
| Comercial | Funil, conversão, velocidade de atendimento e objetivos | Somente fontes e equipes permitidas |
| CS e operações | Onboarding, adoção, solicitações, riscos e pendências | Carteira, área e dados concedidos |
| Marketing, produto e financeiro | Indicadores específicos e investigações de sua área | Não inferir acesso financeiro ou pessoal pelo título do cargo |

O MCP atual do admin é o ponto de partida para leitura. Não atribuir a ele ferramentas de escrita ou segregação por funcionário que ainda não foram comprovadas. Ver [arquitetura](ARCHITECTURE.md).

## 4. Jornadas que conectam os públicos

### Mapear um processo

O dono descreve como funciona a abertura. A Koru pergunta sobre responsáveis, sequência, evidência, prazo e exceções; consulta procedimentos autorizados; produz um rascunho. Gestor e operadores revisam. A pessoa habilitada publica uma versão. A Koru acompanha a execução daquela versão e sugere melhorias baseadas em resultados.

### Resolver um desvio

Um operador registra uma ocorrência. A Koru confirma o registro e apresenta a orientação aprovada disponível. O gestor recebe o alerta pelo canal permitido, atribui ou confirma um responsável e acompanha a resolução. A conclusão exige a evidência definida. Na revisão semanal, a Koru aponta recorrência e propõe alteração do processo. Cada ação tem autoria e estado rastreável.

### Consultar a empresa por MCP

Um colaborador pergunta sobre sua meta; um líder faz a mesma pergunta sobre a área. A Koru obtém dados distintos conforme o acesso efetivo. Não entrega ao modelo dados de toda a empresa para depois pedir que ele omita o que não pode mostrar.

### Conversar e continuar em outro dispositivo

O dono começa pelo celular, pede um diagnóstico e abre no desktop os gráficos e propostas. A conversa continua no mesmo workspace com as mesmas fontes e permissões. No aparelho compartilhado, a sessão pessoal termina sem deixar o histórico na tela.

## 5. Experiência e personalidade

O [contrato proposto de usabilidade e microcopy](UX-AND-MICROCOPY.md) detalha navegação, busca, mensagens e recuperação por estado e papel. Seus textos são candidatos para protótipo, condicionados às capacidades e permissões reais.

A Koru é calma, atenta, precisa, acolhedora e discreta, conforme o playbook da personagem [L2](SOURCES.md#l2-personagem-koru). A equipe e o negócio são protagonistas.

- Voz para respostas curtas; tela para fonte, gráfico, evidência, revisão e ação.
- Resposta inicial objetiva, com opção de aprofundar e abrir o registro original.
- Estados claros: ouvindo, consultando, preparando, aguardando confirmação, executando, concluído, falhou e resultado desconhecido.
- Não afirmar “resolvido” quando apenas criou um chamado.
- Explicar dados ausentes, desatualizados, conflitantes ou parcialmente acessíveis.
- Não interromper o trabalho com animações; a personagem aparece nos momentos de interação e transição. Não inserir presença decorativa persistente no preenchimento do checklist.
- Sons opcionais e discretos. O som de coruja pode identificar a Koru. O som de venda só acompanha evento real de uma fonte conectada, ou demonstração explicitamente rotulada.
- Celebrações de processo e equipe fazem parte da proposta; exposição pública de falhas individuais não faz.
- Texto, toque e teclado permanecem alternativas completas à voz. Legendas/transcrição, contraste, foco e redução de movimento são requisitos.

## 6. Funcionalidades por horizonte

| Horizonte | Conteúdo |
|---|---|
| Primeiro valor | Contexto de workspace, resumo operacional, pendências, procedimentos, ocorrência assistida e piloto de checklist curto |
| Expansão | Mapeamento e consolidação de processos, MCPs externos selecionados, inteligência entre fontes e ações confirmadas |
| Voz e presença | Conversa em tempo real, continuidade entre dispositivos, notificações e estudos de ativação local |
| Hábitos | Gamificação validada, metas de qualidade, missões de equipe, aprendizagem e continuidade por turno |
| Administração avançada | Limites por usuário, histórico administrativo com visibilidade definida, orçamentos por função e automações recorrentes |

A ordem detalhada, equipe, prazos e pacote comercial ainda precisam de definição. Não vender “qualquer aplicativo”, “sempre ouvindo” ou “funciona offline” como capacidade universal.
