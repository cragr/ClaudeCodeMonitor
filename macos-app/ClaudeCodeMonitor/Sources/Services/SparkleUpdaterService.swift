import Foundation
import Sparkle

/// Service wrapper for Sparkle auto-updater
/// Provides SwiftUI-compatible interface to SPUStandardUpdaterController
@MainActor
final class SparkleUpdaterService: ObservableObject {

    /// The underlying Sparkle updater controller
    private let updaterController: SPUStandardUpdaterController

    /// Published property to track if updater started successfully
    @Published var updaterStarted = false
    @Published var startError: String?

    /// Access to the SPUUpdater for configuration
    var updater: SPUUpdater {
        updaterController.updater
    }

    init() {
        // Initialize without auto-starting to handle errors gracefully
        // Feed URL is configured via SUFeedURL in Info.plist (set by build-app.sh)
        updaterController = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        // Try to start the updater manually
        do {
            try updater.start()
            updaterStarted = true
            print("Sparkle updater started successfully")
        } catch {
            startError = error.localizedDescription
            print("Sparkle updater failed to start: \(error)")
        }
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
