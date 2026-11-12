#!/bin/bash
# K6's renderer: Koru's scenes (minis, desktop hit area, FlowHub floor, mood, gulp, upload) through CoucouKit's sources,
# built on K2's harness (KoruRender.swift's helpers, its @main dropped in a temp copy), Swift 6 strict concurrency as the app.
# Usage: bash scripts/konclui/render/k6/scenes.sh <mode> [out dir]
#   typecheck   macOS 15 (CoucouKit + this harness) and iOS 18 (CoucouKit + the iPhone app's Mac stubs)
#   minis | desktop | flowhub | mood | gulp | upload   see SceneRender.swift
# Output defaults to .scratch/konclui/k6/swift. Not in CI.
set -euo pipefail
cd "$(dirname "$0")/../../../.."

KIT=NotchBuddy/Sources/CoucouKit
TMP=/tmp/konclui-k6
OUT=${2:-.scratch/konclui/k6/swift}
mkdir -p "$TMP"
sed 's/^@main$//' scripts/konclui/render/KoruRender.swift > "$TMP/KoruRenderLib.swift"
cat NotchBuddy/Sources/App/GreetingCanvasView.swift scripts/konclui/render/GreetingFrames.swift.part > "$TMP/GreetingCombined.swift"
FLAGS=(-swift-version 6 -strict-concurrency=complete -parse-as-library)
MAC=(-sdk "$(xcrun --sdk macosx --show-sdk-path)" -target arm64-apple-macosx15.0)
BASE=("$KIT/IslandScreenGeometry.swift" "$KIT/IslandTypes.swift" "$KIT/MochiWardrobe.swift" "$KIT/BotEngine.swift"
      "$KIT/MochiOutfitDrawing.swift" "$KIT/MochiMood.swift" "$KIT/ColorHex.swift")
HARNESS=("$TMP/GreetingCombined.swift" scripts/konclui/render/GreetingStubs.swift "$TMP/KoruRenderLib.swift"
         scripts/konclui/render/k6/SceneRender.swift)
# The upload scene's Koru (UploadCanvasView.swift's drawing, file-private there) is compiled from the app's own file, its
# view stubbed out: the constants and engine come from UploadSequenceEngine.swift.
UPLOAD=(NotchBuddy/Sources/App/UploadSequenceEngine.swift "$TMP/UploadKoru.swift")
python3 - "$TMP/UploadKoru.swift" <<'PY'
import re, sys
src = open("NotchBuddy/Sources/App/UploadCanvasView.swift").read()
# Keep what follows the K6 marker (Koru's upload drawing) up to its end marker.
a = src.find("// MARK: - Koru upload scene")
b = src.find("// MARK: - End Koru upload scene")
body = src[a:b] if a >= 0 and b > a else ""
open(sys.argv[1], "w").write("import SwiftUI\nimport AppKit\n\n" + body)
PY

case "${1:-}" in
typecheck)
  swiftc -typecheck "${MAC[@]}" "${FLAGS[@]}" "${BASE[@]}" "$KIT"/Koru*.swift "${UPLOAD[@]}" "${HARNESS[@]}"
  echo "macOS typecheck ok"
  swiftc -typecheck -sdk "$(xcrun --sdk iphoneos --show-sdk-path)" -target arm64-apple-ios18.0 "${FLAGS[@]}" "$KIT"/*.swift \
    NotchBuddy/Sources/Phone/MacStubs.swift
  echo "iOS typecheck ok"
  exit 0 ;;
esac

# K5 works on the outfit files at the same time: when they do not build yet, build without them.
build() { swiftc -O "${MAC[@]}" "${FLAGS[@]}" "${BASE[@]}" "$@" "${UPLOAD[@]}" "${HARNESS[@]}" \
  -framework AppKit -framework SwiftUI -o "$TMP/scenes"; }
# Last resort (another unit's files mid-change): git HEAD's Koru files and BotEngine (with K6's mini routing line), and
# K6's own files from the worktree.
head_build() {
  mkdir -p "$TMP/head"; rm -f "$TMP"/head/*.swift
  for f in $(git ls-tree --name-only HEAD "$KIT/" | grep -E '/(Koru[A-Za-z]*|BotEngine)\.swift$' | grep -vE 'Koru(Scenes|Mood|Gulp)'); do
    git show "HEAD:$f" > "$TMP/head/$(basename "$f")"; done
  python3 - "$TMP/head/BotEngine.swift" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
if "koruMiniBehavior" not in s:
    s = s.replace("    func doMiniBehaviorLoop() {\n", "    func doMiniBehaviorLoop() {\n        if Koru.enabled && koruMiniBehavior() { return }\n", 1)
open(p, "w").write(s)
PY
  B=("${BASE[@]/$KIT\/BotEngine.swift/$TMP/head/BotEngine.swift}")
  swiftc -O "${MAC[@]}" "${FLAGS[@]}" "${B[@]}" "$TMP"/head/Koru*.swift $(ls "$KIT"/Koru{Scenes,Mood,Gulp}*.swift 2>/dev/null) \
    "${UPLOAD[@]}" "${HARNESS[@]}" -framework AppKit -framework SwiftUI -o "$TMP/scenes"
}
build "$KIT"/Koru*.swift 2>"$TMP/build.log" || {
  echo "build with every Koru file failed ($(grep -c error: "$TMP/build.log") errors, see $TMP/build.log); without KoruOutfits*"
  build $(ls "$KIT"/Koru*.swift | grep -v KoruOutfits) 2>"$TMP/build2.log" || {
    echo "failed too (see $TMP/build2.log); with git HEAD's Koru engine"; head_build; }; }
"$TMP/scenes" "${1:-minis}" "$OUT"
