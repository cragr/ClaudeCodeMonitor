import SwiftUI

/// Centralized model name formatting and color assignment
/// Single source of truth for displaying Claude model names and assigning chart colors
enum ModelFormatting {

    // MARK: - Color Palette

    /// Consistent color palette for model charts across all views
    static let colorPalette: [Color] = [
        .phosphorPurple,
        .phosphorCyan,
        .phosphorGreen,
        .phosphorAmber,
        .phosphorMagenta,
        .phosphorOrange,
        .phosphorRed,
        Color(red: 0.4, green: 0.8, blue: 0.9),  // Light cyan
        Color(red: 0.9, green: 0.6, blue: 0.8),  // Pink
        Color(red: 0.6, green: 0.9, blue: 0.7),  // Mint
    ]

    // MARK: - Model Family

    enum Family: String {
        case opus = "Opus"
        case sonnet = "Sonnet"
        case haiku = "Haiku"
        case unknown = "Unknown"

        init(from modelId: String) {
            let lower = modelId.lowercased()
            if lower.contains("opus") {
                self = .opus
            } else if lower.contains("sonnet") {
                self = .sonnet
            } else if lower.contains("haiku") {
                self = .haiku
            } else {
                self = .unknown
            }
        }
    }

    // MARK: - Version Detection

    enum Version: String {
        case v3_5 = "3.5"
        case v4_0 = "4.0"
        case v4_1 = "4.1"
        case v4_5 = "4.5"
        case unknown = ""

        init(from modelId: String) {
            let lower = modelId.lowercased()
            // Check for version patterns: "4-5", "4.5", "4_5"
            if lower.contains("4-5") || lower.contains("4.5") || lower.contains("4_5") {
                self = .v4_5
            } else if lower.contains("4-1") || lower.contains("4.1") || lower.contains("4_1") {
                self = .v4_1
            } else if lower.contains("4-0") || lower.contains("4.0") || lower.contains("4_0") {
                self = .v4_0
            } else if lower.contains("3-5") || lower.contains("3.5") || lower.contains("3_5") {
                self = .v3_5
            } else {
                self = .unknown
            }
        }
    }

    // MARK: - Short Name

    /// Converts full model identifier to human-readable short name
    /// e.g., "claude-3-5-sonnet-20241022" -> "Sonnet 3.5"
    static func shortName(_ fullName: String) -> String {
        let family = Family(from: fullName)
        let version = Version(from: fullName)

        guard family != .unknown else {
            // Fallback: take first two parts
            let parts = fullName.split(separator: "-")
            if parts.count > 1 {
                return String(parts.prefix(2).joined(separator: "-"))
            }
            return fullName
        }

        if version == .unknown {
            return family.rawValue
        }
        return "\(family.rawValue) \(version.rawValue)"
    }

    // MARK: - Color Assignment

    /// Assigns color based on position in sorted model list (for consistent chart colors)
    static func color(for modelName: String, in sortedModels: [String]) -> Color {
        if let index = sortedModels.firstIndex(of: modelName) {
            return colorPalette[index % colorPalette.count]
        }
        return color(forFamily: modelName)
    }

    /// Color based on model family (fallback when no sorted list available)
    static func color(forFamily modelName: String) -> Color {
        switch Family(from: modelName) {
        case .opus:    return .phosphorPurple
        case .sonnet:  return .phosphorCyan
        case .haiku:   return .phosphorGreen
        case .unknown: return .noirTextSecondary
        }
    }
}
