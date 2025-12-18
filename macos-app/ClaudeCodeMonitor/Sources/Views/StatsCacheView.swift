import SwiftUI
import Charts

// MARK: - Stats Cache View

struct StatsCacheView: View {
    @StateObject private var loader = StatsCacheLoader()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection

                if loader.isLoading {
                    loadingView
                } else if let error = loader.error {
                    errorView(error)
                } else if let stats = loader.statsCache {
                    statsContent(stats)
                } else if !loader.fileExists {
                    noFileView
                } else {
                    emptyStateView
                }
            }
            .padding(24)
        }
        .frame(minWidth: 650, minHeight: 550)
        .background(Color(NSColor.controlBackgroundColor))
        .task {
            await loader.load()
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Local Stats Cache")
                    .font(.title2.weight(.semibold))
                Text("Claude Code usage statistics from ~/.claude/stats-cache.json")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let lastLoad = loader.lastLoadTime {
                Text("Loaded \(lastLoad, style: .relative) ago")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Button(action: { Task { await loader.load() } }) {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .disabled(loader.isLoading)
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading stats cache...")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    // MARK: - Error View

    private func errorView(_ error: String) -> some View {
        ContentUnavailableView {
            Label("Error Loading Stats", systemImage: "exclamationmark.triangle")
        } description: {
            Text(error)
        } actions: {
            Button("Try Again") {
                Task { await loader.load() }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - No File View

    private var noFileView: some View {
        ContentUnavailableView {
            Label("Stats Cache Not Found", systemImage: "doc.questionmark")
        } description: {
            VStack(spacing: 8) {
                Text("The stats cache file doesn't exist yet.")
                Text("Use Claude Code to generate usage statistics.")
                    .foregroundStyle(.secondary)

                CopyableCodeBlock(
                    code: loader.filePath,
                    label: "Expected path"
                )
                .padding(.top, 8)
            }
        }
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Stats Available", systemImage: "chart.bar")
        } description: {
            Text("Click Refresh to load the stats cache")
        } actions: {
            Button("Refresh") {
                Task { await loader.load() }
            }
            .buttonStyle(.borderedProminent)
        }
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
        VStack(alignment: .leading, spacing: 16) {
            Text("Summary")
                .font(.sectionTitle)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 16)], spacing: 16) {
                StatsSummaryCard(
                    title: "Total Tokens",
                    value: formatTokens(stats.totalTokens),
                    icon: "number.circle.fill",
                    color: .cyan
                )

                StatsSummaryCard(
                    title: "Total Sessions",
                    value: "\(stats.totalSessions)",
                    icon: "terminal.fill",
                    color: .purple
                )

                StatsSummaryCard(
                    title: "Active Days",
                    value: "\(stats.activeDays)",
                    icon: "calendar",
                    color: .orange
                )

                StatsSummaryCard(
                    title: "Avg Messages/Day",
                    value: String(format: "%.1f", stats.averageMessagesPerDay),
                    icon: "chart.line.uptrend.xyaxis",
                    color: .green
                )

                StatsSummaryCard(
                    title: "Total Messages",
                    value: formatNumber(stats.totalMessages),
                    icon: "message.fill",
                    color: .blue
                )

                StatsSummaryCard(
                    title: "Est. Cost",
                    value: formatCost(stats.totalCost),
                    icon: "dollarsign.circle.fill",
                    color: .mint
                )

                if let peakHour = stats.peakHour {
                    StatsSummaryCard(
                        title: "Peak Hour",
                        value: formatHour(peakHour),
                        icon: "clock.fill",
                        color: .indigo
                    )
                }

                if stats.firstSessionDate != nil {
                    StatsSummaryCard(
                        title: "First Session",
                        value: stats.formattedFirstSessionDate ?? "Unknown",
                        icon: "star.fill",
                        color: .yellow
                    )
                }
            }
        }
    }

    // MARK: - Activity Chart Section

    private func activityChartSection(_ stats: StatsCache) -> some View {
        InteractiveChartCard(
            title: "Daily Activity",
            onExport: { exportActivityData(stats) }
        ) {
            if stats.dailyActivity.isEmpty {
                ContentUnavailableView("No Activity Data", systemImage: "chart.bar")
                    .frame(height: .chartHeightStandard)
            } else {
                Chart(stats.dailyActivity) { day in
                    BarMark(
                        x: .value("Date", day.parsedDate ?? Date(), unit: .day),
                        y: .value("Messages", day.messageCount)
                    )
                    .foregroundStyle(.blue.gradient)
                    .cornerRadius(4)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let val = value.as(Int.self) {
                                Text(formatNumber(val))
                            }
                        }
                    }
                }
                .frame(height: .chartHeightStandard)
            }
        }
    }

    // MARK: - Model Usage Section

    private func modelUsageSection(_ stats: StatsCache) -> some View {
        InteractiveChartCard(
            title: "Token Usage by Model",
            onExport: { exportModelData(stats) }
        ) {
            if stats.modelUsage.isEmpty {
                ContentUnavailableView("No Model Data", systemImage: "cpu")
                    .frame(height: .chartHeightStandard)
            } else {
                HStack(spacing: 24) {
                    // Pie Chart
                    Chart(Array(stats.modelUsage), id: \.key) { model in
                        SectorMark(
                            angle: .value("Tokens", model.value.totalTokens),
                            innerRadius: .ratio(0.5),
                            angularInset: 2
                        )
                        .foregroundStyle(by: .value("Model", shortModelName(model.key)))
                        .cornerRadius(6)
                    }
                    .chartLegend(position: .trailing, alignment: .center)
                    .frame(width: .chartHeightStandard, height: .chartHeightStandard)

                    // Details Table
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(stats.modelUsage).sorted(by: { $0.value.totalTokens > $1.value.totalTokens }), id: \.key) { model in
                            ModelUsageRow(
                                modelName: shortModelName(model.key),
                                usage: model.value,
                                fullName: model.key
                            )
                        }
                    }
                    .frame(width: 280)
                }
            }
        }
    }

    // MARK: - Hourly Distribution Section

    private func hourlyDistributionSection(_ stats: StatsCache) -> some View {
        InteractiveChartCard(
            title: "Activity by Hour of Day",
            onExport: { exportHourlyData(stats) }
        ) {
            if stats.hourCounts.isEmpty {
                ContentUnavailableView("No Hourly Data", systemImage: "clock")
                    .frame(height: .chartHeightCompact)
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
                        item.hour >= 9 && item.hour <= 17 ? Color.blue.gradient : Color.blue.opacity(0.5).gradient
                    )
                    .cornerRadius(2)
                }
                .chartXAxis {
                    AxisMarks(values: [0, 6, 12, 18, 23]) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let hour = value.as(Int.self) {
                                Text(formatHour(hour))
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .frame(height: .chartHeightCompact)
            }
        }
    }

    // MARK: - Details Section

    private func detailsSection(_ stats: StatsCache) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                DetailRow(label: "Cache Version", value: "\(stats.version)")
                DetailRow(label: "Last Computed", value: stats.lastComputedDate)

                if let longest = stats.longestSession {
                    Divider()
                    Text("Longest Session")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    DetailRow(label: "Duration", value: longest.formattedDuration)
                    DetailRow(label: "Messages", value: "\(longest.messageCount)")
                    DetailRow(label: "Date", value: longest.formattedDate)
                }

                Divider()

                HStack {
                    Text("File Path")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    CopyableCodeBlock(code: loader.filePath, label: nil)
                }
            }
        } label: {
            Label("Details", systemImage: "info.circle")
                .font(.headline)
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
            return "Claude Opus 4.5"
        } else if fullName.contains("opus-4-1") || fullName.contains("opus-4.1") || fullName.contains("opus-4-0") {
            return "Claude Opus 4.1"
        } else if fullName.contains("opus") {
            return "Claude Opus"
        } else if fullName.contains("sonnet-4-5") || fullName.contains("sonnet-4.5") {
            return "Claude Sonnet 4.5"
        } else if fullName.contains("sonnet-4-0") || fullName.contains("sonnet-4.0") {
            return "Claude Sonnet 4.0"
        } else if fullName.contains("sonnet-3-5") || fullName.contains("sonnet-3.5") {
            return "Claude Sonnet 3.5"
        } else if fullName.contains("sonnet") {
            return "Claude Sonnet"
        } else if fullName.contains("haiku-4-5") || fullName.contains("haiku-4.5") {
            return "Claude Haiku 4.5"
        } else if fullName.contains("haiku-3-5") || fullName.contains("haiku-3.5") {
            return "Claude Haiku 3.5"
        } else if fullName.contains("haiku") {
            return "Claude Haiku"
        }
        return fullName
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

// MARK: - Stats Summary Card

struct StatsSummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    @State private var isHovered = false
    @State private var showCopied = false

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(.title2, design: .rounded, weight: .semibold))
                    .foregroundStyle(.primary)

                if showCopied {
                    Text("Copied!")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }
            }
        } label: {
            Label(title, systemImage: icon)
                .font(.caption.weight(.medium))
                .foregroundStyle(color)
        }
        .groupBoxStyle(CardGroupBoxStyle(isHovered: isHovered))
        .onHover { hovering in
            withAnimation(.spring(response: 0.3)) {
                isHovered = hovering
            }
        }
        .onTapGesture(count: 2) {
            copyValue()
        }
        .contextMenu {
            Button(action: copyValue) {
                Label("Copy Value", systemImage: "doc.on.doc")
            }
        }
        .help("Double-click to copy")
    }

    private func copyValue() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        withAnimation {
            showCopied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showCopied = false
            }
        }
    }
}

// MARK: - Model Usage Row

struct ModelUsageRow: View {
    let modelName: String
    let usage: ModelUsage
    let fullName: String

    @State private var isHovered = false
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(colorForModel(modelName))
                    .frame(width: 8, height: 8)

                Text(modelName)
                    .font(.caption.weight(.medium))

                Spacer()

                Text(formatTokens(usage.totalTokens))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)

                Button(action: { withAnimation { isExpanded.toggle() } }) {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .buttonStyle(.plain)
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 2) {
                    TokenDetailRow(label: "Input", value: usage.inputTokens)
                    TokenDetailRow(label: "Output", value: usage.outputTokens)
                    TokenDetailRow(label: "Cache Read", value: usage.cacheReadInputTokens)
                    TokenDetailRow(label: "Cache Write", value: usage.cacheCreationInputTokens)

                    Divider()

                    HStack {
                        Text("Est. Cost")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "$%.2f", usage.estimatedCost(for: fullName)))
                            .font(.system(.caption2, design: .monospaced, weight: .medium))
                            .foregroundStyle(.green)
                    }
                }
                .padding(.leading, 16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(8)
        .background(isHovered ? Color.gray.opacity(0.1) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }

    private func colorForModel(_ name: String) -> Color {
        if name.contains("Opus") { return .purple }
        if name.contains("Sonnet") { return .blue }
        if name.contains("Haiku") { return .green }
        return .gray
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

// MARK: - Token Detail Row

struct TokenDetailRow: View {
    let label: String
    let value: Int

    var body: some View {
        HStack {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Spacer()
            Text(formatValue(value))
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private func formatValue(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

// MARK: - Detail Row

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
        }
    }
}

// MARK: - Copyable Code Block

struct CopyableCodeBlock: View {
    let code: String
    let label: String?

    @State private var showCopied = false

    var body: some View {
        HStack(spacing: 8) {
            if let label = label {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(code)
                .font(.system(.caption2, design: .monospaced))
                .textSelection(.enabled)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.8))
                .foregroundStyle(.green)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            Button(action: copyToClipboard) {
                Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                    .font(.caption2)
                    .foregroundStyle(showCopied ? .green : .secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        withAnimation {
            showCopied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showCopied = false
            }
        }
    }
}

#if DEBUG
struct StatsCacheView_Previews: PreviewProvider {
    static var previews: some View {
        StatsCacheView()
    }
}
#endif
