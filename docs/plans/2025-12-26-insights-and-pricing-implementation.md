# Insights View & Pricing Presets Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add an Insights view showing usage comparisons and trends, configurable pricing providers, and extended time range options.

**Architecture:** New `InsightsView` reads from existing `StatsCacheLoader`, computes period comparisons using new methods on `StatsCache`, and displays in Terminal Noir aesthetic. `PricingProvider` enum centralizes model pricing with provider-specific rates. Extended `TimeRangePreset` adds new presets and custom date range support.

**Tech Stack:** SwiftUI, Swift Charts, UserDefaults (via SettingsManager)

---

## Task 1: Create PricingProvider Model

**Files:**
- Create: `macos-app/ClaudeCodeMonitor/Sources/Models/PricingProvider.swift`
- Test: `macos-app/ClaudeCodeMonitorTests/PricingProviderTests.swift`

**Step 1: Write the failing test**

Create `macos-app/ClaudeCodeMonitorTests/PricingProviderTests.swift`:

```swift
import XCTest
@testable import ClaudeCodeMonitor

final class PricingProviderTests: XCTestCase {

    // MARK: - Provider Cases

    func testAllProviderCases() {
        let providers = PricingProvider.allCases
        XCTAssertEqual(providers.count, 3)
        XCTAssertTrue(providers.contains(.anthropic))
        XCTAssertTrue(providers.contains(.awsBedrock))
        XCTAssertTrue(providers.contains(.googleVertex))
    }

    func testProviderDisplayNames() {
        XCTAssertEqual(PricingProvider.anthropic.displayName, "Anthropic")
        XCTAssertEqual(PricingProvider.awsBedrock.displayName, "AWS Bedrock")
        XCTAssertEqual(PricingProvider.googleVertex.displayName, "Google Vertex AI")
    }

    // MARK: - Anthropic Pricing

    func testAnthropicOpus45Pricing() {
        let pricing = PricingProvider.anthropic.pricing(for: "claude-opus-4-5")
        XCTAssertEqual(pricing.input, 5.0)
        XCTAssertEqual(pricing.output, 25.0)
        XCTAssertEqual(pricing.cacheRead, 0.50)
        XCTAssertEqual(pricing.cacheWrite, 6.25)
    }

    func testAnthropicSonnet45Pricing() {
        let pricing = PricingProvider.anthropic.pricing(for: "claude-sonnet-4-5")
        XCTAssertEqual(pricing.input, 3.0)
        XCTAssertEqual(pricing.output, 15.0)
        XCTAssertEqual(pricing.cacheRead, 0.30)
        XCTAssertEqual(pricing.cacheWrite, 3.75)
    }

    func testAnthropicHaiku45Pricing() {
        let pricing = PricingProvider.anthropic.pricing(for: "claude-haiku-4-5")
        XCTAssertEqual(pricing.input, 1.0)
        XCTAssertEqual(pricing.output, 5.0)
        XCTAssertEqual(pricing.cacheRead, 0.10)
        XCTAssertEqual(pricing.cacheWrite, 1.25)
    }

    // MARK: - Google Vertex Pricing (10% premium)

    func testVertexOpus45Pricing() {
        let pricing = PricingProvider.googleVertex.pricing(for: "claude-opus-4-5")
        XCTAssertEqual(pricing.input, 5.50)
        XCTAssertEqual(pricing.output, 27.50)
        XCTAssertEqual(pricing.cacheRead, 0.55)
        XCTAssertEqual(pricing.cacheWrite, 6.875)
    }

    func testVertexSonnet45Pricing() {
        let pricing = PricingProvider.googleVertex.pricing(for: "claude-sonnet-4-5")
        XCTAssertEqual(pricing.input, 3.30)
        XCTAssertEqual(pricing.output, 16.50)
        XCTAssertEqual(pricing.cacheRead, 0.33)
        XCTAssertEqual(pricing.cacheWrite, 4.125)
    }

    // MARK: - Cost Calculation

    func testCostCalculation() {
        let cost = PricingProvider.anthropic.calculateCost(
            model: "claude-sonnet-4-5",
            inputTokens: 1_000_000,
            outputTokens: 500_000,
            cacheReadTokens: 200_000,
            cacheWriteTokens: 100_000
        )
        // $3 input + $7.50 output + $0.06 cache read + $0.375 cache write = $10.935
        XCTAssertEqual(cost, 10.935, accuracy: 0.001)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `cd macos-app && swift test --filter PricingProviderTests 2>&1 | head -20`
Expected: Compilation error "cannot find 'PricingProvider' in scope"

**Step 3: Write minimal implementation**

Create `macos-app/ClaudeCodeMonitor/Sources/Models/PricingProvider.swift`:

```swift
import Foundation

// MARK: - Pricing Provider

enum PricingProvider: String, CaseIterable, Codable {
    case anthropic = "anthropic"
    case awsBedrock = "aws_bedrock"
    case googleVertex = "google_vertex"

    var displayName: String {
        switch self {
        case .anthropic: return "Anthropic"
        case .awsBedrock: return "AWS Bedrock"
        case .googleVertex: return "Google Vertex AI"
        }
    }

    // MARK: - Model Pricing (per 1M tokens)

    struct ModelPricing {
        let input: Double
        let output: Double
        let cacheRead: Double
        let cacheWrite: Double
    }

    func pricing(for modelName: String) -> ModelPricing {
        let baseModel = normalizeModelName(modelName)
        let basePricing = basePricing(for: baseModel)

        switch self {
        case .anthropic, .awsBedrock:
            return basePricing
        case .googleVertex:
            // Google Vertex is ~10% premium
            return ModelPricing(
                input: basePricing.input * 1.10,
                output: basePricing.output * 1.10,
                cacheRead: basePricing.cacheRead * 1.10,
                cacheWrite: basePricing.cacheWrite * 1.10
            )
        }
    }

    private func basePricing(for model: String) -> ModelPricing {
        switch model {
        case "opus-4-5", "opus-4.5":
            return ModelPricing(input: 5.0, output: 25.0, cacheRead: 0.50, cacheWrite: 6.25)
        case "opus-4-1", "opus-4.1", "opus-4-0", "opus-4.0", "opus":
            return ModelPricing(input: 15.0, output: 75.0, cacheRead: 1.50, cacheWrite: 18.75)
        case "sonnet-4-5", "sonnet-4.5":
            return ModelPricing(input: 3.0, output: 15.0, cacheRead: 0.30, cacheWrite: 3.75)
        case "sonnet-4", "sonnet-3-5", "sonnet-3.5", "sonnet":
            return ModelPricing(input: 3.0, output: 15.0, cacheRead: 0.30, cacheWrite: 3.75)
        case "haiku-4-5", "haiku-4.5":
            return ModelPricing(input: 1.0, output: 5.0, cacheRead: 0.10, cacheWrite: 1.25)
        case "haiku-3-5", "haiku-3.5", "haiku":
            return ModelPricing(input: 0.80, output: 4.0, cacheRead: 0.08, cacheWrite: 1.0)
        default:
            // Default to Sonnet pricing
            return ModelPricing(input: 3.0, output: 15.0, cacheRead: 0.30, cacheWrite: 3.75)
        }
    }

    private func normalizeModelName(_ name: String) -> String {
        let lowercased = name.lowercased()

        if lowercased.contains("opus-4-5") || lowercased.contains("opus-4.5") {
            return "opus-4-5"
        } else if lowercased.contains("opus-4-1") || lowercased.contains("opus-4.1") {
            return "opus-4-1"
        } else if lowercased.contains("opus") {
            return "opus"
        } else if lowercased.contains("sonnet-4-5") || lowercased.contains("sonnet-4.5") {
            return "sonnet-4-5"
        } else if lowercased.contains("sonnet") {
            return "sonnet"
        } else if lowercased.contains("haiku-4-5") || lowercased.contains("haiku-4.5") {
            return "haiku-4-5"
        } else if lowercased.contains("haiku-3-5") || lowercased.contains("haiku-3.5") {
            return "haiku-3-5"
        } else if lowercased.contains("haiku") {
            return "haiku"
        }
        return "sonnet" // default
    }

    // MARK: - Cost Calculation

    func calculateCost(
        model: String,
        inputTokens: Int,
        outputTokens: Int,
        cacheReadTokens: Int,
        cacheWriteTokens: Int
    ) -> Double {
        let p = pricing(for: model)
        let inputCost = Double(inputTokens) / 1_000_000 * p.input
        let outputCost = Double(outputTokens) / 1_000_000 * p.output
        let cacheReadCost = Double(cacheReadTokens) / 1_000_000 * p.cacheRead
        let cacheWriteCost = Double(cacheWriteTokens) / 1_000_000 * p.cacheWrite
        return inputCost + outputCost + cacheReadCost + cacheWriteCost
    }
}
```

**Step 4: Run test to verify it passes**

Run: `cd macos-app && swift test --filter PricingProviderTests`
Expected: All tests pass

**Step 5: Commit**

```bash
git add macos-app/ClaudeCodeMonitor/Sources/Models/PricingProvider.swift macos-app/ClaudeCodeMonitorTests/PricingProviderTests.swift
git commit -m "feat: add PricingProvider model with Anthropic, Bedrock, Vertex pricing"
```

---

## Task 2: Add Extended Time Range Presets

**Files:**
- Modify: `macos-app/ClaudeCodeMonitor/Sources/Models/PrometheusModels.swift` (TimeRangePreset enum)
- Modify: `macos-app/ClaudeCodeMonitorTests/TimeRangeBucketingTests.swift`

**Step 1: Write the failing tests**

Add to `macos-app/ClaudeCodeMonitorTests/TimeRangeBucketingTests.swift`:

```swift
// MARK: - New Presets

func testLast8HoursDuration() {
    XCTAssertEqual(TimeRangePreset.last8Hours.duration, 8 * 3600)
}

func testLast8HoursUses5MinuteBuckets() {
    XCTAssertEqual(TimeRangePreset.last8Hours.step, 300)
}

func testLast2DaysDuration() {
    XCTAssertEqual(TimeRangePreset.last2Days.duration, 2 * 24 * 3600)
}

func testLast2DaysUsesHourBuckets() {
    XCTAssertEqual(TimeRangePreset.last2Days.step, 3600)
}

func testCustomRangeDisplayName() {
    XCTAssertEqual(TimeRangePreset.custom.displayName, "Custom")
}

func testNewPresetsDisplayNames() {
    XCTAssertEqual(TimeRangePreset.last8Hours.displayName, "Last 8 Hours")
    XCTAssertEqual(TimeRangePreset.last2Days.displayName, "Last 2 Days")
}
```

**Step 2: Run test to verify it fails**

Run: `cd macos-app && swift test --filter TimeRangeBucketingTests 2>&1 | head -30`
Expected: Compilation error "type 'TimeRangePreset' has no member 'last8Hours'"

**Step 3: Add new cases to TimeRangePreset**

In `macos-app/ClaudeCodeMonitor/Sources/Models/PrometheusModels.swift`, find the `TimeRangePreset` enum and add:

```swift
enum TimeRangePreset: String, CaseIterable, Codable {
    case last15Minutes = "15m"
    case last1Hour = "1h"
    case last8Hours = "8h"      // NEW
    case last12Hours = "12h"
    case last1Day = "1d"
    case last2Days = "2d"       // NEW
    case last1Week = "1w"
    case last2Weeks = "2w"
    case last1Month = "1M"
    case custom = "custom"      // NEW

    var displayName: String {
        switch self {
        case .last15Minutes: return "Last 15 Minutes"
        case .last1Hour: return "Last 1 Hour"
        case .last8Hours: return "Last 8 Hours"
        case .last12Hours: return "Last 12 Hours"
        case .last1Day: return "Last 1 Day"
        case .last2Days: return "Last 2 Days"
        case .last1Week: return "Last 1 Week"
        case .last2Weeks: return "Last 2 Weeks"
        case .last1Month: return "Last 1 Month"
        case .custom: return "Custom"
        }
    }

    var duration: TimeInterval {
        switch self {
        case .last15Minutes: return 15 * 60
        case .last1Hour: return 3600
        case .last8Hours: return 8 * 3600
        case .last12Hours: return 12 * 3600
        case .last1Day: return 24 * 3600
        case .last2Days: return 2 * 24 * 3600
        case .last1Week: return 7 * 24 * 3600
        case .last2Weeks: return 14 * 24 * 3600
        case .last1Month: return 30 * 24 * 3600
        case .custom: return 0 // Custom uses explicit dates
        }
    }

    var step: Int {
        switch self {
        case .last15Minutes: return 60
        case .last1Hour: return 60
        case .last8Hours: return 300
        case .last12Hours: return 300
        case .last1Day: return 3600
        case .last2Days: return 3600
        case .last1Week: return 3600
        case .last2Weeks: return 86400
        case .last1Month: return 86400
        case .custom: return 3600 // Default, will be calculated
        }
    }

    // ... rest of existing implementation
}
```

**Step 4: Run test to verify it passes**

Run: `cd macos-app && swift test --filter TimeRangeBucketingTests`
Expected: All tests pass

**Step 5: Commit**

```bash
git add macos-app/ClaudeCodeMonitor/Sources/Models/PrometheusModels.swift macos-app/ClaudeCodeMonitorTests/TimeRangeBucketingTests.swift
git commit -m "feat: add Last 8 Hours, Last 2 Days, and Custom time range presets"
```

---

## Task 3: Add StatsCache Comparison Methods

**Files:**
- Modify: `macos-app/ClaudeCodeMonitor/Sources/Models/StatsCache.swift`
- Create: `macos-app/ClaudeCodeMonitorTests/StatsCacheComparisonTests.swift`

**Step 1: Write the failing tests**

Create `macos-app/ClaudeCodeMonitorTests/StatsCacheComparisonTests.swift`:

```swift
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
        XCTAssertEqual(PeriodComparison.percentageChange(from: 100, to: 150), 50.0, accuracy: 0.01)
        XCTAssertEqual(PeriodComparison.percentageChange(from: 100, to: 50), -50.0, accuracy: 0.01)
        XCTAssertEqual(PeriodComparison.percentageChange(from: 0, to: 100), nil) // Avoid division by zero
        XCTAssertEqual(PeriodComparison.percentageChange(from: 100, to: 100), 0.0, accuracy: 0.01)
    }

    func testStreakCalculation() {
        let stats = createMockStatsCache()
        let streak = stats.currentStreak()
        XCTAssertGreaterThanOrEqual(streak, 0)
    }

    // MARK: - Helper

    private func createMockStatsCache() -> StatsCache {
        let today = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let dailyActivity = (0..<14).map { daysAgo -> DailyActivity in
            let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: today)!
            return DailyActivity(
                date: formatter.string(from: date),
                messageCount: Int.random(in: 50...200),
                sessionCount: Int.random(in: 2...10),
                toolCallCount: Int.random(in: 20...100)
            )
        }

        return StatsCache(
            version: 1,
            lastComputedDate: ISO8601DateFormatter().string(from: today),
            dailyActivity: dailyActivity,
            dailyModelTokens: [],
            modelUsage: [:],
            totalSessions: 50,
            totalMessages: 1000,
            longestSession: nil,
            firstSessionDate: nil,
            hourCounts: [:]
        )
    }
}
```

**Step 2: Run test to verify it fails**

Run: `cd macos-app && swift test --filter StatsCacheComparisonTests 2>&1 | head -20`
Expected: Compilation error "value of type 'StatsCache' has no member 'weekOverWeekComparison'"

**Step 3: Add comparison methods to StatsCache**

Add to `macos-app/ClaudeCodeMonitor/Sources/Models/StatsCache.swift`:

```swift
// MARK: - Period Comparison

struct PeriodComparison {
    let currentMessages: Int
    let previousMessages: Int
    let currentSessions: Int
    let previousSessions: Int
    let currentTokens: Int
    let previousTokens: Int

    var messagesChange: Double? {
        PeriodComparison.percentageChange(from: previousMessages, to: currentMessages)
    }

    var sessionsChange: Double? {
        PeriodComparison.percentageChange(from: previousSessions, to: currentSessions)
    }

    var tokensChange: Double? {
        PeriodComparison.percentageChange(from: previousTokens, to: currentTokens)
    }

    static func percentageChange(from previous: Int, to current: Int) -> Double? {
        guard previous > 0 else { return nil }
        return Double(current - previous) / Double(previous) * 100
    }
}

extension StatsCache {

    func weekOverWeekComparison() -> PeriodComparison? {
        periodComparison(currentDays: 7, previousDays: 7)
    }

    func monthOverMonthComparison() -> PeriodComparison? {
        periodComparison(currentDays: 30, previousDays: 30)
    }

    func periodComparison(currentDays: Int, previousDays: Int) -> PeriodComparison? {
        let today = Date()
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        // Current period
        let currentStart = calendar.date(byAdding: .day, value: -currentDays, to: today)!
        let currentActivities = dailyActivity.filter { activity in
            guard let date = activity.parsedDate else { return false }
            return date >= currentStart && date <= today
        }

        // Previous period
        let previousStart = calendar.date(byAdding: .day, value: -(currentDays + previousDays), to: today)!
        let previousEnd = calendar.date(byAdding: .day, value: -currentDays - 1, to: today)!
        let previousActivities = dailyActivity.filter { activity in
            guard let date = activity.parsedDate else { return false }
            return date >= previousStart && date <= previousEnd
        }

        let currentMessages = currentActivities.reduce(0) { $0 + $1.messageCount }
        let previousMessages = previousActivities.reduce(0) { $0 + $1.messageCount }
        let currentSessions = currentActivities.reduce(0) { $0 + $1.sessionCount }
        let previousSessions = previousActivities.reduce(0) { $0 + $1.sessionCount }

        // Tokens from dailyModelTokens
        let currentTokens = dailyModelTokens.filter { tokens in
            guard let date = tokens.parsedDate else { return false }
            return date >= currentStart && date <= today
        }.reduce(0) { $0 + $1.totalTokens }

        let previousTokens = dailyModelTokens.filter { tokens in
            guard let date = tokens.parsedDate else { return false }
            return date >= previousStart && date <= previousEnd
        }.reduce(0) { $0 + $1.totalTokens }

        return PeriodComparison(
            currentMessages: currentMessages,
            previousMessages: previousMessages,
            currentSessions: currentSessions,
            previousSessions: previousSessions,
            currentTokens: currentTokens,
            previousTokens: previousTokens
        )
    }

    func currentStreak() -> Int {
        let today = Date()
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let sortedDates = dailyActivity
            .compactMap { $0.parsedDate }
            .sorted(by: >)

        guard !sortedDates.isEmpty else { return 0 }

        var streak = 0
        var checkDate = today

        for date in sortedDates {
            let daysDiff = calendar.dateComponents([.day], from: date, to: checkDate).day ?? 0

            if daysDiff <= 1 {
                streak += 1
                checkDate = date
            } else {
                break
            }
        }

        return streak
    }
}
```

**Step 4: Run test to verify it passes**

Run: `cd macos-app && swift test --filter StatsCacheComparisonTests`
Expected: All tests pass

**Step 5: Commit**

```bash
git add macos-app/ClaudeCodeMonitor/Sources/Models/StatsCache.swift macos-app/ClaudeCodeMonitorTests/StatsCacheComparisonTests.swift
git commit -m "feat: add period comparison and streak calculation to StatsCache"
```

---

## Task 4: Add Pricing Provider to SettingsManager

**Files:**
- Modify: `macos-app/ClaudeCodeMonitor/Sources/Services/SettingsManager.swift`

**Step 1: Read current SettingsManager**

Run: `head -100 macos-app/ClaudeCodeMonitor/Sources/Services/SettingsManager.swift`

**Step 2: Add pricing provider property**

Add to SettingsManager class:

```swift
@Published var pricingProvider: PricingProvider {
    didSet {
        UserDefaults.standard.set(pricingProvider.rawValue, forKey: "pricingProvider")
    }
}

// In init():
self.pricingProvider = PricingProvider(rawValue: UserDefaults.standard.string(forKey: "pricingProvider") ?? "") ?? .anthropic
```

**Step 3: Build to verify**

Run: `cd macos-app && swift build`
Expected: Build succeeds

**Step 4: Commit**

```bash
git add macos-app/ClaudeCodeMonitor/Sources/Services/SettingsManager.swift
git commit -m "feat: add pricingProvider setting to SettingsManager"
```

---

## Task 5: Create InsightsView

**Files:**
- Create: `macos-app/ClaudeCodeMonitor/Sources/Views/InsightsView.swift`

**Step 1: Create the view file**

Create `macos-app/ClaudeCodeMonitor/Sources/Views/InsightsView.swift`:

```swift
import SwiftUI
import Charts

// MARK: - Insights View

struct InsightsView: View {
    @StateObject private var loader = StatsCacheLoader()
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var selectedPeriod: InsightsPeriod = .thisWeek
    @State private var appearAnimation = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum InsightsPeriod: String, CaseIterable {
        case thisWeek = "This Week"
        case thisMonth = "This Month"
        case last7Days = "Last 7 Days"

        var comparisonDays: Int {
            switch self {
            case .thisWeek, .last7Days: return 7
            case .thisMonth: return 30
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                headerSection
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 10)

                if loader.isLoading {
                    loadingView
                } else if let error = loader.error {
                    errorView(error)
                } else if let stats = loader.statsCache {
                    insightsContent(stats)
                        .opacity(appearAnimation ? 1 : 0)
                        .offset(y: appearAnimation ? 0 : 15)
                } else if !loader.fileExists {
                    noFileView
                }
            }
            .padding(Spacing.xl)
        }
        .frame(minWidth: 650, minHeight: 550)
        .background(Color.noirBackground)
        .task {
            await loader.load()
        }
        .onAppear {
            withAnimation(reduceMotion ? .none : .easeOut(duration: 0.5)) {
                appearAnimation = true
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.sm) {
                    Circle()
                        .fill(Color.phosphorGreen)
                        .frame(width: 8, height: 8)
                        .phosphorGlow(.phosphorGreen, intensity: 0.6, isActive: true)

                    Text("INSIGHTS")
                        .font(.terminalCaptionSmall)
                        .foregroundStyle(Color.noirTextSecondary)
                        .tracking(2)
                }

                Text("Usage Trends")
                    .font(.terminalHeadline)
                    .foregroundStyle(Color.noirTextPrimary)
            }

            Spacer()

            // Period Selector
            Picker("Period", selection: $selectedPeriod) {
                ForEach(InsightsPeriod.allCases, id: \.self) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 280)

            // Pricing Provider
            Menu {
                ForEach(PricingProvider.allCases, id: \.self) { provider in
                    Button(provider.displayName) {
                        settingsManager.pricingProvider = provider
                    }
                }
            } label: {
                HStack(spacing: Spacing.xs) {
                    Text(settingsManager.pricingProvider.displayName)
                        .font(.terminalCaptionSmall)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8))
                }
                .foregroundStyle(Color.noirTextSecondary)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background {
                    Capsule()
                        .strokeBorder(Color.noirStroke, lineWidth: 1)
                }
            }
            .menuStyle(.borderlessButton)
        }
        .padding(Spacing.lg)
        .background {
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .fill(Color.noirSurface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .strokeBorder(Color.noirStroke, lineWidth: 1)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func insightsContent(_ stats: StatsCache) -> some View {
        // Period Comparison Cards
        comparisonCardsSection(stats)

        // Trend Sparklines
        sparklineSection(stats)

        // Peak Activity
        peakActivitySection(stats)
    }

    // MARK: - Comparison Cards

    private func comparisonCardsSection(_ stats: StatsCache) -> some View {
        let comparison = stats.periodComparison(
            currentDays: selectedPeriod.comparisonDays,
            previousDays: selectedPeriod.comparisonDays
        )

        return VStack(alignment: .leading, spacing: Spacing.md) {
            TerminalSectionHeader("Period Comparison")

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 200), spacing: Spacing.md)], spacing: Spacing.md) {
                ComparisonCard(
                    title: "Messages",
                    value: comparison?.currentMessages ?? 0,
                    change: comparison?.messagesChange,
                    icon: "message.fill",
                    color: .phosphorCyan
                )

                ComparisonCard(
                    title: "Sessions",
                    value: comparison?.currentSessions ?? 0,
                    change: comparison?.sessionsChange,
                    icon: "terminal.fill",
                    color: .phosphorPurple
                )

                ComparisonCard(
                    title: "Tokens",
                    value: comparison?.currentTokens ?? 0,
                    change: comparison?.tokensChange,
                    icon: "number.circle.fill",
                    color: .phosphorOrange,
                    formatter: NumberFormatting.compact
                )

                ComparisonCard(
                    title: "Est. Cost",
                    value: Int(stats.totalCost * 100), // cents for display
                    change: nil, // Would need cost history
                    icon: "dollarsign.circle.fill",
                    color: .phosphorGreen,
                    formatter: { NumberFormatting.cost(Double($0) / 100) }
                )
            }
        }
    }

    // MARK: - Sparklines

    private func sparklineSection(_ stats: StatsCache) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            TerminalSectionHeader("Trends")

            HStack(spacing: Spacing.lg) {
                // Daily Activity Sparkline
                SparklineCard(
                    title: "Daily Activity",
                    subtitle: "Avg: \(Int(stats.averageMessagesPerDay))/day",
                    data: stats.dailyActivity.suffix(selectedPeriod.comparisonDays).map { Double($0.messageCount) },
                    color: .phosphorCyan
                )

                // Session Length (placeholder - would need session duration data)
                SparklineCard(
                    title: "Sessions/Day",
                    subtitle: "Avg: \(String(format: "%.1f", stats.averageSessionsPerDay))",
                    data: stats.dailyActivity.suffix(selectedPeriod.comparisonDays).map { Double($0.sessionCount) },
                    color: .phosphorPurple
                )
            }
        }
    }

    // MARK: - Peak Activity

    private func peakActivitySection(_ stats: StatsCache) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            TerminalSectionHeader("Peak Activity")

            VStack(alignment: .leading, spacing: Spacing.sm) {
                if let peakHour = stats.peakHour {
                    TerminalDetailRow(label: "Most Active Hour", value: NumberFormatting.hour(peakHour))
                }

                if let longest = stats.longestSession {
                    TerminalDetailRow(label: "Longest Session", value: longest.formattedDuration)
                }

                TerminalDetailRow(label: "Current Streak", value: "\(stats.currentStreak()) days")

                if let firstSession = stats.formattedFirstSessionDate {
                    TerminalDetailRow(label: "Member Since", value: firstSession)
                }
            }
            .padding(Spacing.lg)
            .background {
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .fill(Color.noirSurface)
            }
            .overlay {
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .strokeBorder(Color.noirStroke, lineWidth: 1)
            }
        }
    }

    // MARK: - Loading/Error Views

    private var loadingView: some View {
        VStack(spacing: Spacing.lg) {
            TerminalLoadingIndicator(color: .phosphorGreen)
                .scaleEffect(1.5)
            Text("LOADING INSIGHTS")
                .font(.terminalCaptionSmall)
                .foregroundStyle(Color.noirTextSecondary)
                .tracking(2)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: Spacing.xl) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40, weight: .thin))
                .foregroundStyle(Color.phosphorRed)
            Text(error)
                .font(.terminalBodySmall)
                .foregroundStyle(Color.noirTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    private var noFileView: some View {
        TerminalEmptyState(
            title: "No Stats Available",
            message: "Use Claude Code to generate usage statistics",
            icon: "chart.line.uptrend.xyaxis"
        )
        .frame(maxWidth: .infinity, minHeight: 300)
    }
}

// MARK: - Comparison Card

struct ComparisonCard: View {
    let title: String
    let value: Int
    let change: Double?
    let icon: String
    let color: Color
    var formatter: (Int) -> String = { "\($0)" }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(color)
                Text(title.uppercased())
                    .font(.terminalCaptionSmall)
                    .foregroundStyle(Color.noirTextTertiary)
                    .tracking(1)
            }

            Text(formatter(value))
                .font(.terminalHeadline)
                .foregroundStyle(Color.noirTextPrimary)

            if let change = change {
                HStack(spacing: Spacing.xxs) {
                    Image(systemName: change >= 0 ? "arrow.up" : "arrow.down")
                        .font(.system(size: 10, weight: .bold))
                    Text(String(format: "%.0f%%", abs(change)))
                        .font(.terminalDataSmall)
                    Text("vs last period")
                        .font(.terminalCaptionSmall)
                        .foregroundStyle(Color.noirTextTertiary)
                }
                .foregroundStyle(change >= 0 ? Color.phosphorGreen : Color.phosphorRed)
            } else {
                Text("—")
                    .font(.terminalDataSmall)
                    .foregroundStyle(Color.noirTextTertiary)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .fill(Color.noirSurface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .strokeBorder(Color.noirStroke, lineWidth: 1)
        }
    }
}

// MARK: - Sparkline Card

struct SparklineCard: View {
    let title: String
    let subtitle: String
    let data: [Double]
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title.uppercased())
                .font(.terminalCaptionSmall)
                .foregroundStyle(Color.noirTextTertiary)
                .tracking(1)

            if data.isEmpty {
                Rectangle()
                    .fill(Color.noirStroke)
                    .frame(height: 60)
            } else {
                Chart(Array(data.enumerated()), id: \.offset) { index, value in
                    LineMark(
                        x: .value("Day", index),
                        y: .value("Value", value)
                    )
                    .foregroundStyle(color)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Day", index),
                        y: .value("Value", value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [color.opacity(0.3), color.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 60)
            }

            Text(subtitle)
                .font(.terminalDataSmall)
                .foregroundStyle(Color.noirTextSecondary)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .fill(Color.noirSurface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .strokeBorder(Color.noirStroke, lineWidth: 1)
        }
    }
}
```

**Step 2: Build to verify**

Run: `cd macos-app && swift build`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add macos-app/ClaudeCodeMonitor/Sources/Views/InsightsView.swift
git commit -m "feat: add InsightsView with comparison cards, sparklines, and peak activity"
```

---

## Task 6: Add Insights Tab to ContentView

**Files:**
- Modify: `macos-app/ClaudeCodeMonitor/Sources/Views/ContentView.swift`

**Step 1: Add insights case to DashboardTab enum**

Find the `DashboardTab` enum and add:

```swift
enum DashboardTab: String, CaseIterable, Identifiable {
    case summary = "Summary"
    case tokenMetrics = "Token Metrics"
    case insights = "Insights"           // NEW
    case localStatsCache = "Local Stats Cache"
    case smokeTest = "Smoke Test"

    var description: String {
        switch self {
        case .summary: return "Overview of key metrics and costs"
        case .tokenMetrics: return "Token usage and model performance"
        case .insights: return "Usage trends and comparisons"  // NEW
        case .localStatsCache: return "Local Claude Code usage statistics"
        case .smokeTest: return "Debug and test connectivity"
        }
    }

    var keyboardShortcut: KeyEquivalent {
        switch self {
        case .summary: return "1"
        case .tokenMetrics: return "2"
        case .insights: return "3"        // NEW
        case .localStatsCache: return "4" // UPDATED
        case .smokeTest: return "5"       // UPDATED
        }
    }
    // ... update shortcutKey similarly
}
```

**Step 2: Add case to mainContent switch**

```swift
@ViewBuilder
private var mainContent: some View {
    // ... existing code ...
    switch selectedTab {
    case .summary:
        SummaryDashboardView(metricsService: metricsService)
    case .tokenMetrics:
        PerformanceDashboardView(metricsService: metricsService)
    case .insights:                        // NEW
        InsightsView()                     // NEW
    case .localStatsCache:
        StatsCacheView()
    case .smokeTest:
        SmokeTestView(metricsService: metricsService)
    }
}
```

**Step 3: Add icon and color for insights tab**

```swift
private func iconForTab(_ tab: DashboardTab) -> String {
    switch tab {
    case .summary: return "square.grid.2x2"
    case .tokenMetrics: return "waveform.path.ecg"
    case .insights: return "lightbulb.fill"    // NEW
    case .localStatsCache: return "internaldrive"
    case .smokeTest: return "stethoscope"
    }
}

private func colorForTab(_ tab: DashboardTab) -> Color {
    switch tab {
    case .summary: return .phosphorGreen
    case .tokenMetrics: return .phosphorCyan
    case .insights: return .phosphorAmber      // NEW
    case .localStatsCache: return .phosphorPurple
    case .smokeTest: return .noirTextTertiary
    }
}
```

**Step 4: Build and test**

Run: `cd macos-app && swift build && swift test`
Expected: Build succeeds, all tests pass

**Step 5: Commit**

```bash
git add macos-app/ClaudeCodeMonitor/Sources/Views/ContentView.swift
git commit -m "feat: add Insights tab to sidebar navigation"
```

---

## Task 7: Add Pricing Provider to Settings View

**Files:**
- Modify: `macos-app/ClaudeCodeMonitor/Sources/Views/SettingsView.swift`

**Step 1: Add pricing section to settings**

Find the appropriate location in SettingsView and add a new section:

```swift
// MARK: - Pricing Section

private var pricingSection: some View {
    VStack(alignment: .leading, spacing: Spacing.md) {
        TerminalSectionHeader("Pricing")

        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("COST CALCULATION")
                .font(.terminalCaptionSmall)
                .foregroundStyle(Color.noirTextTertiary)
                .tracking(1)

            Picker("Provider", selection: $settingsManager.pricingProvider) {
                ForEach(PricingProvider.allCases, id: \.self) { provider in
                    Text(provider.displayName).tag(provider)
                }
            }
            .pickerStyle(.menu)

            Text("Select your API provider to calculate accurate costs")
                .font(.terminalCaptionSmall)
                .foregroundStyle(Color.noirTextTertiary)
        }
        .padding(Spacing.lg)
        .background {
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .fill(Color.noirSurface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .strokeBorder(Color.noirStroke, lineWidth: 1)
        }
    }
}
```

Add `pricingSection` to the settings body.

**Step 2: Build to verify**

Run: `cd macos-app && swift build`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add macos-app/ClaudeCodeMonitor/Sources/Views/SettingsView.swift
git commit -m "feat: add pricing provider picker to Settings view"
```

---

## Task 8: Run Full Test Suite and Final Build

**Step 1: Run all tests**

Run: `cd macos-app && swift test`
Expected: All tests pass (96+ tests)

**Step 2: Build release**

Run: `cd macos-app && swift build -c release`
Expected: Release build succeeds

**Step 3: Commit any remaining changes**

```bash
git status
# If any uncommitted changes:
git add -A
git commit -m "chore: final cleanup for insights and pricing feature"
```

---

## Summary

**New Files Created:**
- `Sources/Models/PricingProvider.swift`
- `Sources/Views/InsightsView.swift`
- `Tests/PricingProviderTests.swift`
- `Tests/StatsCacheComparisonTests.swift`

**Files Modified:**
- `Sources/Models/PrometheusModels.swift` (TimeRangePreset)
- `Sources/Models/StatsCache.swift` (comparison methods)
- `Sources/Services/SettingsManager.swift` (pricingProvider)
- `Sources/Views/ContentView.swift` (Insights tab)
- `Sources/Views/SettingsView.swift` (pricing picker)
- `Tests/TimeRangeBucketingTests.swift` (new preset tests)

**Total Commits:** ~8 atomic commits following TDD
