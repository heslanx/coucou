#!/bin/bash
# Right after `git merge upstream/main` stops on conflicts (docs/konclui/WORKFLOW.md, "Coucou updates"): merges each
# conflicted file again, against the merge base and upstream with rebrand.py applied to both. A difference that is only
# the brand then vanishes, and what is left is where a Koncluí hook meets an upstream change. The catalog is merged by
# key and by language (merge-catalog.py). Only a file still exactly as git left it is merged again: one a person (or an
# earlier run) already touched is left alone, so the script can run twice.
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
STYLE=$(git config merge.conflictStyle || true)
STYLE_FLAG=()
case "$STYLE" in diff3) STYLE_FLAG=(--diff3);; zdiff3) STYLE_FLAG=(--zdiff3);; esac
# The marker lines stay (deleting them is a resolution too); only their labels go, git's and merge-file's differ.
unlabel() { sed -E 's/^(<<<<<<<|\|\|\|\|\|\|\||>>>>>>>) .*/\1/'; }

while read -r f; do
  # Which versions git has: a file added on both sides has no base, one deleted on a side has no stage for it.
  stages=$(git ls-files -u -- "$f" | awk '{print $3}' | sort -u | tr -d '\n')
  if [ "$stages" != "123" ]; then
    echo "  $f: added or deleted on one side (stages $stages), by hand"
    continue
  fi
  for n in 1 2 3; do git show ":$n:$f" > "$WORK/s$n"; done
  # Untouched means the conflict git wrote, labels aside (git's merge diffs with histogram): anything else is someone's
  # work in progress.
  if ! cmp -s <(unlabel < "$f") \
              <({ git merge-file -p --diff-algorithm=histogram ${STYLE_FLAG[@]+"${STYLE_FLAG[@]}"} "$WORK/s2" "$WORK/s1" "$WORK/s3" || true; } \
                 | unlabel); then
    echo "  $f: already touched since git's merge: left alone"
    continue
  fi
  if [ "$f" = "$CATALOG" ]; then
    python3 scripts/konclui/merge-catalog.py "$WORK/base/$f" "$WORK/s2" "$WORK/theirs/$f" "$f" | sed 's/^/  /'
  else
    cp "$WORK/s2" "$f"
    git merge-file --diff-algorithm=histogram -L konclui -L base-branded -L upstream-branded \
      "$f" "$WORK/base/$f" "$WORK/theirs/$f" || true
    echo "  $f: $(grep -c '^<<<<<<< ' "$f" || true) conflict(s) left"
  fi
done <<< "$CONFLICTS"
echo "sync-remerge: resolve what is left, \`git add\` each file, then rebrand.py and its --check (WORKFLOW.md)."
