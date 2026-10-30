#!/usr/bin/env bash
# Koncluí's voice brain: which brain answers "OK Koru" for every combination of Apple Intelligence, the Claude opt-in,
# the Koncluí Proxy and the Anthropic key, and the proxy request of a voice turn (bearer, anthropic-version, tools, the
# retry without the web search). Pure Foundation files, a fake token, no network.
set -euo pipefail
cd "$(dirname "$0")/../.."
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/konclui-voice-brain.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
swiftc -swift-version 6 -warnings-as-errors \
  NotchBuddy/Sources/App/KoncluiChatCore.swift NotchBuddy/Sources/App/KoncluiChatProcess.swift \
  NotchBuddy/Sources/App/KoncluiVoiceBrain.swift scripts/konclui/KoncluiVoiceBrainTests.swift \
  -o "$TEST_DIR/konclui-voice-brain-tests"
"$TEST_DIR/konclui-voice-brain-tests"
