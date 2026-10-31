# Usabilidade e microcopy da Koru

[Índice](README.md) · 2026-10-30 · Especificação proposta; telas, áudio e comportamento ainda não homologados.

Revisão heurística das jornadas descritas em [produto](PRODUCT.md), [adoção](ADOPTION.md), [créditos](CREDITS.md) e [plataformas](PLATFORMS.md). A unidade de avaliação é a especificação, não o aplicativo Coucou nem uma interface Koru já entregue. Os textos abaixo são candidatos para protótipo. Não autorizam preços, canais, permissões ou recursos ainda pendentes.

## 1. Diagnóstico e prioridades

Nota inicial da especificação: **6/10**, calculada a partir de 10 menos as deduções abaixo. “Previsto” significa requisito documentado, não comportamento aprovado em teste. A ausência de tela impede atribuir nota de usabilidade ao produto funcionando.

| Diagnóstico rápido | Situação inicial | Dedução | Tratamento nesta revisão |
|---|---|---|---|
| Sei que produto/página estou usando? | Contexto de workspace previsto | 0 | Cabeçalho com produto, contexto e tarefa |
| A ação principal é evidente? | Primeira tarefa por público prevista em ADOPTION | 0 | Botão com verbo e objeto |
| A navegação é clara? | Seções e retorno ainda indefinidos; UX-01 | −1 | Mapa de navegação e preservação do contexto |
| Encontro a busca? | Busca operacional não especificada; UX-02 | −1 | Busca visível com escopo e estados próprios |
| Sei o que está acontecendo? | Estados de execução previstos | 0 | Texto condicionado ao estado confirmado |
| Os erros ajudam a recuperar? | Regras técnicas sem catálogo completo de saídas por papel; UX-03 | −2 | Erro, impacto e ação realmente disponível |
| Consigo voltar ou desfazer? | Cancelamento e limites de reversão previstos | 0 | Distinguir voltar, parar áudio e cancelar execução |
| Funciona sem hover? | Toque/teclado e acessibilidade previstos | 0 | Explicações persistentes junto à ação |
| Controles têm nome compreensível? | Texto e alternativas acessíveis previstos | 0 | Rótulos e nomes acessíveis consistentes |
| Preciso decifrar conceitos? | Linguagem operacional prevista | 0 | Vocabulário controlado e detalhes técnicos sob demanda |

| Achado | Severidade e contexto | Consequência | Correção proposta |
|---|---|---|---|
| UX-01 — Orientação entre conversa e registro | 2, menor; recorrente ao abrir uma pendência a partir do chat | Perder a conversa, os filtros ou o workspace de origem | Título e contexto visíveis; voltar restaura a origem |
| UX-02 — Dependência de saber perguntar | 2, menor; recorrente para iniciantes buscando procedimento | Tentar adivinhar comandos ou abandonar a consulta | Busca e entradas por tarefa, sem exigir um prompt |
| UX-03 — Recuperação sem saída adequada ao papel | 3, maior; condicional a falha/bloqueio, persiste até resolução | Operador tenta resolver conexão ou crédito que não administra; retry pode repetir escrita incerta | Saídas específicas por estado e permissão, preservando o trabalho |

Frequência e persistência são estimadas pelo fluxo, não observadas em usuários. Não foi identificado bloqueio catastrófico comprovado. A revisão especifica correções para os três achados; não declara aumento de nota antes da verificação. Para chegar a 10/10, demonstrar os dez critérios em protótipo funcional, inclusive erros, contexto, busca, teclado e voz, sem falhas relevantes nos percursos observados. Mesmo essa nota não substitui teste com usuários.

## 2. Orientação e navegação propostas

No mobile inicial, a Koru pode viver no app Flutter já existente da plataforma. As entradas abaixo são hipóteses para organizar a experiência Koru, não autorização para substituir a navegação atual. Inventariar rotas, contexto e padrões do app hospedeiro antes de desenhar a integração; ver [evolução mobile](../decisions/ADR-005-koru-mobile-evolution.md).

No aplicativo pessoal, usar **Início**, **Conversas**, **Tarefas** e **Procedimentos** como pontos de entrada candidatos. Recursos administrativos ficam em **Configurações**, conforme acesso. “Início” apresenta a próxima tarefa útil para a pessoa; não exige navegar por todas as áreas antes de agir. Indicadores podem ser abertos pelo resumo, busca ou conversa; uma seção própria depende da descoberta com cada público.

Cabeçalho de exemplo fictício: **Koru · Padaria Exemplo · Unidade Centro**. Título da página: **Pendências do turno**. Mostrar unidade apenas quando aplicável. Não substituir o nome do workspace por “Empresa” em todos os casos: uma empresa pode ter vários workspaces. Apresentar “Workspace — espaço de trabalho da equipe” na primeira escolha e usar o mesmo termo depois, sujeito a validação com clientes.

O seletor **Trocar workspace** mostra o destino antes de abrir seu conteúdo. Uma operação em andamento continua vinculada ao workspace original e permanece identificada. Na troca, não transportar rascunhos, contexto ou resultados para o novo workspace automaticamente.

Busca visível: **Buscar tarefas e procedimentos**. Campo com rótulo persistente; placeholder “Nome, assunto ou código” é apenas exemplo. Indicar o escopo selecionado e oferecer filtros autorizados. Não buscar globalmente todos os clientes. Resultados mostram título, tipo e contexto suficiente para distinguir itens; nunca exibem títulos ou contagens de registros proibidos.

Ao abrir um registro pela conversa, oferecer **Voltar à conversa** e preservar sua posição. Pela lista, oferecer **Voltar às tarefas**, mantendo filtros. Histórico do navegador, gesto de voltar e teclado seguem a plataforma. “Recentes” e sugestões só mostram conteúdo ainda autorizado. Texto digitado é preservado apenas conforme a política aprovada de rascunhos; se não for possível, avisar antes de descartá-lo.

Na tela compartilhada, evitar histórico pessoal e navegação administrativa. Mostrar a tarefa atual, **Repetir orientação**, **Pausar tarefa** e a opção de continuar no dispositivo pessoal quando esse fluxo existir. Não prometer transferência pronta. Busca por voz tem alternativa visual; frases de exemplo ajudam sem obrigar a memorizar comandos.

## 3. Voz editorial e vocabulário

A Koru fala com calma, objetividade e respeito. Usa primeira pessoa para sua atuação (“Não consegui consultar”) e identifica o sistema quando o resultado depende dele. Não atribui culpa, intenção ou competência à pessoa. Uma resposta curta pode conter informação crítica; brevidade não remove custo, destino ou efeito.

| Conceito | Usar | Evitar |
|---|---|---|
| Algo ainda não enviado | Rascunho | Salvo, sem dizer onde |
| Escrita confirmada | Registro salvo / Ocorrência registrada | Tudo resolvido |
| Fechamento comprovado | Ocorrência resolvida | Resolvido ao apenas encaminhar |
| Dados não obtidos | Não consegui consultar | Nenhum resultado / zero |
| IA paga | Créditos de IA | Pontos / energia |
| Gamificação | Sequência de turnos, explicada no contexto | Ofensiva sem explicação para iniciantes |
| Fonte externa | Nome do aplicativo conectado | MCP, token ou endpoint na tarefa comum |
| Falta de acesso | Seu acesso não permite esta ação | Você não pode / acesso inválido |
| Cancelamento de áudio | Parar resposta | Cancelar tudo |
| Encerramento do microfone | Encerrar conversa por voz | Sair, sem esclarecer o efeito |

Uma ação principal por etapa; ações secundárias continuam encontráveis. Preferir **Registrar ocorrência**, **Salvar rascunho**, **Revisar alteração**, **Ver procedimento** a “OK”, “Enviar” ou “Continuar” sem contexto. “Desfazer” aparece somente com reversão real disponível. Confirmação adicional é proporcional ao efeito; não colocar modal em toda consulta. E-mail e aprovação de permissões de agentes preservam o clique explícito exigido neste checkout.

## 4. Catálogo de estados e recuperação

Textos entre chaves são parâmetros, não mensagens literais. Toda variável vem de dados autorizados e é formatada para leitura; nunca exibir placeholders não resolvidos. Os exemplos não garantem funcionalidades futuras. Só mostrar cada ação quando ela estiver implementada e disponível à pessoa.

| Estado e condição | Mensagem proposta | Ação / comportamento |
|---|---|---|
| Consulta em andamento | “Consultando as pendências de {unidade}…” | Mostrar progresso real; não inventar percentual |
| Escrita em andamento | “Registrando a ocorrência…” | Impedir envio duplicado; manter resultado acessível |
| Escrita confirmada pela origem | “Ocorrência registrada.” | **Ver ocorrência**; ID e horário no detalhe |
| Rascunho persistido com confirmação | “Rascunho salvo. Ainda não foi enviado.” | **Retomar rascunho** |
| Falha antes do envio comprovada | “A ocorrência não foi enviada. Revise a conexão e tente novamente.” | **Tentar enviar novamente**, preservando entrada quando permitido |
| Timeout após envio, resultado desconhecido | “Ainda não consegui confirmar se a ocorrência foi registrada.” | **Verificar registro** consulta a operação existente; não cria outra |
| Conflito de versão | “Este registro mudou enquanto você revisava. Confira a versão atual antes de salvar.” | **Revisar versão atual**; invalidar aprovação anterior |
| Sem acesso | “Seu acesso não permite esta ação.” | **Voltar à tarefa**; contato administrativo apenas se disponível, sem revelar o conteúdo restrito |
| Sessão expirada | “Sua sessão terminou. Entre novamente para continuar.” | **Entrar novamente**; restaurar contexto somente após revalidar acesso |
| Fonte indisponível | “Não consegui consultar {aplicativo}. Tente novamente mais tarde.” | **Tentar consultar novamente**; não apresentar contagem zero |
| Conexão precisa de renovação | “A conexão com {aplicativo} precisa ser renovada.” | Administrador: **Renovar conexão**; demais: orientação ao responsável, sem botão administrativo inoperante |
| Dados antigos disponíveis | “Estes dados foram atualizados em {data e hora}. A atualização mais recente não está disponível.” | **Ver fonte**, quando autorizada; identificar resultado parcial |
| Consulta completa sem pendências no recorte | “Nenhuma pendência neste turno.” | Mostrar turno/unidade; não concluir que toda a operação está regular |
| Busca sem resultado autorizado | “Nenhum resultado para esta busca. Tente outro termo ou ajuste os filtros.” | **Limpar filtros**, se houver; não sugerir existência de itens ocultos |
| Nenhuma fonte conectada | “Ainda não há uma fonte conectada para esta consulta.” | Administrador: **Conectar aplicativo**; demais: **Ver exemplo**, se demo existir |
| Microfone negado | “O microfone está desativado para a Koru. Você pode continuar por texto.” | **Usar texto**; acesso às configurações conforme suporte da plataforma |
| Áudio encerrado, execução ainda ativa | “Conversa por voz encerrada. O registro continua em andamento.” | **Acompanhar registro**; não declarar cancelamento da escrita |
| Recurso não contratado | “O uso de IA não está habilitado neste workspace.” | Administrador: **Ver opções de IA**, se disponível; demais: orientação ao administrador |
| Saldo insuficiente confirmado | “Os créditos de IA disponíveis não são suficientes para esta tarefa.” | Administrador: **Gerenciar créditos**; demais: caminho operacional sem IA, quando disponível |
| Teto individual futuro atingido | “Você atingiu o limite de IA definido para este período.” | Mostrar período e rota autorizada de solicitação; não confundir com saldo global |

Erros que afetam conclusão permanecem no contexto até serem resolvidos, com estado consultável depois. Um aviso que desaparece não é suficiente. **Verificar registro** não é retry de escrita. Se a origem ainda não permitir verificação, informar que o resultado segue pendente e oferecer o suporte real disponível, sem prometer prazo.

Não afirmar “Seus dados estão salvos”, “Nada foi cobrado” ou “Tente de novo sem custo” sem confirmação específica. Causa desconhecida recebe mensagem honesta; não atribuir automaticamente toda falha à conexão da pessoa.

## 5. Confirmações, formulários e custo

Exemplo fictício de confirmação: **Registrar temperatura**. Resumo: “Geladeira 2 · Unidade Centro · 4 °C · {data e hora}”. Ações: **Registrar temperatura** e **Corrigir dados**. A origem pode exigir evidência adicional. Não inventar faixa permitida; validar conforme o procedimento aprovado. Distinguir valor tecnicamente inválido de medição real fora do padrão: a segunda precisa poder ser registrada conforme o processo, sem incentivar sua alteração para parecer normal.

Labels persistentes: **Equipamento**, **Temperatura (°C)**, **Observação (opcional)**. Exemplo de erro: “Informe a temperatura em números. Exemplo: 4,5.” Preservar o que foi digitado, aceitar formato local conforme contrato e mostrar o entendimento antes de gravar. Associar erro ao campo e posicionar foco de modo previsível. Não marcar um campo como opcional quando a política do processo o exige.

Confirmação de compartilhamento: **Compartilhar modelo** → mostrar artefato, versão, público/destinatários e prévia. Em exportação: “Quem receber o arquivo poderá guardar ou encaminhar uma cópia. Revogar um link não remove essas cópias.” Botão **Exportar modelo**; alternativa **Voltar à revisão**. Não usar “Compartilhar com segurança” como garantia absoluta.

Antes de uso cobrado, informar workspace pagador e a regra aplicável. Se houver teto tecnicamente garantido: “Esta tarefa usará até {limite} créditos de IA de {workspace}.” Se houver apenas estimativa: “Consumo estimado: {estimativa} créditos de IA. O valor final depende de {fatores relevantes}.” Não chamar estimativa de limite. O fluxo comercial depende das decisões de [créditos](CREDITS.md); não publicar valores de exemplo como tarifa aprovada.

Durante a sessão, **Créditos usados** só mostra consumo confirmado; estimativa e apuração pendente têm rótulos próprios. Encerrar voz informa o fim da captura e o estado de tarefas já iniciadas. Eventual cobrança do uso já realizado segue a política aprovada; não prometer estorno automático.

## 6. Voz, alertas e progresso sem pressão

Voz deve entregar um fato e um próximo passo por vez. Exemplo fictício: “Há uma pendência na abertura. Posso mostrar o item.” Detalhes, fontes e revisão ficam na tela. Diante de ambiguidade: “Você disse geladeira dois ou doze?” Não ler identificadores longos nem recitar todos os botões. Não repetir dados privados em aparelho compartilhado para pedir confirmação.

O texto **Ouvindo** aparece somente enquanto a captura está ativa. **Preparando resposta** não significa que uma escrita começou. Reconexão não reativa microfone silenciosamente. No Echo Show, não instruir “Diga apenas Koru” como funcionalidade entregue; usar somente invocação validada para a skill e o aparelho.

| Contexto | Texto candidato | Controle |
|---|---|---|
| Alerta em tela bloqueada | “Há uma atualização na Koru.” | **Abrir Koru**; conteúdo após autenticação |
| Lembrete pessoal autorizado | “Sua revisão do turno está pendente.” | **Ver revisão**; ajustes de frequência acessíveis |
| Escolha de lembrete | “Quer receber um lembrete antes da sua próxima revisão?” | **Configurar lembrete** / **Agora não** |
| Contribuição válida | “Participação registrada neste turno.” | Detalhe do critério; não declarar conformidade de toda a operação |
| Retorno após quebra de sequência | “Você pode começar uma nova sequência no próximo turno elegível.” | **Ver próxima tarefa**; sem culpa ou perda do trabalho anterior |
| Folga confirmada | “Hoje não conta para sua sequência.” | Explicação do calendário; não estimular trabalho fora da escala |
| Preferência social | “Mostrar minhas conquistas para a equipe” | Desativada até escolha explícita; sem efeito nas obrigações operacionais |

Evitar “Você decepcionou sua equipe”, “Última chance”, “Não perca tudo” e celebrações que ocultem erro, pendência ou custo. Alertas operacionais obrigatórios e lembretes opcionais precisam de políticas distintas e visíveis. Silenciar a camada de jogo não confirma resolução de ocorrência.

## 7. Acessibilidade e verificação antes de implementar

O texto visível fornece o nome acessível dos controles; ícones isolados precisam de nome equivalente. Campo não depende de placeholder, erro não depende de vermelho e explicação de bloqueio não depende de hover. Mudanças importantes são anunciadas por tecnologia assistiva sem repetir cada atualização de streaming. Devolver foco ao controle de origem ao fechar modal; status persistente continua encontrável.

Revisar toque, teclado, leitor de tela, zoom, orientação, redução de movimento e alternativa textual à voz nos dispositivos escolhidos. Contraste e dimensões de alvo seguem o contrato de acessibilidade da implementação, a definir/verificar antes da entrega; esta avaliação textual não certifica conformidade visual. Datas, fuso da unidade, números, plurais e nomes longos precisam de exemplos reais, incluindo um e vários itens. Não usar limites universais de caracteres sem testar o layout e a leitura por voz.

Percursos de validação propostos:

1. Operador encontra procedimento sem conhecer o comando, registra uma medição e corrige uma ambiguidade.
2. Gestor abre pendência pelo chat, enfrenta conflito de versão e retorna sem perder o contexto.
3. Dono identifica workspace pagador, entende estimativa versus teto e encerra voz com uma tarefa ainda ativa.
4. Colaborador interno encontra um indicador permitido e entende uma negação sem descobrir dados de outras áreas.
5. Pessoa em aparelho compartilhado continua em sessão pessoal sem expor histórico; uma falha após envio mantém o resultado desconhecido identificável.
6. Pessoa usando teclado/leitor de tela encontra busca, percebe erro, corrige campo e retoma a tarefa.

Registrar conclusão correta, hesitação, interpretação de mensagens e recuperação. Testar variações apenas quando houver dúvida concreta; não escolher texto por preferência interna isolada. Runtime, acessibilidade e testes com pessoas permanecem pendentes. Esta entrega altera documentação, sem telas, instrumentação ou testes de produto.
