#!/usr/bin/env bash
# Koncluí's WhatsApp block (KONCLUI.md, "Koncluí hooks in upstream files"): how a phone number reads, which stage the block is in
# (the calm line, the install card, the QR, a problem) for the state of the install and the link, and which sample messages the live
# notch preview shows for each set of options. Pure: it runs on the real WAInbox and WAFilters, with no view, network or setting.
set -euo pipefail
cd "$(dirname "$0")/../.."
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/konclui-whatsapp-preview.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
swiftc NotchBuddy/Sources/App/WhatsAppModels.swift NotchBuddy/Sources/App/WhatsAppGateway.swift \
    NotchBuddy/Sources/App/KoncluiWhatsAppModel.swift scripts/konclui/KoncluiWhatsAppTests.swift \
    -o "$TEST_DIR/konclui-whatsapp-tests"
"$TEST_DIR/konclui-whatsapp-tests"
