import SwiftUI
import Charts
import UniformTypeIdentifiers

// MARK: - Summary Dashboard View (Tab 1)
// Per spec: KPI tiles for Total spend, Total tokens, Active time, Sessions,
// Lines added, Lines removed, Commits, PRs
// Graphs: Cost rate over time, Cost per model breakdown

struct SummaryDashboardView: View {
    @ObservedObject var metricsService: MetricsService
    @State private var showExportMenu = false

    private let columns = [
        GridItem(.adaptive(minimum: 180, maximum: 220), spacing: 20)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                headerSection
                kpiCardsSection
                chartsSection
            }
            .padding(24)
        }
        .frame(minWidth: 650, minHeight: 550)
        .background(Color(NSColor.controlBackgroundColor))
        .overlay {
            if metricsService.isLoading {
                ZStack {
                    Color.black.opacity(0.05)
                    ProgressView()
                        .scaleEffect(1.2)
                        .progressViewStyle(CircularProgressViewStyle())
                }
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
            }
        }
        .overlay {
            if !metricsService.connectionStatus.isConnected {
                disconnectedOverlay
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Dashboard Overview")
                    .font(.title2.weight(.semibold))
                Text("Showing data for \(metricsService.currentTimeRange.displayName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Export menu
            Menu {
                Button(action: copyAllMetrics) {
                    Label("Copy All Metrics", systemImage: "doc.on.doc")
                }

                Button(action: exportSummary) {
                    Label("Export Summary", systemImage: "square.and.arrow.up")
                }

                Divider()

                Button(action: shareMetrics) {
                    Label("Share", systemImage: "square.and.arrow.up.on.square")
                }
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .menuStyle(.borderedButton)
            .fixedSize()
        }
    }

    // MARK: - KPI Cards Section

    private var kpiCardsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Key Metrics")
                    .font(.sectionTitle)
                Spacer()
                Text("Double-click to copy")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            LazyVGrid(columns: columns, spacing: 20) {
                InteractiveKPICard(
                    title: "Total Spend",
                    value: metricsService.dashboardData.formattedCost,
                    icon: "dollarsign.circle.fill",
                    color: .metricGreen,
                    subtitle: "USD"
                )

                InteractiveKPICard(
                    title: "Active Time",
                    value: metricsService.dashboardData.formattedActiveTime,
                    icon: "clock.fill",
                    color: .metricOrange,
                    subtitle: "coding with Claude"
                )

                InteractiveKPICard(
                    title: "Total Tokens",
                    value: metricsService.dashboardData.formattedTokens,
                    icon: "number.circle.fill",
                    color: .metricBlue,
                    subtitle: "all models"
                )

                InteractiveKPICard(
                    title: "Lines Added",
                    value: "+\(String(format: "%.0f", metricsService.dashboardData.linesAdded))",
                    icon: "plus.circle.fill",
                    color: .metricMint,
                    subtitle: "code added"
                )

                InteractiveKPICard(
                    title: "Lines Removed",
                    value: "-\(String(format: "%.0f", metricsService.dashboardData.linesRemoved))",
                    icon: "minus.circle.fill",
                    color: .metricRed,
                    subtitle: "code removed"
                )

                InteractiveKPICard(
                    title: "Commits",
                    value: String(format: "%.0f", metricsService.dashboardData.commitCount),
                    icon: "checkmark.circle.fill",
                    color: .metricIndigo,
                    subtitle: "git commits"
                )

                InteractiveKPICard(
                    title: "Pull Requests",
                    value: String(format: "%.0f", metricsService.dashboardData.prCount),
                    icon: "arrow.triangle.pull",
                    color: .metricTeal,
                    subtitle: "PRs created"
                )
            }
        }
    }

    // MARK: - Charts Section

    private var chartsSection: some View {
        VStack(spacing: 24) {
            // Cumulative Total Cost Chart - Interactive
            InteractiveChartCard(
                title: "Total Cost Over Period (\(metricsService.currentTimeRange.displayName))",
                onExport: { exportCostRateData() }
            ) {
                if metricsService.dashboardData.costSeries.isEmpty {
                    emptyChartPlaceholder
                } else {
                    // Calculate cumulative cost scaled to match Total Spend
                    let cumulativeData = calculateCumulativeCost(
                        metricsService.dashboardData.costSeries,
                        targetTotal: metricsService.dashboardData.totalCost
                    )

                    InteractiveLineChart(
                        data: cumulativeData,
                        title: "Total Cost",
                        color: .metricGreen,
                        valueFormatter: { String(format: "$%.2f", $0) },
                        yAxisLabel: "USD"
                    )
                }
            }

            // Cost Per Model Breakdown - with context menu
            InteractiveChartCard(
                title: "Cost by Model",
                onExport: { exportModelCostData() }
            ) {
                if metricsService.dashboardData.costByModel.isEmpty {
                    emptyChartPlaceholder
                } else {
                    HStack(spacing: 24) {
                        // Pie Chart
                        Chart(Array(metricsService.dashboardData.costByModel), id: \.key) { item in
                            SectorMark(
                                angle: .value("Cost", item.value),
                                innerRadius: .ratio(0.5),
                                angularInset: 2
                            )
                            .foregroundStyle(by: .value("Model", shortModelName(item.key)))
                            .cornerRadius(6)
                        }
                        .chartLegend(position: .trailing, alignment: .center)
                        .chartBackground { _ in
                            Circle()
                                .fill(Color.gray.opacity(0.03))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)

                        // Cost breakdown table with copy functionality
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(Array(metricsService.dashboardData.costByModel.sorted { $0.value > $1.value }), id: \.key) { item in
                                ModelCostRow(
                                    modelName: shortModelName(item.key),
                                    cost: item.value,
                                    color: colorForModel(shortModelName(item.key))
                                )
                            }
                        }
                        .frame(width: 200)
                        .padding(12)
                        .background(Color.gray.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private var emptyChartPlaceholder: some View {
        ContentUnavailableView {
            Label("No Data", systemImage: "chart.line.downtrend.xyaxis")
        } description: {
            Text("No metrics data available for this time range")
        }
        .frame(height: 150)
    }

    private var disconnectedOverlay: some View {
        ContentUnavailableView {
            Label("Not Connected", systemImage: "wifi.slash")
        } description: {
            Text(metricsService.errorMessage ?? "Unable to connect to Prometheus")
        } actions: {
            Button("Retry Connection") {
                Task { await metricsService.checkConnection() }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }

    private func shortModelName(_ fullName: String) -> String {
        // Show exact model versions like "Opus 4.5" or "Opus 4.1"
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
        // Return last part of model name if unknown format
        let parts = fullName.split(separator: "-")
        if parts.count > 1 {
            return String(parts.prefix(2).joined(separator: "-"))
        }
        return fullName
    }

    private func colorForModel(_ modelName: String) -> Color {
        switch modelName.lowercased() {
        case let name where name.contains("opus"):
            return .purple
        case let name where name.contains("sonnet"):
            return .blue
        case let name where name.contains("haiku"):
            return .green
        default:
            return .gray
        }
    }

    private func calculateCumulativeCost(_ series: [MetricDataPoint], targetTotal: Double) -> [MetricDataPoint] {
        guard !series.isEmpty else { return [] }

        // First pass: calculate raw cumulative values
        var cumulative: Double = 0
        var rawCumulative = series.map { point -> MetricDataPoint in
            cumulative += point.value
            return MetricDataPoint(timestamp: point.timestamp, value: cumulative, labels: point.labels)
        }

        // Scale the values so the final point matches the target total (Total Spend)
        let rawTotal = rawCumulative.last?.value ?? 0
        if rawTotal > 0 && targetTotal > 0 {
            let scaleFactor = targetTotal / rawTotal
            rawCumulative = rawCumulative.map { point in
                MetricDataPoint(timestamp: point.timestamp, value: point.value * scaleFactor, labels: point.labels)
            }
        }

        return rawCumulative
    }

    // MARK: - Export Functions

    private func copyAllMetrics() {
        let exporter = MetricsSummaryExporter(
            dashboardData: metricsService.dashboardData,
            timeRange: metricsService.currentTimeRange.displayName
        )
        exporter.copyToClipboard()
    }

    private func exportSummary() {
        let exporter = MetricsSummaryExporter(
            dashboardData: metricsService.dashboardData,
            timeRange: metricsService.currentTimeRange.displayName
        )
        exporter.exportToFile()
    }

    private func shareMetrics() {
        let exporter = MetricsSummaryExporter(
            dashboardData: metricsService.dashboardData,
            timeRange: metricsService.currentTimeRange.displayName
        )
        ChartExportManager.shareData(
            title: "Claude Code Metrics",
            data: exporter.generateSummary()
        )
    }

    private func exportCostRateData() {
        let cumulativeData = calculateCumulativeCost(
            metricsService.dashboardData.costSeries,
            targetTotal: metricsService.dashboardData.totalCost
        )
        let data = cumulativeData.map {
            (ISO8601DateFormatter().string(from: $0.timestamp), String(format: "%.6f", $0.value))
        }
        ChartExportManager.exportToCSV(title: "Total_Cost", data: data)
    }

    private func exportModelCostData() {
        let data = metricsService.dashboardData.costByModel.map {
            (shortModelName($0.key), DashboardData.formatCost($0.value))
        }
        ChartExportManager.exportToCSV(title: "Cost_by_Model", data: data)
    }
}

// MARK: - Model Cost Row (with copy functionality)

struct ModelCostRow: View {
    let modelName: String
    let cost: Double
    let color: Color
    @State private var isHovered = false
    @State private var showCopied = false

    var body: some View {
        HStack {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(modelName)
                    .font(.cardSubtitle)
                    .lineLimit(1)
            }
            Spacer()

            if showCopied {
                Text("Copied!")
                    .font(.caption2)
                    .foregroundStyle(.green)
                    .transition(.opacity)
            } else {
                Text(DashboardData.formatCost(cost))
                    .font(.system(.caption, design: .monospaced, weight: .medium))
                    .foregroundStyle(isHovered ? .primary : .secondary)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(isHovered ? color.opacity(0.1) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            copyToClipboard()
        }
        .contextMenu {
            Button(action: copyToClipboard) {
                Label("Copy Cost", systemImage: "doc.on.doc")
            }
            Button(action: copyWithModel) {
                Label("Copy with Model Name", systemImage: "doc.on.doc.fill")
            }
        }
        .help("Click to copy cost")
    }

    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(DashboardData.formatCost(cost), forType: .string)
        withAnimation {
            showCopied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            withAnimation {
                showCopied = false
            }
        }
    }

    private func copyWithModel() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("\(modelName): \(DashboardData.formatCost(cost))", forType: .string)
        withAnimation {
            showCopied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            withAnimation {
                showCopied = false
            }
        }
    }
}

// MARK: - Modern KPI Card

struct ModernKPICard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    @State private var isHovered = false

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.metricValue)
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
            }
        } label: {
            Label(title, systemImage: icon)
                .font(.metricLabel)
                .foregroundStyle(color)
        }
        .groupBoxStyle(CardGroupBoxStyle(isHovered: isHovered))
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Modern Chart Card

struct ModernChartCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        GroupBox {
            content
        } label: {
            Text(title)
                .font(.chartTitle)
        }
        .groupBoxStyle(ChartGroupBoxStyle())
    }
}

#if DEBUG
struct SummaryDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        SummaryDashboardView(metricsService: MetricsService())
    }
}
#endif
