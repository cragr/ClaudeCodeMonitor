# Session Cost Explorer Design

**Date:** 2026-01-07
**Status:** Ready for implementation

## Overview

A new "Sessions" sidebar tab providing session-level cost analysis for budget tracking, session analysis, and cost optimization. Users can view all sessions with sortable metrics, drill into individual sessions for detailed breakdowns, and quickly identify expensive sessions.

## Goals

1. **Budget tracking** - Understand spending patterns across sessions
2. **Session analysis** - Identify which sessions were most expensive and why
3. **Optimization** - Discover expensive patterns to reduce costs

## Non-Goals

- Project-level tracking (no `project` label in telemetry)
- Cost allocation for billing/invoicing

---

## Data Model

### SessionMetrics

```swift
struct SessionMetrics: Identifiable {
    let sessionId: String
    var totalCostUSD: Decimal
    var totalTokens: Int
    var tokensByType: [TokenType: Int]  // input, output, cacheRead, cacheCreation
    var tokensByModel: [String: Int]
    var activeTime: TimeInterval
    var firstSeen: Date?  // approximate from query range
    var lastSeen: Date?

    var id: String { sessionId }
}

extension SessionMetrics {
    var costPerToken: Double? {
        guard totalTokens > 0 else { return nil }
        let cost = (totalCostUSD as NSDecimalNumber).doubleValue
        return cost / Double(totalTokens)
    }

    var costPerMinute: Double? {
        guard activeTime > 0 else { return nil }
        let cost = (totalCostUSD as NSDecimalNumber).doubleValue
        return cost / (activeTime / 60.0)
    }

    var tokensPerMinute: Double? {
        guard activeTime > 0 else { return nil }
        return Double(totalTokens) / (activeTime / 60.0)
    }
}
```

### PromQL Queries

```promql
// Cost per session
sum by (session_id) (increase(claude_code_cost_usage_USD_total[timerange]))

// Tokens per session by type
sum by (session_id, type) (increase(claude_code_token_usage_tokens_total[timerange]))

// Tokens per session by model
sum by (session_id, model) (increase(claude_code_token_usage_tokens_total[timerange]))

// Active time per session
sum by (session_id) (increase(claude_code_active_time_seconds_total[timerange]))
```

**Notes:**
- All queries use consistent `[timerange]` driven by UI time picker
- Top sessions computed client-side (no `topk()` query needed)
- `firstSeen`/`lastSeen` approximated from query range bounds

---

## UI Design

### Sessions Tab Layout

```
+-----------------------------------------------------------+
|  Sessions                              [Time Range v]     |
+-----------------------------------------------------------+
|  TOP SESSIONS (3 cards)                                   |
|  +------------+ +------------+ +------------+             |
|  | Highest    | | Most       | | Longest    |             |
|  | Cost       | | Tokens     | | Duration   |             |
|  | $4.23      | | 1.2M       | | 2h 15m     |             |
|  | sess_abc   | | sess_xyz   | | sess_def   |             |
|  +------------+ +------------+ +------------+             |
+-----------------------------------------------------------+
|  ALL SESSIONS                              [Sort v]       |
|  +-------------------------------------------------------+|
|  | Session ID | Cost  | Tokens | Duration | $/min | Last ||
|  +-------------------------------------------------------+|
|  | sess_abc   | $4.23 | 890K   | 1h 12m   | $0.06 | 5m   ||
|  | sess_xyz   | $2.15 | 1.2M   | 45m      | $0.05 | 1h   ||
|  | sess_def   | $1.89 | 450K   | 2h 15m   | $0.01 | 2d   ||
|  +-------------------------------------------------------+|
+-----------------------------------------------------------+
```

### Detail View (on row click)

```
+-----------------------------------------------------------+
|  < Back              Session: sess_abc123                 |
+-----------------------------------------------------------+
|  SUMMARY                                                  |
|  Cost: $4.23  |  Tokens: 890K  |  Duration: 1h 12m        |
|  $/token: $0.000005  |  tokens/min: 12.3K                 |
|  Active: 2026-01-06 13:02 - 14:14                         |
+-----------------------------------------------------------+
|  TOKENS BY TYPE          |  TOKENS BY MODEL              |
|  +------------------+    |  +------------------+         |
|  | [stacked bar]    |    |  | [horizontal bar] |         |
|  | input: 400K      |    |  | sonnet: 600K     |         |
|  | output: 300K     |    |  | haiku: 290K      |         |
|  | cacheRead: 150K  |    |  |                  |         |
|  | cacheCreate: 40K |    |  |                  |         |
|  +------------------+    |  +------------------+         |
+-----------------------------------------------------------+
```

### Key Interactions

- **Time range picker**: Reuse existing `TimeRangePreset`, triggers full refetch
- **Top cards**: Clickable, navigate directly to detail view
- **Table sorting**: Header-click (macOS native), default Cost desc
- **Columns**: Session ID, Cost, Tokens, Duration, $/min, Last Active
- **Session ID display**: Truncated with tooltip for full ID
- **Filter** (optional): Search by session ID or model name

---

## Implementation

### New Files

```
Sources/
├── Models/
│   └── SessionMetrics.swift          # Model + derived props
├── Services/
│   └── SessionMetricsService.swift   # Fetches & aggregates session data
└── Views/
    ├── SessionsView.swift            # Main tab (list + top cards)
    └── SessionDetailView.swift       # Drill-down detail view
```

### SessionMetricsService

```swift
@MainActor
class SessionMetricsService: ObservableObject {
    @Published var sessions: [SessionMetrics] = []
    @Published var isLoading = false
    @Published var error: SessionFetchError?

    private var lastSuccessfulSessions: [SessionMetrics] = []
    private let client: PrometheusClient

    func fetchSessions(timeRange: TimeRangePreset) async {
        isLoading = true
        error = nil

        let rangeString = timeRange.promQLRange
        var failures: [String] = []

        do {
            async let costResult   = client.query(PromQLQueryBuilder.costBySession(range: rangeString))
            async let typeResult   = client.query(PromQLQueryBuilder.tokensBySessionAndType(range: rangeString))
            async let modelResult  = client.query(PromQLQueryBuilder.tokensBySessionAndModel(range: rangeString))
            async let activeResult = client.query(PromQLQueryBuilder.activeTimeBySession(range: rangeString))

            var cost: [PrometheusMetricResult]?
            var type: [PrometheusMetricResult]?
            var model: [PrometheusMetricResult]?
            var active: [PrometheusMetricResult]?

            do { cost   = try await costResult }   catch { failures.append("cost") }
            do { type   = try await typeResult }   catch { failures.append("tokens by type") }
            do { model  = try await modelResult }  catch { failures.append("tokens by model") }
            do { active = try await activeResult } catch { failures.append("active time") }

            guard cost != nil || type != nil || model != nil || active != nil else {
                throw SessionFetchError.connectionFailed(underlying: NSError(domain: "", code: -1))
            }

            let merged = Self.mergeResults(
                costResult: cost,
                typeResult: type,
                modelResult: model,
                activeResult: active,
                timeRange: timeRange
            )

            if merged.isEmpty {
                error = .noSessions
                sessions = lastSuccessfulSessions
            } else {
                sessions = merged
                lastSuccessfulSessions = merged
                if !failures.isEmpty {
                    error = .partialData(fetched: 4 - failures.count, failed: failures)
                }
            }
        } catch let err as SessionFetchError {
            error = err
            sessions = lastSuccessfulSessions
        } catch {
            error = .connectionFailed(underlying: error)
            sessions = lastSuccessfulSessions
        }

        isLoading = false
    }

    // Top Sessions (computed client-side)
    var highestCostSession: SessionMetrics? {
        sessions.max(by: { $0.totalCostUSD < $1.totalCostUSD })
    }
    var mostTokensSession: SessionMetrics? {
        sessions.max(by: { $0.totalTokens < $1.totalTokens })
    }
    var longestSession: SessionMetrics? {
        sessions.max(by: { $0.activeTime < $1.activeTime })
    }

    static func mergeResults(
        costResult: [PrometheusMetricResult]?,
        typeResult: [PrometheusMetricResult]?,
        modelResult: [PrometheusMetricResult]?,
        activeResult: [PrometheusMetricResult]?,
        timeRange: TimeRangePreset
    ) -> [SessionMetrics] {
        // Implementation: merge by session_id key
        // ...
    }
}
```

### Error Handling

```swift
enum SessionFetchError: LocalizedError {
    case partialData(fetched: Int, failed: [String])
    case noSessions
    case connectionFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .partialData(let fetched, let failed):
            return "Loaded \(fetched) metrics, but failed: \(failed.joined(separator: ", ")). Some charts may be missing."
        case .noSessions:
            return "No sessions found in the selected time range."
        case .connectionFailed:
            return "Unable to reach metrics backend. Please check your connection or try again."
        }
    }
}
```

**View behavior:**
- `sessions.isEmpty && error == .noSessions` → Empty state message
- `sessions.nonEmpty && error != nil` → Non-blocking warning banner
- `error == .connectionFailed` → Error banner with retry button, show `lastSuccessfulSessions`

### Query Builder Additions

```swift
extension PromQLQueryBuilder {
    static func costBySession(range: String) -> String {
        PromQLQueryBuilder(metric: "claude_code_cost_usage_USD_total")
            .increase(range)
            .sum(by: ["session_id"])
            .build()
    }

    static func tokensBySessionAndType(range: String) -> String {
        PromQLQueryBuilder(metric: "claude_code_token_usage_tokens_total")
            .increase(range)
            .sum(by: ["session_id", "type"])
            .build()
    }

    static func tokensBySessionAndModel(range: String) -> String {
        PromQLQueryBuilder(metric: "claude_code_token_usage_tokens_total")
            .increase(range)
            .sum(by: ["session_id", "model"])
            .build()
    }

    static func activeTimeBySession(range: String) -> String {
        PromQLQueryBuilder(metric: "claude_code_active_time_seconds_total")
            .increase(range)
            .sum(by: ["session_id"])
            .build()
    }
}
```

### Integration Points

1. **ContentView.swift** - Add "Sessions" to sidebar navigation
2. **Reuse existing:**
   - `TimeRangePreset` picker
   - Chart components from `InteractiveCharts.swift`
   - Formatting from `NumberFormatting.swift`

---

## Testing

### Unit Tests

| Component | Test Cases |
|-----------|------------|
| `SessionMetrics` derived props | `costPerToken` with zero tokens → nil |
| | `tokensPerMinute` with zero activeTime → nil |
| | Normal case with non-zero values, verify precision |
| `PromQLQueryBuilder` | `costBySession` produces correct PromQL |
| | `tokensBySessionAndType` produces correct PromQL |
| | `tokensBySessionAndModel` produces correct PromQL |
| | `activeTimeBySession` produces correct PromQL |
| `SessionMetricsService.mergeResults` | Merges partial data across sessions |
| | Session with all data populated |
| | Session missing some metrics (cost but no activeTime) |
| | Session from only one query (tokens but no cost) |
| Error paths | All queries fail → `.connectionFailed`, sessions unchanged |
| | Some queries fail → `.partialData`, sessions populated |
| | No sessions returned → `.noSessions` |
| Sort logic | Sort by cost desc (default) |
| | Sort by tokens, duration, $/min, last active |
| Top Sessions | Correct session selected for each category |

### Example: Merge Logic Test

```swift
func testMergeSessionDataFromMultipleQueries() {
    let costResult = [
        PrometheusMetricResult(metric: ["session_id": "A"], value: 1.0),
        PrometheusMetricResult(metric: ["session_id": "B"], value: 2.0),
    ]
    let typeResult = [
        PrometheusMetricResult(metric: ["session_id": "A", "type": "input"], value: 100),
        PrometheusMetricResult(metric: ["session_id": "B", "type": "input"], value: 200),
        PrometheusMetricResult(metric: ["session_id": "C", "type": "input"], value: 300),
    ]
    let modelResult = [
        PrometheusMetricResult(metric: ["session_id": "A", "model": "claude-3.5"], value: 150),
    ]
    let activeResult = [
        PrometheusMetricResult(metric: ["session_id": "A"], value: 60),
        PrometheusMetricResult(metric: ["session_id": "C"], value: 120),
    ]

    let sessions = SessionMetricsService.mergeResults(...)

    // A: has cost, tokens, model, activeTime
    // B: has cost, tokens; missing activeTime, model
    // C: has tokens, activeTime; missing cost
    XCTAssertEqual(Set(sessions.map(\.sessionId)), ["A", "B", "C"])
}
```

---

## Open Questions

None - ready for implementation.

## Future Enhancements

- Manual session tagging/grouping for pseudo-project tracking
- Export session data to CSV
- Session comparison view (side-by-side)
