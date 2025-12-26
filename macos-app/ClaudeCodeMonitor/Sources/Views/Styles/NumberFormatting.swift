import Foundation

/// Centralized number formatting utilities
/// Single source of truth for displaying numbers, tokens, costs, and times
enum NumberFormatting {

    /// Formats large integers with K/M suffix (e.g., 1500 → "1.5K")
    static func compact(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "%.1fK", Double(value) / 1_000)
        }
        return "\(value)"
    }

    /// Formats token counts with B/M/K suffix
    static func tokens(_ value: Int) -> String {
        if value >= 1_000_000_000 {
            return String(format: "%.2fB", Double(value) / 1_000_000_000)
        } else if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "%.1fK", Double(value) / 1_000)
        }
        return "\(value)"
    }

    /// Formats token counts (Double) with B/M/K suffix
    static func tokens(_ value: Double) -> String {
        tokens(Int(value))
    }

    /// Formats cost values with appropriate precision
    static func cost(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "$%.0f", value)
        } else if value >= 100 {
            return String(format: "$%.1f", value)
        } else if value >= 1 {
            return String(format: "$%.2f", value)
        }
        return String(format: "$%.3f", value)
    }

    /// Formats hour as 12-hour time (e.g., 14 → "2pm")
    static func hour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        var components = DateComponents()
        components.hour = hour
        if let date = Calendar.current.date(from: components) {
            return formatter.string(from: date).lowercased()
        }
        return "\(hour):00"
    }

    /// Formats integer with decimal separators (e.g., 1234567 → "1,234,567")
    static func decimal(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
