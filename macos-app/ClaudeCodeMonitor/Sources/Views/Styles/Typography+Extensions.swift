import SwiftUI

// MARK: - Legacy Spacing System (8-point grid)
// Kept for backward compatibility with existing views

extension CGFloat {
    static let spacingXS: CGFloat = 4
    static let spacingSM: CGFloat = 8
    static let spacingMD: CGFloat = 12
    static let spacingLG: CGFloat = 16
    static let spacingXL: CGFloat = 20
    static let spacingXXL: CGFloat = 24
    static let spacingSection: CGFloat = 32
}

// MARK: - Chart Heights

extension CGFloat {
    static let chartHeightCompact: CGFloat = 150
    static let chartHeightStandard: CGFloat = 200
    static let chartHeightExpanded: CGFloat = 280
}

// MARK: - Legacy Typography Scale
// Kept for backward compatibility - prefer DesignSystem fonts for new code

extension Font {
    // Dashboard specific fonts (legacy)
    static let dashboardTitle = Font.system(.largeTitle, design: .rounded, weight: .semibold)
    static let sectionTitle = Font.system(.title2, design: .default, weight: .semibold)
    static let metricValue = Font.system(.title2, design: .rounded, weight: .medium)
    static let metricLabel = Font.subheadline.weight(.medium)
    static let chartTitle = Font.headline
    static let statusText = Font.footnote
    static let cardSubtitle = Font.caption.weight(.medium)
}

// MARK: - Terminal Noir GroupBox Styles

struct CardGroupBoxStyle: GroupBoxStyle {
    var isHovered: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            configuration.label
            configuration.content
        }
        .padding(Spacing.lg)
        .background {
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .fill(Color.noirSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                        .fill(isHovered ? Color.phosphorCyan.opacity(0.05) : .clear)
                }
        }
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .strokeBorder(isHovered ? Color.phosphorCyan.opacity(0.3) : Color.noirStroke, lineWidth: 1)
        )
        .animation(reduceMotion ? .none : .easeInOut(duration: 0.15), value: isHovered)
    }
}

struct ChartGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            configuration.label
                .font(.terminalTitle)
                .foregroundStyle(Color.noirTextSecondary)
            configuration.content
        }
        .padding(Spacing.xl)
        .background {
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .fill(Color.noirSurface)
        }
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .strokeBorder(Color.noirStroke, lineWidth: 1)
        )
    }
}

// MARK: - View Modifiers

struct HoverEffectModifier: ViewModifier {
    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var highlightColor: Color = .phosphorCyan

    func body(content: Content) -> some View {
        content
            .background(isHovered ? highlightColor.opacity(0.08) : .clear)
            .animation(reduceMotion ? .none : .easeInOut(duration: 0.15), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

extension View {
    func hoverHighlight(color: Color = .phosphorCyan) -> some View {
        modifier(HoverEffectModifier(highlightColor: color))
    }
}

// MARK: - Legacy Color Extensions
// Maps legacy colors to Terminal Noir phosphor palette

extension Color {
    static let metricGreen = Color.phosphorGreen
    static let metricBlue = Color.phosphorCyan
    static let metricOrange = Color.phosphorOrange
    static let metricPurple = Color.phosphorPurple
    static let metricMint = Color.phosphorCyan.opacity(0.7)
    static let metricRed = Color.phosphorRed
    static let metricIndigo = Color.phosphorPurple.opacity(0.8)
    static let metricTeal = Color.phosphorCyan.opacity(0.8)
}

// MARK: - Connection Status Extensions

extension ConnectionStatus {
    var icon: String {
        switch self {
        case .connected: return "circle.fill"
        case .connecting: return "circle.dotted"
        case .disconnected: return "circle.slash"
        case .unknown: return "circle.slash"
        }
    }

    var color: Color {
        switch self {
        case .connected: return .phosphorGreen
        case .connecting: return .phosphorAmber
        case .disconnected: return .phosphorRed
        case .unknown: return .phosphorRed
        }
    }
}

// MARK: - Legacy Empty State Component
// Prefer TerminalEmptyState from DesignSystem for new code

struct MetricEmptyState: View {
    let title: String
    let message: String
    let icon: String
    var action: (() -> Void)? = nil
    var actionLabel: String? = nil

    var body: some View {
        TerminalEmptyState(
            title: title,
            message: message,
            icon: icon,
            action: action,
            actionLabel: actionLabel
        )
        .frame(minHeight: .chartHeightCompact)
    }
}
