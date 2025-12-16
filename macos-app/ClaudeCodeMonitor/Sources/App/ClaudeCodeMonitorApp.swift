import SwiftUI
import AppKit

// App Delegate to handle application lifecycle
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure the app appears in the dock and has a menu bar
        NSApp.setActivationPolicy(.regular)
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
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(settingsManager)
                .environmentObject(metricsService)
        }
        .windowStyle(.automatic)
        .windowResizability(.contentMinSize)
        .commands {
            // Add standard app menu commands
            CommandGroup(replacing: .appInfo) {
                Button("About Claude Code Monitor") {
                    NSApp.orderFrontStandardAboutPanel(nil)
                }
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
        }
    }
}
