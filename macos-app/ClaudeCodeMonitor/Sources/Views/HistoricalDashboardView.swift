import SwiftUI
import Charts

// MARK: - Historical Dashboard View (Tab 3)
// Per spec: Graphical representation of `claude /stats` command output
// Uses its own time selector (same presets as global)
// Shows key /stats concepts as readable charts

struct HistoricalDashboardView: View {
    @ObservedObject var metricsService: MetricsService
    @State private var selectedPreset: TimeRangePreset = .last1Day
    @State private var customStartDate = Date().addingTimeInterval(-86400)
    @State private var customEndDate = Date()
    @State private var useCustomRange = false
    @State private var historicalData = DashboardData()
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 0) {
            timeRangePicker
            Divider()

            ScrollView {
                VStack(spacing: 24) {
                    dataSourceNote
                    overviewStatsSection
                    usageTrendsSection
                    productivitySection
                }
                .padding()
            }
        }
        .frame(minWidth: 600, minHeight: 500)
        .overlay {
            if isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
            }
        }
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

    // MARK: - Time Range Picker (Independent from global)

    private var timeRangePicker: some View {
        HStack(spacing: 16) {
            Text("Historical Range:")
                .foregroundStyle(.secondary)
                .fixedSize()

            Picker("Preset", selection: $selectedPreset) {
                ForEach(TimeRangePreset.allCases, id: \.self) { preset in
                    Text(preset.displayName).tag(preset)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 160)

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

            Button {
                refreshData()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Refresh data")
        }
        .padding()
        .background(.bar)
    }

    // MARK: - Data Source Note

    private var dataSourceNote: some View {
        HStack {
            Image(systemName: "info.circle")
                .foregroundStyle(.blue)
            Text("Historical data derived from Prometheus telemetry metrics. Equivalent to `claude /stats` command output.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(12)
        .background(.blue.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Overview Stats Section (like /stats summary)

    private var overviewStatsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Usage Overview")
                .font(.title2.bold())

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200))], spacing: 16) {
                StatCard(
                    title: "Total Cost",
                    value: historicalData.formattedCost,
                    subtitle: "in selected period",
                    icon: "dollarsign.circle.fill",
                    color: .green
                )

                StatCard(
                    title: "Total Tokens",
                    value: historicalData.formattedTokens,
                    subtitle: "processed",
                    icon: "number.circle.fill",
                    color: .blue
                )

                StatCard(
                    title: "Active Time",
                    value: historicalData.formattedActiveTime,
                    subtitle: "coding with Claude",
                    icon: "clock.fill",
                    color: .orange
                )

                StatCard(
                    title: "Sessions",
                    value: String(format: "%.0f", historicalData.sessionCount),
                    subtitle: "CLI sessions",
                    icon: "terminal.fill",
                    color: .purple
                )
            }
        }
    }

    // MARK: - Usage Trends Section

    private var usageTrendsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Usage Trends")
                .font(.title2.bold())

            HStack(spacing: 20) {
                // Token Trend Chart
                ChartCard(title: "Token Usage") {
                    if historicalData.tokensSeries.isEmpty {
                        emptyChartPlaceholder
                    } else {
                        Chart(historicalData.tokensSeries) { point in
                            BarMark(
                                x: .value("Time", point.timestamp, unit: chartUnit),
                                y: .value("Tokens", point.value)
                            )
                            .foregroundStyle(.blue.gradient)
                        }
                        .chartXAxis {
                            AxisMarks(values: .automatic) { _ in
                                AxisGridLine()
                                AxisValueLabel(format: selectedPreset.bucketGranularity.chartDateFormat)
                            }
                        }
                    }
                }

                // Cost Trend Chart
                ChartCard(title: "Cost") {
                    if historicalData.costSeries.isEmpty {
                        emptyChartPlaceholder
                    } else {
                        Chart(historicalData.costSeries) { point in
                            BarMark(
                                x: .value("Time", point.timestamp, unit: chartUnit),
                                y: .value("Cost", point.value)
                            )
                            .foregroundStyle(.green.gradient)
                        }
                        .chartXAxis {
                            AxisMarks(values: .automatic) { _ in
                                AxisGridLine()
                                AxisValueLabel(format: selectedPreset.bucketGranularity.chartDateFormat)
                            }
                        }
                        .chartYAxis {
                            AxisMarks { value in
                                AxisGridLine()
                                AxisValueLabel {
                                    if let val = value.as(Double.self) {
                                        Text("$\(val, specifier: "%.3f")")
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Model Distribution
            ChartCard(title: "Usage by Model") {
                if historicalData.modelBreakdown.isEmpty {
                    emptyChartPlaceholder
                } else {
                    HStack {
                        Chart(Array(historicalData.modelBreakdown), id: \.key) { item in
                            BarMark(
                                x: .value("Tokens", item.value),
                                y: .value("Model", shortModelName(item.key))
                            )
                            .foregroundStyle(by: .value("Model", shortModelName(item.key)))
                        }
                        .chartLegend(.hidden)
                        .frame(maxWidth: .infinity)

                        // Breakdown table
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(historicalData.modelBreakdown.sorted { $0.value > $1.value }), id: \.key) { item in
                                HStack {
                                    Text(shortModelName(item.key))
                                        .font(.caption)
                                    Spacer()
                                    Text(DashboardData.formatTokenCount(item.value))
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .frame(width: 150)
                    }
                }
            }
        }
    }

    // MARK: - Productivity Section (Lines of code, commits, PRs)

    private var productivitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Productivity")
                .font(.title2.bold())

            HStack(spacing: 20) {
                // Lines of Code Card
                VStack(alignment: .leading, spacing: 12) {
                    Text("Lines of Code")
                        .font(.headline)

                    HStack(spacing: 40) {
                        VStack {
                            Text("+\(Int(historicalData.linesAdded))")
                                .font(.system(.title, design: .rounded, weight: .bold))
                                .foregroundStyle(.green)
                            Text("Added")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        VStack {
                            Text("-\(Int(historicalData.linesRemoved))")
                                .font(.system(.title, design: .rounded, weight: .bold))
                                .foregroundStyle(.red)
                            Text("Removed")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        VStack {
                            let net = historicalData.linesAdded - historicalData.linesRemoved
                            Text("\(net >= 0 ? "+" : "")\(Int(net))")
                                .font(.system(.title, design: .rounded, weight: .bold))
                                .foregroundStyle(net >= 0 ? .blue : .orange)
                            Text("Net")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(.background.secondary)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Git Activity Card
                VStack(alignment: .leading, spacing: 12) {
                    Text("Git Activity")
                        .font(.headline)

                    HStack(spacing: 40) {
                        VStack {
                            Text("\(Int(historicalData.commitCount))")
                                .font(.system(.title, design: .rounded, weight: .bold))
                                .foregroundStyle(.indigo)
                            Text("Commits")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        VStack {
                            Text("\(Int(historicalData.prCount))")
                                .font(.system(.title, design: .rounded, weight: .bold))
                                .foregroundStyle(.teal)
                            Text("Pull Requests")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(.background.secondary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .frame(height: 150)
        }
    }

    // MARK: - Helpers

    private var emptyChartPlaceholder: some View {
        ContentUnavailableView {
            Label("No Data", systemImage: "chart.bar")
        } description: {
            Text("No historical data available")
        }
        .frame(height: 150)
    }

    private var chartUnit: Calendar.Component {
        switch selectedPreset.bucketGranularity {
        case .minutes: return .minute
        case .hours: return .hour
        case .days: return .day
        }
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

    private func refreshData() {
        isLoading = true
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
            await MainActor.run {
                historicalData = metricsService.dashboardData
                isLoading = false
            }
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
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
