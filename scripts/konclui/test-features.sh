#!/usr/bin/env bash
# Koncluí's feature flags and recognized-only Settings lists (KONCLUI.md, "Feature flags"): the shipped defaults, the
# override round trip through PillCatalog.available, the unlock, the detection of tools on a Mac and what counts as
# recognized. Pure: the flags live in a throwaway UserDefaults suite and the Mac is a fake. Prints the pill ids offered
# with the default flags.
set -euo pipefail
cd "$(dirname "$0")/../.."
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/konclui-features.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
# AgentSource and ChatProvider as the source has them (IslandTypes.swift also pulls in the drawing code).
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
  scripts/konclui/KoncluiFeaturesTests.swift -o "$TEST_DIR/konclui-features-tests"
"$TEST_DIR/konclui-features-tests"
