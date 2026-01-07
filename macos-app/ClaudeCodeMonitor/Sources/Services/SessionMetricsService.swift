import Foundation

// MARK: - Error Types

enum SessionFetchError: LocalizedError {
    case partialData(fetched: Int, failed: [String])
    case noSessions
    case connectionFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .partialData(let fetched, let failed):
            return "Loaded \(fetched) metrics queries, but failed: \(failed.joined(separator: ", ")). Some charts may be missing."
        case .noSessions:
            return "No sessions found in the selected time range."
        case .connectionFailed:
            return "Unable to reach metrics backend. Please check your connection or try again."
        }
    }
}

// MARK: - Session Metrics Service

/// Service for fetching and aggregating session-level metrics from Prometheus
@MainActor
class SessionMetricsService: ObservableObject {
    @Published var sessions: [SessionMetrics] = []
    @Published var isLoading = false
    @Published var error: SessionFetchError?
}

// MARK: - Merge Logic

extension SessionMetricsService {
    /// Merge results from multiple Prometheus queries into SessionMetrics array
    ///
    /// This method combines data from 4 separate Prometheus queries:
    /// - costResults: Total cost per session
    /// - typeResults: Token counts by type (input, output, cacheRead, cacheCreation)
    /// - modelResults: Token counts by model
    /// - activeResults: Active time per session
    ///
    /// Sessions are identified by the `session_id` label. If a session only appears
    /// in some of the queries, missing data defaults to zero.
    ///
    /// - Returns: Array of SessionMetrics sorted by session ID
    nonisolated static func mergeResults(
        costResults: [PrometheusMetricResult],
        typeResults: [PrometheusMetricResult],
        modelResults: [PrometheusMetricResult],
        activeResults: [PrometheusMetricResult]
    ) -> [SessionMetrics] {
        // Collect all unique session IDs from all result sets
        var sessionIds = Set<String>()
        for result in costResults + typeResults + modelResults + activeResults {
            if let sessionId = result.metric["session_id"], !sessionId.isEmpty {
                sessionIds.insert(sessionId)
            }
        }

        // Return empty array if no sessions found
        guard !sessionIds.isEmpty else {
            return []
        }

        // Build sessions dictionary with default values
        var sessionsDict: [String: SessionMetrics] = [:]
        for sessionId in sessionIds {
            sessionsDict[sessionId] = SessionMetrics(
                sessionId: sessionId,
                totalCostUSD: Decimal(0),
                totalTokens: 0,
                tokensByType: [:],
                tokensByModel: [:],
                activeTime: 0,
                firstSeen: nil,
                lastSeen: nil
            )
        }

        // Populate cost data
        for result in costResults {
            guard let sessionId = result.metric["session_id"],
                  let value = result.value?.doubleValue else { continue }
            sessionsDict[sessionId]?.totalCostUSD = Decimal(value)
        }

        // Populate tokens by type and accumulate total tokens
        for result in typeResults {
            guard let sessionId = result.metric["session_id"],
                  let typeStr = result.metric["type"],
                  let tokenType = TokenType(rawValue: typeStr),
                  let value = result.value?.doubleValue else { continue }
            let intValue = Int(value)
            sessionsDict[sessionId]?.tokensByType[tokenType] = intValue
            sessionsDict[sessionId]?.totalTokens += intValue
        }

        // Populate tokens by model
        for result in modelResults {
            guard let sessionId = result.metric["session_id"],
                  let model = result.metric["model"],
                  let value = result.value?.doubleValue else { continue }
            sessionsDict[sessionId]?.tokensByModel[model] = Int(value)
        }

        // Populate active time
        for result in activeResults {
            guard let sessionId = result.metric["session_id"],
                  let value = result.value?.doubleValue else { continue }
            sessionsDict[sessionId]?.activeTime = value
        }

        // Return sorted array for consistent ordering
        return Array(sessionsDict.values).sorted { $0.sessionId < $1.sessionId }
    }
}
