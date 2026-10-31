#!/bin/bash
# Right after `git merge upstream/main` stops on conflicts (docs/konclui/WORKFLOW.md, "Coucou updates"): merges each
# conflicted file again, against the merge base and upstream with rebrand.py applied to both. A difference that is only
# the brand then vanishes, and what is left is where a Koncluí hook meets an upstream change. The catalog is merged by
# key and by language (merge-catalog.py). Files a person already started resolving are left alone.
#
#   scripts/konclui/sync-remerge.sh
set -euo pipefail
ROOT=$(git rev-parse --show-toplevel)
cd "$ROOT"
git rev-parse -q --verify MERGE_HEAD >/dev/null || { echo "sync-remerge: no merge in progress" >&2; exit 1; }
THEIRS=$(git rev-parse MERGE_HEAD)
BASE=$(git merge-base HEAD MERGE_HEAD)
CONFLICTS=$(git diff --name-only --diff-filter=U)
[ -n "$CONFLICTS" ] || { echo "sync-remerge: no conflicted file"; exit 0; }

WORK=$(mktemp -d /tmp/konclui-remerge.XXXX)
cleanup() {
  git worktree remove --force "$WORK/base" 2>/dev/null || true
  git worktree remove --force "$WORK/theirs" 2>/dev/null || true
  rm -rf "$WORK"
}
trap cleanup EXIT

for side in base theirs; do
  rev=$BASE
  [ "$side" = theirs ] && rev=$THEIRS
  git worktree add -q --detach "$WORK/$side" "$rev"
  # The fork's own files (rebrand.py, its data, the files it reads) on top of that tree.
  comm -23 <(git ls-tree -r --name-only HEAD | sort) <(git ls-tree -r --name-only "$rev" | sort) | while read -r f; do
    mkdir -p "$WORK/$side/$(dirname "$f")"
    git show "HEAD:$f" > "$WORK/$side/$f"
  done
  (cd "$WORK/$side" && python3 scripts/konclui/rebrand.py --no-xcodegen > "$WORK/$side.log" 2>&1) \
    || echo "sync-remerge: rebrand.py on the $side tree ended with an error (stale rules are expected there)" >&2
done

CATALOG=NotchBuddy/Resources/Localizable.xcstrings
while read -r f; do
  if [ ! -f "$WORK/base/$f" ] || [ ! -f "$WORK/theirs/$f" ]; then
    echo "  $f: added or deleted on one side, by hand"
    continue
  fi
  if [ "$f" != "$CATALOG" ] && ! grep -q '^<<<<<<< ' "$f"; then
    echo "  $f: no conflict marker left, already resolved by hand: not touched"
    continue
  fi
  git show ":2:$f" > "$WORK/ours"
  if [ "$f" = "$CATALOG" ]; then
    python3 scripts/konclui/merge-catalog.py "$WORK/base/$f" "$WORK/ours" "$WORK/theirs/$f" "$f" | sed 's/^/  /'
  else
    cp "$WORK/ours" "$f"
    git merge-file -L konclui -L base-branded -L upstream-branded "$f" "$WORK/base/$f" "$WORK/theirs/$f" || true
    echo "  $f: $(grep -c '^<<<<<<< ' "$f" || true) conflict(s) left"
  fi
done <<< "$CONFLICTS"
echo "sync-remerge: resolve what is left, \`git add\` each file, then rebrand.py and its --check (WORKFLOW.md)."
