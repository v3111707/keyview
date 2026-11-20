#!/bin/zsh
# Builds build/KeyView.app from the Swift package.
set -euo pipefail
cd "${0:A:h}"

swift build -c release

APP=build/KeyView.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/KeyView "$APP/Contents/MacOS/KeyView"
cp Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"

# The ad-hoc signature changes with every build, so an old Input Monitoring
# grant no longer matches. Reset it so macOS asks again on the next launch.
tccutil reset ListenEvent local.keyview >/dev/null 2>&1 || true

echo "Built $APP"
