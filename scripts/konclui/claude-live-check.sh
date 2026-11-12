#!/usr/bin/env bash
# One real dictation clean-up through the Koncluí Proxy: the real FlowCleanup prompt and reply handling, the real request
# builder and sender, klaude's token read from the Keychain for the call. Prints the words before and after, the source,
# the model and the time, never the token. Needs klaude set up on this Mac. Optional argument: the words to clean up.
set -euo pipefail
cd "$(dirname "$0")/../.."
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/konclui-claude-live.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
swiftc -swift-version 6 -parse-as-library \
  NotchBuddy/Sources/App/KoncluiChatCore.swift NotchBuddy/Sources/App/KoncluiChatProcess.swift \
  NotchBuddy/Sources/App/KoncluiClaudeAccess.swift NotchBuddy/Sources/App/KoncluiClaudeSender.swift \
  NotchBuddy/Sources/App/FlowCleanup.swift NotchBuddy/Sources/App/FlowText.swift NotchBuddy/Sources/App/FlowLanguages.swift \
  scripts/konclui/KoncluiClaudeLiveCheck.swift -o "$TEST_DIR/claude-live-check"
"$TEST_DIR/claude-live-check" "$@"
