#!/usr/bin/env bash
# The rules of the Lembretes page (KoncluiReminderRules.swift): the editor's sizes, places and snap, the first time a
# reminder rings, what blocks a save, the draft's round trip to the owner's model, the rows' order and words, and every
# key they name in the catalog's 14 languages. Pure: swiftc with the owner's reminder model only.
set -euo pipefail
cd "$(dirname "$0")/../.."
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/konclui-reminder-rules.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
swiftc NotchBuddy/Sources/App/ReminderModels.swift NotchBuddy/Sources/App/ReminderSchedule.swift \
  NotchBuddy/Sources/App/KoncluiReminderRules.swift scripts/konclui/KoncluiReminderRulesTests.swift \
  -o "$TEST_DIR/konclui-reminder-rules-tests"
"$TEST_DIR/konclui-reminder-rules-tests" NotchBuddy/Resources/Localizable.xcstrings
