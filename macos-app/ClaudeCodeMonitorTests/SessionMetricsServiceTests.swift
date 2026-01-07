import XCTest
@testable import ClaudeCodeMonitor

final class SessionMetricsServiceTests: XCTestCase {

    // MARK: - Merge Logic Tests

    func testMergeWithAllDataPresent() {
        let costResults = [
            mockResult(sessionId: "A", value: 1.5),
            mockResult(sessionId: "B", value: 2.0),
        ]
        let typeResults = [
            mockResult(sessionId: "A", value: 100, extraLabels: ["type": "input"]),
            mockResult(sessionId: "A", value: 50, extraLabels: ["type": "output"]),
            mockResult(sessionId: "B", value: 200, extraLabels: ["type": "input"]),
        ]
        let modelResults = [
            mockResult(sessionId: "A", value: 150, extraLabels: ["model": "claude-3-5-sonnet"]),
            mockResult(sessionId: "B", value: 200, extraLabels: ["model": "claude-3-5-sonnet"]),
        ]
        let activeResults = [
            mockResult(sessionId: "A", value: 60),
            mockResult(sessionId: "B", value: 120),
        ]

        let sessions = SessionMetricsService.mergeResults(
            costResults: costResults,
            typeResults: typeResults,
            modelResults: modelResults,
            activeResults: activeResults
        )

        XCTAssertEqual(sessions.count, 2)

        let sessionA = sessions.first { $0.sessionId == "A" }!
        XCTAssertEqual(sessionA.totalCostUSD, Decimal(string: "1.5"))
        XCTAssertEqual(sessionA.totalTokens, 150) // 100 input + 50 output
        XCTAssertEqual(sessionA.tokensByType[.input], 100)
        XCTAssertEqual(sessionA.tokensByType[.output], 50)
        XCTAssertEqual(sessionA.tokensByModel["claude-3-5-sonnet"], 150)
        XCTAssertEqual(sessionA.activeTime, 60)

        let sessionB = sessions.first { $0.sessionId == "B" }!
        XCTAssertEqual(sessionB.totalCostUSD, Decimal(string: "2.0"))
        XCTAssertEqual(sessionB.totalTokens, 200)
        XCTAssertEqual(sessionB.activeTime, 120)
    }

    func testMergeWithPartialData() {
        // Session C only has tokens, no cost or active time
        let costResults = [
            mockResult(sessionId: "A", value: 1.0),
        ]
        let typeResults = [
            mockResult(sessionId: "A", value: 100, extraLabels: ["type": "input"]),
            mockResult(sessionId: "C", value: 300, extraLabels: ["type": "input"]),
        ]
        let modelResults: [PrometheusMetricResult] = []
        let activeResults = [
            mockResult(sessionId: "C", value: 180),
        ]

        let sessions = SessionMetricsService.mergeResults(
            costResults: costResults,
            typeResults: typeResults,
            modelResults: modelResults,
            activeResults: activeResults
        )

        XCTAssertEqual(sessions.count, 2)

        let sessionA = sessions.first { $0.sessionId == "A" }!
        XCTAssertEqual(sessionA.totalCostUSD, Decimal(string: "1.0"))
        XCTAssertEqual(sessionA.totalTokens, 100)
        XCTAssertEqual(sessionA.activeTime, 0) // No active time data

        let sessionC = sessions.first { $0.sessionId == "C" }!
        XCTAssertEqual(sessionC.totalCostUSD, Decimal(0)) // No cost data
        XCTAssertEqual(sessionC.totalTokens, 300)
        XCTAssertEqual(sessionC.activeTime, 180)
    }

    func testMergeWithEmptyResults() {
        let sessions = SessionMetricsService.mergeResults(
            costResults: [],
            typeResults: [],
            modelResults: [],
            activeResults: []
        )

        XCTAssertTrue(sessions.isEmpty)
    }

    func testMergeWithAllTokenTypes() {
        let typeResults = [
            mockResult(sessionId: "A", value: 100, extraLabels: ["type": "input"]),
            mockResult(sessionId: "A", value: 50, extraLabels: ["type": "output"]),
            mockResult(sessionId: "A", value: 200, extraLabels: ["type": "cacheRead"]),
            mockResult(sessionId: "A", value: 25, extraLabels: ["type": "cacheCreation"]),
        ]

        let sessions = SessionMetricsService.mergeResults(
            costResults: [],
            typeResults: typeResults,
            modelResults: [],
            activeResults: []
        )

        let session = sessions.first!
        XCTAssertEqual(session.tokensByType[.input], 100)
        XCTAssertEqual(session.tokensByType[.output], 50)
        XCTAssertEqual(session.tokensByType[.cacheRead], 200)
        XCTAssertEqual(session.tokensByType[.cacheCreation], 25)
        XCTAssertEqual(session.totalTokens, 375)
    }

    // MARK: - Helpers

    private func mockResult(sessionId: String, value: Double, extraLabels: [String: String] = [:]) -> PrometheusMetricResult {
        var labels = ["session_id": sessionId]
        labels.merge(extraLabels) { _, new in new }
        return PrometheusMetricResult(
            metric: labels,
            value: PrometheusValue(timestamp: Date().timeIntervalSince1970, valueString: String(value)),
            values: nil
        )
    }
}
