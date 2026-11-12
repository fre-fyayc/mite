#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

swift build -c release

APP="$HOME/Applications/Mite Menu.app"
mkdir -p "$APP/Contents/MacOS"

# Quit a running copy first, so open starts the binary just built.
if pgrep -x "Mite Menu" >/dev/null; then
  killall "Mite Menu" || true
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    pgrep -x "Mite Menu" >/dev/null || break
    sleep 0.2
  done
fi

cp .build/release/MiteMenu "$APP/Contents/MacOS/Mite Menu"
cat > "$APP/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>Mite Menu</string>
  <key>CFBundleIdentifier</key>
  <string>de.mite.menu</string>
  <key>CFBundleName</key>
  <string>Mite Menu</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSUIElement</key>
  <true/>
</dict>
</plist>
EOF
codesign -s - "$APP"
open "$APP"
