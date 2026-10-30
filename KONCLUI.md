# Koncluí

Koncluí is a fork of [Coucou](https://github.com/Louis-CFM/coucou) by Louis Raillé, for the Mac
only for now. Coucou's code is under the MIT licence (`LICENSE`, kept as is); its name, Mochi,
icon, sounds and artwork are reserved by their author (`LICENSE-ASSETS.md`), so Koncluí replaces
them: the name Koncluí, the character Koru, the icon and the sounds are Koncluí's own.

## Rules for everyone working on Koncluí

- [docs/konclui/UX.md](docs/konclui/UX.md): usability, microcopy, accessibility, the review gate and the UI polish pass.
- [docs/konclui/ENGINEERING.md](docs/konclui/ENGINEERING.md): code rules and how to stay mergeable with upstream.

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
- The notch chat can run through what the Mac is already signed in to, with no API key stored in Koncluí:
  Claude Code (the user's Claude login, `claude -p`), Codex (the ChatGPT login, `codex exec`) and the
  Koncluí Proxy (the Anthropic Messages API behind klaude, with klaude's own key). Settings → Chat lists them
  first (`KoncluiChatSubscriptionsSection`); the model picker shows them when the Mac is signed in to them.
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
5. `Localizable.xcstrings` (the coffee keys removed): keys (with the Swift literals that use them) and values in the 14
   languages, with per-language grammar for Koru (articles, pronouns, agreement in en, es, fr,
   pt-BR, de, ru).
6. `whats-new.json`: the item texts (the coffee item removed).

It is idempotent: a second run reports `0 files changed`. `--check` changes nothing and exits 1
when a run would change something. A rule whose old and new text are both gone is reported as
`STALE`: upstream changed that code and the rule needs a look.

`./scripts/konclui/test-hooks.sh` checks that Koncluí's hook handling never claims Coucou's
entries (no settings file is read or written).

Day to day: `./scripts/konclui/dev-install.sh` builds Debug and installs `/Applications/Konclui.app`
(it never touches `Coucou.app`).

## Upstream workflow

```
git fetch upstream
git merge upstream/main
# conflicts in brand files (project.yml, Info*.plist, Localizable.xcstrings, whats-new.json,
# Swift files the script edits): take upstream's side, then re-apply the brand
git checkout --theirs <file>          # for each conflicting brand file
python3 scripts/konclui/rebrand.py    # re-applies everything, runs xcodegen
python3 scripts/konclui/rebrand.py --check   # 0 files would change, 0 stale rules
./scripts/konclui/test-hooks.sh
cd NotchBuddy && xcodebuild -scheme NotchBuddy -configuration Debug build
```

New upstream strings that mention Coucou or Mochi are rebranded by the next run. A new string
where Koru needs a feminine form (an adjective or pronoun that pointed at Mochi) needs a rule in
`AGREEMENT` of `rebrand.py`.

## Functional ties

Places where the name, or Louis's identity, does something. Changed when users see it or when
Koncluí and an installed Coucou would clash running side by side; kept otherwise.

| Tie | Where | Koncluí | Why |
|---|---|---|---|
| Bundle id | project.yml, `AppState` fallback | changed: `com.konclui.mac` | separate product; also gives Koncluí its own UserDefaults domain, TCC entries and notifications |
| Product / executable name | project.yml `PRODUCT_NAME` | changed: `Konclui` (`Konclui.app`) | ASCII file name, no clash with `Coucou.app` |
| Display name, usage descriptions | project.yml → Info.plist | changed: Koncluí | users see them |
| Application Support folder | `HookServer.supportDir`, `RecapStore`, `SoundEngine`, GOWA dir, Reminders MCP path | changed: `~/Library/Application Support/Konclui` | holds the hook socket, hook scripts, notes, models, sounds: shared, the two apps would fight over the socket |
| Hook socket | `<support>/nb.sock`, nb-hook.py, `coucou-mcp.py` | changed (follows the folder) | Coucou binds its own |
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
| MacUpdater | `MacUpdate.owner/repo/bundleId`, asset `Konclui.zip` | changed: `heslanx/coucou`, `com.konclui.mac` | never installs Coucou's releases; `teamId` is still Louis's, so any download fails the signature check until Koncluí has its own Developer ID team (fails closed) |
| Weekly recap watermark | `WeeklyRecapView` | changed: `Koncluí · github.com/heslanx/coucou`, `konclui-weekly-recap.png` | users share it |
| Wake word | `WakePhrase` patterns and spellings, `WakeSpotter` hints, `VoiceQuery` fillers, every label | changed: "OK Koru" / "hey Koru" (also "ok coru", "corú", "koroo", "kourou", "ko ru"…); "OK Coucou" no longer wakes Koncluí | the two apps never answer the same phrase |
| iCloud container, CloudKit zone, Live Activity relay | `iCloud.fr.louisraille.Coucou`, zone `Coucou`, `coucou-relay.raillelouis.workers.dev` | kept | iPhone link, compiled only with `PHONE_LINK` (DebugCloud/Release); out of scope until Koncluí has its own container and relay |
| App Store build | target `CoucouAppStore`, `fr.louisraille.Coucou`, container socket | kept (display name changed) | not built for Koncluí |
| Signing team, profiles | DebugCloud / Release / ReleaseCloud (`256AUJ9555`, "Coucou Developer ID") | kept, marked in project.yml | need Koncluí's own team, profile and container |
| URL schemes | none on the Mac app (`coucou://` is the iPhone app's) | — | — |
| Launch at login | `SMAppService.mainApp` | nothing to change | per app |
| UserDefaults keys, notification ids, queue labels, `CoucouGitHash`, NSError domain `CoucouNoop` | many | kept | internal, scoped to the app's own domain or process |
| AppleScript / Apple events | `tell application id "com.apple.Music"` etc. | nothing to change | no Coucou name involved |
| Chat providers `claude-code`, `codex`, `konclui-proxy` | `ChatProvider` (CoucouKit/IslandTypes.swift), UserDefaults `chatProvider` | added; raw values are stable from now on. Pill ids `ai_claude_code`, `ai_codex`, `ai_konclui_proxy` are reserved in `ChatProvider.pillID` (no catalog pill yet) | the chat provider is persisted |
| Claude Code / Codex login | `KoncluiChat.swift`, `KoncluiChatProcess.swift` | the official `claude` / `codex` run as subprocesses (`claude -p … --safe-mode`, `codex exec --json --disable hooks -c sandbox_mode="read-only"`), prompt on stdin, in `~/Library/Application Support/Konclui/chat`; routing variables (`ANTHROPIC_*`, `CLAUDE_CONFIG_DIR`, `OPENAI_API_KEY`…) are removed from their environment | the CLIs keep their own credentials: Koncluí never reads their token files (their terms of use); a shell started from klaude or Orca must not send the subscription route elsewhere |
| klaude key | Keychain generic password, service `klaude-api-key`, account = user name | read when a request starts, with `/usr/bin/security … -w` as klaude does; presence checked without `-w`; kept in a local variable, never stored in Koncluí's Keychain items or UserDefaults, never logged, wiped from server error text | the key is klaude's, not Koncluí's |
| Koncluí Proxy address | `proxy_url=` in `~/.local/bin/klaude`; override: UserDefaults `konclui.proxyURL` | https only (http only for localhost) | network calls only to the proxy the user installed |
| Hooks during a chat turn | `claude --safe-mode`, `codex --disable hooks` | on | Koncluí's own hooks would show the chat as a session in the notch |
| Orca pill | `HookServer.processEvent`, `processPermissionRequest`, `processQuestionRequest` (`isOrcaSession`, first branch of the routing); `ClaudeHost.isOrca` / `orcaPillId` / `termPrograms["orca"]` | added: `TERM_PROGRAM=Orca` or bundle id `com.stablyai.orca` → `agent_orca`, for every agent kind that runs in the terminal, before the Codex / `coucou_agent` / Cursor / VS Code / terminal routes (those are unchanged for every other client) | one pill for what runs in Orca; approvals and questions of those sessions use the same pill so the queue still matches their events |
| Orca terminal in the hook payload | nb-hook.py `add_orca_context` (GitHub and App Store scripts) | added: `orca_terminal` (`ORCA_TERMINAL_HANDLE`) and `orca_worktree` (`ORCA_WORKTREE_ID`), when set | the click needs the handle; no other `ORCA_*` value is read, the hook token never leaves the terminal |
| Orca click | `TerminalTarget.activate` (`TerminalTarget+AppKit.swift`, one `if` for Orca's bundle id), `ClaudeHost.switchOrcaTerminal`, `OrcaTerminals` (`KoncluiOrca.swift`) | added: runs `<Orca.app>/Contents/Resources/bin/orca terminal switch --terminal <handle>` off the main thread (bare environment `HOME`/`PATH`, killed after 5 s), then activates Orca; no handle, or no CLI: only activates Orca | covers the pill click, the finished/error "Open terminal" buttons and ⌃⌥T; the handle is the one of the session that owns the pill's card (same owner rule as its name) |
| klaude hooks | `HookServer.previewClaudeHooks(at:install:)`, `writeClaudeHooks(at:)`, `uninstallClaudeHooks(at:)` (the `~/.claude` installer, now parameterized by settings path), `KoncluiAgentHooks.swift` (`KlaudeHooks`, `KlaudeHooksSection`) | added: the same 12 Claude Code hooks plus the AskUserQuestion one, installed into `~/.klaude/settings.json`; dated backup, merge, JSON preview, written only after the user confirms; Uninstall previews and removes only Koncluí's entries | klaude starts Claude Code with `CLAUDE_CONFIG_DIR=~/.klaude`, which never reads `~/.claude/settings.json` |
| "Is this Claude hook ours?" | `HookServer.buildHooksData(at:)`, `hooksDataWithoutKoncluiEntries(at:)` | changed: `KoncluiHook.owns` (command runs `konclui/nb-hook`) instead of "contains Konclui/konclui" | a foreign hook whose path only mentions konclui (for example under `~/Developments/konclui-project/…`) was replaced at install and deleted at uninstall |
| Claude opt-in | UserDefaults `voiceClaudeBrain` (`VoiceSettings.claudeBrainEnabled`) | now read by `ClaudeVoiceBrain.isActive` and set by Settings → Voice; off by default | the words leave the Mac only after the person turns it on |
| klaude key for the voice | Keychain generic password, service `klaude-api-key` | read with `KoncluiProxyAccess.readKey()` when a voice call starts, kept in a local variable, never stored, logged or shown; server error text is wiped of it; the logs hold the HTTP status only | same rule as the notch chat (K10) |
| Brain order | `KoncluiVoiceBrain.brain` | Claude (opt-in, subscription before key) > Apple Intelligence > phrase commands | owner decision D13: the lightest way is the default |
| Apple speech language files | `AssetInventory`, `SpeechTranscriber.installedLocales` (system-managed, outside Koncluí's folders) | installed on the first recording when missing; nothing is written to Koncluí's Application Support; `AssetInventory.status` answers "supported" for an installed language, so the installed list is asked instead | the Mac's own files, small, shared with other apps |
| Parakeet models | `Application Support/Konclui/Models` | untouched; the choice reads `Parakeet.shared.isReady` | installed models keep winning |

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
  `integration_vercel`, `integration_n8n`, `integration_resend`, `integration_notion`, `integration_portfolio`.
  Everything else ships on.
- **Always on**: `integration_claude` (the main workspace pill until the user picks another). `KoncluiFeatures.required`.
- **Ids**: a pill is its PillCatalog id (`agent_orca` included); a page is `page_<HubPage case>` (`page_notes`,
  `page_voice`…); a Settings block is `block_iphone`, `block_recap` (Weekly recap), `block_vitals` (Koru and your
  Mac) or `block_reminders`. A service of Integrations follows its pill's id (`integration_notion`,
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
| Agents | its tool is on this Mac or its hooks, plugin or switch are already on. Claude and Codex plan gauges follow Claude Code or Codex. `KlaudeHooksSection` (K11) is always first |
| Chat | `KoncluiChatSubscriptionsSection` (K10) is always first. Anthropic API and the key-based providers: a key is saved. Ollama and LM Studio: a server is connected, or `ChatAccess` says one answers |
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
| | `activePillsSection`, `agentsSection`, `chatSection`, `integrationsSection` | recognized-only lists and the "Add…" menu; `KlaudeHooksSection()` and `KoncluiChatSubscriptionsSection()` at the top of Agents and Chat |
| | `extension SettingsView` at the end | the signals the screens feed `KoncluiRecognition` |
| | `KoncluiWhatsAppSection()` in place of `WhatsAppSettingsSection()` in `integrationsSection`, shown also when `KoncluiWhatsAppDebug.forcesBlock` | the new WhatsApp block (one line, popover, notch preview). `WhatsAppViews.swift` is untouched and still holds the old block, the notch card and the rows the preview reuses (`WhatsAppRow`, `WhatsAppStatus`); the new block repeats the old one's Advanced fields and save logic, and the preview repeats `WhatsAppCardView`'s header and status layout: after an upstream merge, mirror changes to those two places. DEBUG only, for screenshots: `-konclui.debug.whatsappState` with `fresh`, `installing`, `qr`, `connected`, `stopped`, `unauthorized`, `failed`, `connecting`, `off` or `noroom` draws that state (no setting, Keychain item or gateway is read or written), and `-konclui.debug.whatsappPopover` with `options`, `ignored` or `advanced` opens the popover |
| | `agentsSection`: each block's `GroupBox(String(localized: "hooks.<agent>.title")) {` line (Claude Code, Gemini, Antigravity, Codex, Copilot, Muse, OpenCode, Amp, Hermes, Plan usage: 10 lines, each marked `// Koncluí: row + popover`) is `koncluiAgentRow(.<block>, .<kind>, installed: …) {`; the content closures, the `@State` and the install methods are untouched | every agent is a row with a popover (`KoncluiAgentRow`); a merge that brings a `GroupBox` back is caught by `test-agent-rows.sh` |
| | `pillRow`: the three-line `Text(h)…` hint became `koncluiHint(h, for: def)`; the hint computation above it is untouched | "Hooks not installed" and "Plugin not installed" are doors for the seven agent pills that have one (`KoncluiAgentRows.door(forPill:)`) |
| | `body`: `&& !koncluiPopoverOpen` on the bottom message; `onAppear` calls `koncluiDebugPreview()`; two `@State` (`koncluiOpenAgent`, `koncluiDoorPill`) | the open popover shows the message itself; the DEBUG `:preview` flag; which popover is open |
| | `extension SettingsView` (Agents part): `koncluiAgentRow`, `koncluiPopoverBinding`, `koncluiPopoverOpen`, `koncluiHint`, `koncluiDoor`, `koncluiDoorPopover`, `KoncluiHookWiring` / `koncluiHookWiring` (each agent's preview, confirm and cancel by block), `koncluiDebugPreview`; `koncluiAgentShown` also true for the DEBUG flag's agent | the row helper and the door; no logic of the old blocks is copied |
| `App/ClaudeDesktopChatWatcher.swift` | `ClaudeDesktopChatSettingsSection`: its `GroupBox(String(localized: "claude-desktop.chat.title")) {` line is `KoncluiAgentRow(id: "claudeDesktop", …) {` | the only upstream line outside `SettingsView` for the rows; `KlaudeHooksSection` is Koncluí's own file and builds its row the same way |
| | `FlowHubView.body`: `.disclosureGroupStyle(KoncluiDisclosureStyle())` | every disclosure in the window opens from its whole label (`App/KoncluiDisclosureStyle.swift`) |
| `App/IslandViewContent.swift` | `AgentPill.displayName` and `MusicPill`'s title go through `KoncluiTabLabel.short` | a tab's name fits in 11 characters: "Claude Desk" (`App/KoncluiTabLabel.swift`, `scripts/konclui/test-tab-label.sh`) |
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
| `Resources/Localizable.xcstrings` | 14 `konclui.*` keys, 14 languages; 69 `konclui.whatsapp.*` keys, 14 languages; 2 `konclui.disclosure.*` keys; 20 `konclui.voice.*` keys; 14 `konclui.notes.speech.*` keys; 10 `konclui.agents.*` keys | the Features screen and "Add…"; the WhatsApp block and its notch preview; the disclosures' VoiceOver state; Settings → Voice (who understands you, the Claude opt-in; `voice.setting-web-desc` and `voice.setting-web-nokey` stay in the catalog, unused); the Notetaker's engine row, popover and install messages; the status words, the row's VoiceOver hint and the install door of Settings → Agents and Active pills |

`scripts/konclui/test-note-speech.sh` fails when an upstream merge brings back a `Parakeet.shared.isReady` gate in
`NoteTaker.swift` or `FlowHubHome.swift`, or drops one of these hooks.

## Open items

- The Notetaker screen was typechecked and built, not walked in the running app (the unit may not launch Koncluí): the
  engine row, its popover, the install progress under the live call and the failed state with "Try again" still need a look,
  with Parakeet installed (nothing new may show), without it, and with the language files missing.
- Install progress shows in the Notetaker screen only; a call started from the pill with the window closed installs
  silently, and a failed install shows on the note (failed, with the audio kept and "Retry").
- If macOS asks for Speech Recognition permission on the first Apple transcription, `NSSpeechRecognitionUsageDescription`
  says only "the text of a chat message". The framework call was proven in a command-line harness, not inside the signed app.
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
- `Info.plist` keeps two usage descriptions in French (Apple events, Accessibility), as upstream.
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

## Orca and klaude, as found on this Mac (read-only)

- Orca copies `~/.claude/settings.json` into each Claude profile home it launches agents with
  (`~/Library/Application Support/orca/claude-profiles/<id>/home/settings.json`, a separate file, not a link),
  then adds its own hook entries. Hooks installed in `~/.claude` reach Orca's Claude Code sessions the next time
  Orca prepares the profile (the copy made earlier still carries the previous entries until then). Orca's Codex
  home (`codex-accounts/<id>/home/hooks.json`) carries the `~/.codex/hooks.json` entries the same way.
- `~/.klaude/settings.json` is not hook-free: it holds a `PreToolUse` `Bash` hook (`rtk hook claude`). The merge keeps it.
- The Orca CLI runs with a bare environment (`env -i HOME PATH`), about 0.85 s per call.
