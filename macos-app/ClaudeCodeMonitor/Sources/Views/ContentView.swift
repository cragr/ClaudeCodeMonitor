import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var metricsService: MetricsService
    @State private var selectedTab: DashboardTab = .summary
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum DashboardTab: String, CaseIterable, Identifiable {
        case summary = "Summary"
        case tokenMetrics = "Token Metrics"
        case localStatsCache = "Local Stats Cache"
        case smokeTest = "Smoke Test"

        var id: String { rawValue }

        var description: String {
            switch self {
            case .summary: return "Overview of key metrics and costs"
            case .tokenMetrics: return "Token usage and model performance"
            case .localStatsCache: return "Local Claude Code usage statistics"
            case .smokeTest: return "Debug and test connectivity"
            }
        }

        var keyboardShortcut: KeyEquivalent {
            switch self {
            case .summary: return "1"
            case .tokenMetrics: return "2"
            case .localStatsCache: return "3"
            case .smokeTest: return "4"
            }
        }

        var shortcutKey: String {
            switch self {
            case .summary: return "1"
            case .tokenMetrics: return "2"
            case .localStatsCache: return "3"
            case .smokeTest: return "4"
            }
        }
    }

    var body: some View {
        navigationContent
            .onAppear {
                setupMetricsService()
            }
            .onChange(of: settingsManager.prometheusBaseURLString) { _, _ in
                metricsService.prometheusURL = settingsManager.prometheusURL
            }
    }

    private var navigationContent: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 300)
        } detail: {
            mainContent
        }
        .navigationSplitViewStyle(.balanced)
        .navigationTitle(selectedTab.rawValue)
        .navigationSubtitle(navigationSubtitle)
        .toolbar {
            toolbarContent
        }
    }

    private var navigationSubtitle: String {
        if selectedTab == .localStatsCache {
            return ""
        }
        if metricsService.connectionStatus.isConnected {
            return metricsService.currentTimeRange.displayName
        } else {
            return "Not Connected"
        }
    }

    private func selectTab(_ tab: DashboardTab) {
        withAnimation(reduceMotion ? .none : .spring(response: 0.3)) {
            selectedTab = tab
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selectedTab) {
            Section {
                ForEach(DashboardTab.allCases.filter { $0 != .smokeTest }) { tab in
                    SidebarRow(
                        tab: tab,
                        icon: iconForTab(tab),
                        color: colorForTab(tab),
                        isSelected: selectedTab == tab
                    )
                    .tag(tab)
                    .accessibilityLabel("\(tab.rawValue). \(tab.description)")
                }
            } header: {
                HStack {
                    Text("Dashboard")
                    Spacer()
                    if metricsService.connectionStatus.isConnected {
                        Text(metricsService.dashboardData.formattedCost)
                            .font(.caption2.monospacedDigit())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.green.opacity(0.15))
                            .foregroundStyle(.green)
                            .clipShape(Capsule())
                            .accessibilityLabel("Total cost: \(metricsService.dashboardData.formattedCost)")
                    }
                }
            }

            #if DEBUG
            Section("Developer") {
                SidebarRow(
                    tab: .smokeTest,
                    icon: iconForTab(.smokeTest),
                    color: .gray,
                    isSelected: selectedTab == .smokeTest
                )
                .tag(DashboardTab.smokeTest)
            }
            #endif
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            statusFooter
        }
    }

    private var statusFooter: some View {
        VStack(alignment: .leading, spacing: .spacingSM) {
            Divider()

            HStack(spacing: .spacingSM) {
                ConnectionStatusBadge(status: metricsService.connectionStatus)

                Spacer()

                if metricsService.isLoading {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 14, height: 14)
                        .accessibilityLabel("Loading")
                }
            }

            if let lastRefresh = metricsService.lastRefresh {
                HStack(spacing: .spacingXS) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                    Text("Updated \(lastRefresh, style: .relative) ago")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Last updated \(lastRefresh, style: .relative) ago")
            }
        }
        .padding(.horizontal, .spacingLG)
        .padding(.vertical, .spacingSM)
        .background(.ultraThinMaterial)
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        switch selectedTab {
        case .summary:
            SummaryDashboardView(metricsService: metricsService)
        case .tokenMetrics:
            PerformanceDashboardView(metricsService: metricsService)
        case .localStatsCache:
            StatsCacheView()
        case .smokeTest:
            SmokeTestView(metricsService: metricsService)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            if selectedTab == .summary || selectedTab == .tokenMetrics {
                Picker("Time Range", selection: $metricsService.currentTimeRange) {
                    ForEach(TimeRangePreset.allCases.filter { $0 != .custom }, id: \.self) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }
                .pickerStyle(.menu)
                .help("Select time range for metrics")
                .accessibilityLabel("Time range selector")
            }
        }

        ToolbarItemGroup(placement: .primaryAction) {
            ConnectionStatusBadge(status: metricsService.connectionStatus)

            Divider()

            Button(action: { Task { await metricsService.refreshDashboard() } }) {
                if metricsService.isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 16, height: 16)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .symbolRenderingMode(.hierarchical)
                }
            }
            .disabled(metricsService.isLoading)
            .help("Refresh dashboard (⌘R)")
            .keyboardShortcut("r", modifiers: .command)
            .accessibilityLabel(metricsService.isLoading ? "Refreshing" : "Refresh dashboard")
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
        case .tokenMetrics: return "gauge.with.dots.needle.bottom.50percent"
        case .localStatsCache: return "doc.badge.clock"
        case .smokeTest: return "checkmark.shield"
        }
    }

    private func colorForTab(_ tab: DashboardTab) -> Color {
        switch tab {
        case .summary: return .blue
        case .tokenMetrics: return .orange
        case .localStatsCache: return .purple
        case .smokeTest: return .gray
        }
    }
}

// MARK: - Sidebar Row Component

struct SidebarRow: View {
    let tab: ContentView.DashboardTab
    let icon: String
    let color: Color
    let isSelected: Bool
    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(isSelected ? color : .secondary)
                .frame(width: 20)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(tab.rawValue)
                    .font(.system(.body, weight: isSelected ? .medium : .regular))

                if isHovered || isSelected {
                    Text(tab.description)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text("⌘\(tab.shortcutKey)")
                .font(.caption2.monospaced())
                .foregroundStyle(.quaternary)
                .opacity(isHovered ? 1 : 0)
                .accessibilityHidden(true)
        }
        .padding(.vertical, .spacingXS)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
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
