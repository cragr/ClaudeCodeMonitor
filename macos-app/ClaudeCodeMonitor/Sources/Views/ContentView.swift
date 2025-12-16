import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var metricsService: MetricsService
    @State private var selectedTab: DashboardTab = .summary

    enum DashboardTab: String, CaseIterable {
        case summary = "Summary"
        case performance = "Performance"
        case historical = "Historical"
        case smokeTest = "Smoke Test"
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            mainContent
        }
        .navigationTitle("Claude Code Monitor")
        .toolbar {
            toolbarContent
        }
        .onAppear {
            setupMetricsService()
        }
        .onChange(of: settingsManager.prometheusBaseURLString) { _, _ in
            metricsService.prometheusURL = settingsManager.prometheusURL
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selectedTab) {
            Section("Views") {
                ForEach(DashboardTab.allCases, id: \.self) { tab in
                    Label(tab.rawValue, systemImage: iconForTab(tab))
                        .tag(tab)
                }
            }

            Section("Status") {
                HStack {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text(metricsService.connectionStatus.displayText)
                        .font(.caption)
                }

                if let lastRefresh = metricsService.lastRefresh {
                    Text("Updated: \(lastRefresh, style: .relative) ago")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 180)
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        switch selectedTab {
        case .summary:
            SummaryDashboardView(metricsService: metricsService)
        case .performance:
            PerformanceDashboardView(metricsService: metricsService)
        case .historical:
            HistoricalDashboardView(metricsService: metricsService)
        case .smokeTest:
            SmokeTestView(metricsService: metricsService)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if metricsService.isLoading {
            ToolbarItem(placement: .primaryAction) {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 16, height: 16)
            }
        }

        if selectedTab == .summary || selectedTab == .performance {
            ToolbarItem(placement: .primaryAction) {
                Picker("Time Range", selection: $metricsService.currentTimeRange) {
                    ForEach(TimeRangePreset.allCases.filter { $0 != .custom }, id: \.self) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 160)
            }
        }
    }

    // MARK: - Helpers

    private func setupMetricsService() {
        metricsService.prometheusURL = settingsManager.prometheusURL
        metricsService.currentTimeRange = settingsManager.defaultTimeRange
        metricsService.startAutoRefresh(interval: settingsManager.refreshInterval)
    }

    private func iconForTab(_ tab: DashboardTab) -> String {
        switch tab {
        case .summary: return "chart.pie.fill"
        case .performance: return "gauge.with.dots.needle.bottom.50percent"
        case .historical: return "clock.arrow.circlepath"
        case .smokeTest: return "checkmark.shield"
        }
    }

    private var statusColor: Color {
        switch metricsService.connectionStatus {
        case .connected: return .green
        case .connecting: return .orange
        case .disconnected, .unknown: return .red
        }
    }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AppState())
            .environmentObject(SettingsManager())
            .environmentObject(MetricsService())
    }
}
#endif
