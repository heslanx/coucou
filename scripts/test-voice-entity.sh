#!/usr/bin/env bash
set -e
echo "Running EntityResolver tests…"
swiftc -o /tmp/voice-entity-tests \
  tests/VoiceTestStubs.swift \
  tests/PillFixture.swift \
  NotchBuddy/Sources/App/Voice/VoiceIntent.swift \
  NotchBuddy/Sources/App/Voice/IntentParser.swift \
  NotchBuddy/Sources/App/Voice/VoiceQuery.swift \
  NotchBuddy/Sources/App/Voice/EntityResolver.swift \
  NotchBuddy/Sources/App/KoncluiVoiceLanguage.swift \
  NotchBuddy/Sources/App/KoncluiVoicePhrases.swift \
  NotchBuddy/Sources/App/KoncluiVoiceParserPT.swift \
  tests/EntityResolverTests.swift
/tmp/voice-entity-tests
