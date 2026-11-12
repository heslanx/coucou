#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/coucou-reminders.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
swiftc NotchBuddy/Sources/App/ReminderSchedule.swift NotchBuddy/Sources/App/ReminderModels.swift NotchBuddy/Sources/App/ReminderFileStore.swift tests/ReminderTests.swift -o "$TEST_DIR/reminder-tests"
"$TEST_DIR/reminder-tests"
