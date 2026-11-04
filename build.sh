#!/bin/sh
# G.ai Token Tray by GauthamWho. Copyright © 2026 GauthamWho. All rights reserved.
# Builds "build/G.ai Token Tray.app". Usage: ./build.sh [--open]
set -e
cd "$(dirname "$0")"
swift build -c release
APP="build/G.ai Token Tray.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/TokenTray "$APP/Contents/MacOS/TokenTray"
cp Support/Info.plist "$APP/Contents/Info.plist"
cp Support/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
# A stable identity keeps Keychain and Touch ID trust across rebuilds (ad-hoc changes every build).
SIGN_ID="${SIGN_ID:-$(security find-identity -p codesigning -v 2>/dev/null | awk '/Apple Development|Developer ID Application/ {print $2; exit}')}"
codesign --force --sign "${SIGN_ID:--}" "$APP"
echo "Built $APP"
if [ "$1" = "--open" ]; then
  pkill -x TokenTray 2>/dev/null || true
  open "$APP"
fi
