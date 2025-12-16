import XCTest
@testable import ClaudeCodeMonitor

final class MetricNormalizationTests: XCTestCase {

    // MARK: - Metric Name Normalization

    func testNormalizeUnderscoreFormat() {
        let metric = ClaudeCodeMetric.normalize("claude_code_token_usage")
        XCTAssertEqual(metric, .tokenUsage)
    }

    func testNormalizeDotFormat() {
        let metric = ClaudeCodeMetric.normalize("claude_code.token.usage")
        XCTAssertEqual(metric, .tokenUsage)
    }

    func testNormalizeSessionCount() {
        XCTAssertEqual(ClaudeCodeMetric.normalize("claude_code_session_count"), .sessionCount)
        XCTAssertEqual(ClaudeCodeMetric.normalize("claude_code.session.count"), .sessionCount)
    }

    func testNormalizeLinesOfCode() {
        XCTAssertEqual(ClaudeCodeMetric.normalize("claude_code_lines_of_code_count"), .linesOfCode)
        XCTAssertEqual(ClaudeCodeMetric.normalize("claude_code.lines_of_code.count"), .linesOfCode)
    }

    func testNormalizeCostUsage() {
        XCTAssertEqual(ClaudeCodeMetric.normalize("claude_code_cost_usage"), .costUsage)
        XCTAssertEqual(ClaudeCodeMetric.normalize("claude_code.cost.usage"), .costUsage)
    }

    func testNormalizeActiveTime() {
        XCTAssertEqual(ClaudeCodeMetric.normalize("claude_code_active_time_total"), .activeTime)
        XCTAssertEqual(ClaudeCodeMetric.normalize("claude_code.active_time.total"), .activeTime)
    }

    func testNormalizeUnknownMetric() {
        let metric = ClaudeCodeMetric.normalize("unknown_metric")
        XCTAssertNil(metric)
    }

    // MARK: - Label Normalization

    func testNormalizeLabelUnderscoreFormat() {
        let label = ClaudeCodeLabel.normalize("session_id")
        XCTAssertEqual(label, .sessionId)
    }

    func testNormalizeLabelDotFormat() {
        let label = ClaudeCodeLabel.normalize("session.id")
        XCTAssertEqual(label, .sessionId)
    }

    func testNormalizeAccountUuid() {
        XCTAssertEqual(ClaudeCodeLabel.normalize("user_account_uuid"), .accountUuid)
        XCTAssertEqual(ClaudeCodeLabel.normalize("user.account_uuid"), .accountUuid)
    }

    func testNormalizeOrganizationId() {
        XCTAssertEqual(ClaudeCodeLabel.normalize("organization_id"), .organizationId)
        XCTAssertEqual(ClaudeCodeLabel.normalize("organization.id"), .organizationId)
    }

    func testNormalizeTerminalType() {
        XCTAssertEqual(ClaudeCodeLabel.normalize("terminal_type"), .terminalType)
        XCTAssertEqual(ClaudeCodeLabel.normalize("terminal.type"), .terminalType)
    }

    func testNormalizeAppVersion() {
        XCTAssertEqual(ClaudeCodeLabel.normalize("app_version"), .appVersion)
        XCTAssertEqual(ClaudeCodeLabel.normalize("app.version"), .appVersion)
    }

    func testNormalizeModelLabel() {
        XCTAssertEqual(ClaudeCodeLabel.normalize("model"), .model)
    }

    func testNormalizeTypeLabel() {
        XCTAssertEqual(ClaudeCodeLabel.normalize("type"), .type)
    }

    func testNormalizeUnknownLabel() {
        let label = ClaudeCodeLabel.normalize("unknown_label")
        XCTAssertNil(label)
    }

    // MARK: - Metric Properties

    func testMetricDisplayNames() {
        XCTAssertEqual(ClaudeCodeMetric.tokenUsage.displayName, "Tokens")
        XCTAssertEqual(ClaudeCodeMetric.costUsage.displayName, "Cost (USD)")
        XCTAssertEqual(ClaudeCodeMetric.activeTime.displayName, "Active Time")
        XCTAssertEqual(ClaudeCodeMetric.sessionCount.displayName, "Sessions")
        XCTAssertEqual(ClaudeCodeMetric.linesOfCode.displayName, "Lines of Code")
        XCTAssertEqual(ClaudeCodeMetric.commitCount.displayName, "Commits")
        XCTAssertEqual(ClaudeCodeMetric.pullRequestCount.displayName, "Pull Requests")
    }

    func testMetricUnits() {
        XCTAssertEqual(ClaudeCodeMetric.tokenUsage.unit, "tokens")
        XCTAssertEqual(ClaudeCodeMetric.costUsage.unit, "USD")
        XCTAssertEqual(ClaudeCodeMetric.activeTime.unit, "seconds")
        XCTAssertEqual(ClaudeCodeMetric.sessionCount.unit, "count")
    }

    func testMetricSearchPatterns() {
        let patterns = ClaudeCodeMetric.tokenUsage.searchPatterns
        XCTAssertTrue(patterns.contains("claude_code_token_usage"))
        XCTAssertTrue(patterns.contains("claude.code.token.usage"))
    }

    // MARK: - Time Range Preset Tests
    // Note: Comprehensive time range tests are in TimeRangeBucketingTests.swift
    // These are basic sanity checks for the updated presets

    func testTimeRangePresetDurations() {
        XCTAssertEqual(TimeRangePreset.last15Minutes.duration, 15 * 60)
        XCTAssertEqual(TimeRangePreset.last1Hour.duration, 60 * 60)
        XCTAssertEqual(TimeRangePreset.last12Hours.duration, 12 * 60 * 60)
        XCTAssertEqual(TimeRangePreset.last1Day.duration, 24 * 60 * 60)
        XCTAssertEqual(TimeRangePreset.last1Week.duration, 7 * 24 * 60 * 60)
        XCTAssertEqual(TimeRangePreset.last2Weeks.duration, 14 * 24 * 60 * 60)
        XCTAssertEqual(TimeRangePreset.last1Month.duration, 30 * 24 * 60 * 60)
    }

    func testTimeRangePresetSteps() {
        // Per spec: 15m/1h use minute buckets, 12h uses 5min, 1d/1w use hour, 2w/1mo use day
        XCTAssertEqual(TimeRangePreset.last15Minutes.recommendedStep, 60)
        XCTAssertEqual(TimeRangePreset.last1Hour.recommendedStep, 60)
        XCTAssertEqual(TimeRangePreset.last12Hours.recommendedStep, 300)
        XCTAssertEqual(TimeRangePreset.last1Day.recommendedStep, 3600)
        XCTAssertEqual(TimeRangePreset.last1Week.recommendedStep, 3600)
        XCTAssertEqual(TimeRangePreset.last2Weeks.recommendedStep, 86400)
        XCTAssertEqual(TimeRangePreset.last1Month.recommendedStep, 86400)
    }

    func testTimeRangePresetDisplayNames() {
        XCTAssertEqual(TimeRangePreset.last15Minutes.displayName, "Past 15 minutes")
        XCTAssertEqual(TimeRangePreset.last1Hour.displayName, "Past 1 hour")
        XCTAssertEqual(TimeRangePreset.last12Hours.displayName, "Past 12 hours")
        XCTAssertEqual(TimeRangePreset.last1Day.displayName, "Past 1 day")
        XCTAssertEqual(TimeRangePreset.last1Week.displayName, "Past 1 week")
        XCTAssertEqual(TimeRangePreset.last2Weeks.displayName, "Past 2 weeks")
        XCTAssertEqual(TimeRangePreset.last1Month.displayName, "Past 1 month")
        XCTAssertEqual(TimeRangePreset.custom.displayName, "Custom")
    }

    // MARK: - Dashboard Data Tests

    func testDashboardDataFormattedCost() {
        var data = DashboardData()

        // Small costs show 4 decimal places
        data.totalCost = 0.0012
        XCTAssertEqual(data.formattedCost, "$0.0012")

        // Medium costs show 3 decimal places
        data.totalCost = 0.1234
        XCTAssertEqual(data.formattedCost, "$0.123")

        // Large costs show 2 decimal places
        data.totalCost = 1.5
        XCTAssertEqual(data.formattedCost, "$1.50")
    }

    func testDashboardDataFormattedTokens() {
        var data = DashboardData()

        data.totalTokens = 500
        XCTAssertEqual(data.formattedTokens, "500")

        data.totalTokens = 1500
        XCTAssertEqual(data.formattedTokens, "1.5K")

        data.totalTokens = 1_500_000
        XCTAssertEqual(data.formattedTokens, "1.50M")
    }

    func testDashboardDataFormattedActiveTime() {
        var data = DashboardData()

        data.totalActiveTime = 45
        XCTAssertEqual(data.formattedActiveTime, "45s")

        data.totalActiveTime = 125
        XCTAssertEqual(data.formattedActiveTime, "2m 5s")

        data.totalActiveTime = 3725
        XCTAssertEqual(data.formattedActiveTime, "1h 2m")
    }

    // MARK: - Connection Status Tests

    func testConnectionStatusIsConnected() {
        XCTAssertTrue(ConnectionStatus.connected(version: "2.47.0").isConnected)
        XCTAssertFalse(ConnectionStatus.disconnected(error: "test").isConnected)
        XCTAssertFalse(ConnectionStatus.connecting.isConnected)
        XCTAssertFalse(ConnectionStatus.unknown.isConnected)
    }

    func testConnectionStatusDisplayText() {
        XCTAssertEqual(ConnectionStatus.connected(version: "2.47.0").displayText, "Connected (v2.47.0)")
        XCTAssertEqual(ConnectionStatus.connecting.displayText, "Connecting...")
        XCTAssertEqual(ConnectionStatus.disconnected(error: "timeout").displayText, "Disconnected: timeout")
        XCTAssertEqual(ConnectionStatus.unknown.displayText, "Unknown")
    }
}
