#!/usr/bin/env bash
# Settings → Agents as one row per agent with an options popover, and the install doors on Active pills (KONCLUI.md,
# "Koncluí hooks in upstream files"): the words of a row for each state, how VoiceOver reads it, which agents show, which
# agent pills open an install from their hint, the strings in 16 languages, and that no agent block is a GroupBox again.
# Pure: swiftc with the recognition rules and the catalog, and the sources read as text.
set -euo pipefail
cd "$(dirname "$0")/../.."
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/konclui-agent-rows.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
{
  echo "import Foundation"
  awk '/^enum AgentSource/{on=1} on{print} on&&/^}/{exit}' NotchBuddy/Sources/CoucouKit/IslandTypes.swift
  awk '/^enum ChatProvider/{on=1} on{print} on&&/^}/{exit}' NotchBuddy/Sources/CoucouKit/IslandTypes.swift
} > "$TEST_DIR/IslandTypesExtract.swift"
grep -q 'enum ChatProvider' "$TEST_DIR/IslandTypesExtract.swift" && grep -q 'enum AgentSource' "$TEST_DIR/IslandTypesExtract.swift" \
  || { echo "IslandTypes.swift no longer declares AgentSource and ChatProvider in this shape" >&2; exit 1; }
swiftc "$TEST_DIR/IslandTypesExtract.swift" \
  NotchBuddy/Sources/CoucouKit/PillColors.swift NotchBuddy/Sources/CoucouKit/PillCatalog.swift \
  NotchBuddy/Sources/CoucouKit/KoncluiFeatures.swift NotchBuddy/Sources/App/KoncluiRecognition.swift \
  NotchBuddy/Sources/App/KoncluiAgentRows.swift scripts/konclui/KoncluiAgentRowsTests.swift \
  -o "$TEST_DIR/konclui-agent-rows-tests"
"$TEST_DIR/konclui-agent-rows-tests"
