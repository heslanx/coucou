#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 -I tests/test_reminder_mcp.py
