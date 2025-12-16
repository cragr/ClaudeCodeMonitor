import SwiftUI
import Charts

struct HistoricalDashboardView: View {
    @ObservedObject var metricsService: MetricsService
    @State private var selectedPreset: TimeRangePreset = .last24Hours
    @State private var customStartDate = Date().addingTimeInterval(-3600)
    @State private var customEndDate = Date()
    @State private var useCustomRange = false

    var body: some View {
        VStack(spacing: 0) {
            // Time Range Picker
            timeRangePicker

            Divider()

            // Content
            ScrollView {
                VStack(spacing: 24) {
                    summarySection
                    trendsSection
                }
                .padding()
            }
        }
        .frame(minWidth: 600, minHeight: 500)
        .onChange(of: selectedPreset) { _, newValue in
            if newValue != .custom {
                useCustomRange = false
                refreshData()
            }
        }
        .onAppear {
            refreshData()
        }
    }

    // MARK: - Time Range Picker

    private var timeRangePicker: some View {
        HStack(spacing: 16) {
            Text("Time Range:")
                .foregroundStyle(.secondary)
                .fixedSize()

            Picker("Preset", selection: $selectedPreset) {
                ForEach(TimeRangePreset.allCases, id: \.self) { preset in
                    Text(preset.displayName).tag(preset)
                }
            }
            .pickerStyle(.segmented)
            .fixedSize()

            if selectedPreset == .custom {
                DatePicker("From", selection: $customStartDate, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                DatePicker("To", selection: $customEndDate, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()

                Button("Apply") {
                    useCustomRange = true
                    refreshData()
                }
                .buttonStyle(.borderedProminent)
            }

            Spacer()
        }
        .padding()
        .background(.bar)
    }

    // MARK: - Summary Section

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Summary")
                .font(.title2.bold())

            HStack(spacing: 20) {
                SummaryStatCard(
                    title: "Total Tokens",
                    value: metricsService.dashboardData.formattedTokens,
                    subtitle: "in selected period",
                    color: .blue
                )

                SummaryStatCard(
                    title: "Total Cost",
                    value: metricsService.dashboardData.formattedCost,
                    subtitle: "USD spent",
                    color: .green
                )

                SummaryStatCard(
                    title: "Active Time",
                    value: metricsService.dashboardData.formattedActiveTime,
                    subtitle: "coding with Claude",
                    color: .orange
                )

                SummaryStatCard(
                    title: "Sessions",
                    value: String(format: "%.0f", metricsService.dashboardData.sessionCount),
                    subtitle: "CLI sessions",
                    color: .purple
                )
            }
        }
    }

    // MARK: - Trends Section

    private var trendsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Trends")
                .font(.title2.bold())

            // Token Trend
            ChartCard(title: "Token Usage Over Time") {
                if metricsService.dashboardData.tokensSeries.isEmpty {
                    emptyChartPlaceholder
                } else {
                    Chart(metricsService.dashboardData.tokensSeries) { point in
                        BarMark(
                            x: .value("Time", point.timestamp, unit: .hour),
                            y: .value("Tokens", point.value)
                        )
                        .foregroundStyle(.blue.gradient)
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic) { _ in
                            AxisGridLine()
                            AxisValueLabel(format: dateFormat)
                        }
                    }
                }
            }

            // Cost Trend
            ChartCard(title: "Cost Over Time") {
                if metricsService.dashboardData.costSeries.isEmpty {
                    emptyChartPlaceholder
                } else {
                    Chart(metricsService.dashboardData.costSeries) { point in
                        BarMark(
                            x: .value("Time", point.timestamp, unit: .hour),
                            y: .value("Cost", point.value)
                        )
                        .foregroundStyle(.green.gradient)
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic) { _ in
                            AxisGridLine()
                            AxisValueLabel(format: dateFormat)
                        }
                    }
                }
            }

            // Model Distribution
            HStack(spacing: 20) {
                ChartCard(title: "Usage by Model") {
                    if metricsService.dashboardData.modelBreakdown.isEmpty {
                        emptyChartPlaceholder
                    } else {
                        Chart(Array(metricsService.dashboardData.modelBreakdown), id: \.key) { item in
                            BarMark(
                                x: .value("Tokens", item.value),
                                y: .value("Model", item.key)
                            )
                            .foregroundStyle(by: .value("Model", item.key))
                        }
                        .chartLegend(.hidden)
                    }
                }

                ChartCard(title: "Lines of Code") {
                    linesOfCodeChart
                }
            }
        }
    }

    private var linesOfCodeChart: some View {
        VStack {
            HStack(spacing: 40) {
                VStack {
                    Text("+\(Int(metricsService.dashboardData.linesAdded))")
                        .font(.title.bold())
                        .foregroundStyle(.green)
                    Text("Added")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack {
                    Text("-\(Int(metricsService.dashboardData.linesRemoved))")
                        .font(.title.bold())
                        .foregroundStyle(.red)
                    Text("Removed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack {
                    let net = metricsService.dashboardData.linesAdded - metricsService.dashboardData.linesRemoved
                    Text("\(net >= 0 ? "+" : "")\(Int(net))")
                        .font(.title.bold())
                        .foregroundStyle(net >= 0 ? .blue : .orange)
                    Text("Net")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxHeight: .infinity)
        }
    }

    private var emptyChartPlaceholder: some View {
        ContentUnavailableView {
            Label("No Data", systemImage: "chart.bar")
        } description: {
            Text("No historical data available")
        }
        .frame(height: 150)
    }

    private var dateFormat: Date.FormatStyle {
        switch selectedPreset {
        case .last5Minutes, .last15Minutes, .last1Hour:
            return .dateTime.hour().minute()
        case .last24Hours:
            return .dateTime.hour()
        case .last7Days:
            return .dateTime.weekday(.abbreviated)
        case .last30Days, .custom:
            return .dateTime.month(.abbreviated).day()
        }
    }

    private func refreshData() {
        Task {
            if useCustomRange && selectedPreset == .custom {
                await metricsService.refreshDashboard(
                    timeRange: .custom,
                    customStart: customStartDate,
                    customEnd: customEndDate
                )
            } else {
                await metricsService.refreshDashboard(timeRange: selectedPreset)
            }
        }
    }
}

// MARK: - Summary Stat Card

struct SummaryStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(color)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#if DEBUG
struct HistoricalDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        HistoricalDashboardView(metricsService: MetricsService())
    }
}
#endif
