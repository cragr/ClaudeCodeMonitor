import SwiftUI
import Charts
import UniformTypeIdentifiers

// MARK: - Summary Dashboard View (Tab 1)
// Terminal Noir aesthetic with phosphor glow effects

struct SummaryDashboardView: View {
    @ObservedObject var metricsService: MetricsService
    @State private var showExportMenu = false
    @State private var appearAnimation = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 200), spacing: Spacing.lg)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xxl) {
                // Hero section with primary cost
                heroSection
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 10)

                // KPI Grid
                kpiGridSection
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 15)

                // Charts
                chartsSection
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 20)
            }
            .padding(Spacing.xl)
        }
        .frame(minWidth: 650, minHeight: 550)
        .background(Color.noirBackground)
        .overlay {
            if metricsService.isLoading && !metricsService.connectionStatus.isConnected {
                loadingOverlay
            }
        }
        .overlay {
            if !metricsService.connectionStatus.isConnected && !metricsService.isLoading {
                disconnectedOverlay
            }
        }
        .onAppear {
            withAnimation(reduceMotion ? .none : .easeOut(duration: 0.5)) {
                appearAnimation = true
            }
        }
    }

    // MARK: - Hero Section (Primary Cost Display)

    private var heroSection: some View {
        HStack(alignment: .top, spacing: Spacing.xl) {
            // Main cost display
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.sm) {
                    Circle()
                        .fill(Color.phosphorGreen)
                        .frame(width: 8, height: 8)
                        .phosphorGlow(.phosphorGreen, intensity: 0.8, isActive: true)

                    Text("TOTAL SPEND")
                        .font(.terminalCaptionSmall)
                        .foregroundStyle(Color.noirTextSecondary)
                        .tracking(2)
                }

                Text(metricsService.dashboardData.formattedCost)
                    .font(.terminalDisplay)
                    .foregroundStyle(Color.noirTextPrimary)
                    .phosphorGlow(.phosphorGreen, intensity: 0.4, isActive: true)
                    .contentTransition(.numericText())

                Text(metricsService.currentTimeRange.displayName)
                    .font(.terminalCaption)
                    .foregroundStyle(Color.noirTextTertiary)
            }

            Spacer()

            // Export actions
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
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 11))
                    Text("EXPORT")
                        .font(.terminalCaptionSmall)
                        .tracking(1)
                }
                .foregroundStyle(Color.noirTextSecondary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background {
                    Capsule()
                        .strokeBorder(Color.noirStroke, lineWidth: 1)
                }
            }
            .menuStyle(.borderlessButton)
        }
        .padding(Spacing.xl)
        .background {
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .fill(Color.noirSurface)
                .overlay {
                    // Subtle gradient glow at top
                    RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.phosphorGreen.opacity(0.08), .clear],
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

    // MARK: - KPI Grid Section

    private var kpiGridSection: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            TerminalSectionHeader("Key Metrics", trailing: "Double-click to copy")

            LazyVGrid(columns: columns, spacing: Spacing.lg) {
                TerminalMetricCard(
                    title: "Active Time",
                    value: metricsService.dashboardData.formattedActiveTime,
                    icon: "clock.fill",
                    color: .phosphorAmber,
                    subtitle: "coding with Claude"
                )

                TerminalMetricCard(
                    title: "Total Tokens",
                    value: metricsService.dashboardData.formattedTokens,
                    icon: "number.circle.fill",
                    color: .phosphorCyan,
                    subtitle: "all models"
                )

                TerminalMetricCard(
                    title: "Lines Added",
                    value: "+\(String(format: "%.0f", metricsService.dashboardData.linesAdded))",
                    icon: "plus.circle.fill",
                    color: .phosphorMagenta,
                    subtitle: "code added"
                )

                TerminalMetricCard(
                    title: "Lines Removed",
                    value: "-\(String(format: "%.0f", metricsService.dashboardData.linesRemoved))",
                    icon: "minus.circle.fill",
                    color: .phosphorRed,
                    subtitle: "code removed"
                )

                TerminalMetricCard(
                    title: "Commits",
                    value: String(format: "%.0f", metricsService.dashboardData.commitCount),
                    icon: "checkmark.circle.fill",
                    color: .phosphorPurple,
                    subtitle: "git commits"
                )

                TerminalMetricCard(
                    title: "Pull Requests",
                    value: String(format: "%.0f", metricsService.dashboardData.prCount),
                    icon: "arrow.triangle.pull",
                    color: .phosphorCyan,
                    subtitle: "PRs created"
                )
            }
        }
    }

    // MARK: - Charts Section

    private var chartsSection: some View {
        VStack(spacing: Spacing.xl) {
            // Cost Over Time Chart
            TerminalChartCard(
                title: "Total Cost Over Period",
                subtitle: metricsService.currentTimeRange.displayName,
                onExport: { exportCostRateData() }
            ) {
                if metricsService.dashboardData.costSeries.isEmpty {
                    TerminalEmptyState(
                        title: "No Data",
                        message: "No cost data available for this time range",
                        icon: "chart.line.downtrend.xyaxis"
                    )
                } else {
                    let cumulativeData = calculateCumulativeCost(
                        metricsService.dashboardData.costSeries,
                        targetTotal: metricsService.dashboardData.totalCost
                    )

                    TerminalLineChart(
                        data: cumulativeData,
                        color: .phosphorGreen,
                        valueFormatter: { String(format: "$%.2f", $0) }
                    )
                }
            }

            // Cost by Model Chart
            TerminalChartCard(
                title: "Cost by Model",
                subtitle: "breakdown",
                onExport: { exportModelCostData() }
            ) {
                if metricsService.dashboardData.costByModel.isEmpty {
                    TerminalEmptyState(
                        title: "No Data",
                        message: "No model cost data available",
                        icon: "cpu"
                    )
                } else {
                    modelBreakdownContent
                }
            }
        }
    }

    private var sortedModelNames: [String] {
        metricsService.dashboardData.costByModel
            .sorted { $0.value > $1.value }
            .map { ModelFormatting.shortName($0.key) }
    }

    private var modelBreakdownContent: some View {
        let sortedModels = sortedModelNames

        return HStack(spacing: Spacing.xl) {
            // Donut Chart
            Chart(Array(metricsService.dashboardData.costByModel.sorted { $0.value > $1.value }), id: \.key) { item in
                SectorMark(
                    angle: .value("Cost", item.value),
                    innerRadius: .ratio(0.55),
                    outerRadius: .ratio(0.95),
                    angularInset: 3
                )
                .foregroundStyle(ModelFormatting.color(for: ModelFormatting.shortName(item.key), in: sortedModels))
                .cornerRadius(4)
            }
            .chartBackground { _ in
                // Center glow effect
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

            // Model breakdown table
            VStack(alignment: .leading, spacing: Spacing.sm) {
                ForEach(Array(metricsService.dashboardData.costByModel.sorted { $0.value > $1.value }), id: \.key) { item in
                    TerminalModelCostRow(
                        modelName: ModelFormatting.shortName(item.key),
                        cost: item.value,
                        color: ModelFormatting.color(for: ModelFormatting.shortName(item.key), in: sortedModels),
                        percentage: item.value / max(metricsService.dashboardData.totalCost, 0.01)
                    )
                }
            }
            .frame(width: 220)
        }
        .frame(height: 200)
    }

    // MARK: - Overlays

    private var loadingOverlay: some View {
        ZStack {
            Color.noirBackground.opacity(0.8)

            VStack(spacing: Spacing.lg) {
                TerminalLoadingIndicator(color: .phosphorCyan)
                    .scaleEffect(1.5)

                Text("LOADING METRICS")
                    .font(.terminalCaptionSmall)
                    .foregroundStyle(Color.noirTextSecondary)
                    .tracking(2)
            }
        }
        .ignoresSafeArea()
    }

    private var disconnectedOverlay: some View {
        ZStack {
            Color.noirBackground.opacity(0.9)

            VStack(spacing: Spacing.xl) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 40, weight: .thin))
                    .foregroundStyle(Color.phosphorRed)
                    .phosphorGlow(.phosphorRed, intensity: 0.5, isActive: true)

                VStack(spacing: Spacing.sm) {
                    Text("NOT CONNECTED")
                        .font(.terminalCaption)
                        .foregroundStyle(Color.noirTextPrimary)
                        .tracking(2)

                    Text(metricsService.errorMessage ?? "Unable to connect to Prometheus")
                        .font(.terminalBodySmall)
                        .foregroundStyle(Color.noirTextSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 300)
                }

                Button(action: { Task { await metricsService.checkConnection() } }) {
                    Text("RETRY CONNECTION")
                        .font(.terminalCaptionSmall)
                        .tracking(1)
                }
                .buttonStyle(TerminalButtonStyle(color: .phosphorCyan, isProminent: true))
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Helpers

    private func calculateCumulativeCost(_ series: [MetricDataPoint], targetTotal: Double) -> [MetricDataPoint] {
        guard !series.isEmpty else { return [] }

        var cumulative: Double = 0
        var rawCumulative = series.map { point -> MetricDataPoint in
            cumulative += point.value
            return MetricDataPoint(timestamp: point.timestamp, value: cumulative, labels: point.labels)
        }

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
            (ModelFormatting.shortName($0.key), DashboardData.formatCost($0.value))
        }
        ChartExportManager.exportToCSV(title: "Cost_by_Model", data: data)
    }
}

#if DEBUG
struct SummaryDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        SummaryDashboardView(metricsService: MetricsService())
    }
}
#endif
