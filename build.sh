#!/bin/sh
# G.AI TokenTray by GauthamWho. Copyright © 2026 GauthamWho. All rights reserved.
# Builds "build/G.AI TokenTray.app". Usage: ./build.sh [--open]
set -e
cd "$(dirname "$0")"
swift build -c release
APP="build/G.AI TokenTray.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/TokenTray "$APP/Contents/MacOS/TokenTray"
cp Support/Info.plist "$APP/Contents/Info.plist"
cp Support/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP"
echo "Built $APP"
if [ "$1" = "--open" ]; then
  pkill -x TokenTray 2>/dev/null || true
  open "$APP"
fi
