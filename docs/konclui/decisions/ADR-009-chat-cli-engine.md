# ADR-009: One chat engine for every subscription CLI

## Status

Accepted on 2026-10-31, at the owner's request ("give Gemini, Cursor and Copilot what is better in Koncluí's engine, as
far as each CLI really supports it"). Extends [ADR-008](ADR-008-chat-subscriptions.md), which kept Gemini, Cursor and
Copilot on Coucou's relay.

## Context

After ADR-008, Claude and ChatGPT were answered by `KoncluiChat` (streamed answer, the CLI's own thread, a new message
stops the old run, a sign-in line with the plan) and the other three AIs by Coucou's `CLIRelay` (the whole answer when
the tool ends, no stop, the whole conversation sent again each turn). `KoncluiChat` had one hand-written turn per CLI.

## Decision

One engine, one adapter per CLI (`App/KoncluiChatAdapters.swift`). An adapter is a pure value: the command line and the
files the CLI reads for a turn, how it takes the system prompt (`.flag`, `.firstTurn`, `.everyTurn`) and a dropped file
(`.readsCopy`, `.images`, `.text`), a stream that reads its output into the answer, the thread and the failure, and the
answer of a run the stream could not read that still ended with 0 (`fallbackAnswer`: by default the relay's own reading
of that CLI, `CLIRelay.parse`, else the plain lines; Copilot's, the plain lines only). The engine (`KoncluiChat.run`)
knows no CLI and no output format: it runs the process with `KoncluiCLI.routingVariables` removed, writes the adapter's
files (a file that cannot be written stops the turn), streams the answer, kills the process tree on a new message, Clear
or Quit, retries once when the adapter has a fallback run (Claude Code without `--safe-mode`), keeps one thread per CLI,
and asks the adapter for `fallbackAnswer` when the stream gave no text. Never a blank answer: else the CLI's error, its
stderr or "No response text."; the 300 s timeout stays.

Claude Code and Codex moved onto the adapter shape because it removed their two near-identical turns; their command
lines and streams (`KoncluiChatCore.swift`) did not change. Routing (`KoncluiChat.route`) picks the provider's first
installed tool, or, for a conversation that holds email, the first that can turn every web tool off
(`SubscriptionCLI.koncluiTurnsWebOff`: all but Antigravity). Coucou's relay now only says that no installed tool can
answer such a conversation; it no longer runs a CLI in Koncluí.

| | Streaming | Thread | Stop | Sign-in line | Isolation | Checked |
|---|---|---|---|---|---|---|
| Claude Code | token by token | `--resume` | yes | plan (`auth status`) | unchanged (ADR-008) | live (ADR-008); on 2026-10-31 the account's weekly limit came back as the CLI's own words |
| Codex | message by message | `exec resume` | yes | method (`login status`) | unchanged (ADR-008) | live, two turns, 2026-10-31 |
| Cursor | token by token (`--stream-partial-output`) | `--resume` | yes | plan (`about --format json`: "Seu plano · Ultra") | below | live, cursor-agent 2026.10.19-6bbf2c4 |
| Gemini CLI | token by token (`stream-json`) | `--resume <session_id>` | yes | none (no status command) | below | source and docs, fixtures |
| Antigravity | `text_delta` steps (`stream-json`) | `--conversation <id>` | yes | none (no status command) | the relay's (no switch) | docs, fixtures |
| Copilot | the relay's plain text, line by line if it prints so | none: the conversation is sent again | yes | none (no status command) | the relay's | docs, fixtures |

**Cursor.** `cursor-agent -p --output-format stream-json --stream-partial-output --mode ask --trust`, the prompt on
stdin (checked: it reads it there), in Koncluí's chat folder. Ask mode alone reads the whole disk (checked: it read a
file in `/tmp`), so every run denies `Read`, `Write`, `Shell` and `Mcp` everywhere, in the chat folder's
`.cursor/cli.json` and in Koncluí's own config folder (`CURSOR_CONFIG_DIR=…/Konclui/cursor`; deny always wins). That folder
also keeps out the user's allow list, approval mode and web auto-accept, and holds the chats Koncluí starts (Cursor
still writes their transcripts and the folder's trust under `~/.cursor/projects/<the chat folder>`); the model chosen in
the user's `~/.cursor/cli-config.json` is carried over. Web search runs only with `autoAcceptWebSearch` and
web fetch only when allowed: both are on for the chat and off once the conversation holds email or a dropped file, so
Cursor now answers a conversation with email. Checked live: streaming, the second turn remembers the first, the sign-in
and plan, a read outside is refused ("Permission denied"), a web search with outside text is rejected, and stopping a
turn ends the CLI and the 27 processes under it. Signed out (an empty `HOME`): nothing on stdout, exit 1, "Error:
Authentication required. Please run 'agent login' first" on stderr, shown as Coucou's "sign in once" line. A dropped PDF
or image is named, not read (no folder can be allowed while all reads are denied); text files go in the prompt.

**Gemini CLI.** As the relay (`-p`, plan mode, `--skip-trust`, `--extensions none`, `--allowed-mcp-server-names
coucou-none`) with `--output-format stream-json` and a policy on every turn (`…/Konclui/gemini/chat-policy.toml`): no
file tool, no shell, no memory, and no `exit_plan_mode`, which a run with no one to ask allows and which leaves plan mode
for one that runs everything; the web tools are denied too while the conversation holds outside text. A lost session
("Invalid session identifier") starts a new thread.

**Antigravity.** As the relay (`-p`, `--mode plan`, `--disable-slash-commands`) with `--output-format stream-json` and
`--conversation`. The result's `response` is the answer when it differs from the streamed text, as the relay shows it.

**Copilot.** Its `-p --output-format json` events are not documented, so it keeps the relay's command line
(`CLIRelay.arguments`) and plain text, its conversation sent again each turn, now stoppable. `--session-id` (1.0.51)
would give it a thread; it waits for the JSON events to be documented or checked on a Mac that has Copilot.

Sources, read on 2026-10-31:

- Cursor: https://cursor.com/docs/cli/reference/output-format, …/parameters, …/permissions, …/configuration; the run
  above.
- Gemini CLI: https://github.com/google-gemini/gemini-cli at `main` (0.67.0-nightly.20261020; stable v0.66.0, 2026-10-27):
  `packages/core/src/output/types.ts` (stream-json, since v0.11.0, PR #10883), `packages/cli/src/config/config.ts`
  (`--resume`, `--policy` since v0.30.0, `--skip-trust`, `-e none`), `packages/cli/src/utils/sessionUtils.ts`,
  `packages/cli/src/validateNonInterActiveAuth.ts` (no sign-in: stderr only, exit 41), `docs/cli/session-management.md`
  (sessions are per project folder: Koncluí always runs in its chat folder).
- Antigravity CLI: https://antigravity.google/docs/cli/headless (stream-json since v1.1.8, 2026-07-28; `--conversation`),
  …/docs/cli/reference, …/docs/changelog (v1.4.10, 2026-10-29), …/docs/faq.
- Copilot CLI: https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-command-reference (`--output-format
  json` since 0.0.422, `--session-id` since 1.0.51), …/how-tos/copilot-cli/set-up-copilot-cli/authenticate-copilot-cli
  (`COPILOT_GITHUB_TOKEN`, `GH_TOKEN`, `GITHUB_TOKEN` override the login), https://github.com/github/copilot-cli
  changelog (1.0.105, 2026-10-27).

## Consequences

- Gemini, Cursor and Copilot gain the stop; Gemini, Antigravity and Cursor the streamed answer and the thread; Cursor the
  sign-in line and an isolation stricter than the relay's (no file read anywhere, no MCP, no web with outside text).
- Gemini CLI, Antigravity and Copilot are not installed on the Mac this was built on: their adapters follow the sources
  above and are tested on fixtures; a run in a format they do not read falls back to the relay's reading.
- What no CLI lets a run switch off stays as with the relay: the user's hooks for Cursor (`~/.cursor/hooks.json`; checked:
  `CURSOR_CONFIG_DIR` does not move them), Gemini CLI, Antigravity and Copilot; GEMINI.md; Antigravity's MCP servers,
  plugins and web (its headless defaults refuse them unless the user's settings allow them).
- A dropped text file goes in the prompt whole up to the relay's limit, 200 KB of UTF-8 (`CLIRelay.inlineText`, one
  source for every CLI; Claude Code and Codex cut it at 24,000 characters before), else by its name. Claude Code, Codex
  and Cursor get it on stdin, the others in the `-p` argument as the relay sends it (the Mac's argument space is 1 MiB).
- A conversation that moves from Antigravity to Gemini CLI (Mail turned on mid-way) starts Gemini's own thread without
  the turns before.
- With the web off, the system prompt no longer says the model can search the web (Claude Code included).
- Antigravity's FAQ says wrapping `agy` in third-party applications is not supported under consumer plans. The relay
  already did it; the owner decides whether Koncluí keeps offering it.
- Rejected: keeping the relay for the three (no stop, no thread, the whole answer at the end); one turn function per CLI
  in the engine (the near-duplicate turns this replaces); running Copilot on undocumented JSON events.
