#!/usr/bin/env bash
# Builds, notarizes and publishes Koncluí for macOS (docs/konclui/WORKFLOW.md, "Releases").
#
#   ./scripts/konclui/release.sh --check          what a release still needs on this Mac; changes nothing
#   ./scripts/konclui/release.sh 0.6.0            build, sign, notarize, staple, tag, publish
#   ./scripts/konclui/release.sh 0.6.0 --finish   finish after an interrupted notarization wait
#
# Only Koncluí: its team, its notary profile, Konclui.zip, a konclui-vX.Y.Z tag pushed to the private `konclui` remote and
# the release published there, in the same private repository; the app reads it through Koncluí's update service
# (updates/, ADR-002). Never `origin`, never Louis-CFM/coucou, no Homebrew cask. Upstream's scripts/release.sh is Coucou's
# and refuses to run in this fork. Run it from a clean checkout of main, up to date with konclui/main.
set -euo pipefail

TEAM="5M8RG3BCX2"                          # scripts/konclui/signing.sh; MacUpdate.teamId
BUNDLE_ID="com.konclui.mac"                # MacUpdate.bundleId
RELEASES_REPO="konclui/konclui-notch"      # private: the code and its releases, one repository
SERVICE="https://updates.konclui.com"      # MacUpdate.service: the app asks it, it asks RELEASES_REPO
NOTARY_PROFILE="konclui-notary"            # xcrun notarytool store-credentials konclui-notary --team-id 5M8RG3BCX2 …
REMOTE="konclui"                           # the private repository, where the tag goes
TAG_PREFIX="konclui-v"                     # MacUpdate.tagPrefix; upstream's vX.Y.Z tags arrive with every sync
CHANGELOG="docs/konclui/CHANGELOG.md"
APP_NAME="Konclui"

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

die() { echo "error: $*" >&2; exit 1; }

# ── What a release needs, each with the way to get it ─────────────────────────
MISSING=0
need() {   # need <ok 0|1> <what> <how to fix>
  if [ "$1" = 0 ]; then echo "  ✓ $2"; else echo "  ✗ $2"; echo "      $3"; MISSING=$((MISSING + 1)); fi
}

preflight() {
  echo "Koncluí release, what this Mac has:"
  local ok settings team bundle entitlements
  # Each check sets ok=0 when it passes; `a && ok=0` does not stop the script under `set -e` when `a` fails.

  ok=1; command -v gh >/dev/null && gh auth status >/dev/null 2>&1 && ok=0
  need $ok "gh installed and signed in" "brew install gh && gh auth login"

  ok=1; security find-identity -v -p codesigning 2>/dev/null | grep -q "Developer ID Application: .*($TEAM)" && ok=0
  need $ok "a Developer ID Application certificate of team $TEAM" \
    "needs the paid Apple Developer Program on that team; Xcode → Settings → Accounts → Manage Certificates → + Developer ID Application"

  ok=1; xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1 && ok=0
  need $ok "the notary profile '$NOTARY_PROFILE'" \
    "xcrun notarytool store-credentials $NOTARY_PROFILE --apple-id <id> --team-id $TEAM (with an app-specific password)"

  settings=$(cd NotchBuddy && xcodebuild -project NotchBuddy.xcodeproj -scheme NotchBuddy -configuration Release \
    -showBuildSettings 2>/dev/null || true)
  team=$(awk '$1 == "DEVELOPMENT_TEAM" { print $3; exit }' <<<"$settings")
  bundle=$(awk '$1 == "PRODUCT_BUNDLE_IDENTIFIER" { print $3; exit }' <<<"$settings")
  entitlements=$(awk '$1 == "CODE_SIGN_ENTITLEMENTS" { print $3; exit }' <<<"$settings")
  ok=1; [ "$team" = "$TEAM" ] && ok=0
  need $ok "the Release build signs with team $TEAM (today: ${team:-unknown})" \
    "a FIXED rule in scripts/konclui/rebrand.py on NotchBuddy/project.yml (KONCLUI.md, \"Distributing Koncluí\", step 2)"
  ok=1; [ "$bundle" = "$BUNDLE_ID" ] && ok=0
  need $ok "the Release build is $BUNDLE_ID (today: ${bundle:-unknown})" "project.yml, rebrand.py"
  ok=1; [ -n "$entitlements" ] && ! grep -qs "fr.louisraille" "NotchBuddy/$entitlements" && ok=0
  need $ok "the Release entitlements carry nothing of Coucou's (today: ${entitlements:-unknown})" \
    "entitlements of Koncluí's own, without Coucou's iCloud container (KONCLUI.md, step 2)"

  ok=1; grep -q "CFBundleShortVersionString" scripts/konclui/rebrand.py && ok=0
  need $ok "Koncluí's version is its own (today project.yml follows Coucou's at every sync)" \
    "pin CFBundleShortVersionString with a FIXED rule in scripts/konclui/rebrand.py"

  ok=1; curl -fsS --max-time 10 "$SERVICE/health" 2>/dev/null | grep -q '"configured":true' && ok=0
  need $ok "the update service answers with a token ($SERVICE/health)" \
    "deploy updates/ on Easypanel with GITHUB_TOKEN (updates/README.md, \"Deploy on Easypanel\")"

  ok=1
  grep -q "static let teamId = \"$TEAM\"" NotchBuddy/Sources/App/MacUpdate.swift \
    && grep -q "static let tagPrefix = \"$TAG_PREFIX\"" NotchBuddy/Sources/App/MacUpdate.swift \
    && grep -q "static let service = \"$SERVICE\"" NotchBuddy/Sources/App/MacUpdate.swift && ok=0
  need $ok "the app's updater asks this service and wants this team and these tags" "NotchBuddy/Sources/App/MacUpdate.swift"
}

if [ "${1:-}" = "--check" ]; then
  preflight
  echo
  if [ "$MISSING" = 0 ]; then echo "Ready to release."; else echo "$MISSING thing(s) missing before a release."; fi
  [ "$MISSING" = 0 ] && exit 0 || exit 1
fi

VERSION="${1:?Usage: $0 --check | <version> [--finish]}"
MODE="${2:-}"
case "$MODE" in ""|--finish) ;; *) die "unknown option '$MODE' (the only option is --finish)" ;; esac
TAG="$TAG_PREFIX$VERSION"
BUILD_DIR="/tmp/konclui-release-$VERSION"
APP="$BUILD_DIR/$APP_NAME.app"
ZIP="$BUILD_DIR/$APP_NAME.zip"
COMMIT_FILE="$BUILD_DIR/commit"

preflight
[ "$MISSING" = 0 ] || die "$MISSING thing(s) missing (above); nothing was built or published"

# The "## <version>" section of Koncluí's changelog: the release notes.
CHANGES=$(awk -v head="## $VERSION" '
  index($0, head " ") == 1 || $0 == head { found = 1; next }
  found && /^## / { exit }
  found { if ($0 ~ /^[ \t\r]*$/) { if (started) blanks++; next } while (blanks > 0) { print ""; blanks-- } print; started = 1 }
' "$CHANGELOG")
[ -n "$CHANGES" ] || die "$CHANGELOG has no '## $VERSION' section"
python3 scripts/test-whats-new.py mac >/dev/null \
  || { python3 scripts/test-whats-new.py mac; die "NotchBuddy/Resources/whats-new.json needs a complete entry for $VERSION (CLAUDE.md)"; }

git rev-parse -q --verify "refs/tags/$TAG" >/dev/null && die "tag $TAG already exists here"
git ls-remote --exit-code --tags "$REMOTE" "refs/tags/$TAG" >/dev/null 2>&1 && die "tag $TAG already exists on $REMOTE"
gh release view "$TAG" --repo "$RELEASES_REPO" >/dev/null 2>&1 && die "$RELEASES_REPO already has a release $TAG"

if [ "$MODE" != "--finish" ]; then
  git diff --quiet && git diff --cached --quiet || die "commit or stash your changes first, the release has to match a commit"
  git fetch -q "$REMOTE" main
  [ "$(git rev-parse HEAD)" = "$(git rev-parse "$REMOTE/main")" ] || die "release from $REMOTE/main: check it out and pull first"
  COMMIT=$(git rev-parse HEAD)

  cd NotchBuddy
  xcodegen generate
  PLIST_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist)
  [ "$PLIST_VERSION" = "$VERSION" ] || die "the app is version $PLIST_VERSION, not $VERSION (project.yml)"
  rm -rf "$BUILD_DIR" && mkdir -p "$BUILD_DIR"
  echo "$COMMIT" > "$COMMIT_FILE"
  # Signing comes from project.yml's Release config (preflight checked its team): set on the command line it would
  # reach the Swift packages' targets too, which have no team.
  xcodebuild -project NotchBuddy.xcodeproj -scheme NotchBuddy -configuration Release build CONFIGURATION_BUILD_DIR="$BUILD_DIR"
  cd "$REPO_ROOT"

  # What MacUpdater will demand of the download, demanded now.
  codesign --verify --deep --strict \
    -R="anchor apple generic and identifier \"$BUNDLE_ID\" and certificate leaf[subject.OU] = \"$TEAM\"" "$APP" \
    || die "$APP is not signed as $BUNDLE_ID by team $TEAM"

  ditto -c -k --keepParent "$APP" "$ZIP"
  echo
  echo "Sending to Apple for notarization. If you stop the wait (Ctrl+C), Apple keeps going:"
  echo "  check it with  xcrun notarytool history --keychain-profile $NOTARY_PROFILE"
  echo "  once Accepted  ./scripts/konclui/release.sh $VERSION --finish"
  xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait \
    || die "notarization failed: xcrun notarytool log <id> --keychain-profile $NOTARY_PROFILE"
else
  [ -d "$APP" ] && [ -f "$COMMIT_FILE" ] || die "nothing to finish in $BUILD_DIR, run ./scripts/konclui/release.sh $VERSION first"
  COMMIT=$(cat "$COMMIT_FILE")
fi

xcrun stapler staple "$APP" || die "stapling failed: Apple has not accepted the build yet, then run with --finish"
spctl -a -vv "$APP"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

# "## What's new" is where MacUpdate.headline finds the line the notch shows.
NOTES="Koncluí $VERSION for macOS 15 or later.

Signed with a Developer ID and notarized by Apple.

## What's new

$CHANGES

## Install

1. Download $APP_NAME.zip below and unzip it.
2. Move $APP_NAME.app to your Applications folder, replacing the old one if you have it.
3. Open it. Once installed, Koncluí updates itself from here."

echo
echo "──────── Release notes ────────"
echo "$NOTES"
echo "───────────────────────────────"
read -r -p "Tag $(git rev-parse --short "$COMMIT") as $TAG on $REMOTE and publish it on $RELEASES_REPO? [y/N] " ANSWER
case "$ANSWER" in y|Y|yes|s|S|sim) ;; *) die "stopped before tagging; run with --finish to publish later" ;; esac

git tag -a "$TAG" "$COMMIT" -m "Koncluí $VERSION"
git push "$REMOTE" "$TAG"
gh release create "$TAG" "$ZIP" --repo "$RELEASES_REPO" --title "Koncluí $VERSION" --latest --notes "$NOTES"
echo "✓ $TAG released: https://github.com/$RELEASES_REPO/releases/tag/$TAG"
echo "  Macs see it within $((300 / 60)) minutes: $SERVICE/v1/mac/releases (the service keeps the list 5 minutes)"
