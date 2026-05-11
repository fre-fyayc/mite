#!/usr/bin/env bash
set -euo pipefail

APP_NAME="MiteTool"
BUNDLE_ID="com.local.mitetool"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/dist/${APP_NAME}.app"
PLIST_PATH="$APP_DIR/Contents/Info.plist"
EXEC_PATH="$APP_DIR/Contents/MacOS/${APP_NAME}"
ICONSET_DIR="$ROOT_DIR/dist/AppIcon.iconset"
ICNS_PATH="$APP_DIR/Contents/Resources/AppIcon.icns"

cd "$ROOT_DIR"

echo "Building debug binary..."
swift build -c debug

echo "Creating app bundle at: $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$ROOT_DIR/.build/debug/${APP_NAME}" "$EXEC_PATH"
chmod +x "$EXEC_PATH"

echo "Rendering iconset..."
chmod +x "$ROOT_DIR/scripts/render_iconset.swift"
"$ROOT_DIR/scripts/render_iconset.swift" "$ICONSET_DIR"

echo "Converting iconset to .icns..."
iconutil -c icns "$ICONSET_DIR" -o "$ICNS_PATH"

cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>${APP_NAME}</string>
  <key>CFBundleExecutable</key>
  <string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
EOF

echo "Ad-hoc codesigning bundle..."
codesign --force --deep -s - "$APP_DIR"

echo "Done."
echo "Open it with:"
echo "open \"$APP_DIR\""
