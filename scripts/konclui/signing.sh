#!/usr/bin/env bash
# Prints the xcodebuild settings that sign a Debug build of Koncluí with this Mac's own "Apple Development"
# certificate, so macOS keeps its Keychain and privacy permissions from one build to the next (an ad hoc
# signature changes with every build and macOS asks again each time). Without such a certificate it prints
# nothing and the build stays ad hoc, as project.yml sets it: any Mac can still build Koncluí.
#
# One setting per line (the identity name has a space):
#   while IFS= read -r s; do [ -n "$s" ] && args+=("$s"); done < <(scripts/konclui/signing.sh)
#   xcodebuild ... "${args[@]}" build
#
# KONCLUI_SIGN=adhoc forces the ad hoc signature; KONCLUI_SIGN_IDENTITY=<SHA-1> picks another certificate.
# The identity is passed by its generic name, "Apple Development", with the certificate's team: a precise SHA-1
# would clash with the automatically signed resource bundles of the Swift packages (FluidAudio).
set -euo pipefail

[ "${KONCLUI_SIGN:-}" = adhoc ] && exit 0

identity="${KONCLUI_SIGN_IDENTITY:-}"
if [ -z "$identity" ]; then
  identity=$(security find-identity -v -p codesigning 2>/dev/null \
    | awk '/"Apple Development: / { print $2; exit }')
fi
[ -n "$identity" ] || exit 0

# The team is the certificate's organizational unit.
team=$(security find-certificate -a -Z -p 2>/dev/null \
  | awk -v id="$identity" '
      /^SHA-1 hash:/ { keep = ($3 == id) }
      keep { print }' \
  | openssl x509 -noout -subject 2>/dev/null \
  | sed -n 's/.*OU *= *\([A-Z0-9]*\).*/\1/p')
[ -n "$team" ] || { echo "signing.sh: no team found for $identity; building ad hoc" >&2; exit 0; }

echo "CODE_SIGN_IDENTITY=Apple Development"
echo "DEVELOPMENT_TEAM=$team"
