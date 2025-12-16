import SwiftUI
import Charts

// MARK: - Summary Dashboard View (Tab 1)
// Per spec: KPI tiles for Total spend, Total tokens, Active time, Sessions,
// Lines added, Lines removed, Commits, PRs
// Graphs: Cost rate over time, Cost per model breakdown

struct SummaryDashboardView: View {
    @ObservedObject var metricsService: MetricsService

    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                kpiCardsSection
                chartsSection
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

    // MARK: - KPI Cards Section

    private var kpiCardsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Key Metrics")
                .font(.title2.bold())

            LazyVGrid(columns: columns, spacing: 16) {
                KPICard(
                    title: "Total Spend",
                    value: metricsService.dashboardData.formattedCost,
                    icon: "dollarsign.circle.fill",
                    color: .green
                )

                KPICard(
                    title: "Total Tokens",
                    value: metricsService.dashboardData.formattedTokens,
                    icon: "number.circle.fill",
                    color: .blue
                )

                KPICard(
                    title: "Active Time",
                    value: metricsService.dashboardData.formattedActiveTime,
                    icon: "clock.fill",
                    color: .orange
                )

                KPICard(
                    title: "Sessions",
                    value: String(format: "%.0f", metricsService.dashboardData.sessionCount),
                    icon: "terminal.fill",
                    color: .purple
                )

                KPICard(
                    title: "Lines Added",
                    value: "+\(String(format: "%.0f", metricsService.dashboardData.linesAdded))",
                    icon: "plus.circle.fill",
                    color: .mint
                )

                KPICard(
                    title: "Lines Removed",
                    value: "-\(String(format: "%.0f", metricsService.dashboardData.linesRemoved))",
                    icon: "minus.circle.fill",
                    color: .red
                )

                KPICard(
                    title: "Commits",
                    value: String(format: "%.0f", metricsService.dashboardData.commitCount),
                    icon: "checkmark.circle.fill",
                    color: .indigo
                )

                KPICard(
                    title: "Pull Requests",
                    value: String(format: "%.0f", metricsService.dashboardData.prCount),
                    icon: "arrow.triangle.pull",
                    color: .teal
                )
            }
        }
    }

    // MARK: - Charts Section

    private var chartsSection: some View {
        VStack(spacing: 20) {
            // Cost Rate Chart (USD per unit time)
            ChartCard(title: "Cost Rate (USD/hour)") {
                if metricsService.dashboardData.costRateSeries.isEmpty {
                    emptyChartPlaceholder
                } else {
                    Chart(metricsService.dashboardData.costRateSeries) { point in
                        LineMark(
                            x: .value("Time", point.timestamp),
                            y: .value("Rate", point.value * 3600) // Convert to hourly rate
                        )
                        .foregroundStyle(.green.gradient)

                        AreaMark(
                            x: .value("Time", point.timestamp),
                            y: .value("Rate", point.value * 3600)
                        )
                        .foregroundStyle(.green.opacity(0.1).gradient)
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
                                    Text("$\(val, specifier: "%.4f")")
                                }
                            }
                        }
                    }
                }
            }

            // Cost Per Model Breakdown
            ChartCard(title: "Cost by Model") {
                if metricsService.dashboardData.costByModel.isEmpty {
                    emptyChartPlaceholder
                } else {
                    HStack(spacing: 20) {
                        // Pie Chart
                        Chart(Array(metricsService.dashboardData.costByModel), id: \.key) { item in
                            SectorMark(
                                angle: .value("Cost", item.value),
                                innerRadius: .ratio(0.5),
                                angularInset: 1.5
                            )
                            .foregroundStyle(by: .value("Model", shortModelName(item.key)))
                            .cornerRadius(4)
                        }
                        .chartLegend(position: .trailing, alignment: .center)
                        .frame(maxWidth: .infinity)

                        // Cost breakdown table
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(metricsService.dashboardData.costByModel.sorted { $0.value > $1.value }), id: \.key) { item in
                                HStack {
                                    Text(shortModelName(item.key))
                                        .font(.caption)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(DashboardData.formatCost(item.value))
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .frame(width: 180)
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
        // Shorten model names like "claude-sonnet-4-5-20250929" to "sonnet-4.5"
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
        // Return last part of model name if unknown format
        let parts = fullName.split(separator: "-")
        if parts.count > 1 {
            return String(parts.prefix(2).joined(separator: "-"))
        }
        return fullName
    }
}

// MARK: - KPI Card (Shared Component)

struct KPICard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)

            Text(value)
                .font(.system(.title, design: .rounded, weight: .semibold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Chart Card (Shared Component)

struct ChartCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            content
                .frame(height: 200)
        }
        .padding()
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#if DEBUG
struct SummaryDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        SummaryDashboardView(metricsService: MetricsService())
    }
}
#endif
