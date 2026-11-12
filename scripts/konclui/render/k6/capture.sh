#!/bin/bash
# Prototype captures for K6 (koru.html in headless Chrome): capture.sh <name> <W> <H> <query>, into .scratch/konclui/k6/target.
# PROTO=<dir holding koru.html> picks another copy of the prototype (K6's targets: ROOT's, with the owner's white eye discs of
# commit 10460f7 applied: core.js K eyeIn #F8FAFA / eyeEdge #DAE2E4, disc shade rgba(30,70,80,.16), happy lines rgba(232,112,104,.85)).
ROOT=$(cd "$(dirname "$0")/../../../.." && pwd)
OUT=$ROOT/.scratch/konclui/k6/target
mkdir -p "$OUT"
name=$1; W=$2; H=$3; q=$4
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
  --user-data-dir=/tmp/konclui_chrome_k6_$name --virtual-time-budget=8000 --window-size=$W,$H --screenshot="$OUT/$name.png" \
  "file://${PROTO:-$ROOT/design/prototype}/koru.html?$q" >/dev/null 2>&1
echo "$name -> $OUT/$name.png"
