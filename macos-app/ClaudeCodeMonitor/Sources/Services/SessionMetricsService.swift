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
