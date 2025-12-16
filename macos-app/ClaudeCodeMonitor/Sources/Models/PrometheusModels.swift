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

enum TimeRangePreset: String, CaseIterable, Identifiable {
    case last5Minutes = "5m"
    case last15Minutes = "15m"
    case last1Hour = "1h"
    case last24Hours = "24h"
    case last7Days = "7d"
    case last30Days = "30d"
    case custom = "custom"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .last5Minutes: return "Last 5 minutes"
        case .last15Minutes: return "Last 15 minutes"
        case .last1Hour: return "Last 1 hour"
        case .last24Hours: return "Last 24 hours"
        case .last7Days: return "Last 7 days"
        case .last30Days: return "Last 30 days"
        case .custom: return "Custom"
        }
    }

    var shortName: String {
        rawValue
    }

    var duration: TimeInterval {
        switch self {
        case .last5Minutes: return 5 * 60
        case .last15Minutes: return 15 * 60
        case .last1Hour: return 60 * 60
        case .last24Hours: return 24 * 60 * 60
        case .last7Days: return 7 * 24 * 60 * 60
        case .last30Days: return 30 * 24 * 60 * 60
        case .custom: return 60 * 60 // default to 1 hour
        }
    }

    var recommendedStep: TimeInterval {
        switch self {
        case .last5Minutes: return 15
        case .last15Minutes: return 15
        case .last1Hour: return 60
        case .last24Hours: return 300
        case .last7Days: return 1800
        case .last30Days: return 3600
        case .custom: return 60
        }
    }
}
