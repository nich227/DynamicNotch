#!/bin/bash
#
# Builds the drag-to-Applications disk image from a built DynamicNotch.app.
#
#   scripts/make-dmg.sh <path to DynamicNotch.app> <version> [output.dmg]
#
# The window opens at a fixed size with the app on the left and an alias to
# /Applications on the right, which is the whole installer: drag one onto the
# other.

set -euo pipefail

APP="${1:?usage: make-dmg.sh <DynamicNotch.app> <version> [out.dmg]}"
VERSION="${2:?missing version}"
OUT="${3:-DynamicNotch-${VERSION}.dmg}"

STAGE="$(mktemp -d)/DynamicNotch"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

# The window's backdrop. Finder wants one file holding both sizes, so the two pngs
# are folded into a tiff; without the 2x the window looks soft on every display made
# in the last decade.
HERE="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$STAGE/.background"
MINIMUM="$(/usr/bin/plutil -extract LSMinimumSystemVersion raw -o - \
  "$APP/Contents/Info.plist" 2>/dev/null || echo "14.0")"
swift "$HERE/make-dmg-background.swift" "$VERSION" "$MINIMUM" \
  "$STAGE/.background" > /dev/null
tiffutil -cathidpicheck "$STAGE/.background/background.png" \
  "$STAGE/.background/background@2x.png" -out "$STAGE/.background/background.tiff" \
  2> /dev/null
rm -f "$STAGE/.background/background.png" "$STAGE/.background/background@2x.png"

RW="$(mktemp -u).dmg"
# room for the app plus slack; hdiutil grows the image as needed anyway
hdiutil create -srcfolder "$STAGE" -volname "DynamicNotch $VERSION" \
  -fs HFS+ -fsargs "-c c=64,a=16,e=16" -format UDRW -quiet "$RW"

MOUNT="$(hdiutil attach -readwrite -noverify -noautoopen "$RW" | \
  grep -Eo '/Volumes/.*$' | head -1)"

# Icon positions and window geometry, the part that makes it look deliberate. Finder
# does this, and macOS asks before one program may control another. When the answer is
# no, the image is still complete: it opens as a plain window with both icons.
if ! osascript <<APPLESCRIPT
with timeout of 60 seconds
  tell application "Finder"
    tell disk "$(basename "$MOUNT")"
      open
      set current view of container window to icon view
      set toolbar visible of container window to false
      set statusbar visible of container window to false
      -- the height here is the background's height exactly: bounds give the content
      -- rectangle, with no title bar counted in it
      set the bounds of container window to {200, 100, 800, 500}
      set viewOptions to the icon view options of container window
      set arrangement of viewOptions to not arranged
      set icon size of viewOptions to 96
      set background picture of viewOptions to file ".background:background.tiff"
      set position of item "DynamicNotch.app" of container window to {150, 180}
      set position of item "Applications" of container window to {450, 180}
      close
      open
      update without registering applications
      delay 1
    end tell
  end tell
end timeout
APPLESCRIPT
then
  echo "warning: Finder did not arrange the window, so the image opens with a plain layout" >&2
fi

chmod -Rf go-w "$MOUNT" || true
sync
hdiutil detach "$MOUNT" -quiet

rm -f "$OUT"
hdiutil convert "$RW" -format UDZO -imagekey zlib-level=9 -o "$OUT" -quiet
rm -f "$RW"

echo "$OUT"
