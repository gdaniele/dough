#!/bin/sh
# Builds Dough.app (release, Apple silicon and Intel) into build/, signed ad hoc.
# Run on a Mac:  scripts/build-app.sh && open build/Dough.app
set -eu
cd "$(dirname "$0")/.."
version=${1:-0.1.0}
swift build -c release --arch arm64 --arch x86_64
bin=$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)
app=build/Dough.app
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cp "$bin/Dough" "$app/Contents/MacOS/Dough"
cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>io.github.gdaniele.dough</string>
  <key>CFBundleName</key><string>Dough</string>
  <key>CFBundleExecutable</key><string>Dough</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$version</string>
  <key>CFBundleVersion</key><string>$version</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSAppleEventsUsageDescription</key><string>During a session, Dough reads the front browser tab's address to keep you to the sites you chose. It never leaves your Mac.</string>
</dict></plist>
PLIST
codesign --force --sign - "$app"
echo "built $app"
