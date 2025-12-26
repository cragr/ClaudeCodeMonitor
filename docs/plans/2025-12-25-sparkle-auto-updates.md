# Sparkle Auto-Updates Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add automatic update checking via Sparkle 2 framework, with check-on-launch behavior and user control.

**Architecture:** Sparkle 2 integrated via SPM, wrapped in SparkleUpdaterService for SwiftUI compatibility. Updates hosted on GitHub Releases with appcast.xml in repo root.

**Tech Stack:** Sparkle 2.5+, Swift Package Manager, SwiftUI, GitHub Releases

---

## Task 1: Add Sparkle SPM Dependency

**Files:**
- Modify: `macos-app/Package.swift`

**Step 1: Add Sparkle package dependency**

Open `macos-app/Package.swift` and add Sparkle to dependencies:

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ClaudeCodeMonitor",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "ClaudeCodeMonitor", targets: ["ClaudeCodeMonitor"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.5.0")
    ],
    targets: [
        .executableTarget(
            name: "ClaudeCodeMonitor",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "ClaudeCodeMonitor/Sources"
        ),
        .testTarget(
            name: "ClaudeCodeMonitorTests",
            dependencies: ["ClaudeCodeMonitor"],
            path: "ClaudeCodeMonitorTests"
        )
    ]
)
```

**Step 2: Resolve dependencies**

Run:
```bash
cd macos-app && swift package resolve
```

Expected: Dependencies resolved successfully, Sparkle downloaded

**Step 3: Verify build**

Run:
```bash
cd macos-app && swift build
```

Expected: Build succeeds with Sparkle linked

**Step 4: Commit**

```bash
git add macos-app/Package.swift
git commit -m "feat: add Sparkle 2.5 dependency for auto-updates"
```

---

## Task 2: Create SparkleUpdaterService

**Files:**
- Create: `macos-app/ClaudeCodeMonitor/Sources/Services/SparkleUpdaterService.swift`

**Step 1: Create the service file**

Create `macos-app/ClaudeCodeMonitor/Sources/Services/SparkleUpdaterService.swift`:

```swift
import Foundation
import Sparkle

/// Service wrapper for Sparkle auto-updater
/// Provides SwiftUI-compatible interface to SPUStandardUpdaterController
@MainActor
final class SparkleUpdaterService: ObservableObject {

    /// The underlying Sparkle updater controller
    private let updaterController: SPUStandardUpdaterController

    /// Access to the SPUUpdater for configuration
    var updater: SPUUpdater {
        updaterController.updater
    }

    init() {
        // Initialize with standard UI and start checking for updates
        // startingUpdater: true means it will check on launch
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    /// Manually trigger an update check
    /// Shows UI if update is available
    func checkForUpdates() {
        updater.checkForUpdates()
    }

    /// Whether an update check can be performed right now
    var canCheckForUpdates: Bool {
        updater.canCheckForUpdates
    }

    /// Whether automatic update checks are enabled
    var automaticallyChecksForUpdates: Bool {
        get { updater.automaticallyChecksForUpdates }
        set { updater.automaticallyChecksForUpdates = newValue }
    }

    /// The date of the last update check, if any
    var lastUpdateCheckDate: Date? {
        updater.lastUpdateCheckDate
    }
}
```

**Step 2: Verify build**

Run:
```bash
cd macos-app && swift build
```

Expected: Build succeeds

**Step 3: Commit**

```bash
git add macos-app/ClaudeCodeMonitor/Sources/Services/SparkleUpdaterService.swift
git commit -m "feat: add SparkleUpdaterService wrapper for auto-updates"
```

---

## Task 3: Add Check for Updates Menu Item

**Files:**
- Modify: `macos-app/ClaudeCodeMonitor/Sources/App/ClaudeCodeMonitorApp.swift`

**Step 1: Add SparkleUpdaterService to app**

Modify `ClaudeCodeMonitorApp.swift` to include the sparkle service and menu command:

```swift
import SwiftUI
import AppKit

// App Delegate to handle application lifecycle
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure the app appears in the dock and has a menu bar
        NSApp.setActivationPolicy(.regular)

        // Set dark appearance and cyan accent for the app
        NSApp.appearance = NSAppearance(named: .darkAqua)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Quit the app when the last window is closed
        // The menu bar extra will also be removed
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Clean up any resources if needed
    }
}

@main
struct ClaudeCodeMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()
    @StateObject private var settingsManager = SettingsManager()
    @StateObject private var metricsService = MetricsService()
    @StateObject private var sparkleService = SparkleUpdaterService()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(settingsManager)
                .environmentObject(metricsService)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .windowResizability(.contentMinSize)
        .commands {
            // Add standard app menu commands
            CommandGroup(replacing: .appInfo) {
                Button("About Claude Code Monitor") {
                    NSApp.orderFrontStandardAboutPanel(nil)
                }
            }

            // Add Check for Updates after About
            CommandGroup(after: .appInfo) {
                Button("Check for Updates...") {
                    sparkleService.checkForUpdates()
                }
                .disabled(!sparkleService.canCheckForUpdates)
            }

            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    appState.showSettings = true
                }
                .keyboardShortcut(",", modifiers: .command)

                Divider()

                Button("Quit Claude Code Monitor") {
                    NSApp.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }

            // Add File menu with close window command
            CommandGroup(replacing: .newItem) { }
            CommandGroup(after: .newItem) {
                Button("Close Window") {
                    NSApp.keyWindow?.close()
                }
                .keyboardShortcut("w", modifiers: .command)
            }
        }

        MenuBarExtra("Claude Code Monitor", systemImage: "chart.line.uptrend.xyaxis") {
            MenuBarView()
                .environmentObject(appState)
                .environmentObject(settingsManager)
                .environmentObject(metricsService)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(settingsManager)
                .environmentObject(sparkleService)
        }
    }
}
```

**Step 2: Verify build**

Run:
```bash
cd macos-app && swift build
```

Expected: Build succeeds

**Step 3: Commit**

```bash
git add macos-app/ClaudeCodeMonitor/Sources/App/ClaudeCodeMonitorApp.swift
git commit -m "feat: add Check for Updates menu item"
```

---

## Task 4: Add Updates Section to Settings

**Files:**
- Modify: `macos-app/ClaudeCodeMonitor/Sources/Views/SettingsView.swift`

**Step 1: Add updates tab to SettingsTab enum**

In `SettingsView.swift`, update the enum:

```swift
enum SettingsTab {
    case general, connection, filters, updates
}
```

**Step 2: Add updates tab to TabView**

Add a new tab item in the TabView body after filters:

```swift
TabView(selection: $selectedTab) {
    generalSettings
        .tabItem {
            Label("General", systemImage: "gear")
        }
        .tag(SettingsTab.general)

    connectionSettings
        .tabItem {
            Label("Connection", systemImage: "network")
        }
        .tag(SettingsTab.connection)

    filterSettings
        .tabItem {
            Label("Filters", systemImage: "line.3.horizontal.decrease.circle")
        }
        .tag(SettingsTab.filters)

    updatesSettings
        .tabItem {
            Label("Updates", systemImage: "arrow.triangle.2.circlepath")
        }
        .tag(SettingsTab.updates)
}
```

**Step 3: Add EnvironmentObject for sparkleService**

Add at the top of the struct:

```swift
@EnvironmentObject var sparkleService: SparkleUpdaterService
```

**Step 4: Add updatesSettings computed property**

Add this new view property after `filterSettings`:

```swift
// MARK: - Updates Settings

private var updatesSettings: some View {
    Form {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                Toggle(isOn: Binding(
                    get: { sparkleService.automaticallyChecksForUpdates },
                    set: { sparkleService.automaticallyChecksForUpdates = $0 }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Check for Updates Automatically")
                        Text("Checks for updates when the app launches")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)

                Divider()

                HStack(spacing: 12) {
                    Button(action: {
                        sparkleService.checkForUpdates()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Check Now")
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .disabled(!sparkleService.canCheckForUpdates)

                    Spacer()

                    if let lastCheck = sparkleService.lastUpdateCheckDate {
                        Text("Last checked: \(lastCheck, style: .relative) ago")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } label: {
            Label("Automatic Updates", systemImage: "arrow.triangle.2.circlepath.circle")
                .font(.headline)
        }

        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                    Text("How Updates Work")
                        .font(.caption.weight(.medium))
                }
                Text("When an update is available, you'll see a notification with release notes. You can choose when to download and install.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(4)
        } label: {
            Label("Information", systemImage: "questionmark.circle")
                .font(.headline)
        }

        Spacer()
    }
    .formStyle(.grouped)
    .padding(20)
}
```

**Step 5: Verify build**

Run:
```bash
cd macos-app && swift build
```

Expected: Build succeeds

**Step 6: Commit**

```bash
git add macos-app/ClaudeCodeMonitor/Sources/Views/SettingsView.swift
git commit -m "feat: add Updates tab to Settings with auto-check toggle"
```

---

## Task 5: Create Appcast XML Template

**Files:**
- Create: `appcast.xml`

**Step 1: Create appcast.xml**

Create `appcast.xml` in the repository root:

```xml
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>Claude Code Monitor Updates</title>
    <link>https://github.com/cragr/ClaudeCodeMonitor/releases</link>
    <description>Most recent updates to Claude Code Monitor</description>
    <language>en</language>

    <!--
    To add a new release, add an item like this:

    <item>
      <title>Version X.Y.Z</title>
      <pubDate>Day, DD Mon YYYY HH:MM:SS +0000</pubDate>
      <sparkle:version>X.Y.Z</sparkle:version>
      <sparkle:shortVersionString>X.Y.Z</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <description><![CDATA[
        <h2>What's New</h2>
        <ul>
          <li>Feature 1</li>
          <li>Feature 2</li>
        </ul>
      ]]></description>
      <enclosure
        url="https://github.com/cragr/ClaudeCodeMonitor/releases/download/vX.Y.Z/ClaudeCodeMonitor-X.Y.Z.dmg"
        sparkle:edSignature="YOUR_ED_SIGNATURE_HERE"
        length="FILE_SIZE_IN_BYTES"
        type="application/octet-stream"/>
    </item>
    -->

  </channel>
</rss>
```

**Step 2: Commit**

```bash
git add appcast.xml
git commit -m "feat: add appcast.xml template for Sparkle updates"
```

---

## Task 6: Add SUFeedURL Configuration

**Files:**
- Create: `macos-app/ClaudeCodeMonitor/Sources/App/SparkleConfiguration.swift`

**Step 1: Create configuration file**

Since SPM-based apps don't have Info.plist by default, we configure Sparkle programmatically.

Create `macos-app/ClaudeCodeMonitor/Sources/App/SparkleConfiguration.swift`:

```swift
import Foundation

/// Sparkle update configuration
enum SparkleConfiguration {
    /// URL to the appcast XML file
    static let feedURL = URL(string: "https://raw.githubusercontent.com/cragr/ClaudeCodeMonitor/main/appcast.xml")!

    /// EdDSA public key for verifying update signatures
    /// Generate with: ./bin/generate_keys from Sparkle
    /// TODO: Replace with actual public key before first release
    static let edPublicKey = "REPLACE_WITH_YOUR_ED25519_PUBLIC_KEY"
}
```

**Step 2: Update SparkleUpdaterService to use configuration**

Modify `SparkleUpdaterService.swift` to set the feed URL:

```swift
import Foundation
import Sparkle

/// Service wrapper for Sparkle auto-updater
/// Provides SwiftUI-compatible interface to SPUStandardUpdaterController
@MainActor
final class SparkleUpdaterService: ObservableObject {

    /// The underlying Sparkle updater controller
    private let updaterController: SPUStandardUpdaterController

    /// Access to the SPUUpdater for configuration
    var updater: SPUUpdater {
        updaterController.updater
    }

    init() {
        // Initialize with standard UI and start checking for updates
        // startingUpdater: true means it will check on launch
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        // Configure feed URL programmatically (since we don't use Info.plist)
        updater.setFeedURL(SparkleConfiguration.feedURL)
    }

    /// Manually trigger an update check
    /// Shows UI if update is available
    func checkForUpdates() {
        updater.checkForUpdates()
    }

    /// Whether an update check can be performed right now
    var canCheckForUpdates: Bool {
        updater.canCheckForUpdates
    }

    /// Whether automatic update checks are enabled
    var automaticallyChecksForUpdates: Bool {
        get { updater.automaticallyChecksForUpdates }
        set { updater.automaticallyChecksForUpdates = newValue }
    }

    /// The date of the last update check, if any
    var lastUpdateCheckDate: Date? {
        updater.lastUpdateCheckDate
    }
}
```

**Step 3: Verify build**

Run:
```bash
cd macos-app && swift build
```

Expected: Build succeeds

**Step 4: Commit**

```bash
git add macos-app/ClaudeCodeMonitor/Sources/App/SparkleConfiguration.swift
git add macos-app/ClaudeCodeMonitor/Sources/Services/SparkleUpdaterService.swift
git commit -m "feat: add Sparkle feed URL configuration"
```

---

## Task 7: Run Tests and Verify

**Files:**
- None (verification only)

**Step 1: Run all tests**

Run:
```bash
cd macos-app && swift test
```

Expected: All 96 tests pass

**Step 2: Run the app manually**

Run:
```bash
cd macos-app && swift run ClaudeCodeMonitor
```

Expected:
- App launches successfully
- "Check for Updates..." appears in app menu after "About"
- Settings has "Updates" tab
- Updates tab shows toggle and "Check Now" button

**Step 3: Verify menu item**

In the running app:
1. Click "Claude Code Monitor" menu
2. Verify "Check for Updates..." item is visible
3. Click it (will fail to connect to appcast, which is expected)

---

## Task 8: Final Commit and Summary

**Files:**
- None (administrative)

**Step 1: Review all changes**

Run:
```bash
git log --oneline main..HEAD
```

Expected: 6 commits for each task

**Step 2: Create summary commit (if any cleanup needed)**

If there are any uncommitted changes:
```bash
git status
git add -A
git commit -m "chore: cleanup after Sparkle integration"
```

---

## Post-Implementation: Release Setup (Manual Steps)

These steps are done once before the first release:

1. **Generate EdDSA keys:**
   ```bash
   # Download Sparkle release and run:
   ./bin/generate_keys
   ```
   - Save private key securely (GitHub secret: `SPARKLE_PRIVATE_KEY`)
   - Update `SparkleConfiguration.edPublicKey` with public key

2. **Update appcast.xml with first release:**
   - Build and sign DMG
   - Calculate EdDSA signature: `./bin/sign_update YourApp.dmg`
   - Add `<item>` to appcast.xml with version, signature, download URL

3. **Commit and tag release:**
   ```bash
   git tag v1.0.0
   git push origin main --tags
   ```

4. **Create GitHub Release:**
   - Upload signed DMG
   - Release notes from appcast description
