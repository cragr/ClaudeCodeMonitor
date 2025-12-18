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
        HStack(spacing: 0) {
            // Sidebar (conditionally shown)
            if columnVisibility == .all {
                sidebar
                    .frame(width: 260)
                    .transition(.move(edge: .leading))
            }

            // Detail content
            mainContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .animation(reduceMotion ? .none : .easeInOut(duration: 0.2), value: columnVisibility)
        .toolbar {
            toolbarContent
        }
        .toolbarBackground(Color.noirBackground, for: .windowToolbar)
        .toolbarBackground(.visible, for: .windowToolbar)
        .background(Color.noirBackground)
    }

    private var navigationSubtitle: String {
        if selectedTab == .localStatsCache || selectedTab == .smokeTest {
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
        ZStack {
            // Background
            Color.noirSidebar
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // App title
                sidebarHeader
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.lg)
                    .padding(.bottom, Spacing.md)

                Divider()
                    .background(Color.noirStroke)

                // Navigation items
                ScrollView {
                    VStack(spacing: Spacing.xs) {
                        // Main section
                        TerminalSectionHeader("Dashboard")
                            .padding(.horizontal, Spacing.lg)
                            .padding(.top, Spacing.lg)
                            .padding(.bottom, Spacing.sm)

                        ForEach(DashboardTab.allCases.filter { $0 != .smokeTest }) { tab in
                            TerminalSidebarRow(
                                tab: tab,
                                icon: iconForTab(tab),
                                color: colorForTab(tab),
                                isSelected: selectedTab == tab
                            )
                            .onTapGesture {
                                selectTab(tab)
                            }
                        }

                        // Developer section
                        TerminalSectionHeader("Developer")
                            .padding(.horizontal, Spacing.lg)
                            .padding(.top, Spacing.xl)
                            .padding(.bottom, Spacing.sm)

                        TerminalSidebarRow(
                            tab: .smokeTest,
                            icon: iconForTab(.smokeTest),
                            color: .noirTextTertiary,
                            isSelected: selectedTab == .smokeTest
                        )
                        .onTapGesture {
                            selectTab(.smokeTest)
                        }
                    }
                    .padding(.bottom, Spacing.lg)
                }

                // Status footer
                statusFooter
            }
        }
    }

    private var sidebarHeader: some View {
        HStack(spacing: Spacing.sm) {
            // Terminal icon with glow
            ZStack {
                RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                    .fill(Color.phosphorCyan.opacity(0.15))
                    .frame(width: 28, height: 28)

                Image(systemName: "terminal.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.phosphorCyan)
                    .phosphorGlow(.phosphorCyan, intensity: 0.5, isActive: true)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text("CLAUDE CODE")
                    .font(.terminalCaptionSmall)
                    .foregroundStyle(Color.noirTextSecondary)
                    .tracking(1.5)

                Text("Monitor")
                    .font(.terminalTitle)
                    .foregroundStyle(Color.noirTextPrimary)
            }

            Spacer()

            // Cost badge (if connected)
            if metricsService.connectionStatus.isConnected {
                Text(metricsService.dashboardData.formattedCost)
                    .font(.terminalDataSmall)
                    .foregroundStyle(Color.phosphorGreen)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xxs)
                    .background {
                        Capsule()
                            .fill(Color.phosphorGreen.opacity(0.15))
                    }
                    .phosphorGlow(.phosphorGreen, intensity: 0.3, isActive: true)
                    .accessibilityLabel("Total cost: \(metricsService.dashboardData.formattedCost)")
            }
        }
    }

    private var statusFooter: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Rectangle()
                .fill(Color.noirStroke)
                .frame(height: 1)

            HStack(spacing: Spacing.sm) {
                TerminalStatusBadge(status: metricsService.connectionStatus)

                Spacer()

                if metricsService.isLoading {
                    TerminalLoadingIndicator(color: .phosphorCyan)
                        .accessibilityLabel("Loading")
                }
            }

            if let lastRefresh = metricsService.lastRefresh {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "clock")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.noirTextTertiary)
                        .accessibilityHidden(true)
                    Text("Updated \(lastRefresh, style: .relative) ago")
                        .font(.terminalCaptionSmall)
                        .foregroundStyle(Color.noirTextTertiary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Last updated \(lastRefresh, style: .relative) ago")
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(Color.noirSurface.opacity(0.5))
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        ZStack {
            // Deep background
            Color.noirBackground
                .ignoresSafeArea()

            // Subtle noise texture
            NoiseTexture(opacity: 0.02)
                .ignoresSafeArea()

            // Content
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
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // Leading: Custom sidebar toggle (cyan)
        ToolbarItem(placement: .navigation) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    columnVisibility = columnVisibility == .all ? .detailOnly : .all
                }
            }) {
                Image(systemName: columnVisibility == .all ? "sidebar.left" : "sidebar.leading")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.phosphorCyan)
            }
            .buttonStyle(.plain)
            .help("Toggle sidebar")
        }

        // Center: Time range picker (only for relevant tabs)
        ToolbarItem(placement: .principal) {
            if selectedTab == .summary || selectedTab == .tokenMetrics {
                TerminalTimeRangePicker(selection: $metricsService.currentTimeRange)
            } else {
                // Empty spacer for other tabs
                Color.clear.frame(width: 1)
            }
        }

        // Trailing: Status and refresh grouped together
        ToolbarItem(placement: .primaryAction) {
            HStack(spacing: Spacing.sm) {
                TerminalStatusBadge(status: metricsService.connectionStatus)

                Button(action: { Task { await metricsService.refreshDashboard() } }) {
                    HStack(spacing: Spacing.xs) {
                        if metricsService.isLoading {
                            TerminalLoadingIndicator(color: .phosphorCyan)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11, weight: .medium))
                        }
                    }
                    .foregroundStyle(Color.phosphorCyan)
                    .frame(width: 28, height: 22)
                    .background {
                        RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                            .fill(Color.phosphorCyan.opacity(0.1))
                            .overlay {
                                RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                                    .strokeBorder(Color.phosphorCyan.opacity(0.3), lineWidth: 1)
                            }
                    }
                }
                .buttonStyle(.plain)
                .disabled(metricsService.isLoading)
                .help("Refresh dashboard (⌘R)")
                .keyboardShortcut("r", modifiers: .command)
                .accessibilityLabel(metricsService.isLoading ? "Refreshing" : "Refresh dashboard")
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
        case .summary: return "square.grid.2x2"
        case .tokenMetrics: return "waveform.path.ecg"
        case .localStatsCache: return "internaldrive"
        case .smokeTest: return "stethoscope"
        }
    }

    private func colorForTab(_ tab: DashboardTab) -> Color {
        switch tab {
        case .summary: return .phosphorGreen
        case .tokenMetrics: return .phosphorCyan
        case .localStatsCache: return .phosphorPurple
        case .smokeTest: return .noirTextTertiary
        }
    }
}

// MARK: - Terminal Sidebar Row Component

struct TerminalSidebarRow: View {
    let tab: ContentView.DashboardTab
    let icon: String
    let color: Color
    let isSelected: Bool
    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Icon with glow effect when selected
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isSelected ? color : Color.noirTextSecondary)
                .frame(width: 20)
                .phosphorGlow(color, intensity: 0.5, isActive: isSelected)
                .accessibilityHidden(true)

            // Title and description
            VStack(alignment: .leading, spacing: 2) {
                Text(tab.rawValue)
                    .font(.terminalBody)
                    .foregroundStyle(isSelected ? Color.noirTextPrimary : Color.noirTextSecondary)

                if isHovered || isSelected {
                    Text(tab.description)
                        .font(.terminalCaptionSmall)
                        .foregroundStyle(Color.noirTextTertiary)
                        .lineLimit(1)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            Spacer()

            // Keyboard shortcut hint
            Text("⌘\(tab.shortcutKey)")
                .font(.terminalDataSmall)
                .foregroundStyle(Color.noirTextQuaternary)
                .opacity(isHovered ? 1 : 0)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                    .fill(color.opacity(0.12))
                    .overlay {
                        RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                            .strokeBorder(color.opacity(0.25), lineWidth: 1)
                    }
            } else if isHovered {
                RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                    .fill(Color.noirSurface)
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(tab.rawValue). \(tab.description)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Terminal Time Range Picker

struct TerminalTimeRangePicker: View {
    @Binding var selection: TimeRangePreset
    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Menu {
            ForEach(TimeRangePreset.allCases.filter { $0 != .custom }, id: \.self) { preset in
                Button(action: { selection = preset }) {
                    HStack {
                        Text(preset.displayName)
                        if selection == preset {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "calendar")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.phosphorAmber)
                    .phosphorGlow(.phosphorAmber, intensity: 0.4, isActive: isHovered)

                Text(selection.displayName)
                    .font(.terminalTitle)
                    .foregroundStyle(Color.noirTextPrimary)

                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.noirTextSecondary)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm)
            .background {
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .fill(Color.noirSurface)
                    .overlay {
                        RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                            .strokeBorder(isHovered ? Color.phosphorAmber.opacity(0.5) : Color.noirStroke, lineWidth: 1)
                    }
            }
            .shadow(color: isHovered ? Color.phosphorAmber.opacity(0.2) : .clear, radius: 8, y: 2)
        }
        .menuStyle(.borderlessButton)
        .onHover { hovering in
            withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .accessibilityLabel("Time range: \(selection.displayName)")
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
