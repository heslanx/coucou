# ADR-008: The chat on the user's subscriptions

## Status

Accepted on 2026-10-31, at the owner's request ("see how Coucou did it; if it is better, we implement it"). Extended
the same day by [ADR-009](ADR-009-chat-cli-engine.md): Koncluí's engine answers Gemini, Cursor and Copilot too.

## Context

Koncluí added chat through what the Mac is signed in to before Coucou did: two providers of its own, `claudeCode` and
`codex`, answered by `KoncluiChat` (`claude -p` stream-json, `codex exec --json`), plus the Koncluí Proxy. Coucou 0.5.8 then
shipped "Your AI subscriptions": a switch on its existing providers (Anthropic, Google, OpenAI, Cursor, Copilot), answered by
`CLIRelay` (`CLIRelay.swift`, `CLIRelayRun.swift`). After the sync both existed side by side, with Claude and ChatGPT in two
places.

What each did better, read in the code on 2026-10-31:

| | Koncluí's `KoncluiChat` | Coucou's `CLIRelay` |
|---|---|---|
| Reach | Claude, ChatGPT | Claude, Gemini (Antigravity or Gemini CLI), ChatGPT, Cursor, Copilot |
| The answer | Claude's streams token by token, Codex's message by message (the screen refreshes up to 15 times a second) | arrives whole when the tool ends (up to 180 s of waiting) |
| A new message, Clear, Quit | stops the running CLI and its helpers | the old run goes on until it ends |
| The conversation | the CLI's own thread (`--resume`): each turn sends only the new message | the whole conversation is sent again every turn |
| Sign-in | checks `claude auth status`, `codex login status`; shows the plan | knows the tool is installed; a turn says when it is signed out |
| Models | Claude's aliases with Fable | Claude's aliases without Fable; the others use the tool's default |
| Isolation, Claude | `--safe-mode` (no CLAUDE.md, skills, plugins, hooks, MCP), web tools only; **an older CLI retried without it kept nothing** | `--setting-sources ""`, `--strict-mcp-config`, `--disable-slash-commands`, web tools only |
| Isolation, Codex | read-only sandbox, hooks off, **shell on** (it reads the whole disk), **the user's config loaded** (its MCP servers too) | read-only sandbox, shell, apps, plugins and hooks off, `--ignore-user-config`, `--ignore-rules` |
| A dropped file | its text in the prompt, **web still on**; Claude gets a PDF or an image only by name (Codex takes an image) | no web while a file is read; Claude reads an isolated copy (PDFs, images), **with Read allowed anywhere** |
| Settings | a section of its own, with the providers as separate entries | one switch per AI, on the provider people already know |
| Cost at each sync | `ChatProvider` cases in seven switches, each a conflict | none |

## Decision

Coucou's model, Koncluí's engine where it is better:

1. Claude and ChatGPT are Coucou's Anthropic and OpenAI with the subscription switch on. Koncluí's `claudeCode` and `codex`
   providers are removed; `KoncluiChatMigration` turns a stored `claude-code` or `codex` choice into the provider with its
   switch on. Settings → Chat shows Coucou's box with the five AIs, then the Koncluí Proxy (`KoncluiProxySection`).
2. With the switch on, Claude and ChatGPT are answered by `KoncluiChat` (`KoncluiChat.route(for:state:)`, called first in
   `ClaudeService.sendMessage`): streaming, the CLI's thread, a new message stops the old one, and `KoncluiSignInLine` shows
   the sign-in and the plan under Coucou's row. Gemini, Cursor and Copilot stay with Coucou's relay (until ADR-009).
3. `KoncluiChat` takes Coucou's safeguards, and closes what both left open: no web tool once the conversation holds a
   dropped file (as it already did for email); Coucou's isolation flags for Claude on every run, the retry for an older
   CLI included; a dropped PDF or image is read by Claude from an isolated copy (`CLIRelay.isolate`), with Read allowed
   only in that folder (`Read(//<folder>/**)` under `dontAsk`; checked live: a read outside is denied); Codex with its
   user config and rules not loaded, and shell, apps, plugins and web search off. The model chosen in Codex is read
   from its `config.toml` and passed on, so it still applies.
4. The Koncluí Proxy stays Koncluí's own provider.

## Consequences

- One place per AI in Settings, five subscriptions instead of two, and two fewer `ChatProvider` cases to carry through
  every Coucou sync.
- Claude and ChatGPT keep the streamed answer, the thread and the sign-in line people had.
- The Codex model picker is gone: Codex uses the model chosen in Codex (the top-level `model` of `~/.codex/config.toml`,
  passed with `-m`); Coucou's relay ignores that config and gets Codex's built-in default.
- Rejected: Coucou's relay for all five (Claude and ChatGPT would lose streaming, stopping and threads); keeping both
  (two entries for the same AI, and the file and Codex gaps above).
