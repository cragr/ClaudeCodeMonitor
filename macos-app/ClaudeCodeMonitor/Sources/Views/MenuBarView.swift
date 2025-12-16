import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var metricsService: MetricsService
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Image(systemName: "terminal.fill")
                    .foregroundStyle(.blue)
                Text("Claude Code Monitor")
                    .font(.headline)
                Spacer()
                statusIndicator
            }

            Divider()

            // Quick Stats
            if metricsService.connectionStatus.isConnected {
                quickStatsView
            } else {
                disconnectedView
            }

            Divider()

            // Actions
            actionsView
        }
        .padding()
        .frame(width: 280)
    }

    // MARK: - Status Indicator

    private var statusIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var statusColor: Color {
        switch metricsService.connectionStatus {
        case .connected: return .green
        case .connecting: return .orange
        case .disconnected, .unknown: return .red
        }
    }

    private var statusText: String {
        switch metricsService.connectionStatus {
        case .connected: return "Connected"
        case .connecting: return "Connecting"
        case .disconnected, .unknown: return "Offline"
        }
    }

    // MARK: - Quick Stats

    private var quickStatsView: some View {
        VStack(spacing: 8) {
            if settingsManager.showMenuBarTokens {
                MenuBarStatRow(
                    icon: "number.circle.fill",
                    label: "Tokens (\(metricsService.currentTimeRange.shortName))",
                    value: metricsService.dashboardData.formattedTokens,
                    color: .blue
                )
            }

            if settingsManager.showMenuBarCost {
                MenuBarStatRow(
                    icon: "dollarsign.circle.fill",
                    label: "Cost (\(metricsService.currentTimeRange.shortName))",
                    value: metricsService.dashboardData.formattedCost,
                    color: .green
                )
            }

            MenuBarStatRow(
                icon: "clock.fill",
                label: "Active Time",
                value: metricsService.dashboardData.formattedActiveTime,
                color: .orange
            )

            if isExpanded {
                Divider()

                MenuBarStatRow(
                    icon: "terminal.fill",
                    label: "Sessions",
                    value: String(format: "%.0f", metricsService.dashboardData.sessionCount),
                    color: .purple
                )

                MenuBarStatRow(
                    icon: "plus.circle.fill",
                    label: "Lines Added",
                    value: String(format: "%.0f", metricsService.dashboardData.linesAdded),
                    color: .mint
                )

                MenuBarStatRow(
                    icon: "minus.circle.fill",
                    label: "Lines Removed",
                    value: String(format: "%.0f", metricsService.dashboardData.linesRemoved),
                    color: .red
                )
            }

            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Text(isExpanded ? "Show Less" : "Show More")
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Disconnected View

    private var disconnectedView: some View {
        VStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.title2)
                .foregroundStyle(.secondary)

            Text("Not Connected")
                .font(.subheadline)

            Text(metricsService.errorMessage ?? "Unable to reach Prometheus")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Retry") {
                Task { await metricsService.checkConnection() }
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Actions

    private var actionsView: some View {
        VStack(spacing: 4) {
            Button(action: { Task { await metricsService.refreshDashboard() } }) {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .disabled(metricsService.isLoading)

            Button(action: openMainWindow) {
                Label("Open Dashboard", systemImage: "rectangle.expand.vertical")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Divider()

            Button(action: { NSApp.terminate(nil) }) {
                Label("Quit Claude Code Monitor", systemImage: "power")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("q", modifiers: .command)

            if let lastRefresh = metricsService.lastRefresh {
                Text("Updated \(lastRefresh, style: .relative) ago")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    // MARK: - Helpers

    private func openMainWindow() {
        if let window = NSApp.windows.first(where: { $0.title.contains("Claude Code Monitor") }) {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            // Create new window if none exists
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

// MARK: - Menu Bar Stat Row

struct MenuBarStatRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 20)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.system(.caption, design: .monospaced, weight: .medium))
        }
    }
}

#if DEBUG
struct MenuBarView_Previews: PreviewProvider {
    static var previews: some View {
        MenuBarView()
            .environmentObject(AppState())
            .environmentObject(SettingsManager())
            .environmentObject(MetricsService())
    }
}
#endif
