# Building Claude Code Monitor

This document covers building, testing, and distributing the Claude Code Monitor macOS application.

## Prerequisites

1. **macOS 14.0+** (Sonoma or later)
2. **Swift 5.9+** (included with Xcode 15+ or install via swiftly/homebrew)

## Building the App

### Command Line (Recommended)

No Xcode project needed - just use Swift Package Manager:

```bash
cd macos-app
swift build
swift run ClaudeCodeMonitor
```

For a release build:

```bash
swift build -c release
```

The binary will be at `.build/release/ClaudeCodeMonitor`.

### Using the Build Script

A convenience script is provided to create distributable archives:

```bash
cd macos-app
./scripts/build-app.sh
```

This creates:
- `ClaudeCodeMonitor.zip` - ZIP archive for distribution
- `ClaudeCodeMonitor.dmg` - DMG installer (if `create-dmg` is installed)

The script automatically:
- Builds a release binary
- Creates a proper app bundle with Info.plist
- Bundles the Sparkle.framework for auto-updates
- Signs the app if `DEVELOPER_ID` is set (see below)
- Creates ZIP and DMG archives
- Cleans up the intermediate .app bundle

#### Optional: Install create-dmg

For DMG creation with a nice drag-to-Applications layout:

```bash
brew install create-dmg
```

#### Optional: Code Signing

To sign the app with your Developer ID:

```bash
export DEVELOPER_ID="Developer ID Application: Your Name (TEAMID)"
./scripts/build-app.sh
```

If `DEVELOPER_ID` is not set, the script skips signing (useful for local testing).

## Running Tests

```bash
cd macos-app
swift test
```

The test suite includes:
- **PrometheusClientTests**: Query builder validation
- **PrometheusDecodingTests**: API response decoding
- **MetricNormalizationTests**: Metric name/label normalization

## Architecture

```
macos-app/
├── ClaudeCodeMonitor/
│   └── Sources/
│       ├── App/                    # App entry point
│       ├── Models/                 # Data models
│       │   ├── PrometheusModels.swift   # API response types
│       │   └── ClaudeCodeMetrics.swift  # Domain models
│       ├── Services/               # Business logic
│       │   ├── PrometheusClient.swift   # HTTP client
│       │   ├── MetricsService.swift     # Data aggregation
│       │   └── SettingsManager.swift    # App settings
│       └── Views/                  # SwiftUI views
│           ├── ContentView.swift
│           ├── LiveDashboardView.swift
│           ├── HistoricalDashboardView.swift
│           ├── SmokeTestView.swift
│           ├── SettingsView.swift
│           └── MenuBarView.swift
├── ClaudeCodeMonitorTests/         # Unit tests
├── Package.swift                   # SPM manifest
└── scripts/
    └── build-app.sh                # Build script
```

## Auto-Updates (Sparkle)

The app includes [Sparkle](https://sparkle-project.org/) for automatic update checking. The build script automatically bundles Sparkle.framework.

### Configuration

The app is configured to check for updates from:
- Feed URL: `https://raw.githubusercontent.com/cragr/ClaudeCodeMonitor/main/appcast.xml`

### Creating a Release with Updates

#### Prerequisites (one-time setup)

1. Generate Sparkle EdDSA keys (stored in Keychain):
   ```bash
   # Download Sparkle tools
   curl -L -o /tmp/Sparkle.tar.xz https://github.com/sparkle-project/Sparkle/releases/download/2.5.0/Sparkle-2.5.0.tar.xz
   cd /tmp && tar -xf Sparkle.tar.xz

   # Generate keys (saves to Keychain, outputs public key)
   /tmp/bin/generate_keys
   ```

2. Update `SUPublicEDKey` in `build-app.sh` Info.plist with the public key output

3. Create an app-specific password at https://appleid.apple.com for notarization

#### Release Workflow

```bash
cd macos-app

# 1. Build and sign the app
export DEVELOPER_ID="Developer ID Application: Your Name (TEAM_ID)"
./scripts/build-app.sh

# 2. Notarize the DMG with Apple
xcrun notarytool submit ClaudeCodeMonitor.dmg \
  --apple-id "your@email.com" \
  --team-id "TEAM_ID" \
  --password "your-app-specific-password" \
  --wait

# 3. Staple the notarization ticket to the DMG
xcrun stapler staple ClaudeCodeMonitor.dmg

# 4. Generate Sparkle EdDSA signature
/tmp/bin/sign_update ClaudeCodeMonitor.dmg
# Output: sparkle:edSignature="..." length="..."

# 5. Update appcast.xml with new version entry:
#    - sparkle:version (build number)
#    - sparkle:shortVersionString (display version)
#    - sparkle:edSignature (from step 4)
#    - length (from step 4)
#    - enclosure url

# 6. Create GitHub release and upload artifacts
gh release create vX.Y.Z --title "vX.Y.Z - Release Title" --notes "Release notes..."
gh release upload vX.Y.Z ClaudeCodeMonitor.dmg ClaudeCodeMonitor.zip

# 7. Commit and push appcast.xml
git add appcast.xml
git commit -m "chore: Add vX.Y.Z to appcast.xml"
git push
```

#### Updating an Existing Release

```bash
# Re-upload artifacts (after rebuilding)
gh release upload vX.Y.Z ClaudeCodeMonitor.dmg ClaudeCodeMonitor.zip --clobber

# Update appcast.xml signature/length and push
git add appcast.xml
git commit -m "chore: Update appcast signature for vX.Y.Z"
git push
```

## Distributing the App

### Quick Distribution (No Developer Account)

For sharing with trusted users without an Apple Developer account:

1. Build using the script:
   ```bash
   cd macos-app
   ./scripts/build-app.sh
   ```

2. Share the `ClaudeCodeMonitor.zip` file

3. Recipients should:
   - Unzip and move `ClaudeCodeMonitor.app` to `/Applications`
   - Remove the quarantine attribute (required for unsigned apps):
     ```bash
     xattr -cr /Applications/ClaudeCodeMonitor.app
     ```
   - Launch the app from Applications

### Create a DMG Installer

The build script automatically creates a DMG if `create-dmg` is installed:

```bash
brew install create-dmg
./scripts/build-app.sh
```

For manual DMG creation using hdiutil:

```bash
# Create a folder with the app and Applications alias
mkdir -p dmg-contents
cp -R ClaudeCodeMonitor.app dmg-contents/
ln -s /Applications dmg-contents/Applications

# Create DMG
hdiutil create -volname "Claude Code Monitor" \
  -srcfolder dmg-contents \
  -ov -format UDZO \
  ClaudeCodeMonitor.dmg
```

## Code Signing and Notarization

For distribution to other users (outside App Store), Apple recommends code signing and notarization.

### Sign with Developer ID

Requires an Apple Developer account ($99/year).

**Using the build script (recommended):**

```bash
export DEVELOPER_ID="Developer ID Application: Your Name (TEAM_ID)"
./scripts/build-app.sh
```

**Manual signing:**

```bash
codesign --deep --force --verify --verbose \
  --sign "Developer ID Application: Your Name (TEAM_ID)" \
  ClaudeCodeMonitor.app
```

### Notarize the App

```bash
# Create a ZIP for notarization
ditto -c -k --keepParent ClaudeCodeMonitor.app ClaudeCodeMonitor.zip

# Submit for notarization
xcrun notarytool submit ClaudeCodeMonitor.zip \
  --apple-id "your@email.com" \
  --team-id "TEAM_ID" \
  --password "app-specific-password" \
  --wait

# Staple the ticket
xcrun stapler staple ClaudeCodeMonitor.app
```

Without notarization, users will see Gatekeeper warnings and need to right-click → Open to bypass.
