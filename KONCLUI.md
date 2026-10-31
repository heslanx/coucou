# Koncluí

Koncluí is a fork of [Coucou](https://github.com/Louis-CFM/coucou) by Louis Raillé, for the Mac
only for now. Coucou's code is under the MIT licence (`LICENSE`, kept as is); its name, Mochi,
icon, sounds and artwork are reserved by their author (`LICENSE-ASSETS.md`), so Koncluí replaces
them: the name Koncluí, the character Koru, the icon and the sounds are Koncluí's own.

## Rules for everyone working on Koncluí

- [docs/konclui/UX.md](docs/konclui/UX.md): usability, microcopy, accessibility, the review gate and the UI polish pass.
- [docs/konclui/ENGINEERING.md](docs/konclui/ENGINEERING.md): code rules and how to stay mergeable with upstream.
- [docs/konclui/WORKFLOW.md](docs/konclui/WORKFLOW.md): branches, remotes, pull requests, Coucou syncs, pushes and releases,
  with the commands; why it is so: [ADR-001](docs/konclui/decisions/ADR-001-branches-and-flow.md).

## Where Koru is going

[docs/koru](docs/koru/README.md) records the proposed operational assistant for business owners, managers,
operators and the Koncluí team: MCP integrations, workspace AI credits, device-specific experiences, real-time
voice and gamification research. It keeps product direction apart from what this app and the prototypes already do.

## What changes

- The Mac app (target `NotchBuddy`, scheme `NotchBuddy`) builds as `Konclui.app`, bundle id
  `com.konclui.mac`, display name Koncluí. Debug signs ad hoc (`-`, no Apple team), so it builds
  and runs on any Mac.
- Every text a user sees says Koncluí (the app) and Koru (the character, female: "a Koru" in
  Portuguese, "Koru" with no article in French). The voice wake word is "OK Koru".
- No coffee button: Coucou's What's New asked for a coffee that went to its author. Koncluí
  removes the button, its two strings and the 0.5.3 item. Coucou and Louis Raillé are credited
  here and in `LICENSE`.
- The Koncluí window's sidebar header (FlowHub) shows the Koncluí wordmark (`Assets.xcassets/KoncluiLogo`, a vector
  template image made from the brand's `konclui-partner/brand/logo-konclui.svg`, filled black so
  it takes the text colour) instead of the app name in the system font.
- Koru is drawn in code in new files (`CoucouKit/Koru*.swift`); the sounds are synthesized by
  `scripts/konclui/sounds.py` under the same file names.
- Internal names stay Coucou's: targets, schemes, file names, Swift types (`Mochi*`, `Coucou*`),
  UserDefaults keys, Keychain account names, the hook protocol fields (`coucou_kind`…). That keeps
  upstream merges small.
- The notch chat can run through what the Mac is already signed in to, with no API key stored in Koncluí. Settings →
  Chat → Coucou's "Your AI subscriptions" has one switch per AI (Claude, Gemini, ChatGPT, Cursor, Copilot). With it on,
  the AI is answered by Koncluí's `KoncluiChat`, one engine with one adapter per CLI (`KoncluiChatAdapters.swift`:
  `claude`, `codex`, `agy` or `gemini`, `cursor-agent`, `copilot`): a new message, Clear or Quit stops the running CLI
  and its helpers, and so does picking another provider; the answer streams as it is written and the CLI keeps the
  thread while it holds the whole visible conversation (else a new one starts with it), except Copilot, which keeps
  Coucou's relay format (the whole conversation each turn, plain text); the row says whether Claude Code, Codex or
  Cursor is signed in and with which plan (`KoncluiSignInLine`). Once the conversation holds email or a dropped
  file, only a tool that can turn its web off answers (Gemini CLI rather than Antigravity), else the turn is refused;
  Coucou's relay (`CLIRelay`) no longer runs a CLI. The Koncluí Proxy (the Anthropic Messages API behind klaude,
  with klaude's own key) is Koncluí's own provider, in `KoncluiProxySection` under Coucou's box. The model picker lists
  a provider once it has a key or its switch is on with its tool installed. Why:
  [ADR-008](docs/konclui/decisions/ADR-008-chat-subscriptions.md), [ADR-009](docs/konclui/decisions/ADR-009-chat-cli-engine.md).
- Sessions of agents that run in Orca's terminals (Claude Code, klaude, Codex, Gemini…) show on their own
  Orca pill (`agent_orca`), and a click on it brings that session's own terminal forward. klaude, which
  runs Claude Code with its own config folder (`~/.klaude`), gets Koncluí's hooks too: Settings → Agents
  has a klaude block (shown only when `~/.local/bin/klaude` or `~/.klaude` exists).
- Settings → Integrations → WhatsApp is one calm line when connected (status, the number written as "+55 11 91234-5678",
  the gateway version) with an "Options" popover for the daily options, ignored chats, the update, privacy and the
  advanced gateway; setting up (install, QR, a failed install) expands in place as a card and a stopped gateway adds its
  panel. A live preview of the notch sits on top and follows the options (sample conversations through the real inbox
  rules, nothing real, nothing clickable). "Install WhatsApp" also turns the integration on. The number and the ignored
  chats are doors (a popover to open the chat or copy the number or the id), the line and the tags show the pointing hand,
  and what changes data offers Undo for ten seconds (ignore, stop ignoring, saving the gateway, switching WhatsApp off).
  Files: `App/KoncluiWhatsAppModel.swift` (pure rules, `scripts/konclui/test-whatsapp-preview.sh`),
  `KoncluiWhatsAppSection.swift`, `KoncluiWhatsAppPreview.swift`; design: `design/konclui/whatsapp/whatsapp-settings-10.html`
  (versions 8 and 7); rules: `docs/konclui/UX.md`. There is no "update available" notice: nothing in the app knows a newer
  gateway exists without a network call the user did not configure, so "Update gateway" stays inside the popover (it
  downloads the latest, as before).
- "OK Koru" needs no API key. By default the words are understood on this Mac: the phrase parser first, then Apple
  Intelligence for what it does not know. Claude answers open questions and searches the web only when the person turns it
  on in Settings → Voice ("Claude answers open questions and searches the web", off by default), through the Koncluí Proxy
  (the subscription behind klaude) when klaude is set up, else through the Anthropic key of Settings → Chat. Settings →
  Voice says who understands you now and what that means for privacy, and says why "Enable voice command" is greyed out.
  The routing is `App/KoncluiVoiceBrain.swift` (pure, `scripts/konclui/test-voice-brain.sh`); the live inputs and the proxy
  call are `App/KoncluiVoiceBrainLive.swift`; the Settings view is `App/KoncluiVoiceBrainSection.swift`.
- The Notetaker records a call without any download. On macOS 26 it transcribes with Apple's on-device
  `SpeechAnalyzer` + `SpeechTranscriber` (the Mac's language, English when the Mac's is not supported); if the language
  files are missing, `AssetInventory` installs them while the call is recorded, with progress in the Notetaker screen
  (the live lines start when they are there, the audio is kept and the transcript is written at Stop). Parakeet and the
  diarizer stay an optional upgrade ("more accurate, and tells each person on the call apart", about 650 MB): when they are
  installed the Notetaker works exactly as in Coucou. Without them the other people of a call are one speaker
  ("Person 2"); the Notetaker screen says so where Parakeet is offered. On macOS before 26 or an Intel Mac with no
  Parakeet, Record is blocked as before, with the reason beside it. Files: `App/KoncluiNoteSpeechChoice.swift` (the choice
  and the words, pure, `scripts/konclui/test-note-speech.sh`), `KoncluiNoteSpeech.swift` (the Speech framework),
  `KoncluiNoteSpeechState.swift` (the glue), `KoncluiNoteSpeechCard.swift` (the engine row under Record and its popover).
- Settings → Agents is one calm row per agent (Claude Code, Claude Desktop chats, klaude, Gemini CLI, Antigravity, Codex, Copilot
  CLI, Muse Code, OpenCode, Amp, Hermes, the plan gauges): the agent's colour dot, its name, its status in words ("Hooks
  instalados", "Hooks não instalados", "Hooks desatualizados", "Plugin instalado", "Ativado", "Precisa de permissão") and a
  chevron. The whole row opens a subtle popover that holds the agent's old block unchanged: the path line, Install, Uninstall,
  the JSON preview, "Confirm and write", Cancel (Uninstall stays the undo of Install). The result or error of the last action
  shows at the bottom of that popover (the window's bottom line is hidden meanwhile, so it is not said twice), and the row's
  words change at once after an install. On Active pills, "Hooks not installed" / "Plugin not installed" beside Gemini
  CLI, Antigravity, Codex, Copilot CLI, Muse Code, OpenCode and Amp is a door: it opens a popover with one line on what the
  install does and "Install hooks" (or "Install plugin"), then the same preview and "Confirm and write" through the Agents
  page's own state; installed, the hint is gone. Files: `App/KoncluiAgentRows.swift` (pure: the words, the doors, the
  DEBUG flag; `scripts/konclui/test-agent-rows.sh`), `App/KoncluiAgentRow.swift` (`KoncluiAgentRow`,
  `KoncluiHookDoorPopover`). DEBUG only, for screenshots: `-konclui.debug.agentPopover <id>` (`claudeCode`, `claudeDesktop`,
  `gemini`, `antigravity`, `codex`, `copilot`, `muse`, `opencode`, `amp`, `hermes`, `plan` or `klaude`) opens that popover and
  shows the row even without the agent on this Mac (on Active pills it opens the door of that agent when its hint shows);
  `<id>:preview` also builds the install preview in it. The flag reads and previews only: it never writes a hook file.
  The klaude block, `KlaudeHooksSection` (`KoncluiAgentHooks.swift`), was deleted: `KoncluiKlaudeHooksSection`
  (`KoncluiKlaudeRow.swift`) replaces it.
- **One design system for the hub window.** `App/KoncluiTheme.swift` (tokens, type roles, the hub's buttons, GroupBox, Toggle, status,
  key cap and field) and `App/KoncluiThemeCore.swift` (the numbers, tested by `scripts/konclui/test-theme.sh`): one gutter of 28 pt so
  every page lines up with its header card (the Notetaker's "Gravar uma chamada" included), text that passes 4.5:1, one primary look
  (ink on mint, 15:1), a disabled button that never looks enabled, switches in one column, a status drawn one way, Reduce
  Motion, Increase Contrast and Reduce Transparency honoured. The notch pages' header is the compact band pinned over the scroll
  view with macOS 26's soft scroll edge (the window's only glass; macOS 15 to 25 get a fade). Every page's band is alive
  (particles, a breathing glow, the light under the pointer); the glow cards inside pages stay still. The rules are in UX.md section 11.
- **The design system's colours.** The window wears konclui-platform's dark navy family with mint as the one accent, and its
  background is the Painel Gestor's sidebar (navy, ink, deep teal at -160° with the mint glow, `KoncluiBrandBackdrop`) under
  the website's grain (`KoncluiGrain`, also on the pages' bands and the reminder's card). The notch keeps its black: it has to
  disappear into the hardware notch.
- Every word on screen follows `docs/konclui/UX.md` section 5 in all 16 languages: no dashes as punctuation, one name per
  concept (notch, aba, Ajustes do ditado, Ajustes do Sistema, gateway), paths written with "›", macOS permission prompts that
  say what the app does with the permission and are localized (`NotchBuddy/Resources/InfoPlist.xcstrings`).
- **The notch pages behave.** Every agent's popover (Settings → Agents, the "Hooks not installed" door of Active pills, klaude)
  is one component, `KoncluiHookControls`: the state in a sentence, the one primary that state needs (Install when nothing is
  installed, Update when outdated, none when fine), Uninstall as the quiet button once there is something to take back, and a
  review before anything is written that shows only the lines Koncluí adds or removes ("Koncluí will add its entries (13) to
  ~/.claude/settings.json. The other 2 stay as they are."), the whole file behind "Ver o arquivo inteiro". The path is a detail
  (Details: Show in Finder, Copy path). Claude Code's removal is previewed and confirmed like its install (it wrote at once).
  What Koncluí wrote is read once, off the main thread (`KoncluiHookStatus`), not from the agents' files at every redraw.
  Active pills: a switch blocked by the 4-tab limit says so and offers "Desligar" for the tabs that can free a place; the colour
  dot is a door (ring, pointing hand, tooltip, VoiceOver). "Adicionar…" sits at the page's outer edge on all four lists.
  Geral: the demo is first only while nothing is connected, then a quiet button at the end; the open/close hotkey has one
  switch (Atalhos); the updater is behind a flag that ships off; a card "Conecte seus agentes" names the agents found and
  not connected; "Remover integrações…" previews and removes every file Koncluí wrote. Reminders is a page of the window.
  Orca has its own row; its approvals ship on (see Functional ties, "Orca approvals").
- "OK Koru" listens, understands and answers in Brazilian Portuguese. Settings → Voice → Language offers
  Português next to Français and English, in both pickers ("Você fala", "Koncluí responde em"). Until the person picks
  one, Koru answers in the Mac's language when it is Portuguese, French or English (`VoiceLanguage.macDefault`).
  Automatic listening already follows the Mac's dictation languages, so Portuguese comes first on a Brazilian Mac.
  The phrase parser reads natural Brazilian phrasings (tabs, music, volume, apps, questions about the services,
  weather, e-mail, web search, several commands in one sentence; accents never matter), the spoken answers exist in
  Portuguese for every topic, the Apple Intelligence and Claude prompts answer in pt-BR, and the Mac voice is chosen
  region first (Luciana or Felipe, never a premium voice from Portugal). The wake word stays "OK Koru"; the
  recognizer's Brazilian spellings of it ("okei Kôru") are accepted too.
  Files: `App/KoncluiVoiceLanguage.swift`, `App/KoncluiVoicePhrases.swift`, `App/KoncluiVoiceParserPT.swift`,
  `App/KoncluiVoicePrompts.swift`; tests `scripts/konclui/test-voice-pt.sh`; coverage check
  `scripts/konclui/voice-pt-templates.py`.
  How it stays mergeable after an upstream merge:
  Upstream says every answer as `t("<French>", "<English>")` with a two-way `Bool`. The wide change (a third argument at
  about 100 call sites) was not made. `t` now takes `VoiceText`, a string-interpolation type that remembers the English
  sentence with a `{}` for each `\( )`; French and English render exactly what is written at the call site (byte for
  byte), Portuguese is looked up by the English sentence in `KoncluiVoicePhrases.table`. The call sites are upstream's
  lines, untouched. A sentence upstream adds or rewords has no Portuguese until someone writes it, and is said in English
  meanwhile; `scripts/konclui/voice-pt-templates.py --check` finds it (it also runs first in `test-voice-pt.sh`).

  The parser is the same idea: `KoncluiVoicePT.parse` answers nil unless a Portuguese word is in the phrase, so French and
  English reach upstream's tables unchanged, and nothing of upstream's tables is edited.

  ### After `git merge upstream/main` (voice files)

  1. Conflicts in `App/Voice/*`, `ClaudeService.swift`, `IslandWindowController.swift`: take upstream's side of the
     hunk, then re-apply the marked hooks listed below (`grep -rn "Koncluí" NotchBuddy/Sources/App/Voice` finds them;
     each is one to five lines).
  2. `python3 scripts/konclui/voice-pt-templates.py --check`. For each sentence it lists, run `--missing`, paste the
     lines into the table in `KoncluiVoicePhrases.swift` (the French is printed next to the English), write the
     Portuguese (`{1}`, `{2}`… are the values in the order of the English `{}`), run it again until it reports 0 problems.
  3. `./scripts/konclui/test-voice-pt.sh`, the 12 `scripts/test-voice-*.sh`, `scripts/test-conversation-context.sh`,
     `scripts/test-turn-end-policy.sh`, `scripts/konclui/test-voice-brain.sh`. A voice test script that upstream adds and
     that compiles `IntentParser`, `VoiceQuery` or `VoiceActionRunner` needs the three pure files on its `swiftc` line
     (`KoncluiVoiceLanguage.swift`, `KoncluiVoicePhrases.swift`, `KoncluiVoiceParserPT.swift`).
- **Claude for dictation and call notes without an API key.** "Limpar com o Claude", "Modo prompt", "Traduzir para" and the
  Notetaker's Claude summary and transcript correction reach Claude through the Koncluí Proxy (the subscription behind klaude)
  when klaude is set up, else through the Anthropic key of Chat. Clean-up (not the others) falls back to Apple Intelligence on
  the Mac. The order is one pure rule (`App/KoncluiClaudeAccess.swift`, tested by `scripts/konclui/test-claude-access.sh`); the
  sending is `App/KoncluiClaudeSender.swift`; the live inputs, the failure notice and the Apple route are
  `App/KoncluiClaudeLive.swift`. Dictation keeps the fast model (haiku) and its timeouts (4 s clean-up, 8 s translation, 12 s
  prompt). When a call fails the words are still pasted as heard, and the pill now says once per streak what failed and what to
  do (A3-27); `KoncluiClaudeLive.shared.lastFailure(_:)` keeps the last one per feature for the Settings pages. The klaude token
  is read from the Keychain item `klaude-api-key` for each call, held in one local variable and never stored, logged or shown;
  a failure keeps its HTTP status only, never a body.
  `scripts/konclui/claude-live-check.sh` makes one real clean-up through the proxy ("eh tipo assim né vamo testar" becomes
  "É tipo assim, né? Vamos testar.") and prints only the words, the source, the model and the time.
  DEBUG: `-konclui.debug.claudeFail <kind>` shows a sample clean-up failure on the pill 1.5 s after the first page reads the source (the
- **The Flow pages answer every click.** Every removal on Ditado, Dicionário, Trechos, Estilos and Ajustes do ditado offers Undo for ten
  seconds (`App/KoncluiUndo.swift`: one bar and one center shared with the WhatsApp block). Ditado, Estatísticas, Dicionário and Trechos
  never promise "Segure ⌥" while dictation is off: they say how to turn it on and the empty states end in that button. Every number in
  Ditado and Estatísticas opens the days behind it (`App/KoncluiStatDoor.swift`), and words per minute reads "indisponível" until there is
  a dictation to measure. Estilos lists the apps this Mac has (under the name this Mac gives them, plus Orca, Warp and Ghostty once, when
  installed), explains each style in the popover of its picker, and disables the per-app list, with the reason beside it, while the
  clean-up is off. Ajustes do ditado shows the Accessibility permission only while dictation is on and macOS does not trust Koncluí, and
  advises "remove and add again" only when macOS once trusted it. The dictation keys stay in Ajustes do ditado and link to Atalhos.
  DEBUG: `-konclui.debug.page <dictation|insights|dictionary|snippets|styles|settings>`; `-konclui.debug.dictation  off | access | access-stale | ready`; `-konclui.debug.flow-data  empty | sample`.
- **The last hand-offs, wired.** Estilos and Ajustes do ditado read the Claude source the way the dictation does
  (`KoncluiClaudeLive`): the clean-up switch counts Apple Intelligence (`FlowCleanup.canClean`), prompt mode and translation need
  Claude (`hasKey`), the privacy lines and the Notetaker's sentence say where the words go for the source that answers now
  (subscription, key or this Mac), and a Mac with nothing to ask shows one line with "Abrir Chat" that adds the Anthropic key block
  first, so the person lands on the field (A1-03, A3-10). The last failed call of each feature stays under its switch until a call
  succeeds, in words that fit the feature: the dictation sentences say the words were pasted as heard, the Notetaker's (summary,
  correction) say the notes of the call were left as they were (A3-27). Undo reaches the Atalhos reset, the weekly recap clear and a
  deleted line of a call. Atalhos lists the dictation keys (read-only, linking to Ajustes do ditado); every shortcut is one key cap,
  the recorder included. In Voz the voice rows share the Language box's label column. Saving an API key (Chat, ElevenLabs,
  Integrações) says so when the Keychain refuses it, instead of "Key saved" (A3-28). The voice proxy has one deadline of 10 s for a
  whole turn across its models and its retry, raced against the clock (A3-29). The agent popovers and rows use the hub's card,
  `KoncluiStatus` and the type roles.
  DEBUG: `-konclui.debug.claudeSource none | proxy | key | apple` (what the Claude lines think this Mac has); `-konclui.debug.claudeFail <kind>` now shows under every switch; `-konclui.debug.keychainFail 1` makes every key save answer "refused".
- Out of scope for now: the iPhone app and its extensions, Windows/Linux (`windows/`), Android,
  the docs site and the relay.

## How the rebrand is applied

All brand text comes from one re-runnable script, `scripts/konclui/rebrand.py`. It rewrites:

1. `NotchBuddy/project.yml`: the Mac targets' names, the GitHub build's bundle id and product
   name, its ad hoc Debug signing; then runs `xcodegen` (Info.plist files and the project).
2. Fixed edits for the functional ties below, in Swift sources and `scripts/coucou-mcp.py`, the
   wake word, and the removal of the coffee button.
3. The string literals of the Mac Swift sources (`App/**`, `CoucouKit/**`; not the character
   drawing files, not comments).
4. Upstream tests that name Coucou's ids, URLs and wake word (`tests/MacUpdateTests.swift`,
   `WhatsNewTests.swift`, `ClaudeHookDetectionTests.swift`, `WakePhraseTests.swift`), plus cases
   for the fork: Coucou's hooks are not Koncluí's, "OK Coucou" does not wake Koncluí.
5. `Localizable.xcstrings` (the coffee keys removed): keys (with the Swift literals that use them) and values in all 16
   languages, with per-language grammar for Koru (articles, pronouns, agreement in en, es, fr,
   pt-BR, de, ru).
6. `whats-new.json`: the item texts (the coffee item removed).
7. The copy rules (`scripts/konclui/rebrand_copy.py`, data in `rebrand_copy_data.py`), run by `rebrand.py` after the brand pass:
   COPY, SUBS, FILL, DASHES and PATHS over `Localizable.xcstrings` (one rewritten entry keeps its style; nothing else in the file
   moves), the Info.plist usage descriptions (project.yml English through FIXED, 16 languages in `InfoPlist.xcstrings`, which
   rebrand.py keeps equal to the table and adds to the Mac target's resources), and FIXED edits for hard-coded English literals of
   upstream views. A rule whose upstream English changed is reported STALE and not applied. `python3 scripts/konclui/test-copy.py`
   checks the result (glossary, dashes, format arguments, prompts).

It is idempotent: a second run reports `0 files changed`. `--check` changes nothing and exits 1
when a run would change something. A rule whose old and new text are both gone is reported as
`STALE`: upstream changed that code and the rule needs a look.

`./scripts/konclui/test-hooks.sh` checks that Koncluí's hook handling never claims Coucou's
entries (no settings file is read or written).

Day to day: `./scripts/konclui/dev-install.sh` builds Debug and installs `/Applications/Konclui.app`
(it never touches `Coucou.app`).

## Upstream workflow

Branches, remotes, pull requests and releases: [WORKFLOW.md](docs/konclui/WORKFLOW.md). Upstream comes in on a
`sync/upstream-<date>` branch from `main` of `konclui/konclui-notch` ("Coucou updates" there), then:

```
git fetch upstream
git merge upstream/main
scripts/konclui/sync-remerge.sh       # each conflicted file merged again with the brand on both sides; the catalog by key
# what is left is a Koncluí hook next to an upstream change: keep both, by hand. Never `git checkout --theirs` a file
# that has hooks (the table below lists them): the hooks go with it. Then `git add` each file.
python3 scripts/konclui/rebrand.py    # re-applies everything, runs xcodegen
python3 scripts/konclui/rebrand.py --check   # 0 files would change, 0 stale rules
python3 scripts/konclui/voice-pt-templates.py --check
cd NotchBuddy && xcodebuild -scheme NotchBuddy -configuration Debug build
```

Then every suite (`scripts/test-*`, `scripts/konclui/test-*`). A suite that cuts code out of an upstream file between two
marker lines (`test-konclui-orca.sh`) or matches its text (`KoncluiPageRulesTests.swift`) follows the moved code. A switch
over `ChatProvider` or `HubPage` that upstream adds needs Koncluí's cases: the build says where. The 2026-10-31 sync
(Coucou 0.5.8, 205 commits, 14 files in conflict) is the worked example: its merge commit says how each was resolved.

New upstream strings that mention Coucou or Mochi are rebranded by the next run, in every language: the names are
matched without `\b`, so a Korean or Japanese particle written right after one ("Coucou를") does not hide it, and a
local spelling (모찌, Мочи) goes in `NAMES_LOCAL`. A new string
where Koru needs a feminine form (an adjective or pronoun that pointed at Mochi) needs a rule in
`AGREEMENT` of `rebrand.py`.

## Functional ties

Places where the name, or Louis's identity, does something. Changed when users see it or when
Koncluí and an installed Coucou would clash running side by side; kept otherwise.

| Tie | Where | Koncluí | Why |
|---|---|---|---|
| Bundle id | project.yml, `AppState` fallback | changed: `com.konclui.mac` | separate product; also gives Koncluí its own UserDefaults domain, TCC entries and notifications |
| Product / executable name | project.yml `PRODUCT_NAME` | changed: `Konclui` (`Konclui.app`) | ASCII file name, no clash with `Coucou.app` |
| Display name, usage descriptions | project.yml → Info.plist; `InfoPlist.xcstrings` | changed: Koncluí; the seven prompts say what the app does, in 16 languages | users see them; people decide on trust from these lines |
| Application Support folder | `HookServer.supportDir`, `RecapStore`, `SoundEngine`, GOWA dir, Reminders MCP path | changed: `~/Library/Application Support/Konclui` | holds the hook socket, hook scripts, notes, models, sounds: shared, the two apps would fight over the socket |
| Hook socket | `<support>/nb.sock`, nb-hook.py, `coucou-mcp.py` | changed (follows the folder) | Coucou binds its own |
| Mail plans folder | `MailAgent.swift` (a `rebrand.py` FIXED rule) | changed: `$TMPDIR/konclui-mail-plans` | the agent empties it when it starts: with Coucou's name the two apps would delete each other's attachments |
| Logs folder | `AppLog`, `InstructionRunner` | changed: `~/Library/Logs/Konclui` | the two apps would write the same logs |
| Keychain service | `Keychain.service` (ClaudeService.swift) | changed: `com.konclui.mac` | otherwise Koncluí reads and overwrites Coucou's API keys |
| Claude Code hook command | `<support>/nb-hook`; ownership test `contains("Konclui"/"konclui")` | changed | Koncluí installs, detects and removes only its own hooks in `~/.claude/settings.json` |
| Copilot, OpenCode, Amp, Hermes, Antigravity hook files | `~/.copilot/hooks/konclui.json`, `plugins/konclui.js`, `plugins/konclui.ts`, `~/.hermes/plugins/konclui/`, `"konclui"` key | changed | Coucou writes `coucou.*`; one would overwrite the other |
| Hermes approval transport | `transport: konclui` | changed | follows the plugin name; Hermes has one approval transport, whichever app installed last |
| Gemini, Codex, Muse, Copilot hook entries, Claude status line | every "is this entry ours?" test in `HookServer` goes through `KoncluiHook.owns` (`App/KoncluiBrand.swift`): the command must run `konclui/nb-hook` (`…/Application Support/Konclui/nb-hook` or `~/.claude/konclui/nb-hook`) | changed | both apps write `nb-hook` entries into the same files; Koncluí now detects, replaces and removes only its own, and Coucou's stay as they are. The status line has one slot: Koncluí keeps Coucou's as its "previous" command and runs it after relaying, and puts it back on uninstall. Coucou itself still matches any `nb-hook`, so installing or removing Coucou's status line from Coucou can drop Koncluí's |
| Antigravity, OpenCode, Amp, Hermes plugin contents | `content.contains("nb-hook")` inside Koncluí's own files and `"konclui"` key | kept | the files and key are already Koncluí's alone |
| MCP server name | Reminders settings, `scripts/coucou-mcp.py` | changed: `konclui-reminders` | users add it to their MCP client next to Coucou's; file name `coucou-mcp.py` kept |
| Codex app-server client name | `CodexPlanGauge` | changed: `konclui` | Codex sees who asks |
| WhatsApp gateway device/session | `WhatsAppProvider` | changed: `konclui` | users see it in the gateway; separate device from Coucou's |
| GOWA port / webhook port | Settings (`127.0.0.1:3000`, webhook port) | kept | user setting; with both apps on, give one of them other ports |
| MacUpdater | `MacUpdate.service/bundleId/teamId/tagPrefix`, asset `Konclui.zip`, `WhatsNew.releasePage` | changed: Koncluí's update service `https://updates.konclui.com` (in front of the private `konclui/konclui-notch`, ADR-002), `com.konclui.mac`, team `5M8RG3BCX2`, tags `konclui-vX.Y.Z`, the service's notes page | only Koncluí's releases: a Coucou tag (`v0.5.6`) or Louis's team never passes. `scripts/konclui/release.sh` publishes; WORKFLOW.md "How the app finds and installs an update" |
| Weekly recap watermark | `WeeklyRecapView` | changed: `Koncluí · github.com/heslanx/coucou`, `konclui-weekly-recap.png` | users share it |
| Wake word | `WakePhrase` patterns and spellings, `WakeSpotter` hints, `VoiceQuery` fillers, every label | changed: "OK Koru" / "hey Koru" (also "ok coru", "corú", "koroo", "kourou", "ko ru"…); "OK Coucou" no longer wakes Koncluí | the two apps never answer the same phrase |
| iCloud container, CloudKit zone, Live Activity relay | `iCloud.fr.louisraille.Coucou`, zone `Coucou`, `coucou-relay.raillelouis.workers.dev` | kept | iPhone link, compiled only with `PHONE_LINK` (DebugCloud/Release); out of scope until Koncluí has its own container and relay |
| App Store build | target `CoucouAppStore`, `fr.louisraille.Coucou`, container socket | kept (display name changed) | not built for Koncluí |
| Signing team, profiles | DebugCloud / Release / ReleaseCloud (`256AUJ9555`, "Coucou Developer ID") | kept, marked in project.yml | need Koncluí's own team, profile and container; `scripts/konclui/release.sh --check` refuses a release until Release signs with `5M8RG3BCX2` |
| URL schemes | none on the Mac app (`coucou://` is the iPhone app's) | — | — |
| Launch at login | `SMAppService.mainApp` | nothing to change | per app |
| UserDefaults keys, notification ids, queue labels, `CoucouGitHash`, NSError domain `CoucouNoop` | many | kept | internal, scoped to the app's own domain or process |
| AppleScript / Apple events | `tell application id "com.apple.Music"` etc. | nothing to change | no Coucou name involved |
| Chat provider `konclui-proxy` | `ChatProvider` (CoucouKit/IslandTypes.swift), UserDefaults `chatProvider` | added; the raw value is stable. Pill id `ai_konclui_proxy` is reserved in `ChatProvider.pillID` (no catalog pill yet). `claude-code` and `codex` (2026-10-30 to 10-31, never released) became Anthropic and OpenAI with the subscription switch on: `KoncluiChatMigration` rewrites a stored choice at launch | the chat provider is persisted |
| Claude Code / Codex login | `KoncluiChat.swift`, `KoncluiChatProcess.swift` | the official `claude` / `codex` run as subprocesses (`claude -p … --safe-mode`; with `--setting-sources ""`, `--strict-mcp-config`, `--disable-slash-commands` on every run; `codex exec --json` with `--ignore-user-config`, `--ignore-rules`, hooks, shell, apps, plugins and web search off, `sandbox_mode="read-only"`, `-m` the top-level model of Codex's `config.toml`), prompt on stdin, in `~/Library/Application Support/Konclui/chat`; routing variables (`ANTHROPIC_*`, `CLAUDE_CONFIG_DIR`, `OPENAI_API_KEY`, `GEMINI_API_KEY`, `CURSOR_API_KEY`, `GH_TOKEN`…) are removed from their environment; once the conversation carries email (Mail on) or a dropped file, `claude` has no web tool, `claude` runs with `--no-session-persistence` and `codex` with `--ephemeral`, each turn carrying the conversation instead of resuming (ADR-009, "What stays on disk"), and a dropped PDF or image is read from an isolated copy, Read allowed only in that folder (`Read(//<folder>/**)`) | the CLIs keep their own credentials: Koncluí never reads their token files (their terms of use); a shell started from klaude or Orca must not send the subscription route elsewhere |
| klaude key | Keychain generic password, service `klaude-api-key`, account = user name | read when a request starts, with `/usr/bin/security … -w` as klaude does; presence checked without `-w`; kept in a local variable, never stored in Koncluí's Keychain items or UserDefaults, never logged, wiped from server error text | the key is klaude's, not Koncluí's |
| Koncluí Proxy address | `proxy_url=` in `~/.local/bin/klaude`; override: UserDefaults `konclui.proxyURL` | https only (http only for localhost) | network calls only to the proxy the user installed |
| Gemini CLI, Antigravity, Cursor, Copilot login | `KoncluiChatAdapters.swift`, `KoncluiChat.swift` | the official `gemini` / `agy` / `cursor-agent` / `copilot` run as subprocesses in the same chat folder (ADR-009): Gemini as Coucou's relay (plan mode, no extensions or MCP) with `--output-format stream-json`, `--resume` and a policy on every turn (`Konclui/gemini/chat-policy.toml`: no file tool, shell or `exit_plan_mode`; no web with outside text); Antigravity as the relay with `stream-json` and `--conversation`; Cursor in ask mode, prompt on stdin, `stream-json`, `--resume`, its config folder Koncluí's own (`CURSOR_CONFIG_DIR=Konclui/cursor`, the user's model carried over) and every read, write, shell and MCP tool denied there and in the chat folder's `.cursor/cli.json`, web search and fetch only without outside text, its chats removed from `Konclui/cursor` when the conversation is cleared and at launch; Copilot with the relay's command line; Cursor (also under `~/.cursor/projects`), Gemini and Copilot keep their sessions in their own stores even for a conversation with email or a dropped file (no switch, as with the relay), and Clear does not remove those; Cursor's sign-in is `cursor-agent about --format json` | the CLIs keep their own credentials; Cursor's ask mode alone reads the whole disk |
| Hooks during a chat turn | `claude --safe-mode`, `codex --disable hooks`; Cursor, Gemini CLI, Antigravity and Copilot have no per-run switch (the user's hooks run, as with Coucou's relay) | on | Koncluí's own hooks would show the chat as a session in the notch |
| Orca pill | `HookServer.processEvent`, `processPermissionRequest`, `processQuestionRequest` (`isOrcaSession`, first branch of the routing); `ClaudeHost.isOrca` / `orcaPillId` / `termPrograms["orca"]` | added: `TERM_PROGRAM=Orca` or bundle id `com.stablyai.orca` → `agent_orca`, for every agent kind that runs in the terminal, before the Codex / `coucou_agent` / Cursor / VS Code / terminal routes (those are unchanged for every other client) | one pill for what runs in Orca; approvals and questions of those sessions use the same pill so the queue still matches their events |
| Orca terminal in the hook payload | nb-hook.py `add_orca_context` (GitHub and App Store scripts) | added: `orca_terminal` (`ORCA_TERMINAL_HANDLE`) and `orca_worktree` (`ORCA_WORKTREE_ID`), when set | the click needs the handle; no other `ORCA_*` value is read, the hook token never leaves the terminal |
| Orca click | `TerminalTarget.activate` (`TerminalTarget+AppKit.swift`, one `if` for Orca's bundle id), `ClaudeHost.switchOrcaTerminal`, `OrcaTerminals` (`KoncluiOrca.swift`) | added: runs `<Orca.app>/Contents/Resources/bin/orca terminal switch --terminal <handle>` off the main thread (bare environment `HOME`/`PATH`, killed after 5 s), then activates Orca; no handle, or no CLI: only activates Orca | covers the pill click, the finished/error "Open terminal" buttons and ⌃⌥T; the handle is the one of the session that owns the pill's card (same owner rule as its name) |
| klaude hooks | `HookServer.previewClaudeHooks(at:install:)`, `writeClaudeHooks(at:)`, `uninstallClaudeHooks(at:)` (the `~/.claude` installer, now parameterized by settings path), `KoncluiAgentHooks.swift` (`KlaudeHooks`), `KoncluiKlaudeRow.swift` (`KoncluiKlaudeHooksSection`; the old `KlaudeHooksSection` was deleted) | added: the same 12 Claude Code hooks plus the AskUserQuestion one, installed into `~/.klaude/settings.json`; dated backup, merge, JSON preview, written only after the user confirms; Uninstall previews and removes only Koncluí's entries | klaude starts Claude Code with `CLAUDE_CONFIG_DIR=~/.klaude`, which never reads `~/.claude/settings.json` |
| "Is this Claude hook ours?" | `HookServer.buildHooksData(at:)`, `hooksDataWithoutKoncluiEntries(at:)` | changed: `KoncluiHook.owns` (command runs `konclui/nb-hook`) instead of "contains Konclui/konclui" | a foreign hook whose path only mentions konclui (for example under `~/Developments/konclui-project/…`) was replaced at install and deleted at uninstall |
| Claude opt-in | UserDefaults `voiceClaudeBrain` (`VoiceSettings.claudeBrainEnabled`) | now read by `ClaudeVoiceBrain.isActive` and set by Settings → Voice; off by default | the words leave the Mac only after the person turns it on |
| klaude key for the voice | Keychain generic password, service `klaude-api-key` | read with `KoncluiProxyAccess.readKey()` when a voice call starts, kept in a local variable, never stored, logged or shown; server error text is wiped of it; the logs hold the HTTP status only | same rule as the notch chat (K10) |
| Brain order | `KoncluiVoiceBrain.brain` | Claude (opt-in, subscription before key) > Apple Intelligence > phrase commands | owner decision D13: the lightest way is the default |
| Apple speech language files | `AssetInventory`, `SpeechTranscriber.installedLocales` (system-managed, outside Koncluí's folders) | installed on the first recording when missing; nothing is written to Koncluí's Application Support; `AssetInventory.status` answers "supported" for an installed language, so the installed list is asked instead | the Mac's own files, small, shared with other apps |
| Parakeet models | `Application Support/Konclui/Models` | untouched; the choice reads `Parakeet.shared.isReady` | installed models keep winning |
| Hub title inset | `HubHero` (`FlowHubMochis.swift`); audit items A2 (26 pt) and A1-06 (18 pt) | 18 pt, the card's own content inset | one inner edge for the title and the card's text |
| Canvas rate when the window is not the front one | `KoncluiMotion.rate`; audit items A2-09 (30 Hz) and A3-18 (pause) | 30 Hz | the window can sit beside another one, and a frozen Koru reads as a bug |
| "Gravar uma chamada" while dictation needs setup | `FlowHubHome.swift`; audit items A1-22 (secondary button while the setup card shows) and A2-08 (no setup card) | A2-08: the setup card is no longer drawn, the band's one primary is the setup | one primary per region; recording a call is the primary only when dictation works |
| Orca approvals | `KoncluiOrcaCards.showsInNotch(isOrca:otherTerminalsOn:)` (`KoncluiPageRules.swift`), UserDefaults `konclui.orcaCards`, used by `HookServer.processPermissionRequest` and `processQuestionRequest` | added: on by default for Orca sessions only (Koncluí's own key; the switch is in Agents → Orca); every other terminal keeps `terminalCardsEnabled`, off by default | the owner runs many agents in Orca, and their permission requests and questions wait in the notch for up to 2 minutes (answering in the terminal still works); every Warp or iTerm session would otherwise wait on the notch |
| Updater | `AppDelegate` (`MacUpdater.shared.start()`), the "Atualizações" block (`UpdateSettingsSection`), flag `block_updates` | ships off; the code and its fail-closed signature check are untouched | `MacUpdate` asks Koncluí's update service and `MacUpdater` verifies every download against Koncluí's team `5M8RG3BCX2`; there is no Developer ID, notarization or deployed service yet, so the flag stays off (A3-13) |
| Remove integrations | `KoncluiRemoveIntegrations` (end of Geral) | goes through the installers' own removal steps (preview, the same fingerprint check and dated backup, only Koncluí's entries), one file at a time, and says what happened to each file | UX.md 1.5 and CLAUDE.md: another app's settings file is never written without a preview and a confirmation |
| Key `hub.notch.reminders` | `Localizable.xcstrings`, `HubPage.reminders` | added with the owner's own key name (from the owner's main checkout), the one new key outside the `konclui.` namespace | the later merge of that checkout is a no-op; its catalog line has the key itself as the English text: replace it with this one |
| Answer language | UserDefaults `voiceLanguage` | "pt" is a third value; absent means the Mac's language (pt, fr or en), else English | "OK Koru" in Portuguese (the owner speaks pt-BR) |
| Listen language | UserDefaults `voiceListenLanguage` | "pt" is a fourth value (`auto`, `en`, `fr`, `pt`) | "OK Koru" in Portuguese (the owner speaks pt-BR) |
| Catalog `voice.*` strings | `Localizable.xcstrings` | untouched: the runner already read them in the answer language's lproj, and pt-BR was complete | "OK Koru" in Portuguese (the owner speaks pt-BR) |
| Button of the connect line (audit A1-03 and A2-19) | `KoncluiClaudeConnectLine`, `KoncluiClaudeLive.openChatForKey()`, key `hub.open-settings` | kept "Abrir Chat", the label the pill already uses; the click adds the Anthropic key block first | A1-03 asks for "Adicionar a chave do Claude" on the button and A2-19 for "Abrir Chat"; landing on the field is what both rows want |
| Estilos list while clean-up is off (audit A1-30 and A2-18) | `FlowHubWords.swift`, Estilos | U3b's choice kept: the list is disabled and dimmed, with the line beside it | A1-30 asks for full opacity plus one line, A2-18 for disabled plus one line |
| Weekly recap clear (audit A1-10) | `RecapStore.snapshotForUndo()`, `KoncluiUndoCenter.offer` (Settings, Clear history) | Undo, no dialog | A1-10 asks for a confirmation with the number; Undo does the same job without a dialog, as for the history clears |

## Feature flags

Every feature of Koncluí (a pill, a page of the window, a Settings block) has a local flag. A flag that is off
hides the feature's entry points: the pill leaves `PillCatalog.available` (Active pills, the notch, voice) and
the active pills, the page leaves the window's sidebar, the block leaves its Settings page. The code stays until
the feature is deleted for good (below). No network: nothing is fetched, nothing is sent.

- **Value** of a flag: the user's override (`konclui.feature.<id>` in the app's UserDefaults, a Bool) or, without
  one, what ships. What ships is a Swift table, `KoncluiFeatures.shippedOff` in `CoucouKit/KoncluiFeatures.swift`
  (everything not listed ships on). A table, not a bundled JSON: CoucouKit also builds into the iPhone targets, which
  have no resource bundle for it, a compiled-in table cannot be missing or malformed at run time, and the swiftc test
  reads it with no bundle. `KoncluiFeatures.isOn(_:)`, `set(_:_:)`, `reset(_:)`, `resetAll()`.
- **Ships off**: `integration_crypto`, `integration_calcom`, `integration_stripe`, `integration_github`,
  `integration_vercel`, `integration_n8n`, `integration_resend`, `integration_notion`, `integration_portfolio`,
  `block_updates`. Everything else ships on.
- **Why `block_updates` ships off**: it is the Settings block "Atualizações" (`UpdateSettingsSection`). `MacUpdate` asks
  Koncluí's update service (`updates/`, ADR-002; tags `konclui-vX.Y.Z`) and `MacUpdater` verifies every download against
  Koncluí's team `5M8RG3BCX2`, but the Developer ID, notarization and the deployed service do not exist yet: the block would
  promise updates nobody can publish. Turn the flag on once `scripts/konclui/release.sh --check` is ready and the first
  release is out (A3-13).
  `AppDelegate.swift` (`MacUpdater.shared.start()`) follows the flag too (hook table below).
- **Always on**: `integration_claude` (the main workspace pill until the user picks another). `KoncluiFeatures.required`.
- **Ids**: a pill is its PillCatalog id (`agent_orca` included); a page is `page_<HubPage case>` (`page_notes`,
  `page_voice`…); a Settings block is `block_iphone`, `block_recap` (Weekly recap), `block_vitals` (Koru and your
  Mac) or `block_updates` (Atualizações). `block_reminders` is the flag of the "Lembretes" page (`HubPage.reminders`,
  returned by `HubPage.featureId`); it is no longer listed twice, as a block and as a page, and was dropped from
  `KoncluiFeatureRegistry.blocks`. A service of Integrations follows its pill's id (`integration_notion`,
  `integration_portfolio`, `integration_whatsapp`…); Voice and the Notetaker are the pages `page_voice` and
  `page_notes`. The registry is `App/KoncluiFeatureRegistry.swift`: pills come from `PillCatalog.all`, pages from
  `HubPage.allCases`, blocks from `KoncluiFeatureRegistry.blocks`.
- **The Features screen** (the Portuguese app calls it "Recursos"): a switch for every flag, in three groups (pills,
  pages, Settings blocks) with a note each, and "Restore defaults". Hidden. Unlock it with ⌥-click on the Koncluí
  wordmark at the top of the window's sidebar (again to lock it), or
  `defaults write com.konclui.mac konclui.features.unlocked -bool YES`; a Features item then shows under the
  notch's pages. `App/KoncluiFeaturesPage.swift`.
- **What a change does while the app runs** (`KoncluiFeatureModel`, `App/KoncluiFeatureRegistry.swift`): the
  window and Settings draw again; a pill turned off leaves the active pills and the notch (turning it on again
  brings nothing back: the user adds it again); the window falls back to the first page that is on if it was on a page
  that went off. A value written with `defaults write` is read the next time the flag is read, and the pill cleanup
  runs at the next launch (`loadIntegrationTasks`).
- **What a flag does not do**: it does not stop a session an agent sends through its own hooks (HookServer makes
  a pill for it), and it does not stop what the user configured earlier (a saved key, a running poller): the pollers
  run while their pill is active, and a pill that is off is not active.

### Deleting a feature for good

Delete its code and its registry line; nothing else holds a reference to it:

- **A pill**: its `.init(...)` line in `PillCatalog.all`; its entry in `KoncluiFeatures.shippedOff`; its entries in
  `toolForPill` / `keysForPill` (`KoncluiRecognition.swift`); its block in `SettingsView` (Integrations or Agents:
  the `.koncluiShown(...)` line goes with it) and the feature's own files. The registry follows `PillCatalog.all`.
- **A page**: its `HubPage` case (the compiler lists the switches to fix: `title`, `symbol`, `settingsSection`,
  `notchSubtitle`, `HubHeroTheme.of`, `FlowHubView.hubPage`), its entry in `flowPages` / `notchPages`, its
  `sectionFeatureId` line if it shows a Settings section, and its view.
- **A Settings block**: its code and its `.koncluiShown(...)` line in `SettingsView`, and its tuple in
  `KoncluiFeatureRegistry.blocks`.

A stored override of a deleted id is never read again. Then `./scripts/konclui/test-features.sh` and the build.

### Only what this Mac has

Settings → Active pills, Agents, Chat and Integrations list what was recognized (installed, configured, signed
in or turned on) and an "Add…" menu at the end lists the rest of what the flags allow. Picking from it reveals the
block or row and keeps it (`konclui.added`, entries `<screen>:<id>`). The rules are `App/KoncluiRecognition.swift`
(pure, tested); `SettingsView` feeds them.

| Screen | Listed when |
|---|---|
| Active pills | the pill is on (main or active), or its tool is on this Mac (CLI on `$PATH` or in the usual install folders, app in `/Applications` or `~/Applications`; a config folder alone does not count, it outlives an uninstall), or its service has a key in the Keychain, or its chat provider has a key or a connected server, or Spotify is installed. Apple Music, Mail and Crypto carry no signal (built in, or keyless): only when on |
| Agents | its tool is on this Mac or its hooks, plugin or switch are already on. Claude and Codex plan gauges follow Claude Code or Codex. `KoncluiKlaudeHooksSection` (K11) is always first |
| Chat | Coucou's subscriptions box, then `KoncluiProxySection` (K10), are always shown. Anthropic API and the key-based providers: a key is saved. Ollama and LM Studio: a server is connected, or `ChatAccess` says one answers |
| Integrations | a token, key or URL is saved, or the pill is on (Crypto, Portfolio, WhatsApp, Notion…) |

`./scripts/konclui/test-features.sh` checks the defaults (it prints the pill ids offered with them), the override
round trip, the unlock, the detection on a fake Mac and the rules above.

## Koncluí hooks in upstream files

Small and marked `// Koncluí:`; the logic lives in new files (`CoucouKit/KoncluiFeatures.swift`,
`App/KoncluiFeatureRegistry.swift`, `App/KoncluiFeaturesPage.swift`, `App/KoncluiRecognition.swift`).

| File | Hook | What it does |
|---|---|---|
| `CoucouKit/PillCatalog.swift` | `available` filters by `KoncluiFeatures.isOn` | a pill whose flag is off is offered nowhere |
| | `agent_orca` in `all`, and its `sessionSubtitle` | the Orca pill (Where you code, `#A6A6A6`: Orca's icon is monochrome, this is the mid silver of the orca's shading and the one grey the other pills leave free) |
| `App/FlowHub.swift` | `HubPage.flowPages` / `notchPages` are computed and skip pages that are off | the sidebar lists the pages that are on |
| | `HubRouter.page` falls back, `HubRouter.showFeatures` | a page that is off is replaced by the first one that is on; the Features screen |
| | `FlowHubView`: observes flags, shows `KoncluiFeaturesPage`, `hubPage` | the hidden screen takes the page's place once unlocked |
| | `HubSidebar`: ⌥-click on the wordmark, the Features item, `selected` | the unlock gesture and the item |
| | `HubRouter.init()` (`#if DEBUG` only) | `-konclui.debug.page <HubPage rawValue>` opens the window on that page, for screenshots |
| `App/SettingsView.swift` | `.koncluiShown(...)` after a block or row (General: Koru and your Mac, Weekly recap, iPhone; the standalone sidebar's rows; Agents' blocks; Chat's; Integrations') | a block shows only while its flag is on and it was recognized or added |
| | `activePillsSection`, `agentsSection`, `chatSection`, `integrationsSection` | recognized-only lists and the "Add…" menu; `KoncluiKlaudeHooksSection()` at the top of Agents, `KoncluiProxySection()` after Coucou's subscriptions in Chat |
| | `extension SettingsView` at the end | the signals the screens feed `KoncluiRecognition` |
| | `KoncluiWhatsAppSection()` in place of `WhatsAppSettingsSection()` in `integrationsSection`, shown also when `KoncluiWhatsAppDebug.forcesBlock` | the new WhatsApp block (one line, popover, notch preview). `WhatsAppViews.swift` is untouched and still holds the old block, the notch card and the rows the preview reuses (`WhatsAppRow`, `WhatsAppStatus`); the new block repeats the old one's Advanced fields and save logic, and the preview repeats `WhatsAppCardView`'s header and status layout: after an upstream merge, mirror changes to those two places. DEBUG only, for screenshots: `-konclui.debug.whatsappState` with `fresh`, `installing`, `qr`, `connected`, `stopped`, `unauthorized`, `failed`, `connecting`, `off` or `noroom` draws that state (no setting, Keychain item or gateway is read or written), and `-konclui.debug.whatsappPopover` with `options`, `ignored` or `advanced` opens the popover |
| | `agentsSection`: each block's `GroupBox(String(localized: "hooks.<agent>.title")) {` line (Claude Code, Gemini, Antigravity, Codex, Copilot, Muse, OpenCode, Amp, Hermes, Plan usage: 10 lines, each marked `// Koncluí: row + popover`) is `koncluiAgentRow(.<block>, .<kind>, installed: …) {`; the content closures, the `@State` and the install methods are untouched | every agent is a row with a popover (`KoncluiAgentRow`); a merge that brings a `GroupBox` back is caught by `test-agent-rows.sh` |
| | `pillRow`: the three-line `Text(h)…` hint became `koncluiHint(h, for: def)`; the hint computation above it is untouched | "Hooks not installed" and "Plugin not installed" are doors for the seven agent pills that have one (`KoncluiAgentRows.door(forPill:)`) |
| | `body`: `&& !koncluiPopoverOpen` on the bottom message; `onAppear` calls `koncluiDebugPreview()`; two `@State` (`koncluiOpenAgent`, `koncluiDoorPill`) | the open popover shows the message itself; the DEBUG `:preview` flag; which popover is open |
| | `extension SettingsView` (Agents part): `koncluiAgentRow`, `koncluiPopoverBinding`, `koncluiPopoverOpen`, `koncluiHint`, `koncluiDoor`, `koncluiDoorPopover`, `KoncluiHookWiring` / `koncluiHookWiring` (each agent's preview, confirm and cancel by block), `koncluiDebugPreview`; `koncluiAgentShown` also true for the DEBUG flag's agent | the row helper and the door; no logic of the old blocks is copied |
| `App/ClaudeDesktopChatWatcher.swift` | `ClaudeDesktopChatSettingsSection`: its `GroupBox(String(localized: "claude-desktop.chat.title")) {` line is `KoncluiAgentRow(id: "claudeDesktop", …) {` | the only upstream line outside `SettingsView` for the rows; `KoncluiKlaudeHooksSection` is Koncluí's own file and builds its row the same way |
| | `FlowHubView.body`: `.disclosureGroupStyle(KoncluiDisclosureStyle())` | every disclosure in the window opens from its whole label (`App/KoncluiDisclosureStyle.swift`) |
| `App/IslandViewContent.swift` | `AgentPill.displayName` and `MusicPill`'s title go through `KoncluiTabLabel.short` | a tab's name fits in 11 characters: "Claude Desk" (`App/KoncluiTabLabel.swift`, `scripts/konclui/test-tab-label.sh`) |
| | `QuestionView`: `.koncluiScrollsWhenTall()` on the question's content | a question taller than the island scrolls under its header, the edge with more beyond it fading out, instead of spilling past both edges (`App/KoncluiOverflowScroll.swift`); unchanged while it fits |
| `App/IslandRootView.swift` | `isTall` also holds for the active question when `KoncluiOverflowScroll.isTall(state.pendingQuestion)` | a question taller than the default card fills the island the estimate made for it (as Mail does), not the fixed 98 pt slot; a short one keeps the slot |
| | `BotPlacement`'s mask is `max(320, islandHeight)` tall when expanded | in an island taller than 320 pt the Koru, centered, stays whole instead of losing her lower half |
| `App/MachineVitals.swift` | `displayName`: `KoncluiTextRepair.unmangled(local)` | a process name macOS hands over garbled (UTF-8 read as Mac Roman: "Servi√ßo de M√°quina Virtual do app limactl") shows as written under the notch (`App/KoncluiTextRepair.swift`, `scripts/konclui/test-text-repair.sh`) |
| `App/AskQuestion.swift` | `estimatedIslandHeight`: `lines` counts each paragraph on its own | a multi-paragraph question (a decision brief) gets a tall enough island; `tests/AskQuestionTests.swift` covers it |
| `App/Voice/ClaudeVoiceBrain.swift` | `isActive` returns `KoncluiVoiceBrainLive.shared.currentBrain().claudeSource != nil`; `respond` calls `turnEnded(failed:)` at both exits | Claude is the brain only when the person turned it on and a source exists (not "a key is saved"); the outcome of each turn feeds the failure notice in Settings → Voice |
| `App/ClaudeService.swift` | `voiceTurn` and `voiceAnswer`: an early branch when `claudeSource() == .proxy`; `voiceAnswer` no longer needs a key in that case | the same Messages body goes through the Koncluí Proxy (non-streamed, bearer token read per call); if the proxy refuses the server tool `web_search_20250305` the call is repeated once without it and later turns leave it out |
| `App/Voice/VoiceDataSources.swift` | `LiveVoiceInfo.hasWebKey` | the subscription counts as a way to reach Claude, so the web answer path works without a key |
| `App/SettingsView.swift` | `voiceSection`: the orange "add your Anthropic key" row is replaced by `KoncluiVoiceBrainSection(permissionsGranted:voiceOn:)` | the reason the checkbox is greyed out, who understands you now, the Claude opt-in. The `webKeySaved` state stays declared (unused now) to keep the diff small |
| `App/NoteTaker.swift` | `toggleFromPill`, `start`, `load` gates: `guard KoncluiNoteSpeech.engine != .needsDownload` (were `Parakeet.shared.isReady`) | Record never waits for a download when Apple's speech is on the Mac |
| | `start`: `KoncluiNoteSpeech.shared.prepare()` before `startLiveLoop()` | installs Apple's language files while the call is recorded (does nothing when Parakeet is the engine) |
| | `startLiveLoop`: `KoncluiNoteSpeech.canTranscribeLive` before `takeChunk()`, `KoncluiNoteSpeech.text(of:)` instead of `Parakeet.shared.transcribe` | the live lines; the stretch waits in the recorder while the language installs; with Parakeet it is the same call |
| | `process`: `apple`, `asr: AsrManager?`, `diarize` closure; `words(in:asr:)` takes an optional and starts with `guard let asr else { return try await KoncluiNoteSpeech.words(in: url) }` | Apple's words, no Parakeet load, no diarizer (turns are empty, so `NoteBuilder` keeps the others as one speaker); with Parakeet the lines are the old ones |
| `App/FlowHubNotes.swift` | `HubNotesPage`: setup card only when `engine == .needsDownload`; `HubNotesList`: `KoncluiNoteSpeechRow()`; `HubRecordButton`: `.disabled(KoncluiNoteSpeech.engine == .needsDownload && !taker.isRecording)`; `HubLiveNote`: `KoncluiNoteSpeechProgress()` | the Record button is on; the engine in use and the Parakeet upgrade sit in one row with a popover; the language install shows under the live call |
| `App/FlowHubHome.swift` | Home's "Record a call": `KoncluiNoteSpeech.engine != .needsDownload` instead of `Parakeet.shared.isReady` | same gate |
| `App/FlowHub.swift` | `HubTheme.muted` is `KoncluiTheme.textTertiary` | the muted grey passes 4.5:1 (was 3.5:1 on a card) |
| | every `HubTheme` colour is its `KoncluiTheme` token (`sidebar` is clear); `FlowHubView`'s background is `KoncluiBrandBackdrop()`; `HubSidebarItem`: the selected item's icon is the accent on a 12 % accent wash | the design system's colours (UX.md 11.1): navy surfaces, mint, the Painel Gestor's sidebar gradient with the website's grain |
| `App/GreetingCanvasView.swift` | `drawGreeting`: the card's fill is `KoncluiGreetingAmbient.cardFill` and `KoncluiGreetingAmbient.draw(…)` follows it; `drawMochi`: no golden halo (all `#if !APPSTORE`) | the greeting's card is a band: the navy well and the mint edge from its first frame, then the bands' life behind the Koru once she lands (the mint glow breathing, particles rising, the website's grain), without the old Mochi's warm haze over it (`App/KoncluiGreetingAmbient.swift`) |
| `App/FlowHubMochis.swift` | `HubHeroTheme.of(.dictation)`: the accent and a mint Koru where Coucou's orange was; `HubHeroBackdrop`: the band's base is `KoncluiTheme.sunken`, with `KoncluiGrain` over it | the home band wears the brand; every band sits in the navy family with the site's texture |
| | `FlowHubView.body`: `.koncluiTheme()` and `.environment(\.koncluiMotion, …)`, `@Environment(\.accessibilityReduceMotion)` | the hub's GroupBox, Toggle and button styles at the root; the canvases' rate (window front, behind, hidden, Reduce Motion) |
| | `hubPage`: the notch pages are `KoncluiSettingsPage(page:section:)` | the compact header pinned over `SettingsView`'s scroll (`App/KoncluiSettingsPage.swift`); `SettingsView` is untouched |
| | `HubSidebar.status` is `KoncluiDictationStatus` | the sidebar status is a door with a popover (`App/KoncluiDictationDoor.swift`) |
| | `HubSidebarHeader`, `HubSidebarItem`, `HubPageScaffold`, `HubCard`, `HubLabel`, `HubRow`, `HubDivider`, `HubIconButton` | tokens (gutter, label role, hairline with Increase Contrast), the pointing hand |
| | `HubButtonStyle.makeBody` is `KoncluiButtonLook`; `HubField` is `KoncluiField` (+ `label`, `hint`) | one button look with a disabled state; a field with an edge, a focus ring, a label and a hint |
| `App/FlowHubMochis.swift` | `HubWindowState`: `key` and the two key notifications | the window being the front one |
| | `HubMochiScene` and `HubHeroBackdrop` read `koncluiMotion`; `HubHeroBackdrop(live:)` | still under Reduce Motion or when hidden, 30 Hz behind; every band drifts (`HubHero` passes `live: true`; `KoncluiMotion.bandIsLive`), the glow cards do not |
| | `HubHero`: title 30 pt and inset 18 on every page, `minHeight` instead of a fixed height, a material behind the pinned band | the title no longer jumps between pages; a long subtitle grows the band |
| `App/FlowHubNotes.swift` | list column `.padding(.leading, KoncluiSpace.gutter)`, detail panes `KoncluiSpace.gutter`, `startError` is `KoncluiStatus` | the list column and the detail pane line up with the header card |
| `App/FlowHubHome.swift` | `needsSetup`, `bandSubtitle`, the band's trailing button; `HubSetupCard` no longer drawn (kept in the file) | while dictation is off or cannot paste, the band's one primary is the setup; recording a call is the primary only when dictation works |
| `App/FlowHubWords.swift` | `missing` state, `hint:` on the fields, `.disabled` removed from "Adicionar" and "Salvar", labels on the Snippets fields, `.menuIndicator(.hidden)` | a blocked add says what is missing under the field |
| `App/FlowHubSettings.swift` | `subtitle`, `HubKeyCap` is `KoncluiKeyCap`, the installed menu label is `KoncluiStatus` | a subtitle for Ajustes; one key cap; one way to say "installed" |
| `scripts/konclui/rebrand.py` | `HUB_STYLES` (CODE rules) | `.buttonStyle(.borderedProminent)` → `.koncluiPrimary`, `.bordered` → `.koncluiSecondary`, `.pickerStyle(.segmented)` + `.koncluiSegmented()` in `SettingsView`, `WhatsAppViews`, `RemindersSettingsSection`, `ShortcutsSettingsView`; outside the hub the three names draw upstream's own styles |
| `App/FlowHub.swift` | `HubSidebarHeader(text: "Flow")` → `konclui.hub.section.flow` (a `rebrand.py` FIXED rule) | the first sidebar group is "Ditado e notas" |
| `App/FlowHubWords.swift` | three `hub.add` buttons → `konclui.hub.add-word/-replacement/-snippet`; the snippet trigger → `konclui.hub.trigger-quoted %@` (FIXED rules) | three different "Adicionar"; no French guillemets in every language |
| `App/FlowSettingsBox.swift` | `FlowHubController.shared.show()` → `show(.settings)` (FIXED rule) | "Abrir os ajustes do ditado" opens that page (it did nothing) |
| `App/NoteTaker.swift` | the models notice's button uses `hub.open` (FIXED rule) | it opens the dictation settings; `hub.open-settings` now only labels the "go to Chat" button |
| `App/SettingsView.swift` | recorder: `KoncluiKeyName.label(c)` for unmapped keys, `konclui.key.press`, `String(localized: "None")` (FIXED rules) | ⌃⌥] and ⌃⌥[ both read ⌃⌥· |
| `App/ShortcutLogic.swift` | `keyCodeToString` falls back to `KoncluiKeyName`; "⌘1 – ⌘9" → "⌘1 … ⌘9" (FIXED rules) | same; no dash in a range |
| `App/CodexPlanGauge.swift` | eight English literals → the Claude gauge's keys (`plan.5hours`, `plan.week`, `plan.just-now`, `plan.mins-ago %lld`, `plan.hours-ago %lld`) and `konclui.codex.*` (FIXED rules) | the Codex gauge in the notch speaks the person's language |
| `NotchBuddy/project.yml` | four usage descriptions; `InfoPlist.xcstrings` in the Mac target's resources (FIXED rules) | permission prompts |
| `App/FlowHub.swift` | `HubPage.reminders` in the enum, `notchPages`, `settingsSection`, `title`, `symbol`, `notchSubtitle` (six lines marked `// Koncluí`, the owner's own lines from the owner's main checkout) | the menu's Reminders and `HubPage.forSettings("reminders")` land on a real page that hosts `RemindersSettingsSection` |
| `App/FlowHubMochis.swift` | `HubHeroTheme.of`: `case .reminders` (the owner's colour and cast) | the new page needs a header; the switch is exhaustive |
| `App/SettingsView.swift` | the `@State` installed flags start from `KoncluiHookStatus.shared.snapshot` instead of `HookServer.*Installed()`; `koncluiHooks`, `koncluiLimitPill` | no file read in a `@State` initializer or a view body (A3-19) |
| | `onAppear` calls `koncluiHooks.refresh()`; `.onChange(of: koncluiHooks.snapshot)`, `.onChange(of: koncluiInstalledFlags)` | the answer is read off the main thread and copied in; an install or removal reads again |
| | each agent's popover content: `koncluiHookControls(.<agent>, …)` replaces the path text, the Install/Uninstall pair and the diff box (Gemini, Antigravity, Codex, Copilot, Muse, OpenCode, Amp, Hermes, Claude Code; the Hermes approvals part stays) | one component for every agent (`KoncluiHookControls`) |
| | `installHooks` / `confirmInstall` / `uninstallHooks` (Claude Code): `claudePendingInstall`; the removal is previewed (`previewClaudeHooks(install: false)`) and confirmed | CLAUDE.md: never write `~/.claude/settings.json` without showing what changes |
| | `terminalCardsEnabled` toggle and its paragraph in Claude Code's popover: `konclui.terminals.toggle` / `.about` | the English text is now Portuguese and says what the switch does |
| | `KoncluiKlaudeHooksSection()` replaces `KlaudeHooksSection()`; `KoncluiOrcaRow()` after Claude Code's row | `KlaudeHooksSection` was deleted (klaude's block is now `KoncluiKlaudeHooksSection` in `KoncluiKlaudeRow.swift`); Orca's row decides its approvals |
| | `pillRow`: `atMax` from `KoncluiTabLimit.blocks`, hints from the snapshot, `koncluiColorDot(def)`, `koncluiLimitDoor(def)` | the blocked switch says why; the colour dot is a door |
| | `activePillsSection` and `integrationsSection`: the `KoncluiAddMenu` moved out of the card | "Add…" at the outer edge on every list |
| | `generalSection`: `KoncluiConnectAgentsCard`, `demoBox(quiet:)` (first or last), `.koncluiShown(embeddedSection == nil)` on the Hotkey box, `UpdateSettingsSection().koncluiShown(isOn("block_updates"))`, `KoncluiRemoveIntegrations` at the end | Geral for a Mac that is set up |
| `App/KoncluiFeatureRegistry.swift` | `HubPage.featureId` for `.reminders`; `block_updates` in `blocks` | flags |
| `CoucouKit/KoncluiFeatures.swift` | `"block_updates"` in `shippedOff` | ships off |
| `App/AppDelegate.swift` | a `Task` warming `KoncluiVoiceBrainLive.shared.refreshProxy()` at launch | the pages name the right Claude source on first read |
| `App/HookServer.swift` | `processPermissionRequest` and `processQuestionRequest`: `isTerminal` uses `KoncluiOrcaCards.showsInNotch(isOrca:otherTerminalsOn:)` | Orca sessions' approvals and questions show in the notch by default (switch on the Orca row); other terminals keep their own switch |
| `App/AppDelegate.swift` | `MacUpdater.shared.start()` only when `KoncluiFeatures.isOn("block_updates")` | the updater stays off until Koncluí has its own Developer ID and release channel |
| `App/MacUpdate.swift` | `service` (`releasesURL`, `latestPageURL`), `teamId` `5M8RG3BCX2`, `tagPrefix` `konclui-v` used by `macVersion`, the service in `allowedHost` | the updater reads and accepts only Koncluí's releases, through its update service (`tests/MacUpdateTests.swift` follows: Coucou's `v0.5.6` and Louis's team are rejected) |
| `App/MacUpdater.swift` | `openReleasePage`: `MacUpdate.latestPageURL` when no release is known | the private repository's page would be a 404 for anyone else |
| `App/WhatsNew.swift` | `releasePage`: the service's notes page of `konclui-v<version>` | same reason (`tests/WhatsNewTests.swift` follows) |
| (rules) | `scripts/konclui/updater-rules.py` writes the `>>> updater rules` / `>>> updater inserts` blocks of `rebrand.py` for these five files | a Coucou sync gives them back; `scripts/konclui/test-updater-rules.sh` checks it. After changing one of them: `python3 scripts/konclui/updater-rules.py` |
| `scripts/release.sh` | first line: stops when `scripts/konclui/release.sh` exists | Coucou's release can never run from this fork (it would push to the public `origin` and publish to `Louis-CFM/coucou`) |
| `App/FlowHubHome.swift` | `KoncluiConnectAgentsHome(router:)` at the top of the home content | agents found but not connected |
| `App/Voice/IntentParser.swift` | first line of `parse`, first line of `parseMultiAction` | Portuguese phrases first (`KoncluiVoicePT.parse`, `parseMulti`); nil for anything else |
| `App/Voice/VoiceQuery.swift` | `VoiceAnswer.text(_:_:language:)` (the `french:` overload forwards); `stateText` / `weatherText` calls take the language; the lead-in lists of the guided e-mail (`recipientAnswer`, `subjectAnswer`, `bodyAnswer`, `instructionText`, `attachmentAnswer`) get `+ KoncluiVoicePT.…Leads`; `contactCandidates`, `spokenEmail` ("arroba", "ponto"), `cleanFreeText`, `simpleMail`, `looksLikeQuestion` | Portuguese answers and Portuguese answers to the e-mail questions |
| `App/Voice/VoiceActionRunner.swift` | `t` takes `VoiceText`; `answerLanguage` replaces `answersFrench`; `webAnswer(…language:)` in the protocol, with a default that calls the `french:` one; the language offer and its answers call `VoiceLanguageSwitch`; `isYes`, `isNo`, `cancelsMail`, `askIfIncomplete`, playlist prefixes get Portuguese words | the runner speaks fr, en or pt; an older provider (upstream's test double) keeps working |
| `App/Voice/VoiceDataSources.swift` | `fr: Bool` became `language: VoiceLanguage` in `answer`, `snapshot`, `money`, `ago`, `duration`, `when`, `plan`, `WeatherSource.forecast`, `geocode`; `openApp` says its two sentences with `voiceSay`; `webAnswer(…language:)` | formats, Open-Meteo place names and answers follow the answer language |
| `App/Voice/VoiceSettings.swift` | `language` defaults to `VoiceLanguage.macDefault()`; `answerLocale` is `VoiceLanguage(code:).locale` | "pt" is a language; the Mac's language is the default |
| `App/Voice/VoiceEngine.swift` | `suitableLocale`: `case "pt"` | Settings → "Você fala: Português" listens with pt-BR (pt-PT second) |
| `App/Voice/VoiceBrain.swift` | `instructions()` returns `KoncluiVoicePrompts.appleIntelligence` for "pt"; `draftMail` writes in Portuguese when the instruction is; `ServiceTool` uses `VoiceSettings.answerLocale` | the on-device model answers and writes e-mails in pt-BR |
| `App/Voice/ClaudeVoiceBrain.swift` | `systemPrompt`: language from `VoiceLanguage`, `+ KoncluiVoicePrompts.claudeAddendum` (empty for fr and en) | Claude answers in pt-BR |
| `App/ClaudeService.swift` | `voiceAnswer(…language:)` (was `french: Bool`); `let system = language == .pt ? KoncluiVoicePrompts.webAnswer(…) : french ? …` | the web answer prompt in pt-BR |
| `App/Voice/ElevenLabsTTS.swift` | the cached voice is keyed by language too; `pick(…language:)` prefers a voice labelled Portuguese (the model `eleven_flash_v2_5` is multilingual: an English-labelled voice still speaks it) | ElevenLabs keeps working in Portuguese |
| `App/Voice/VoiceSpeaker.swift` | `rank` calls `KoncluiVoicePick.rank` | Portuguese ranks the region first, then Luciana and Felipe |
| `App/Voice/VoiceGenderNames.swift` | `luciana`, `joana`, `catarina`, `felipe` | "female" and "male" find the Brazilian system voices |
| `App/Voice/LiveVoiceControls.swift` | `onLanguageSwitch` also resets the ElevenLabs voice | the voice follows a language change made by speaking |
| `App/Voice/TurnEndPolicy.swift` | Portuguese end phrases ("obrigado", "valeu", "deixa pra lá"…) and mid-sentence words ("e", "o", "adiciona"…) | the conversation ends, and the mic waits, in Portuguese |
| `App/Voice/ConversationContext.swift` | `resolveRelative` reads `KoncluiVoicePT.relativeForm(norm)` | "e o Vercel também", "igual para o Stripe", "desfaz" |
| `App/Voice/WakePhrase.swift` | `normWord`: "okei", "oquei" → "ok"; "kôru", "côru" → "koru" | how a Brazilian recognizer writes the wake word |
| `App/IslandWindowController.swift` | 4 sentences through `voiceSay`; the language offer accepts "pt" | "Deixa eu ver.", "Pronto.", the attachment line and the offer in Portuguese |
| `App/SettingsView.swift` | `voiceSection`: both language pickers get `Português` (tag "pt"); `voiceLanguage` defaults to `VoiceLanguage.macDefault().rawValue`; `speakVoiceSample` and the Mac voice name follow the language | the choice is offered and the sample speaks it |
| `scripts/test-voice-{entity,intent,query,runner}.sh`, `scripts/test-conversation-context.sh` | three `swiftc` lines (the pure Koncluí files) | the unchanged upstream tests still compile |
| `App/FlowCleanup.swift` | `hasKey` is `@MainActor` and reads `KoncluiClaudeLive.shared.claudeSource() != .none`; new `canClean` | "a Claude is reachable" is the subscription or the key (was the key alone); clean-up alone also counts Apple Intelligence |
| | `clean` and `transform`: the inline request (headers, body, status check, parse) is one `KoncluiClaudeLive.shared.complete(...)` call; the prompts, the tag stripping and `plausible`/`plausibleTransform` are upstream's | one place picks the source, sends, tells the person once, answers nil on any failure (the words are pasted as heard) |
| | `model` is `KoncluiClaudeAccess.fastModel`; the type's doc comment has one Koncluí line | one name for the fast model |
| `App/NoteTaker.swift` | `NoteSummaryEngine.label` is `@MainActor` and names the source ("Claude (sua assinatura)" for the subscription, upstream's "Claude (sua chave)" for the key); `claude` case doc | the picker says where Claude comes from; the raw values are unchanged |
| | `init`: `Self.defaultEngine` (Claude when a source exists, else Apple, else off), `followDefaultEngine()` | the default engine follows what the Mac has once klaude is found a moment after launch; it is not saved, so a Mac that loses klaude falls back by itself |
| | `correct`: `FlowCleanup.hasKey` guard instead of reading the key; `claude(.correction, …)` | the transcript correction works with the subscription |
| | `claude(_:system:user:maxTokens:)`, `claudeSummary(_:)`, `summarize` `.claude` case | the inline request with the key and its two tries is one `complete` call (the chosen model, then the fast one, as before) |
| `App/FlowStore.swift` | `init`: `seedInstalledAppStyles()` and (DEBUG) `KoncluiFlowDebug.data`; `readOnly` in `save`; `restoreHistory`, `restoreStats` | Orca, Warp and Ghostty are offered once when installed; screenshots can use sample data that is never written; Undo puts a deleted dictation or the cleared numbers back |
| `App/FlowHubWords.swift` | `removeWordWithUndo` / `removeReplacementWithUndo` / `removeSnippetWithUndo` / `removeAppStyleWithUndo` instead of `removeAll`; `.koncluiUndoBar()` on the three pages; `KoncluiDictationNextStep` in the two empty states; Estilos: `KoncluiStylePicker` instead of `Picker`, `visibleApps`, `stylesOff`, `.disabled(!store.cleanupEnabled)`, the legend card is gone (privacy line kept) | Undo for every removal; the apps this Mac has; each style explained where it is chosen; a disabled list says why |
| `App/FlowHubHome.swift` | `bandSubtitle` and the band's button follow `flow.koncluiState`; the empty history says dictation is off first; `deleteWithUndo`; `HubTotalsCard` is three `KoncluiStatDoor`s, speed is optional, "Ilimitado e grátis" is `konclui.home.local-only`; `HubSetupCard` deleted | no promise of a key while off; numbers are doors; "indisponível" instead of a computed 0 |
| `App/FlowHubInsights.swift` | four `HubStatCard`s are `KoncluiStatDoor`s (note keeps two lines), speed is optional, `chartEmpty` when the period has no word | every number opens its records; an empty chart has a next action; no cut note |
| `App/FlowHubSettings.swift` | the permission is the first row of Teclas, only for `.needsAccess`, and the "Permissão" card is gone; a link to Atalhos; `clearHistoryWithUndo`, `clearEverythingWithUndo`, `.koncluiUndoBar()` | A2-19, A3-24, A1-38, A1-10 |
| `App/FlowHub.swift` | `HubSidebar`: `KoncluiAccessibilityMemory.note(trusted:)` on appear and when `flow.trusted` changes | remember that macOS once trusted Koncluí |
| `App/KoncluiDictationDoor.swift` | the three states come from `flow.koncluiState`; "Ativar o ditado" is `KoncluiDictation.turnOn()` | one source for the state; debug launch arguments reach the sidebar |
| `App/KoncluiWhatsAppSection.swift` | the private `UndoNotice` and `undoBar` are `KoncluiUndoNotice` and `KoncluiUndoBar` | one Undo bar for the app |
| `App/FlowHubWords.swift` | `HubStylesPage`: `@ObservedObject claude`; the switch and "Ligar a limpeza" read `FlowCleanup.canClean`; `KoncluiClaudeConnectLine(feature: .cleanup)` and `KoncluiClaudeFailureLine(feature: .cleanup)` replace the key HStack; the privacy text is `claude.privacyLine(for: .cleanup)` | Apple Intelligence counts for clean-up; nothing is asked for a key it does not need; one line with the way to the key |
| `App/FlowHubSettings.swift` | `HubSettingsPage`: `@ObservedObject claude`; `KoncluiClaudeFailureLine` under prompt mode and translation; `KoncluiClaudeConnectLine(feature: .prompt)` replaces the key HStack; `claude.privacyLine(for: .prompt)` and `claude.notesDetail` replace `flow.ai-privacy` and `notes.engine-detail`; `KoncluiClaudeFailureLine` for summary and correction under the Notetaker engine | A1-03, A3-10, A3-27 |
| `App/FlowHubNotes.swift` | `HubSummaryEnginePicker`: `@ObservedObject claude`; the line menu calls `deleteLineWithUndo`; `.koncluiUndoBar()` on `HubNotesPage` | the engine's name follows the source; a deleted line can be put back |
| `App/NoteTaker.swift` | `deleteLineWithUndo` (the line goes back where it was) | Undo (UX.md 1.5) |
| `App/KoncluiClaudeLive.swift` | `openChatForKey()` (in `KoncluiClaudeLines.swift`) replaces the pill's own jump; DEBUG `claudeSource` and every feature in `claudeFail` | the key block exists when Chat opens |
| `App/KoncluiClaudeAccess.swift` | `Failure.messageKey(source:feature:)`: the Notetaker's two features speak of the notes | the failure sentence fits the feature |
| `App/ShortcutsSettingsView.swift` | `resetAll()` is `KoncluiShortcutsUndo.resetAll(then: reload)`; `KoncluiDictationShortcuts()` after the island group; the island keys are `KoncluiKeyCap`s (`#if !APPSTORE` each) | Undo; the dictation keys where people look for keys (A1-38); one key cap (A2-29) |
| `App/SettingsView.swift` | `ShortcutRecorderButton`: `KoncluiKeyCap(recording:)` and `.koncluiPointer` | A2-29 |
| | "Clear history" of the weekly recap: `RecapStore.snapshotForUndo()` and `KoncluiUndoCenter.offer` | Undo |
| | `voiceSection`: the voice source, the voice type and the pitch get the 130 pt label column of the Language box; "Fonte da voz" is `konclui.voice.source`; the ElevenLabs key sits under the picker | A1-49 |
| | the six Chat key buttons, the ElevenLabs button and `saveKey` of Integrations use `KoncluiKeychainSave` and `@State koncluiKeychainRefused` | A3-28 |
| `App/KoncluiSettingsPage.swift` | `.koncluiUndoBar()` after `.koncluiPinnedHeader` | the notch pages show the Undo notice |
| `App/RecapStore.swift` | `snapshotForUndo()` (what "Clear history" takes, as a closure that puts it back; turns recorded since stay) | Undo |
| `App/ClaudeService.swift` | `Keychain.save` and `KeychainStore.set` are `@discardableResult` and answer the `OSStatus`; DEBUG `-konclui.debug.keychainFail 1` | A3-28 |
| `App/KoncluiVoiceBrain.swift`, `KoncluiVoiceBrainLive.swift` | `turnDeadline` (10 s), `timeLeft(until:now:)`, `request(..., timeout:)`; `send` stops when the deadline passes; `post` races the request against the clock | A3-29 |
| `App/KoncluiAgentRow.swift`, `KoncluiHookControls.swift`, `KoncluiPillRowParts.swift`, `KoncluiOrcaRow.swift` | `KoncluiStatus`, the card tokens, `.koncluiType` roles, `KoncluiTheme` colours, 11 pt minimum for code | the agent rows and popovers look like the rest of the hub |
| `App/KoncluiTheme.swift` | `KoncluiKeyCap(recording:)` | the recorder's "press the keys" state |
| `App/SettingsView.swift` | `case "reminders"`: `KoncluiRemindersPage()` (`#if APPSTORE` keeps `RemindersSettingsSection`) | Lembretes is a list like Agentes, and "Novo lembrete" opens an editor with a live preview (KoncluiReminderEditor, KoncluiReminderPreview, KoncluiReminderRules); the owner's section stays as it is |
| `App/ReminderManager.swift` | top of `perform`: `KoncluiReminderTrial.close(...)`; `.complete` finishes with `complete: reminder.repeats == .none` | "Testar" shows the reminder being edited without saving and its buttons change nothing; "Concluído" on a repeating reminder brings it back at its next turn, as the MCP's `complete_reminder` already said (it used to stop it for good) |
| `App/ReminderWindowController.swift` | `show`: `panel.contentView = KoncluiReminderAlert.hostingView(for:) ?? NSHostingView(…ReminderAlertView…)`; `cardFrame`: the height is `KoncluiReminderAlert.cardHeight(for:)` | the alert is "Despertador com a Koru" (KoncluiReminderAlert.swift, option 11 of `design/konclui/reminders/reminder-alerts-10.html`): the Koru on top, the time and how far it is, one primary the whole width (a meeting link in a button or in the message is "Entrar na reunião"), snooze lengths on the spot, ⏎ and esc; a card is as tall as what it says (`reminder.height` is no longer used), full screen covers the screen over the blurred desktop. The App Store build keeps the owner's view |
| | `ReminderAlertView`: the card's `.frame(maxWidth: .infinity, …)` | App Store build: a full-screen alert covers the whole width |
| `scripts/konclui/rebrand_copy_data.py` | the COPY rule of `flow.accessibility` ends at the path; the previous text is an accepted source spelling | the stale-permission advice lives only in `konclui.flow.accessibility-stale` |
| `Resources/Localizable.xcstrings` | 14 `konclui.*` keys, 16 languages; `konclui.file.needs-offline %@` (ADR-009), 16 languages; 69 `konclui.whatsapp.*` keys, 16 languages; 2 `konclui.disclosure.*` keys; 20 `konclui.voice.*` keys; 14 `konclui.notes.speech.*` keys; 10 `konclui.agents.*` keys; 11 `konclui.*` keys (`status`, `settings`, `home`, `hint`, `snippets`); 12 `konclui.*` keys (`hub`, `key`, `codex`) and 225 entries rewritten or filled by the copy rules, plus the new `Resources/InfoPlist.xcstrings` (the usage descriptions, 16 languages); 45 keys (`konclui.hooks.*`, `terminals.*`, `orca.*`, `pills.*`, `connect.*`, `remove.*`, one each of `konclui.agents.*` and `konclui.features.*`, and the owner's `hub.notch.reminders`) | the Features screen and "Add…"; the WhatsApp block and its notch preview; the disclosures' VoiceOver state; Settings → Voice (who understands you, the Claude opt-in; `voice.setting-web-desc` and `voice.setting-web-nokey` stay in the catalog, unused); the Notetaker's engine row, popover and install messages; the status words, the row's VoiceOver hint and the install door of Settings → Agents and Active pills; the hub's status lines, doors and field hints; the key names, the three "Adicionar" and the Codex gauge; the agent popovers' review text, the Orca row, the 4-tab limit, the "Conecte seus agentes" card and the removal popover; 16 `konclui.claude.*` keys (U3a: the source line, privacy, failures); 33 `konclui.*` keys (U3b: undo, home, stat doors, styles, accessibility); 12 `konclui.*` keys (U7); 108 `konclui.reminders.*` keys and the owner's `Snooze · %lld min` (the alert's snooze button read English) |
| `App/ChatSubscription.swift` | `subscriptionCLIs`: `case .koncluiProxy: []` | the proxy is not a subscription tool: klaude's key answers it (`KoncluiChat`) |
| `App/SettingsView.swift` | `chatSection`: Coucou's subscriptions box (all five), then `KoncluiProxySection()`; `subscriptionRow` adds `KoncluiSignInLine(cli:)` under "found" and hides the "sign in once" hint once the CLI is signed in | every AI keeps Coucou's switch and gets Koncluí's engine; Claude, ChatGPT and Cursor the sign-in line |
| | every `.settingsAnchor` sits before the block's `.koncluiShown`; `demoBox(quiet:)` carries `general.demo` both times | the search scrolls to the blocks that are shown |
| `App/SettingsSearch.swift` | `flow.keys` also matches `hub.settings.permission` and `flow.accessibility-open`; the `flow.permission` entry is gone | the permission is a row of Teclas (A2-19), its card is gone |
| `App/FlowHub.swift` | `HubPage.mailPages` is computed like the others and skips pages that are off; the sidebar shows the search results, else Flow, Notch, Mail and the Features item | Coucou 0.5.8's Mail pages follow their flags (`page_mailOverview`…) |
| `App/FlowHubSettings.swift` | the AI card keeps Koncluí's lines and takes upstream's `.settingsAnchor("flow.ai")`; no Permission card | as before the merge |
| `App/SettingsSearch.swift` | `results()` skips what `KoncluiSettingsSearch.isShown` refuses and matches `KoncluiSettingsSearch.terms(entry)` (`KoncluiFeatureRegistry.swift`) | no result for a page or block whose flag is off, for a service whose pill is off, nor for the open/close hotkey the hub shows on Atalhos only |
| `App/IslandViewContent.swift` | the model picker also lists `p.koncluiAnswersBySubscription(state)` (`KoncluiChatAccess.swift`) | a provider whose subscription switch is on and whose tool is installed shows without a key |
| | `TerminalTarget.activate(…, task: task.id)` (two places) | the click opens the clicked card's own Orca terminal |
| `App/IslandWindowController.swift` | `TerminalTarget.activate(…, task: state.focusTask?.id)` | the same for the shortcut |
| `App/TerminalTarget+AppKit.swift` | `activate(sessionBundleId:task:)`: the Orca terminal of `OrcaTerminals.terminal(task:)`; the pill's owner only when no card is given | a popped-out card (0.5.8's board) opens its session, and a card whose session is unknown opens Orca as it is, never another session |
| `App/HookServer.swift` | `write(_:waiting:client:to:)`: `OrcaTerminals.shared.shown(task:session:)` | which session each card shows, for the line above |
| `App/CLIRelayRun.swift` | removes `KoncluiCLI.routingVariables` from the relay's environment | a shell started from klaude or Orca must not send a subscription elsewhere (as `KoncluiChat`) |
| `App/ClaudeService.swift` | `sendMessage`: `KoncluiChat.route(for:state:context:)` first (every AI on its subscription, the proxy; the turn's context, since a file it brings makes the turn offline), then Coucou's relay | Koncluí's engine answers every subscription CLI (ADR-009) |
| `App/AppState.swift` | `fetchModelsIfNeeded`: Claude's subscription lists `KoncluiClaudeCLI.models` (without "default") instead of `claudeCodeModels`, which stays upstream's | Claude Fable in the list |
| | init: `KoncluiChatMigration.run(ud)` before any chat setting is read | a stored `claude-code`/`codex` choice (and Claude Code's model) becomes Anthropic/OpenAI with the switch on |
| `App/ClaudeService.swift` | `conversationHoldsMail` reads `KoncluiChat.shared.outside.mail`, and `KoncluiChat.shared.receive(mail:context:)` runs after Mail adds the messages, before any route: one record of email and dropped files for the whole conversation, whichever route answers (an API key's turn included); `KoncluiChat.route` takes a tool that can turn its web off (Gemini rather than Antigravity; Cursor too), and refuses the turn with `konclui.mail.needs-offline` when the installed tool cannot (Antigravity alone); the Anthropic API gets no web search tool; `KoncluiChat.shared.chat(…, extraSystem:)` | an email written to steer the model cannot make it fetch a URL; Koncluí's routes get Mail's plan format |

`scripts/konclui/test-note-speech.sh` fails when an upstream merge brings back a `Parakeet.shared.isReady` gate in
`NoteTaker.swift` or `FlowHubHome.swift`, or drops one of these hooks.

## Resolved decision

- Korean and Japanese were kept in the 16-language Mac build, and Koncluí-owned catalog and permission strings were translated. Shared upstream COPY rules remain in 14 languages. **Decision: kept and translated, 2026-10-31.**

## Open items

- The chat adapters for Gemini CLI, Antigravity and Copilot follow their official sources but were never run (the CLIs
  are not on the Mac that built them; ADR-009). Run `KONCLUI_CHAT_LIVE=1 scripts/test-konclui-chat.sh` on a Mac that has
  them once its live probe covers them. Copilot keeps the relay's format until its `-p` JSON events are documented or
  captured; `--session-id` would then give it a thread. Antigravity's FAQ says wrapping `agy` in a third-party app is not
  supported under consumer plans: the owner decides whether Koncluí keeps offering it.
- `hub.cleanup-key`, `flow.ai-privacy`, `hub.cleanup-privacy` are no longer read by any page (upstream keys, kept so a merge still finds them);
  `notes.engine-detail` is read through `KoncluiClaudeAccess.notesDetailKey` when the source is the key.
- The failure line of a Notetaker feature is the last one for the app, not per note: after a failed summary of one call the Ajustes page
  says "the notes of this call were left as they were" until any summary succeeds. The note's own page does not show it.
- The voice proxy's deadline is 10 s for a whole turn (A3-29). A turn that really needs more (a slow web search through the proxy) now
  falls to the phrase parser and shows "O Koncluí Proxy demorou demais"; raise `KoncluiVoiceBrain.turnDeadline` if that happens on a
  healthy day.
- A key saved while the Keychain refuses (A3-28) works until Koncluí quits (the store keeps it in memory) and the line says so; the old
  value is already deleted by upstream's delete-then-add. The WhatsApp block (`KoncluiWhatsAppSection`) and the crypto portfolio still save
  without reading the answer.
- The APPSTORE target does not build: `.koncluiPrimary` / `.koncluiSecondary` (written by `rebrand.py`) and `KoncluiStatus` are
  `#if !APPSTORE`, and shared files already use them (ShortcutsSettingsView, SettingsView, now KoncluiAgentRow). The hooks U7 added to shared
  files that need Konclui types carry the guard (Atalhos, the recorder, the recap clear); `KoncluiAgentRow.swift` does not.
- `ShortcutsSettingsView` still draws the conflict tags and the group titles with upstream's greys and 10 pt text (`conflictTag`); not an
  agent file, left as is.
- Latency measured on the owner's Mac (6 runs of the live check, clean-up of a 13-word sentence through the proxy, haiku): 1.9
  to 2.2 s, once 3.4 s, against the 4 s timeout. About 0.3 s of it is reading klaude's token from the Keychain for the call
  (`security` takes 0.3 s on this Mac). The direct API answered in about 1 s. A slower proxy day shows up as the "took too long"
  notice, once per streak.
- Prompt mode and translation have no Apple Intelligence route on purpose (a small on-device model is not good at a structured
  prompt or a translation); the "connect" line says so.
- The wake word in Portuguese was tested as text ("okei Kôru adiciona…"), never with a real voice. If the recognizer
  writes it in another way, add the spelling to `WakePhrase.normWord` (the Portuguese line above the upstream one).
- The "Pronto"/"Zera"-style sentences are written for a Brazilian ear but have not been read aloud by Luciana or
  Felipe yet; listen to the sample in Settings → Voice before shipping.
- `voice.mac-voices-help` still names English voices only ("Ava para mulher, Jamie para homem"). A pt-BR line
  for Luciana and Felipe would be a catalog copy rule (U2's domain).
- The catalog message after "adiciona o Stripe e o Notion" reads "Stripe, Notion adicionado" (upstream's
  `voice.pill-added`, singular): a copy rule for the plural would fix it.
- Approving or denying a permission by voice does not exist upstream (never without a click); nothing was added.
- ElevenLabs: `language_code` is not sent; the model detects Portuguese from the text. If an account's voice is
  heavily accented, label a Portuguese voice in the account (it is picked first).
- A2-34 (is the panel's 20 pt corner concentric with the macOS 26 window?): not changed. A concentric radius is the window's radius minus the
  10 pt inset; the window's radius cannot be read from SwiftUI, and 20 is already the floor. Measure on a Mac with a ruler before touching it.
- The note title in the Notetaker (24 pt) is the only size outside the seven type roles; kept (a document title is not a page title).
- Turkish still says "ada" (island) for the notch: Turkish upstream chose it everywhere (about 17 strings); a Turkish speaker
  should pick the word before it changes.
- The six crypto-portfolio instruction strings (`portfolio.instructions.*`, `portfolio.error.coinbase-key`, `portfolio.testing`)
  have no pt-BR (the integration ships off). Reminders now read in 13 languages (its page, Lembretes, exists since U3c).
- Russian "voice.setting-web" and "voice.setting-web-desc" (unused in the app) still carry a dash and « » in pt-BR.
- The public home (A3-33): `FORK` in `rebrand.py` still says `heslanx/coucou`; the weekly recap and the updater show it. Needs the
  owner's repository before it changes.
- SMAppService's status (`launchAtStartup`) is still read in a `@State` initializer: it is one call to the system, not a file
  read, and moving it would make its `onChange` register or unregister the app by itself (A3-19 PARTLY).
- Walk in the running app: the review of an install (Codex), of a removal (Claude Code, with the owner's own hooks present), the
  removal popover on Geral (do not press "Remover" on the owner's Mac), the 4-tab limit, the connect card, Lembretes.
- The Notetaker screen was typechecked and built, not walked in the running app (the unit may not launch Koncluí): the
  engine row, its popover, the install progress under the live call and the failed state with "Try again" still need a look,
  with Parakeet installed (nothing new may show), without it, and with the language files missing.
- Install progress shows in the Notetaker screen only; a call started from the pill with the window closed installs
  silently, and a failed install shows on the note (failed, with the audio kept and "Retry").
- Apple's speech has no diarizer: "Person 2" is everyone but you. Renaming a person and moving a line (`assign`) work as before.
- The proxy answers the model id `claude-haiku-4-5` (probed through klaude, 2026-10-30); whether it accepts the server tool
  `web_search_20250305` is not probed. The code
  handles both refusals (retry without the tool; then the model chosen for the chat), so the first Claude turn after turning
  it on may cost up to four requests; what worked is remembered until the app quits.
- Anyone who had an Anthropic key saved and relied on Claude as the voice brain gets Apple Intelligence until they turn the
  opt-in on (before, a saved key was enough).
- When Claude is on and a turn fails, the phrase parser answers and Apple Intelligence is skipped (upstream's guard, kept);
  Settings → Voice shows "Couldn't reach Claude on the last try".
- "Request permissions" does nothing when macOS has the microphone or speech recognition on "denied" (the system asks once);
  the new reason line then says so and offers "Open System Settings".
- Portuguese speakers: see the K13 return (listening follows the Mac's dictation language, the phrase parser and the answer
  language are English and French only).
- "OK Koru" is checked on transcripts only (`scripts/test-voice-wake.sh`); how often the
  recognizer writes it in a spelling the list misses needs a try on a real Mac.
- Koru's gender in ar, bn, hi, id, th, tr, zh: names are replaced, agreement was not reviewed
  (hi verbs, for instance, stay masculine).
- A Developer ID team, provisioning profile and iCloud container for Koncluí, before Release
  builds, the updater and the iPhone link can work.
- Codex streams whole messages (its `--json` output has no token deltas), Claude Code and the proxy stream token by token.
- Claude Code and Codex keep the conversation in their own session files (`claude --resume`, `codex exec resume`),
  in Koncluí's chat folder above; "new conversation" forgets the thread, it does not delete the files.
- The proxy models have opaque ids; the picker shows the gateway's `display_name`.
- iPhone: only `ChatProvider` changed in CoucouKit; typechecked against the iPhoneOS 26.5 SDK (Swift 6, iOS 18), but the iOS 26.5 platform is not installed on this Mac so no `xcodebuild` of the iPhone scheme.
- Upstream merge: `rebrand.py` has no rule for the Claude installer's ownership test. After taking upstream's
  `HookServer.swift`, the installer's `contains("Coucou")` tests come back; re-apply `KoncluiHook.owns` there
  (`buildHooksData`, `hooksDataWithoutKoncluiEntries`) or add a `CODE` rule. `test-konclui-orca.sh` fails on the
  installer section if `KoncluiHook.owns` is missing.
- Approval cards of Codex, Copilot and Muse sessions in Orca show "Always" (the card hides it by pill id
  `agent_codex`/`agent_copilot`/`agent_muse`); the relay answers it as a plain allow for those agents.
- The hook command is `<Application Support>/Konclui/nb-hook`, written at launch by `installHookScript()`; klaude's
  hooks point to it, so klaude hooks work only while that file exists.

- Settings → Agents rows and the Active pills door were built and tested (`test-agent-rows.sh`), not walked in the running app
  (the unit may not launch Koncluí): the popovers' sizes with the longest Claude Code content, the focus ring around a row, the
  popover reopening when the row itself is clicked while it is open (the same behaviour as the WhatsApp Options button), and
  VoiceOver reading the row (name, status, hint) still need a look.
- The popovers hold the old blocks unchanged, so their sentences keep upstream's dashes ("Hooks installed — restart Codex…",
  `hooks.*.installed`, `hooks.outdated`, `status.*-hooks-installed`, the Hermes and plan texts): UX.md asks for none; rewriting
  those catalog entries is left to the copy pass (they are upstream's multi-line entries, so each rewrite is a merge conflict
  to re-apply).
- Uninstalling an agent whose tool is not on this Mac removes its row (a row shows while the tool is there or the hooks are
  installed), and the popover with it; the status message then shows in the window's bottom line.

## Distributing Koncluí (to do, needs the owner's Apple account)

Today only this Mac can run Koncluí: Debug builds are signed with the owner's Apple Development certificate
(`scripts/konclui/signing.sh`), and Release still carries Coucou's team and profile. Before anyone else installs it:

1. A paid Apple Developer Program membership for Koncluí, and a "Developer ID Application" certificate in it.
2. Release and ReleaseCloud signed with that team (a `FIXED` rule in `scripts/konclui/rebrand.py` on `NotchBuddy/project.yml`,
   so upstream merges keep it), hardened runtime on, and Koncluí's own iCloud container if the iPhone link is wanted.
3. Notarization (`xcrun notarytool submit … --wait`, then `xcrun stapler staple`) for every build that leaves this Mac.
4. Koncluí's update service (`updates/`): deployed on 2026-10-30 (KNC Easypanel, `backend/updates`, automatic deploy from
   `main`, `https://updates.konclui.com` live). Missing: its read-only GitHub token (`updates/scripts/set-github-token.py`,
   updates/README.md). Then `block_updates` can ship on. `MacUpdater` already asks it (ADR-002).
5. `FORK` in `rebrand.py` (the weekly recap image's link, today the public Coucou fork `heslanx/coucou`) pointed at
   Koncluí's public page, its website: there is no public repository (ADR-002).
6. Releases with `scripts/konclui/release.sh` (only Koncluí: its team, notary profile, `Konclui.zip`, `konclui-vX.Y.Z` tags
   and the release in the private `konclui/konclui-notch`), read by the app through Koncluí's update service (`updates/` on
   Easypanel, ADR-002). `--check` lists what is still missing. Upstream's `scripts/release.sh` (Coucou's profile,
   `Coucou.zip`, pushes to the public `origin`, publishes to `Louis-CFM/coucou`) stops at its first line in this fork.
   [WORKFLOW.md](docs/konclui/WORKFLOW.md), "Releases".

## Orca and klaude, as found on this Mac (read-only)

- Orca copies `~/.claude/settings.json` into each Claude profile home it launches agents with
  (`~/Library/Application Support/orca/claude-profiles/<id>/home/settings.json`, a separate file, not a link),
  then adds its own hook entries. Hooks installed in `~/.claude` reach Orca's Claude Code sessions the next time
  Orca prepares the profile (the copy made earlier still carries the previous entries until then). Orca's Codex
  home (`codex-accounts/<id>/home/hooks.json`) carries the `~/.codex/hooks.json` entries the same way.
- `~/.klaude/settings.json` is not hook-free: it holds a `PreToolUse` `Bash` hook (`rtk hook claude`). The merge keeps it.
- The Orca CLI runs with a bare environment (`env -i HOME PATH`), about 0.85 s per call.
