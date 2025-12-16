import XCTest
@testable import ClaudeCodeMonitor

/// Tests for time range presets and bucketing rules
/// Per spec:
/// - 15 minutes and 1 hour: bucket in MINUTES (1 minute step)
/// - 12 hours: bucket in MINUTES (5 minute step)
/// - 1 day and 1 week: bucket in HOURS (1 hour step)
/// - 2 weeks and 1 month: bucket in DAYS (1 day step)
final class TimeRangeBucketingTests: XCTestCase {

    // MARK: - Time Range Preset Tests

    func testAllPresetsExist() {
        let presets = TimeRangePreset.allCases
        XCTAssertTrue(presets.contains(.last15Minutes))
        XCTAssertTrue(presets.contains(.last1Hour))
        XCTAssertTrue(presets.contains(.last12Hours))
        XCTAssertTrue(presets.contains(.last1Day))
        XCTAssertTrue(presets.contains(.last1Week))
        XCTAssertTrue(presets.contains(.last2Weeks))
        XCTAssertTrue(presets.contains(.last1Month))
        XCTAssertTrue(presets.contains(.custom))
    }

    // MARK: - Duration Tests

    func testLast15MinutesDuration() {
        XCTAssertEqual(TimeRangePreset.last15Minutes.duration, 15 * 60)
    }

    func testLast1HourDuration() {
        XCTAssertEqual(TimeRangePreset.last1Hour.duration, 60 * 60)
    }

    func testLast12HoursDuration() {
        XCTAssertEqual(TimeRangePreset.last12Hours.duration, 12 * 60 * 60)
    }

    func testLast1DayDuration() {
        XCTAssertEqual(TimeRangePreset.last1Day.duration, 24 * 60 * 60)
    }

    func testLast1WeekDuration() {
        XCTAssertEqual(TimeRangePreset.last1Week.duration, 7 * 24 * 60 * 60)
    }

    func testLast2WeeksDuration() {
        XCTAssertEqual(TimeRangePreset.last2Weeks.duration, 14 * 24 * 60 * 60)
    }

    func testLast1MonthDuration() {
        XCTAssertEqual(TimeRangePreset.last1Month.duration, 30 * 24 * 60 * 60)
    }

    // MARK: - Step/Bucketing Tests (Core requirement)

    func testLast15MinutesUsesMinuteBuckets() {
        // 15 minutes should use 1 minute step (60 seconds)
        XCTAssertEqual(TimeRangePreset.last15Minutes.recommendedStep, 60)
        XCTAssertEqual(TimeRangePreset.last15Minutes.bucketGranularity, .minutes)
    }

    func testLast1HourUsesMinuteBuckets() {
        // 1 hour should use 1 minute step (60 seconds)
        XCTAssertEqual(TimeRangePreset.last1Hour.recommendedStep, 60)
        XCTAssertEqual(TimeRangePreset.last1Hour.bucketGranularity, .minutes)
    }

    func testLast12HoursUses5MinuteBuckets() {
        // 12 hours should use 5 minute step (300 seconds)
        XCTAssertEqual(TimeRangePreset.last12Hours.recommendedStep, 300)
        XCTAssertEqual(TimeRangePreset.last12Hours.bucketGranularity, .minutes)
    }

    func testLast1DayUsesHourBuckets() {
        // 1 day should use 1 hour step (3600 seconds)
        XCTAssertEqual(TimeRangePreset.last1Day.recommendedStep, 3600)
        XCTAssertEqual(TimeRangePreset.last1Day.bucketGranularity, .hours)
    }

    func testLast1WeekUsesHourBuckets() {
        // 1 week should use 1 hour step (3600 seconds)
        XCTAssertEqual(TimeRangePreset.last1Week.recommendedStep, 3600)
        XCTAssertEqual(TimeRangePreset.last1Week.bucketGranularity, .hours)
    }

    func testLast2WeeksUsesDayBuckets() {
        // 2 weeks should use 1 day step (86400 seconds)
        XCTAssertEqual(TimeRangePreset.last2Weeks.recommendedStep, 86400)
        XCTAssertEqual(TimeRangePreset.last2Weeks.bucketGranularity, .days)
    }

    func testLast1MonthUsesDayBuckets() {
        // 1 month should use 1 day step (86400 seconds)
        XCTAssertEqual(TimeRangePreset.last1Month.recommendedStep, 86400)
        XCTAssertEqual(TimeRangePreset.last1Month.bucketGranularity, .days)
    }

    // MARK: - PromQL Range String Tests

    func testPromQLRangeStrings() {
        XCTAssertEqual(TimeRangePreset.last15Minutes.promQLRange, "15m")
        XCTAssertEqual(TimeRangePreset.last1Hour.promQLRange, "1h")
        XCTAssertEqual(TimeRangePreset.last12Hours.promQLRange, "12h")
        XCTAssertEqual(TimeRangePreset.last1Day.promQLRange, "1d")
        XCTAssertEqual(TimeRangePreset.last1Week.promQLRange, "1w")
        XCTAssertEqual(TimeRangePreset.last2Weeks.promQLRange, "2w")
        XCTAssertEqual(TimeRangePreset.last1Month.promQLRange, "1mo")
    }

    // MARK: - Display Name Tests

    func testDisplayNames() {
        XCTAssertEqual(TimeRangePreset.last15Minutes.displayName, "Past 15 minutes")
        XCTAssertEqual(TimeRangePreset.last1Hour.displayName, "Past 1 hour")
        XCTAssertEqual(TimeRangePreset.last12Hours.displayName, "Past 12 hours")
        XCTAssertEqual(TimeRangePreset.last1Day.displayName, "Past 1 day")
        XCTAssertEqual(TimeRangePreset.last1Week.displayName, "Past 1 week")
        XCTAssertEqual(TimeRangePreset.last2Weeks.displayName, "Past 2 weeks")
        XCTAssertEqual(TimeRangePreset.last1Month.displayName, "Past 1 month")
        XCTAssertEqual(TimeRangePreset.custom.displayName, "Custom")
    }

    // MARK: - stepForDuration Tests

    func testStepForDurationUnder1Hour() {
        // Duration < 1 hour should use 1 minute step
        XCTAssertEqual(TimeRangePreset.stepForDuration(30 * 60), 60)
        XCTAssertEqual(TimeRangePreset.stepForDuration(45 * 60), 60)
    }

    func testStepForDurationUnder12Hours() {
        // Duration < 12 hours should use 1 minute step
        XCTAssertEqual(TimeRangePreset.stepForDuration(2 * 60 * 60), 60)
        XCTAssertEqual(TimeRangePreset.stepForDuration(6 * 60 * 60), 60)
    }

    func testStepForDurationUnder1Day() {
        // Duration >= 12 hours but < 1 day should use 5 minute step
        XCTAssertEqual(TimeRangePreset.stepForDuration(12 * 60 * 60), 300)
        XCTAssertEqual(TimeRangePreset.stepForDuration(18 * 60 * 60), 300)
    }

    func testStepForDurationUnder1Week() {
        // Duration >= 1 day but < 1 week should use 1 hour step
        XCTAssertEqual(TimeRangePreset.stepForDuration(24 * 60 * 60), 3600)
        XCTAssertEqual(TimeRangePreset.stepForDuration(3 * 24 * 60 * 60), 3600)
    }

    func testStepForDurationOver1Week() {
        // Duration >= 1 week should use 1 day step
        XCTAssertEqual(TimeRangePreset.stepForDuration(7 * 24 * 60 * 60), 86400)
        XCTAssertEqual(TimeRangePreset.stepForDuration(14 * 24 * 60 * 60), 86400)
        XCTAssertEqual(TimeRangePreset.stepForDuration(30 * 24 * 60 * 60), 86400)
    }

    // MARK: - Bucket Granularity Chart Format Tests

    func testMinuteGranularityChartFormat() {
        let format = BucketGranularity.minutes.chartDateFormat
        // Just verify it compiles and returns a format
        XCTAssertNotNil(format)
    }

    func testHourGranularityChartFormat() {
        let format = BucketGranularity.hours.chartDateFormat
        XCTAssertNotNil(format)
    }

    func testDayGranularityChartFormat() {
        let format = BucketGranularity.days.chartDateFormat
        XCTAssertNotNil(format)
    }

    // MARK: - Non-Oversampling Verification Tests

    func testNoOversamplingFor15Minutes() {
        // 15 minutes / 1 minute step = 15 data points (reasonable)
        let dataPoints = TimeRangePreset.last15Minutes.duration / TimeRangePreset.last15Minutes.recommendedStep
        XCTAssertEqual(dataPoints, 15)
        XCTAssertLessThanOrEqual(dataPoints, 100, "Should not oversample")
    }

    func testNoOversamplingFor1Hour() {
        // 1 hour / 1 minute step = 60 data points (reasonable)
        let dataPoints = TimeRangePreset.last1Hour.duration / TimeRangePreset.last1Hour.recommendedStep
        XCTAssertEqual(dataPoints, 60)
        XCTAssertLessThanOrEqual(dataPoints, 100, "Should not oversample")
    }

    func testNoOversamplingFor12Hours() {
        // 12 hours / 5 minute step = 144 data points (reasonable)
        let dataPoints = TimeRangePreset.last12Hours.duration / TimeRangePreset.last12Hours.recommendedStep
        XCTAssertEqual(dataPoints, 144)
        XCTAssertLessThanOrEqual(dataPoints, 200, "Should not oversample")
    }

    func testNoOversamplingFor1Day() {
        // 1 day / 1 hour step = 24 data points (reasonable)
        let dataPoints = TimeRangePreset.last1Day.duration / TimeRangePreset.last1Day.recommendedStep
        XCTAssertEqual(dataPoints, 24)
        XCTAssertLessThanOrEqual(dataPoints, 100, "Should not oversample")
    }

    func testNoOversamplingFor1Week() {
        // 1 week / 1 hour step = 168 data points (reasonable)
        let dataPoints = TimeRangePreset.last1Week.duration / TimeRangePreset.last1Week.recommendedStep
        XCTAssertEqual(dataPoints, 168)
        XCTAssertLessThanOrEqual(dataPoints, 200, "Should not oversample")
    }

    func testNoOversamplingFor2Weeks() {
        // 2 weeks / 1 day step = 14 data points (reasonable)
        let dataPoints = TimeRangePreset.last2Weeks.duration / TimeRangePreset.last2Weeks.recommendedStep
        XCTAssertEqual(dataPoints, 14)
        XCTAssertLessThanOrEqual(dataPoints, 100, "Should not oversample")
    }

    func testNoOversamplingFor1Month() {
        // 1 month / 1 day step = 30 data points (reasonable)
        let dataPoints = TimeRangePreset.last1Month.duration / TimeRangePreset.last1Month.recommendedStep
        XCTAssertEqual(dataPoints, 30)
        XCTAssertLessThanOrEqual(dataPoints, 100, "Should not oversample")
    }
}
