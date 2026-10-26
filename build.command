#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
if ! xcrun --find swift >/dev/null 2>&1; then
  echo 'Install Xcode Command Line Tools first: xcode-select --install'
  exit 1
fi
swift test
swift build -c release
APP="$PWD/dist/MacWatch.app"
mkdir -p "$APP/Contents/MacOS"
BIN_DIR="$(swift build -c release --show-bin-path)"
cp "$BIN_DIR/MacWatch" "$APP/Contents/MacOS/MacWatch"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>MacWatch</string>
<key>CFBundleIdentifier</key><string>com.aminemtar.macwatch</string>
<key>CFBundleName</key><string>MacWatch</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --deep --sign - "$APP"
open "$APP"
echo "Built: $APP"
