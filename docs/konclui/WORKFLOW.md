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

Louis's Coucou keeps moving (the last sync, on 2026-10-31, brought in 0.5.8: 205 commits). It comes in on its own branch, at
least once per upstream release (upstream's `CHANGELOG.md` and its `v*` tags):

```
git fetch konclui && git fetch upstream
git worktree add ../sync -b sync/upstream-$(date +%F) konclui/main
cd ../sync && git merge upstream/main
```

Then the recipe in KONCLUI.md, "Upstream workflow" (`scripts/konclui/sync-remerge.sh` merges each conflicted file again with
the brand on both sides, the rest by hand keeping both sides, `rebrand.py` re-applies the brand, `rebrand.py --check` reports 0
changes and 0 stale rules, `voice-pt-templates.py --check`, the suites, a build), a pull request,
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

Everything about a release points at Koncluí only: its team (`5M8RG3BCX2`), its notary profile (`konclui-notary`),
`Konclui.zip`, `konclui-vX.Y.Z` tags, and the release published in this same private repository, `konclui/konclui-notch`.
The app reads it through Koncluí's update service (`updates/`, `https://updates.konclui.com`), which holds a read-only token:
one private repository, no token in the app ([ADR-002](decisions/ADR-002-update-service.md)). Never `origin`, never
`Louis-CFM/coucou`. Deploying the service: [updates/README.md](../../updates/README.md).

What is still missing on this Mac, each with how to get it:

```
./scripts/konclui/release.sh --check
```

On 2026-10-30 it lists six: a Developer ID Application certificate of team `5M8RG3BCX2` (the paid Apple Developer Program),
the notary profile, the Release build signed with that team, Release entitlements without Coucou's iCloud container, a
version of Koncluí's own (today `project.yml` follows Coucou's at every sync), and the update service answering with its
token. Until then a Mac gets Koncluí by building it with `scripts/konclui/dev-install.sh`, and `block_updates` stays off.

Once `--check` says "Ready to release", from a clean `main` equal to `konclui/main`:

1. The `## <version>` section in [CHANGELOG.md](CHANGELOG.md) (the release notes; its first bold part is the line the notch
   shows) and the What's new entry that [CLAUDE.md](../../CLAUDE.md) asks for, merged like any other change.
2. `./scripts/konclui/release.sh <version>`: builds Release, checks the signature the updater will demand, notarizes, staples,
   shows the notes, and after a "y" tags `konclui-v<version>` on `konclui` and publishes the release with `Konclui.zip`.
   `--finish` resumes after an interrupted notarization wait. Macs see it within five minutes (the service keeps the list
   that long).

`scripts/release.sh` is upstream's (Coucou's profile and notary profile, `Coucou.zip`, the tag and a Homebrew commit pushed
to the public `origin`, the release on `Louis-CFM/coucou`): in this fork it stops at its first line.

A fix for a released version while `main` has changes not ready to ship: `release/x.y` from the tag, the fix on `main` first,
then cherry-picked to `release/x.y`, released from there.

A release that must not be installed: its tag in the service's `BLOCKED_TAGS` (Easypanel) and a redeploy; within a minute no
Mac is offered it or can download it. Then publish a fixed release with a higher version.

## How the app finds and installs an update

Once `block_updates` is on and the person said yes to looking (once, in the notch, or in Settings → Atualizações):

1. 30 seconds after launch, then every hour, `MacUpdater` checks whether 6 hours have passed since the last look. If so it
   asks `GET https://updates.konclui.com/v1/mac/releases`; the service answers from the private repository's releases.
2. `MacUpdate.latest` keeps the newest published release (not a draft or prerelease) whose tag is `konclui-vX.Y.Z` and that has
   a `Konclui.zip`, and compares its version with the running app's, number by number (0.10.0 is newer than 0.9.3).
3. Newer: the Koru announces it in the notch, once a day at most per version ("Later" hides it for 24 hours), and turns blue
   until it is installed; the menu bar and Settings keep offering it.
4. "Install": the zip is downloaded through the service, which redirects to GitHub's short-lived link (only those two hosts
   are allowed), unzipped with `ditto`, and checked before anything is replaced: the
   bundle id is `com.konclui.mac` and the version is the announced one, the signature satisfies `anchor apple generic and
   identifier "com.konclui.mac" and certificate leaf[subject.OU] = "5M8RG3BCX2"` on every architecture and nested binary,
   and Gatekeeper accepts it as notarized (`spctl`). Any failure stops there and nothing is replaced.
5. The app replaces itself only in `/Applications` or `~/Applications` (a build run from Xcode only gets the release page),
   then waits for its own process to end and opens the new version.

## CI

Upstream's workflows came with the fork (`.github/workflows/build.yml` runs on a push or a pull request to `main`, on
`macos-latest`). On `konclui/konclui-notch` every run fails in seconds and never starts: "The job was not started because an
Actions budget is preventing further use" (the check run's annotation, 2026-10-31; a macOS runner on a private repository
uses paid minutes). They run again once the owner raises the organization's Actions budget (Settings, Billing).

Koncluí's own checks do run: `.github/workflows/konclui-checks.yml`, on a push or a pull request to `main`, on the
organization's Linux server (Contabo, Ubuntu 24.04), through the self-hosted runner `vps-ci-contabo-notch` (label
`konclui-notch`, service `actions.runner.konclui-konclui-notch.vps-ci-contabo-notch` in `/opt/actions-runner-konclui-notch`,
user `github-runner`; registered 2026-10-31). A self-hosted runner spends no Actions minutes. It runs what needs no Mac:
gitleaks on the new commits, `rebrand.py --check`, the copy rules, localization, What's new, the updater rules against
Coucou, the Orca relay hook and the update service's tests. The build and the Swift tests need macOS (build.yml): until a
Mac runner exists or the budget is raised, each pull request lists the ones that ran locally. The server's root password
is in the owner's Keychain (`konclui-ci-207.180.224.192`), never in git.

## Where things stand (2026-10-31)

`main` of `konclui/konclui-notch` has everything: the app, the Koru prototype, the Alexa skill and the owner's reminders work
(pull request #1, `858ee90`), the update service (`updates/`, live at `updates.konclui.com`; pull requests #3 to #5), the
Koru product docs (`docs/koru`, ADR-003 to ADR-007; pull request #6) and Coucou 0.5.8 (the 2026-10-31 sync). The local
`main` tracks `konclui/main`, and Orca starts new worktrees of this repository from it.

| Branch | State |
|---|---|
| `main` | the primary branch, and the only one. Protected since 2026-10-31, admins included: a pull request is required (no approval, there is one owner), no force push, no deletion, no required status check (GitHub Actions is out of budget, CI) |

Next, in order:

1. The owner puts the update service's read-only GitHub token in (`updates/README.md`, "The token").
2. The two decisions in KONCLUI.md, "Open items": Korean and Japanese, and the AI subscriptions.
3. The next Coucou sync, at upstream's next release.
