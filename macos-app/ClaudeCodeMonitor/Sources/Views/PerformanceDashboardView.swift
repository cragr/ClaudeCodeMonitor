import SwiftUI
import Charts

// MARK: - Performance Dashboard View (Tab 2)
// Token metrics with Terminal Noir aesthetic

struct PerformanceDashboardView: View {
    @ObservedObject var metricsService: MetricsService
    @State private var appearAnimation = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                tokenBreakdownSection
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 10)

                tokenTimeSeriesSection
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 15)

                tokensByModelSection
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 20)

                tokensByTypeSection
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 25)
            }
            .padding(Spacing.xl)
        }
        .frame(minWidth: 600, minHeight: 500)
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
            withAnimation(reduceMotion ? .none : .easeOut(duration: 0.6)) {
                appearAnimation = true
            }
        }
    }

    // MARK: - Token Breakdown Section (Compact summary)

    private var tokenBreakdownSection: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            // Header with total
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    HStack(spacing: Spacing.sm) {
                        Circle()
                            .fill(Color.phosphorCyan)
                            .frame(width: 8, height: 8)
                            .phosphorGlow(.phosphorCyan, intensity: 0.6, isActive: true)

                        Text("TOKEN BREAKDOWN")
                            .font(.terminalCaptionSmall)
                            .foregroundStyle(Color.noirTextSecondary)
                            .tracking(2)
                    }

                    Text(metricsService.dashboardData.formattedTokens)
                        .font(.terminalDisplayMedium)
                        .foregroundStyle(Color.noirTextPrimary)
                        .phosphorGlow(.phosphorCyan, intensity: 0.3, isActive: true)
                        .contentTransition(.numericText())
                }

                Spacer()

                Text(metricsService.currentTimeRange.displayName)
                    .font(.terminalCaption)
                    .foregroundStyle(Color.noirTextTertiary)
            }
            .padding(Spacing.lg)
            .background {
                RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                    .fill(Color.noirSurface)
                    .overlay {
                        RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.phosphorCyan.opacity(0.06), .clear],
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

            // Token type cards
            HStack(spacing: Spacing.md) {
                TerminalTokenTypeCard(
                    type: "Input",
                    value: metricsService.dashboardData.tokensByType["input"] ?? 0,
                    color: .phosphorCyan,
                    icon: "arrow.right.circle.fill",
                    totalTokens: totalTokens
                )

                TerminalTokenTypeCard(
                    type: "Output",
                    value: metricsService.dashboardData.tokensByType["output"] ?? 0,
                    color: .phosphorGreen,
                    icon: "arrow.left.circle.fill",
                    totalTokens: totalTokens
                )

                TerminalTokenTypeCard(
                    type: "Cache Read",
                    value: metricsService.dashboardData.tokensByType["cacheRead"] ?? 0,
                    color: .phosphorOrange,
                    icon: "arrow.triangle.2.circlepath.circle.fill",
                    totalTokens: totalTokens
                )

                TerminalTokenTypeCard(
                    type: "Cache Create",
                    value: metricsService.dashboardData.tokensByType["cacheCreation"] ?? 0,
                    color: .phosphorPurple,
                    icon: "plus.circle.fill",
                    totalTokens: totalTokens
                )
            }
        }
    }

    private var totalTokens: Double {
        let data = metricsService.dashboardData.tokensByType
        let input: Double = data["input"] ?? 0
        let output: Double = data["output"] ?? 0
        let cacheRead: Double = data["cacheRead"] ?? 0
        let cacheCreation: Double = data["cacheCreation"] ?? 0
        return input + output + cacheRead + cacheCreation
    }

    // MARK: - Total Tokens Time Series

    private var tokenTimeSeriesSection: some View {
        TerminalChartCard(
            title: "Total Tokens Over Time",
            subtitle: metricsService.currentTimeRange.displayName,
            onExport: nil
        ) {
            if metricsService.dashboardData.tokensSeries.isEmpty {
                TerminalEmptyState(
                    title: "No Data",
                    message: "No token metrics available for this time range",
                    icon: "chart.line.downtrend.xyaxis"
                )
            } else {
                TerminalLineChart(
                    data: metricsService.dashboardData.tokensSeries,
                    color: .phosphorCyan,
                    valueFormatter: { DashboardData.formatTokenCount($0) }
                )
            }
        }
    }

    // MARK: - Tokens by Model (Multi-line)

    private var tokensByModelSection: some View {
        TerminalChartCard(
            title: "Tokens by Model",
            subtitle: "comparison",
            onExport: nil
        ) {
            if metricsService.dashboardData.tokensByModelSeries.isEmpty {
                TerminalEmptyState(
                    title: "No Data",
                    message: "No model breakdown available",
                    icon: "cpu"
                )
            } else {
                Chart {
                    ForEach(metricsService.dashboardData.tokensByModelSeries) { modelSeries in
                        let modelName = ModelFormatting.shortName(modelSeries.model)
                        ForEach(modelSeries.dataPoints) { point in
                            LineMark(
                                x: .value("Time", point.timestamp),
                                y: .value("Tokens", point.value),
                                series: .value("Model", modelName)
                            )
                            .foregroundStyle(by: .value("Model", modelName))
                            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                            .interpolationMethod(.catmullRom)
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color.noirStroke)
                        AxisValueLabel(format: metricsService.currentTimeRange.bucketGranularity.chartDateFormat)
                            .font(.terminalDataSmall)
                            .foregroundStyle(Color.noirTextTertiary)
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
                .chartForegroundStyleScale(modelColorMapping())
                .chartLegend(position: .bottom, alignment: .center, spacing: Spacing.md)
                .chartPlotStyle { content in
                    content
                        .background(Color.noirBackground.opacity(0.3))
                }
                .frame(height: 220)
            }
        }
    }

    private func modelColorMapping() -> KeyValuePairs<String, Color> {
        let modelNames = metricsService.dashboardData.tokensByModelSeries.map { ModelFormatting.shortName($0.model) }
        let palette = ModelFormatting.colorPalette

        // Build KeyValuePairs dynamically based on actual models
        switch modelNames.count {
        case 0:
            return [:]
        case 1:
            return [modelNames[0]: palette[0]]
        case 2:
            return [
                modelNames[0]: palette[0],
                modelNames[1]: palette[1]
            ]
        case 3:
            return [
                modelNames[0]: palette[0],
                modelNames[1]: palette[1],
                modelNames[2]: palette[2]
            ]
        case 4:
            return [
                modelNames[0]: palette[0],
                modelNames[1]: palette[1],
                modelNames[2]: palette[2],
                modelNames[3]: palette[3]
            ]
        case 5:
            return [
                modelNames[0]: palette[0],
                modelNames[1]: palette[1],
                modelNames[2]: palette[2],
                modelNames[3]: palette[3],
                modelNames[4]: palette[4]
            ]
        default:
            return [
                modelNames[0]: palette[0],
                modelNames[1]: palette[1],
                modelNames[2]: palette[2],
                modelNames[3]: palette[3],
                modelNames[4]: palette[4],
                modelNames[5]: palette[5]
            ]
        }
    }

    // MARK: - Tokens by Type (Stacked Area)

    private var tokensByTypeSection: some View {
        TerminalChartCard(
            title: "Tokens by Type",
            subtitle: "stacked view",
            onExport: nil
        ) {
            if metricsService.dashboardData.tokensByTypeSeries.isEmpty {
                TerminalEmptyState(
                    title: "No Data",
                    message: "No token type breakdown available",
                    icon: "square.stack.3d.up"
                )
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
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color.noirStroke)
                        AxisValueLabel(format: metricsService.currentTimeRange.bucketGranularity.chartDateFormat)
                            .font(.terminalDataSmall)
                            .foregroundStyle(Color.noirTextTertiary)
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
                .chartLegend(position: .bottom, alignment: .center)
                .chartForegroundStyleScale([
                    "Input": Color.phosphorCyan,
                    "Output": Color.phosphorGreen,
                    "Cache Read": Color.phosphorOrange,
                    "Cache Creation": Color.phosphorPurple
                ])
                .chartPlotStyle { content in
                    content
                        .background(Color.noirBackground.opacity(0.3))
                }
                .frame(height: 200)
            }
        }
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

    private var sortedModelNames: [String] {
        metricsService.dashboardData.tokensByModelSeries.map { ModelFormatting.shortName($0.model) }
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

#if DEBUG
struct PerformanceDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        PerformanceDashboardView(metricsService: MetricsService())
    }
}
#endif
