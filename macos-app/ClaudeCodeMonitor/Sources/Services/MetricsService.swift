import Foundation
import os

private let logger = Logger(subsystem: "com.claudecode.monitor", category: "MetricsService")

// MARK: - Metrics Fetch Result

private enum MetricFetchResult: Sendable {
    case totalTokens(Double)
    case totalCost(Double)
    case activeTime(Double)
    case sessionCount(Double)
    case linesAdded(Double)
    case linesRemoved(Double)
    case commitCount(Double)
    case prCount(Double)
    case tokensSeries([MetricDataPoint])
    case costSeries([MetricDataPoint])
    case modelBreakdown([String: Double])
}

// MARK: - Metrics Service

@MainActor
class MetricsService: ObservableObject {
    @Published var connectionStatus: ConnectionStatus = .unknown
    @Published var dashboardData = DashboardData()
    @Published var discoveredMetrics: [String] = []
    @Published var lastRefresh: Date?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentTimeRange: TimeRangePreset = .last15Minutes {
        didSet {
            if oldValue != currentTimeRange {
                Task { await refreshDashboard() }
            }
        }
    }

    private var client: PrometheusClient?
    private var refreshTask: Task<Void, Never>?

    var prometheusURL: URL? {
        didSet {
            if let url = prometheusURL {
                client = PrometheusClient(baseURL: url)
                Task { await checkConnection() }
            }
        }
    }

    init() {}

    // MARK: - Connection

    func checkConnection() async {
        guard let client = client else {
            connectionStatus = .disconnected(error: "No URL configured")
            return
        }

        connectionStatus = .connecting
        do {
            let buildInfo = try await client.checkConnection()
            connectionStatus = .connected(version: buildInfo.version)
            errorMessage = nil

            // Discover metrics on successful connection
            await discoverClaudeMetrics()

            // Trigger initial data refresh after connection is established
            await refreshDashboard()
        } catch {
            connectionStatus = .disconnected(error: error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }

    func discoverClaudeMetrics() async {
        guard let client = client else { return }

        do {
            let metrics = try await client.discoverMetrics()
            discoveredMetrics = metrics.sorted()
        } catch {
            // Not critical, just log
            logger.warning("Failed to discover metrics: \(error.localizedDescription)")
        }
    }

    // MARK: - Auto Refresh

    func startAutoRefresh(interval: TimeInterval) {
        stopAutoRefresh()
        refreshTask = Task {
            while !Task.isCancelled {
                await refreshDashboard()
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    // MARK: - Dashboard Refresh

    /// Refresh dashboard using the current time range
    func refreshDashboard() async {
        await refreshDashboard(timeRange: currentTimeRange)
    }

    func refreshDashboard(timeRange: TimeRangePreset, customStart: Date? = nil, customEnd: Date? = nil) async {
        guard let client = client, connectionStatus.isConnected else {
            await checkConnection()
            return
        }

        isLoading = true
        defer { isLoading = false }

        let end = customEnd ?? Date()
        let start = customStart ?? end.addingTimeInterval(-timeRange.duration)
        let step = timeRange.recommendedStep
        let rangeStr = timeRangeString(timeRange)

        var newData = DashboardData()

        // Fetch all metrics in parallel using typed task group to avoid data races
        await withTaskGroup(of: MetricFetchResult?.self) { group in
            // Total tokens
            group.addTask {
                await self.fetchTotalTokens(client: client, range: rangeStr)
            }

            // Total cost
            group.addTask {
                await self.fetchTotalCost(client: client, range: rangeStr)
            }

            // Active time
            group.addTask {
                await self.fetchActiveTime(client: client, range: rangeStr)
            }

            // Session count
            group.addTask {
                await self.fetchSessionCount(client: client, range: rangeStr)
            }

            // Lines of code (added)
            group.addTask {
                await self.fetchLinesAdded(client: client, range: rangeStr)
            }

            // Lines of code (removed)
            group.addTask {
                await self.fetchLinesRemoved(client: client, range: rangeStr)
            }

            // Commit count
            group.addTask {
                await self.fetchCommitCount(client: client, range: rangeStr)
            }

            // PR count
            group.addTask {
                await self.fetchPRCount(client: client, range: rangeStr)
            }

            // Token series (for chart)
            group.addTask {
                await self.fetchTokenSeries(client: client, start: start, end: end, step: step)
            }

            // Cost series (for chart)
            group.addTask {
                await self.fetchCostSeries(client: client, start: start, end: end, step: step)
            }

            // Model breakdown
            group.addTask {
                await self.fetchModelBreakdown(client: client, range: rangeStr)
            }

            // Collect results safely
            for await result in group {
                guard let result = result else { continue }
                switch result {
                case .totalTokens(let value):
                    newData.totalTokens = value
                case .totalCost(let value):
                    newData.totalCost = value
                case .activeTime(let value):
                    newData.totalActiveTime = value
                case .sessionCount(let value):
                    newData.sessionCount = value
                case .linesAdded(let value):
                    newData.linesAdded = value
                case .linesRemoved(let value):
                    newData.linesRemoved = value
                case .commitCount(let value):
                    newData.commitCount = value
                case .prCount(let value):
                    newData.prCount = value
                case .tokensSeries(let series):
                    newData.tokensSeries = series
                case .costSeries(let series):
                    newData.costSeries = series
                case .modelBreakdown(let breakdown):
                    newData.modelBreakdown = breakdown
                }
            }
        }

        dashboardData = newData
        lastRefresh = Date()
        errorMessage = nil
    }

    // MARK: - Private Fetch Methods

    private func fetchTotalTokens(client: PrometheusClient, range: String) async -> MetricFetchResult? {
        do {
            let query = PromQLQueryBuilder.totalTokens(range: range)
            let results = try await client.query(query)
            if let value = results.first?.value?.doubleValue {
                return .totalTokens(value)
            }
        } catch {
            logger.error("Failed to fetch tokens: \(error.localizedDescription)")
        }
        return nil
    }

    private func fetchTotalCost(client: PrometheusClient, range: String) async -> MetricFetchResult? {
        do {
            let query = PromQLQueryBuilder.totalCost(range: range)
            let results = try await client.query(query)
            if let value = results.first?.value?.doubleValue {
                return .totalCost(value)
            }
        } catch {
            logger.error("Failed to fetch cost: \(error.localizedDescription)")
        }
        return nil
    }

    private func fetchActiveTime(client: PrometheusClient, range: String) async -> MetricFetchResult? {
        do {
            let query = PromQLQueryBuilder.activeTime(range: range)
            let results = try await client.query(query)
            if let value = results.first?.value?.doubleValue {
                return .activeTime(value)
            }
        } catch {
            logger.error("Failed to fetch active time: \(error.localizedDescription)")
        }
        return nil
    }

    private func fetchSessionCount(client: PrometheusClient, range: String) async -> MetricFetchResult? {
        do {
            let query = PromQLQueryBuilder.sessionCount(range: range)
            let results = try await client.query(query)
            if let value = results.first?.value?.doubleValue {
                return .sessionCount(value)
            }
        } catch {
            logger.error("Failed to fetch session count: \(error.localizedDescription)")
        }
        return nil
    }

    private func fetchLinesAdded(client: PrometheusClient, range: String) async -> MetricFetchResult? {
        do {
            let query = PromQLQueryBuilder.linesOfCode(type: "added", range: range)
            let results = try await client.query(query)
            if let value = results.first?.value?.doubleValue {
                return .linesAdded(value)
            }
        } catch {
            logger.error("Failed to fetch lines added: \(error.localizedDescription)")
        }
        return nil
    }

    private func fetchLinesRemoved(client: PrometheusClient, range: String) async -> MetricFetchResult? {
        do {
            let query = PromQLQueryBuilder.linesOfCode(type: "removed", range: range)
            let results = try await client.query(query)
            if let value = results.first?.value?.doubleValue {
                return .linesRemoved(value)
            }
        } catch {
            logger.error("Failed to fetch lines removed: \(error.localizedDescription)")
        }
        return nil
    }

    private func fetchCommitCount(client: PrometheusClient, range: String) async -> MetricFetchResult? {
        do {
            let query = PromQLQueryBuilder.commitCount(range: range)
            let results = try await client.query(query)
            if let value = results.first?.value?.doubleValue {
                return .commitCount(value)
            }
        } catch {
            logger.error("Failed to fetch commit count: \(error.localizedDescription)")
        }
        return nil
    }

    private func fetchPRCount(client: PrometheusClient, range: String) async -> MetricFetchResult? {
        do {
            let query = PromQLQueryBuilder.prCount(range: range)
            let results = try await client.query(query)
            if let value = results.first?.value?.doubleValue {
                return .prCount(value)
            }
        } catch {
            logger.error("Failed to fetch PR count: \(error.localizedDescription)")
        }
        return nil
    }

    private func fetchTokenSeries(client: PrometheusClient, start: Date, end: Date, step: TimeInterval) async -> MetricFetchResult? {
        do {
            let query = PromQLQueryBuilder.tokensRate(window: "5m")
            let results = try await client.queryRange(query, start: start, end: end, step: step)

            let series = results.flatMap { result in
                (result.values ?? []).map { value in
                    MetricDataPoint(
                        timestamp: value.date,
                        value: value.doubleValue ?? 0,
                        labels: result.metric
                    )
                }
            }.sorted { $0.timestamp < $1.timestamp }
            return .tokensSeries(series)
        } catch {
            logger.error("Failed to fetch token series: \(error.localizedDescription)")
        }
        return nil
    }

    private func fetchCostSeries(client: PrometheusClient, start: Date, end: Date, step: TimeInterval) async -> MetricFetchResult? {
        do {
            let query = PromQLQueryBuilder.costRate(window: "5m")
            let results = try await client.queryRange(query, start: start, end: end, step: step)

            let series = results.flatMap { result in
                (result.values ?? []).map { value in
                    MetricDataPoint(
                        timestamp: value.date,
                        value: value.doubleValue ?? 0,
                        labels: result.metric
                    )
                }
            }.sorted { $0.timestamp < $1.timestamp }
            return .costSeries(series)
        } catch {
            logger.error("Failed to fetch cost series: \(error.localizedDescription)")
        }
        return nil
    }

    private func fetchModelBreakdown(client: PrometheusClient, range: String) async -> MetricFetchResult? {
        do {
            let query = PromQLQueryBuilder.tokensByModel(range: range)
            let results = try await client.query(query)

            var breakdown: [String: Double] = [:]
            for result in results {
                let model = result.metric["model"] ?? "unknown"
                if let value = result.value?.doubleValue {
                    breakdown[model] = value
                }
            }
            return .modelBreakdown(breakdown)
        } catch {
            logger.error("Failed to fetch model breakdown: \(error.localizedDescription)")
        }
        return nil
    }

    // MARK: - Helpers

    private func timeRangeString(_ preset: TimeRangePreset) -> String {
        switch preset {
        case .last5Minutes: return "5m"
        case .last15Minutes: return "15m"
        case .last1Hour: return "1h"
        case .last24Hours: return "24h"
        case .last7Days: return "7d"
        case .last30Days: return "30d"
        case .custom: return "1h"
        }
    }
}
