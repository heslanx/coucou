#!/bin/bash
# K5's renderer: Koru's layer hooks and outfits, built on K2's harness (KoruRender.swift's helpers, its @main dropped in a
# temp copy) against CoucouKit's sources only (Swift 6, strict concurrency, as the app).
# Usage: bash scripts/konclui/render/k5/outfits.sh <mode> [out dir] [arg]
#   typecheck            macOS 15 and iOS 18, every CoucouKit source and this harness
#   poses <out>          fixed poses (no engine, no clock) drawn bare: the before/after proof of the hooks
#   baseline <out>       the same poses with the KoruDrawing.swift of git HEAD (no hooks)
#   sheet|film|bench|sizes|icons <out>   outfits (see OutfitRender.swift)
# Output defaults to .scratch/konclui/k5/swift. Not in CI.
set -euo pipefail
cd "$(dirname "$0")/../../../.."

SDK=$(xcrun --sdk macosx --show-sdk-path)
TMP=/tmp/konclui-k5
OUT=${2:-.scratch/konclui/k5/swift}
mkdir -p "$TMP"
# Builds read a snapshot of CoucouKit: other units edit it while this runs.
rm -rf "$TMP/kit" && cp -R NotchBuddy/Sources/CoucouKit "$TMP/kit"
KIT=$TMP/kit
sed 's/^@main$//' scripts/konclui/render/KoruRender.swift > "$TMP/KoruRenderLib.swift"
cat NotchBuddy/Sources/App/GreetingCanvasView.swift scripts/konclui/render/GreetingFrames.swift.part > "$TMP/GreetingCombined.swift"
FLAGS=(-swift-version 6 -strict-concurrency=complete -parse-as-library)
MAC=(-sdk "$SDK" -target arm64-apple-macosx15.0)
BASE=("$KIT/IslandScreenGeometry.swift" "$KIT/IslandTypes.swift" "$KIT/MochiWardrobe.swift" "$KIT/BotEngine.swift"
      "$KIT/MochiOutfitDrawing.swift" "$KIT/MochiMood.swift" "$KIT/ColorHex.swift")
HARNESS=("$TMP/GreetingCombined.swift" scripts/konclui/render/GreetingStubs.swift "$TMP/KoruRenderLib.swift"
         scripts/konclui/render/k5/OutfitRender.swift)
MODE=${1:-sheet}

case "$MODE" in
typecheck)
  swiftc -typecheck "${MAC[@]}" "${FLAGS[@]}" "${BASE[@]}" "$KIT"/Koru*.swift "${HARNESS[@]}"
  echo "macOS typecheck ok"
  # iOS: CoucouKit with the iPhone app's stand-ins for the Mac pieces BotEngine calls (the harness is AppKit).
  IOS_SDK=$(xcrun --sdk iphoneos --show-sdk-path)
  swiftc -typecheck -sdk "$IOS_SDK" -target arm64-apple-ios18.0 "${FLAGS[@]}" "$KIT"/*.swift NotchBuddy/Sources/Phone/MacStubs.swift
  echo "iOS typecheck ok"
  exit 0 ;;
baseline)
  git show HEAD:NotchBuddy/Sources/CoucouKit/KoruDrawing.swift > "$TMP/KoruDrawing.orig.swift"
  git show HEAD:NotchBuddy/Sources/CoucouKit/KoruEngine.swift > "$TMP/KoruEngine.orig.swift"
  sed '/^extension BotEngine {/,$d' "$KIT/KoruLayers.swift" > "$TMP/KoruLayers.types.swift"   # the types, not BotEngine's composition
  KORU=("$KIT/KoruShapes.swift" "$KIT/KoruSheets.swift" "$TMP/KoruEngine.orig.swift" "$TMP/KoruLayers.types.swift" "$TMP/KoruDrawing.orig.swift")
  # HEAD's BotEngine routes nothing to the hooks; KoruOutfits*.swift need them, so they stay out.
  git show HEAD:NotchBuddy/Sources/CoucouKit/BotEngine.swift > "$TMP/BotEngine.orig.swift"
  B0=("$KIT/IslandScreenGeometry.swift" "$KIT/IslandTypes.swift" "$KIT/MochiWardrobe.swift" "$TMP/BotEngine.orig.swift"
      "$KIT/MochiOutfitDrawing.swift" "$KIT/MochiMood.swift" "$KIT/ColorHex.swift")
  swiftc -O "${MAC[@]}" "${FLAGS[@]}" -D K5_BASELINE "${B0[@]}" "${KORU[@]}" "${HARNESS[@]}" \
    -framework AppKit -framework SwiftUI -o "$TMP/render-baseline"
  "$TMP/render-baseline" poses "$OUT" ;;
*)
  swiftc -O "${MAC[@]}" "${FLAGS[@]}" "${BASE[@]}" "$KIT"/Koru*.swift "${HARNESS[@]}" \
    -framework AppKit -framework SwiftUI -o "$TMP/render"
  "$TMP/render" "$MODE" "$OUT" "${3:-}" ;;
esac
