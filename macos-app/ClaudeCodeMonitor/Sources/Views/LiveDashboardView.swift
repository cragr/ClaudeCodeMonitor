import SwiftUI
import Charts

struct LiveDashboardView: View {
    @ObservedObject var metricsService: MetricsService

    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // KPI Cards
                kpiCardsSection

                // Charts
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

    // MARK: - KPI Cards

    private var kpiCardsSection: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            KPICard(
                title: "Tokens",
                value: metricsService.dashboardData.formattedTokens,
                icon: "number.circle.fill",
                color: .blue
            )

            KPICard(
                title: "Cost",
                value: metricsService.dashboardData.formattedCost,
                icon: "dollarsign.circle.fill",
                color: .green
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
                value: String(format: "%.0f", metricsService.dashboardData.linesAdded),
                icon: "plus.circle.fill",
                color: .mint
            )

            KPICard(
                title: "Lines Removed",
                value: String(format: "%.0f", metricsService.dashboardData.linesRemoved),
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

    // MARK: - Charts Section

    private var chartsSection: some View {
        VStack(spacing: 20) {
            // Tokens Rate Chart
            ChartCard(title: "Token Rate (tokens/sec)") {
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
                            AxisValueLabel(format: .dateTime.hour().minute())
                        }
                    }
                }
            }

            // Cost Rate Chart
            ChartCard(title: "Cost Rate ($/hour)") {
                if metricsService.dashboardData.costSeries.isEmpty {
                    emptyChartPlaceholder
                } else {
                    Chart(metricsService.dashboardData.costSeries) { point in
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
                            AxisValueLabel(format: .dateTime.hour().minute())
                        }
                    }
                }
            }

            // Model Breakdown
            ChartCard(title: "Token Usage by Model") {
                if metricsService.dashboardData.modelBreakdown.isEmpty {
                    emptyChartPlaceholder
                } else {
                    Chart(Array(metricsService.dashboardData.modelBreakdown), id: \.key) { item in
                        SectorMark(
                            angle: .value("Tokens", item.value),
                            innerRadius: .ratio(0.5),
                            angularInset: 1.5
                        )
                        .foregroundStyle(by: .value("Model", item.key))
                        .cornerRadius(4)
                    }
                    .chartLegend(position: .trailing)
                }
            }
        }
    }

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
}

// MARK: - KPI Card

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

// MARK: - Chart Card

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
struct LiveDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        LiveDashboardView(metricsService: MetricsService())
    }
}
#endif
