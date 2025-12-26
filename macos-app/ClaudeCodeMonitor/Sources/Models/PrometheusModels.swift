import Foundation

// MARK: - Prometheus API Response Models

struct PrometheusResponse<T: Decodable>: Decodable {
    let status: String
    let data: T?
    let errorType: String?
    let error: String?

    var isSuccess: Bool { status == "success" }
}

struct PrometheusQueryResult: Decodable {
    let resultType: String
    let result: [PrometheusMetricResult]
}

struct PrometheusMetricResult: Decodable {
    let metric: [String: String]
    let value: PrometheusValue?      // For instant queries
    let values: [PrometheusValue]?   // For range queries

    var metricName: String {
        metric["__name__"] ?? "unknown"
    }
}

struct PrometheusValue: Decodable {
    let timestamp: Double
    let value: String

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        timestamp = try container.decode(Double.self)
        value = try container.decode(String.self)
    }

    var doubleValue: Double? {
        Double(value)
    }

    var date: Date {
        Date(timeIntervalSince1970: timestamp)
    }
}

// MARK: - Build Info Response

struct PrometheusBuildInfo: Decodable {
    let version: String
    let revision: String
    let branch: String
    let buildUser: String
    let buildDate: String
    let goVersion: String
}

// MARK: - Targets Response

struct PrometheusTargetsResult: Decodable {
    let activeTargets: [PrometheusTarget]
    let droppedTargets: [PrometheusTarget]?
}

struct PrometheusTarget: Decodable {
    let labels: [String: String]
    let scrapePool: String?
    let scrapeUrl: String?
    let health: String?
    let lastError: String?
    let lastScrape: String?
}

// MARK: - Label Values Response

struct PrometheusLabelValuesResult: Decodable {
    // Label values endpoint returns array directly in data
}

// MARK: - Metric Metadata

struct PrometheusMetricMetadata: Decodable {
    let type: String
    let help: String
    let unit: String?
}

// MARK: - Query Types

enum PrometheusQueryType {
    case instant
    case range(start: Date, end: Date, step: TimeInterval)
}

// MARK: - Time Range Presets
// Per spec: 15m, 1h, 12h, 1d, 1w, 2w, 1mo
// Bucketing rules:
// - 15 minutes and 1 hour: bucket in MINUTES (1 minute step)
// - 12 hours: bucket in MINUTES (5 minute step)
// - 1 day and 1 week: bucket in HOURS (1 hour step)
// - 2 weeks and 1 month: bucket in DAYS (1 day step)

enum TimeRangePreset: String, CaseIterable, Identifiable {
    case last15Minutes = "15m"
    case last1Hour = "1h"
    case last8Hours = "8h"
    case last12Hours = "12h"
    case last1Day = "1d"
    case last2Days = "2d"
    case last1Week = "1w"
    case last2Weeks = "2w"
    case last1Month = "1mo"
    case custom = "custom"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .last15Minutes: return "Past 15 minutes"
        case .last1Hour: return "Past 1 hour"
        case .last8Hours: return "Past 8 hours"
        case .last12Hours: return "Past 12 hours"
        case .last1Day: return "Past 1 day"
        case .last2Days: return "Past 2 days"
        case .last1Week: return "Past 1 week"
        case .last2Weeks: return "Past 2 weeks"
        case .last1Month: return "Past 1 month"
        case .custom: return "Custom"
        }
    }

    var shortName: String {
        switch self {
        case .last15Minutes: return "15m"
        case .last1Hour: return "1h"
        case .last8Hours: return "8h"
        case .last12Hours: return "12h"
        case .last1Day: return "1d"
        case .last2Days: return "2d"
        case .last1Week: return "1w"
        case .last2Weeks: return "2w"
        case .last1Month: return "1mo"
        case .custom: return "custom"
        }
    }

    var duration: TimeInterval {
        switch self {
        case .last15Minutes: return 15 * 60                    // 900s
        case .last1Hour: return 60 * 60                        // 3600s
        case .last8Hours: return 8 * 60 * 60                   // 28800s
        case .last12Hours: return 12 * 60 * 60                 // 43200s
        case .last1Day: return 24 * 60 * 60                    // 86400s
        case .last2Days: return 2 * 24 * 60 * 60               // 172800s
        case .last1Week: return 7 * 24 * 60 * 60               // 604800s
        case .last2Weeks: return 14 * 24 * 60 * 60             // 1209600s
        case .last1Month: return 30 * 24 * 60 * 60             // 2592000s
        case .custom: return 60 * 60                           // default 1h
        }
    }

    /// Recommended step for range queries based on bucketing rules
    /// - 15m, 1h: 1 minute buckets (60s step)
    /// - 8h, 12h: 5 minute buckets (300s step)
    /// - 1d, 2d, 1w: 1 hour buckets (3600s step)
    /// - 2w, 1mo: 1 day buckets (86400s step)
    var recommendedStep: TimeInterval {
        switch self {
        case .last15Minutes: return 60          // 1 minute buckets
        case .last1Hour: return 60              // 1 minute buckets
        case .last8Hours: return 300            // 5 minute buckets
        case .last12Hours: return 300           // 5 minute buckets
        case .last1Day: return 3600             // 1 hour buckets
        case .last2Days: return 3600            // 1 hour buckets
        case .last1Week: return 3600            // 1 hour buckets
        case .last2Weeks: return 86400          // 1 day buckets
        case .last1Month: return 86400          // 1 day buckets
        case .custom: return 60                 // default 1 minute
        }
    }

    /// Bucket granularity for display purposes
    var bucketGranularity: BucketGranularity {
        switch self {
        case .last15Minutes, .last1Hour, .last8Hours, .last12Hours:
            return .minutes
        case .last1Day, .last2Days, .last1Week:
            return .hours
        case .last2Weeks, .last1Month:
            return .days
        case .custom:
            return .minutes
        }
    }

    /// PromQL range string for increase/rate functions
    var promQLRange: String {
        rawValue
    }

    /// Calculate appropriate step for custom date ranges
    static func stepForDuration(_ duration: TimeInterval) -> TimeInterval {
        switch duration {
        case ..<3600:           // < 1 hour
            return 60           // 1 minute
        case ..<43200:          // < 12 hours
            return 60           // 1 minute
        case ..<86400:          // < 1 day
            return 300          // 5 minutes
        case ..<604800:         // < 1 week
            return 3600         // 1 hour
        default:                // >= 1 week
            return 86400        // 1 day
        }
    }
}

enum BucketGranularity {
    case minutes
    case hours
    case days

    var chartDateFormat: Date.FormatStyle {
        switch self {
        case .minutes:
            return .dateTime.hour().minute()
        case .hours:
            return .dateTime.weekday(.abbreviated).hour()
        case .days:
            return .dateTime.month(.abbreviated).day()
        }
    }
}
