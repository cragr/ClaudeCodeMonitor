import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var metricsService: MetricsService
    @AppStorage("menuBarDetailLevel") private var detailLevel: DetailLevel = .standard
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum DetailLevel: String, CaseIterable {
        case compact, standard, expanded

        var icon: String {
            switch self {
            case .compact: return "rectangle.compress.vertical"
            case .standard: return "rectangle"
            case .expanded: return "rectangle.expand.vertical"
            }
        }

        var description: String {
            switch self {
            case .compact: return "Essential metrics only"
            case .standard: return "Key metrics and stats"
            case .expanded: return "All available metrics"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
                .padding(.horizontal, .spacingLG)
                .padding(.vertical, .spacingMD)

            Divider()

            timeRangeSelector
                .padding(.horizontal, .spacingLG)
                .padding(.vertical, .spacingSM)

            Divider()

            ScrollView {
                VStack(spacing: .spacingLG) {
                    if metricsService.connectionStatus.isConnected {
                        quickStatsView
                    } else {
                        disconnectedView
                    }
                }
                .padding(.spacingLG)
            }
            .frame(maxHeight: maxContentHeight)

            Divider()

            actionsView
                .padding(.spacingMD)
        }
        .frame(width: 340)
        .background(.regularMaterial)
    }

    private var maxContentHeight: CGFloat {
        switch detailLevel {
        case .compact: return 180
        case .standard: return 280
        case .expanded: return 420
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack(spacing: 10) {
            Image(systemName: "terminal.fill")
                .font(.title3)
                .foregroundStyle(.tint)
                .symbolRenderingMode(.hierarchical)
                .accessibilityHidden(true)

            Text("Claude Code")
                .font(.headline)

            Spacer()

            Picker("Detail", selection: $detailLevel) {
                ForEach(DetailLevel.allCases, id: \.self) { level in
                    Image(systemName: level.icon)
                        .tag(level)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 90)
            .labelsHidden()
            .help("Change detail level")
            .accessibilityLabel("Detail level")

            ConnectionStatusBadge(status: metricsService.connectionStatus)
        }
    }

    // MARK: - Time Range Selector

    private var timeRangeSelector: some View {
        HStack(spacing: .spacingSM) {
            Image(systemName: "calendar")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Picker("Time Range", selection: $metricsService.currentTimeRange) {
                ForEach(TimeRangePreset.allCases.filter { $0 != .custom }, id: \.self) { preset in
                    Text(preset.shortName).tag(preset)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity)
            .labelsHidden()
            .accessibilityLabel("Time range")

            HStack(spacing: .spacingXS) {
                QuickTimeButton(preset: .last1Hour, current: $metricsService.currentTimeRange)
                QuickTimeButton(preset: .last1Day, current: $metricsService.currentTimeRange)
                QuickTimeButton(preset: .last1Week, current: $metricsService.currentTimeRange)
            }
        }
        .padding(.spacingSM)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    // MARK: - Quick Stats

    private var quickStatsView: some View {
        VStack(spacing: .spacingMD) {
            // Primary stats - always visible
            GroupBox {
                VStack(spacing: 10) {
                    ModernMenuBarStatRow(
                        icon: "dollarsign.circle.fill",
                        label: "Cost",
                        value: metricsService.dashboardData.formattedCost,
                        color: .metricGreen
                    )

                    if detailLevel != .compact {
                        ModernMenuBarStatRow(
                            icon: "number.circle.fill",
                            label: "Tokens",
                            value: metricsService.dashboardData.formattedTokens,
                            color: .metricBlue
                        )
                    }

                    ModernMenuBarStatRow(
                        icon: "clock.fill",
                        label: "Active Time",
                        value: metricsService.dashboardData.formattedActiveTime,
                        color: .metricOrange
                    )
                }
            } label: {
                HStack {
                    Text("Usage")
                        .font(.caption.weight(.medium))
                    Spacer()
                    Text(metricsService.currentTimeRange.shortName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Usage metrics for \(metricsService.currentTimeRange.shortName)")

            // Code stats - visible in standard and expanded
            if detailLevel != .compact {
                GroupBox {
                    VStack(spacing: 10) {
                        ModernMenuBarStatRow(
                            icon: "plus.circle.fill",
                            label: "Lines Added",
                            value: "+\(String(format: "%.0f", metricsService.dashboardData.linesAdded))",
                            color: .metricMint
                        )

                        ModernMenuBarStatRow(
                            icon: "minus.circle.fill",
                            label: "Lines Removed",
                            value: "-\(String(format: "%.0f", metricsService.dashboardData.linesRemoved))",
                            color: .metricRed
                        )
                    }
                } label: {
                    Text("Code Changes")
                        .font(.caption.weight(.medium))
                }
                .transition(.asymmetric(
                    insertion: .push(from: .bottom).combined(with: .opacity),
                    removal: .push(from: .top).combined(with: .opacity)
                ))
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Code changes")
            }

            // Git stats - only in expanded mode
            if detailLevel == .expanded {
                GroupBox {
                    VStack(spacing: 10) {
                        ModernMenuBarStatRow(
                            icon: "checkmark.circle.fill",
                            label: "Commits",
                            value: String(format: "%.0f", metricsService.dashboardData.commitCount),
                            color: .metricIndigo
                        )

                        ModernMenuBarStatRow(
                            icon: "arrow.triangle.pull",
                            label: "Pull Requests",
                            value: String(format: "%.0f", metricsService.dashboardData.prCount),
                            color: .metricTeal
                        )
                    }
                } label: {
                    Text("Git Activity")
                        .font(.caption.weight(.medium))
                }
                .transition(.asymmetric(
                    insertion: .push(from: .bottom).combined(with: .opacity),
                    removal: .push(from: .top).combined(with: .opacity)
                ))
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Git activity")
            }
        }
        .animation(reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.8), value: detailLevel)
    }

    // MARK: - Disconnected View

    private var disconnectedView: some View {
        VStack(spacing: .spacingSM) {
            Image(systemName: "wifi.slash")
                .font(.title2)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

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
            .controlSize(.regular)
        }
        .padding(.vertical, .spacingSM)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Not connected to Prometheus. \(metricsService.errorMessage ?? "")")
    }

    // MARK: - Actions

    private var actionsView: some View {
        VStack(spacing: .spacingSM) {
            HStack(spacing: .spacingSM) {
                Button(action: { Task { await metricsService.refreshDashboard() } }) {
                    HStack(spacing: 6) {
                        if metricsService.isLoading {
                            ProgressView()
                                .scaleEffect(0.5)
                                .frame(width: 14, height: 14)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 14))
                        }
                        Text("Refresh")
                            .font(.system(size: 13))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .disabled(metricsService.isLoading)
                .accessibilityLabel("Refresh metrics")

                Button(action: openMainWindow) {
                    HStack(spacing: 6) {
                        Image(systemName: "macwindow")
                            .font(.system(size: 14))
                        Text("Dashboard")
                            .font(.system(size: 13))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .accessibilityLabel("Open dashboard window")
            }

            HStack {
                if let lastRefresh = metricsService.lastRefresh {
                    HStack(spacing: .spacingXS) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                            .accessibilityHidden(true)
                        Text("Updated \(lastRefresh, style: .relative) ago")
                            .font(.caption2)
                    }
                    .foregroundStyle(.tertiary)
                    .accessibilityLabel("Last updated \(lastRefresh, style: .relative) ago")
                }

                Spacer()

                Button(action: { NSApp.terminate(nil) }) {
                    Image(systemName: "power")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("q", modifiers: .command)
                .help("Quit Claude Code Monitor")
                .accessibilityLabel("Quit application")
            }
        }
    }

    // MARK: - Helpers

    private func openMainWindow() {
        if let window = NSApp.windows.first(where: { $0.title.contains("Claude Code Monitor") }) {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

// MARK: - Modern Menu Bar Stat Row

struct ModernMenuBarStatRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: .spacingMD) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 20)
                .accessibilityHidden(true)

            Text(label)
                .font(.cardSubtitle)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.system(.caption, design: .monospaced, weight: .semibold))
                .foregroundStyle(isHovered ? .primary : .secondary)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, .spacingSM)
        .padding(.vertical, .spacingXS)
        .background(isHovered ? color.opacity(0.08) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .onHover { hovering in
            withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - Quick Time Button

struct QuickTimeButton: View {
    let preset: TimeRangePreset
    @Binding var current: TimeRangePreset
    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isSelected: Bool {
        current == preset
    }

    private var shortLabel: String {
        switch preset {
        case .last1Hour: return "1h"
        case .last1Day: return "1d"
        case .last1Week: return "1w"
        default: return preset.shortName
        }
    }

    var body: some View {
        Button(action: { current = preset }) {
            Text(shortLabel)
                .font(.caption2.weight(.medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(isSelected ? Color.accentColor : (isHovered ? Color.gray.opacity(0.2) : Color.clear))
                .foregroundStyle(isSelected ? .white : .secondary)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
        .accessibilityLabel("Set time range to \(preset.displayName)")
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
