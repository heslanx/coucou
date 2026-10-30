#!/bin/bash
# Stills of the hub window's visual system, before and after, drawn offscreen around mock pages with the real theme files.
# The pinned header uses macOS 26's safeAreaBar, so it renders on macOS 26 only; two stills flash a small window for a second.
# Usage: bash scripts/konclui/render-theme/render.sh [out dir]   (default .scratch/konclui/u1/stills). Not in CI.
set -euo pipefail
cd "$(dirname "$0")/../../.."
OUT=${1:-.scratch/konclui/u1/stills}
BIN="$(mktemp -d "${TMPDIR:-/tmp}/konclui-render-theme.XXXXXX")"
trap 'rm -rf "$BIN"' EXIT
SDK=$(xcrun --sdk macosx --show-sdk-path)
swiftc -sdk "$SDK" -target arm64-apple-macosx26.0 -swift-version 6 -strict-concurrency=complete \
  NotchBuddy/Sources/CoucouKit/ColorHex.swift NotchBuddy/Sources/App/KoncluiThemeCore.swift \
  NotchBuddy/Sources/App/KoncluiTheme.swift NotchBuddy/Sources/App/KoncluiPointer.swift \
  scripts/konclui/render-theme/main.swift -o "$BIN/render-theme"
"$BIN/render-theme" "$OUT"
