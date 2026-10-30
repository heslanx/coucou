#!/usr/bin/env bash
# Koncluí's Claude access: which source answers clean-up, prompt mode, translation, the Notetaker's summary and correction
# (the subscription, the key, Apple Intelligence, none), the request each source gets (bearer or key, version, model), the
# failure kinds, and that no credential reaches an outcome or a log line. Pure Foundation files, a stub network, fake keys.
# Every catalog key the pure file can produce must exist in the app's catalog (KONCLUI_STRINGS=<json> adds strings that
# `scripts/konclui/add-strings.py` has not applied yet).
set -euo pipefail
cd "$(dirname "$0")/../.."
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/konclui-claude-access.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
swiftc -swift-version 6 -warnings-as-errors -parse-as-library \
  NotchBuddy/Sources/App/KoncluiChatCore.swift NotchBuddy/Sources/App/KoncluiChatProcess.swift \
  NotchBuddy/Sources/App/KoncluiClaudeAccess.swift NotchBuddy/Sources/App/KoncluiClaudeSender.swift \
  scripts/konclui/KoncluiClaudeAccessTests.swift -o "$TEST_DIR/konclui-claude-access-tests"
"$TEST_DIR/konclui-claude-access-tests" | tee "$TEST_DIR/out.txt"
python3 - "$TEST_DIR/out.txt" "${KONCLUI_STRINGS:-}" <<'PY'
import json, pathlib, sys
keys = [line.split(" ", 1)[1].strip() for line in pathlib.Path(sys.argv[1]).read_text().splitlines() if line.startswith("KEY ")]
catalog = json.loads(pathlib.Path("NotchBuddy/Resources/Localizable.xcstrings").read_text())["strings"]
extra = json.loads(pathlib.Path(sys.argv[2]).read_text()) if sys.argv[2] else {}
missing = [k for k in keys if k not in catalog and k not in extra]
if missing:
    print("catalog keys missing:", *missing, sep="\n  ")
    sys.exit(1)
print(f"PASS: {len(keys)} catalog keys exist")
PY
