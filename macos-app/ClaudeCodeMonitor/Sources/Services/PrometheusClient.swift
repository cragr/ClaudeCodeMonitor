import Foundation

// MARK: - Prometheus Client Errors

enum PrometheusError: LocalizedError {
    case invalidURL
    case connectionFailed(String)
    case httpError(Int)
    case decodingError(String)
    case queryError(String)
    case noData

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Prometheus URL"
        case .connectionFailed(let message):
            return "Connection failed: \(message)"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .decodingError(let message):
            return "Failed to decode response: \(message)"
        case .queryError(let message):
            return "Query error: \(message)"
        case .noData:
            return "No data returned"
        }
    }
}

// MARK: - Prometheus Client

actor PrometheusClient {
    private let baseURL: URL
    private let session: URLSession
    private var cache: [String: CachedResult] = [:]
    private let cacheTTL: TimeInterval = 5.0  // 5 second cache

    struct CachedResult {
        let data: Data
        let timestamp: Date
    }

    init(baseURL: URL) {
        self.baseURL = baseURL
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }

    // MARK: - API Detection

    func checkConnection() async throws -> PrometheusBuildInfo {
        let url = baseURL.appendingPathComponent("api/v1/status/buildinfo")
        let response: PrometheusResponse<PrometheusBuildInfo> = try await fetch(url)
        guard let data = response.data else {
            throw PrometheusError.noData
        }
        return data
    }

    // MARK: - Instant Query

    func query(_ promQL: String, time: Date? = nil) async throws -> [PrometheusMetricResult] {
        guard var components = URLComponents(url: baseURL.appendingPathComponent("api/v1/query"), resolvingAgainstBaseURL: false) else {
            throw PrometheusError.invalidURL
        }
        var queryItems = [URLQueryItem(name: "query", value: promQL)]
        if let time = time {
            queryItems.append(URLQueryItem(name: "time", value: String(time.timeIntervalSince1970)))
        }
        components.queryItems = queryItems

        guard let url = components.url else {
            throw PrometheusError.invalidURL
        }

        let response: PrometheusResponse<PrometheusQueryResult> = try await fetch(url)
        if let error = response.error {
            throw PrometheusError.queryError(error)
        }
        return response.data?.result ?? []
    }

    // MARK: - Range Query

    func queryRange(_ promQL: String, start: Date, end: Date, step: TimeInterval) async throws -> [PrometheusMetricResult] {
        guard var components = URLComponents(url: baseURL.appendingPathComponent("api/v1/query_range"), resolvingAgainstBaseURL: false) else {
            throw PrometheusError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "query", value: promQL),
            URLQueryItem(name: "start", value: String(start.timeIntervalSince1970)),
            URLQueryItem(name: "end", value: String(end.timeIntervalSince1970)),
            URLQueryItem(name: "step", value: String(Int(step)))
        ]

        guard let url = components.url else {
            throw PrometheusError.invalidURL
        }

        let response: PrometheusResponse<PrometheusQueryResult> = try await fetch(url)
        if let error = response.error {
            throw PrometheusError.queryError(error)
        }
        return response.data?.result ?? []
    }

    // MARK: - Get Targets

    func getTargets() async throws -> PrometheusTargetsResult {
        let url = baseURL.appendingPathComponent("api/v1/targets")
        let response: PrometheusResponse<PrometheusTargetsResult> = try await fetch(url)
        guard let data = response.data else {
            throw PrometheusError.noData
        }
        return data
    }

    // MARK: - Discover Metrics

    func discoverMetrics(matching pattern: String = "claude") async throws -> [String] {
        // Use label values endpoint to get all metric names
        let url = baseURL.appendingPathComponent("api/v1/label/__name__/values")
        let data = try await fetchRaw(url)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let status = json["status"] as? String, status == "success",
              let metricNames = json["data"] as? [String] else {
            throw PrometheusError.decodingError("Failed to parse label values")
        }

        // Filter for Claude-related metrics (case-insensitive)
        let filtered = metricNames.filter { metric in
            let lower = metric.lowercased()
            return lower.contains(pattern.lowercased()) || lower.contains("claude_code")
        }

        return filtered.sorted()
    }

    // MARK: - Private Helpers

    private func fetch<T: Decodable>(_ url: URL, useCache: Bool = false) async throws -> T {
        let cacheKey = url.absoluteString

        if useCache, let cached = cache[cacheKey],
           Date().timeIntervalSince(cached.timestamp) < cacheTTL {
            return try JSONDecoder().decode(T.self, from: cached.data)
        }

        let data = try await fetchRaw(url)

        if useCache {
            cache[cacheKey] = CachedResult(data: data, timestamp: Date())
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw PrometheusError.decodingError(error.localizedDescription)
        }
    }

    private func fetchRaw(_ url: URL) async throws -> Data {
        do {
            let (data, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw PrometheusError.connectionFailed("Invalid response")
            }
            guard (200...299).contains(httpResponse.statusCode) else {
                throw PrometheusError.httpError(httpResponse.statusCode)
            }
            return data
        } catch let error as PrometheusError {
            throw error
        } catch {
            throw PrometheusError.connectionFailed(error.localizedDescription)
        }
    }

    func clearCache() {
        cache.removeAll()
    }
}

// MARK: - Query Builder

struct PromQLQueryBuilder {
    private var metric: String
    private var labels: [String: String] = [:]
    private var aggregation: String?
    private var aggregationLabels: [String] = []
    private var rangeFunction: String?
    private var rangeDuration: String?

    init(metric: String) {
        self.metric = metric
    }

    // Factory for Claude Code metrics
    static func claudeMetric(_ metric: ClaudeCodeMetric) -> PromQLQueryBuilder {
        PromQLQueryBuilder(metric: metric.rawValue)
    }

    func withLabel(_ name: String, _ value: String) -> PromQLQueryBuilder {
        var builder = self
        builder.labels[name] = value
        return builder
    }

    func withLabels(_ newLabels: [String: String]) -> PromQLQueryBuilder {
        var builder = self
        for (key, value) in newLabels {
            builder.labels[key] = value
        }
        return builder
    }

    func sum(by labels: [String] = []) -> PromQLQueryBuilder {
        var builder = self
        builder.aggregation = "sum"
        builder.aggregationLabels = labels
        return builder
    }

    func avg(by labels: [String] = []) -> PromQLQueryBuilder {
        var builder = self
        builder.aggregation = "avg"
        builder.aggregationLabels = labels
        return builder
    }

    func rate(_ duration: String) -> PromQLQueryBuilder {
        var builder = self
        builder.rangeFunction = "rate"
        builder.rangeDuration = duration
        return builder
    }

    func increase(_ duration: String) -> PromQLQueryBuilder {
        var builder = self
        builder.rangeFunction = "increase"
        builder.rangeDuration = duration
        return builder
    }

    func irate(_ duration: String) -> PromQLQueryBuilder {
        var builder = self
        builder.rangeFunction = "irate"
        builder.rangeDuration = duration
        return builder
    }

    func lastOverTime(_ duration: String) -> PromQLQueryBuilder {
        var builder = self
        builder.rangeFunction = "last_over_time"
        builder.rangeDuration = duration
        return builder
    }

    func maxOverTime(_ duration: String) -> PromQLQueryBuilder {
        var builder = self
        builder.rangeFunction = "max_over_time"
        builder.rangeDuration = duration
        return builder
    }

    func build() -> String {
        var query = metric

        // Add labels if present (sorted for deterministic output)
        if !labels.isEmpty {
            let labelParts = labels.keys.sorted().map { "\($0)=\"\(labels[$0]!)\"" }
            query += "{\(labelParts.joined(separator: ","))}"
        }

        // Add range selector if using a range function
        if let duration = rangeDuration {
            query += "[\(duration)]"
        }

        // Wrap in range function
        if let fn = rangeFunction {
            query = "\(fn)(\(query))"
        }

        // Add aggregation
        if let agg = aggregation {
            if aggregationLabels.isEmpty {
                query = "\(agg)(\(query))"
            } else {
                query = "\(agg) by (\(aggregationLabels.joined(separator: ","))) (\(query))"
            }
        }

        return query
    }
}

// MARK: - Common Queries
// Based on official Claude Code telemetry metrics:
// - claude_code.session.count -> claude_code_session_count_total
// - claude_code.lines_of_code.count (type=added|removed) -> claude_code_lines_of_code_count_total
// - claude_code.pull_request.count -> claude_code_pull_request_count_total
// - claude_code.commit.count -> claude_code_commit_count_total
// - claude_code.cost.usage (model=...) -> claude_code_cost_usage_USD_total
// - claude_code.token.usage (type=input|output|cacheRead|cacheCreation, model=...) -> claude_code_token_usage_tokens_total
// - claude_code.active_time.total -> claude_code_active_time_seconds_total

extension PromQLQueryBuilder {

    // MARK: - Token Queries

    /// Tokens per second rate (for live charts)
    static func tokensRate(window: String = "5m") -> String {
        PromQLQueryBuilder(metric: "claude_code_token_usage_tokens_total")
            .rate(window)
            .sum()
            .build()
    }

    /// Tokens rate by model (for stacked charts)
    static func tokensRateByModel(window: String = "5m") -> String {
        PromQLQueryBuilder(metric: "claude_code_token_usage_tokens_total")
            .rate(window)
            .sum(by: ["model"])
            .build()
    }

    /// Tokens rate by type: input, output, cacheRead, cacheCreation
    static func tokensRateByType(window: String = "5m") -> String {
        PromQLQueryBuilder(metric: "claude_code_token_usage_tokens_total")
            .rate(window)
            .sum(by: ["type"])
            .build()
    }

    /// Total tokens (increase during time range)
    static func totalTokens(range: String) -> String {
        PromQLQueryBuilder(metric: "claude_code_token_usage_tokens_total")
            .increase(range)
            .sum()
            .build()
    }

    /// Tokens by model (increase during time range)
    static func tokensByModel(range: String) -> String {
        PromQLQueryBuilder(metric: "claude_code_token_usage_tokens_total")
            .increase(range)
            .sum(by: ["model"])
            .build()
    }

    /// Tokens by type (increase during time range)
    static func tokensByType(range: String) -> String {
        PromQLQueryBuilder(metric: "claude_code_token_usage_tokens_total")
            .increase(range)
            .sum(by: ["type"])
            .build()
    }

    // MARK: - Cost Queries

    /// Cost per second rate (for live charts)
    static func costRate(window: String = "5m") -> String {
        PromQLQueryBuilder(metric: "claude_code_cost_usage_USD_total")
            .rate(window)
            .sum()
            .build()
    }

    /// Cost rate by model (for stacked charts)
    static func costRateByModel(window: String = "5m") -> String {
        PromQLQueryBuilder(metric: "claude_code_cost_usage_USD_total")
            .rate(window)
            .sum(by: ["model"])
            .build()
    }

    /// Total cost (increase during time range)
    static func totalCost(range: String) -> String {
        PromQLQueryBuilder(metric: "claude_code_cost_usage_USD_total")
            .increase(range)
            .sum()
            .build()
    }

    /// Cost by model (increase during time range)
    static func costByModel(range: String) -> String {
        PromQLQueryBuilder(metric: "claude_code_cost_usage_USD_total")
            .increase(range)
            .sum(by: ["model"])
            .build()
    }

    // MARK: - Activity Queries

    /// Active time total (increase during time range)
    static func activeTime(range: String) -> String {
        PromQLQueryBuilder(metric: "claude_code_active_time_seconds_total")
            .increase(range)
            .sum()
            .build()
    }

    /// Session count (increase during time range)
    static func sessionCount(range: String) -> String {
        PromQLQueryBuilder(metric: "claude_code_session_count_total")
            .increase(range)
            .sum()
            .build()
    }

    // MARK: - Code Metrics Queries

    /// Lines of code by type (increase during time range)
    static func linesOfCode(type: String, range: String) -> String {
        PromQLQueryBuilder(metric: "claude_code_lines_of_code_count_total")
            .withLabel("type", type)
            .increase(range)
            .sum()
            .build()
    }

    /// Total lines added (increase during time range)
    static func linesAdded(range: String) -> String {
        linesOfCode(type: "added", range: range)
    }

    /// Total lines removed (increase during time range)
    static func linesRemoved(range: String) -> String {
        linesOfCode(type: "removed", range: range)
    }

    /// Commit count (increase during time range)
    static func commitCount(range: String) -> String {
        PromQLQueryBuilder(metric: "claude_code_commit_count_total")
            .increase(range)
            .sum()
            .build()
    }

    /// PR count (increase during time range)
    static func prCount(range: String) -> String {
        PromQLQueryBuilder(metric: "claude_code_pull_request_count_total")
            .increase(range)
            .sum()
            .build()
    }

    // MARK: - Session-Level Queries

    /// Cost per session (increase during time range)
    static func costBySession(range: String) -> String {
        PromQLQueryBuilder(metric: "claude_code_cost_usage_USD_total")
            .increase(range)
            .sum(by: ["session_id"])
            .build()
    }

    /// Tokens per session by type (increase during time range)
    static func tokensBySessionAndType(range: String) -> String {
        PromQLQueryBuilder(metric: "claude_code_token_usage_tokens_total")
            .increase(range)
            .sum(by: ["session_id", "type"])
            .build()
    }

    /// Tokens per session by model (increase during time range)
    static func tokensBySessionAndModel(range: String) -> String {
        PromQLQueryBuilder(metric: "claude_code_token_usage_tokens_total")
            .increase(range)
            .sum(by: ["session_id", "model"])
            .build()
    }

    /// Active time per session (increase during time range)
    static func activeTimeBySession(range: String) -> String {
        PromQLQueryBuilder(metric: "claude_code_active_time_seconds_total")
            .increase(range)
            .sum(by: ["session_id"])
            .build()
    }
}
