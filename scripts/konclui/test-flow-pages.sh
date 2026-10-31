#!/usr/bin/env bash
# The Flow pages' behaviour (KONCLUI.md, "Koncluí hooks in upstream files"): dictation off or needing the permission, the
# numbers behind a statistic, the apps the Estilos list shows, Undo for every removal, the strings in 16 languages. Pure:
# swiftc with FlowText.swift and KoncluiFlowRules.swift, the sources read as text, nothing runs.
set -euo pipefail
cd "$(dirname "$0")/../.."
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/konclui-flow-pages.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
swiftc NotchBuddy/Sources/App/FlowText.swift NotchBuddy/Sources/App/KoncluiFlowRules.swift \
  scripts/konclui/KoncluiFlowPagesTests.swift -o "$TEST_DIR/konclui-flow-pages-tests"
"$TEST_DIR/konclui-flow-pages-tests"
