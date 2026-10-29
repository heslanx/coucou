# Koncluí · Sons da Koru (v2)

Os 29 sons do Koncluí e 4 loops de ambiente, refeitos na identidade sonora oficial da Koru. A v1 (unidade K4: marimba modal com
modos inarmônicos, sinos com pares em batimento, sala, low-pass em 11 kHz) soava "metalizada". A v2 usa só o que a Koru já tem:
vozes senoidais com glide, vibrato de 6 Hz, parciais 2 e 3 baixos e harmônicos, ataques lentos, decaimento exponencial. Nenhum modo
inarmônico, nenhuma sala, nenhum sino metálico.

| Pergunta | Onde está |
|---|---|
| Receitas, mapeamento, níveis, loops | `scripts/konclui/sounds.py` (branch `heslanx/konclui`, worktree do Koncluí) |
| Os 29 arquivos do app (48 kHz, estéreo, 16 bits) | `NotchBuddy/Resources/sounds/*.wav` (mesmo worktree) |
| Masters dos loops, contact sheet, preview, tabelas de prova | `design/konclui/sound/` (mesmo worktree) |
| Cópias do protótipo (AAC) e os loops em base64 | `design/prototype/koru/sounds/*.m4a`, `koru/sounds/loops.js` (este checkout) |
| Player do protótipo | `design/prototype/koru/features/sounds.js` |
| Identidade oficial da Koru (somente leitura) | `konclui-project/koru/docs/sound.md`, `spec/sound.json`, `lib/koru-sound.js` |

## 1. O que veio da Koru, e por quê

Do `docs/sound.md` e do `lib/koru-sound.js` da Koru:

- **As receitas, portadas literalmente.** `koru_render()` em `sounds.py` reproduz `KoruSound.render()` (mulberry32, biquad RBJ por
  amostra, `addVoice`, `tickInto`, `whoosh`, `thump`, normalização a -12 dBFS, fade final de 2 ms). Prova na §9: correlação 1,000000 e
  diferença máxima de 3,3e-8 (arredondamento do `Float32Array`) nos 8 sons, a 48 e a 44,1 kHz. Os eventos do Koncluí são escritos com
  essas mesmas funções, então a família é a mesma da Koru, não uma imitação.
- **O caráter:** calma, atenta, discreta, "não faz barulho" (`playbook.md` §2). Sons de 40 a 400 ms, a animação é o feedback e o som só
  sublinha. A Koru nunca repreende: sem buzzer, sem "wah" descendente, sem suspiro.
- **A regra de silêncio:** decorativo, alta frequência ou o que possa soar como queixa fica mudo (`appropriate-no-decorative`,
  `appropriate-no-high-frequency`, `appropriate-no-punishing`). Seis eventos viram arquivos mudos (§5).
- **Mesmo pico para todos.** A Koru normaliza tudo a um pico só, e o volume do host é o único controle de intensidade.
- **Determinismo:** todo ruído é semeado; `sounds.py` rodado duas vezes grava arquivos idênticos byte a byte.

Desvios, cada um com motivo:

| Desvio | Koru | Koncluí | Por quê |
|---|---|---|---|
| Tonalidade | glides 620→840 Hz, 680→900 Hz | o mesmo gesto com os pontos de chegada em Dó maior pentatônico (C5 D5 E5 G5 A5) | uma família numa tonalidade só; o deslocamento máximo é 7 % (840→784 Hz) |
| Pico do arquivo | -12 dBFS com volume do host 0,3 | -4 dBFS com o volume do app 0,12 | dá o mesmo nível ouvido, ver §6 |
| Low-pass quente | nenhum | Butterworth de 2ª ordem em 6 kHz em todos os one-shots | amacia o transiente dos ticks e o topo do whoosh; as vozes (até 3 kHz com os parciais) passam intactas |
| Ruído do tick | 4 kHz, Q 3 | 1,5 a 3 kHz, Q 2 a 2,5 | "batidinha de madeira", não clique mecânico (a própria Koru já tinha baixado o ataque por esse motivo) |
| Thump (`slap`) | 130→65 Hz | 220→110 Hz, parciais 2 e 3 mais fortes, ruído em 900 Hz | alto-falante de MacBook não reproduz 65 Hz; o tapa sumiria |
| Duração | 40 a 400 ms | `greeting` com 2,26 s | é o logo sonoro da saudação de 4,6 s, posicionado no aceno (1,45 s); a parte audível tem 0,8 s |
| Calor | só os parciais 2 e 3 | `love` e `finish` ganham um sub (oitava abaixo) baixo; `love` um sopro de 3 % | o carinho e o "pronto" pedem corpo; os outros ficam no timbre da Koru puro |
| Loops | "nada faz loop" | 4 loops opcionais (desligados por padrão) | o pedido da unidade; a doutrina continua valendo por padrão (§7) |

## 2. A assinatura

**`greet` = o "oi" da Koru:** `chirp-double`, dois chirps subindo, o segundo mais agudo, 150 ms entre eles (D5→G5, depois E5→A5). É o
gesto do aceno da Koru e o motivo que identifica a família. O `greeting` (primeira saudação) toca a assinatura no aceno e emenda o
`chime-rise` da Koru (sinos C5 E5 G5, 110 ms entre eles): é o logo sonoro do Koncluí. Os outros sons são parentes: chirps de um gesto só
(`approve`, `question`, `work`, `wink`), a assinatura com resolução (`finish`), os ticks de madeira da Koru (`approval`, `peek`, `rate`,
`attach`, `blip`, `tick`).

## 3. Receitas

Voz (`voice()`, a `chirpVoice` da Koru): senoide com glide exponencial de f0 a f1, vibrato de 6 Hz a 1,5 %, parcial 2 a 0,2 e 3 a 0,1,
ataque linear de 8 ms, decaimento exponencial τ 45 ms, fade linear de 3 ms no fim de toda voz. Sino (`bell()`): senoide pura, parcial 2
a 0,25 e 3 a 0,06, ataque 4 ms, τ 70 ms. Tick (`tick_into()`): senoide de 50 ms com ataque de 6 ms e 8 ms de ruído passa-banda. Todos os
arquivos passam pelo `master()`: low-pass quente, pico a -4 dBFS, fade de 2 ms até zero exato.

## 4. Mapeamento (29 eventos)

"Onde toca" são as chamadas do app Mac no worktree do Koncluí (`NotchBuddy/Sources`). No protótipo os mesmos nomes chegam por
`bot.sound(name)` (`core.js`: estados 270, `greet` 298, emotes 310; `slap.js`, `gulp.js`, `voice.js`).

| Evento (arquivo) | Onde toca no Mac | Som | Receita | ms | Regra |
|---|---|---|---|---|---|
| greet | BotEngine.swift:599 (aceno) | assinatura `chirp-double` | chirp D5→G5 em 0, E5→A5 em 150 ms | 300 | appropriate-confirmations-only; weight-duration-matches-action |
| greeting | GreetingCanvasView.swift:699 (primeira saudação, 4,6 s) | assinatura + `chime-rise` | silêncio até 1,45 s (GT.pop1, o aceno), assinatura, sinos C5 E5 G5 em 1,78/1,89/2,00 s | 2260 | desvio documentado da faixa 40-400 ms: o logo sonoro acompanha o aceno |
| finish | HookServer.swift:630, ClaudeDesktopChatWatcher.swift:88, N8nPoller.swift:239, VercelPoller.swift:95, StripePoller.swift:144, AppState.swift:658, DemoEngine.swift:556 | família chirp, leve | chirp C5→G5 (sub 0,08) e sino C6 a 0,5 em 110 ms | 300 | appropriate-confirmations-only; leve porque é frequente (weight-match-action) |
| approve | IslandWindowController.swift:850, :987, :1913, :1949; FileDropView.swift:77, :110; DesktopMochi.swift:665 | `chirp` | D5→G5 | 140 | appropriate-confirmations-only |
| pop | MachineVitals.swift:109, DesktopMochi.swift:209, ScreenCapture.swift:148, WhatsAppController.swift:579, IslandViewContent.swift:1617, SettingsView.swift:327 | chirp pequeno | E5→A5 em 90 ms, sem vibrato, τ 25 ms | 90 | appropriate-confirmations-only; weight-match-action |
| question | HookServer.swift:575, BotEngine.swift:665, AppState.swift:658, DemoEngine.swift:533 | chirp curioso subindo | C5→A5, glide 160 ms, τ 80 ms | 280 | appropriate-errors-warnings (pede atenção sem alarme) |
| approval | HookServer.swift:926, :1077; DemoEngine.swift:514 | `tick-double` | ticks G5 e C6 (120 ms), τ 26 ms, ruído 2,5 kHz | 250 | appropriate-errors-warnings: não pode passar despercebido; dois toques, não alarme (appropriate-no-punishing) |
| peek | MacUpdater.swift:206, DesktopMochi.swift:344, IslandWindowController.swift:284 | `tick-double` leve | ticks E5 e G5 (100 ms), τ 14 ms | 200 | novidade que pode passar despercebida (a `flutter` da Koru) |
| error | HookServer.swift:658; IslandWindowController.swift:680, :831, :844, :847; N8nPoller.swift:239; VercelPoller.swift:95; AppState.swift:658 | `boop-down` | C5→G4, ataque 30 ms, τ 55 ms | 220 | appropriate-errors-warnings; appropriate-no-punishing |
| rate | HookServer.swift:604 | `tick-double` grave e suave | dois ticks G4, τ 30 ms, ruído 1,5 kHz | 230 | aviso de espera, não falha (appropriate-no-punishing) |
| slap | BotEngine.swift:432 | `thump` suave | 220→110 Hz, parciais 0,3/0,12, ruído LP 900 Hz | 120 | reação ao clique do usuário; weight-match-action |
| gulp | ScreenCapture.swift:95 | engolida brincalhona | chirp G5→C5 em 50 ms e thump pequeno (200→100 Hz) em 85 ms | 200 | confirmação da captura; rápido e agudo, distinto do `error` |
| send | ScreenCapture.swift:136, IslandViewContent.swift:1333 | `whoosh` | ruído com passa-banda 400→1600 Hz, Q 2 | 180 | appropriate-confirmations-only (mensagem enviada) |
| attach | não é tocado pelo Mac hoje (só `SoundEngine.soundNames`) | dois ticks de madeira | C5 e E5, 70 ms | 150 | weight-match-action |
| blip | FlowDictation.swift:313; IslandViewContent.swift:1699, :4125, :4132, :4139 | tick de madeira | C6, τ 10 ms, ruído 3 kHz | 50 | marcador mínimo (ditado ou nota começa) |
| tick | IslandWindowController.swift:350, :701, :1868; FileDropView.swift:100; ScreenCapture.swift:42 | `tick` | G5, ruído 2,5 kHz | 50 | marcador mínimo; ver §10 sobre FileDropView.swift:100 |
| work | HookServer.swift:539 (SessionStart) | "hu" curtinho | chirp C5→D5, τ 20 ms | 80 | frequente: o mais leve dos chirps |
| think | só `BotStateCfg.sound` (BotEngine.swift:112, nunca lido no Mac) | "hm" | chirp A4→C5, ataque 15 ms | 110 | frequente, curto |
| search | só `BotStateCfg.sound` (BotEngine.swift:119) | "pip-pip" | dois chirps G5→A5 de 55 ms | 130 | frequente, curto |
| love | IslandWindowController.swift:577 (carinho, no máximo a cada 6 s) | coo quente e grave | G4→C5, vibrato 5,5 Hz a 2,5 %, sub 0,15, sopro 3 % | 380 | resposta a um gesto do usuário |
| proud | WhatsNewViews.swift:73 | `chime-rise` | sinos C5 E5 G5 | 400 | a única celebração de peso médio |
| wink | não é tocado pelo Mac (o emote não chama som) | chirp agudo mínimo | A5→D6 em 70 ms | 70 | weight-match-action |
| dizzy | só `BotStateCfg.sound` (BotEngine.swift:168) | chirp bamboleante | E5→A5 com vibrato de 9 Hz a 4,5 % | 380 | brincalhão, sobe (nunca triste) |
| hover | IslandWindowController.swift:561 | **mudo** | 50 ms de zeros | 50 | appropriate-no-decorative; hover nunca soa |
| open | IslandWindowController.swift:604 | **mudo** | 50 ms de zeros | 50 | appropriate-no-high-frequency, appropriate-no-decorative |
| close | IslandWindowController.swift:606 | **mudo** | 50 ms de zeros | 50 | appropriate-no-high-frequency, appropriate-no-decorative |
| sleep | só `BotStateCfg.sound` (BotEngine.swift:161) | **mudo** | 50 ms de zeros | 50 | a `rest`/`drowse` da Koru: um suspiro soaria como queixa (appropriate-no-punishing) |
| yawn | não é tocado pelo Mac | **mudo** | 50 ms de zeros | 50 | a `soft-yawn` da Koru: appropriate-no-decorative |
| annoyed | BotEngine.swift:444, :857 | **mudo** | 50 ms de zeros | 50 | a Koru nunca repreende (appropriate-no-punishing); o tapa já tem o `slap` |

O iPhone (fora do escopo, D7) usa `approval`, `finish`, `question` e `error` como sons de notificação (`project.yml`:307-314): todos
continuam válidos (curtos, WAV).

## 5. Silêncio

`hover`, `open`, `close`, `sleep`, `yawn`, `annoyed`: arquivos de 50 ms de zeros (2400 quadros, estéreo), para que o `SoundEngine`
continue achando o arquivo e nenhum código mude. Motivos: hover, open e close acontecem a toda hora e são decorativos; sleep e yawn
são estados de baixa energia que a Koru deixa calados; annoyed soaria como bronca.

## 6. Níveis

Todo arquivo que soa tem pico de amostra em **-4,0 dBFS** (doutrina: um pico só). Por quê -4: a Koru entrega -12 dBFS a volume 0,3,
o que dá -22,5 dBFS ouvidos ("audível numa sala quieta, ignorável numa cozinha"). O app toca a `AppState.soundVolume` = 0,12
(-18,4 dB), então -4 dBFS × 0,12 = **-22,4 dBFS**, o mesmo nível efetivo. O protótipo começa no mesmo 0,12. RMS dos one-shots: -14 a
-21 dBFS (`design/konclui/sound/files.md`). Nenhum clip, primeiro e último quadro em zero exato em todos.

Consequência conhecida: a v1 casava o nível de cada som do Coucou (hover e tick ~30 dB abaixo dos alertas). Com pico único, os sons
curtos (tick 50 ms) soam naturalmente mais leves que os longos, como na Koru, e hover agora é mudo.

## 7. Loops de ambiente

A doutrina diz que estados contínuos são mudos; por isso os loops são **opt-in** ("Som ambiente", desligado por padrão) e muito baixos:
pico de **-16 dBFS** (12 dB abaixo dos one-shots, -34,4 dBFS ouvidos a 0,12), RMS de -29 a -33 dBFS. Período de **4,0 s**, o da
respiração (`breathe`) da Koru.

| Loop | Estado | Por quê | Conteúdo | Emenda |
|---|---|---|---|---|
| `sleep-loop` | sleeping | dormir dura minutos; uma respiração lenta conta que a Koru está ali sem pedir nada | inspiração de ar (700-2600 Hz) 0,25-1,65 s, expiração mais longa e quente (250-1300 Hz) 1,55-3,75 s com um "hoo" baixo em C4, sobre um chiado constante | na pausa depois da expiração (só o chiado soa) |
| `think-loop` | thinking | o streaming pode levar dezenas de segundos; um "hm... hm..." diz "estou pensando" | dois "hm" com a voz da Koru, E4 e depois G4, sobre um ar fraco que respira junto | entre os dois "hm" (só o ar) |
| `work-loop` | working | trabalho longo; um pulso de atividade tranquilo | ar pulsando 2 vezes por segundo (8 por ciclo) e um zumbido C5+G5 que cresce uma vez por ciclo | contínua |
| `search-loop` | searching | a busca "varre"; o som varre junto | faixa de ar subindo e descendo 600↔1700 Hz duas vezes por ciclo | contínua |

Candidatos descartados: **listening** (o microfone está aberto: o loop vazaria para a gravação e atrapalharia o reconhecimento de
voz, e é o usuário quem está falando); **approval** e **question** (um pedido em loop vira cobrança, appropriate-no-punishing; o
one-shot e o badge bastam); **ratelimit** (soaria como queixa); **dizzy** (dura 3,3 s e já tem one-shot); **idle** (decorativo).

Como a emenda é garantida: cada parcial tem frequência múltipla de 1/4 s (`snap()`, por exemplo C4 = 261,75 Hz), o vibrato e todo LFO
fecham ciclos inteiros em 4 s, o ruído é gerado nos bins da própria FFT do loop (periódico por construção), a varredura do `search`
é filtrada por overlap-add circular, e os envelopes são funções periódicas (`bump()` dá a volta no fim). Nenhum fade na emenda.

Prova (`design/konclui/sound/seams.md`): cada loop concatenado 3 vezes, detector de clique = pico da segunda diferença na emenda
(±2 amostras) dividido pelo maior valor dos 10 ms em volta; clique acima de 2.

| Loop | Master WAV: razão nas 2 emendas | Controle (cortado 66 quadros) | Cópia AAC decodificada |
|---|---|---|---|
| sleep-loop | 0,25 / 0,25 (sem clique) | 9,75 (clique) | 4,00, pico -66 dBFS |
| think-loop | 0,28 / 0,28 (sem clique) | 15,31 (clique) | 2,33, pico -48 dBFS |
| work-loop | 0,13 / 0,13 (sem clique) | 2,96 (clique) | 0,90 (sem clique) |
| search-loop | 0,11 / 0,11 (sem clique) | 78,00 (clique) | 2,51, pico -48 dBFS |

Os masters (o que o app usaria) emendam sem clique; o controle mostra que o detector pega uma emenda ruim. A cópia AAC do protótipo
tem um resíduo do codec na emenda (pico da segunda diferença de -48 a -66 dBFS no arquivo, -66 a -84 dBFS ouvidos a 0,12), que o
detector estrito marca; o app deve usar os WAV.

No protótipo os loops tocam por Web Audio (`AudioBufferSourceNode` com `loop`, de amostra em amostra): um `<audio loop>` volta ao início
com uma pausa audível, e o Chrome conta o priming e o resto do AAC na duração (4,0533 s em vez de 4,0). Como uma página `file://` não
pode buscar arquivos, `koru/sounds/loops.js` traz os quatro `-loop.m4a` em base64; `sounds.js` os decodifica no início e toca um
período de 4 s exato, pulando o priming de 2112 quadros quando o decodificador o deixa. Sem Web Audio, ou se o AAC não decodificar,
o loop toca num `<audio loop>` (com a pausa).

## 8. Como regenerar

No worktree do Koncluí:

```sh
python3 scripts/konclui/sounds.py                    # 29 WAV em NotchBuddy/Resources/sounds, 4 loops em design/konclui/sound/loops
sh design/konclui/sound/tools/prototype-assets.sh /Users/erickheslan/Developments/study/coucou/design/prototype   # .m4a + loops.js
python3 design/konclui/sound/tools/port_check.py > design/konclui/sound/port.md          # prova do port (node + koru-sound.js)
python3 design/konclui/sound/tools/measure.py NotchBuddy/Resources/sounds design/konclui/sound/loops <loops AAC decodificados> design/konclui/sound
```

`measure.py` grava `files.md` (formato, pico, RMS, bordas), `seams.md` (prova dos loops), `contact-sheet.png` (forma de onda +
espectrograma) e `preview.m4a` (todos os sons em sequência, os loops duas vezes; tempos em `preview.txt`). Para decodificar os loops
AAC: `afconvert -f WAVE -d LEI16 <x>-loop.m4a <dir>/<x>-loop.wav`. `sounds.py` é determinístico (sha256 igual entre execuções); o
`afconvert` carimba o contêiner, então os `.m4a` mudam de bytes a cada execução, o áudio decodificado não.

Prova do player do protótipo: `design/konclui/sound/tools/probe.html` (Chrome headless, `Audio` e Web Audio simulados; `?nowa` testa o
fallback, `?shot=idle` uma captura) e `decode.html` (os 33 `.m4a` carregam no Chrome).

## 9. Prova do port

`port_check.py` renderiza os 8 sons oficiais com `require('koru/lib/koru-sound.js')` no node e com `koru_render()` em Python.

| Som | 48 kHz: correlação / diferença máx. | 44,1 kHz: correlação / diferença máx. |
|---|---|---|
| chirp | 1,000000 / 2,4e-8 | 1,000000 / 1,9e-8 |
| chirp-double | 1,000000 / 2,4e-8 | 1,000000 / 1,9e-8 |
| chime-rise | 1,000000 / 1,8e-8 | 1,000000 / 2,2e-8 |
| boop-down | 1,000000 / 2,4e-8 | 1,000000 / 1,8e-8 |
| tick | 1,000000 / 2,2e-8 | 1,000000 / 2,4e-8 |
| tick-double | 1,000000 / 3,3e-8 | 1,000000 / 2,5e-8 |
| whoosh | 1,000000 / 1,8e-8 | 1,000000 / 1,8e-8 |
| thump | 1,000000 / 2,1e-8 | 1,000000 / 2,3e-8 |

Mesmo número de amostras e pico de -12,00 dBFS em todos. A diferença é o arredondamento do `Float32Array` do JS.

## 10. Auditoria sounds-on-the-web

### App Mac (`SoundEngine.swift` e chamadas, worktree do Koncluí)

| Regra | Estado | Evidência |
|---|---|---|
| a11y-visual-equivalent | ok | cada `play` acompanha uma mudança visível: HookServer.swift:538-539 (a ilha abre e `work` toca), BotEngine.swift:432-433 (`slap` e o squash), IslandWindowController.swift:350-352 (`tick` e `fsm.voiceWoke()`), FileDropView.swift:109-111 (gulp, `approve` e emote) |
| a11y-toggle-setting | ok | `SoundEngine.play` checa `AppState.shared.soundEnabled` (SoundEngine.swift:106); toggle em SettingsView.swift:312 e na ilha IslandRootView.swift:578 |
| a11y-reduced-motion-check | **falha** | SoundEngine.swift:105-113 nunca lê `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion`; ver follow-up 1 |
| a11y-volume-control | ok | slider 0 a 0,2 em SettingsView.swift:316 → `AppState.soundVolume` (AppState.swift:273-276) → `SoundEngine.volume` (SoundEngine.swift:11-13) |
| appropriate-no-high-frequency | parcial | hover, open e close (IslandWindowController.swift:561, :604, :606) agora são mudos; WhatsAppController.swift:575 limita a 1 som a cada 4 s (bom exemplo); **FileDropView.swift:100** toca `tick` a cada 10 % de um upload (até 10 ticks seguidos); `finish` dos pollers (N8nPoller.swift:239, VercelPoller.swift:95, StripePoller.swift:144) não tem limite de rajada |
| appropriate-confirmations-only | ok | `approve`, `finish`, `pop`, `proud`, `send`, `gulp` só depois de uma ação concluída |
| appropriate-errors-warnings | ok | `error`, `approval`, `question`, `rate` (§4) |
| appropriate-no-decorative | ok com a v2 | hover/open/close/yawn/sleep mudos; `wink` e `dizzy` têm som, mas o Mac não os toca (BotEngine.swift:61 `BotStateCfg.sound` nunca é lido; o emote wink não chama som) |
| appropriate-no-punishing | ok com a v2 | `annoyed` (BotEngine.swift:444, :857) mudo; `error` é o `boop-down` de ataque lento |
| impl-preload-audio | ok | `preload()` no `init` (SoundEngine.swift:18-19, 49-66), 3 players por som com `prepareToPlay()` (:68-78) |
| impl-default-subtle | ok | volume padrão 0,12 (AppState.swift:273, SoundEngine.swift:11); arquivos a -4 dBFS → -22,4 dBFS ouvidos |
| impl-reset-current-time | ok | `player.currentTime = 0` antes de tocar (SoundEngine.swift:110) |
| weight-match-action | ok | §4: ticks para marcadores, chirps para confirmações, `chime-rise` só para o What's New |
| weight-duration-matches-action | ok | todos entre 50 e 400 ms, exceto `greeting` (2,26 s para uma saudação de 4,6 s, desvio documentado) |

Outros achados: `SoundEngine` não tem reprodução em loop (só `play` e `fadeOut`, SoundEngine.swift:92-113). Os sons de estado
`think`, `search`, `sleep` e `dizzy` estão declarados em `BotStates` (BotEngine.swift:112, :119, :161, :168) mas o Mac só toca os de
estado que o HookServer chama direto; o protótipo toca todos (`core.js`:270).

### Protótipo (`features/sounds.js`)

| Regra | Estado | Evidência |
|---|---|---|
| a11y-visual-equivalent | ok | só toca em `onSound`, chamado por `bot.sound()` nas mudanças visíveis (core.js:270, :298, :310; slap.js:15; gulp.js:39; voice.js:30) |
| a11y-toggle-setting | ok | toggle "Som" (sounds.js:52) checado em `play` (:17) e em `wanted` (:43) |
| a11y-reduced-motion-check | ok | `matchMedia('(prefers-reduced-motion: reduce)')` (:14) checado a cada som e a cada quadro (:17, :43); a mudança ao vivo cala tudo (:45) |
| a11y-volume-control | ok | slider 0 a 0,2 como o do app (:54), vale para os sons novos e para o loop tocando |
| appropriate-no-high-frequency | ok | as minis não soam (:49); um loop por vez (:34-42); página escondida fica quieta (:46) |
| appropriate-no-decorative | ok | "Som ambiente" desligado por padrão (:13, :53) |
| impl-preload-audio | ok | os 29 sons (2 players cada) e os 4 loops carregam no início (:16, :27-32) |
| impl-default-subtle | ok | volume 0,12 (:13), o do app |
| impl-reset-current-time | ok | `currentTime = 0` em todo play (:18, :37); cada loop começa do início |
| capturas mudas | ok | nada é criado nem tocado com `Clock.virtual` (:16, :17, :27, :50) |

## 11. Follow-ups para o app (recomendações, não implementadas)

1. **Reduced motion:** em `SoundEngine.play`, `guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion` (o mesmo vale para
   os loops).
2. **Loops no `SoundEngine`:** copiar `design/konclui/sound/loops/*.wav` para `Resources/sounds`, um `AVAudioPlayer` por loop com
   `numberOfLoops = -1` (PCM emenda sem pausa; `AVAudioPlayerNode.scheduleBuffer(_:at:options: .loops)` é exato à amostra), iniciado e
   parado em `BotEngine.setState` (BotEngine.swift:314) atrás de um ajuste novo "Som ambiente", desligado por padrão. Parar quando a
   ilha esconde (regra de 0 % de CPU), quando o som é desligado e com reduced motion; volume = `soundVolume`; sair com o `fadeOut`
   existente (~150 ms).
3. Tirar o `tick` a cada 10 % do upload (FileDropView.swift:100): o gulp e o `approve` do fim já dizem "recebido".
4. Limitar `finish` em rajada dos pollers (um por 4 s, como WhatsAppController.swift:575).
5. Não ligar `BotStateCfg.sound` no Mac: `think` e `search` seriam frequentes demais; os loops opt-in cobrem esses estados.

## 12. Limites conhecidos

- Ninguém ouviu ainda: a v2 foi validada por medição (port exato, harmônicos apenas, energia acima de 4 kHz ≤ 1,7 %, picos, emendas),
  não por escuta. Ouça `design/konclui/sound/preview.m4a` ou os botões "Sons" e "Loops" do protótipo.
- No Chrome headless o `decodeAudioData` de AAC não resolve (um WAV resolve em 8 ms), então o caminho Web Audio dos loops foi provado
  com Web Audio simulado; num Chrome normal ele decodifica no início. Se não decodificar, o fallback `<audio loop>` toca (com a pausa).
