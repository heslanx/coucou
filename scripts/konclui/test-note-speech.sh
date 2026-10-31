#!/usr/bin/env bash
# Koncluí K14: the Notetaker records a call without downloading a model (Apple's on-device speech first, Parakeet optional).
#  - the engine choice for every (Parakeet installed, Apple speech available) pair, the gates' messages and the words built
#    from a recognizer's pieces run the pure file App/KoncluiNoteSpeechChoice.swift with swiftc alone;
#  - the hooks are checked in the sources: the gates ask the chooser (not Parakeet.isReady), so an upstream merge that brings
#    the old gate back fails here;
#  - every konclui.notes.speech.* string the sources use exists in the 16 languages (catalog, or staged for the merge).
# Pure: no audio, no Speech framework, no model, no window.
set -euo pipefail
cd "$(dirname "$0")/../.."
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/konclui-note-speech.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
SRC=NotchBuddy/Sources/App

swiftc -swift-version 6 $SRC/NoteModels.swift $SRC/NoteEcho.swift $SRC/KoncluiNoteSpeechChoice.swift \
  scripts/konclui/KoncluiNoteSpeechTests.swift -o "$TEST_DIR/note-speech-tests"
"$TEST_DIR/note-speech-tests"

echo
echo "Hooks in the upstream files"
fail=0
expect() {  # label, file, fixed string that must be there
  if grep -qF -- "$3" "$2"; then echo "  ✓ $1"; else echo "  ✗ $1"; fail=1; fi
}
absent() {  # label, file, fixed string that must not be there
  if grep -qF -- "$3" "$2"; then echo "  ✗ $1"; fail=1; else echo "  ✓ $1"; fi
}
absent "NoteTaker: no gate asks Parakeet.isReady any more" $SRC/NoteTaker.swift 'guard Parakeet.shared.isReady'
[ "$(grep -cF 'guard KoncluiNoteSpeech.engine != .needsDownload' $SRC/NoteTaker.swift)" = 3 ] \
  && echo "  ✓ NoteTaker: the pill, Start and the relaunch gates ask the chooser" \
  || { echo "  ✗ NoteTaker: expected 3 gates asking KoncluiNoteSpeech.engine"; fail=1; }
expect "NoteTaker: the live loop asks the chosen engine" $SRC/NoteTaker.swift 'KoncluiNoteSpeech.text(of: chunk.samples)'
expect "NoteTaker: the live loop waits for Apple's language files" $SRC/NoteTaker.swift 'KoncluiNoteSpeech.canTranscribeLive'
expect "NoteTaker: Parakeet is loaded only when it is the engine" $SRC/NoteTaker.swift 'let asr: AsrManager? = apple ? nil : try await Parakeet.shared.manager()'
expect "NoteTaker: no diarizer without Parakeet" $SRC/NoteTaker.swift 'apple ? { _ in [] } : { try await Self.diarize($0) }'
expect "NoteTaker: Apple's language files install while the call is recorded" $SRC/NoteTaker.swift 'KoncluiNoteSpeech.shared.prepare()'
absent "FlowHubHome: Record on Home does not ask Parakeet.isReady" $SRC/FlowHubHome.swift 'if Parakeet.shared.isReady'
expect "FlowHubNotes: Record is blocked only when no engine is there" $SRC/FlowHubNotes.swift '.disabled(KoncluiNoteSpeech.engine == .needsDownload && !taker.isRecording)'
expect "FlowHubNotes: the engine row sits under Record" $SRC/FlowHubNotes.swift 'KoncluiNoteSpeechRow()'
expect "FlowHubNotes: the live call shows the language install" $SRC/FlowHubNotes.swift 'KoncluiNoteSpeechProgress()'

echo
echo "Strings (16 languages)"
python3 -I - "$SRC" <<'PY' || fail=1
import json, os, re, sys
src = sys.argv[1]
langs = ["ar", "bn", "de", "en", "es", "fr", "hi", "id", "pt-BR", "ru", "th", "tr", "zh-Hans", "zh-Hant"]
used = set()
for name in os.listdir(src):
    if name.startswith("KoncluiNoteSpeech") and name.endswith(".swift"):
        used |= set(re.findall(r'"(konclui\.notes\.speech\.[a-z0-9.\-]+)"', open(os.path.join(src, name)).read()))
catalog = json.load(open("NotchBuddy/Resources/Localizable.xcstrings"))["strings"]
staged_path = ".scratch/konclui/k16/strings.json"
staged = json.load(open(staged_path)) if os.path.exists(staged_path) else {}
bad = 0
for key in sorted(used):
    have = {l for l, v in catalog.get(key, {}).get("localizations", {}).items() if v.get("stringUnit", {}).get("value")}
    have |= {l for l, v in staged.get(key, {}).items() if v}
    missing = [l for l in langs if l not in have]
    if missing:
        print(f"  ✗ {key}: missing {', '.join(missing)}"); bad += 1
    else:
        print(f"  ✓ {key}")
print(f"  {len(used)} keys used")
sys.exit(1 if bad or not used else 0)
PY
[ "$fail" = 0 ] || exit 1
echo
echo "All passed."
