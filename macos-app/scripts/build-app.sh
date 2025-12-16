#!/bin/bash
# Build script for Claude Code Monitor macOS app
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="ClaudeCodeMonitor"
BUNDLE_NAME="$APP_NAME.app"

cd "$PROJECT_DIR"

echo "Building release version..."
swift build -c release

echo "Creating app bundle..."
rm -rf "$BUNDLE_NAME"
mkdir -p "$BUNDLE_NAME/Contents/MacOS"
mkdir -p "$BUNDLE_NAME/Contents/Resources"

cp ".build/release/$APP_NAME" "$BUNDLE_NAME/Contents/MacOS/"

# Copy icon if it exists
if [ -f "$APP_NAME.icns" ]; then
    cp "$APP_NAME.icns" "$BUNDLE_NAME/Contents/Resources/AppIcon.icns"
    echo "  Icon included"
fi

cat > "$BUNDLE_NAME/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>ClaudeCodeMonitor</string>
    <key>CFBundleIdentifier</key>
    <string>com.claudecode.monitor</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Claude Code Monitor</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

echo "Creating ZIP archive..."
zip -r "$APP_NAME.zip" "$BUNDLE_NAME"

echo ""
echo "Build complete!"
echo "  App bundle: $PROJECT_DIR/$BUNDLE_NAME"
echo "  ZIP archive: $PROJECT_DIR/$APP_NAME.zip"
echo ""
echo "To install: Unzip and drag $BUNDLE_NAME to /Applications"
