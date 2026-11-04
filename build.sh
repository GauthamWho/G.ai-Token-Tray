#!/bin/sh
# Builds TokenTray.app into ./build. Usage: ./build.sh [--open]
set -e
cd "$(dirname "$0")"
swift build -c release
APP=build/TokenTray.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/TokenTray "$APP/Contents/MacOS/TokenTray"
cp Support/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
echo "Built $APP"
if [ "$1" = "--open" ]; then
  pkill -x TokenTray 2>/dev/null || true
  open "$APP"
fi
