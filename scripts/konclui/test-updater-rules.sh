#!/usr/bin/env bash
# rebrand.py's updater rules match the updater's files, and a Coucou sync gives those files back (updater-rules.py).
# Needs the `upstream` remote: without it there is nothing to compare with, and the check says so.
set -euo pipefail
cd "$(dirname "$0")/../.."
if ! git rev-parse -q --verify upstream/main >/dev/null; then
  echo "updater rules: skipped, no upstream/main here (git remote add upstream https://github.com/Louis-CFM/coucou.git && git fetch upstream)"
  exit 0
fi
python3 scripts/konclui/updater-rules.py --check
