#!/bin/bash
# Builds the Koru renderer against CoucouKit's sources only (Swift 6, strict concurrency, as the app) and runs one mode.
# Usage: bash scripts/konclui/render/render.sh <grid|shot|small|greet|greeting|bench|sizes|calib|typecheck> [out dir] [state]
# Output defaults to .scratch/konclui/k2/swift. Not in CI.
set -euo pipefail
cd "$(dirname "$0")/../../.."

KIT=NotchBuddy/Sources/CoucouKit
SDK=$(xcrun --sdk macosx --show-sdk-path)
BIN=/tmp/konclui-k2/koru-render
OUT=${2:-.scratch/konclui/k2/swift}
SOURCES=(
  "$KIT/IslandScreenGeometry.swift" "$KIT/IslandTypes.swift" "$KIT/MochiWardrobe.swift" "$KIT/BotEngine.swift"
  "$KIT/MochiOutfitDrawing.swift" "$KIT/MochiMood.swift" "$KIT/ColorHex.swift"
  "$KIT"/Koru*.swift
  # The real greeting view, in a temp copy with a frame grabber appended (its drawing functions are file-private);
  # GreetingStubs.swift stands in for the app around it.
  /tmp/konclui-k2/GreetingCombined.swift scripts/konclui/render/GreetingStubs.swift
)
mkdir -p /tmp/konclui-k2
cat NotchBuddy/Sources/App/GreetingCanvasView.swift scripts/konclui/render/GreetingFrames.swift.part > /tmp/konclui-k2/GreetingCombined.swift
FLAGS=(-sdk "$SDK" -target arm64-apple-macosx15.0 -swift-version 6 -strict-concurrency=complete)

if [ "${1:-}" = "typecheck" ]; then
  swiftc -typecheck "${FLAGS[@]}" -parse-as-library "${SOURCES[@]}" scripts/konclui/render/KoruRender.swift
  echo "typecheck ok"
  exit 0
fi

mkdir -p /tmp/konclui-k2
swiftc -O "${FLAGS[@]}" -parse-as-library "${SOURCES[@]}" scripts/konclui/render/KoruRender.swift \
  -framework AppKit -framework SwiftUI -o "$BIN"
"$BIN" "${1:-grid}" "$OUT" "${3:-}"
