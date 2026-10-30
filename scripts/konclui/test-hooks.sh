#!/usr/bin/env bash
# Koncluí's hook entries never claim Coucou's (KONCLUI.md, "Functional ties"): KoncluiHook.owns
# and HookServer's removeNbHookEntries, as the source has it, on settings holding both apps' hooks.
# Pure: no settings file is read or written.
set -euo pipefail
cd "$(dirname "$0")/../.."
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/konclui-hooks.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
awk '/private func removeNbHookEntries\(/{on=1} on{print} on&&/^    }$/{exit}' NotchBuddy/Sources/App/HookServer.swift \
  | sed 's/^    //; s/^private func/func/' > "$TEST_DIR/RemoveNbHookEntries.swift"
grep -q 'KoncluiHook.owns' "$TEST_DIR/RemoveNbHookEntries.swift" \
  || { echo "removeNbHookEntries does not use KoncluiHook.owns: run scripts/konclui/rebrand.py" >&2; exit 1; }
swiftc NotchBuddy/Sources/App/KoncluiBrand.swift "$TEST_DIR/RemoveNbHookEntries.swift" \
  scripts/konclui/KoncluiHookTests.swift -o "$TEST_DIR/konclui-hook-tests"
"$TEST_DIR/konclui-hook-tests"
