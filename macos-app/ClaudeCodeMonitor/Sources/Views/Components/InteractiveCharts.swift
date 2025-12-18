import SwiftUI
import Charts
import UniformTypeIdentifiers

// MARK: - Interactive Line Chart

struct InteractiveLineChart: View {
    let data: [MetricDataPoint]
    let title: String
    let color: Color
    let valueFormatter: (Double) -> String
    let yAxisLabel: String

    @State private var selectedPoint: MetricDataPoint?
    @State private var tooltipPosition: CGPoint = .zero
    @State private var showTooltip = false

    var body: some View {
        chartContent
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
                    ChartTooltip(
                        title: formatDate(point.timestamp),
                        value: valueFormatter(point.value),
                        color: color
                    )
                    .offset(x: max(10, min(tooltipPosition.x - 60, 200)), y: max(10, tooltipPosition.y - 70))
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .contextMenu {
                chartContextMenu
            }
    }

    private var chartContent: some View {
        Chart(data) { point in
            LineMark(
                x: .value("Time", point.timestamp),
                y: .value("Value", point.value)
            )
            .foregroundStyle(
                .linearGradient(
                    colors: [color, color.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

            AreaMark(
                x: .value("Time", point.timestamp),
                y: .value("Value", point.value)
            )
            .foregroundStyle(
                .linearGradient(
                    colors: [color.opacity(0.2), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            // Selection indicator
            if let selected = selectedPoint, selected.id == point.id {
                RuleMark(x: .value("Selected", selected.timestamp))
                    .foregroundStyle(color.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 2]))

                PointMark(
                    x: .value("Time", selected.timestamp),
                    y: .value("Value", selected.value)
                )
                .foregroundStyle(color)
                .symbolSize(80)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2]))
                    .foregroundStyle(.quaternary)
                AxisValueLabel()
                    .font(.caption)
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2]))
                    .foregroundStyle(.quaternary)
                AxisValueLabel {
                    if let val = value.as(Double.self) {
                        Text(valueFormatter(val))
                            .font(.caption)
                    }
                }
            }
        }
        .chartPlotStyle { content in
            content
                .background(Color.gray.opacity(0.02))
                .border(Color.gray.opacity(0.1), width: 0.5)
        }
        .frame(height: .chartHeightStandard)
    }

    @ViewBuilder
    private var chartContextMenu: some View {
        Button(action: copyDataToClipboard) {
            Label("Copy Data", systemImage: "doc.on.doc")
        }

        Button(action: exportAsCSV) {
            Label("Export as CSV", systemImage: "square.and.arrow.up")
        }

        Divider()

        if let point = selectedPoint {
            Text("Selected: \(formatDate(point.timestamp))")
            Text("Value: \(valueFormatter(point.value))")
        }
    }

    private func updateSelection(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        guard let plotFrame = proxy.plotFrame else { return }
        let xPosition = location.x - geometry[plotFrame].origin.x

        if let date: Date = proxy.value(atX: xPosition) {
            // Find closest point
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

    private func copyDataToClipboard() {
        let text = data.map { "\(formatDate($0.timestamp))\t\(valueFormatter($0.value))" }.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func exportAsCSV() {
        let csv = "Timestamp,Value\n" + data.map { "\(ISO8601DateFormatter().string(from: $0.timestamp)),\($0.value)" }.joined(separator: "\n")

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [UTType.commaSeparatedText]
        savePanel.nameFieldStringValue = "\(title.replacingOccurrences(of: " ", with: "_")).csv"

        if savePanel.runModal() == .OK, let url = savePanel.url {
            try? csv.write(to: url, atomically: true, encoding: String.Encoding.utf8)
        }
    }
}

// MARK: - Chart Tooltip

struct ChartTooltip: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                Text(value)
                    .font(.system(.caption, design: .monospaced, weight: .semibold))
            }
        }
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(color.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }
}

// MARK: - Interactive KPI Card with Copy & Actions

struct InteractiveKPICard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let subtitle: String?
    let trend: TrendDirection?

    @State private var isHovered = false
    @State private var showCopied = false

    enum TrendDirection {
        case up, down, neutral

        var icon: String {
            switch self {
            case .up: return "arrow.up.right"
            case .down: return "arrow.down.right"
            case .neutral: return "arrow.right"
            }
        }

        var color: Color {
            switch self {
            case .up: return .green
            case .down: return .red
            case .neutral: return .secondary
            }
        }
    }

    init(title: String, value: String, icon: String, color: Color, subtitle: String? = nil, trend: TrendDirection? = nil) {
        self.title = title
        self.value = value
        self.icon = icon
        self.color = color
        self.subtitle = subtitle
        self.trend = trend
    }

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(value)
                        .font(.metricValue)
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())

                    if let trend = trend {
                        Image(systemName: trend.icon)
                            .font(.caption)
                            .foregroundStyle(trend.color)
                    }
                }

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                if showCopied {
                    Text("Copied!")
                        .font(.caption2)
                        .foregroundStyle(.green)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
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
        .contextMenu {
            Button(action: copyValue) {
                Label("Copy Value", systemImage: "doc.on.doc")
            }

            Button(action: copyWithLabel) {
                Label("Copy with Label", systemImage: "doc.on.doc.fill")
            }
        }
        .onTapGesture(count: 2) {
            copyValue()
        }
        .help("Double-click to copy, right-click for more options")
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

    private func copyWithLabel() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("\(title): \(value)", forType: .string)

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

// MARK: - Interactive Chart Card with Export

struct InteractiveChartCard<Content: View>: View {
    let title: String
    let onExport: (() -> Void)?
    let onShare: (() -> Void)?
    @ViewBuilder let content: Content

    @State private var isHovered = false

    init(title: String, onExport: (() -> Void)? = nil, onShare: (() -> Void)? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.onExport = onExport
        self.onShare = onShare
        self.content = content()
    }

    var body: some View {
        GroupBox {
            content
        } label: {
            HStack {
                Text(title)
                    .font(.chartTitle)

                Spacer()

                if isHovered {
                    HStack(spacing: 8) {
                        if let onExport = onExport {
                            Button(action: onExport) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                            .help("Export data")
                        }

                        Menu {
                            if let onExport = onExport {
                                Button(action: onExport) {
                                    Label("Export as CSV", systemImage: "tablecells")
                                }
                            }

                            if let onShare = onShare {
                                Button(action: onShare) {
                                    Label("Share", systemImage: "square.and.arrow.up")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.caption)
                        }
                        .menuStyle(.borderlessButton)
                        .frame(width: 20)
                    }
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
        }
        .groupBoxStyle(ChartGroupBoxStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Export Helpers

struct ChartExportManager {
    static func exportToCSV(title: String, data: [(String, String)]) {
        let csv = data.map { "\($0.0),\($0.1)" }.joined(separator: "\n")
        let header = "Label,Value\n"

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [UTType.commaSeparatedText]
        savePanel.nameFieldStringValue = "\(title.replacingOccurrences(of: " ", with: "_")).csv"

        if savePanel.runModal() == .OK, let url = savePanel.url {
            try? (header + csv).write(to: url, atomically: true, encoding: .utf8)
        }
    }

    static func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    static func shareData(title: String, data: String) {
        let picker = NSSharingServicePicker(items: ["\(title)\n\n\(data)"])
        if let window = NSApp.keyWindow, let contentView = window.contentView {
            picker.show(relativeTo: .zero, of: contentView, preferredEdge: .minY)
        }
    }
}

// MARK: - Metric Summary View (for sharing/exporting all metrics)

struct MetricsSummaryExporter {
    let dashboardData: DashboardData
    let timeRange: String

    func generateSummary() -> String {
        """
        Claude Code Monitor - Metrics Summary
        Time Range: \(timeRange)
        Generated: \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short))

        === Usage Metrics ===
        Total Cost: \(dashboardData.formattedCost)
        Total Tokens: \(dashboardData.formattedTokens)
        Active Time: \(dashboardData.formattedActiveTime)
        Sessions: \(Int(dashboardData.sessionCount))

        === Code Metrics ===
        Lines Added: +\(Int(dashboardData.linesAdded))
        Lines Removed: -\(Int(dashboardData.linesRemoved))
        Net Lines: \(Int(dashboardData.linesAdded - dashboardData.linesRemoved))
        Commits: \(Int(dashboardData.commitCount))
        Pull Requests: \(Int(dashboardData.prCount))

        === Cost by Model ===
        \(dashboardData.costByModel.map { "\($0.key): \(DashboardData.formatCost($0.value))" }.joined(separator: "\n"))
        """
    }

    func copyToClipboard() {
        ChartExportManager.copyToClipboard(generateSummary())
    }

    func exportToFile() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [UTType.plainText]
        savePanel.nameFieldStringValue = "claude_code_metrics_\(timeRange.replacingOccurrences(of: " ", with: "_")).txt"

        if savePanel.runModal() == .OK, let url = savePanel.url {
            try? generateSummary().write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
