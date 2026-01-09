#!/bin/bash
# Build script for Claude Code Monitor Tauri app (macOS universal binary)
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="Claude Code Monitor"
BUNDLE_ID="com.cragr.claudecodemonitor"

cd "$PROJECT_DIR"

# Check for required tools
if ! command -v pnpm &> /dev/null; then
    echo "Error: pnpm is required but not installed"
    echo "  Install with: npm install -g pnpm"
    exit 1
fi

if ! command -v rustup &> /dev/null; then
    echo "Error: rustup is required but not installed"
    exit 1
fi

# Ensure both targets are installed
echo "Ensuring Rust targets are installed..."
rustup target add aarch64-apple-darwin 2>/dev/null || true
rustup target add x86_64-apple-darwin 2>/dev/null || true

# Install frontend dependencies if needed
if [ ! -d "node_modules" ]; then
    echo "Installing frontend dependencies..."
    pnpm install
fi

# Build frontend first
echo "Building frontend..."
pnpm build

# Determine build mode
UNIVERSAL=${UNIVERSAL:-true}
SIGN=${SIGN:-false}

if [ "$UNIVERSAL" = "true" ]; then
    echo ""
    echo "=== Building Universal Binary (arm64 + x86_64) ==="
    echo ""

    # Build for Apple Silicon
    echo "Building for Apple Silicon (aarch64)..."
    pnpm tauri build --target aarch64-apple-darwin --bundles app

    # Build for Intel
    echo ""
    echo "Building for Intel (x86_64)..."
    pnpm tauri build --target x86_64-apple-darwin --bundles app

    # Create universal binary
    echo ""
    echo "Creating universal binary..."

    ARM_APP="src-tauri/target/aarch64-apple-darwin/release/bundle/macos/$APP_NAME.app"
    X86_APP="src-tauri/target/x86_64-apple-darwin/release/bundle/macos/$APP_NAME.app"
    UNIVERSAL_APP="src-tauri/target/universal-apple-darwin/release/bundle/macos/$APP_NAME.app"

    # Create output directory
    mkdir -p "$(dirname "$UNIVERSAL_APP")"

    # Copy the arm64 app as base (preserves structure, resources, etc.)
    rm -rf "$UNIVERSAL_APP"
    cp -R "$ARM_APP" "$UNIVERSAL_APP"

    # Create universal binary with lipo
    BINARY_NAME="claude-code-monitor"
    lipo -create \
        "$ARM_APP/Contents/MacOS/$BINARY_NAME" \
        "$X86_APP/Contents/MacOS/$BINARY_NAME" \
        -output "$UNIVERSAL_APP/Contents/MacOS/$BINARY_NAME"

    echo "Universal binary created"
    lipo -info "$UNIVERSAL_APP/Contents/MacOS/$BINARY_NAME"

    APP_BUNDLE="$UNIVERSAL_APP"
else
    echo ""
    echo "=== Building Native Binary ==="
    echo ""

    pnpm tauri build --bundles app
    APP_BUNDLE="src-tauri/target/release/bundle/macos/$APP_NAME.app"
fi

# Code signing
if [ -n "$APPLE_SIGNING_IDENTITY" ] || [ "$SIGN" = "true" ]; then
    IDENTITY="${APPLE_SIGNING_IDENTITY:-Developer ID Application}"
    echo ""
    echo "=== Code Signing ==="
    echo "Identity: $IDENTITY"

    # Sign the app bundle
    codesign --force --options runtime --timestamp \
        --sign "$IDENTITY" \
        --deep \
        "$APP_BUNDLE"

    # Verify signature
    echo "Verifying signature..."
    codesign --verify --verbose=2 "$APP_BUNDLE"
    echo "Code signing complete"
else
    echo ""
    echo "Skipping code signing (APPLE_SIGNING_IDENTITY not set)"
    echo "  Set APPLE_SIGNING_IDENTITY env var to sign, e.g.:"
    echo "  export APPLE_SIGNING_IDENTITY=\"Developer ID Application: Your Name (TEAMID)\""
fi

# Create DMG
DMG_NAME="ClaudeCodeMonitor.dmg"
DMG_PATH="$PROJECT_DIR/$DMG_NAME"

if command -v create-dmg &> /dev/null; then
    echo ""
    echo "=== Creating DMG ==="
    rm -f "$DMG_PATH"

    create-dmg \
        --volname "Claude Code Monitor" \
        --volicon "src-tauri/icons/icon.icns" \
        --window-size 600 400 \
        --icon-size 100 \
        --icon "$APP_NAME.app" 150 200 \
        --app-drop-link 450 200 \
        --hide-extension "$APP_NAME.app" \
        "$DMG_PATH" \
        "$APP_BUNDLE"

    DMG_CREATED=true
    echo "DMG created: $DMG_PATH"
else
    echo ""
    echo "Skipping DMG creation (create-dmg not installed)"
    echo "  Install with: brew install create-dmg"
    DMG_CREATED=false
fi

# Notarization
if [ "$DMG_CREATED" = true ] && [ -n "$APPLE_ID" ] && [ -n "$APPLE_TEAM_ID" ] && [ -n "$APPLE_PASSWORD" ]; then
    echo ""
    echo "=== Notarizing DMG ==="

    xcrun notarytool submit "$DMG_PATH" \
        --apple-id "$APPLE_ID" \
        --team-id "$APPLE_TEAM_ID" \
        --password "$APPLE_PASSWORD" \
        --wait

    echo "Stapling notarization ticket..."
    xcrun stapler staple "$DMG_PATH"
    echo "Notarization complete"
elif [ "$DMG_CREATED" = true ]; then
    echo ""
    echo "Skipping notarization (credentials not set)"
    echo "  Set APPLE_ID, APPLE_TEAM_ID, and APPLE_PASSWORD env vars to notarize"
fi

# Summary
echo ""
echo "========================================="
echo "Build Complete!"
echo "========================================="
echo ""

if [ "$UNIVERSAL" = "true" ]; then
    echo "App Bundle (Universal): $APP_BUNDLE"
else
    echo "App Bundle: $APP_BUNDLE"
fi

if [ "$DMG_CREATED" = true ]; then
    echo "DMG: $DMG_PATH"
    DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1)
    echo "DMG Size: $DMG_SIZE"
fi

echo ""
echo "To install: Open DMG and drag to /Applications"
