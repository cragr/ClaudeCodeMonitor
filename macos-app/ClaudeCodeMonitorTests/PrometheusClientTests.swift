import XCTest
@testable import ClaudeCodeMonitor

final class PrometheusClientTests: XCTestCase {

    // MARK: - Query Builder Tests

    func testBasicQuery() {
        let query = PromQLQueryBuilder(metric: "up").build()
        XCTAssertEqual(query, "up")
    }

    func testQueryWithLabels() {
        let query = PromQLQueryBuilder(metric: "up")
            .withLabel("job", "prometheus")
            .build()
        XCTAssertEqual(query, "up{job=\"prometheus\"}")
    }

    func testQueryWithMultipleLabels() {
        let query = PromQLQueryBuilder(metric: "http_requests_total")
            .withLabel("method", "GET")
            .withLabel("status", "200")
            .build()
        // Labels order may vary, so check both possibilities
        XCTAssertTrue(
            query == "http_requests_total{method=\"GET\",status=\"200\"}" ||
            query == "http_requests_total{status=\"200\",method=\"GET\"}"
        )
    }

    func testQueryWithRate() {
        let query = PromQLQueryBuilder(metric: "http_requests_total")
            .rate("5m")
            .build()
        XCTAssertEqual(query, "rate(http_requests_total[5m])")
    }

    func testQueryWithIncrease() {
        let query = PromQLQueryBuilder(metric: "counter_total")
            .increase("1h")
            .build()
        XCTAssertEqual(query, "increase(counter_total[1h])")
    }

    func testQueryWithSum() {
        let query = PromQLQueryBuilder(metric: "requests")
            .sum()
            .build()
        XCTAssertEqual(query, "sum(requests)")
    }

    func testQueryWithSumBy() {
        let query = PromQLQueryBuilder(metric: "requests")
            .sum(by: ["method", "status"])
            .build()
        XCTAssertEqual(query, "sum by (method,status) (requests)")
    }

    func testQueryWithRateAndSum() {
        let query = PromQLQueryBuilder(metric: "http_requests_total")
            .rate("5m")
            .sum(by: ["method"])
            .build()
        XCTAssertEqual(query, "sum by (method) (rate(http_requests_total[5m]))")
    }

    func testQueryWithLabelsAndRateAndSum() {
        let query = PromQLQueryBuilder(metric: "http_requests_total")
            .withLabel("job", "api")
            .rate("5m")
            .sum()
            .build()
        XCTAssertEqual(query, "sum(rate(http_requests_total{job=\"api\"}[5m]))")
    }

    // MARK: - Claude Code Query Builder Tests

    func testTokensRateQuery() {
        let query = PromQLQueryBuilder.tokensRate(window: "5m")
        XCTAssertEqual(query, "rate(claude_code_token_usage_tokens_total[5m])")
    }

    func testCostRateQuery() {
        let query = PromQLQueryBuilder.costRate(window: "5m")
        XCTAssertEqual(query, "rate(claude_code_cost_usage_USD_total[5m])")
    }

    func testTotalTokensQuery() {
        let query = PromQLQueryBuilder.totalTokens(range: "1h")
        XCTAssertEqual(query, "sum(last_over_time(claude_code_token_usage_tokens_total[1h]))")
    }

    func testTotalCostQuery() {
        let query = PromQLQueryBuilder.totalCost(range: "24h")
        XCTAssertEqual(query, "sum(last_over_time(claude_code_cost_usage_USD_total[24h]))")
    }

    func testTokensByModelQuery() {
        let query = PromQLQueryBuilder.tokensByModel(range: "1h")
        XCTAssertEqual(query, "sum by (model) (last_over_time(claude_code_token_usage_tokens_total[1h]))")
    }

    func testActiveTimeQuery() {
        let query = PromQLQueryBuilder.activeTime(range: "1h")
        XCTAssertEqual(query, "sum(last_over_time(claude_code_active_time_seconds_total[1h]))")
    }

    func testSessionCountQuery() {
        let query = PromQLQueryBuilder.sessionCount(range: "24h")
        XCTAssertEqual(query, "sum(last_over_time(claude_code_session_count_total[24h]))")
    }

    func testLinesOfCodeAddedQuery() {
        let query = PromQLQueryBuilder.linesOfCode(type: "added", range: "1h")
        XCTAssertEqual(query, "sum(last_over_time(claude_code_lines_of_code_count_total{type=\"added\"}[1h]))")
    }

    func testLinesOfCodeRemovedQuery() {
        let query = PromQLQueryBuilder.linesOfCode(type: "removed", range: "1h")
        XCTAssertEqual(query, "sum(last_over_time(claude_code_lines_of_code_count_total{type=\"removed\"}[1h]))")
    }

    func testCommitCountQuery() {
        let query = PromQLQueryBuilder.commitCount(range: "7d")
        XCTAssertEqual(query, "sum(last_over_time(claude_code_commit_count_total[7d]))")
    }

    func testPRCountQuery() {
        let query = PromQLQueryBuilder.prCount(range: "30d")
        XCTAssertEqual(query, "sum(last_over_time(claude_code_pull_request_count_total[30d]))")
    }

    // MARK: - Claude Metric Factory Tests

    func testClaudeMetricFactory() {
        let query = PromQLQueryBuilder.claudeMetric(.tokenUsage)
            .rate("5m")
            .build()
        XCTAssertEqual(query, "rate(claude_code_token_usage[5m])")
    }
}
