# Koncluí: how a change reaches the product

The decision and its reasons are [ADR-001](decisions/ADR-001-branches-and-flow.md); this page is the how, with the commands.
Code rules are in [ENGINEERING.md](ENGINEERING.md), interface rules in [UX.md](UX.md), what the fork changes in
[KONCLUI.md](../../KONCLUI.md).

The model is GitHub Flow: one protected `main`, short branches that reach it by pull request, tags for releases. No `develop`
branch: with one owner and parallel agents it only adds merges.

```
konclui/konclui-notch (private)

main ──●──────●──────●──────●──── always builds and passes the checks; releases are tags
        \    /        \    /
         feat/…        sync/upstream-2026-11-02
         (hours or days, one worktree each)
```

## Remotes

| Remote | Repository | Visibility | Use |
|---|---|---|---|
| `konclui` | `konclui/konclui-notch` | private | everything Koncluí: `main`, the task branches, the pull requests |
| `upstream` | `Louis-CFM/coucou` | public | read only: the source of the syncs |
| `origin` | `heslanx/coucou` | public | only contributions to Coucou, made from `upstream/main` without Koncluí code. Never Koncluí |

The local `main` tracks `konclui/main`, so a `git push` from it can only reach the private repository:

```
git fetch konclui
git branch -f main konclui/main          # with main not checked out; its only extra commit, f32fb85, is already in konclui/main
git branch -u konclui/main main
```

In Orca, set the repository's base to `konclui/main` so every new worktree starts from it:
`orca repo set-base-ref --repo id:<repoId> --ref konclui/main` (`orca repo list --json` gives the id).

## Branches

| Branch | Lives | For |
|---|---|---|
| `main` | always | the product. Protected: changes arrive by pull request, no force push, no deletion |
| `feat/<task>`, `fix/<task>`, `design/<task>`, `docs/<task>` | hours to a few days | one task, one branch, one worktree, one agent. From `main`, back by pull request, then deleted |
| `sync/upstream-YYYY-MM-DD` | one pull request | Coucou's updates coming in ("Coucou updates" below) |
| `release/x.y` | only when needed | a fix to a released version while `main` holds changes not ready to ship. Not needed today |

Names say the task, in English, lowercase with hyphens: `feat/reminders-editor`, `fix/long-question-scroll`. Not a person's name.
Prototypes and side projects (`design/prototype/koru`, `alexa/`) are folders on `main`, not branches that live for weeks.

## A task, start to finish

1. **Start from an up-to-date `main`**, in a worktree of its own:
   `git fetch konclui && git worktree add ../<task> -b feat/<task> konclui/main` (or a new Orca worktree, whose base is
   `konclui/main`).
2. **Commit in small steps.** Messages in English, `type(scope): what changed` (`feat(konclui): …`, `fix(reminders): …`), the
   why in the body. A commit made by an agent ends with its `Co-Authored-By` line.
3. **Before the pull request, catch up and check:**
   `git fetch konclui && git rebase konclui/main`, then the checks of ENGINEERING.md section 6 for what changed (at least the
   suites in `scripts/konclui/`, `python3 scripts/konclui/rebrand.py --check`, a Debug build; a screen change is walked in the
   running app).
4. **Push** (the rules in "Push" below): `git push -u konclui feat/<task>`.
5. **Open the pull request:**
   `gh pr create -R konclui/konclui-notch --base main --head feat/<task>`. The body says what changed and why, the checks that
   ran and their results, and what was not verified.
6. **Merge** with the history kept: `gh pr merge <n> -R konclui/konclui-notch --rebase --delete-branch` (or `--merge` for a
   branch whose commits should stay grouped). Never `--squash`: the granular commits are the record. Then remove the worktree:
   `git worktree remove ../<task>`.

## Parallel agents

- One task, one branch, one worktree. Two agents never share a branch; the owner's own checkout is not an agent's.
- An agent's work ends with its branch pushed and a pull request opened. It merges into `main` only when the owner asks.
- An agent never pushes to `origin`, never force pushes, never uses `--no-verify`, never touches another session's
  uncommitted changes.
- Short branches keep conflicts small: an agent rebases on `konclui/main` before its pull request, and a branch older than a
  few days is finished, split or closed.

## Coucou updates

Louis's Coucou keeps moving (0.5.6 on 2026-10-30, 97 commits Koncluí did not have). It comes in on its own branch, at least
once per upstream release (upstream's `CHANGELOG.md` and its `v*` tags):

```
git fetch konclui && git fetch upstream
git worktree add ../sync -b sync/upstream-$(date +%F) konclui/main
cd ../sync && git merge upstream/main
```

Then the recipe in KONCLUI.md, "Upstream workflow" (brand conflicts take upstream's side, `rebrand.py` re-applies the brand,
`rebrand.py --check` reports 0 changes and 0 stale rules, `voice-pt-templates.py --check`, the suites, a build), a pull request,
and a merge with `gh pr merge <n> --merge`: never squash or rebase a sync, the merge commit is what lets the next merge find
its base.

## Push

Before every push, scan exactly the commits that are about to leave this Mac:

```
gitleaks git --log-opts="<branch> --not --remotes=konclui" --redact .
```

"no leaks found", then `git push konclui <branch>`. Never a force push to `main`, never `--no-verify`, never a secret or an
`.env` in a commit (secrets live in the Keychain). Anything for `origin` is checked twice: that remote is public.

## Releases

Today there are none: the owner's Mac runs Koncluí built from source with `scripts/konclui/dev-install.sh`, and the app does
not look for updates (`block_updates` is off; `MacUpdate` still names `heslanx/coucou` and Louis's signing team, so it would
refuse any download anyway). Before the first release, KONCLUI.md "Distributing Koncluí": a Developer ID for Koncluí, Release
signed with it, notarization, and a **public** update channel (the app reads releases without a token, and
`konclui/konclui-notch` is private), with `MacUpdater` pointed at it.

From then on, a release is cut from `main`:

1. The CHANGELOG section, the README row and the What's new entry that [CLAUDE.md](../../CLAUDE.md) asks for, on a
   `release/…` or `docs/…` branch merged like any other.
2. A tag on `main` with Koncluí's own prefix, so it never meets upstream's `v0.5.6`-style tags that every sync brings in:
   `git tag -a konclui-v0.1.0 -m "Koncluí 0.1.0" && git push konclui konclui-v0.1.0`.
3. The build, signed and notarized, published to the update channel.

**Do not run `scripts/release.sh`.** It is upstream's: it asks for Coucou's provisioning profile (`fr.louisraille.NotchBuddy`)
and notary profile (`coucou-notary`), builds `Coucou.zip` and publishes the release to `Louis-CFM/coucou` with
`gh release create`. Koncluí needs its own release script (or a `FIXED` rule set for this one) before its first release.

A fix for a released version while `main` has changes not ready to ship: `release/x.y` from the tag, the fix on `main` first,
then cherry-picked to `release/x.y`, tagged `konclui-vx.y.z+1`.

## CI

Upstream's workflows came with the fork (`.github/workflows/build.yml` runs on a push or a pull request to `main`, on
`macos-latest`). On `konclui/konclui-notch` the only run (2026-10-29, a push to `main`) failed in 5 seconds without a log; its
cause was not investigated (a macOS runner on a private repository uses paid minutes). Until CI runs there, each pull request
lists the checks that ran locally, and protecting `main` cannot require status checks yet.

## Where things stand (2026-10-30)

| Branch | Where | State |
|---|---|---|
| `heslanx/konclui` | Orca worktree `~/orca/workspaces/coucou/konclui`, pushed | the app as of today; `konclui/main` is behind it (a fast-forward) |
| `feat/koru-canvas-prototype` | `~/Developments/study/coucou`, pushed | the Koru prototype, its sounds, the Alexa skill, the owner's reminders page; 9 commits the app branch lacks |
| `main` (local) | not checked out | tracks the public `origin`, one commit ahead (`f32fb85`, already in `konclui/main`) |
| `konclui/main` | GitHub's default branch | unprotected, behind `heslanx/konclui` |

Getting to the model, in order:

1. The owner protects `main` on GitHub (Settings, Branches: require a pull request, block force pushes and deletion).
2. A pull request `heslanx/konclui` → `main` (a fast-forward, no conflict).
3. A pull request `feat/koru-canvas-prototype` → `main`. Its conflicts are where the owner's reminders lines meet the app's copy
   of them (`FlowHub.swift`, `FlowHubMochis.swift`, `Localizable.xcstrings`): the app's side wins (KONCLUI.md).
4. The local `main` tracks `konclui/main` ("Remotes"), Orca's base is `konclui/main`, and the two old branches are deleted.
5. `sync/upstream-<date>` with Coucou's 97 new commits.
