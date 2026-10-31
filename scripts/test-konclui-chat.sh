#!/usr/bin/env bash
# Koncluí chat through subscriptions: login parsing, CLI command lines, CLI output parsing, proxy
# request building, and the subprocess runner (pure Foundation files, no UI).
#   KONCLUI_CHAT_LIVE=1 scripts/test-konclui-chat.sh   also asks each route two short questions
#   (claude, codex, cursor, the proxy; KONCLUI_CHAT_LIVE_ROUTES="cursor" narrows them) and checks Cursor's
#   isolation and stop: uses the Mac's own logins and klaude's key, prints answers only.
set -euo pipefail
cd "$(dirname "$0")/.."
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/konclui-chat.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
CORE=(NotchBuddy/Sources/App/KoncluiChatCore.swift NotchBuddy/Sources/App/KoncluiChatAdapters.swift
      NotchBuddy/Sources/App/CLIRelay.swift NotchBuddy/Sources/App/KoncluiChatProcess.swift)
swiftc -swift-version 6 -warnings-as-errors "${CORE[@]}" tests/KoncluiChatTests.swift -o "$TEST_DIR/konclui-chat-tests"
"$TEST_DIR/konclui-chat-tests"
if [ "${KONCLUI_CHAT_LIVE:-}" = 1 ]; then
    swiftc -swift-version 6 -warnings-as-errors "${CORE[@]}" tests/KoncluiChatLive.swift -o "$TEST_DIR/konclui-chat-live"
    "$TEST_DIR/konclui-chat-live"
fi
