#!/bin/bash
#
# Builds a signed DynamicNotch.app on this Mac and packs it as a zip and a disk image.
#
#   scripts/build-signed.sh [version]
#
# The version defaults to MARKETING_VERSION in the project. The script holds no
# credentials. It reads them from the environment and the keychain when it runs:
#
#   CODE_SIGN_IDENTITY  The signing identity is a name or a SHA-1 hash from
#                       `security find-identity -v -p codesigning`. The default is the
#                       first "Developer ID Application" identity in the keychain. Use a
#                       single hyphen for an ad hoc signature.
#   NOTARY_PROFILE      Create a notarytool keychain profile once with
#                       `xcrun notarytool store-credentials <name>`. After you set the
#                       profile, the app and the disk image are notarized and stapled.
#   JOBS                The number of parallel build jobs. The default is Xcode's.
#
# The output goes to build/release.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="${1:-$(sed -n 's/^[[:space:]]*MARKETING_VERSION = \(.*\);$/\1/p' \
  DynamicNotch.xcodeproj/project.pbxproj | head -1)}"
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "the version must look like 1.2.3, not '$VERSION'" >&2
  exit 1
fi
IFS=. read -r X Y Z <<< "$VERSION"
# sparkle compares this monotonically increasing build number
BUILD=$((X * 10000 + Y * 100 + Z))

IDENTITY="${CODE_SIGN_IDENTITY:-}"
if [ -z "$IDENTITY" ]; then
  IDENTITY="$(security find-identity -v -p codesigning \
    | grep 'Developer ID Application' | head -1 | awk '{print $2}')"
fi
if [ -z "$IDENTITY" ]; then
  echo "no Developer ID Application identity in the keychain;" \
    "set CODE_SIGN_IDENTITY, or set it to - for an ad hoc signature" >&2
  exit 1
fi

DERIVED="$ROOT/build/release-dd"
OUT="$ROOT/build/release"
APP="$DERIVED/Build/Products/Release/DynamicNotch.app"
ZIP="$OUT/DynamicNotch-$VERSION.zip"
DMG="$OUT/DynamicNotch-$VERSION.dmg"
mkdir -p "$OUT"

# A bundle left by an earlier run still carries that run's signature, and Xcode does
# not remove it. Start with a bundle that Xcode writes in full.
rm -rf "$APP"

echo "building DynamicNotch $VERSION (build $BUILD)"
xcodebuild \
  -project DynamicNotch.xcodeproj \
  -scheme DynamicNotch \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED" \
  ${JOBS:+-jobs "$JOBS"} \
  MARKETING_VERSION="$VERSION" \
  CURRENT_PROJECT_VERSION="$BUILD" \
  CODE_SIGNING_ALLOWED=NO \
  build > "$OUT/build.log" 2>&1 || { tail -30 "$OUT/build.log" >&2; exit 1; }

# Xcode builds without a signature, and sign-nested.sh signs everything afterward.
# The same path handles an ad hoc signature, a development certificate, and a
# Developer ID certificate.
./scripts/sign-nested.sh "$APP" "$IDENTITY" "" \
  DynamicNotch/Application/DynamicNotch.entitlements > "$OUT/sign.log" 2>&1 \
  || { tail -30 "$OUT/sign.log" >&2; exit 1; }
codesign --verify --deep --strict "$APP"

# get-task-allow is the debug entitlement and notarization rejects it
if codesign -d --entitlements :- "$APP" 2> /dev/null | grep -q get-task-allow; then
  echo "the build carries get-task-allow" >&2
  exit 1
fi

notarize() {
  xcrun notarytool submit "$1" --keychain-profile "$NOTARY_PROFILE" --wait --timeout 45m
}

# Notarized before the zip and the dmg are made, since both have to carry the
# stapled ticket. A stapled app opens without asking Apple at launch.
if [ -n "${NOTARY_PROFILE:-}" ]; then
  ditto -c -k --keepParent "$APP" "$OUT/notarize.zip"
  notarize "$OUT/notarize.zip"
  rm -f "$OUT/notarize.zip"
  xcrun stapler staple "$APP"
fi

# the zip is what Sparkle downloads; the dmg is what people download
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
./scripts/make-dmg.sh "$APP" "$VERSION" "$DMG" > /dev/null

# The image needs its own signature and its own ticket: a download carries the
# quarantine bit on the image, so that is what macOS checks first.
if [ "$IDENTITY" != "-" ]; then
  codesign --force --sign "$IDENTITY" --timestamp "$DMG"
fi
if [ -n "${NOTARY_PROFILE:-}" ]; then
  notarize "$DMG"
  xcrun stapler staple "$DMG"
fi

echo "$ZIP"
echo "$DMG"
if [ -z "${NOTARY_PROFILE:-}" ]; then
  echo "not notarized: set NOTARY_PROFILE to notarize, or macOS will warn on other Macs" >&2
fi
