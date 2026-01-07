# Session Cost Explorer Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a Sessions tab to the sidebar that displays session-level cost analysis with sortable list, detail drill-down, and top sessions highlights.

**Architecture:** New `SessionMetrics` model holds per-session aggregated data. `SessionMetricsService` fetches from Prometheus using four queries (cost, tokens by type, tokens by model, active time) grouped by `session_id`, then merges results. Views use existing design system components.

**Tech Stack:** Swift 5.9, SwiftUI, Prometheus PromQL, async/await

---

## Task 1: SessionMetrics Model

**Files:**
- Create: `macos-app/ClaudeCodeMonitor/Sources/Models/SessionMetrics.swift`
- Test: `macos-app/ClaudeCodeMonitorTests/SessionMetricsTests.swift`

**Step 1: Write the failing tests**

Create `macos-app/ClaudeCodeMonitorTests/SessionMetricsTests.swift`:

```swift
import XCTest
@testable import ClaudeCodeMonitor

final class SessionMetricsTests: XCTestCase {

    // MARK: - Derived Properties

    func testCostPerTokenWithValidData() {
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
        XCTAssertEqual(session.costPerToken, 0.001, accuracy: 0.0001)
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

    func testCostPerMinuteWithValidData() {
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
        XCTAssertEqual(session.costPerMinute, 3.0, accuracy: 0.01)
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

    func testTokensPerMinuteWithValidData() {
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
        XCTAssertEqual(session.tokensPerMinute, 3000.0, accuracy: 0.1)
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
```

**Step 2: Run tests to verify they fail**

Run: `cd macos-app && swift test --filter SessionMetricsTests 2>&1 | head -20`
Expected: Compilation error - `SessionMetrics` not found

**Step 3: Write the implementation**

Create `macos-app/ClaudeCodeMonitor/Sources/Models/SessionMetrics.swift`:

```swift
import Foundation

/// Aggregated metrics for a single Claude Code session
struct SessionMetrics: Identifiable {
    let sessionId: String
    var totalCostUSD: Decimal
    var totalTokens: Int
    var tokensByType: [TokenType: Int]
    var tokensByModel: [String: Int]
    var activeTime: TimeInterval
    var firstSeen: Date?
    var lastSeen: Date?

    var id: String { sessionId }
}

// MARK: - Derived Properties

extension SessionMetrics {
    /// Cost per token in USD, nil if no tokens
    var costPerToken: Double? {
        guard totalTokens > 0 else { return nil }
        let cost = (totalCostUSD as NSDecimalNumber).doubleValue
        return cost / Double(totalTokens)
    }

    /// Cost per minute of active time in USD, nil if no active time
    var costPerMinute: Double? {
        guard activeTime > 0 else { return nil }
        let cost = (totalCostUSD as NSDecimalNumber).doubleValue
        return cost / (activeTime / 60.0)
    }

    /// Tokens consumed per minute of active time, nil if no active time
    var tokensPerMinute: Double? {
        guard activeTime > 0 else { return nil }
        return Double(totalTokens) / (activeTime / 60.0)
    }
}

// MARK: - Formatting Helpers

extension SessionMetrics {
    /// Formatted cost string (e.g., "$1.23" or "$0.0045")
    var formattedCost: String {
        let cost = (totalCostUSD as NSDecimalNumber).doubleValue
        if cost >= 1.0 {
            return String(format: "$%.2f", cost)
        } else if cost >= 0.01 {
            return String(format: "$%.3f", cost)
        }
        return String(format: "$%.4f", cost)
    }

    /// Formatted token count (e.g., "1.2M", "890K", "500")
    var formattedTokens: String {
        if totalTokens >= 1_000_000 {
            return String(format: "%.2fM", Double(totalTokens) / 1_000_000)
        } else if totalTokens >= 1_000 {
            return String(format: "%.1fK", Double(totalTokens) / 1_000)
        }
        return "\(totalTokens)"
    }

    /// Formatted active time (e.g., "2h 15m", "45m 30s")
    var formattedActiveTime: String {
        let hours = Int(activeTime) / 3600
        let minutes = (Int(activeTime) % 3600) / 60
        let seconds = Int(activeTime) % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }

    /// Truncated session ID for display (e.g., "sess_abc...xyz")
    var truncatedSessionId: String {
        if sessionId.count <= 16 {
            return sessionId
        }
        let prefix = sessionId.prefix(8)
        let suffix = sessionId.suffix(4)
        return "\(prefix)...\(suffix)"
    }
}
```

**Step 4: Run tests to verify they pass**

Run: `cd macos-app && swift test --filter SessionMetricsTests`
Expected: All 7 tests pass

**Step 5: Commit**

```bash
git add macos-app/ClaudeCodeMonitor/Sources/Models/SessionMetrics.swift macos-app/ClaudeCodeMonitorTests/SessionMetricsTests.swift
git commit -m "feat(sessions): add SessionMetrics model with derived properties"
```

---

## Task 2: PromQL Query Builder Extensions

**Files:**
- Modify: `macos-app/ClaudeCodeMonitor/Sources/Services/PrometheusClient.swift`
- Modify: `macos-app/ClaudeCodeMonitorTests/PrometheusClientTests.swift`

**Step 1: Write the failing tests**

Add to `macos-app/ClaudeCodeMonitorTests/PrometheusClientTests.swift`:

```swift
// MARK: - Session Queries

func testCostBySessionQuery() {
    let query = PromQLQueryBuilder.costBySession(range: "24h")
    XCTAssertEqual(
        query,
        "sum by (session_id) (increase(claude_code_cost_usage_USD_total[24h]))"
    )
}

func testTokensBySessionAndTypeQuery() {
    let query = PromQLQueryBuilder.tokensBySessionAndType(range: "24h")
    XCTAssertEqual(
        query,
        "sum by (session_id,type) (increase(claude_code_token_usage_tokens_total[24h]))"
    )
}

func testTokensBySessionAndModelQuery() {
    let query = PromQLQueryBuilder.tokensBySessionAndModel(range: "24h")
    XCTAssertEqual(
        query,
        "sum by (session_id,model) (increase(claude_code_token_usage_tokens_total[24h]))"
    )
}

func testActiveTimeBySessionQuery() {
    let query = PromQLQueryBuilder.activeTimeBySession(range: "24h")
    XCTAssertEqual(
        query,
        "sum by (session_id) (increase(claude_code_active_time_seconds_total[24h]))"
    )
}
```

**Step 2: Run tests to verify they fail**

Run: `cd macos-app && swift test --filter "testCostBySessionQuery|testTokensBySessionAndTypeQuery|testTokensBySessionAndModelQuery|testActiveTimeBySessionQuery" 2>&1 | head -20`
Expected: Compilation error - methods not found

**Step 3: Write the implementation**

Add to `macos-app/ClaudeCodeMonitor/Sources/Services/PrometheusClient.swift` in the `PromQLQueryBuilder` extension (after the existing query methods):

```swift
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
```

**Step 4: Run tests to verify they pass**

Run: `cd macos-app && swift test --filter PrometheusClientTests`
Expected: All 32 tests pass (28 existing + 4 new)

**Step 5: Commit**

```bash
git add macos-app/ClaudeCodeMonitor/Sources/Services/PrometheusClient.swift macos-app/ClaudeCodeMonitorTests/PrometheusClientTests.swift
git commit -m "feat(sessions): add PromQL query builders for session-level metrics"
```

---

## Task 3: SessionFetchError Enum

**Files:**
- Create: `macos-app/ClaudeCodeMonitor/Sources/Services/SessionMetricsService.swift` (partial)
- Modify: `macos-app/ClaudeCodeMonitorTests/SessionMetricsTests.swift`

**Step 1: Write the failing tests**

Add to `macos-app/ClaudeCodeMonitorTests/SessionMetricsTests.swift`:

```swift
// MARK: - SessionFetchError Tests

func testPartialDataErrorDescription() {
    let error = SessionFetchError.partialData(fetched: 3, failed: ["cost", "active time"])
    XCTAssertTrue(error.errorDescription?.contains("3 metrics") ?? false)
    XCTAssertTrue(error.errorDescription?.contains("cost") ?? false)
    XCTAssertTrue(error.errorDescription?.contains("active time") ?? false)
}

func testNoSessionsErrorDescription() {
    let error = SessionFetchError.noSessions
    XCTAssertTrue(error.errorDescription?.contains("No sessions") ?? false)
}

func testConnectionFailedErrorDescription() {
    let underlyingError = NSError(domain: "test", code: -1, userInfo: nil)
    let error = SessionFetchError.connectionFailed(underlying: underlyingError)
    XCTAssertTrue(error.errorDescription?.contains("Unable to reach") ?? false)
}
```

**Step 2: Run tests to verify they fail**

Run: `cd macos-app && swift test --filter "testPartialDataErrorDescription|testNoSessionsErrorDescription|testConnectionFailedErrorDescription" 2>&1 | head -20`
Expected: Compilation error - `SessionFetchError` not found

**Step 3: Write the implementation**

Create `macos-app/ClaudeCodeMonitor/Sources/Services/SessionMetricsService.swift`:

```swift
import Foundation

// MARK: - Error Types

enum SessionFetchError: LocalizedError {
    case partialData(fetched: Int, failed: [String])
    case noSessions
    case connectionFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .partialData(let fetched, let failed):
            return "Loaded \(fetched) metrics queries, but failed: \(failed.joined(separator: ", ")). Some charts may be missing."
        case .noSessions:
            return "No sessions found in the selected time range."
        case .connectionFailed:
            return "Unable to reach metrics backend. Please check your connection or try again."
        }
    }
}
```

**Step 4: Run tests to verify they pass**

Run: `cd macos-app && swift test --filter SessionMetricsTests`
Expected: All 10 tests pass (7 existing + 3 new)

**Step 5: Commit**

```bash
git add macos-app/ClaudeCodeMonitor/Sources/Services/SessionMetricsService.swift macos-app/ClaudeCodeMonitorTests/SessionMetricsTests.swift
git commit -m "feat(sessions): add SessionFetchError enum"
```

---

## Task 4: SessionMetricsService - Merge Logic

**Files:**
- Modify: `macos-app/ClaudeCodeMonitor/Sources/Services/SessionMetricsService.swift`
- Create: `macos-app/ClaudeCodeMonitorTests/SessionMetricsServiceTests.swift`

**Step 1: Write the failing tests**

Create `macos-app/ClaudeCodeMonitorTests/SessionMetricsServiceTests.swift`:

```swift
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

// Test helper extension for creating PrometheusValue
extension PrometheusValue {
    init(timestamp: Double, valueString: String) {
        self.timestamp = timestamp
        self.value = valueString
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `cd macos-app && swift test --filter SessionMetricsServiceTests 2>&1 | head -30`
Expected: Compilation error - `mergeResults` method not found

**Step 3: Write the implementation**

Add to `macos-app/ClaudeCodeMonitor/Sources/Services/SessionMetricsService.swift`:

```swift
// MARK: - Merge Logic

extension SessionMetricsService {
    /// Merge results from multiple Prometheus queries into SessionMetrics array
    static func mergeResults(
        costResults: [PrometheusMetricResult],
        typeResults: [PrometheusMetricResult],
        modelResults: [PrometheusMetricResult],
        activeResults: [PrometheusMetricResult]
    ) -> [SessionMetrics] {
        // Collect all unique session IDs
        var sessionIds = Set<String>()
        for result in costResults + typeResults + modelResults + activeResults {
            if let sessionId = result.metric["session_id"], !sessionId.isEmpty {
                sessionIds.insert(sessionId)
            }
        }

        // Build sessions dictionary
        var sessionsDict: [String: SessionMetrics] = [:]
        for sessionId in sessionIds {
            sessionsDict[sessionId] = SessionMetrics(
                sessionId: sessionId,
                totalCostUSD: Decimal(0),
                totalTokens: 0,
                tokensByType: [:],
                tokensByModel: [:],
                activeTime: 0,
                firstSeen: nil,
                lastSeen: nil
            )
        }

        // Populate cost
        for result in costResults {
            guard let sessionId = result.metric["session_id"],
                  let value = result.value?.doubleValue else { continue }
            sessionsDict[sessionId]?.totalCostUSD = Decimal(value)
        }

        // Populate tokens by type
        for result in typeResults {
            guard let sessionId = result.metric["session_id"],
                  let typeStr = result.metric["type"],
                  let tokenType = TokenType(rawValue: typeStr),
                  let value = result.value?.doubleValue else { continue }
            let intValue = Int(value)
            sessionsDict[sessionId]?.tokensByType[tokenType] = intValue
            sessionsDict[sessionId]?.totalTokens += intValue
        }

        // Populate tokens by model
        for result in modelResults {
            guard let sessionId = result.metric["session_id"],
                  let model = result.metric["model"],
                  let value = result.value?.doubleValue else { continue }
            sessionsDict[sessionId]?.tokensByModel[model] = Int(value)
        }

        // Populate active time
        for result in activeResults {
            guard let sessionId = result.metric["session_id"],
                  let value = result.value?.doubleValue else { continue }
            sessionsDict[sessionId]?.activeTime = value
        }

        return Array(sessionsDict.values).sorted { $0.sessionId < $1.sessionId }
    }
}

// Placeholder class for compilation (will be expanded in next task)
@MainActor
class SessionMetricsService: ObservableObject {
    @Published var sessions: [SessionMetrics] = []
    @Published var isLoading = false
    @Published var error: SessionFetchError?
}
```

**Step 4: Run tests to verify they pass**

Run: `cd macos-app && swift test --filter SessionMetricsServiceTests`
Expected: All 4 tests pass

**Step 5: Commit**

```bash
git add macos-app/ClaudeCodeMonitor/Sources/Services/SessionMetricsService.swift macos-app/ClaudeCodeMonitorTests/SessionMetricsServiceTests.swift
git commit -m "feat(sessions): add SessionMetricsService merge logic"
```

---

## Task 5: SessionMetricsService - Fetch Implementation

**Files:**
- Modify: `macos-app/ClaudeCodeMonitor/Sources/Services/SessionMetricsService.swift`

**Step 1: Review current implementation**

The service needs `fetchSessions` method and computed properties for top sessions.

**Step 2: Write the full service implementation**

Update `macos-app/ClaudeCodeMonitor/Sources/Services/SessionMetricsService.swift` to replace the placeholder class:

```swift
import Foundation

// MARK: - Error Types

enum SessionFetchError: LocalizedError {
    case partialData(fetched: Int, failed: [String])
    case noSessions
    case connectionFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .partialData(let fetched, let failed):
            return "Loaded \(fetched) metrics queries, but failed: \(failed.joined(separator: ", ")). Some charts may be missing."
        case .noSessions:
            return "No sessions found in the selected time range."
        case .connectionFailed:
            return "Unable to reach metrics backend. Please check your connection or try again."
        }
    }
}

// MARK: - Service

@MainActor
class SessionMetricsService: ObservableObject {
    @Published var sessions: [SessionMetrics] = []
    @Published var isLoading = false
    @Published var error: SessionFetchError?

    private var lastSuccessfulSessions: [SessionMetrics] = []
    private let client: PrometheusClient

    init(client: PrometheusClient) {
        self.client = client
    }

    // MARK: - Top Sessions (computed client-side)

    var highestCostSession: SessionMetrics? {
        sessions.max(by: { $0.totalCostUSD < $1.totalCostUSD })
    }

    var mostTokensSession: SessionMetrics? {
        sessions.max(by: { $0.totalTokens < $1.totalTokens })
    }

    var longestSession: SessionMetrics? {
        sessions.max(by: { $0.activeTime < $1.activeTime })
    }

    // MARK: - Fetch

    func fetchSessions(timeRange: TimeRangePreset) async {
        isLoading = true
        error = nil

        let rangeString = timeRange.promQLRange
        var failures: [String] = []

        var costResults: [PrometheusMetricResult]?
        var typeResults: [PrometheusMetricResult]?
        var modelResults: [PrometheusMetricResult]?
        var activeResults: [PrometheusMetricResult]?

        // Fetch all queries concurrently
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                do {
                    costResults = try await self.client.query(PromQLQueryBuilder.costBySession(range: rangeString))
                } catch {
                    failures.append("cost")
                }
            }
            group.addTask {
                do {
                    typeResults = try await self.client.query(PromQLQueryBuilder.tokensBySessionAndType(range: rangeString))
                } catch {
                    failures.append("tokens by type")
                }
            }
            group.addTask {
                do {
                    modelResults = try await self.client.query(PromQLQueryBuilder.tokensBySessionAndModel(range: rangeString))
                } catch {
                    failures.append("tokens by model")
                }
            }
            group.addTask {
                do {
                    activeResults = try await self.client.query(PromQLQueryBuilder.activeTimeBySession(range: rangeString))
                } catch {
                    failures.append("active time")
                }
            }
        }

        // Check for total failure
        if costResults == nil && typeResults == nil && modelResults == nil && activeResults == nil {
            error = .connectionFailed(underlying: NSError(domain: "SessionMetricsService", code: -1))
            sessions = lastSuccessfulSessions
            isLoading = false
            return
        }

        // Merge results
        let merged = Self.mergeResults(
            costResults: costResults ?? [],
            typeResults: typeResults ?? [],
            modelResults: modelResults ?? [],
            activeResults: activeResults ?? []
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

        isLoading = false
    }
}

// MARK: - Merge Logic

extension SessionMetricsService {
    /// Merge results from multiple Prometheus queries into SessionMetrics array
    static func mergeResults(
        costResults: [PrometheusMetricResult],
        typeResults: [PrometheusMetricResult],
        modelResults: [PrometheusMetricResult],
        activeResults: [PrometheusMetricResult]
    ) -> [SessionMetrics] {
        // Collect all unique session IDs
        var sessionIds = Set<String>()
        for result in costResults + typeResults + modelResults + activeResults {
            if let sessionId = result.metric["session_id"], !sessionId.isEmpty {
                sessionIds.insert(sessionId)
            }
        }

        // Build sessions dictionary
        var sessionsDict: [String: SessionMetrics] = [:]
        for sessionId in sessionIds {
            sessionsDict[sessionId] = SessionMetrics(
                sessionId: sessionId,
                totalCostUSD: Decimal(0),
                totalTokens: 0,
                tokensByType: [:],
                tokensByModel: [:],
                activeTime: 0,
                firstSeen: nil,
                lastSeen: nil
            )
        }

        // Populate cost
        for result in costResults {
            guard let sessionId = result.metric["session_id"],
                  let value = result.value?.doubleValue else { continue }
            sessionsDict[sessionId]?.totalCostUSD = Decimal(value)
        }

        // Populate tokens by type
        for result in typeResults {
            guard let sessionId = result.metric["session_id"],
                  let typeStr = result.metric["type"],
                  let tokenType = TokenType(rawValue: typeStr),
                  let value = result.value?.doubleValue else { continue }
            let intValue = Int(value)
            sessionsDict[sessionId]?.tokensByType[tokenType] = intValue
            sessionsDict[sessionId]?.totalTokens += intValue
        }

        // Populate tokens by model
        for result in modelResults {
            guard let sessionId = result.metric["session_id"],
                  let model = result.metric["model"],
                  let value = result.value?.doubleValue else { continue }
            sessionsDict[sessionId]?.tokensByModel[model] = Int(value)
        }

        // Populate active time
        for result in activeResults {
            guard let sessionId = result.metric["session_id"],
                  let value = result.value?.doubleValue else { continue }
            sessionsDict[sessionId]?.activeTime = value
        }

        return Array(sessionsDict.values).sorted { $0.sessionId < $1.sessionId }
    }
}
```

**Step 3: Build and run all tests**

Run: `cd macos-app && swift build && swift test`
Expected: Build succeeds, all tests pass

**Step 4: Commit**

```bash
git add macos-app/ClaudeCodeMonitor/Sources/Services/SessionMetricsService.swift
git commit -m "feat(sessions): complete SessionMetricsService with fetch and top sessions"
```

---

## Task 6: SessionsView - Main View Structure

**Files:**
- Create: `macos-app/ClaudeCodeMonitor/Sources/Views/SessionsView.swift`

**Step 1: Create the view file**

Create `macos-app/ClaudeCodeMonitor/Sources/Views/SessionsView.swift`:

```swift
import SwiftUI

struct SessionsView: View {
    @StateObject private var service: SessionMetricsService
    @EnvironmentObject private var settings: SettingsManager
    @State private var selectedTimeRange: TimeRangePreset = .last1Day
    @State private var sortOrder: SessionSortOrder = .costDesc
    @State private var selectedSession: SessionMetrics?

    init(client: PrometheusClient) {
        _service = StateObject(wrappedValue: SessionMetricsService(client: client))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with time range picker
                headerView

                Divider()

                if service.isLoading && service.sessions.isEmpty {
                    loadingView
                } else if service.sessions.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Top Sessions Cards
                            topSessionsSection

                            // Error banner (non-blocking)
                            if let error = service.error, !service.sessions.isEmpty {
                                warningBanner(error: error)
                            }

                            // All Sessions Table
                            allSessionsSection
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Sessions")
            .navigationDestination(item: $selectedSession) { session in
                SessionDetailView(session: session)
            }
            .task {
                await service.fetchSessions(timeRange: selectedTimeRange)
            }
            .onChange(of: selectedTimeRange) { _, newValue in
                Task {
                    await service.fetchSessions(timeRange: newValue)
                }
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Text("Sessions")
                .font(.title2)
                .fontWeight(.semibold)

            Spacer()

            Picker("Time Range", selection: $selectedTimeRange) {
                ForEach(TimeRangePreset.allCases.filter { $0 != .custom }, id: \.self) { preset in
                    Text(preset.displayName).tag(preset)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 150)

            if service.isLoading {
                ProgressView()
                    .scaleEffect(0.7)
                    .padding(.leading, 8)
            }
        }
        .padding()
    }

    // MARK: - Loading & Empty States

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading sessions...")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Sessions Found")
                .font(.title3)
                .fontWeight(.medium)

            Text(service.error?.errorDescription ?? "No session data available for the selected time range.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Refresh") {
                Task {
                    await service.fetchSessions(timeRange: selectedTimeRange)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Warning Banner

    private func warningBanner(error: SessionFetchError) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)

            Text(error.errorDescription ?? "Some data couldn't be loaded")
                .font(.callout)

            Spacer()

            Button("Retry") {
                Task {
                    await service.fetchSessions(timeRange: selectedTimeRange)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Top Sessions

    private var topSessionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TOP SESSIONS")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                if let session = service.highestCostSession {
                    TopSessionCard(
                        title: "Highest Cost",
                        value: session.formattedCost,
                        sessionId: session.truncatedSessionId,
                        icon: "dollarsign.circle.fill",
                        color: .green
                    ) {
                        selectedSession = session
                    }
                }

                if let session = service.mostTokensSession {
                    TopSessionCard(
                        title: "Most Tokens",
                        value: session.formattedTokens,
                        sessionId: session.truncatedSessionId,
                        icon: "number.circle.fill",
                        color: .blue
                    ) {
                        selectedSession = session
                    }
                }

                if let session = service.longestSession {
                    TopSessionCard(
                        title: "Longest Duration",
                        value: session.formattedActiveTime,
                        sessionId: session.truncatedSessionId,
                        icon: "clock.fill",
                        color: .orange
                    ) {
                        selectedSession = session
                    }
                }
            }
        }
    }

    // MARK: - All Sessions Table

    private var allSessionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("ALL SESSIONS")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Spacer()

                Picker("Sort by", selection: $sortOrder) {
                    ForEach(SessionSortOrder.allCases, id: \.self) { order in
                        Text(order.displayName).tag(order)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 140)
            }

            SessionsTableView(
                sessions: sortedSessions,
                onSelect: { session in
                    selectedSession = session
                }
            )
        }
    }

    private var sortedSessions: [SessionMetrics] {
        switch sortOrder {
        case .costDesc:
            return service.sessions.sorted { $0.totalCostUSD > $1.totalCostUSD }
        case .costAsc:
            return service.sessions.sorted { $0.totalCostUSD < $1.totalCostUSD }
        case .tokensDesc:
            return service.sessions.sorted { $0.totalTokens > $1.totalTokens }
        case .tokensAsc:
            return service.sessions.sorted { $0.totalTokens < $1.totalTokens }
        case .durationDesc:
            return service.sessions.sorted { $0.activeTime > $1.activeTime }
        case .durationAsc:
            return service.sessions.sorted { $0.activeTime < $1.activeTime }
        case .costPerMinDesc:
            return service.sessions.sorted { ($0.costPerMinute ?? 0) > ($1.costPerMinute ?? 0) }
        }
    }
}

// MARK: - Sort Order

enum SessionSortOrder: String, CaseIterable {
    case costDesc = "cost_desc"
    case costAsc = "cost_asc"
    case tokensDesc = "tokens_desc"
    case tokensAsc = "tokens_asc"
    case durationDesc = "duration_desc"
    case durationAsc = "duration_asc"
    case costPerMinDesc = "cost_per_min_desc"

    var displayName: String {
        switch self {
        case .costDesc: return "Cost (High → Low)"
        case .costAsc: return "Cost (Low → High)"
        case .tokensDesc: return "Tokens (High → Low)"
        case .tokensAsc: return "Tokens (Low → High)"
        case .durationDesc: return "Duration (Long → Short)"
        case .durationAsc: return "Duration (Short → Long)"
        case .costPerMinDesc: return "$/min (High → Low)"
        }
    }
}

// MARK: - Top Session Card

struct TopSessionCard: View {
    let title: String
    let value: String
    let sessionId: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .foregroundStyle(color)
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)

                Text(sessionId)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.windowBackgroundColor))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Sessions Table

struct SessionsTableView: View {
    let sessions: [SessionMetrics]
    let onSelect: (SessionMetrics) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Session ID")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Cost")
                    .frame(width: 80, alignment: .trailing)
                Text("Tokens")
                    .frame(width: 80, alignment: .trailing)
                Text("Duration")
                    .frame(width: 80, alignment: .trailing)
                Text("$/min")
                    .frame(width: 70, alignment: .trailing)
            }
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.windowBackgroundColor))

            Divider()

            // Rows
            ForEach(sessions) { session in
                Button {
                    onSelect(session)
                } label: {
                    HStack {
                        Text(session.truncatedSessionId)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .help(session.sessionId) // Tooltip with full ID

                        Text(session.formattedCost)
                            .frame(width: 80, alignment: .trailing)

                        Text(session.formattedTokens)
                            .frame(width: 80, alignment: .trailing)

                        Text(session.formattedActiveTime)
                            .frame(width: 80, alignment: .trailing)

                        Text(session.costPerMinute.map { String(format: "$%.3f", $0) } ?? "-")
                            .frame(width: 70, alignment: .trailing)
                    }
                    .font(.callout)
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Divider()
            }
        }
        .background(Color(.textBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}
```

**Step 2: Build to verify compilation**

Run: `cd macos-app && swift build`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add macos-app/ClaudeCodeMonitor/Sources/Views/SessionsView.swift
git commit -m "feat(sessions): add SessionsView with top sessions cards and table"
```

---

## Task 7: SessionDetailView

**Files:**
- Create: `macos-app/ClaudeCodeMonitor/Sources/Views/SessionDetailView.swift`

**Step 1: Create the detail view**

Create `macos-app/ClaudeCodeMonitor/Sources/Views/SessionDetailView.swift`:

```swift
import SwiftUI
import Charts

struct SessionDetailView: View {
    let session: SessionMetrics

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Summary Section
                summarySection

                Divider()

                // Charts Section
                HStack(alignment: .top, spacing: 24) {
                    tokensByTypeChart
                    tokensByModelChart
                }
            }
            .padding()
        }
        .navigationTitle("Session: \(session.truncatedSessionId)")
    }

    // MARK: - Summary Section

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("SUMMARY")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            // Main metrics row
            HStack(spacing: 32) {
                SummaryMetric(label: "Cost", value: session.formattedCost, icon: "dollarsign.circle")
                SummaryMetric(label: "Tokens", value: session.formattedTokens, icon: "number.circle")
                SummaryMetric(label: "Duration", value: session.formattedActiveTime, icon: "clock")
            }

            Divider()

            // Derived metrics row
            HStack(spacing: 32) {
                SummaryMetric(
                    label: "$/token",
                    value: session.costPerToken.map { String(format: "$%.6f", $0) } ?? "-",
                    icon: "function"
                )
                SummaryMetric(
                    label: "tokens/min",
                    value: session.tokensPerMinute.map { formatNumber($0) } ?? "-",
                    icon: "gauge.with.needle"
                )
                SummaryMetric(
                    label: "$/min",
                    value: session.costPerMinute.map { String(format: "$%.4f", $0) } ?? "-",
                    icon: "chart.line.uptrend.xyaxis"
                )
            }

            // Session ID (full)
            HStack {
                Text("Session ID:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(session.sessionId)
                    .font(.caption)
                    .fontDesign(.monospaced)
                    .textSelection(.enabled)

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(session.sessionId, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .help("Copy session ID")
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Tokens by Type Chart

    private var tokensByTypeChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TOKENS BY TYPE")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            if session.tokensByType.isEmpty {
                noDataPlaceholder
            } else {
                Chart {
                    ForEach(tokenTypeData, id: \.type) { item in
                        BarMark(
                            x: .value("Tokens", item.count),
                            y: .value("Type", item.type.displayName)
                        )
                        .foregroundStyle(colorForTokenType(item.type))
                        .annotation(position: .trailing) {
                            Text(formatNumber(Double(item.count)))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(position: .bottom)
                }
                .frame(height: CGFloat(session.tokensByType.count) * 40 + 40)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.windowBackgroundColor))
        .cornerRadius(12)
    }

    private var tokenTypeData: [(type: TokenType, count: Int)] {
        TokenType.allCases.compactMap { type in
            guard let count = session.tokensByType[type], count > 0 else { return nil }
            return (type, count)
        }.sorted { $0.count > $1.count }
    }

    private func colorForTokenType(_ type: TokenType) -> Color {
        switch type {
        case .input: return .blue
        case .output: return .green
        case .cacheRead: return .orange
        case .cacheCreation: return .purple
        }
    }

    // MARK: - Tokens by Model Chart

    private var tokensByModelChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TOKENS BY MODEL")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            if session.tokensByModel.isEmpty {
                noDataPlaceholder
            } else {
                Chart {
                    ForEach(modelData, id: \.model) { item in
                        BarMark(
                            x: .value("Tokens", item.count),
                            y: .value("Model", item.displayName)
                        )
                        .foregroundStyle(.teal)
                        .annotation(position: .trailing) {
                            Text(formatNumber(Double(item.count)))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(position: .bottom)
                }
                .frame(height: CGFloat(session.tokensByModel.count) * 40 + 40)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.windowBackgroundColor))
        .cornerRadius(12)
    }

    private var modelData: [(model: String, displayName: String, count: Int)] {
        session.tokensByModel.map { (model, count) in
            let displayName = formatModelName(model)
            return (model, displayName, count)
        }.sorted { $0.count > $1.count }
    }

    private func formatModelName(_ model: String) -> String {
        // Shorten common model names for display
        if model.contains("claude-3-5-sonnet") {
            return "Sonnet 3.5"
        } else if model.contains("claude-3-5-haiku") {
            return "Haiku 3.5"
        } else if model.contains("claude-3-opus") {
            return "Opus 3"
        } else if model.contains("sonnet") {
            return "Sonnet"
        } else if model.contains("haiku") {
            return "Haiku"
        } else if model.contains("opus") {
            return "Opus"
        }
        return model
    }

    // MARK: - Helpers

    private var noDataPlaceholder: some View {
        Text("No data available")
            .font(.callout)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, minHeight: 80)
    }

    private func formatNumber(_ value: Double) -> String {
        if value >= 1_000_000 {
            return String(format: "%.2fM", value / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "%.1fK", value / 1_000)
        }
        return String(format: "%.0f", value)
    }
}

// MARK: - Summary Metric

struct SummaryMetric: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(label)
                    .font(.caption)
            }
            .foregroundStyle(.secondary)

            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
        }
    }
}
```

**Step 2: Build to verify compilation**

Run: `cd macos-app && swift build`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add macos-app/ClaudeCodeMonitor/Sources/Views/SessionDetailView.swift
git commit -m "feat(sessions): add SessionDetailView with summary and charts"
```

---

## Task 8: Integrate Sessions Tab into Navigation

**Files:**
- Modify: `macos-app/ClaudeCodeMonitor/Sources/Views/ContentView.swift`

**Step 1: Read current ContentView**

Run: `head -100 macos-app/ClaudeCodeMonitor/Sources/Views/ContentView.swift`

**Step 2: Add Sessions to sidebar navigation**

Add `sessions` case to the `NavigationItem` enum and add the `SessionsView` to the navigation.

Look for the `NavigationItem` enum and add:
```swift
case sessions
```

Look for the sidebar `List` and add:
```swift
NavigationLink(value: NavigationItem.sessions) {
    Label("Sessions", systemImage: "list.bullet.rectangle")
}
```

Look for the `navigationDestination` and add:
```swift
case .sessions:
    SessionsView(client: appState.prometheusClient)
```

**Step 3: Build and run to verify**

Run: `cd macos-app && swift build`
Expected: Build succeeds

**Step 4: Commit**

```bash
git add macos-app/ClaudeCodeMonitor/Sources/Views/ContentView.swift
git commit -m "feat(sessions): integrate Sessions tab into sidebar navigation"
```

---

## Task 9: Run Full Test Suite

**Step 1: Run all tests**

Run: `cd macos-app && swift test`
Expected: All tests pass (existing + new)

**Step 2: Run build**

Run: `cd macos-app && swift build -c release`
Expected: Release build succeeds

**Step 3: Final commit if any cleanup needed**

```bash
git status
# If clean, proceed to verification
```

---

## Task 10: Manual Verification

**Step 1: Launch the app**

Run: `cd macos-app && swift run ClaudeCodeMonitor`

**Step 2: Verify functionality**

- [ ] Sessions tab appears in sidebar
- [ ] Time range picker works
- [ ] Top Sessions cards display (if data available)
- [ ] Sessions table displays and sorts
- [ ] Clicking a session navigates to detail view
- [ ] Detail view shows summary and charts
- [ ] Back navigation works
- [ ] Empty state shows when no sessions

**Step 3: Document any issues**

If issues found, create additional tasks to fix them.

---

## Summary

| Task | Description | Files |
|------|-------------|-------|
| 1 | SessionMetrics model | Model + Tests |
| 2 | PromQL query builders | PrometheusClient + Tests |
| 3 | SessionFetchError enum | Service + Tests |
| 4 | Merge logic | Service + Tests |
| 5 | Fetch implementation | Service |
| 6 | SessionsView | View |
| 7 | SessionDetailView | View |
| 8 | Navigation integration | ContentView |
| 9 | Full test suite | All |
| 10 | Manual verification | Runtime |

**Estimated commits:** 8
**Test coverage:** Model derived props, query builders, merge logic, error handling
