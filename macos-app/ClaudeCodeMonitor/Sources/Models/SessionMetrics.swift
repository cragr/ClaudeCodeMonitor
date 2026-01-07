import Foundation

/// Aggregated metrics for a single Claude Code session
struct SessionMetrics: Identifiable, Hashable {
    let sessionId: String
    var totalCostUSD: Decimal
    var totalTokens: Int
    var tokensByType: [TokenType: Int]
    var tokensByModel: [String: Int]
    var activeTime: TimeInterval
    var firstSeen: Date?
    var lastSeen: Date?
    var projectPath: String?

    var id: String { sessionId }

    /// Project name (last path component) for display
    var projectName: String? {
        guard let path = projectPath else { return nil }
        return (path as NSString).lastPathComponent
    }

    // MARK: - Hashable Conformance

    func hash(into hasher: inout Hasher) {
        hasher.combine(sessionId)
    }

    static func == (lhs: SessionMetrics, rhs: SessionMetrics) -> Bool {
        lhs.sessionId == rhs.sessionId
    }
}

// MARK: - Derived Properties

extension SessionMetrics {
    /// Cost per token in USD, nil if no tokens
    var costPerToken: Double? {
        guard totalTokens > 0 else { return nil }
        let cost = (totalCostUSD as NSDecimalNumber).doubleValue
        return cost / Double(totalTokens)
    }

    /// Cost per minute of active time in USD, nil if no active time
    var costPerMinute: Double? {
        guard activeTime > 0 else { return nil }
        let cost = (totalCostUSD as NSDecimalNumber).doubleValue
        return cost / (activeTime / 60.0)
    }

    /// Tokens consumed per minute of active time, nil if no active time
    var tokensPerMinute: Double? {
        guard activeTime > 0 else { return nil }
        return Double(totalTokens) / (activeTime / 60.0)
    }
}

// MARK: - Formatting Helpers

extension SessionMetrics {
    /// Formatted cost string (e.g., "$1.23" or "$0.0045")
    var formattedCost: String {
        let cost = (totalCostUSD as NSDecimalNumber).doubleValue
        if cost >= 1.0 {
            return String(format: "$%.2f", cost)
        } else if cost >= 0.01 {
            return String(format: "$%.3f", cost)
        }
        return String(format: "$%.4f", cost)
    }

    /// Formatted token count (e.g., "1.2M", "890K", "500")
    var formattedTokens: String {
        if totalTokens >= 1_000_000 {
            return String(format: "%.2fM", Double(totalTokens) / 1_000_000)
        } else if totalTokens >= 1_000 {
            return String(format: "%.1fK", Double(totalTokens) / 1_000)
        }
        return "\(totalTokens)"
    }

    /// Formatted active time (e.g., "2h 15m", "45m 30s")
    var formattedActiveTime: String {
        let hours = Int(activeTime) / 3600
        let minutes = (Int(activeTime) % 3600) / 60
        let seconds = Int(activeTime) % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }

    /// Truncated session ID for display (e.g., "sess_abc...xyz")
    var truncatedSessionId: String {
        if sessionId.count <= 16 {
            return sessionId
        }
        let prefix = sessionId.prefix(8)
        let suffix = sessionId.suffix(4)
        return "\(prefix)...\(suffix)"
    }
}

// MARK: - Project Cost Summary

/// Aggregated cost summary for a project
struct ProjectCostSummary: Identifiable {
    let projectPath: String
    let totalCostUSD: Decimal
    let totalTokens: Int
    let sessionCount: Int
    let totalActiveTime: TimeInterval

    var id: String { projectPath }

    /// Project name (last path component)
    var projectName: String {
        if projectPath == "Unknown" { return "Unknown" }
        return (projectPath as NSString).lastPathComponent
    }

    /// Formatted cost string
    var formattedCost: String {
        let cost = (totalCostUSD as NSDecimalNumber).doubleValue
        if cost >= 1.0 {
            return String(format: "$%.2f", cost)
        } else if cost >= 0.01 {
            return String(format: "$%.3f", cost)
        }
        return String(format: "$%.4f", cost)
    }

    /// Formatted token count
    var formattedTokens: String {
        if totalTokens >= 1_000_000 {
            return String(format: "%.2fM", Double(totalTokens) / 1_000_000)
        } else if totalTokens >= 1_000 {
            return String(format: "%.1fK", Double(totalTokens) / 1_000)
        }
        return "\(totalTokens)"
    }

    /// Formatted active time
    var formattedActiveTime: String {
        let hours = Int(totalActiveTime) / 3600
        let minutes = (Int(totalActiveTime) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
