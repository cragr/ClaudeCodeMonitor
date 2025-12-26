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
