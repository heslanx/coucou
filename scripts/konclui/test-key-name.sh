#!/usr/bin/env bash
# A shortcut keycap never shows "·" for a key (KoncluiKeyName.swift). Pure: swiftc alone.
set -euo pipefail
cd "$(dirname "$0")/../.."
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/konclui-key-name.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
swiftc NotchBuddy/Sources/App/KoncluiKeyName.swift scripts/konclui/KoncluiKeyNameTests.swift -o "$TEST_DIR/konclui-key-name-tests"
"$TEST_DIR/konclui-key-name-tests"
