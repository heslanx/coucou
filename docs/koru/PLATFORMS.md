# Dispositivos, voz em tempo real e alertas

[Índice](README.md) · 2026-10-30 · Plataformas são direção aceita; capacidade por sistema exige prova técnica.

## 1. Disponibilidade desejada

A Koru deve existir como app instalável em **macOS/MacBook, iPadOS/iPad, iOS/iPhone, Android, Windows e Linux**, além da **web**. Instalação, assinatura, atualização e suporte fazem parte do produto. Uma página responsiva não prova que o aplicativo nativo foi entregue.

Compartilhar identidade, contexto autorizado, histórico, capacidades MCP e cobrança. Adaptar interação, navegação, notificações, áudio, acessibilidade e uso de recursos a cada dispositivo. O app Flutter já existente em `konclui-platform/apps/mobile` é o caminho inicial provável para a integração mobile. O trabalho nativo neste checkout segue como exploração paralela; não foi decidida reescrita nem adoção de um único framework para todos os canais. Ver [ADR-005](../decisions/ADR-005-koru-mobile-evolution.md).

### Evolução mobile sem depender de reescrita

Primeiro investigar como a Koru entra na navegação, sessão e permissões do Flutter atual, reaproveitando os contratos de backend e respeitando rascunhos, filas e versões existentes. Não presumir que as abas propostas no documento de UX substituirão as atuais. A operação offline existente não demonstra IA offline.

Em paralelo, comparar capacidades específicas em protótipos nativos: voz, retomada de sessão, acessibilidade, notificações e uso de recursos. Usar a mesma tarefa, condições de rede e aparelhos representativos. Considerar uma integração nativa delimitada dentro do Flutter antes de concluir que é necessário outro app.

Uma decisão futura de migração exige benefício observado, custo de manter dois clientes, compatibilidade de APIs, preservação de dados/sessões, rollout e rollback. Não duplicar carteira, permissões ou regras de processo por plataforma. A pesquisa de [engenharia mobile e agentes](../../.feature-radar/references/duolingo-engineering.md) orienta hipóteses, sem importar metas ou tecnologias automaticamente.

| Superfície | Uso principal | Adaptação desejada |
|---|---|---|
| MacBook/macOS | Gestão, investigação, documentos e acompanhamento | Janela completa, acesso rápido, teclado, notificações e uso discreto da personagem |
| Windows | Gestão e operação administrativa | Instalação/atualização, atalhos e integração com notificações do sistema |
| Linux | Gestão e estações operacionais compatíveis | Definir distribuições e arquiteturas suportadas; testar áudio e notificações nelas |
| iPhone | Gerente no bolso, evidência, aprovação e voz | Uma mão, câmera, notificações, atalhos e continuidade de tarefa |
| Android | Operação e gestão móvel | Mesmas jornadas essenciais, permissões e variações de bateria por fabricante |
| iPad | Gestão móvel e estação de setor | Layout amplo, toque, teclado e modo compartilhado com troca segura de usuário |
| Web | Acesso sem instalar, investigação e administração | Navegadores suportados, teclado, layouts responsivos; PWA onde fizer sentido |
| Echo Show | Consultas curtas e rotina guiada por voz | Tela legível à distância, respostas breves e continuidade no celular |
| Dispositivo dedicado futuro | Presença contínua no setor | Canal separado a avaliar se tela permanente e wake word própria forem requisitos centrais |

O Coucou deste repositório é uma referência de implementação existente; não demonstra que a identidade, MCPs e carteira Koncluí estejam integrados às suas versões desktop/mobile.

## 2. Três capacidades diferentes

1. **Abrir a Koru:** toque, atalho, widget ou invocação pela assistente do sistema.
2. **Chamar apenas “Koru”:** detecção de palavra de ativação, possivelmente local, com processo habilitado para ouvir.
3. **Conversar em tempo real:** áudio bidirecional numa sessão aberta, com interrupção e contexto.

Uma delas funcionar não comprova as outras. Receber notificações também não exige microfone permanentemente aberto.

### Matriz de compromisso

| Plataforma | Base que deve orientar a primeira entrega | “Koru” com app em segundo plano ou fechado |
|---|---|---|
| iOS/iPadOS | Toque, atalhos/App Intents a validar, sessão de voz explícita e notificações autorizadas | Pesquisa; não prometer substituição da Siri nem escuta permanente universal |
| Android | Toque/atalhos e sessão explícita; avaliar serviço permitido e papel de assistente | Condicional a versão, permissões, papel do app, fabricante e política de distribuição |
| macOS/Windows/Linux | Atalho e sessão de voz; avaliar detecção local opt-in com app em execução | Hipótese testável; app encerrado não equivale a serviço de escuta ativo |
| Web/PWA | Voz enquanto o navegador permite, após consentimento | Não prometer ativação com navegador fechado ou aba suspensa |
| Echo original | Invocação de skill e interação na sessão | Uma skill não cadastra uma palavra arbitrária para substituir a ativação do Echo |
| Echo modificado | Laboratório separado | Possível em projetos e modelos específicos, sem garantia para a frota de clientes |

Apple restringe usos de execução em segundo plano e exige transparência na gravação; isso não comprova nem proíbe toda sessão de áudio persistente. É necessário validar o desenho concreto, versões e distribuição. Android documenta restrições de início de serviços e permissões de microfone, com exceções específicas. [Apple](https://developer.apple.com/app-store/review/guidelines/), [Android](https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start).

### Estudo de ativação local

Se habilitado, detectar localmente com sinalização de microfone e botão fácil de desligar; enviar áudio ao serviço só no contexto autorizado. Medir falsos positivos, falhas de ativação, consumo de bateria/CPU, distância e diferentes sotaques. Não usar a voz como autenticação forte. Verificar compatibilidade de bibliotecas e licenças antes da adoção.

Casos obrigatórios: aparelho bloqueado, app em primeiro/segundo plano, encerramento pelo usuário, reinício, chamada telefônica, Bluetooth/fones, economia de energia, revogação de permissão e suspensão pelo sistema.

## 3. Voz em tempo real

A referência de experiência é a fluidez que o usuário associa ao Grok Bot: conversar naturalmente, interromper e continuar com contexto. Não significa copiar seu backend ou escolher o mesmo fornecedor. A documentação pública de voz xAI confirma padrões de áudio bidirecional, transcrição e interrupção; o exemplo consultado não se declara pronto para produção. [Referência](https://docs.x.ai/cookbook/examples/voice-agent-webrtc).

Requisitos propostos:

- Início e fim inequívocos da sessão; indicador de microfone e saída imediata.
- Detecção de fim de fala, interrupção da resposta pela pessoa e cancelamento de áudio já enfileirado.
- Transcrição visível e correção de números, nomes, unidades e alvos antes de uma ação ambígua.
- Uso de ferramentas durante a conversa, com confirmação e permissões iguais às do texto.
- Distinguir parar a fala de cancelar uma ação: interromper a voz não desfaz uma escrita já confirmada.
- Manter o estado confirmado ao reconectar, sem repetir ações nem débitos; não reabrir o microfone silenciosamente.
- Respostas curtas por voz e detalhes na tela; não ler tabelas extensas ou dados sensíveis em ambiente compartilhado.
- Funcionar com sotaques brasileiros, ruído de cozinha, múltiplas vozes e fones; manter alternativa por toque/texto.
- Sessões com orçamento e teto de duração/ociosidade. Chaves de fornecedor duráveis não ficam no cliente.
- Medir latência até primeiro áudio e conclusão, sucesso de interrupção, correções, reconexão, custo e qualidade por dispositivo.

O streaming é uma escolha técnica a validar entre transporte e fornecedor. Prova de uma API em tempo real não é prova de qualidade na cozinha do cliente.

## 4. Alertas automáticos

Alertas são eventos de negócio autorizados, não iniciativa irrestrita do modelo. Exemplos: item crítico vencido, ocorrência escalada, resumo agendado e decisão aguardando a pessoa responsável.

Fluxo proposto: evento confiável → avaliar escopo/criticidade → aplicar preferências e horário → deduplicar/agrupar → escolher canal → enviar → registrar estado → escalar conforme regra configurada.

- Definir dono, unidade, responsável, prazo e motivo; evitar “há algo errado” sem próxima ação.
- Respeitar expediente, descanso, silêncio, dispositivo compartilhado e opção de resumo.
- Diferenciar enviado, entregue quando observável, visto, reconhecido e resolvido.
- Revalidar acesso no momento da entrega e ao abrir o conteúdo.
- Não colocar detalhes privados na tela bloqueada por padrão.
- Agrupar ocorrências repetidas; não tocar som em todos os dispositivos simultaneamente sem preferência explícita.
- Configurar delegação de automações e orçamento de IA para resumos. Um alerta determinístico não precisa de uma geração de IA por destinatário.
- Push depende das permissões, rede e comportamento do sistema; não prometer prazo garantido.

Na Alexa, eventos proativos usam categorias predefinidas, permissões e limites. Uma venda ou pendência operacional não deve ser encaixada artificialmente em um schema sem correspondência. Não prometer que uma skill falará ou tocará automaticamente a cada evento. [Amazon](https://developer.amazon.com/en-US/docs/alexa/smapi/proactive-events-api.html).

## 5. Echo Show como produto para clientes

A recomendação proposta é usar skill oficial com account linking para um piloto suportável. O navegador Silk é útil para demonstração visual, mas não equivale a controle nativo de voz, quiosque permanente ou entrega confiável de alertas.

A skill local atual usa “minha coruja”; “Koru” é intenção de nome a testar no reconhecimento e nas regras da plataforma. Não há implantação confirmada no aparelho. [Protótipo](../../alexa/README.md).

| Referência de laboratório | O que investigar | Limite |
|---|---|---|
| [EchoLocal](https://github.com/ygelfand/echolocal) | Assistente local, wake words, áudio e integração Home Assistant | Desbloqueio e modelos específicos |
| [TECHO5](https://github.com/HuskerMinion/techo5) | Controle do sistema/tela e modelos próprios de ativação | Substituição de firmware e suporte de hardware |
| [echo-show-claude](https://github.com/lee-soft/echo-show-claude) | Assistente conectado a agente em Show 5 com root | O projeto usa “Hey Jarvis”; o modelo próprio “Hey Claude” foi retirado |
| [HomeAssistantAssist](https://github.com/fabianosan/HomeAssistantAssist) | Skill, conversa e painel no Show | Projeto alfa e dependência do fluxo Amazon/Home Assistant |

São evidências de possibilidade, não homologação pela Koncluí. Não recomendar modificações em aparelhos de clientes sem uma decisão específica de suporte, instalação, atualização e recuperação. Se a experiência exigir controle total, avaliar equipamento dedicado contra o custo de manter uma frota de Echos modificados.
