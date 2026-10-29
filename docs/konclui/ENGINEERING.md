# Koncluí: engineering rules

How code is written in Koncluí. The project rules in [CLAUDE.md](../../CLAUDE.md) (Swift 6, SwiftUI + AppKit, no third-party
dependencies, secrets in the Keychain, no telemetry, never block Claude Code, never overwrite another app's settings without
a preview and a confirmation) still apply. Product and interface rules are in [UX.md](UX.md); what the fork changes is in
[KONCLUI.md](../../KONCLUI.md).

## 1. Stay mergeable with upstream

Koncluí is a fork of Coucou and keeps pulling its updates (`KONCLUI.md`, "Upstream workflow"). Every change is judged by
what it costs at the next `git merge upstream/main`.

- Koncluí's code lives in **new files** named `Konclui*.swift` (and `Koru*.swift` for the character).
- An upstream file gets only a **small hook**: one call, one filter, one `if`, marked with a `// Koncluí:` comment and listed
  in `KONCLUI.md`, "Koncluí hooks in upstream files".
- Text that users see is rewritten by `scripts/konclui/rebrand.py`, not by hand. A new rule goes into the script so it is
  applied again after a merge; `python3 scripts/konclui/rebrand.py --check` must report 0 changes and 0 stale rules.
- Internal identifiers stay upstream's (targets, Swift types, UserDefaults keys). Pill IDs, feature flag IDs, chat provider
  raw values and hook markers are **stable contract values**: never rename one that shipped.
- New features ship behind a feature flag (`CoucouKit/KoncluiFeatures.swift`); deleting a feature for good is "delete its code
  and its registry line" (`KONCLUI.md`, "Feature flags").

## 2. Clean code

- **Names say what a thing is or does**, in the domain's words (`pillRecognized`, `KlaudeHooks.installed`), not `data`,
  `result`, `tmp`, `mgr`. A function named like a getter does not mutate.
- **Small functions, one job each.** Long views are split into named subviews; long functions into named steps.
- **Comments explain why** (a platform constraint, a rule from the owner, a trap), never what the next line does. Match the
  comment density and idiom of the surrounding file.
- **Errors are handled where they can be acted on** and surfaced to the person (UX.md, section 3): no empty `catch`, no `try?`
  that turns a failure into a silent default where the person needed to know.
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

## 4. Pragmatic programming

- **DRY is about knowledge, not text**: one source of truth per fact (the pill catalog, the flag registry, the glossary).
  Two copies of the same rule will drift.
- **Orthogonality**: a change in one feature should not ripple into unrelated ones; a feature flag off must leave the rest
  working.
- **Tracer bullets**: build the thinnest end-to-end path first (detection, then the row, then the action), then widen it.
- **Broken windows**: fix a known defect or record it in `KONCLUI.md`, "Open items"; never leave it silent.
- **Reversibility**: prefer decisions that are cheap to undo (flags, new files, small hooks) over ones that lock the fork in.
- **Design by contract**: state preconditions and what a function guarantees; check them in tests.

## 5. Simplification

- Simplify only **behaviour-preserving** code that is hard to read, after it works, scoped to what you changed.
- One simplification at a time, each followed by its tests; tests must pass **without** being modified (a test that has to
  change means behaviour changed).
- Prefer clarity over cleverness; do not inline a helper that gave a concept its name; do not merge unrelated logic.
- Refactors and features go in separate commits.

## 6. Verification before calling a change done

- Build: `cd NotchBuddy && xcodegen && xcodebuild -scheme NotchBuddy -configuration Debug build` (use a
  `-derivedDataPath` under `/tmp` for throwaway builds and delete it after; the disk is small).
- The tests of what you touched: `scripts/test-*.sh`, `scripts/konclui/test-*.sh`, `python3 scripts/test-localization.py`,
  `python3 scripts/test-whats-new.py`, and `python3 scripts/konclui/rebrand.py --check`.
- A screen or interaction change is walked in the running app (UX.md, section 7). The Debug build accepts
  `-konclui.debug.page <page>` to open the Koncluí window on a given page for screenshots.
- Report what ran, what passed, and what remains unverified.
