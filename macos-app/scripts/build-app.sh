#!/bin/bash
# Build script for Claude Code Monitor macOS app
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="ClaudeCodeMonitor"
BUNDLE_NAME="$APP_NAME.app"

cd "$PROJECT_DIR"

echo "Building universal binary (arm64 + x86_64)..."
swift build -c release --arch arm64 --arch x86_64

echo "Creating app bundle..."
rm -rf "$BUNDLE_NAME"
mkdir -p "$BUNDLE_NAME/Contents/MacOS"
mkdir -p "$BUNDLE_NAME/Contents/Resources"
mkdir -p "$BUNDLE_NAME/Contents/Frameworks"

cp ".build/apple/Products/Release/$APP_NAME" "$BUNDLE_NAME/Contents/MacOS/"

# Copy Sparkle framework (universal build location)
SPARKLE_FRAMEWORK=".build/apple/Products/Release/Sparkle.framework"
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
    <string>0.4.0-beta</string>
    <key>CFBundleVersion</key>
    <string>6</string>
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

    # Sign Sparkle framework components (inside-out signing)
    SPARKLE_FW="$BUNDLE_NAME/Contents/Frameworks/Sparkle.framework"
    if [ -d "$SPARKLE_FW" ]; then
        echo "  Signing Sparkle.framework components..."

        # Sign XPC services first (deepest level)
        for xpc in "$SPARKLE_FW/Versions/B/XPCServices/"*.xpc; do
            if [ -d "$xpc" ]; then
                codesign --force --options runtime --timestamp \
                    --sign "$DEVELOPER_ID" "$xpc"
                echo "    Signed: $(basename "$xpc")"
            fi
        done

        # Sign Autoupdate binary (bare executable, not a .app)
        if [ -f "$SPARKLE_FW/Versions/B/Autoupdate" ]; then
            codesign --force --options runtime --timestamp \
                --sign "$DEVELOPER_ID" "$SPARKLE_FW/Versions/B/Autoupdate"
            echo "    Signed: Autoupdate"
        fi

        # Sign Updater.app bundle
        if [ -d "$SPARKLE_FW/Versions/B/Updater.app" ]; then
            codesign --force --options runtime --timestamp \
                --sign "$DEVELOPER_ID" "$SPARKLE_FW/Versions/B/Updater.app"
            echo "    Signed: Updater.app"
        fi

        # Sign the framework itself
        codesign --force --options runtime --timestamp \
            --sign "$DEVELOPER_ID" "$SPARKLE_FW"
        echo "    Signed: Sparkle.framework"
    fi

    # Sign the main app bundle last
    codesign --force --options runtime --timestamp \
        --sign "$DEVELOPER_ID" "$BUNDLE_NAME"
    echo "  Signed: $BUNDLE_NAME"

    # Verify the signature
    echo "  Verifying signature..."
    codesign --verify --verbose=2 "$BUNDLE_NAME"
    echo "  Code signing complete"
else
    echo "Skipping code signing (DEVELOPER_ID not set)"
    echo "  Set DEVELOPER_ID env var to sign, e.g.:"
    echo "  export DEVELOPER_ID=\"Developer ID Application: Your Name (TEAMID)\""
fi

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

# Notarize DMG if credentials are set
if [ "$DMG_CREATED" = true ] && [ -n "$APPLE_ID" ] && [ -n "$TEAM_ID" ] && [ -n "$APP_PASSWORD" ]; then
    echo "Notarizing DMG..."
    xcrun notarytool submit "$APP_NAME.dmg" \
        --apple-id "$APPLE_ID" \
        --team-id "$TEAM_ID" \
        --password "$APP_PASSWORD" \
        --wait

    echo "Stapling notarization ticket..."
    xcrun stapler staple "$APP_NAME.dmg"
    echo "  Notarization complete"
elif [ "$DMG_CREATED" = true ]; then
    echo "Skipping notarization (credentials not set)"
    echo "  Set APPLE_ID, TEAM_ID, and APP_PASSWORD env vars to notarize"
fi

# Sign DMG with Sparkle EdDSA if sign_update is available
SPARKLE_SIGN="$SCRIPT_DIR/../../sparkle/bin/sign_update"
if [ "$DMG_CREATED" = true ] && [ -x "$SPARKLE_SIGN" ]; then
    echo "Generating Sparkle EdDSA signature..."
    "$SPARKLE_SIGN" "$APP_NAME.dmg"
elif [ "$DMG_CREATED" = true ]; then
    echo "Skipping Sparkle signing (sign_update not found at $SPARKLE_SIGN)"
fi

echo ""
echo "Build complete!"
if [ "$DMG_CREATED" = true ]; then
    echo "  DMG: $PROJECT_DIR/$APP_NAME.dmg"
    echo ""
    echo "To install: Open DMG and drag to /Applications"
else
    echo "  App bundle cleaned up (DMG not created)"
    echo "  Install create-dmg to generate DMG: brew install create-dmg"
fi
