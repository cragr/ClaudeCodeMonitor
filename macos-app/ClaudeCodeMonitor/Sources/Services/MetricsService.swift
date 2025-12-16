import Foundation
import os

private let logger = Logger(subsystem: "com.claudecode.monitor", category: "MetricsService")

// MARK: - Metrics Fetch Result

private enum MetricFetchResult: Sendable {
    // Summary KPIs
    case totalTokens(Double)
    case totalCost(Double)
    case activeTime(Double)
    case sessionCount(Double)
    case linesAdded(Double)
    case linesRemoved(Double)
    case commitCount(Double)
    case prCount(Double)
    // Summary Charts
    case costRateSeries([MetricDataPoint])
    case costByModel([String: Double])
    // Performance Charts
    case tokensSeries([MetricDataPoint])
    case tokensByType([String: Double])
    case tokensByModelSeries([ModelSeriesData])
    case tokensByTypeSeries([TypeSeriesData])
    // Legacy/shared
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
            // MARK: Summary KPIs
            group.addTask { await self.fetchTotalTokens(client: client, range: rangeStr) }
            group.addTask { await self.fetchTotalCost(client: client, range: rangeStr) }
            group.addTask { await self.fetchActiveTime(client: client, range: rangeStr) }
            group.addTask { await self.fetchSessionCount(client: client, range: rangeStr) }
            group.addTask { await self.fetchLinesAdded(client: client, range: rangeStr) }
            group.addTask { await self.fetchLinesRemoved(client: client, range: rangeStr) }
            group.addTask { await self.fetchCommitCount(client: client, range: rangeStr) }
            group.addTask { await self.fetchPRCount(client: client, range: rangeStr) }

            // MARK: Summary Charts
            group.addTask { await self.fetchCostRateSeries(client: client, start: start, end: end, step: step) }
            group.addTask { await self.fetchCostByModel(client: client, range: rangeStr) }

            // MARK: Performance Charts
            group.addTask { await self.fetchTokenSeries(client: client, start: start, end: end, step: step) }
            group.addTask { await self.fetchTokensByType(client: client, range: rangeStr) }
            group.addTask { await self.fetchTokensByModelSeries(client: client, start: start, end: end, step: step) }
            group.addTask { await self.fetchTokensByTypeSeries(client: client, start: start, end: end, step: step) }

            // MARK: Legacy/shared
            group.addTask { await self.fetchCostSeries(client: client, start: start, end: end, step: step) }
            group.addTask { await self.fetchModelBreakdown(client: client, range: rangeStr) }

            // Collect results safely
            for await result in group {
                guard let result = result else { continue }
                switch result {
                // Summary KPIs
                case .totalTokens(let value):
                    newData.totalTokens = max(0, value)
                case .totalCost(let value):
                    newData.totalCost = max(0, value)
                case .activeTime(let value):
                    newData.totalActiveTime = max(0, value)
                case .sessionCount(let value):
                    newData.sessionCount = max(0, value)
                case .linesAdded(let value):
                    newData.linesAdded = max(0, value)
                case .linesRemoved(let value):
                    newData.linesRemoved = max(0, value)
                case .commitCount(let value):
                    newData.commitCount = max(0, value)
                case .prCount(let value):
                    newData.prCount = max(0, value)
                // Summary Charts
                case .costRateSeries(let series):
                    newData.costRateSeries = series
                case .costByModel(let breakdown):
                    newData.costByModel = breakdown
                // Performance Charts
                case .tokensSeries(let series):
                    newData.tokensSeries = series
                case .tokensByType(let breakdown):
                    newData.tokensByType = breakdown
                case .tokensByModelSeries(let series):
                    newData.tokensByModelSeries = series
                case .tokensByTypeSeries(let series):
                    newData.tokensByTypeSeries = series
                // Legacy/shared
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

    // MARK: - Additional Fetch Methods for Performance Tab

    private func fetchCostByModel(client: PrometheusClient, range: String) async -> MetricFetchResult? {
        do {
            let query = PromQLQueryBuilder.costByModel(range: range)
            let results = try await client.query(query)

            var breakdown: [String: Double] = [:]
            for result in results {
                let model = result.metric["model"] ?? "unknown"
                if let value = result.value?.doubleValue, value > 0 {
                    breakdown[model] = value
                }
            }
            return .costByModel(breakdown)
        } catch {
            logger.error("Failed to fetch cost by model: \(error.localizedDescription)")
        }
        return nil
    }

    private func fetchCostRateSeries(client: PrometheusClient, start: Date, end: Date, step: TimeInterval) async -> MetricFetchResult? {
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
            return .costRateSeries(series)
        } catch {
            logger.error("Failed to fetch cost rate series: \(error.localizedDescription)")
        }
        return nil
    }

    private func fetchTokensByType(client: PrometheusClient, range: String) async -> MetricFetchResult? {
        do {
            let query = PromQLQueryBuilder.tokensByType(range: range)
            let results = try await client.query(query)

            var breakdown: [String: Double] = [:]
            for result in results {
                let tokenType = result.metric["type"] ?? "unknown"
                if let value = result.value?.doubleValue, value > 0 {
                    breakdown[tokenType] = value
                }
            }
            return .tokensByType(breakdown)
        } catch {
            logger.error("Failed to fetch tokens by type: \(error.localizedDescription)")
        }
        return nil
    }

    private func fetchTokensByModelSeries(client: PrometheusClient, start: Date, end: Date, step: TimeInterval) async -> MetricFetchResult? {
        do {
            let query = PromQLQueryBuilder.tokensRateByModel(window: "5m")
            let results = try await client.queryRange(query, start: start, end: end, step: step)

            var modelSeries: [String: [MetricDataPoint]] = [:]
            for result in results {
                let model = result.metric["model"] ?? "unknown"
                let points = (result.values ?? []).map { value in
                    MetricDataPoint(
                        timestamp: value.date,
                        value: value.doubleValue ?? 0,
                        labels: result.metric
                    )
                }
                modelSeries[model] = points.sorted { $0.timestamp < $1.timestamp }
            }

            let series = modelSeries.map { ModelSeriesData(model: $0.key, dataPoints: $0.value) }
            return .tokensByModelSeries(series)
        } catch {
            logger.error("Failed to fetch tokens by model series: \(error.localizedDescription)")
        }
        return nil
    }

    private func fetchTokensByTypeSeries(client: PrometheusClient, start: Date, end: Date, step: TimeInterval) async -> MetricFetchResult? {
        do {
            let query = PromQLQueryBuilder.tokensRateByType(window: "5m")
            let results = try await client.queryRange(query, start: start, end: end, step: step)

            var typeSeries: [String: [MetricDataPoint]] = [:]
            for result in results {
                let tokenType = result.metric["type"] ?? "unknown"
                let points = (result.values ?? []).map { value in
                    MetricDataPoint(
                        timestamp: value.date,
                        value: value.doubleValue ?? 0,
                        labels: result.metric
                    )
                }
                typeSeries[tokenType] = points.sorted { $0.timestamp < $1.timestamp }
            }

            let series = typeSeries.map { TypeSeriesData(tokenType: $0.key, dataPoints: $0.value) }
            return .tokensByTypeSeries(series)
        } catch {
            logger.error("Failed to fetch tokens by type series: \(error.localizedDescription)")
        }
        return nil
    }

    // MARK: - Helpers

    private func timeRangeString(_ preset: TimeRangePreset) -> String {
        preset.promQLRange
    }
}
