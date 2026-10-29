# Koncluí

Koncluí is a fork of [Coucou](https://github.com/Louis-CFM/coucou) by Louis Raillé, for the Mac
only for now. Coucou's code is under the MIT licence (`LICENSE`, kept as is); its name, Mochi,
icon, sounds and artwork are reserved by their author (`LICENSE-ASSETS.md`), so Koncluí replaces
them: the name Koncluí, the character Koru, the icon and the sounds are Koncluí's own.

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

## Open items

- "OK Koru" is checked on transcripts only (`scripts/test-voice-wake.sh`); how often the
  recognizer writes it in a spelling the list misses needs a try on a real Mac.
- Koru's gender in ar, bn, hi, id, th, tr, zh: names are replaced, agreement was not reviewed
  (hi verbs, for instance, stay masculine).
- `Info.plist` keeps two usage descriptions in French (Apple events, Accessibility), as upstream.
- A Developer ID team, provisioning profile and iCloud container for Koncluí, before Release
  builds, the updater and the iPhone link can work.
