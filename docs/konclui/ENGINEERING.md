# Koncluí: engineering rules

How code is written in Koncluí. The project rules in [CLAUDE.md](../../CLAUDE.md) (Swift 6, SwiftUI + AppKit, no third-party
dependencies, secrets in the Keychain, no telemetry, never block Claude Code, never overwrite another app's settings without
a preview and a confirmation) still apply. Product and interface rules are in [UX.md](UX.md); what the fork changes is in
[KONCLUI.md](../../KONCLUI.md).

## 1. Stay mergeable with upstream

Koncluí is a fork of Coucou and keeps pulling its updates (`KONCLUI.md`, "Upstream workflow"). Every change is judged by
what it costs at the next `git merge upstream/main`. Which branch is the product, how a change reaches it and where it may be
pushed: [WORKFLOW.md](WORKFLOW.md) (the why: [ADR-001](decisions/ADR-001-branches-and-flow.md)).

- Koncluí's code lives in **new files** named `Konclui*.swift` (and `Koru*.swift` for the character).
- An upstream file gets only a **small hook**: one call, one filter, one `if`, marked with a `// Koncluí:` comment and listed
  in `KONCLUI.md`, "Koncluí hooks in upstream files".
- New strings go in with `scripts/konclui/add-strings.py <strings.json>` (`{"key": {"en": "...", "pt-BR": "...", ...}}`, all
  14 languages): one line per key at the top of the catalog, upstream's entries untouched. Units working in parallel hand in
  their JSON and one person merges them.
- Text that users see is rewritten by `scripts/konclui/rebrand.py` and its copy rules (`rebrand_copy.py`, data in
  `rebrand_copy_data.py`), not by hand: COPY (a key's upstream English and the new text in the 14 languages), SUBS (a fragment
  of a sentence), FILL (a language upstream never wrote), DASHES and PATHS (listed keys, never a blanket regex), FIXED (a
  hard-coded literal in an upstream view, pointed at a catalog key). A new rule goes into the table so a merge re-applies it;
  `python3 scripts/konclui/rebrand.py --check` must report 0 changes and 0 stale rules (a rule whose upstream English changed
  is reported as STALE). Brand-new strings of ours still go through `add-strings.py`.
- Internal identifiers stay upstream's (targets, Swift types, UserDefaults keys). Pill IDs, feature flag IDs, chat provider
  raw values and hook markers are **stable contract values**: never rename one that shipped.
- New features ship behind a feature flag (`CoucouKit/KoncluiFeatures.swift`); deleting a feature for good is "delete its code
  and its registry line" (`KONCLUI.md`, "Feature flags").
- **Spoken answers keep upstream's call sites.** Every spoken sentence upstream writes as `t("<French>", "<English>")`
  stays that line. Koncluí's Portuguese lives in `App/KoncluiVoicePhrases.swift`, found by the English sentence
  (`VoiceText` records the blanks), never as a third argument at the call site. After a merge,
  `python3 scripts/konclui/voice-pt-templates.py --check` lists the sentences that have no Portuguese yet.

## 2. Clean code

- **Names say what a thing is or does**, in the domain's words (`pillRecognized`, `KlaudeHooks.installed`), not `data`,
  `result`, `tmp`, `mgr`. A function named like a getter does not mutate.
- **Small functions, one job each.** Long views are split into named subviews; long functions into named steps.
- **Comments explain why** (a platform constraint, a rule from the owner, a trap), never what the next line does. Match the
  comment density and idiom of the surrounding file.
- **Errors are handled where they can be acted on** and surfaced to the person (UX.md, section 3): no empty `catch`, no `try?`
  that turns a failure into a silent default where the person needed to know.
- A write that can be refused (the Keychain, a file) returns its status and the screen that offered "Save" shows it; `@discardableResult` keeps
  the signature compatible for callers that cannot act on it.
- **Leave the code cleaner than you found it**, within the scope of your change (boy-scout rule), without drive-by refactors.

## 3. Architecture: the dependency rule

- **Pure logic in its own files**, free of SwiftUI, AppKit and singletons, so it can be tested with `swiftc` alone: detection
  (`KoncluiRecognition.swift`), flags (`KoncluiFeatures.swift`), chat parsing and request building (`KoncluiChatCore.swift`),
  routing rules, preview rules. Views and AppKit glue call it; it never calls them.
- **Side effects at the edges**: subprocesses, the Keychain, files and the network sit behind small types
  (`KoncluiChatProcess`, `KoncluiCLILocator`, `ClaudeSettingsFile`) with timeouts and off the main thread.
- **CoucouKit is shared with the iPhone targets**: code there must compile for iOS (no AppKit, no Mac-only paths); keep Mac-only
  code in `Sources/App`.
- **Contracts between parts are written down** (a protocol, a struct, a documented function) before two people code against
  them.
- **A view never reads an agent's file** in its body or in a `@State` initializer. `KoncluiHookStatus` reads what Koncluí wrote
  once, off the main thread, when a page appears and after an action; views read its last answer and show "Verificando…"
  until the first read ends. Anything that parses a user's file to build a view goes through it.
- When the same popover content serves several entry points (the Agents row, the Active pills door), it is one component fed
  by one state (`KoncluiHookControls`), not a copy per entry point.
- **One door per service.** A service reached from several features (Claude for clean-up, prompt mode, translation and the
  Notetaker) has one pure file for the choice of source and the request (`KoncluiClaudeAccess.swift`), one sender with no app
  dependency (`KoncluiClaudeSender.swift`, tested with a stub network) and one live type (`KoncluiClaudeLive.swift`); an upstream
  call site keeps its prompt and its reply handling and replaces only the transport with one call.

## 4. Pragmatic programming

- **DRY is about knowledge, not text**: one source of truth per fact (the pill catalog, the flag registry, the glossary).
  Two copies of the same rule will drift.
- **Orthogonality**: a change in one feature should not ripple into unrelated ones; a feature flag off must leave the rest
  working.
- **Tracer bullets**: build the thinnest end-to-end path first (detection, then the row, then the action), then widen it.
- **Broken windows**: fix a known defect or record it in `KONCLUI.md`, "Open items"; never leave it silent.
- **Reversibility**: prefer decisions that are cheap to undo (flags, new files, small hooks) over ones that lock the fork in.
- **Design by contract**: state preconditions and what a function guarantees; check them in tests.
- **One deadline per wait.** A turn that waits on a network service (the voice proxy: 10 s) has one deadline across its models and retries
  (`KoncluiVoiceBrain.timeLeft`), and the request is raced against the clock because a request's own timeout only counts the silence
  between bytes.

## 5. Simplification

- Simplify only **behaviour-preserving** code that is hard to read, after it works, scoped to what you changed.
- One simplification at a time, each followed by its tests; tests must pass **without** being modified (a test that has to
  change means behaviour changed).
- Prefer clarity over cleverness; do not inline a helper that gave a concept its name; do not merge unrelated logic.
- Refactors and features go in separate commits.

## 6. Verification before calling a change done

- Build: `cd NotchBuddy && xcodegen && xcodebuild -scheme NotchBuddy -configuration Debug build` (use a
  `-derivedDataPath` under `/tmp` for throwaway builds and delete it after; the disk is small).
- Day to day: `./scripts/konclui/dev-install.sh`. It builds the Debug configuration optimized (`-O`, as upstream's daily
  DebugCloud: unoptimized Swift costs about twice the CPU for Koru's drawing) and signs with your own "Apple Development"
  certificate when the Mac has one (`scripts/konclui/signing.sh`), so macOS keeps Koncluí's Keychain and privacy
  permissions across builds; without one it builds ad hoc and macOS asks again after each build.
- The tests of what you touched: `scripts/test-*.sh`, `scripts/konclui/test-*.sh`, `python3 scripts/test-localization.py`,
  `python3 scripts/test-whats-new.py`, `python3 scripts/konclui/test-copy.py`, `scripts/konclui/test-key-name.sh`, `scripts/konclui/test-flow-pages.sh`,
  `scripts/konclui/test-final-wiring.sh` (the wiring of the last hand-offs, the key save's answer, the new strings),
  `scripts/konclui/test-claude-access.sh` and `scripts/konclui/test-voice-brain.sh` (the notes sentences, the deadline), and
  `python3 scripts/konclui/rebrand.py --check`.
- A screen or interaction change is walked in the running app (UX.md, section 7). The Debug build accepts
  `-konclui.debug.page <page>` to open the Koncluí window on a given page for screenshots.
- Report what ran, what passed, and what remains unverified.
