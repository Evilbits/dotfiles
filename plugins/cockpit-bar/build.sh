#!/bin/bash
# Builds Cockpit Bar.app from source into ~/Applications and (re)launches it. Apple Silicon only, ad-hoc signed.
set -euo pipefail
cd "$(dirname "$0")"
HERE="$(pwd)"

NAME="Cockpit Bar"
EXEC="CockpitBar"
BUNDLE_ID="com.rasmusreiler.cockpit-bar"
VERSION="$(python3 -c 'import json; print(json.load(open(".claude-plugin/plugin.json"))["version"])')"
STAGE="build/$NAME.app"
TARGET="$HOME/Applications/$NAME.app"

rm -rf "$STAGE"
mkdir -p "$STAGE/Contents/MacOS" "$STAGE/Contents/Resources"

echo "Compiling…"
# Pin the deployment target, else swiftc stamps the binary with this machine's OS version.
swiftc -O -target arm64-apple-macos12.0 Sources/*.swift -o "$STAGE/Contents/MacOS/$EXEC" -framework Cocoa

# CockpitBarProvider tells the app where bin/cockpit-bar lives, so the app never needs an install step
# and picks up edits to the Python side without a rebuild.
cat > "$STAGE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>$EXEC</string>
  <key>CFBundleDisplayName</key><string>$NAME</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleExecutable</key><string>$EXEC</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSMinimumSystemVersion</key><string>12.0</string>
  <key>LSUIElement</key><true/>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CockpitBarProvider</key><string>$HERE/bin/cockpit-bar</string>
</dict>
</plist>
PLIST

cp assets/AppIcon.icns assets/completion.mp3 "$STAGE/Contents/Resources/"
xattr -cr "$STAGE"
codesign --force --sign - "$STAGE" >/dev/null 2>&1 || true

pkill -x "$EXEC" 2>/dev/null || true
mkdir -p "$HOME/Applications"
rm -rf "$TARGET"
cp -R "$STAGE" "$TARGET"
echo "Installed $TARGET"
# Start at login through a LaunchAgent (the hooks also relaunch the app whenever a session is active).
AGENT="$HOME/Library/LaunchAgents/$BUNDLE_ID.plist"
mkdir -p "$(dirname "$AGENT")"
cat > "$AGENT" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$BUNDLE_ID</string>
  <key>ProgramArguments</key><array><string>/usr/bin/open</string><string>-g</string><string>$TARGET</string></array>
  <key>RunAtLoad</key><true/>
</dict>
</plist>
PLIST
launchctl bootout "gui/$(id -u)/$BUNDLE_ID" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$AGENT"
echo "Login item: $AGENT"

if [[ "${1:-}" != "--no-launch" ]]; then
  open -g "$TARGET"
  echo "Launched."
fi
