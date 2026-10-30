#!/usr/bin/env bash
# The notch pages' behaviour (KONCLUI.md, "Koncluí hooks in upstream files"): which control is the primary one in an agent's
# popover, the four-tab limit, where the demo goes and when the "Connect your agents" card shows, Orca's approvals, what a
# hook install or removal changes in a file (the lines Koncluí adds or removes), the files Koncluí writes, the strings in
# 14 languages, and that no view reads an agent's file in its body. Pure: swiftc with the recognition rules, the sources
# read as text, nothing runs.
set -euo pipefail
cd "$(dirname "$0")/../.."
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/konclui-page-rules.XXXXXX")"
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
  NotchBuddy/Sources/App/KoncluiHookTargets.swift NotchBuddy/Sources/App/KoncluiHooksDiff.swift \
  NotchBuddy/Sources/App/KoncluiPageRules.swift scripts/konclui/KoncluiPageRulesTests.swift \
  -o "$TEST_DIR/konclui-page-rules-tests"
"$TEST_DIR/konclui-page-rules-tests"
