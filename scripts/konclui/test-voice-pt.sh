#!/usr/bin/env bash
# "OK Koru" in Brazilian Portuguese: the language type, the Portuguese sentences, the phrase parser, the runner's spoken
# answers (with the catalog's pt-BR voice.* strings), the prompts and the hooks in the voice files. Every Portuguese
# sentence upstream says must have an entry: voice-pt-templates.py --check. `--table` prints the evidence table.
set -euo pipefail
cd "$(dirname "$0")/../.."
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/konclui-voice-pt.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT

python3 -I scripts/konclui/voice-pt-templates.py --check

# The runner reads some answers (voice.music-playing…) from the app's pt-BR strings: build that table next to the binary.
mkdir -p "$TEST_DIR/pt-BR.lproj"
python3 -I - "$TEST_DIR/pt-BR.lproj/Localizable.strings" <<'PY'
import json, sys
catalog = json.load(open("NotchBuddy/Resources/Localizable.xcstrings", encoding="utf-8"))["strings"]
def q(s): return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'
with open(sys.argv[1], "w", encoding="utf-8") as out:
    for key, entry in catalog.items():
        value = entry.get("localizations", {}).get("pt-BR", {}).get("stringUnit", {}).get("value")
        if key.startswith("voice.") and value:
            out.write(f"{q(key)} = {q(value)};\n")
PY

swiftc -swift-version 6 -warnings-as-errors \
  tests/VoiceTestStubs.swift tests/PillFixture.swift \
  NotchBuddy/Sources/App/Voice/VoiceIntent.swift NotchBuddy/Sources/App/Voice/IntentParser.swift \
  NotchBuddy/Sources/App/Voice/VoiceQuery.swift NotchBuddy/Sources/App/Voice/EntityResolver.swift \
  NotchBuddy/Sources/App/Voice/VoiceActionRunner.swift NotchBuddy/Sources/App/Voice/ConversationContext.swift \
  NotchBuddy/Sources/App/Voice/TurnEndPolicy.swift NotchBuddy/Sources/App/Voice/WakePhrase.swift \
  NotchBuddy/Sources/App/Voice/VoiceGenderNames.swift \
  NotchBuddy/Sources/App/KoncluiVoiceLanguage.swift NotchBuddy/Sources/App/KoncluiVoicePhrases.swift \
  NotchBuddy/Sources/App/KoncluiVoiceParserPT.swift NotchBuddy/Sources/App/KoncluiVoicePrompts.swift \
  scripts/konclui/KoncluiVoicePortugueseTests.swift \
  -o "$TEST_DIR/konclui-voice-pt-tests"
"$TEST_DIR/konclui-voice-pt-tests" "$@"
