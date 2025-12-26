import XCTest
@testable import ClaudeCodeMonitor

final class StatsCacheComparisonTests: XCTestCase {

    // MARK: - Period Comparison

    func testWeekOverWeekComparison() {
        let stats = createMockStatsCache()
        let comparison = stats.weekOverWeekComparison()

        XCTAssertNotNil(comparison)
        XCTAssertGreaterThanOrEqual(comparison!.currentMessages, 0)
        XCTAssertGreaterThanOrEqual(comparison!.previousMessages, 0)
    }

    func testPercentageChangeCalculation() {
        XCTAssertEqual(PeriodComparison.percentageChange(from: 100, to: 150)!, 50.0, accuracy: 0.01)
        XCTAssertEqual(PeriodComparison.percentageChange(from: 100, to: 50)!, -50.0, accuracy: 0.01)
        XCTAssertNil(PeriodComparison.percentageChange(from: 0, to: 100)) // Avoid division by zero
        XCTAssertEqual(PeriodComparison.percentageChange(from: 100, to: 100)!, 0.0, accuracy: 0.01)
    }

    func testStreakCalculation() {
        let stats = createMockStatsCache()
        let streak = stats.currentStreak()
        XCTAssertGreaterThanOrEqual(streak, 0)
    }

    func testMonthOverMonthComparison() {
        let stats = createMockStatsCache()
        let comparison = stats.monthOverMonthComparison()
        XCTAssertNotNil(comparison)
    }

    func testPeriodComparisonWithCustomDays() {
        let stats = createMockStatsCache()
        let comparison = stats.periodComparison(currentDays: 7, previousDays: 7)
        XCTAssertNotNil(comparison)
    }

    // MARK: - Helper

    private func createMockStatsCache() -> StatsCache {
        let today = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        // Create 14 days of activity with deterministic values
        let dailyActivity = (0..<14).map { daysAgo -> DailyActivity in
            let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: today)!
            return DailyActivity(
                date: formatter.string(from: date),
                messageCount: 100 + daysAgo * 10,  // Deterministic: 100, 110, 120, ...
                sessionCount: 5,
                toolCallCount: 50
            )
        }

        // Create matching dailyModelTokens data
        let dailyModelTokens = (0..<14).map { daysAgo -> DailyModelTokens in
            let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: today)!
            return DailyModelTokens(
                date: formatter.string(from: date),
                tokensByModel: ["claude-sonnet-4": 10000 + daysAgo * 1000]  // Deterministic
            )
        }

        return StatsCache(
            version: 1,
            lastComputedDate: ISO8601DateFormatter().string(from: today),
            dailyActivity: dailyActivity,
            dailyModelTokens: dailyModelTokens,
            modelUsage: [:],
            totalSessions: 50,
            totalMessages: 1000,
            longestSession: nil,
            firstSessionDate: nil,
            hourCounts: [:]
        )
    }
}
