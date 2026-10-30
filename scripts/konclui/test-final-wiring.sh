#!/usr/bin/env bash
# Unit U7's wiring (KONCLUI.md, "Koncluí hooks in upstream files"): what a key save says when the Keychain refuses, the Claude lines on
# the Flow pages, Undo on the last removals, the key caps, the voice rows, the agent files' look, and the new strings in 14 languages.
# Pure: swiftc with KoncluiKeychainSave.swift, the other sources read as text, nothing runs.
set -euo pipefail
cd "$(dirname "$0")/../.."
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/konclui-final-wiring.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
swiftc -swift-version 6 -parse-as-library NotchBuddy/Sources/App/KoncluiKeychainSave.swift scripts/konclui/KoncluiFinalWiringTests.swift \
  -o "$TEST_DIR/konclui-final-wiring-tests"
"$TEST_DIR/konclui-final-wiring-tests"
