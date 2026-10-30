#!/usr/bin/env bash
# The names of the notch's tabs (abas) fit in 11 characters (KoncluiTabLabel.swift): every catalog name, the owner's short
# forms, and how an unknown long name is shortened. Pure: swiftc with the catalog only.
set -euo pipefail
cd "$(dirname "$0")/../.."
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/konclui-tab-label.XXXXXX")"
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
  NotchBuddy/Sources/CoucouKit/KoncluiFeatures.swift NotchBuddy/Sources/App/KoncluiTabLabel.swift \
  scripts/konclui/KoncluiTabLabelTests.swift -o "$TEST_DIR/konclui-tab-label-tests"
"$TEST_DIR/konclui-tab-label-tests"
