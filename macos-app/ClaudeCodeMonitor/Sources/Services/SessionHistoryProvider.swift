import Foundation

// MARK: - Protocol

/// Provides session-to-project mapping from Claude Code history
protocol SessionHistoryProvider: Sendable {
    /// Returns the project path for a given session ID, or nil if not found
    func projectPath(for sessionId: String) async -> String?

    /// Returns project paths for multiple session IDs
    func projectPaths(for sessionIds: [String]) async -> [String: String]
}

// MARK: - File-based Implementation

/// Reads ~/.claude/history.jsonl to correlate session IDs with project directories
actor FileSessionHistoryProvider: SessionHistoryProvider {
    private var cache: [String: ProjectInfo]?
    private let historyURL: URL

    struct ProjectInfo {
        let path: String
        let timestamp: Int64
    }

    init(historyURL: URL? = nil) {
        self.historyURL = historyURL ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude")
            .appendingPathComponent("history.jsonl")
    }

    func projectPath(for sessionId: String) async -> String? {
        let mapping = await loadIfNeeded()
        return mapping[sessionId]?.path
    }

    func projectPaths(for sessionIds: [String]) async -> [String: String] {
        let mapping = await loadIfNeeded()
        var result: [String: String] = [:]
        for sessionId in sessionIds {
            if let info = mapping[sessionId] {
                result[sessionId] = info.path
            }
        }
        return result
    }

    /// Invalidate cache to force reload on next access
    func invalidateCache() {
        cache = nil
    }

    // MARK: - Private

    private func loadIfNeeded() async -> [String: ProjectInfo] {
        if let cache = cache {
            return cache
        }

        let mapping = await streamHistoryFile()
        cache = mapping
        return mapping
    }

    /// Stream the JSONL file line by line to handle large history files
    private func streamHistoryFile() async -> [String: ProjectInfo] {
        var mapping: [String: ProjectInfo] = [:]

        guard FileManager.default.fileExists(atPath: historyURL.path) else {
            return mapping
        }

        guard let fileHandle = try? FileHandle(forReadingFrom: historyURL) else {
            return mapping
        }

        defer { try? fileHandle.close() }

        let decoder = JSONDecoder()
        var buffer = Data()
        let chunkSize = 64 * 1024 // 64KB chunks

        while true {
            guard let chunk = try? fileHandle.read(upToCount: chunkSize), !chunk.isEmpty else {
                // Process any remaining data in buffer
                if !buffer.isEmpty {
                    processLine(buffer, decoder: decoder, into: &mapping)
                }
                break
            }

            buffer.append(chunk)

            // Process complete lines
            while let newlineIndex = buffer.firstIndex(of: UInt8(ascii: "\n")) {
                let lineData = buffer[..<newlineIndex]
                buffer = buffer[(newlineIndex + 1)...]

                if !lineData.isEmpty {
                    processLine(Data(lineData), decoder: decoder, into: &mapping)
                }
            }
        }

        return mapping
    }

    private func processLine(_ lineData: Data, decoder: JSONDecoder, into mapping: inout [String: ProjectInfo]) {
        guard let entry = try? decoder.decode(HistoryEntry.self, from: lineData) else {
            return
        }

        // Only update if this entry is newer (latest timestamp wins)
        if let existing = mapping[entry.sessionId] {
            if entry.timestamp > existing.timestamp {
                mapping[entry.sessionId] = ProjectInfo(path: entry.project, timestamp: entry.timestamp)
            }
        } else {
            mapping[entry.sessionId] = ProjectInfo(path: entry.project, timestamp: entry.timestamp)
        }
    }
}

// MARK: - History Entry Model

private struct HistoryEntry: Decodable {
    let sessionId: String
    let project: String
    let timestamp: Int64
}

// MARK: - Mock Implementation for Testing

/// Mock provider for unit tests
actor MockSessionHistoryProvider: SessionHistoryProvider {
    private var mockData: [String: String]

    init(mockData: [String: String] = [:]) {
        self.mockData = mockData
    }

    func projectPath(for sessionId: String) async -> String? {
        mockData[sessionId]
    }

    func projectPaths(for sessionIds: [String]) async -> [String: String] {
        var result: [String: String] = [:]
        for sessionId in sessionIds {
            if let path = mockData[sessionId] {
                result[sessionId] = path
            }
        }
        return result
    }

    func setMockData(_ data: [String: String]) {
        mockData = data
    }
}
