import SwiftUI
import Charts

// MARK: - Stats Cache View
// Terminal Noir aesthetic for local stats display

struct StatsCacheView: View {
    @StateObject private var loader = StatsCacheLoader()
    @State private var appearAnimation = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                    statsContent(stats)
                        .opacity(appearAnimation ? 1 : 0)
                        .offset(y: appearAnimation ? 0 : 15)
                } else if !loader.fileExists {
                    noFileView
                } else {
                    emptyStateView
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

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.sm) {
                    Circle()
                        .fill(Color.phosphorPurple)
                        .frame(width: 8, height: 8)
                        .phosphorGlow(.phosphorPurple, intensity: 0.6, isActive: true)

                    Text("LOCAL STATS CACHE")
                        .font(.terminalCaptionSmall)
                        .foregroundStyle(Color.noirTextSecondary)
                        .tracking(2)
                }

                Text("Claude Code Usage")
                    .font(.terminalHeadline)
                    .foregroundStyle(Color.noirTextPrimary)

                Text("~/.claude/stats-cache.json")
                    .font(.terminalDataSmall)
                    .foregroundStyle(Color.noirTextTertiary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: Spacing.sm) {
                if let lastLoad = loader.lastLoadTime {
                    Text("Loaded \(lastLoad, style: .relative) ago")
                        .font(.terminalCaptionSmall)
                        .foregroundStyle(Color.noirTextTertiary)
                }

                Button(action: { Task { await loader.load() } }) {
                    HStack(spacing: Spacing.xs) {
                        if loader.isLoading {
                            TerminalLoadingIndicator(color: .phosphorCyan)
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11))
                        }
                        Text("REFRESH")
                            .font(.terminalCaptionSmall)
                            .tracking(1)
                    }
                    .foregroundStyle(Color.phosphorCyan)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background {
                        Capsule()
                            .strokeBorder(Color.noirStroke, lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .disabled(loader.isLoading)
            }
        }
        .padding(Spacing.lg)
        .background {
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .fill(Color.noirSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.phosphorPurple.opacity(0.06), .clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .strokeBorder(Color.noirStroke, lineWidth: 1)
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: Spacing.lg) {
            TerminalLoadingIndicator(color: .phosphorPurple)
                .scaleEffect(1.5)

            Text("LOADING STATS CACHE")
                .font(.terminalCaptionSmall)
                .foregroundStyle(Color.noirTextSecondary)
                .tracking(2)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    // MARK: - Error View

    private func errorView(_ error: String) -> some View {
        VStack(spacing: Spacing.xl) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40, weight: .thin))
                .foregroundStyle(Color.phosphorRed)
                .phosphorGlow(.phosphorRed, intensity: 0.5, isActive: true)

            VStack(spacing: Spacing.sm) {
                Text("ERROR LOADING STATS")
                    .font(.terminalCaption)
                    .foregroundStyle(Color.noirTextPrimary)
                    .tracking(2)

                Text(error)
                    .font(.terminalBodySmall)
                    .foregroundStyle(Color.noirTextSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }

            Button(action: { Task { await loader.load() } }) {
                Text("TRY AGAIN")
                    .font(.terminalCaptionSmall)
                    .tracking(1)
            }
            .buttonStyle(TerminalButtonStyle(color: .phosphorCyan, isProminent: true))
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    // MARK: - No File View

    private var noFileView: some View {
        VStack(spacing: Spacing.xl) {
            Image(systemName: "doc.questionmark")
                .font(.system(size: 40, weight: .thin))
                .foregroundStyle(Color.phosphorAmber)
                .phosphorGlow(.phosphorAmber, intensity: 0.4, isActive: true)

            VStack(spacing: Spacing.md) {
                Text("STATS CACHE NOT FOUND")
                    .font(.terminalCaption)
                    .foregroundStyle(Color.noirTextPrimary)
                    .tracking(2)

                Text("The stats cache file doesn't exist yet.\nUse Claude Code to generate usage statistics.")
                    .font(.terminalBodySmall)
                    .foregroundStyle(Color.noirTextSecondary)
                    .multilineTextAlignment(.center)

                TerminalCodeBlock(code: loader.filePath)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        TerminalEmptyState(
            title: "No Stats Available",
            message: "Click Refresh to load the stats cache",
            icon: "chart.bar",
            action: { Task { await loader.load() } },
            actionLabel: "Refresh"
        )
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    // MARK: - Stats Content

    @ViewBuilder
    private func statsContent(_ stats: StatsCache) -> some View {
        // Summary Cards
        summarySection(stats)

        // Activity Chart
        activityChartSection(stats)

        // Token Usage by Model
        modelUsageSection(stats)

        // Hourly Distribution
        hourlyDistributionSection(stats)

        // Details Section
        detailsSection(stats)
    }

    // MARK: - Summary Section

    private func summarySection(_ stats: StatsCache) -> some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            TerminalSectionHeader("Summary")

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140, maximum: 180), spacing: Spacing.md)], spacing: Spacing.md) {
                TerminalMetricCard(
                    title: "Total Tokens",
                    value: formatTokens(stats.totalTokens),
                    icon: "number.circle.fill",
                    color: .phosphorCyan
                )

                TerminalMetricCard(
                    title: "Sessions",
                    value: "\(stats.totalSessions)",
                    icon: "terminal.fill",
                    color: .phosphorPurple
                )

                TerminalMetricCard(
                    title: "Active Days",
                    value: "\(stats.activeDays)",
                    icon: "calendar",
                    color: .phosphorOrange
                )

                TerminalMetricCard(
                    title: "Avg/Day",
                    value: String(format: "%.1f", stats.averageMessagesPerDay),
                    icon: "chart.line.uptrend.xyaxis",
                    color: .phosphorGreen
                )

                TerminalMetricCard(
                    title: "Messages",
                    value: formatNumber(stats.totalMessages),
                    icon: "message.fill",
                    color: .phosphorCyan
                )

                TerminalMetricCard(
                    title: "Est. Cost",
                    value: formatCost(stats.totalCost),
                    icon: "dollarsign.circle.fill",
                    color: .phosphorGreen
                )

                if let peakHour = stats.peakHour {
                    TerminalMetricCard(
                        title: "Peak Hour",
                        value: formatHour(peakHour),
                        icon: "clock.fill",
                        color: .phosphorAmber
                    )
                }

                if stats.firstSessionDate != nil {
                    TerminalMetricCard(
                        title: "First Session",
                        value: stats.formattedFirstSessionDate ?? "Unknown",
                        icon: "star.fill",
                        color: .phosphorAmber
                    )
                }
            }
        }
    }

    // MARK: - Activity Chart Section

    private func activityChartSection(_ stats: StatsCache) -> some View {
        TerminalChartCard(
            title: "Daily Activity",
            subtitle: "messages per day",
            onExport: { exportActivityData(stats) }
        ) {
            if stats.dailyActivity.isEmpty {
                TerminalEmptyState(
                    title: "No Activity Data",
                    message: "No daily activity recorded",
                    icon: "chart.bar"
                )
            } else {
                Chart(stats.dailyActivity) { day in
                    BarMark(
                        x: .value("Date", day.parsedDate ?? Date(), unit: .day),
                        y: .value("Messages", day.messageCount)
                    )
                    .foregroundStyle(Color.phosphorCyan.gradient)
                    .cornerRadius(3)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color.noirStroke)
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            .font(.terminalDataSmall)
                            .foregroundStyle(Color.noirTextTertiary)
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color.noirStroke)
                        AxisValueLabel {
                            if let val = value.as(Int.self) {
                                Text(formatNumber(val))
                                    .font(.terminalDataSmall)
                                    .foregroundStyle(Color.noirTextTertiary)
                            }
                        }
                    }
                }
                .chartPlotStyle { content in
                    content
                        .background(Color.noirBackground.opacity(0.3))
                }
                .frame(height: 200)
            }
        }
    }

    // MARK: - Model Usage Section

    private func modelUsageSection(_ stats: StatsCache) -> some View {
        // Get sorted model names for consistent color assignment
        let sortedModels = Array(stats.modelUsage)
            .sorted(by: { $0.value.totalTokens > $1.value.totalTokens })
            .map { shortModelName($0.key) }

        return TerminalChartCard(
            title: "Token Usage by Model",
            subtitle: "breakdown",
            onExport: { exportModelData(stats) }
        ) {
            if stats.modelUsage.isEmpty {
                TerminalEmptyState(
                    title: "No Model Data",
                    message: "No model usage recorded",
                    icon: "cpu"
                )
            } else {
                HStack(spacing: Spacing.xl) {
                    // Donut Chart
                    Chart(Array(stats.modelUsage).sorted(by: { $0.value.totalTokens > $1.value.totalTokens }), id: \.key) { model in
                        SectorMark(
                            angle: .value("Tokens", model.value.totalTokens),
                            innerRadius: .ratio(0.55),
                            outerRadius: .ratio(0.95),
                            angularInset: 3
                        )
                        .foregroundStyle(colorForModel(shortModelName(model.key), in: sortedModels))
                        .cornerRadius(4)
                    }
                    .chartBackground { _ in
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Color.noirSurface, Color.noirBackground.opacity(0.5)],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 80
                                )
                            )
                    }
                    .frame(width: 180, height: 180)

                    // Details Table
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        ForEach(Array(stats.modelUsage).sorted(by: { $0.value.totalTokens > $1.value.totalTokens }), id: \.key) { model in
                            TerminalModelUsageRow(
                                modelName: shortModelName(model.key),
                                usage: model.value,
                                fullName: model.key,
                                color: colorForModel(shortModelName(model.key), in: sortedModels)
                            )
                        }
                    }
                    .frame(width: 260)
                }
                .frame(height: 200)
            }
        }
    }

    // MARK: - Hourly Distribution Section

    private func hourlyDistributionSection(_ stats: StatsCache) -> some View {
        TerminalChartCard(
            title: "Activity by Hour",
            subtitle: "when you code",
            onExport: { exportHourlyData(stats) }
        ) {
            if stats.hourCounts.isEmpty {
                TerminalEmptyState(
                    title: "No Hourly Data",
                    message: "No hourly distribution recorded",
                    icon: "clock"
                )
            } else {
                let hourData = (0..<24).map { hour in
                    (hour: hour, count: stats.hourCounts[String(hour)] ?? 0)
                }

                Chart(hourData, id: \.hour) { item in
                    BarMark(
                        x: .value("Hour", item.hour),
                        y: .value("Sessions", item.count)
                    )
                    .foregroundStyle(
                        item.hour >= 9 && item.hour <= 17
                            ? Color.phosphorCyan.gradient
                            : Color.phosphorCyan.opacity(0.4).gradient
                    )
                    .cornerRadius(2)
                }
                .chartXAxis {
                    AxisMarks(values: [0, 6, 12, 18, 23]) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color.noirStroke)
                        AxisValueLabel {
                            if let hour = value.as(Int.self) {
                                Text(formatHour(hour))
                                    .font(.terminalDataSmall)
                                    .foregroundStyle(Color.noirTextTertiary)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color.noirStroke)
                        AxisValueLabel()
                            .font(.terminalDataSmall)
                            .foregroundStyle(Color.noirTextTertiary)
                    }
                }
                .chartPlotStyle { content in
                    content
                        .background(Color.noirBackground.opacity(0.3))
                }
                .frame(height: 150)
            }
        }
    }

    // MARK: - Details Section

    private func detailsSection(_ stats: StatsCache) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            TerminalSectionHeader("Details")

            VStack(alignment: .leading, spacing: Spacing.sm) {
                TerminalDetailRow(label: "Cache Version", value: "\(stats.version)")
                TerminalDetailRow(label: "Last Computed", value: stats.lastComputedDate)

                if let longest = stats.longestSession {
                    Divider()
                        .background(Color.noirStroke)

                    Text("LONGEST SESSION")
                        .font(.terminalCaptionSmall)
                        .foregroundStyle(Color.noirTextTertiary)
                        .tracking(1)
                        .padding(.top, Spacing.xs)

                    TerminalDetailRow(label: "Duration", value: longest.formattedDuration)
                    TerminalDetailRow(label: "Messages", value: "\(longest.messageCount)")
                    TerminalDetailRow(label: "Date", value: longest.formattedDate)
                }

                Divider()
                    .background(Color.noirStroke)

                HStack {
                    Text("File Path")
                        .font(.terminalCaptionSmall)
                        .foregroundStyle(Color.noirTextTertiary)
                    Spacer()
                    TerminalCodeBlock(code: loader.filePath)
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

    // MARK: - Formatting Helpers

    private func formatNumber(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "%.1fK", Double(value) / 1_000)
        }
        return "\(value)"
    }

    private func formatTokens(_ value: Int) -> String {
        if value >= 1_000_000_000 {
            return String(format: "%.2fB", Double(value) / 1_000_000_000)
        } else if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "%.1fK", Double(value) / 1_000)
        }
        return "\(value)"
    }

    private func formatCost(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "$%.0f", value)
        } else if value >= 100 {
            return String(format: "$%.1f", value)
        } else if value >= 1 {
            return String(format: "$%.2f", value)
        }
        return String(format: "$%.3f", value)
    }

    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        var components = DateComponents()
        components.hour = hour
        if let date = Calendar.current.date(from: components) {
            return formatter.string(from: date).lowercased()
        }
        return "\(hour):00"
    }

    private func shortModelName(_ fullName: String) -> String {
        if fullName.contains("opus-4-5") || fullName.contains("opus-4.5") {
            return "Opus 4.5"
        } else if fullName.contains("opus-4-1") || fullName.contains("opus-4.1") || fullName.contains("opus-4-0") {
            return "Opus 4.1"
        } else if fullName.contains("opus") {
            return "Opus"
        } else if fullName.contains("sonnet-4-5") || fullName.contains("sonnet-4.5") {
            return "Sonnet 4.5"
        } else if fullName.contains("sonnet-4-0") || fullName.contains("sonnet-4.0") {
            return "Sonnet 4.0"
        } else if fullName.contains("sonnet-3-5") || fullName.contains("sonnet-3.5") {
            return "Sonnet 3.5"
        } else if fullName.contains("sonnet") {
            return "Sonnet"
        } else if fullName.contains("haiku-4-5") || fullName.contains("haiku-4.5") {
            return "Haiku 4.5"
        } else if fullName.contains("haiku-3-5") || fullName.contains("haiku-3.5") {
            return "Haiku 3.5"
        } else if fullName.contains("haiku") {
            return "Haiku"
        }
        return fullName
    }

    // Color palette for distinct model colors in charts
    private let modelColorPalette: [Color] = [
        .phosphorPurple,
        .phosphorCyan,
        .phosphorGreen,
        .phosphorAmber,
        .phosphorMagenta,
        .phosphorOrange,
        .phosphorRed,
        Color(red: 0.4, green: 0.8, blue: 0.9),  // Light cyan
        Color(red: 0.9, green: 0.6, blue: 0.8),  // Pink
        Color(red: 0.6, green: 0.9, blue: 0.7),  // Mint
    ]

    private func colorForModel(_ name: String, in models: [String]) -> Color {
        // Get the index of this model in the list to assign a unique color
        if let index = models.firstIndex(of: name) {
            return modelColorPalette[index % modelColorPalette.count]
        }
        return .noirTextSecondary
    }

    // MARK: - Export Functions

    private func exportActivityData(_ stats: StatsCache) {
        let data = stats.dailyActivity.map {
            ("\($0.date)", "\($0.messageCount),\($0.sessionCount),\($0.toolCallCount)")
        }
        let header = "Date,Messages,Sessions,ToolCalls"
        exportCSV(title: "daily_activity", header: header, data: data)
    }

    private func exportModelData(_ stats: StatsCache) {
        let data = stats.modelUsage.map {
            ("\($0.key)", "\($0.value.inputTokens),\($0.value.outputTokens),\($0.value.cacheReadInputTokens),\($0.value.cacheCreationInputTokens)")
        }
        let header = "Model,InputTokens,OutputTokens,CacheReadTokens,CacheCreationTokens"
        exportCSV(title: "model_usage", header: header, data: data)
    }

    private func exportHourlyData(_ stats: StatsCache) {
        let data = (0..<24).map { hour in
            ("\(hour)", "\(stats.hourCounts[String(hour)] ?? 0)")
        }
        let header = "Hour,Sessions"
        exportCSV(title: "hourly_distribution", header: header, data: data)
    }

    private func exportCSV(title: String, header: String, data: [(String, String)]) {
        let csv = header + "\n" + data.map { "\($0.0),\($0.1)" }.joined(separator: "\n")

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.commaSeparatedText]
        savePanel.nameFieldStringValue = "\(title).csv"

        if savePanel.runModal() == .OK, let url = savePanel.url {
            try? csv.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

// MARK: - Terminal Code Block

struct TerminalCodeBlock: View {
    let code: String
    @State private var showCopied = false

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Text(code)
                .font(.terminalDataSmall)
                .foregroundStyle(Color.phosphorGreen)
                .textSelection(.enabled)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background {
                    RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                        .fill(Color.noirBackground)
                        .overlay {
                            RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                                .strokeBorder(Color.noirStroke, lineWidth: 1)
                        }
                }

            Button(action: copyToClipboard) {
                Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 10))
                    .foregroundStyle(showCopied ? Color.phosphorGreen : Color.noirTextTertiary)
            }
            .buttonStyle(.plain)
        }
    }

    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        withAnimation { showCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showCopied = false }
        }
    }
}

// MARK: - Terminal Detail Row

struct TerminalDetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.terminalCaptionSmall)
                .foregroundStyle(Color.noirTextTertiary)
            Spacer()
            Text(value)
                .font(.terminalData)
                .foregroundStyle(Color.noirTextSecondary)
                .textSelection(.enabled)
        }
    }
}

// MARK: - Terminal Model Usage Row

struct TerminalModelUsageRow: View {
    let modelName: String
    let usage: ModelUsage
    let fullName: String
    let color: Color

    @State private var isHovered = false
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                HStack(spacing: Spacing.sm) {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                        .phosphorGlow(color, intensity: 0.4, isActive: isHovered)

                    Text(modelName)
                        .font(.terminalCaption)
                        .foregroundStyle(Color.noirTextSecondary)
                }

                Spacer()

                Text(formatTokens(usage.totalTokens))
                    .font(.terminalData)
                    .foregroundStyle(isHovered ? color : Color.noirTextPrimary)

                Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.noirTextTertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .buttonStyle(.plain)
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    TerminalTokenDetailRow(label: "Input", value: usage.inputTokens)
                    TerminalTokenDetailRow(label: "Output", value: usage.outputTokens)
                    TerminalTokenDetailRow(label: "Cache Read", value: usage.cacheReadInputTokens)
                    TerminalTokenDetailRow(label: "Cache Write", value: usage.cacheCreationInputTokens)

                    Divider()
                        .background(Color.noirStroke)

                    HStack {
                        Text("Est. Cost")
                            .font(.terminalCaptionSmall)
                            .foregroundStyle(Color.noirTextTertiary)
                        Spacer()
                        Text(String(format: "$%.2f", usage.estimatedCost(for: fullName)))
                            .font(.terminalData)
                            .foregroundStyle(Color.phosphorGreen)
                            .phosphorGlow(.phosphorGreen, intensity: 0.3, isActive: true)
                    }
                }
                .padding(.leading, Spacing.lg)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(Spacing.sm)
        .background(isHovered ? color.opacity(0.05) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }

    private func formatTokens(_ value: Int) -> String {
        if value >= 1_000_000_000 {
            return String(format: "%.2fB", Double(value) / 1_000_000_000)
        } else if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "%.1fK", Double(value) / 1_000)
        }
        return "\(value)"
    }
}

// MARK: - Terminal Token Detail Row

struct TerminalTokenDetailRow: View {
    let label: String
    let value: Int

    var body: some View {
        HStack {
            Text(label)
                .font(.terminalCaptionSmall)
                .foregroundStyle(Color.noirTextQuaternary)
            Spacer()
            Text(formatValue(value))
                .font(.terminalDataSmall)
                .foregroundStyle(Color.noirTextTertiary)
        }
    }

    private func formatValue(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

// MARK: - Legacy Components (kept for compatibility)

struct StatsSummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        TerminalMetricCard(title: title, value: value, icon: icon, color: color)
    }
}

struct ModelUsageRow: View {
    let modelName: String
    let usage: ModelUsage
    let fullName: String

    var body: some View {
        TerminalModelUsageRow(
            modelName: modelName,
            usage: usage,
            fullName: fullName,
            color: .phosphorCyan
        )
    }
}

struct TokenDetailRow: View {
    let label: String
    let value: Int

    var body: some View {
        TerminalTokenDetailRow(label: label, value: value)
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        TerminalDetailRow(label: label, value: value)
    }
}

struct CopyableCodeBlock: View {
    let code: String
    let label: String?

    var body: some View {
        TerminalCodeBlock(code: code)
    }
}

#if DEBUG
struct StatsCacheView_Previews: PreviewProvider {
    static var previews: some View {
        StatsCacheView()
    }
}
#endif
