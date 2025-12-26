import Foundation

// MARK: - Stats Cache Models
// Represents the data structure from ~/.claude/stats-cache.json

struct StatsCache: Codable {
    let version: Int
    let lastComputedDate: String
    let dailyActivity: [DailyActivity]
    let dailyModelTokens: [DailyModelTokens]
    let modelUsage: [String: ModelUsage]
    let totalSessions: Int
    let totalMessages: Int
    let longestSession: LongestSession?
    let firstSessionDate: String?
    let hourCounts: [String: Int]

    // Computed properties
    var totalTokens: Int {
        modelUsage.values.reduce(0) { $0 + $1.totalTokens }
    }

    var totalCost: Double {
        modelUsage.reduce(0.0) { total, entry in
            total + entry.value.estimatedCost(for: entry.key)
        }
    }

    var activeDays: Int {
        dailyActivity.count
    }

    var averageMessagesPerDay: Double {
        guard activeDays > 0 else { return 0 }
        return Double(totalMessages) / Double(activeDays)
    }

    var averageSessionsPerDay: Double {
        guard activeDays > 0 else { return 0 }
        return Double(totalSessions) / Double(activeDays)
    }

    var peakHour: Int? {
        hourCounts.max(by: { $0.value < $1.value }).flatMap { Int($0.key) }
    }

    var formattedFirstSessionDate: String? {
        guard let dateString = firstSessionDate else { return nil }
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = isoFormatter.date(from: dateString) else { return nil }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

struct DailyActivity: Codable, Identifiable {
    let date: String
    let messageCount: Int
    let sessionCount: Int
    let toolCallCount: Int

    var id: String { date }

    var parsedDate: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: date)
    }

    var formattedDate: String {
        guard let parsed = parsedDate else { return date }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: parsed)
    }
}

struct DailyModelTokens: Codable, Identifiable {
    let date: String
    let tokensByModel: [String: Int]

    var id: String { date }

    var parsedDate: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: date)
    }

    var totalTokens: Int {
        tokensByModel.values.reduce(0, +)
    }
}

struct ModelUsage: Codable {
    let inputTokens: Int
    let outputTokens: Int
    let cacheReadInputTokens: Int
    let cacheCreationInputTokens: Int
    let webSearchRequests: Int
    let costUSD: Double
    let contextWindow: Int

    var totalTokens: Int {
        inputTokens + outputTokens + cacheReadInputTokens + cacheCreationInputTokens
    }

    var effectiveTokens: Int {
        // Tokens that actually count toward billing (cache reads are cheaper)
        inputTokens + outputTokens + cacheCreationInputTokens
    }

    // Estimate cost based on model pricing (per 1M tokens)
    // Claude 4.5 Opus: $5 (Input) / $25 (Output)
    // Claude 4.5 Sonnet: $3 (Input) / $15 (Output)
    // Claude 4.5 Haiku: $1 (Input) / $5 (Output)
    // Claude 4.1 Opus: $15 (Input) / $75 (Output)
    // Claude 3.5 Sonnet: $3 (Input) / $15 (Output)
    // Claude 3.5 Haiku: $0.80 (Input) / $4 (Output)
    // Cache reads are 90% cheaper, cache writes are 25% more expensive
    func estimatedCost(for modelName: String) -> Double {
        let pricing: (input: Double, output: Double, cacheRead: Double, cacheWrite: Double)

        if modelName.contains("opus-4-5") || modelName.contains("opus-4.5") {
            // Claude 4.5 Opus
            pricing = (input: 5.0, output: 25.0, cacheRead: 0.5, cacheWrite: 6.25)
        } else if modelName.contains("opus-4-1") || modelName.contains("opus-4.1") || modelName.contains("opus-4-0") {
            // Claude 4.1/4.0 Opus
            pricing = (input: 15.0, output: 75.0, cacheRead: 1.5, cacheWrite: 18.75)
        } else if modelName.contains("opus") {
            // Default Opus (assume 4.1)
            pricing = (input: 15.0, output: 75.0, cacheRead: 1.5, cacheWrite: 18.75)
        } else if modelName.contains("sonnet-4-5") || modelName.contains("sonnet-4.5") {
            // Claude 4.5 Sonnet
            pricing = (input: 3.0, output: 15.0, cacheRead: 0.3, cacheWrite: 3.75)
        } else if modelName.contains("sonnet-3-5") || modelName.contains("sonnet-3.5") || modelName.contains("sonnet") {
            // Claude 3.5 Sonnet (or default Sonnet)
            pricing = (input: 3.0, output: 15.0, cacheRead: 0.3, cacheWrite: 3.75)
        } else if modelName.contains("haiku-4-5") || modelName.contains("haiku-4.5") {
            // Claude 4.5 Haiku
            pricing = (input: 1.0, output: 5.0, cacheRead: 0.1, cacheWrite: 1.25)
        } else if modelName.contains("haiku-3-5") || modelName.contains("haiku-3.5") || modelName.contains("haiku") {
            // Claude 3.5 Haiku (or default Haiku)
            pricing = (input: 0.80, output: 4.0, cacheRead: 0.08, cacheWrite: 1.0)
        } else {
            // Default to Sonnet pricing
            pricing = (input: 3.0, output: 15.0, cacheRead: 0.3, cacheWrite: 3.75)
        }

        let inputCost = Double(inputTokens) / 1_000_000 * pricing.input
        let outputCost = Double(outputTokens) / 1_000_000 * pricing.output
        let cacheReadCost = Double(cacheReadInputTokens) / 1_000_000 * pricing.cacheRead
        let cacheWriteCost = Double(cacheCreationInputTokens) / 1_000_000 * pricing.cacheWrite

        return inputCost + outputCost + cacheReadCost + cacheWriteCost
    }
}

struct LongestSession: Codable {
    let sessionId: String
    let duration: Int
    let messageCount: Int
    let timestamp: String

    var formattedDuration: String {
        // Duration is stored in milliseconds
        let totalSeconds = duration / 1_000
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 24 {
            let days = hours / 24
            let remainingHours = hours % 24
            return "\(days)d \(remainingHours)h"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }

    var formattedDate: String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = isoFormatter.date(from: timestamp) else { return timestamp }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Stats Cache Loader

class StatsCacheLoader: ObservableObject {
    @Published var statsCache: StatsCache?
    @Published var isLoading = false
    @Published var error: String?
    @Published var lastLoadTime: Date?

    private let cacheFilePath: String

    init() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        cacheFilePath = homeDir.appendingPathComponent(".claude/stats-cache.json").path
    }

    @MainActor
    func load() async {
        isLoading = true
        error = nil

        do {
            let url = URL(fileURLWithPath: cacheFilePath)
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            statsCache = try decoder.decode(StatsCache.self, from: data)
            lastLoadTime = Date()
        } catch let decodingError as DecodingError {
            error = "Failed to parse stats cache: \(decodingError.localizedDescription)"
        } catch {
            self.error = "Failed to load stats cache: \(error.localizedDescription)"
        }

        isLoading = false
    }

    var fileExists: Bool {
        FileManager.default.fileExists(atPath: cacheFilePath)
    }

    var filePath: String {
        cacheFilePath
    }
}

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

        // Current period
        guard let currentStart = calendar.date(byAdding: .day, value: -currentDays, to: today),
              let previousStart = calendar.date(byAdding: .day, value: -(currentDays + previousDays), to: today),
              let previousEnd = calendar.date(byAdding: .day, value: -currentDays - 1, to: today) else {
            return nil
        }

        let currentActivities = dailyActivity.filter { activity in
            guard let date = activity.parsedDate else { return false }
            return date >= currentStart && date <= today
        }

        // Previous period
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
