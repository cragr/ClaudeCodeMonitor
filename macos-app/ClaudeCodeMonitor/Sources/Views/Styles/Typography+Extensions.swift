import SwiftUI

// MARK: - Spacing System (8-point grid)

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

// MARK: - Typography Scale
// Consistent font scaling following Apple HIG

extension Font {
    // Dashboard specific fonts
    static let dashboardTitle = Font.system(.largeTitle, design: .rounded, weight: .semibold)
    static let sectionTitle = Font.system(.title2, design: .default, weight: .semibold)
    static let metricValue = Font.system(.title2, design: .rounded, weight: .medium)
    static let metricLabel = Font.subheadline.weight(.medium)
    static let chartTitle = Font.headline
    static let statusText = Font.footnote
    static let cardSubtitle = Font.caption.weight(.medium)
}

// MARK: - Custom GroupBox Styles

struct CardGroupBoxStyle: GroupBoxStyle {
    var isHovered: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: .spacingMD) {
            configuration.label
            configuration.content
        }
        .padding(.spacingLG)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.regularMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isHovered ? Color.accentColor.opacity(0.05) : .clear)
                }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(isHovered ? Color.accentColor.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 0.5)
        )
        .animation(reduceMotion ? .none : .easeInOut(duration: 0.15), value: isHovered)
    }
}

struct ChartGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: .spacingLG) {
            configuration.label
                .font(.chartTitle)
            configuration.content
        }
        .padding(.spacingXL)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 0.5)
        )
    }
}

// MARK: - View Modifiers

struct HoverEffectModifier: ViewModifier {
    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var highlightColor: Color = .accentColor

    func body(content: Content) -> some View {
        content
            .background(isHovered ? highlightColor.opacity(0.05) : .clear)
            .animation(reduceMotion ? .none : .easeInOut(duration: 0.15), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

extension View {
    func hoverHighlight(color: Color = .accentColor) -> some View {
        modifier(HoverEffectModifier(highlightColor: color))
    }
}

// MARK: - Color Extensions

extension Color {
    static let metricGreen = Color.green
    static let metricBlue = Color.blue
    static let metricOrange = Color.orange
    static let metricPurple = Color.purple
    static let metricMint = Color.mint
    static let metricRed = Color.red
    static let metricIndigo = Color.indigo
    static let metricTeal = Color.teal
}

// MARK: - Connection Status Badge

struct ConnectionStatusBadge: View {
    let status: ConnectionStatus
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: status.icon)
                .font(.caption)
                .symbolEffect(.pulse, isActive: !reduceMotion && status == .connecting)
                .foregroundStyle(status.color)

            Text(status.displayText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, .spacingSM)
        .padding(.vertical, .spacingXS)
        .background(status.color.opacity(0.1))
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Connection status: \(status.displayText)")
    }
}

extension ConnectionStatus {
    var icon: String {
        switch self {
        case .connected: return "circle.fill"
        case .connecting: return "circle.dotted"
        case .disconnected, .unknown: return "circle.slash"
        }
    }

    var color: Color {
        switch self {
        case .connected: return .green
        case .connecting: return .orange
        case .disconnected, .unknown: return .red
        }
    }
}

// MARK: - Empty State Component

struct MetricEmptyState: View {
    let title: String
    let message: String
    let icon: String
    var action: (() -> Void)? = nil
    var actionLabel: String? = nil

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: icon)
        } description: {
            Text(message)
        } actions: {
            if let action = action, let label = actionLabel {
                Button(label, action: action)
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
            }
        }
        .frame(minHeight: .chartHeightCompact)
    }
}
