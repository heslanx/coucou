#!/usr/bin/env bash
# Builds Koncluí (Debug, signed ad hoc: no Apple team needed) and makes it the only Koncluí:
# installed in /Applications/Konclui.app, the copies left by earlier builds removed.
# Coucou.app (any build, any place) is never touched: both apps run side by side.
#
# macOS gives its permissions (Accessibility, Screen Recording, microphone...) to one app at
# one place. An ad hoc signature changes with every build, so macOS may ask again after a
# rebuild; one copy at one place keeps that to a single entry.
#
#   ./scripts/konclui/dev-install.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUNDLE_ID="com.konclui.mac"
APP_NAME="Konclui"            # PRODUCT_NAME in project.yml: Konclui.app, process "Konclui"
DERIVED="${HOME}/Library/Developer/Xcode/DerivedData/KoncluiDev"
BUILT="${DERIVED}/Build/Products/Debug/${APP_NAME}.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister"

# Never overwrite an app that is not Koncluí.
TARGET="/Applications/${APP_NAME}.app"
if [ -d "${TARGET}" ]; then
  EXISTING=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "${TARGET}/Contents/Info.plist" 2>/dev/null || echo "")
  if [ "${EXISTING}" != "${BUNDLE_ID}" ]; then
    echo "${TARGET} is not Koncluí (${EXISTING:-unknown id}): not touching it." >&2
    exit 1
  fi
fi

echo "Building (Debug)..."
cd "${REPO_ROOT}/NotchBuddy"
xcodegen >/dev/null
# Signed with this Mac's "Apple Development" certificate when there is one, so macOS keeps the Keychain and
# privacy permissions across builds; ad hoc otherwise (scripts/konclui/signing.sh).
SIGN_ARGS=()
while IFS= read -r setting; do [ -n "$setting" ] && SIGN_ARGS+=("$setting"); done < <("${REPO_ROOT}/scripts/konclui/signing.sh")
xcodebuild -scheme NotchBuddy -configuration Debug -derivedDataPath "${DERIVED}" -quiet ${SIGN_ARGS[@]+"${SIGN_ARGS[@]}"} build

echo "Quitting Koncluí..."
osascript -e "tell application id \"${BUNDLE_ID}\" to quit" >/dev/null 2>&1 || true
for _ in 1 2 3 4 5; do pgrep -x "${APP_NAME}" >/dev/null || break; sleep 1; done
pkill -x "${APP_NAME}" 2>/dev/null || true

echo "Installing in ${TARGET}..."
rm -rf "${TARGET}"
ditto "${BUILT}" "${TARGET}"

# The build stays in DerivedData for the next (incremental) build, but macOS must not count
# it as another Koncluí. Only Konclui.app copies with Koncluí's bundle id are removed.
"${LSREGISTER}" -u "${BUILT}" >/dev/null 2>&1 || true
for old in "${HOME}"/Library/Developer/Xcode/DerivedData/NotchBuddy-*/Build/Products/*/"${APP_NAME}".app; do
  [ -d "$old" ] || continue
  ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$old/Contents/Info.plist" 2>/dev/null || echo "")
  [ "${ID}" = "${BUNDLE_ID}" ] || continue
  "${LSREGISTER}" -u "$old" >/dev/null 2>&1 || true
  rm -rf "$old"
  echo "Removed an old build: $old"
done
"${LSREGISTER}" -f "${TARGET}" >/dev/null 2>&1 || true

open "${TARGET}"
echo "Koncluí is running from ${TARGET}."
