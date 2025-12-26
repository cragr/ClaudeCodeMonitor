# Sparkle Auto-Updates Design

**Date**: 2025-12-25
**Status**: Approved

## Overview

Add automated update functionality to ClaudeCodeMonitor using Sparkle 2 framework. Updates are checked on launch, users are notified when available, and they choose when to install.

## Requirements

- **Distribution**: Direct download (GitHub Releases)
- **Update experience**: Check on launch, user controls installation timing
- **Hosting**: GitHub Releases with appcast.xml in repo
- **Code signing**: Developer ID signed app
- **Integration**: Swift Package Manager

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  ClaudeCodeMonitor App                                  │
│  ┌─────────────────┐    ┌─────────────────────────────┐│
│  │  AppDelegate    │───▶│  SparkleUpdaterService      ││
│  │  (on launch)    │    │  - SPUUpdater wrapper       ││
│  └─────────────────┘    │  - checkForUpdates()        ││
│                         │  - automaticallyChecks      ││
│  ┌─────────────────┐    └───────────┬─────────────────┘│
│  │  Settings Menu  │                │                  │
│  │  "Check for     │────────────────┘                  │
│  │   Updates..."   │                                   │
│  └─────────────────┘                                   │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│  GitHub Releases                                        │
│  - appcast.xml (generated from releases)                │
│  - ClaudeCodeMonitor-vX.Y.Z.dmg (signed)               │
└─────────────────────────────────────────────────────────┘
```

## Implementation

### 1. SPM Dependency

Add to `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.5.0")
]

targets: [
    .executableTarget(
        name: "ClaudeCodeMonitor",
        dependencies: [
            .product(name: "Sparkle", package: "Sparkle")
        ],
        // ...
    )
]
```

### 2. Info.plist Configuration

| Key | Value |
|-----|-------|
| `SUFeedURL` | `https://raw.githubusercontent.com/cragr/ClaudeCodeMonitor/main/appcast.xml` |
| `SUPublicEDKey` | EdDSA public key (generated once) |
| `SUEnableAutomaticChecks` | `true` |

### 3. Entitlements

Required entitlement for downloading updates:
- `com.apple.security.network.client`

### 4. SparkleUpdaterService

New file: `Sources/Services/SparkleUpdaterService.swift`

```swift
import Sparkle

@MainActor
final class SparkleUpdaterService: ObservableObject {
    private let updaterController: SPUStandardUpdaterController

    var updater: SPUUpdater {
        updaterController.updater
    }

    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    func checkForUpdates() {
        updater.checkForUpdates()
    }

    var canCheckForUpdates: Bool {
        updater.canCheckForUpdates
    }

    var automaticallyChecksForUpdates: Bool {
        get { updater.automaticallyChecksForUpdates }
        set { updater.automaticallyChecksForUpdates = newValue }
    }

    var lastUpdateCheckDate: Date? {
        updater.lastUpdateCheckDate
    }
}
```

### 5. App Integration

**ClaudeCodeMonitorApp.swift** — add menu command:

```swift
@main
struct ClaudeCodeMonitorApp: App {
    @StateObject private var sparkleService = SparkleUpdaterService()

    var body: some Scene {
        // ... existing scenes

        Settings {
            SettingsView()
        }
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates...") {
                    sparkleService.checkForUpdates()
                }
                .disabled(!sparkleService.canCheckForUpdates)
            }
        }
    }
}
```

### 6. Settings UI

Add to `SettingsView.swift`:

```swift
Section("Updates") {
    Toggle("Check for updates automatically", isOn: $sparkleService.automaticallyChecksForUpdates)

    HStack {
        Button("Check Now") {
            sparkleService.checkForUpdates()
        }
        .disabled(!sparkleService.canCheckForUpdates)

        Spacer()

        if let lastCheck = sparkleService.lastUpdateCheckDate {
            Text("Last checked: \(lastCheck, style: .relative) ago")
                .font(.terminalCaptionSmall)
                .foregroundStyle(Color.noirTextTertiary)
        }
    }
}
```

## Release Workflow

### One-Time Setup

1. Generate EdDSA key pair:
   ```bash
   ./bin/generate_keys
   ```
   - Private key: Store securely (GitHub secret for CI)
   - Public key: Add to Info.plist as `SUPublicEDKey`

2. Create initial `appcast.xml` in repo root

### Per-Release Process

1. Build and archive app (Developer ID signed)
2. Create DMG or ZIP
3. Sign archive with EdDSA: `./bin/sign_update YourApp.dmg`
4. Create GitHub Release, attach signed DMG
5. Run `generate_appcast` to update appcast.xml
6. Commit and push appcast.xml

### Automation (Future)

GitHub Actions workflow can automate steps 2-6 on tagged releases.

## Files to Create/Modify

| File | Action |
|------|--------|
| `Package.swift` | Add Sparkle dependency |
| `Sources/Services/SparkleUpdaterService.swift` | Create new |
| `Sources/App/ClaudeCodeMonitorApp.swift` | Add menu command |
| `Sources/Views/SettingsView.swift` | Add Updates section |
| `ClaudeCodeMonitor.entitlements` | Add network.client |
| `appcast.xml` | Create in repo root |

## Testing

1. Build with Sparkle integrated
2. Verify "Check for Updates..." menu item works
3. Test with a mock appcast pointing to test release
4. Verify update download and install flow
5. Test automatic check on launch behavior
