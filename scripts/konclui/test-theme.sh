#!/usr/bin/env bash
# The hub window's visual system (KoncluiThemeCore.swift): every text role passes 4.5:1 on its surfaces, the checkbox's off
# stroke is 3:1, one gutter lines the Notetaker up with its header card, and the motion rules (Reduce Motion, window not
# front, which band is live). Pure: swiftc with the core file only.
set -euo pipefail
cd "$(dirname "$0")/../.."
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/konclui-theme.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
swiftc NotchBuddy/Sources/App/KoncluiThemeCore.swift scripts/konclui/KoncluiThemeTests.swift -o "$TEST_DIR/konclui-theme-tests"
"$TEST_DIR/konclui-theme-tests"
