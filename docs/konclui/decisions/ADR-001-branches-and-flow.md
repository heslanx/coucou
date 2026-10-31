# ADR-001: Branches, remotes and the path from a change to a release

## Status

Accepted on 2026-10-30: the owner chose one primary branch, `main` of `konclui/konclui-notch`, with everything on it.
`main` took all of the work that day (pull request #1). `main` was protected on 2026-10-31, at the owner's request, by an
agent with the owner's account (pull request required, admins included; no force push; no deletion).

## Date

2026-10-30

## Context

Found on 2026-10-30:

| Remote | Repository | Visibility | Role today |
|---|---|---|---|
| `upstream` | `Louis-CFM/coucou` | public | Coucou itself. `main` is at 0.5.6 (`37e457d`) |
| `origin` | `heslanx/coucou` | public | the owner's fork of Coucou, with community branches for Coucou. Its `main` is upstream's, 97 commits behind, with nothing of its own. `MacUpdate` still points at its releases |
| `konclui` | `konclui/konclui-notch` | private | Koncluí. `main` is the default branch, unprotected, never had a pull request, and behind `heslanx/konclui` (31 commits on the day, a fast-forward). Also holds `heslanx/konclui` and `feat/koru-canvas-prototype` |

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

GitHub Flow on the private repository. The commands are in [WORKFLOW.md](../WORKFLOW.md).

1. **`main` of `konclui/konclui-notch` is Koncluí's main branch.** What is on it builds, passes the checks, and is what a
   release is cut from. It is protected: pull request required, no force push, no deletion. There is no `develop` branch.
2. **Work happens on short branches from `main`**, one task, one branch, one worktree, one agent: `feat/<task>`, `fix/<task>`,
   `design/<task>`, `docs/<task>`, named after the task and not a person. Each goes into `main` by pull request once the checks
   of [ENGINEERING.md](../ENGINEERING.md) section 6 pass and are listed in it. Merges keep the history (rebase or merge commit,
   never squash): commits stay granular. An agent's work ends with a pull request; it merges only when the owner asks.
3. **Upstream comes in only through a `sync/upstream-YYYY-MM-DD` branch**, following "Upstream workflow" in
   [KONCLUI.md](../../../KONCLUI.md), at least once per upstream release, merged with a merge commit so the next merge finds
   its base.
4. **Push rules.** Koncluí's work goes only to `konclui`; the local `main` tracks `konclui/main`. `origin` (public) only
   receives branches meant as contributions to Coucou, made from `upstream/main`, without Koncluí code. Before every push, a
   gitleaks scan of the commits being pushed. Never a force push to `main`, never `--no-verify`.
5. **The two long branches end.** `heslanx/konclui` fast-forwards `main`. `feat/koru-canvas-prototype` goes in by a pull
   request: its reminders lines are already in the app (KONCLUI.md marks them as the owner's), so that merge resolves to the
   app's side. Both branches are then deleted. Prototypes and side projects (`design/prototype/koru`, `alexa/`) live as folders
   on `main`, not as long branches.
6. **Releases.** A tag `konclui-vX.Y.Z` on `main` (its own prefix: every sync brings upstream's `vX.Y.Z` tags), with the
   CHANGELOG section, the README row and the What's new entry that [CLAUDE.md](../../../CLAUDE.md) asks for. A
   `release/x.y` branch exists only to fix a released version while `main` holds changes not ready to ship. The update
   channel is [ADR-002](ADR-002-update-service.md) (amended 2026-10-30): the releases stay in this private repository and the
   app asks Koncluí's update service, with the steps of KONCLUI.md "Distributing Koncluí" (Developer ID, notarization). Until then `block_updates` stays off and a Mac gets Koncluí by building it with
   `scripts/konclui/dev-install.sh`.

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

### GitFlow (`develop`, `release/*`, `hotfix/*`)
- Pros: a staging line between work and release.
- Cons: every change is merged twice; built for teams with a QA stage, and there is one owner, no QA stage and no CI yet.
- Rejected: `release/x.y` is kept only for the case it solves (a fix to a shipped version).

### Everyone commits to `main`
- Pros: no branches to manage.
- Cons: no review point for upstream merges, the riskiest changes this fork makes; parallel agents would collide on one branch.
- Rejected.

## Consequences

- "The latest Koncluí" is `konclui/main`, and every change reaches it the same way.
- Owner steps on GitHub, not done by agents: protect `main` (pull request required, no force push, no deletion); required status
  checks once CI runs. Upstream's workflows came with the fork, but their only run on the private repository (2026-10-29) failed
  in 5 seconds without a log, cause not investigated; until CI runs, the checks run locally and are listed in each pull request.
- The first pull requests: `heslanx/konclui` (a fast-forward), then `feat/koru-canvas-prototype`, then
  `sync/upstream-2026-10-30` for the 97 upstream commits.
- The release channel and the Developer ID are a precondition for anyone but the owner to install or update Koncluí.
