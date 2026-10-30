# ADR-001: Branches, remotes and the path from a change to a release

## Status

Proposed. Accepting it takes two steps only the owner can do on GitHub: bring `main` of `konclui/konclui-notch` up to date
(today a fast-forward to `heslanx/konclui`) and protect it.

## Date

2026-10-30

## Context

Found on 2026-10-30:

| Remote | Repository | Visibility | Role today |
|---|---|---|---|
| `upstream` | `Louis-CFM/coucou` | public | Coucou itself. `main` is at 0.5.6 (`37e457d`) |
| `origin` | `heslanx/coucou` | public | the owner's fork of Coucou, with community branches for Coucou. Its `main` is upstream's, 97 commits behind, with nothing of its own. `MacUpdate` still points at its releases |
| `konclui` | `konclui/konclui-notch` | private | Koncluí. `main` is the default branch, unprotected, never had a pull request, 31 commits behind `heslanx/konclui`. Also holds `heslanx/konclui` and `feat/koru-canvas-prototype` |

Checkouts on the owner's Mac: `~/Developments/study/coucou` on `feat/koru-canvas-prototype` (the Koru prototype, the Alexa skill,
the owner's reminders), and Orca's worktree `~/orca/workspaces/coucou/konclui` on `heslanx/konclui` (the app).

What that costs:

- No branch answers "what is the current Koncluí". `main` is stale and the work lives on two long branches that split at
  `d98a34b`; the prototype branch has 9 commits the app branch lacks.
- Koncluí is 97 commits behind upstream, and nothing says when or how often to catch up.
- `origin` is public: one push to the wrong remote publishes Koncluí's code.
- Nothing protects `main` against a force push or a merge without the checks.
- The app's updater reads the releases of a public Coucou fork, and Koncluí's own repository is private, so it cannot serve
  an updater that reads releases without a token.

## Decision

1. **`main` of `konclui/konclui-notch` is Koncluí's main branch.** What is on it builds, passes the checks, and is what a
   release is cut from.
2. **Work happens on short branches from `main`**, one Orca worktree each: `feat/…`, `fix/…`, `design/…`, `docs/…`, and
   `sync/upstream-YYYY-MM-DD` for upstream. Each goes into `main` by pull request on `konclui/konclui-notch`, once the checks of
   [ENGINEERING.md](../ENGINEERING.md) section 6 pass and are listed in the pull request (the suites in `scripts/konclui/`,
   `rebrand.py --check`, the localization test, a Debug build). Commits stay granular. A sync branch is merged with a merge
   commit, never squashed, so the next upstream merge finds its base.
3. **Upstream comes in only through a `sync/upstream-<date>` branch**, following "Upstream workflow" in
   [KONCLUI.md](../../../KONCLUI.md), at least once per upstream release.
4. **Push rules.** Koncluí's work goes only to `konclui`. `origin` (public) only receives branches meant as contributions to
   Coucou, made from `upstream/main`, without Koncluí code. Before every push: a gitleaks scan of the commits being pushed. Never
   a force push to `main`, never `--no-verify`.
5. **The two long branches end.** `heslanx/konclui` fast-forwards `main`. `feat/koru-canvas-prototype` goes in by a pull
   request: its reminders lines are already in the app (KONCLUI.md marks them as the owner's), so that merge resolves to the
   app's side. Both branches are then deleted.
6. **Releases.** A tag `vX.Y.Z` on `main`, with the CHANGELOG section, the README row and the What's new entry that
   [CLAUDE.md](../../../CLAUDE.md) asks for. The update channel must be public, because the app reads releases without a token:
   a public releases repository or a feed of Koncluí's own, set up with the steps of KONCLUI.md "Distributing Koncluí"
   (Developer ID, notarization, `MacUpdater` pointed at it with Koncluí's team). Until then `block_updates` stays off and a Mac
   gets Koncluí by building it with `scripts/konclui/dev-install.sh`.

## Alternatives considered

### `heslanx/konclui` as the main branch
- Pros: it already holds the newest app.
- Cons: a person's name on the product line, and it is already used as a work branch; `main` would stay stale and still be
  the default branch GitHub shows.
- Rejected: two "main" branches is the problem this record removes.

### Koncluí on `origin` (`heslanx/coucou`)
- Pros: one repository for Coucou contributions and Koncluí.
- Cons: public; Koncluí's integrations, brand and fork notes would be published, and Coucou contributions would share a
  `main` with a product that is not Coucou.
- Rejected: the private repository already exists and holds the work.

### Everyone commits to `main`
- Pros: no branches to manage.
- Cons: no review point for upstream merges, the riskiest changes this fork makes; parallel agents would collide on one branch.
- Rejected.

## Consequences

- "The latest Koncluí" is `konclui/main`, and every change reaches it the same way.
- Owner steps on GitHub, not done by agents: protect `main` (pull request required, no force push, no deletion); required status
  checks once there is CI. There is no Mac CI today, so the checks run locally and are listed in each pull request.
- The first pull requests: `heslanx/konclui` (a fast-forward), then `feat/koru-canvas-prototype`, then
  `sync/upstream-2026-10-30` for the 97 upstream commits.
- The release channel and the Developer ID are a precondition for anyone but the owner to install or update Koncluí.
