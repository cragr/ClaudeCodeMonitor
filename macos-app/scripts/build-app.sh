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
mkdir -p "$BUNDLE_NAME/Contents/Frameworks"

cp ".build/release/$APP_NAME" "$BUNDLE_NAME/Contents/MacOS/"

# Copy Sparkle framework
SPARKLE_FRAMEWORK=".build/arm64-apple-macosx/release/Sparkle.framework"
if [ -d "$SPARKLE_FRAMEWORK" ]; then
    cp -R "$SPARKLE_FRAMEWORK" "$BUNDLE_NAME/Contents/Frameworks/"
    echo "  Sparkle.framework included"

    # Update rpath to find framework in Frameworks directory
    install_name_tool -add_rpath "@executable_path/../Frameworks" "$BUNDLE_NAME/Contents/MacOS/$APP_NAME" 2>/dev/null || true
fi

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
    <key>SUPublicEDKey</key>
    <string>tgo3e8T4IiQLiNpC2qf/Tdbs5b5Lnw253nZB4oEXcpU=</string>
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
    <key>SUFeedURL</key>
    <string>https://raw.githubusercontent.com/cragr/ClaudeCodeMonitor/main/appcast.xml</string>
</dict>
</plist>
EOF

# Code sign if DEVELOPER_ID is set
if [ -n "$DEVELOPER_ID" ]; then
    echo "Code signing with: $DEVELOPER_ID"
    codesign --deep --force --verify --verbose \
        --sign "$DEVELOPER_ID" \
        "$BUNDLE_NAME"
    echo "  Code signing complete"
else
    echo "Skipping code signing (DEVELOPER_ID not set)"
    echo "  Set DEVELOPER_ID env var to sign, e.g.:"
    echo "  export DEVELOPER_ID=\"Developer ID Application: Your Name (TEAMID)\""
fi

echo "Creating ZIP archive..."
zip -r "$APP_NAME.zip" "$BUNDLE_NAME"

# Create DMG if create-dmg is available
if command -v create-dmg &> /dev/null; then
    echo "Creating DMG..."
    rm -f "$APP_NAME.dmg"
    create-dmg \
        --volname "Claude Code Monitor" \
        --window-size 600 400 \
        --icon-size 100 \
        --icon "$BUNDLE_NAME" 150 200 \
        --app-drop-link 450 200 \
        "$APP_NAME.dmg" \
        "$BUNDLE_NAME"
    DMG_CREATED=true
else
    echo "Skipping DMG creation (create-dmg not installed)"
    echo "  Install with: brew install create-dmg"
    DMG_CREATED=false
fi

# Clean up app bundle (DMG/ZIP contain the app)
echo "Cleaning up app bundle..."
rm -rf "$BUNDLE_NAME"

echo ""
echo "Build complete!"
echo "  ZIP archive: $PROJECT_DIR/$APP_NAME.zip"
if [ "$DMG_CREATED" = true ]; then
    echo "  DMG archive: $PROJECT_DIR/$APP_NAME.dmg"
fi
echo ""
echo "To install: Open DMG or unzip and drag to /Applications"
