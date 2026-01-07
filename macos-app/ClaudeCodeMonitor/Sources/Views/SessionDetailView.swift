import SwiftUI
import Charts

// MARK: - Session Detail View

/// Detailed view for a single session showing metrics, token breakdowns, and charts
struct SessionDetailView: View {
    let session: SessionMetrics

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                // Summary Section
                summarySection

                Divider()
                    .background(Color.noirStroke)

                // Charts Section
                HStack(alignment: .top, spacing: Spacing.xl) {
                    tokensByTypeChart
                    tokensByModelChart
                }
            }
            .padding(Spacing.xl)
        }
        .background(Color.noirBackground)
        .navigationTitle("Session: \(session.truncatedSessionId)")
    }

    // MARK: - Summary Section

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            // Session Header with ID
            sessionIdHeader

            // Main Metrics Row
            HStack(spacing: Spacing.md) {
                SummaryMetric(
                    title: "Cost",
                    value: session.formattedCost,
                    icon: "dollarsign.circle",
                    color: .phosphorGreen
                )

                SummaryMetric(
                    title: "Tokens",
                    value: session.formattedTokens,
                    icon: "number.circle",
                    color: .phosphorCyan
                )

                SummaryMetric(
                    title: "Duration",
                    value: session.formattedActiveTime,
                    icon: "clock",
                    color: .phosphorAmber
                )
            }

            // Derived Metrics Row
            derivedMetricsRow
        }
    }

    // MARK: - Session ID Header

    private var sessionIdHeader: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Circle()
                    .fill(Color.phosphorOrange)
                    .frame(width: 8, height: 8)
                    .phosphorGlow(.phosphorOrange, intensity: 0.6, isActive: true)

                Text("SESSION DETAILS")
                    .font(.terminalCaptionSmall)
                    .foregroundStyle(Color.noirTextSecondary)
                    .tracking(2)
            }

            HStack(spacing: Spacing.md) {
                Text(session.sessionId)
                    .font(.terminalData)
                    .foregroundStyle(Color.noirTextPrimary)
                    .textSelection(.enabled)
                    .lineLimit(1)

                SessionIdCopyButton(sessionId: session.sessionId)
            }

            // Project Path
            if let projectPath = session.projectPath {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "folder")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.phosphorOrange)

                    Text(projectPath)
                        .font(.terminalCaption)
                        .foregroundStyle(Color.noirTextSecondary)
                        .textSelection(.enabled)
                        .lineLimit(1)

                    Button(action: { copyProjectPath(projectPath) }) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.noirTextTertiary)
                    }
                    .buttonStyle(.plain)
                    .help("Copy project path")
                }
            }
        }
    }

    private func copyProjectPath(_ path: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(path, forType: .string)
    }

    // MARK: - Derived Metrics Row

    private var derivedMetricsRow: some View {
        HStack(spacing: Spacing.md) {
            // Cost per Token
            DerivedMetric(
                label: "$/TOKEN",
                value: formattedCostPerToken
            )

            // Tokens per Minute
            DerivedMetric(
                label: "TOKENS/MIN",
                value: formattedTokensPerMinute
            )

            // Cost per Minute
            DerivedMetric(
                label: "$/MIN",
                value: formattedCostPerMinute
            )
        }
        .padding(Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .fill(Color.noirSurface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .strokeBorder(Color.noirStroke, lineWidth: 1)
        }
    }

    // MARK: - Tokens by Type Chart

    @ViewBuilder
    private var tokensByTypeChart: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            TerminalSectionHeader("Tokens by Type")

            if session.tokensByType.isEmpty {
                chartEmptyState(message: "No token type data available")
            } else {
                TokensByTypeBarChart(tokensByType: session.tokensByType)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Tokens by Model Chart

    @ViewBuilder
    private var tokensByModelChart: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            TerminalSectionHeader("Tokens by Model")

            if session.tokensByModel.isEmpty {
                chartEmptyState(message: "No model data available")
            } else {
                TokensByModelBarChart(tokensByModel: session.tokensByModel)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Empty State for Charts

    private func chartEmptyState(message: String) -> some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 24, weight: .thin))
                .foregroundStyle(Color.noirTextTertiary)

            Text(message)
                .font(.terminalCaptionSmall)
                .foregroundStyle(Color.noirTextTertiary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 150)
        .background {
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .fill(Color.noirSurface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .strokeBorder(Color.noirStroke, lineWidth: 1)
        }
    }

    // MARK: - Formatted Derived Metrics

    private var formattedCostPerToken: String {
        guard let costPerToken = session.costPerToken else { return "--" }
        if costPerToken >= 0.0001 {
            return String(format: "$%.4f", costPerToken)
        } else if costPerToken >= 0.00001 {
            return String(format: "$%.5f", costPerToken)
        }
        return String(format: "$%.6f", costPerToken)
    }

    private var formattedTokensPerMinute: String {
        guard let tokensPerMin = session.tokensPerMinute else { return "--" }
        if tokensPerMin >= 1000 {
            return String(format: "%.1fK", tokensPerMin / 1000)
        }
        return String(format: "%.0f", tokensPerMin)
    }

    private var formattedCostPerMinute: String {
        guard let costPerMin = session.costPerMinute else { return "--" }
        if costPerMin >= 0.01 {
            return String(format: "$%.2f", costPerMin)
        } else if costPerMin >= 0.001 {
            return String(format: "$%.3f", costPerMin)
        }
        return String(format: "$%.4f", costPerMin)
    }
}

// MARK: - Summary Metric Component

/// Main metric display card for the summary section
private struct SummaryMetric: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Header
            HStack(spacing: Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(color)
                    .phosphorGlow(color, intensity: 0.4, isActive: isHovered)

                Text(title.uppercased())
                    .font(.terminalCaptionSmall)
                    .foregroundStyle(Color.noirTextSecondary)
                    .tracking(1.2)
            }

            // Value
            Text(value)
                .font(.terminalValue)
                .foregroundStyle(Color.noirTextPrimary)
                .phosphorGlow(color, intensity: isHovered ? 0.6 : 0.3, isActive: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background {
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .fill(Color.noirSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [color.opacity(isHovered ? 0.08 : 0), .clear],
                                center: .top,
                                startRadius: 0,
                                endRadius: 150
                            )
                        )
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .strokeBorder(isHovered ? color.opacity(0.4) : Color.noirStroke, lineWidth: 1)
        }
        .onHover { hovering in
            withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

// MARK: - Derived Metric Component

/// Small metric display for derived values
private struct DerivedMetric: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(label)
                .font(.terminalCaptionSmall)
                .foregroundStyle(Color.noirTextTertiary)
                .tracking(1)

            Text(value)
                .font(.terminalData)
                .foregroundStyle(Color.noirTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Session ID Copy Button

/// Copy button for the full session ID
private struct SessionIdCopyButton: View {
    let sessionId: String
    @State private var showCopied = false

    var body: some View {
        Button(action: copySessionId) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 10, weight: .medium))

                Text(showCopied ? "COPIED" : "COPY")
                    .font(.terminalCaptionSmall)
                    .tracking(0.5)
            }
            .foregroundStyle(showCopied ? Color.phosphorGreen : Color.noirTextTertiary)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background {
                Capsule()
                    .fill(Color.noirSurface)
                    .overlay {
                        Capsule()
                            .strokeBorder(showCopied ? Color.phosphorGreen.opacity(0.4) : Color.noirStroke, lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Copy session ID")
    }

    private func copySessionId() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(sessionId, forType: .string)
        withAnimation { showCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showCopied = false }
        }
    }
}

// MARK: - Tokens by Type Bar Chart

/// Horizontal bar chart showing token distribution by type
private struct TokensByTypeBarChart: View {
    let tokensByType: [TokenType: Int]

    private var sortedData: [(type: TokenType, count: Int)] {
        tokensByType
            .map { (type: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    private var maxCount: Int {
        sortedData.map(\.count).max() ?? 1
    }

    private func color(for type: TokenType) -> Color {
        switch type {
        case .input: return .phosphorCyan
        case .output: return .phosphorGreen
        case .cacheRead: return .phosphorOrange
        case .cacheCreation: return .phosphorPurple
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ForEach(sortedData, id: \.type) { item in
                TokenTypeBarRow(
                    typeName: item.type.displayName,
                    count: item.count,
                    maxCount: maxCount,
                    color: color(for: item.type)
                )
            }
        }
        .padding(Spacing.lg)
        .background {
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .fill(Color.noirSurface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .strokeBorder(Color.noirStroke, lineWidth: 1)
        }
    }
}

// MARK: - Token Type Bar Row

/// Single row in the tokens by type chart
private struct TokenTypeBarRow: View {
    let typeName: String
    let count: Int
    let maxCount: Int
    let color: Color

    @State private var isHovered = false

    private var percentage: Double {
        guard maxCount > 0 else { return 0 }
        return Double(count) / Double(maxCount)
    }

    private var formattedCount: String {
        if count >= 1_000_000 {
            return String(format: "%.2fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                HStack(spacing: Spacing.sm) {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                        .phosphorGlow(color, intensity: 0.5, isActive: isHovered)

                    Text(typeName)
                        .font(.terminalCaption)
                        .foregroundStyle(Color.noirTextSecondary)
                }

                Spacer()

                Text(formattedCount)
                    .font(.terminalData)
                    .foregroundStyle(isHovered ? color : Color.noirTextPrimary)
                    .phosphorGlow(color, intensity: 0.3, isActive: isHovered)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.noirStroke)
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(color.opacity(isHovered ? 1 : 0.7))
                        .frame(width: geometry.size.width * percentage, height: 4)
                        .phosphorGlow(color, intensity: 0.4, isActive: isHovered)
                }
            }
            .frame(height: 4)
        }
        .padding(.vertical, Spacing.xs)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Tokens by Model Bar Chart

/// Horizontal bar chart showing token distribution by model
private struct TokensByModelBarChart: View {
    let tokensByModel: [String: Int]

    private var sortedData: [(model: String, count: Int)] {
        tokensByModel
            .map { (model: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    private var sortedModelNames: [String] {
        sortedData.map(\.model)
    }

    private var maxCount: Int {
        sortedData.map(\.count).max() ?? 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ForEach(sortedData, id: \.model) { item in
                ModelBarRow(
                    modelName: ModelFormatting.shortName(item.model),
                    fullName: item.model,
                    count: item.count,
                    maxCount: maxCount,
                    color: ModelFormatting.color(for: item.model, in: sortedModelNames)
                )
            }
        }
        .padding(Spacing.lg)
        .background {
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .fill(Color.noirSurface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .strokeBorder(Color.noirStroke, lineWidth: 1)
        }
    }
}

// MARK: - Model Bar Row

/// Single row in the tokens by model chart
private struct ModelBarRow: View {
    let modelName: String
    let fullName: String
    let count: Int
    let maxCount: Int
    let color: Color

    @State private var isHovered = false

    private var percentage: Double {
        guard maxCount > 0 else { return 0 }
        return Double(count) / Double(maxCount)
    }

    private var formattedCount: String {
        if count >= 1_000_000 {
            return String(format: "%.2fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                HStack(spacing: Spacing.sm) {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                        .phosphorGlow(color, intensity: 0.5, isActive: isHovered)

                    Text(modelName)
                        .font(.terminalCaption)
                        .foregroundStyle(Color.noirTextSecondary)
                        .help(fullName)
                }

                Spacer()

                Text(formattedCount)
                    .font(.terminalData)
                    .foregroundStyle(isHovered ? color : Color.noirTextPrimary)
                    .phosphorGlow(color, intensity: 0.3, isActive: isHovered)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.noirStroke)
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(color.opacity(isHovered ? 1 : 0.7))
                        .frame(width: geometry.size.width * percentage, height: 4)
                        .phosphorGlow(color, intensity: 0.4, isActive: isHovered)
                }
            }
            .frame(height: 4)
        }
        .padding(.vertical, Spacing.xs)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
struct SessionDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleSession = SessionMetrics(
            sessionId: "sess_abc123def456ghi789jkl012mno345pqr",
            totalCostUSD: Decimal(1.2345),
            totalTokens: 125_000,
            tokensByType: [
                .input: 50_000,
                .output: 45_000,
                .cacheRead: 25_000,
                .cacheCreation: 5_000
            ],
            tokensByModel: [
                "claude-3-5-sonnet-20241022": 80_000,
                "claude-3-5-haiku-20241022": 45_000
            ],
            activeTime: 3600,
            firstSeen: Date().addingTimeInterval(-7200),
            lastSeen: Date()
        )

        NavigationStack {
            SessionDetailView(session: sampleSession)
        }
        .frame(width: 700, height: 600)
    }
}
#endif
