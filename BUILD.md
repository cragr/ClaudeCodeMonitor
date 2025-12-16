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

A convenience script is provided to create a distributable app bundle:

```bash
cd macos-app
./scripts/build-app.sh
```

This creates:
- `ClaudeCodeMonitor.app` - The app bundle
- `ClaudeCodeMonitor.zip` - Ready for distribution

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

After creating a release build:

1. Using `create-dmg` (prettier DMGs):
   ```bash
   # Install create-dmg
   brew install create-dmg

   # Create DMG with Applications symlink
   create-dmg \
     --volname "Claude Code Monitor" \
     --window-size 600 400 \
     --icon-size 100 \
     --icon "ClaudeCodeMonitor.app" 150 200 \
     --app-drop-link 450 200 \
     "ClaudeCodeMonitor.dmg" \
     "ClaudeCodeMonitor.app"
   ```

2. Or manually using hdiutil:
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

For distribution to other users (outside App Store), Apple recommends notarization.

### Sign with Developer ID

Requires an Apple Developer account ($99/year):

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
