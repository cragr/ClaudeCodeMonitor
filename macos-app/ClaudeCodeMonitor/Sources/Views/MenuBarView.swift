import SwiftUI

// MARK: - Menu Bar View
// Terminal Noir aesthetic for menu bar extra

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
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)

            Divider()
                .background(Color.noirStroke)

            timeRangeSelector
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)

            Divider()
                .background(Color.noirStroke)

            ScrollView {
                VStack(spacing: Spacing.lg) {
                    if metricsService.connectionStatus.isConnected {
                        quickStatsView
                    } else {
                        disconnectedView
                    }
                }
                .padding(Spacing.lg)
            }
            .frame(maxHeight: maxContentHeight)

            Divider()
                .background(Color.noirStroke)

            actionsView
                .padding(Spacing.md)
        }
        .frame(width: 320)
        .background(Color.noirSurface)
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
        HStack(spacing: Spacing.sm) {
            // Icon with glow
            ZStack {
                RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                    .fill(Color.phosphorCyan.opacity(0.15))
                    .frame(width: 26, height: 26)

                Image(systemName: "terminal.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.phosphorCyan)
                    .phosphorGlow(.phosphorCyan, intensity: 0.4, isActive: true)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 0) {
                Text("CLAUDE CODE")
                    .font(.terminalCaptionSmall)
                    .foregroundStyle(Color.noirTextTertiary)
                    .tracking(1)

                Text("Monitor")
                    .font(.terminalTitle)
                    .foregroundStyle(Color.noirTextPrimary)
            }

            Spacer()

            // Detail level picker
            HStack(spacing: Spacing.xxs) {
                ForEach(DetailLevel.allCases, id: \.self) { level in
                    Button(action: { detailLevel = level }) {
                        Image(systemName: level.icon)
                            .font(.system(size: 10))
                            .foregroundStyle(detailLevel == level ? Color.phosphorCyan : Color.noirTextTertiary)
                            .frame(width: 22, height: 22)
                            .background(detailLevel == level ? Color.phosphorCyan.opacity(0.15) : .clear)
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .help(level.description)
                }
            }
            .accessibilityLabel("Detail level")

            TerminalStatusBadge(status: metricsService.connectionStatus)
        }
    }

    // MARK: - Time Range Selector

    private var timeRangeSelector: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "calendar")
                .font(.system(size: 10))
                .foregroundStyle(Color.noirTextTertiary)
                .accessibilityHidden(true)

            Picker("Time Range", selection: $metricsService.currentTimeRange) {
                ForEach(TimeRangePreset.allCases.filter { $0 != .custom }, id: \.self) { preset in
                    Text(preset.shortName).tag(preset)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .accessibilityLabel("Time range")

            Spacer()

            // Quick time buttons
            HStack(spacing: Spacing.xxs) {
                TerminalQuickTimeButton(preset: .last1Hour, current: $metricsService.currentTimeRange)
                TerminalQuickTimeButton(preset: .last1Day, current: $metricsService.currentTimeRange)
                TerminalQuickTimeButton(preset: .last1Week, current: $metricsService.currentTimeRange)
            }
        }
        .padding(Spacing.sm)
        .background(Color.noirBackground.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                .strokeBorder(Color.noirStroke, lineWidth: 1)
        }
    }

    // MARK: - Quick Stats

    private var quickStatsView: some View {
        VStack(spacing: Spacing.md) {
            // Primary stats - always visible
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Text("USAGE")
                        .font(.terminalCaptionSmall)
                        .foregroundStyle(Color.noirTextTertiary)
                        .tracking(1)

                    Spacer()

                    Text(metricsService.currentTimeRange.shortName)
                        .font(.terminalCaptionSmall)
                        .foregroundStyle(Color.noirTextQuaternary)
                }

                VStack(spacing: Spacing.sm) {
                    TerminalMenuBarStatRow(
                        icon: "dollarsign.circle.fill",
                        label: "Cost",
                        value: metricsService.dashboardData.formattedCost,
                        color: .phosphorGreen
                    )

                    if detailLevel != .compact {
                        TerminalMenuBarStatRow(
                            icon: "number.circle.fill",
                            label: "Tokens",
                            value: metricsService.dashboardData.formattedTokens,
                            color: .phosphorCyan
                        )
                    }

                    TerminalMenuBarStatRow(
                        icon: "clock.fill",
                        label: "Active Time",
                        value: metricsService.dashboardData.formattedActiveTime,
                        color: .phosphorAmber
                    )
                }
            }
            .padding(Spacing.md)
            .background {
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .fill(Color.noirBackground.opacity(0.5))
            }
            .overlay {
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .strokeBorder(Color.noirStroke, lineWidth: 1)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Usage metrics for \(metricsService.currentTimeRange.shortName)")

            // Code stats - visible in standard and expanded
            if detailLevel != .compact {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("CODE CHANGES")
                        .font(.terminalCaptionSmall)
                        .foregroundStyle(Color.noirTextTertiary)
                        .tracking(1)

                    VStack(spacing: Spacing.sm) {
                        TerminalMenuBarStatRow(
                            icon: "plus.circle.fill",
                            label: "Lines Added",
                            value: "+\(String(format: "%.0f", metricsService.dashboardData.linesAdded))",
                            color: .phosphorMagenta
                        )

                        TerminalMenuBarStatRow(
                            icon: "minus.circle.fill",
                            label: "Lines Removed",
                            value: "-\(String(format: "%.0f", metricsService.dashboardData.linesRemoved))",
                            color: .phosphorRed
                        )
                    }
                }
                .padding(Spacing.md)
                .background {
                    RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                        .fill(Color.noirBackground.opacity(0.5))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                        .strokeBorder(Color.noirStroke, lineWidth: 1)
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
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("GIT ACTIVITY")
                        .font(.terminalCaptionSmall)
                        .foregroundStyle(Color.noirTextTertiary)
                        .tracking(1)

                    VStack(spacing: Spacing.sm) {
                        TerminalMenuBarStatRow(
                            icon: "checkmark.circle.fill",
                            label: "Commits",
                            value: String(format: "%.0f", metricsService.dashboardData.commitCount),
                            color: .phosphorPurple
                        )

                        TerminalMenuBarStatRow(
                            icon: "arrow.triangle.pull",
                            label: "Pull Requests",
                            value: String(format: "%.0f", metricsService.dashboardData.prCount),
                            color: .phosphorCyan
                        )
                    }
                }
                .padding(Spacing.md)
                .background {
                    RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                        .fill(Color.noirBackground.opacity(0.5))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                        .strokeBorder(Color.noirStroke, lineWidth: 1)
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
        VStack(spacing: Spacing.md) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 28, weight: .thin))
                .foregroundStyle(Color.phosphorRed)
                .phosphorGlow(.phosphorRed, intensity: 0.4, isActive: true)
                .accessibilityHidden(true)

            VStack(spacing: Spacing.xs) {
                Text("NOT CONNECTED")
                    .font(.terminalCaption)
                    .foregroundStyle(Color.noirTextPrimary)
                    .tracking(1)

                Text(metricsService.errorMessage ?? "Unable to reach Prometheus")
                    .font(.terminalCaptionSmall)
                    .foregroundStyle(Color.noirTextSecondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: { Task { await metricsService.checkConnection() } }) {
                Text("RETRY")
                    .font(.terminalCaptionSmall)
                    .tracking(1)
            }
            .buttonStyle(TerminalButtonStyle(color: .phosphorCyan, isProminent: true))
        }
        .padding(.vertical, Spacing.md)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Not connected to Prometheus. \(metricsService.errorMessage ?? "")")
    }

    // MARK: - Actions

    private var actionsView: some View {
        VStack(spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Button(action: { Task { await metricsService.refreshDashboard() } }) {
                    HStack(spacing: Spacing.xs) {
                        if metricsService.isLoading {
                            TerminalLoadingIndicator(color: .phosphorCyan)
                                .scaleEffect(0.6)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11))
                        }
                        Text("REFRESH")
                            .font(.terminalCaptionSmall)
                            .tracking(0.5)
                    }
                    .foregroundStyle(Color.phosphorCyan)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm)
                    .background {
                        RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                            .strokeBorder(Color.phosphorCyan.opacity(0.4), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .disabled(metricsService.isLoading)
                .accessibilityLabel("Refresh metrics")

                Button(action: openMainWindow) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "macwindow")
                            .font(.system(size: 11))
                        Text("DASHBOARD")
                            .font(.terminalCaptionSmall)
                            .tracking(0.5)
                    }
                    .foregroundStyle(Color.noirBackground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm)
                    .background {
                        RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                            .fill(Color.phosphorCyan)
                    }
                    .phosphorGlow(.phosphorCyan, intensity: 0.3, isActive: true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open dashboard window")
            }

            HStack {
                if let lastRefresh = metricsService.lastRefresh {
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                            .accessibilityHidden(true)
                        Text("Updated \(lastRefresh, style: .relative) ago")
                            .font(.terminalCaptionSmall)
                    }
                    .foregroundStyle(Color.noirTextQuaternary)
                    .accessibilityLabel("Last updated \(lastRefresh, style: .relative) ago")
                }

                Spacer()

                Button(action: { NSApp.terminate(nil) }) {
                    Image(systemName: "power")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.noirTextTertiary)
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

// MARK: - Terminal Menu Bar Stat Row

struct TerminalMenuBarStatRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(color)
                .frame(width: 18)
                .phosphorGlow(color, intensity: 0.3, isActive: isHovered)
                .accessibilityHidden(true)

            Text(label)
                .font(.terminalCaptionSmall)
                .foregroundStyle(Color.noirTextSecondary)

            Spacer()

            Text(value)
                .font(.terminalData)
                .foregroundStyle(isHovered ? color : Color.noirTextPrimary)
                .phosphorGlow(color, intensity: 0.3, isActive: isHovered)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(isHovered ? color.opacity(0.08) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
        .onHover { hovering in
            withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - Terminal Quick Time Button

struct TerminalQuickTimeButton: View {
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
                .font(.terminalCaptionSmall)
                .padding(.horizontal, Spacing.xs)
                .padding(.vertical, Spacing.xxs)
                .background(
                    isSelected
                        ? Color.phosphorCyan.opacity(0.2)
                        : (isHovered ? Color.noirStroke : .clear)
                )
                .foregroundStyle(isSelected ? Color.phosphorCyan : Color.noirTextTertiary)
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .strokeBorder(Color.phosphorCyan.opacity(0.4), lineWidth: 1)
                    }
                }
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

// MARK: - Legacy Components (kept for compatibility)

struct ModernMenuBarStatRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        TerminalMenuBarStatRow(icon: icon, label: label, value: value, color: color)
    }
}

struct QuickTimeButton: View {
    let preset: TimeRangePreset
    @Binding var current: TimeRangePreset

    var body: some View {
        TerminalQuickTimeButton(preset: preset, current: $current)
    }
}

struct ConnectionStatusBadge: View {
    let status: ConnectionStatus

    var body: some View {
        TerminalStatusBadge(status: status)
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
