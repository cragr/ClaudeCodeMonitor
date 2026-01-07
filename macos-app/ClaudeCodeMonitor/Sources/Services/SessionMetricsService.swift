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

    private var lastSuccessfulSessions: [SessionMetrics] = []
    private let client: PrometheusClient
    private let historyProvider: (any SessionHistoryProvider)?

    init(client: PrometheusClient, historyProvider: (any SessionHistoryProvider)? = nil) {
        self.client = client
        self.historyProvider = historyProvider
    }

    /// Convenience initializer with default file-based history provider
    convenience init(client: PrometheusClient, enableProjectLookup: Bool) {
        if enableProjectLookup {
            self.init(client: client, historyProvider: FileSessionHistoryProvider())
        } else {
            self.init(client: client, historyProvider: nil)
        }
    }

    // MARK: - Top Sessions (computed client-side)

    var highestCostSession: SessionMetrics? {
        sessions.max(by: { $0.totalCostUSD < $1.totalCostUSD })
    }

    var mostTokensSession: SessionMetrics? {
        sessions.max(by: { $0.totalTokens < $1.totalTokens })
    }

    var longestSession: SessionMetrics? {
        sessions.max(by: { $0.activeTime < $1.activeTime })
    }

    // MARK: - Costs by Project

    /// Aggregated costs grouped by project
    var costsByProject: [ProjectCostSummary] {
        var projectTotals: [String: (cost: Decimal, tokens: Int, sessions: Int, activeTime: TimeInterval)] = [:]

        for session in sessions {
            let projectKey = session.projectPath ?? "Unknown"

            if var existing = projectTotals[projectKey] {
                existing.cost += session.totalCostUSD
                existing.tokens += session.totalTokens
                existing.sessions += 1
                existing.activeTime += session.activeTime
                projectTotals[projectKey] = existing
            } else {
                projectTotals[projectKey] = (session.totalCostUSD, session.totalTokens, 1, session.activeTime)
            }
        }

        return projectTotals.map { (path, totals) in
            ProjectCostSummary(
                projectPath: path,
                totalCostUSD: totals.cost,
                totalTokens: totals.tokens,
                sessionCount: totals.sessions,
                totalActiveTime: totals.activeTime
            )
        }.sorted { $0.totalCostUSD > $1.totalCostUSD }
    }

    // MARK: - Fetch

    /// Fetches session metrics from Prometheus for the given time range
    /// - Parameter timeRange: The time range preset for the query
    func fetchSessions(timeRange: TimeRangePreset) async {
        isLoading = true
        error = nil

        let rangeString = timeRange.promQLRange

        // Use actor to collect failures in a thread-safe manner
        let failureCollector = FailureCollector()

        // Results from concurrent fetches
        var costResults: [PrometheusMetricResult]?
        var typeResults: [PrometheusMetricResult]?
        var modelResults: [PrometheusMetricResult]?
        var activeResults: [PrometheusMetricResult]?

        // Fetch all queries concurrently
        await withTaskGroup(of: (QueryKind, [PrometheusMetricResult]?).self) { group in
            group.addTask {
                do {
                    let results = try await self.client.query(PromQLQueryBuilder.costBySession(range: rangeString))
                    return (.cost, results)
                } catch {
                    await failureCollector.addFailure("cost")
                    return (.cost, nil)
                }
            }
            group.addTask {
                do {
                    let results = try await self.client.query(PromQLQueryBuilder.tokensBySessionAndType(range: rangeString))
                    return (.tokensByType, results)
                } catch {
                    await failureCollector.addFailure("tokens by type")
                    return (.tokensByType, nil)
                }
            }
            group.addTask {
                do {
                    let results = try await self.client.query(PromQLQueryBuilder.tokensBySessionAndModel(range: rangeString))
                    return (.tokensByModel, results)
                } catch {
                    await failureCollector.addFailure("tokens by model")
                    return (.tokensByModel, nil)
                }
            }
            group.addTask {
                do {
                    let results = try await self.client.query(PromQLQueryBuilder.activeTimeBySession(range: rangeString))
                    return (.activeTime, results)
                } catch {
                    await failureCollector.addFailure("active time")
                    return (.activeTime, nil)
                }
            }

            // Collect results
            for await (kind, results) in group {
                switch kind {
                case .cost:
                    costResults = results
                case .tokensByType:
                    typeResults = results
                case .tokensByModel:
                    modelResults = results
                case .activeTime:
                    activeResults = results
                }
            }
        }

        let failures = await failureCollector.failures

        // Check for total failure
        if costResults == nil && typeResults == nil && modelResults == nil && activeResults == nil {
            error = .connectionFailed(underlying: NSError(domain: "SessionMetricsService", code: -1))
            sessions = lastSuccessfulSessions
            isLoading = false
            return
        }

        // Merge results
        var merged = Self.mergeResults(
            costResults: costResults ?? [],
            typeResults: typeResults ?? [],
            modelResults: modelResults ?? [],
            activeResults: activeResults ?? []
        )

        // Enrich with project paths from history provider
        if !merged.isEmpty, let historyProvider = historyProvider {
            let sessionIds = merged.map { $0.sessionId }
            let projectPaths = await historyProvider.projectPaths(for: sessionIds)

            for i in merged.indices {
                if let path = projectPaths[merged[i].sessionId] {
                    merged[i].projectPath = path
                }
            }
        }

        if merged.isEmpty {
            error = .noSessions
            sessions = lastSuccessfulSessions
        } else {
            sessions = merged
            lastSuccessfulSessions = merged

            if !failures.isEmpty {
                error = .partialData(fetched: 4 - failures.count, failed: failures)
            }
        }

        isLoading = false
    }
}

// MARK: - Query Kind

private enum QueryKind {
    case cost
    case tokensByType
    case tokensByModel
    case activeTime
}

// MARK: - Thread-Safe Failure Collector

private actor FailureCollector {
    var failures: [String] = []

    func addFailure(_ name: String) {
        failures.append(name)
    }
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
