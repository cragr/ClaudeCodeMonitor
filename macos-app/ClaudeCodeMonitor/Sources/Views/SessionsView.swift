import SwiftUI

// MARK: - Session Sort Order

enum SessionSortOrder: String, CaseIterable, Identifiable {
    case costDesc = "Cost (High to Low)"
    case costAsc = "Cost (Low to High)"
    case tokensDesc = "Tokens (High to Low)"
    case tokensAsc = "Tokens (Low to High)"
    case durationDesc = "Duration (Longest)"
    case durationAsc = "Duration (Shortest)"
    case costPerMinDesc = "Cost/Min (High to Low)"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .costDesc, .costAsc: return "dollarsign.circle"
        case .tokensDesc, .tokensAsc: return "number.circle"
        case .durationDesc, .durationAsc: return "clock"
        case .costPerMinDesc: return "gauge.with.dots.needle.67percent"
        }
    }
}

// MARK: - Sessions View

struct SessionsView: View {
    @StateObject private var service: SessionMetricsService
    @EnvironmentObject private var settings: SettingsManager
    @State private var selectedTimeRange: TimeRangePreset = .last1Day
    @State private var sortOrder: SessionSortOrder = .costDesc
    @State private var selectedSession: SessionMetrics?
    @State private var appearAnimation = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(client: PrometheusClient) {
        _service = StateObject(wrappedValue: SessionMetricsService(client: client))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerView
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 10)

                Divider()
                    .background(Color.noirStroke)

                if service.isLoading && service.sessions.isEmpty {
                    loadingView
                } else if service.sessions.isEmpty && service.error == nil {
                    emptyStateView
                } else {
                    ScrollView {
                        VStack(spacing: Spacing.xl) {
                            topSessionsSection
                                .opacity(appearAnimation ? 1 : 0)
                                .offset(y: appearAnimation ? 0 : 15)

                            if let error = service.error, !service.sessions.isEmpty {
                                warningBanner(error: error)
                            }

                            allSessionsSection
                                .opacity(appearAnimation ? 1 : 0)
                                .offset(y: appearAnimation ? 0 : 20)
                        }
                        .padding(Spacing.xl)
                    }
                }
            }
            .background(Color.noirBackground)
            .navigationTitle("Sessions")
            .navigationDestination(item: $selectedSession) { session in
                SessionDetailView(session: session)
            }
            .task {
                await service.fetchSessions(timeRange: selectedTimeRange)
            }
            .onChange(of: selectedTimeRange) { _, newValue in
                Task {
                    await service.fetchSessions(timeRange: newValue)
                }
            }
            .onAppear {
                withAnimation(reduceMotion ? .none : .easeOut(duration: 0.5)) {
                    appearAnimation = true
                }
            }
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.sm) {
                    Circle()
                        .fill(Color.phosphorOrange)
                        .frame(width: 8, height: 8)
                        .phosphorGlow(.phosphorOrange, intensity: 0.6, isActive: true)

                    Text("SESSIONS")
                        .font(.terminalCaptionSmall)
                        .foregroundStyle(Color.noirTextSecondary)
                        .tracking(2)
                }

                Text("Cost Explorer")
                    .font(.terminalHeadline)
                    .foregroundStyle(Color.noirTextPrimary)
            }

            Spacer()

            // Time Range Picker
            Picker("Time Range", selection: $selectedTimeRange) {
                ForEach(TimeRangePreset.allCases.filter { $0 != .custom }, id: \.self) { preset in
                    Text(preset.displayName).tag(preset)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 160)

            // Refresh Button
            Button(action: {
                Task {
                    await service.fetchSessions(timeRange: selectedTimeRange)
                }
            }) {
                HStack(spacing: Spacing.xs) {
                    if service.isLoading {
                        TerminalLoadingIndicator(color: .phosphorOrange)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .medium))
                    }
                }
                .foregroundStyle(Color.phosphorOrange)
                .frame(width: 28, height: 22)
                .background {
                    RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                        .fill(Color.phosphorOrange.opacity(0.1))
                        .overlay {
                            RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                                .strokeBorder(Color.phosphorOrange.opacity(0.3), lineWidth: 1)
                        }
                }
            }
            .buttonStyle(.plain)
            .disabled(service.isLoading)
            .help("Refresh sessions")
        }
        .padding(Spacing.lg)
        .background {
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .fill(Color.noirSurface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .strokeBorder(Color.noirStroke, lineWidth: 1)
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.top, Spacing.xl)
        .padding(.bottom, Spacing.lg)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: Spacing.lg) {
            TerminalLoadingIndicator(color: .phosphorOrange)
                .scaleEffect(1.5)
            Text("LOADING SESSIONS")
                .font(.terminalCaptionSmall)
                .foregroundStyle(Color.noirTextSecondary)
                .tracking(2)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        TerminalEmptyState(
            title: "No Sessions Found",
            message: "No session data available for the selected time range.\nTry selecting a longer time range or check your Prometheus connection.",
            icon: "terminal"
        )
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    // MARK: - Warning Banner

    private func warningBanner(error: SessionFetchError) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color.phosphorAmber)

            Text(error.localizedDescription)
                .font(.terminalBodySmall)
                .foregroundStyle(Color.noirTextSecondary)

            Spacer()

            Button("Retry") {
                Task {
                    await service.fetchSessions(timeRange: selectedTimeRange)
                }
            }
            .buttonStyle(TerminalButtonStyle(color: .phosphorAmber))
        }
        .padding(Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .fill(Color.phosphorAmber.opacity(0.1))
                .overlay {
                    RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                        .strokeBorder(Color.phosphorAmber.opacity(0.3), lineWidth: 1)
                }
        }
    }

    // MARK: - Top Sessions Section

    private var topSessionsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            TerminalSectionHeader("Top Sessions")

            HStack(spacing: Spacing.md) {
                // Highest Cost
                if let session = service.highestCostSession {
                    TopSessionCard(
                        title: "Highest Cost",
                        session: session,
                        highlightValue: session.formattedCost,
                        icon: "dollarsign.circle.fill",
                        color: .phosphorGreen
                    ) {
                        selectedSession = session
                    }
                }

                // Most Tokens
                if let session = service.mostTokensSession {
                    TopSessionCard(
                        title: "Most Tokens",
                        session: session,
                        highlightValue: session.formattedTokens,
                        icon: "number.circle.fill",
                        color: .phosphorCyan
                    ) {
                        selectedSession = session
                    }
                }

                // Longest Duration
                if let session = service.longestSession {
                    TopSessionCard(
                        title: "Longest Duration",
                        session: session,
                        highlightValue: session.formattedActiveTime,
                        icon: "clock.fill",
                        color: .phosphorAmber
                    ) {
                        selectedSession = session
                    }
                }
            }
        }
    }

    // MARK: - All Sessions Section

    private var allSessionsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                TerminalSectionHeader("All Sessions", trailing: "\(service.sessions.count) sessions")

                Spacer()

                // Sort Picker
                Picker("Sort By", selection: $sortOrder) {
                    ForEach(SessionSortOrder.allCases) { order in
                        Label(order.rawValue, systemImage: order.iconName).tag(order)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 180)
            }

            SessionsTableView(
                sessions: sortedSessions,
                onSelect: { session in
                    selectedSession = session
                }
            )
        }
    }

    // MARK: - Sorted Sessions

    private var sortedSessions: [SessionMetrics] {
        switch sortOrder {
        case .costDesc:
            return service.sessions.sorted { $0.totalCostUSD > $1.totalCostUSD }
        case .costAsc:
            return service.sessions.sorted { $0.totalCostUSD < $1.totalCostUSD }
        case .tokensDesc:
            return service.sessions.sorted { $0.totalTokens > $1.totalTokens }
        case .tokensAsc:
            return service.sessions.sorted { $0.totalTokens < $1.totalTokens }
        case .durationDesc:
            return service.sessions.sorted { $0.activeTime > $1.activeTime }
        case .durationAsc:
            return service.sessions.sorted { $0.activeTime < $1.activeTime }
        case .costPerMinDesc:
            return service.sessions.sorted {
                ($0.costPerMinute ?? 0) > ($1.costPerMinute ?? 0)
            }
        }
    }
}

// MARK: - Top Session Card

struct TopSessionCard: View {
    let title: String
    let session: SessionMetrics
    let highlightValue: String
    let icon: String
    let color: Color
    let onTap: () -> Void

    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                // Header
                HStack(spacing: Spacing.sm) {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(color)
                        .phosphorGlow(color, intensity: 0.5, isActive: isHovered)

                    Text(title.uppercased())
                        .font(.terminalCaptionSmall)
                        .foregroundStyle(Color.noirTextTertiary)
                        .tracking(1)
                }

                // Highlighted Value
                Text(highlightValue)
                    .font(.terminalValue)
                    .foregroundStyle(color)
                    .phosphorGlow(color, intensity: isHovered ? 0.6 : 0.3, isActive: true)

                // Session ID
                Text(session.truncatedSessionId)
                    .font(.terminalDataSmall)
                    .foregroundStyle(Color.noirTextSecondary)
                    .lineLimit(1)

                Divider()
                    .background(Color.noirStroke)

                // Secondary metrics
                HStack {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text("Tokens")
                            .font(.terminalCaptionSmall)
                            .foregroundStyle(Color.noirTextTertiary)
                        Text(session.formattedTokens)
                            .font(.terminalDataSmall)
                            .foregroundStyle(Color.noirTextSecondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: Spacing.xxs) {
                        Text("Duration")
                            .font(.terminalCaptionSmall)
                            .foregroundStyle(Color.noirTextTertiary)
                        Text(session.formattedActiveTime)
                            .font(.terminalDataSmall)
                            .foregroundStyle(Color.noirTextSecondary)
                    }
                }
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .fill(Color.noirSurface)
                    .overlay {
                        RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                            .fill(
                                RadialGradient(
                                    colors: [color.opacity(isHovered ? 0.08 : 0), .clear],
                                    center: .top,
                                    startRadius: 0,
                                    endRadius: 150
                                )
                            )
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .strokeBorder(isHovered ? color.opacity(0.4) : Color.noirStroke, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .accessibilityLabel("\(title): \(highlightValue), Session \(session.truncatedSessionId)")
    }
}

// MARK: - Sessions Table View

struct SessionsTableView: View {
    let sessions: [SessionMetrics]
    let onSelect: (SessionMetrics) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Table Header
            HStack(spacing: 0) {
                Text("SESSION ID")
                    .frame(width: 140, alignment: .leading)

                Text("COST")
                    .frame(width: 80, alignment: .trailing)

                Text("TOKENS")
                    .frame(width: 80, alignment: .trailing)

                Text("DURATION")
                    .frame(width: 80, alignment: .trailing)

                Text("COST/MIN")
                    .frame(width: 80, alignment: .trailing)

                Spacer()

                Text("")
                    .frame(width: 30)
            }
            .font(.terminalCaptionSmall)
            .foregroundStyle(Color.noirTextTertiary)
            .tracking(1)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(Color.noirSurface.opacity(0.5))

            Divider()
                .background(Color.noirStroke)

            // Table Rows
            ForEach(sessions) { session in
                SessionTableRow(session: session, onSelect: onSelect)
            }
        }
        .background {
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .fill(Color.noirSurface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .strokeBorder(Color.noirStroke, lineWidth: 1)
        }
    }
}

// MARK: - Session Table Row

struct SessionTableRow: View {
    let session: SessionMetrics
    let onSelect: (SessionMetrics) -> Void

    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var formattedCostPerMin: String {
        if let cpm = session.costPerMinute {
            if cpm >= 0.01 {
                return String(format: "$%.2f", cpm)
            } else if cpm >= 0.001 {
                return String(format: "$%.3f", cpm)
            }
            return String(format: "$%.4f", cpm)
        }
        return "--"
    }

    var body: some View {
        Button(action: { onSelect(session) }) {
            HStack(spacing: 0) {
                Text(session.truncatedSessionId)
                    .font(.terminalData)
                    .foregroundStyle(isHovered ? Color.phosphorCyan : Color.noirTextSecondary)
                    .frame(width: 140, alignment: .leading)

                Text(session.formattedCost)
                    .font(.terminalData)
                    .foregroundStyle(Color.phosphorGreen)
                    .frame(width: 80, alignment: .trailing)

                Text(session.formattedTokens)
                    .font(.terminalData)
                    .foregroundStyle(Color.phosphorCyan)
                    .frame(width: 80, alignment: .trailing)

                Text(session.formattedActiveTime)
                    .font(.terminalData)
                    .foregroundStyle(Color.phosphorAmber)
                    .frame(width: 80, alignment: .trailing)

                Text(formattedCostPerMin)
                    .font(.terminalData)
                    .foregroundStyle(Color.noirTextSecondary)
                    .frame(width: 80, alignment: .trailing)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(isHovered ? Color.phosphorCyan : Color.noirTextTertiary)
                    .frame(width: 30)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(isHovered ? Color.phosphorCyan.opacity(0.05) : Color.clear)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
        .accessibilityLabel("Session \(session.truncatedSessionId), Cost \(session.formattedCost), \(session.formattedTokens) tokens, Duration \(session.formattedActiveTime)")
    }
}

// MARK: - Previews

#if DEBUG
struct SessionsView_Previews: PreviewProvider {
    static var previews: some View {
        let client = PrometheusClient(baseURL: URL(string: "http://localhost:9090")!)
        SessionsView(client: client)
            .environmentObject(SettingsManager())
            .frame(width: 800, height: 600)
    }
}
#endif
