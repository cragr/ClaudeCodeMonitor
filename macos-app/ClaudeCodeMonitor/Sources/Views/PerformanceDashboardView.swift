import SwiftUI
import Charts

// MARK: - Performance Dashboard View (Tab 2)
// Per spec: Total tokens time series, Tokens by model, Tokens by type,
// Compact breakdown of input/output/cacheRead/cacheCreation

struct PerformanceDashboardView: View {
    @ObservedObject var metricsService: MetricsService

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                tokenBreakdownSection
                tokenTimeSeriesSection
                tokensByModelSection
                tokensByTypeSection
            }
            .padding()
        }
        .frame(minWidth: 600, minHeight: 500)
        .overlay {
            if metricsService.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
            }
        }
        .overlay {
            if !metricsService.connectionStatus.isConnected {
                disconnectedOverlay
            }
        }
    }

    // MARK: - Token Breakdown Section (Compact summary)

    private var tokenBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Token Breakdown")
                    .font(.title2.bold())
                Spacer()
                Text("Total: \(metricsService.dashboardData.formattedTokens)")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                TokenTypeCard(
                    type: "Input",
                    value: metricsService.dashboardData.tokensByType["input"] ?? 0,
                    color: .blue,
                    icon: "arrow.right.circle.fill"
                )

                TokenTypeCard(
                    type: "Output",
                    value: metricsService.dashboardData.tokensByType["output"] ?? 0,
                    color: .green,
                    icon: "arrow.left.circle.fill"
                )

                TokenTypeCard(
                    type: "Cache Read",
                    value: metricsService.dashboardData.tokensByType["cacheRead"] ?? 0,
                    color: .orange,
                    icon: "arrow.triangle.2.circlepath.circle.fill"
                )

                TokenTypeCard(
                    type: "Cache Creation",
                    value: metricsService.dashboardData.tokensByType["cacheCreation"] ?? 0,
                    color: .purple,
                    icon: "plus.circle.fill"
                )
            }
        }
    }

    // MARK: - Total Tokens Time Series

    private var tokenTimeSeriesSection: some View {
        ChartCard(title: "Total Tokens Over Time") {
            if metricsService.dashboardData.tokensSeries.isEmpty {
                emptyChartPlaceholder
            } else {
                Chart(metricsService.dashboardData.tokensSeries) { point in
                    LineMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Rate", point.value)
                    )
                    .foregroundStyle(.blue.gradient)

                    AreaMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Rate", point.value)
                    )
                    .foregroundStyle(.blue.opacity(0.1).gradient)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: metricsService.currentTimeRange.bucketGranularity.chartDateFormat)
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let val = value.as(Double.self) {
                                Text(DashboardData.formatTokenCount(val))
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Tokens by Model (Stacked/Grouped)

    private var tokensByModelSection: some View {
        ChartCard(title: "Tokens by Model") {
            if metricsService.dashboardData.tokensByModelSeries.isEmpty {
                emptyChartPlaceholder
            } else {
                Chart {
                    ForEach(metricsService.dashboardData.tokensByModelSeries) { modelSeries in
                        ForEach(modelSeries.dataPoints) { point in
                            LineMark(
                                x: .value("Time", point.timestamp),
                                y: .value("Rate", point.value)
                            )
                            .foregroundStyle(by: .value("Model", shortModelName(modelSeries.model)))
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: metricsService.currentTimeRange.bucketGranularity.chartDateFormat)
                    }
                }
                .chartLegend(position: .bottom, alignment: .center)
            }
        }
    }

    // MARK: - Tokens by Type (input/output/cacheRead/cacheCreation)

    private var tokensByTypeSection: some View {
        ChartCard(title: "Tokens by Type") {
            if metricsService.dashboardData.tokensByTypeSeries.isEmpty {
                emptyChartPlaceholder
            } else {
                Chart {
                    ForEach(metricsService.dashboardData.tokensByTypeSeries) { typeSeries in
                        ForEach(typeSeries.dataPoints) { point in
                            AreaMark(
                                x: .value("Time", point.timestamp),
                                y: .value("Rate", point.value)
                            )
                            .foregroundStyle(by: .value("Type", displayTypeName(typeSeries.tokenType)))
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: metricsService.currentTimeRange.bucketGranularity.chartDateFormat)
                    }
                }
                .chartLegend(position: .bottom, alignment: .center)
                .chartForegroundStyleScale([
                    "Input": Color.blue,
                    "Output": Color.green,
                    "Cache Read": Color.orange,
                    "Cache Creation": Color.purple
                ])
            }
        }
    }

    // MARK: - Helpers

    private var emptyChartPlaceholder: some View {
        ContentUnavailableView {
            Label("No Data", systemImage: "chart.line.downtrend.xyaxis")
        } description: {
            Text("No token metrics available for this time range")
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
        if fullName.contains("opus") {
            return "opus"
        } else if fullName.contains("sonnet") {
            if fullName.contains("4-5") || fullName.contains("4.5") {
                return "sonnet-4.5"
            } else if fullName.contains("4-0") || fullName.contains("4.0") {
                return "sonnet-4.0"
            }
            return "sonnet"
        } else if fullName.contains("haiku") {
            return "haiku"
        }
        let parts = fullName.split(separator: "-")
        if parts.count > 1 {
            return String(parts.prefix(2).joined(separator: "-"))
        }
        return fullName
    }

    private func displayTypeName(_ type: String) -> String {
        switch type {
        case "input": return "Input"
        case "output": return "Output"
        case "cacheRead": return "Cache Read"
        case "cacheCreation": return "Cache Creation"
        default: return type.capitalized
        }
    }
}

// MARK: - Token Type Card

struct TokenTypeCard: View {
    let type: String
    let value: Double
    let color: Color
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(type)
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)

            Text(DashboardData.formatTokenCount(value))
                .font(.system(.title2, design: .rounded, weight: .semibold))
                .foregroundStyle(.primary)

            // Percentage bar (optional visualization)
            GeometryReader { geometry in
                RoundedRectangle(cornerRadius: 2)
                    .fill(color.opacity(0.3))
                    .frame(height: 4)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(color)
                            .frame(width: geometry.size.width * min(1.0, value / max(1, totalTokens)), height: 4)
                    }
            }
            .frame(height: 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var totalTokens: Double {
        value // This would ideally be the total, but we calculate percentage relative to self
    }
}

#if DEBUG
struct PerformanceDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        PerformanceDashboardView(metricsService: MetricsService())
    }
}
#endif
