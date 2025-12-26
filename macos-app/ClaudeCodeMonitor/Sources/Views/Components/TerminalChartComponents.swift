import SwiftUI
import Charts

// MARK: - Terminal Line Chart

/// Interactive line chart with hover tooltip and selection
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

/// Tooltip displayed on chart hover showing value at point
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

/// Row displaying model name, cost, and percentage bar
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

// MARK: - Terminal Token Type Card

/// Card displaying token type breakdown with percentage bar
struct TerminalTokenTypeCard: View {
    let type: String
    let value: Double
    let color: Color
    let icon: String
    let totalTokens: Double

    @State private var isHovered = false
    @State private var showCopied = false

    private var percentage: Double {
        guard totalTokens > 0 else { return 0 }
        return value / totalTokens
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Header
            HStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(color)
                    .phosphorGlow(color, intensity: 0.4, isActive: isHovered)

                Text(type.uppercased())
                    .font(.terminalCaptionSmall)
                    .foregroundStyle(Color.noirTextSecondary)
                    .tracking(0.5)
            }

            // Value
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                if showCopied {
                    Text("COPIED")
                        .font(.terminalCaptionSmall)
                        .foregroundStyle(Color.phosphorGreen)
                } else {
                    Text(DashboardData.formatTokenCount(value))
                        .font(.terminalValueSmall)
                        .foregroundStyle(Color.noirTextPrimary)
                        .phosphorGlow(color, intensity: isHovered ? 0.5 : 0.2, isActive: true)
                        .contentTransition(.numericText())
                }

                Text(String(format: "%.1f%%", percentage * 100))
                    .font(.terminalCaptionSmall)
                    .foregroundStyle(Color.noirTextTertiary)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.noirStroke)
                        .frame(height: 3)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(color.opacity(isHovered ? 1 : 0.7))
                        .frame(width: geometry.size.width * min(1.0, percentage), height: 3)
                        .phosphorGlow(color, intensity: 0.4, isActive: isHovered)
                }
            }
            .frame(height: 3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .fill(Color.noirSurface)
                .overlay {
                    if isHovered {
                        RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                            .fill(color.opacity(0.05))
                    }
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .strokeBorder(isHovered ? color.opacity(0.3) : Color.noirStroke, lineWidth: 1)
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onTapGesture(count: 2) {
            copyValue()
        }
        .contextMenu {
            Button(action: copyValue) {
                Label("Copy Value", systemImage: "doc.on.doc")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(type): \(DashboardData.formatTokenCount(value))")
    }

    private func copyValue() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(DashboardData.formatTokenCount(value), forType: .string)
        withAnimation { showCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showCopied = false }
        }
    }
}
