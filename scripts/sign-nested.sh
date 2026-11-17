#!/bin/bash
# This script signs every executable inside the app, innermost first, and then the app
# itself. The app is built without a signature, so this script is the only place that
# signs it.
# Notarization refuses a bundle if any executable is unsigned.
#
#   sign-nested.sh <app> <identity> <keychain> <entitlements>
#
# Pass "" as the keychain to search the default keychains. Pass "-" as the identity for
# an ad hoc signature, which is enough to run the app on the Mac that built it.
set -euo pipefail

APP="$1"
IDENTITY="$2"
KEYCHAIN="$3"
ENTITLEMENTS="$4"

OPTIONS=(--force --options runtime --sign "$IDENTITY")
# An ad hoc signature has no certificate, so there is nothing to timestamp.
if [ "$IDENTITY" != "-" ]; then
  OPTIONS+=(--timestamp)
fi
if [ -n "$KEYCHAIN" ]; then
  OPTIONS+=(--keychain "$KEYCHAIN")
fi

sign() {
  codesign "${OPTIONS[@]}" "$@"
}

# -depth lists a directory after its contents, so a helper is signed before the
# bundle that holds it
find "$APP/Contents" -depth \( -type d \( -name '*.xpc' -o -name '*.app' -o -name '*.framework' \) \
  -o -type f \) -print0 | while IFS= read -r -d '' item; do
  if [ -d "$item" ]; then
    # Sparkle's XPC services carry their own entitlements
    sign --preserve-metadata=entitlements "$item"
  elif file -b "$item" | grep -q 'Mach-O'; then
    if [ "$item" = "$APP/Contents/MacOS/$(basename "$APP" .app)" ]; then
      continue
    fi
    sign --preserve-metadata=entitlements "$item"
  fi
done

sign --entitlements "$ENTITLEMENTS" "$APP"
