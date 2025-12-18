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
            .map { shortModelName($0.key) }
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
                .foregroundStyle(colorForModel(shortModelName(item.key), in: sortedModels))
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
                        modelName: shortModelName(item.key),
                        cost: item.value,
                        color: colorForModel(shortModelName(item.key), in: sortedModels),
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
        let parts = fullName.split(separator: "-")
        if parts.count > 1 {
            return String(parts.prefix(2).joined(separator: "-"))
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

    private func colorForModel(_ modelName: String, in models: [String]) -> Color {
        // Get the index of this model in the sorted list to assign a unique color
        if let index = models.firstIndex(of: modelName) {
            return modelColorPalette[index % modelColorPalette.count]
        }
        return .noirTextSecondary
    }

    private func colorForModel(_ modelName: String) -> Color {
        // Fallback for legacy calls - use model family-based colors
        switch modelName.lowercased() {
        case let name where name.contains("opus"):
            return .phosphorPurple
        case let name where name.contains("sonnet"):
            return .phosphorCyan
        case let name where name.contains("haiku"):
            return .phosphorGreen
        default:
            return .noirTextSecondary
        }
    }

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
            (shortModelName($0.key), DashboardData.formatCost($0.value))
        }
        ChartExportManager.exportToCSV(title: "Cost_by_Model", data: data)
    }
}

// MARK: - Terminal Line Chart

struct TerminalLineChart: View {
    let data: [MetricDataPoint]
    let color: Color
    let valueFormatter: (Double) -> String

    @State private var selectedPoint: MetricDataPoint?
    @State private var tooltipPosition: CGPoint = .zero
    @State private var showTooltip = false

    var body: some View {
        Chart(data) { point in
            // Line
            LineMark(
                x: .value("Time", point.timestamp),
                y: .value("Value", point.value)
            )
            .foregroundStyle(color)
            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

            // Area fill with gradient
            AreaMark(
                x: .value("Time", point.timestamp),
                y: .value("Value", point.value)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [color.opacity(0.25), color.opacity(0.05), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            // Selection indicator
            if let selected = selectedPoint, selected.id == point.id {
                RuleMark(x: .value("Selected", selected.timestamp))
                    .foregroundStyle(color.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))

                PointMark(
                    x: .value("Time", selected.timestamp),
                    y: .value("Value", selected.value)
                )
                .foregroundStyle(color)
                .symbolSize(60)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.noirStroke)
                AxisValueLabel()
                    .font(.terminalDataSmall)
                    .foregroundStyle(Color.noirTextTertiary)
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.noirStroke)
                AxisValueLabel {
                    if let val = value.as(Double.self) {
                        Text(valueFormatter(val))
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
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                updateSelection(at: value.location, proxy: proxy, geometry: geometry)
                            }
                            .onEnded { _ in
                                withAnimation(.easeOut(duration: 0.2)) {
                                    selectedPoint = nil
                                    showTooltip = false
                                }
                            }
                    )
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            updateSelection(at: location, proxy: proxy, geometry: geometry)
                        case .ended:
                            withAnimation(.easeOut(duration: 0.2)) {
                                selectedPoint = nil
                                showTooltip = false
                            }
                        }
                    }
            }
        }
        .overlay(alignment: .topLeading) {
            if showTooltip, let point = selectedPoint {
                TerminalChartTooltip(
                    title: formatDate(point.timestamp),
                    value: valueFormatter(point.value),
                    color: color
                )
                .offset(x: max(10, min(tooltipPosition.x - 60, 200)), y: max(10, tooltipPosition.y - 70))
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
    }

    private func updateSelection(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        guard let plotFrame = proxy.plotFrame else { return }
        let xPosition = location.x - geometry[plotFrame].origin.x

        if let date: Date = proxy.value(atX: xPosition) {
            let closest = data.min(by: { abs($0.timestamp.timeIntervalSince(date)) < abs($1.timestamp.timeIntervalSince(date)) })

            withAnimation(.easeOut(duration: 0.1)) {
                selectedPoint = closest
                tooltipPosition = location
                showTooltip = true
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Terminal Chart Tooltip

struct TerminalChartTooltip: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(title)
                .font(.terminalCaptionSmall)
                .foregroundStyle(Color.noirTextTertiary)

            HStack(spacing: Spacing.xs) {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                    .phosphorGlow(color, intensity: 0.6, isActive: true)

                Text(value)
                    .font(.terminalData)
                    .foregroundStyle(Color.noirTextPrimary)
            }
        }
        .padding(Spacing.sm)
        .background {
            RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                .fill(Color.noirElevated)
                .overlay {
                    RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                        .strokeBorder(color.opacity(0.3), lineWidth: 1)
                }
        }
        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
    }
}

// MARK: - Terminal Model Cost Row

struct TerminalModelCostRow: View {
    let modelName: String
    let cost: Double
    let color: Color
    let percentage: Double

    @State private var isHovered = false
    @State private var showCopied = false

    var body: some View {
        VStack(spacing: Spacing.xs) {
            HStack {
                HStack(spacing: Spacing.sm) {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                        .phosphorGlow(color, intensity: 0.5, isActive: isHovered)

                    Text(modelName)
                        .font(.terminalCaption)
                        .foregroundStyle(Color.noirTextSecondary)
                }

                Spacer()

                if showCopied {
                    Text("COPIED")
                        .font(.terminalCaptionSmall)
                        .foregroundStyle(Color.phosphorGreen)
                        .transition(.opacity)
                } else {
                    Text(DashboardData.formatCost(cost))
                        .font(.terminalData)
                        .foregroundStyle(isHovered ? color : Color.noirTextPrimary)
                        .phosphorGlow(color, intensity: 0.3, isActive: isHovered)
                }
            }

            // Percentage bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.noirStroke)
                        .frame(height: 3)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(color.opacity(isHovered ? 1 : 0.7))
                        .frame(width: geometry.size.width * min(1.0, percentage), height: 3)
                        .phosphorGlow(color, intensity: 0.3, isActive: isHovered)
                }
            }
            .frame(height: 3)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(isHovered ? color.opacity(0.08) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(modelName): \(DashboardData.formatCost(cost))")
    }

    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(DashboardData.formatCost(cost), forType: .string)
        withAnimation { showCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            withAnimation { showCopied = false }
        }
    }

    private func copyWithModel() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("\(modelName): \(DashboardData.formatCost(cost))", forType: .string)
        withAnimation { showCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            withAnimation { showCopied = false }
        }
    }
}

// MARK: - Legacy Components (kept for compatibility)

struct ModernKPICard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    @State private var isHovered = false

    var body: some View {
        TerminalMetricCard(title: title, value: value, icon: icon, color: color)
    }
}

struct ModernChartCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        TerminalChartCard(title: title, subtitle: nil, onExport: nil) {
            content
        }
    }
}

#if DEBUG
struct SummaryDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        SummaryDashboardView(metricsService: MetricsService())
    }
}
#endif
