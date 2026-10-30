#!/usr/bin/env bash
# Koncluí K11: agent sessions in Orca's terminals (Orca pill, focus) and klaude's hooks (~/.klaude).
#  - routing and the klaude installer run HookServer.swift's own code, cut out of the source below
#    (the same technique as scripts/konclui/test-hooks.sh), on payloads and on settings in temp folders;
#  - the relay script embedded in HookServer.swift runs against a throwaway socket (test-orca-relay.py);
#  - the focus command is checked against `orca terminal switch --help` when Orca is installed.
# Pure: no settings file, Keychain or Orca state is read or written; nothing is launched.
set -euo pipefail
cd "$(dirname "$0")/.."
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/konclui-orca.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
SRC=NotchBuddy/Sources/App
HOOK_SERVER=$SRC/HookServer.swift

# --- Router: the routing chain of processEvent, from "Determine which pill" to the focus line.
{
  echo 'import Foundation'
  echo 'enum Router {'
  awk '/private static func validateAgent\(/{on=1} on{print} on&&/^    }$/{exit}' "$HOOK_SERVER" | sed 's/private static func/static func/'
  echo '    static func nbLog(_ message: String) {}'
  echo '    static func route(name: String, payload: [String: Any]) -> (pill: String, external: Bool, host: String?)? {'
  echo '        let projectName = "project"'
  awk '/Determine which pill this event belongs to/{on=1} /let focused = state.focusId == agentId/{on=0} on{print}' "$HOOK_SERVER" \
    | sed 's/^\( *\)return$/\1return nil/'
  echo '        return (agentId, isExternalAgent, hostApp)'
  echo '    }'
  echo '}'
} > "$TEST_DIR/Router.swift"
grep -q 'static func validateAgent' "$TEST_DIR/Router.swift" \
  || { echo "validateAgent not found in HookServer.swift" >&2; exit 1; }
grep -q 'isOrcaSession' "$TEST_DIR/Router.swift" \
  || { echo "the Orca route is not in processEvent's routing" >&2; exit 1; }

# --- HookServer stand-in: the Claude settings.json installer section, as the source has it.
{
  echo 'import Foundation'
  echo 'final class HookServer: @unchecked Sendable {'
  echo '    static let shared = HookServer()'
  echo '    static var hookScriptPath: String { "/Users/test/Library/Application Support/Konclui/nb-hook" }'
  awk '/MARK: - Claude Code settings.json hook installer/{on=1} /MARK: - Claude plan status line installer/{on=0} on{print}' "$HOOK_SERVER"
  echo '}'
} > "$TEST_DIR/HookServerInstaller.swift"
grep -q 'func previewClaudeHooks(at' "$TEST_DIR/HookServerInstaller.swift" \
  || { echo "the Claude hook installer was not found in HookServer.swift" >&2; exit 1; }
grep -q 'KoncluiHook.owns' "$TEST_DIR/HookServerInstaller.swift" \
  || { echo "the Claude hook installer does not use KoncluiHook.owns" >&2; exit 1; }

swiftc -swift-version 6 \
  $SRC/ClaudeHost.swift $SRC/KoncluiOrca.swift $SRC/ClaudeSettingsFile.swift $SRC/KoncluiBrand.swift \
  $SRC/KoncluiAgentHooks.swift "$TEST_DIR/Router.swift" "$TEST_DIR/HookServerInstaller.swift" \
  scripts/konclui/KoncluiOrcaTests.swift -o "$TEST_DIR/konclui-orca-tests"
"$TEST_DIR/konclui-orca-tests"

python3 -I scripts/konclui/test-orca-relay.py "$HOOK_SERVER"

# --- The focus command against Orca's own help (read-only): skipped when Orca is not installed.
ORCA=/Applications/Orca.app/Contents/Resources/bin/orca
echo
echo "Focus command against Orca's CLI"
if [ -x "$ORCA" ]; then
  help="$(env -i HOME="$HOME" PATH=/usr/bin:/bin "$ORCA" terminal switch --help 2>&1)"
  echo "$help" | grep -q 'Usage: orca terminal switch \[--terminal <handle>\]' \
    && echo "  ✓ \`orca terminal switch --terminal <handle>\` is the CLI's own usage" \
    || { echo "  ✗ orca terminal switch --help does not show --terminal <handle>"; exit 1; }
else
  echo "  - Orca is not installed here: skipped"
fi
