# ADR-002: Updates through Koncluí's own service, one private repository

## Status

Accepted on 2026-10-30, by the owner ("one private repository, the app asks a proxy on Easypanel"). Amends
[ADR-001](ADR-001-branches-and-flow.md) item 6, which asked for a public update channel.

## Date

2026-10-30

## Context

The Mac app updates itself (`MacUpdater`): it lists releases on GitHub without a token, downloads `Konclui.zip` and replaces
itself after checking the signature and notarization. Koncluí's code lives in the private `konclui/konclui-notch`, so its
releases cannot be listed without a token, and a token must never ship inside an app. The first plan was a second, public
repository holding only the releases (`konclui/konclui-releases`); it was never created.

## Decision

Releases are published in the private `konclui/konclui-notch` itself, and the app asks **Koncluí's update service**
(`updates/` in that repository, on Easypanel, `https://updates.konclui.com`), which holds a fine-grained, read-only token:

- `GET /v1/mac/releases` answers in GitHub's releases shape, cut to published `konclui-vX.Y.Z` releases with a
  `Konclui.zip`, every link pointing at the service. `MacUpdate.latest` reads it unchanged.
- `GET /v1/mac/download/<tag>/Konclui.zip` redirects to GitHub's short-lived link for the private asset: the zip never passes
  through Easypanel and the token never leaves the service.
- `GET /v1/mac/notes/<tag|latest>` is the page "See what's new" opens.
- `BLOCKED_TAGS` takes a bad release out of the list and the downloads within a minute.

What the app checks before replacing itself does not change: bundle id `com.konclui.mac`, the announced version, the
signature of team `5M8RG3BCX2` on every architecture and nested binary, notarization (`spctl`). The service decides which
release is offered, never what may be installed.

## Alternatives considered

### A public releases repository
- Pros: no service to run; GitHub serves everything.
- Cons: two repositories; every release, its notes and binary public on GitHub; no way to pull a release back other than
  deleting it; no room for channels or licences later.
- Rejected by the owner: one private repository.

### A token inside the app
- Rejected: anyone could extract it and read the whole private repository.

### A feed on the website or object storage
- Pros: no GitHub dependency at download time.
- Cons: a second place to upload each build, and its own credentials; the release would no longer be the GitHub release
  `release.sh` already publishes.
- Not now: the service can move to it later without the app changing its checks.

## Consequences

- One repository for code and releases; `scripts/konclui/release.sh` publishes there and `--check` asks for the service.
- One more service to keep running. If it is down, updates wait; the app keeps working.
- The token expires: renew it in Easypanel before its date (updates/README.md).
- The service sees that a Mac asked, as GitHub did; it logs nothing about who (no telemetry).
- Still needed for any update to install: a Developer ID, notarization, the Release build signed with Koncluí's team
  (`release.sh --check`).
