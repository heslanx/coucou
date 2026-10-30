#!/usr/bin/env bash
# A process name macOS garbled (UTF-8 read as Mac Roman) shows as written under the notch; other names are untouched
# (KoncluiTextRepair.swift). Pure: swiftc with Foundation only.
set -euo pipefail
cd "$(dirname "$0")/../.."
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/konclui-text-repair.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
swiftc NotchBuddy/Sources/App/KoncluiTextRepair.swift scripts/konclui/KoncluiTextRepairTests.swift \
  -o "$TEST_DIR/konclui-text-repair-tests"
"$TEST_DIR/konclui-text-repair-tests"
