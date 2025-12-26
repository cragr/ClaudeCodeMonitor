import SwiftUI
import Charts

// MARK: - Insights View

struct InsightsView: View {
    @StateObject private var loader = StatsCacheLoader()
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var selectedPeriod: InsightsPeriod = .thisWeek
    @State private var appearAnimation = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum InsightsPeriod: String, CaseIterable {
        case thisWeek = "This Week"
        case thisMonth = "This Month"
        case last7Days = "Last 7 Days"

        var comparisonDays: Int {
            switch self {
            case .thisWeek, .last7Days: return 7
            case .thisMonth: return 30
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                headerSection
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 10)

                if loader.isLoading {
                    loadingView
                } else if let error = loader.error {
                    errorView(error)
                } else if let stats = loader.statsCache {
                    insightsContent(stats)
                        .opacity(appearAnimation ? 1 : 0)
                        .offset(y: appearAnimation ? 0 : 15)
                } else if !loader.fileExists {
                    noFileView
                }
            }
            .padding(Spacing.xl)
        }
        .frame(minWidth: 650, minHeight: 550)
        .background(Color.noirBackground)
        .task {
            await loader.load()
        }
        .onAppear {
            withAnimation(reduceMotion ? .none : .easeOut(duration: 0.5)) {
                appearAnimation = true
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.sm) {
                    Circle()
                        .fill(Color.phosphorAmber)
                        .frame(width: 8, height: 8)
                        .phosphorGlow(.phosphorAmber, intensity: 0.6, isActive: true)

                    Text("INSIGHTS")
                        .font(.terminalCaptionSmall)
                        .foregroundStyle(Color.noirTextSecondary)
                        .tracking(2)
                }

                Text("Usage Trends")
                    .font(.terminalHeadline)
                    .foregroundStyle(Color.noirTextPrimary)
            }

            Spacer()

            // Period Selector
            Picker("Period", selection: $selectedPeriod) {
                ForEach(InsightsPeriod.allCases, id: \.self) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 280)

            // Pricing Provider
            Menu {
                ForEach(PricingProvider.allCases, id: \.self) { provider in
                    Button(provider.displayName) {
                        settingsManager.pricingProvider = provider
                    }
                }
            } label: {
                HStack(spacing: Spacing.xs) {
                    Text(settingsManager.pricingProvider.displayName)
                        .font(.terminalCaptionSmall)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8))
                }
                .foregroundStyle(Color.noirTextSecondary)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background {
                    Capsule()
                        .strokeBorder(Color.noirStroke, lineWidth: 1)
                }
            }
            .menuStyle(.borderlessButton)
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
    }

    // MARK: - Content

    @ViewBuilder
    private func insightsContent(_ stats: StatsCache) -> some View {
        // Period Comparison Cards
        comparisonCardsSection(stats)

        // Trend Sparklines
        sparklineSection(stats)

        // Peak Activity
        peakActivitySection(stats)
    }

    // MARK: - Comparison Cards

    private func comparisonCardsSection(_ stats: StatsCache) -> some View {
        let comparison = stats.periodComparison(
            currentDays: selectedPeriod.comparisonDays,
            previousDays: selectedPeriod.comparisonDays
        )

        return VStack(alignment: .leading, spacing: Spacing.md) {
            TerminalSectionHeader("Period Comparison")

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 200), spacing: Spacing.md)], spacing: Spacing.md) {
                ComparisonCard(
                    title: "Messages",
                    value: comparison?.currentMessages ?? 0,
                    change: comparison?.messagesChange,
                    icon: "message.fill",
                    color: .phosphorCyan
                )

                ComparisonCard(
                    title: "Sessions",
                    value: comparison?.currentSessions ?? 0,
                    change: comparison?.sessionsChange,
                    icon: "terminal.fill",
                    color: .phosphorPurple
                )

                ComparisonCard(
                    title: "Tokens",
                    value: comparison?.currentTokens ?? 0,
                    change: comparison?.tokensChange,
                    icon: "number.circle.fill",
                    color: .phosphorOrange,
                    formatter: NumberFormatting.compact
                )

                ComparisonCard(
                    title: "Est. Cost",
                    value: Int(stats.totalCost * 100), // cents for display
                    change: nil, // Would need cost history
                    icon: "dollarsign.circle.fill",
                    color: .phosphorGreen,
                    formatter: { NumberFormatting.cost(Double($0) / 100) }
                )
            }
        }
    }

    // MARK: - Sparklines

    private func sparklineSection(_ stats: StatsCache) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            TerminalSectionHeader("Trends")

            HStack(spacing: Spacing.lg) {
                // Daily Activity Sparkline
                SparklineCard(
                    title: "Daily Activity",
                    subtitle: "Avg: \(Int(stats.averageMessagesPerDay))/day",
                    data: stats.dailyActivity.suffix(selectedPeriod.comparisonDays).map { Double($0.messageCount) },
                    color: .phosphorCyan
                )

                // Sessions per day
                SparklineCard(
                    title: "Sessions/Day",
                    subtitle: "Avg: \(String(format: "%.1f", stats.averageSessionsPerDay))",
                    data: stats.dailyActivity.suffix(selectedPeriod.comparisonDays).map { Double($0.sessionCount) },
                    color: .phosphorPurple
                )
            }
        }
    }

    // MARK: - Peak Activity

    private func peakActivitySection(_ stats: StatsCache) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            TerminalSectionHeader("Peak Activity")

            VStack(alignment: .leading, spacing: Spacing.sm) {
                if let peakHour = stats.peakHour {
                    TerminalDetailRow(label: "Most Active Hour", value: NumberFormatting.hour(peakHour))
                }

                if let longest = stats.longestSession {
                    TerminalDetailRow(label: "Longest Session", value: longest.formattedDuration)
                }

                TerminalDetailRow(label: "Current Streak", value: "\(stats.currentStreak()) days")

                if let firstSession = stats.formattedFirstSessionDate {
                    TerminalDetailRow(label: "Member Since", value: firstSession)
                }
            }
            .padding(Spacing.lg)
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

    // MARK: - Loading/Error Views

    private var loadingView: some View {
        VStack(spacing: Spacing.lg) {
            TerminalLoadingIndicator(color: .phosphorAmber)
                .scaleEffect(1.5)
            Text("LOADING INSIGHTS")
                .font(.terminalCaptionSmall)
                .foregroundStyle(Color.noirTextSecondary)
                .tracking(2)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: Spacing.xl) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40, weight: .thin))
                .foregroundStyle(Color.phosphorRed)
            Text(error)
                .font(.terminalBodySmall)
                .foregroundStyle(Color.noirTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    private var noFileView: some View {
        TerminalEmptyState(
            title: "No Stats Available",
            message: "Use Claude Code to generate usage statistics",
            icon: "chart.line.uptrend.xyaxis"
        )
        .frame(maxWidth: .infinity, minHeight: 300)
    }
}

// MARK: - Comparison Card

struct ComparisonCard: View {
    let title: String
    let value: Int
    let change: Double?
    let icon: String
    let color: Color
    var formatter: (Int) -> String = { "\($0)" }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(color)
                Text(title.uppercased())
                    .font(.terminalCaptionSmall)
                    .foregroundStyle(Color.noirTextTertiary)
                    .tracking(1)
            }

            Text(formatter(value))
                .font(.terminalHeadline)
                .foregroundStyle(Color.noirTextPrimary)

            if let change = change {
                HStack(spacing: Spacing.xxs) {
                    Image(systemName: change >= 0 ? "arrow.up" : "arrow.down")
                        .font(.system(size: 10, weight: .bold))
                    Text(String(format: "%.0f%%", abs(change)))
                        .font(.terminalDataSmall)
                    Text("vs last period")
                        .font(.terminalCaptionSmall)
                        .foregroundStyle(Color.noirTextTertiary)
                }
                .foregroundStyle(change >= 0 ? Color.phosphorGreen : Color.phosphorRed)
            } else {
                Text("—")
                    .font(.terminalDataSmall)
                    .foregroundStyle(Color.noirTextTertiary)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
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

// MARK: - Sparkline Card

struct SparklineCard: View {
    let title: String
    let subtitle: String
    let data: [Double]
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title.uppercased())
                .font(.terminalCaptionSmall)
                .foregroundStyle(Color.noirTextTertiary)
                .tracking(1)

            if data.isEmpty {
                Rectangle()
                    .fill(Color.noirStroke)
                    .frame(height: 60)
            } else {
                Chart(Array(data.enumerated()), id: \.offset) { index, value in
                    LineMark(
                        x: .value("Day", index),
                        y: .value("Value", value)
                    )
                    .foregroundStyle(color)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Day", index),
                        y: .value("Value", value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [color.opacity(0.3), color.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 60)
            }

            Text(subtitle)
                .font(.terminalDataSmall)
                .foregroundStyle(Color.noirTextSecondary)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity)
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
