import XCTest
@testable import ClaudeCodeMonitor

final class SessionMetricsTests: XCTestCase {

    // MARK: - Derived Properties

    func testCostPerTokenWithValidData() throws {
        let session = SessionMetrics(
            sessionId: "test-session",
            totalCostUSD: Decimal(string: "1.00")!,
            totalTokens: 1000,
            tokensByType: [:],
            tokensByModel: [:],
            activeTime: 60,
            firstSeen: nil,
            lastSeen: nil
        )
        let costPerToken = try XCTUnwrap(session.costPerToken)
        XCTAssertEqual(costPerToken, 0.001, accuracy: 0.0001)
    }

    func testCostPerTokenWithZeroTokens() {
        let session = SessionMetrics(
            sessionId: "test-session",
            totalCostUSD: Decimal(string: "1.00")!,
            totalTokens: 0,
            tokensByType: [:],
            tokensByModel: [:],
            activeTime: 60,
            firstSeen: nil,
            lastSeen: nil
        )
        XCTAssertNil(session.costPerToken)
    }

    func testCostPerMinuteWithValidData() throws {
        let session = SessionMetrics(
            sessionId: "test-session",
            totalCostUSD: Decimal(string: "6.00")!,
            totalTokens: 1000,
            tokensByType: [:],
            tokensByModel: [:],
            activeTime: 120, // 2 minutes
            firstSeen: nil,
            lastSeen: nil
        )
        let costPerMinute = try XCTUnwrap(session.costPerMinute)
        XCTAssertEqual(costPerMinute, 3.0, accuracy: 0.01)
    }

    func testCostPerMinuteWithZeroActiveTime() {
        let session = SessionMetrics(
            sessionId: "test-session",
            totalCostUSD: Decimal(string: "1.00")!,
            totalTokens: 1000,
            tokensByType: [:],
            tokensByModel: [:],
            activeTime: 0,
            firstSeen: nil,
            lastSeen: nil
        )
        XCTAssertNil(session.costPerMinute)
    }

    func testTokensPerMinuteWithValidData() throws {
        let session = SessionMetrics(
            sessionId: "test-session",
            totalCostUSD: Decimal(string: "1.00")!,
            totalTokens: 6000,
            tokensByType: [:],
            tokensByModel: [:],
            activeTime: 120, // 2 minutes
            firstSeen: nil,
            lastSeen: nil
        )
        let tokensPerMinute = try XCTUnwrap(session.tokensPerMinute)
        XCTAssertEqual(tokensPerMinute, 3000.0, accuracy: 0.1)
    }

    func testTokensPerMinuteWithZeroActiveTime() {
        let session = SessionMetrics(
            sessionId: "test-session",
            totalCostUSD: Decimal(string: "1.00")!,
            totalTokens: 1000,
            tokensByType: [:],
            tokensByModel: [:],
            activeTime: 0,
            firstSeen: nil,
            lastSeen: nil
        )
        XCTAssertNil(session.tokensPerMinute)
    }

    func testIdentifiable() {
        let session = SessionMetrics(
            sessionId: "unique-id-123",
            totalCostUSD: Decimal(0),
            totalTokens: 0,
            tokensByType: [:],
            tokensByModel: [:],
            activeTime: 0,
            firstSeen: nil,
            lastSeen: nil
        )
        XCTAssertEqual(session.id, "unique-id-123")
    }
}
