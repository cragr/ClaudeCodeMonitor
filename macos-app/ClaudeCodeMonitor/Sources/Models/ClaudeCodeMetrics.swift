import Foundation

// MARK: - Claude Code Metric Names

enum ClaudeCodeMetric: String, CaseIterable {
    case sessionCount = "claude_code_session_count"
    case linesOfCode = "claude_code_lines_of_code_count"
    case pullRequestCount = "claude_code_pull_request_count"
    case commitCount = "claude_code_commit_count"
    case costUsage = "claude_code_cost_usage"
    case tokenUsage = "claude_code_token_usage"
    case codeEditDecision = "claude_code_code_edit_tool_decision"
    case activeTime = "claude_code_active_time"

    // Map actual Prometheus metric names to our canonical names
    static let prometheusVariants: [String: ClaudeCodeMetric] = [
        // With _total suffix (counters)
        "claude_code_session_count_total": .sessionCount,
        "claude_code_lines_of_code_count_total": .linesOfCode,
        "claude_code_pull_request_count_total": .pullRequestCount,
        "claude_code_commit_count_total": .commitCount,
        "claude_code_cost_usage_USD_total": .costUsage,
        "claude_code_token_usage_tokens_total": .tokenUsage,
        "claude_code_code_edit_tool_decision_total": .codeEditDecision,
        "claude_code_active_time_seconds_total": .activeTime,
        "claude_code_active_time_total": .activeTime,
        // Dot notation variants
        "claude_code.session.count": .sessionCount,
        "claude_code.lines_of_code.count": .linesOfCode,
        "claude_code.pull_request.count": .pullRequestCount,
        "claude_code.commit.count": .commitCount,
        "claude_code.cost.usage": .costUsage,
        "claude_code.token.usage": .tokenUsage,
        "claude_code.code_edit_tool.decision": .codeEditDecision,
        "claude_code.active_time.total": .activeTime
    ]

    var displayName: String {
        switch self {
        case .sessionCount: return "Sessions"
        case .linesOfCode: return "Lines of Code"
        case .pullRequestCount: return "Pull Requests"
        case .commitCount: return "Commits"
        case .costUsage: return "Cost (USD)"
        case .tokenUsage: return "Tokens"
        case .codeEditDecision: return "Code Edit Decisions"
        case .activeTime: return "Active Time"
        }
    }

    var unit: String {
        switch self {
        case .costUsage: return "USD"
        case .tokenUsage: return "tokens"
        case .activeTime: return "seconds"
        default: return "count"
        }
    }

    var iconName: String {
        switch self {
        case .sessionCount: return "terminal"
        case .linesOfCode: return "text.alignleft"
        case .pullRequestCount: return "arrow.triangle.pull"
        case .commitCount: return "checkmark.circle"
        case .costUsage: return "dollarsign.circle"
        case .tokenUsage: return "number.circle"
        case .codeEditDecision: return "pencil.circle"
        case .activeTime: return "clock"
        }
    }

    // Normalize metric name from Prometheus format
    static func normalize(_ name: String) -> ClaudeCodeMetric? {
        // Try direct match first
        if let metric = ClaudeCodeMetric(rawValue: name) {
            return metric
        }
        // Try prometheus variants (includes _total suffixes and dot notation)
        if let metric = prometheusVariants[name] {
            return metric
        }
        // Try converting dots to underscores
        let underscored = name.replacingOccurrences(of: ".", with: "_")
        if let metric = ClaudeCodeMetric(rawValue: underscored) {
            return metric
        }
        // Try again with prometheus variants after converting dots
        return prometheusVariants[underscored]
    }

    // All possible metric name patterns to search for
    var searchPatterns: [String] {
        let base = rawValue
        let dotted = rawValue.replacingOccurrences(of: "_", with: ".")
        // Also try with _total suffix for counters
        return [base, dotted, "\(base)_total", "\(dotted)_total"]
    }
}

// MARK: - Common Labels

enum ClaudeCodeLabel: String {
    case sessionId = "session_id"
    case accountUuid = "user_account_uuid"
    case organizationId = "organization_id"
    case terminalType = "terminal_type"
    case appVersion = "app_version"
    case model = "model"
    case type = "type"  // For lines_of_code: added/removed
    case decision = "decision"  // For code_edit_tool

    // Dot notation alternatives
    static let dotVariants: [String: ClaudeCodeLabel] = [
        "session.id": .sessionId,
        "user.account_uuid": .accountUuid,
        "organization.id": .organizationId,
        "terminal.type": .terminalType,
        "app.version": .appVersion
    ]

    static func normalize(_ name: String) -> ClaudeCodeLabel? {
        if let label = ClaudeCodeLabel(rawValue: name) {
            return label
        }
        if let label = dotVariants[name] {
            return label
        }
        let underscored = name.replacingOccurrences(of: ".", with: "_")
        return ClaudeCodeLabel(rawValue: underscored)
    }
}

// MARK: - Domain Models

struct MetricDataPoint: Identifiable {
    let id = UUID()
    let timestamp: Date
    let value: Double
    let labels: [String: String]

    var model: String? {
        labels[ClaudeCodeLabel.model.rawValue] ?? labels["model"]
    }

    var type: String? {
        labels[ClaudeCodeLabel.type.rawValue] ?? labels["type"]
    }
}

struct MetricSeries: Identifiable {
    let id = UUID()
    let metricName: String
    let labels: [String: String]
    var dataPoints: [MetricDataPoint]

    var latestValue: Double? {
        dataPoints.last?.value
    }

    var totalValue: Double {
        dataPoints.reduce(0) { $0 + $1.value }
    }
}

// MARK: - Token Type (from docs: input, output, cacheRead, cacheCreation)

enum TokenType: String, CaseIterable {
    case input
    case output
    case cacheRead
    case cacheCreation

    var displayName: String {
        switch self {
        case .input: return "Input"
        case .output: return "Output"
        case .cacheRead: return "Cache Read"
        case .cacheCreation: return "Cache Creation"
        }
    }

    var color: String {
        switch self {
        case .input: return "blue"
        case .output: return "green"
        case .cacheRead: return "orange"
        case .cacheCreation: return "purple"
        }
    }
}

// MARK: - Dashboard Data

struct DashboardData {
    // MARK: - Summary KPIs (Tab 1)
    var totalTokens: Double = 0
    var totalCost: Double = 0
    var totalActiveTime: Double = 0
    var sessionCount: Double = 0
    var linesAdded: Double = 0
    var linesRemoved: Double = 0
    var commitCount: Double = 0
    var prCount: Double = 0

    // MARK: - Summary Charts (Tab 1)
    var costRateSeries: [MetricDataPoint] = []       // Cost rate over time (USD per unit time)
    var costByModel: [String: Double] = [:]          // Cost breakdown by model

    // MARK: - Performance Data (Tab 2)
    var tokensSeries: [MetricDataPoint] = []         // Total tokens time series
    var tokensByModelSeries: [ModelSeriesData] = []  // Tokens by model time series
    var tokensByTypeSeries: [TypeSeriesData] = []    // Tokens by type time series
    var tokensByType: [String: Double] = [:]         // Token totals by type (input/output/cache)

    // MARK: - Legacy / Shared
    var costSeries: [MetricDataPoint] = []
    var activeTimeSeries: [MetricDataPoint] = []
    var modelBreakdown: [String: Double] = [:]       // Token breakdown by model (for pie charts)
    var linesAddedSeries: [MetricDataPoint] = []
    var linesRemovedSeries: [MetricDataPoint] = []

    // MARK: - Formatted Values

    var formattedCost: String {
        if totalCost >= 1.0 {
            return String(format: "$%.2f", totalCost)
        } else if totalCost >= 0.01 {
            return String(format: "$%.3f", totalCost)
        }
        return String(format: "$%.4f", totalCost)
    }

    var formattedActiveTime: String {
        let hours = Int(totalActiveTime) / 3600
        let minutes = (Int(totalActiveTime) % 3600) / 60
        let seconds = Int(totalActiveTime) % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }

    var formattedTokens: String {
        if totalTokens >= 1_000_000 {
            return String(format: "%.2fM", totalTokens / 1_000_000)
        } else if totalTokens >= 1_000 {
            return String(format: "%.1fK", totalTokens / 1_000)
        }
        return String(format: "%.0f", totalTokens)
    }

    static func formatTokenCount(_ count: Double) -> String {
        if count >= 1_000_000 {
            return String(format: "%.2fM", count / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", count / 1_000)
        }
        return String(format: "%.0f", count)
    }

    static func formatCost(_ cost: Double) -> String {
        if cost >= 1.0 {
            return String(format: "$%.2f", cost)
        } else if cost >= 0.01 {
            return String(format: "$%.3f", cost)
        }
        return String(format: "$%.4f", cost)
    }
}

// MARK: - Series Data Types for Grouped Charts

struct ModelSeriesData: Identifiable {
    let id = UUID()
    let model: String
    var dataPoints: [MetricDataPoint]
}

struct TypeSeriesData: Identifiable {
    let id = UUID()
    let tokenType: String
    var dataPoints: [MetricDataPoint]
}

// MARK: - Connection Status

enum ConnectionStatus: Equatable {
    case unknown
    case connecting
    case connected(version: String)
    case disconnected(error: String)

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    var displayText: String {
        switch self {
        case .unknown: return "Unknown"
        case .connecting: return "Connecting..."
        case .connected(let version): return "Connected (v\(version))"
        case .disconnected(let error): return "Disconnected: \(error)"
        }
    }
}
