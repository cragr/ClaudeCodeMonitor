import SwiftUI

// MARK: - Terminal Noir Design System
// A retro-futuristic hacker aesthetic with phosphor glow effects

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Color Tokens
// ═══════════════════════════════════════════════════════════════════════════

extension Color {

    // MARK: - Background Hierarchy

    /// Deep charcoal - primary app background
    static let noirBackground = Color(red: 0.08, green: 0.09, blue: 0.10)

    /// Slightly elevated surface for cards
    static let noirSurface = Color(red: 0.11, green: 0.12, blue: 0.14)

    /// Even more elevated for popovers, tooltips
    static let noirElevated = Color(red: 0.14, green: 0.15, blue: 0.17)

    /// Sidebar background - slightly warmer
    static let noirSidebar = Color(red: 0.09, green: 0.10, blue: 0.11)

    // MARK: - Phosphor Accent Colors (The Glow)

    /// Primary phosphor green - for costs, success, primary data
    static let phosphorGreen = Color(red: 0.35, green: 0.95, blue: 0.45)

    /// Muted green for less prominent data
    static let phosphorGreenMuted = Color(red: 0.25, green: 0.65, blue: 0.35)

    /// Amber/gold - for activity, time, warnings
    static let phosphorAmber = Color(red: 0.95, green: 0.75, blue: 0.20)

    /// Muted amber
    static let phosphorAmberMuted = Color(red: 0.70, green: 0.55, blue: 0.15)

    /// Cyan - for interactive elements, selection, tokens
    static let phosphorCyan = Color(red: 0.30, green: 0.85, blue: 0.95)

    /// Muted cyan
    static let phosphorCyanMuted = Color(red: 0.20, green: 0.55, blue: 0.65)

    /// Magenta/pink - for code additions, positive deltas
    static let phosphorMagenta = Color(red: 0.95, green: 0.40, blue: 0.70)

    /// Orange - for cache, secondary metrics
    static let phosphorOrange = Color(red: 0.95, green: 0.55, blue: 0.25)

    /// Red - for errors, removals, alerts
    static let phosphorRed = Color(red: 0.95, green: 0.30, blue: 0.35)

    /// Purple - for Opus model, premium features
    static let phosphorPurple = Color(red: 0.70, green: 0.45, blue: 0.95)

    // MARK: - Text Hierarchy

    /// Primary text - bright but not pure white
    static let noirTextPrimary = Color(red: 0.92, green: 0.94, blue: 0.96)

    /// Secondary text - muted
    static let noirTextSecondary = Color(red: 0.55, green: 0.58, blue: 0.62)

    /// Tertiary text - very muted
    static let noirTextTertiary = Color(red: 0.38, green: 0.40, blue: 0.44)

    /// Quaternary - barely visible, for hints
    static let noirTextQuaternary = Color(red: 0.25, green: 0.27, blue: 0.30)

    // MARK: - Stroke/Border Colors

    /// Subtle border
    static let noirStroke = Color(red: 0.20, green: 0.22, blue: 0.25)

    /// Emphasized border (hover, focus)
    static let noirStrokeEmphasis = Color(red: 0.30, green: 0.32, blue: 0.36)

    // MARK: - Semantic Metric Colors

    static let metricCost = phosphorGreen
    static let metricTokens = phosphorCyan
    static let metricTime = phosphorAmber
    static let metricLinesAdded = phosphorMagenta
    static let metricLinesRemoved = phosphorRed
    static let metricCommits = phosphorPurple
    static let metricPR = phosphorCyan
    static let metricSessions = phosphorOrange

    // MARK: - Model Colors

    static let modelOpus = phosphorPurple
    static let modelSonnet = phosphorCyan
    static let modelHaiku = phosphorGreen
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Typography System
// ═══════════════════════════════════════════════════════════════════════════

extension Font {

    // MARK: - Display Fonts (Headlines, Hero Numbers)

    /// Large metric display - for hero numbers like cost
    static let terminalDisplay = Font.system(size: 36, weight: .light, design: .monospaced)

    /// Medium display for secondary hero metrics
    static let terminalDisplayMedium = Font.system(size: 28, weight: .light, design: .monospaced)

    /// Dashboard section titles
    static let terminalHeadline = Font.system(size: 18, weight: .semibold, design: .default)

    // MARK: - Body Fonts

    /// Card titles, labels
    static let terminalTitle = Font.system(size: 13, weight: .semibold, design: .default)

    /// Primary body text
    static let terminalBody = Font.system(size: 13, weight: .regular, design: .default)

    /// Secondary body text
    static let terminalBodySmall = Font.system(size: 11, weight: .regular, design: .default)

    // MARK: - Data Fonts (Monospaced for numbers)

    /// Primary metric values
    static let terminalValue = Font.system(size: 24, weight: .medium, design: .monospaced)

    /// Secondary metric values
    static let terminalValueSmall = Font.system(size: 16, weight: .medium, design: .monospaced)

    /// Inline data
    static let terminalData = Font.system(size: 12, weight: .medium, design: .monospaced)

    /// Small data (chart labels, timestamps)
    static let terminalDataSmall = Font.system(size: 10, weight: .regular, design: .monospaced)

    // MARK: - Caption Fonts

    /// Labels, subtitles
    static let terminalCaption = Font.system(size: 11, weight: .medium, design: .default)

    /// Tiny labels
    static let terminalCaptionSmall = Font.system(size: 9, weight: .medium, design: .default)
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Spacing System (8pt Grid)
// ═══════════════════════════════════════════════════════════════════════════

enum Spacing {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 48
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Corner Radius
// ═══════════════════════════════════════════════════════════════════════════

enum CornerRadius {
    static let small: CGFloat = 4
    static let medium: CGFloat = 8
    static let large: CGFloat = 12
    static let xl: CGFloat = 16
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Shadow Definitions (Glow Effects)
// ═══════════════════════════════════════════════════════════════════════════

struct GlowEffect {
    let color: Color
    let radius: CGFloat
    let opacity: Double

    static let greenSubtle = GlowEffect(color: .phosphorGreen, radius: 8, opacity: 0.3)
    static let greenStrong = GlowEffect(color: .phosphorGreen, radius: 16, opacity: 0.5)
    static let cyanSubtle = GlowEffect(color: .phosphorCyan, radius: 8, opacity: 0.3)
    static let amberSubtle = GlowEffect(color: .phosphorAmber, radius: 8, opacity: 0.3)
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - View Modifiers
// ═══════════════════════════════════════════════════════════════════════════

// MARK: - Phosphor Glow Modifier

struct PhosphorGlowModifier: ViewModifier {
    let color: Color
    let intensity: Double
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .shadow(color: isActive ? color.opacity(intensity * 0.6) : .clear, radius: 4, x: 0, y: 0)
            .shadow(color: isActive ? color.opacity(intensity * 0.3) : .clear, radius: 12, x: 0, y: 0)
    }
}

extension View {
    func phosphorGlow(_ color: Color, intensity: Double = 0.5, isActive: Bool = true) -> some View {
        modifier(PhosphorGlowModifier(color: color, intensity: intensity, isActive: isActive))
    }
}

// MARK: - Terminal Card Style

struct TerminalCardModifier: ViewModifier {
    let isHovered: Bool
    let accentColor: Color

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .fill(Color.noirSurface)
                    .overlay {
                        // Subtle inner glow on hover
                        RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                            .fill(
                                RadialGradient(
                                    colors: [accentColor.opacity(isHovered ? 0.08 : 0), .clear],
                                    center: .top,
                                    startRadius: 0,
                                    endRadius: 150
                                )
                            )
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .strokeBorder(
                        isHovered ? accentColor.opacity(0.4) : Color.noirStroke,
                        lineWidth: 1
                    )
            }
    }
}

extension View {
    func terminalCard(isHovered: Bool = false, accent: Color = .phosphorCyan) -> some View {
        modifier(TerminalCardModifier(isHovered: isHovered, accentColor: accent))
    }
}

// MARK: - Scanline Overlay

struct ScanlineOverlay: View {
    let opacity: Double

    var body: some View {
        Canvas { context, size in
            for y in stride(from: 0, to: size.height, by: 2) {
                let rect = CGRect(x: 0, y: y, width: size.width, height: 1)
                context.fill(Path(rect), with: .color(.black.opacity(opacity)))
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - CRT Vignette Effect

struct CRTVignetteModifier: ViewModifier {
    let intensity: Double

    func body(content: Content) -> some View {
        content
            .overlay {
                RadialGradient(
                    colors: [
                        .clear,
                        Color.black.opacity(intensity * 0.3),
                        Color.black.opacity(intensity * 0.6)
                    ],
                    center: .center,
                    startRadius: 200,
                    endRadius: 600
                )
                .allowsHitTesting(false)
            }
    }
}

extension View {
    func crtVignette(intensity: Double = 0.5) -> some View {
        modifier(CRTVignetteModifier(intensity: intensity))
    }
}

// MARK: - Noise Texture

struct NoiseTexture: View {
    let opacity: Double

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                // Generate deterministic noise pattern
                for x in stride(from: 0, to: Int(size.width), by: 3) {
                    for y in stride(from: 0, to: Int(size.height), by: 3) {
                        let noise = sin(Double(x * 13 + y * 7)) * 0.5 + 0.5
                        if noise > 0.6 {
                            let rect = CGRect(x: x, y: y, width: 1, height: 1)
                            context.fill(Path(rect), with: .color(.white.opacity(opacity * noise * 0.3)))
                        }
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Terminal Card Component
// ═══════════════════════════════════════════════════════════════════════════

struct TerminalMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let accentColor: Color
    let subtitle: String?

    @State private var isHovered = false
    @State private var showCopied = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        title: String,
        value: String,
        icon: String,
        color: Color,
        subtitle: String? = nil
    ) {
        self.title = title
        self.value = value
        self.icon = icon
        self.accentColor = color
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Header
            HStack(spacing: Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(accentColor)
                    .phosphorGlow(accentColor, intensity: 0.4, isActive: isHovered)

                Text(title.uppercased())
                    .font(.terminalCaptionSmall)
                    .foregroundStyle(Color.noirTextSecondary)
                    .tracking(1.2)

                Spacer()

                if showCopied {
                    Text("COPIED")
                        .font(.terminalCaptionSmall)
                        .foregroundStyle(Color.phosphorGreen)
                        .transition(.opacity)
                }
            }

            // Value
            Text(value)
                .font(.terminalValue)
                .foregroundStyle(Color.noirTextPrimary)
                .phosphorGlow(accentColor, intensity: isHovered ? 0.6 : 0.3, isActive: true)
                .contentTransition(.numericText())

            // Subtitle
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.terminalCaptionSmall)
                    .foregroundStyle(Color.noirTextTertiary)
            }
        }
        .padding(Spacing.lg)
        .terminalCard(isHovered: isHovered, accent: accentColor)
        .onHover { hovering in
            withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .onTapGesture(count: 2) {
            copyValue()
        }
        .contextMenu {
            Button(action: copyValue) {
                Label("Copy Value", systemImage: "doc.on.doc")
            }
            Button(action: copyWithLabel) {
                Label("Copy with Label", systemImage: "doc.on.doc.fill")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
        .accessibilityHint("Double-click to copy")
    }

    private func copyValue() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        withAnimation { showCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showCopied = false }
        }
    }

    private func copyWithLabel() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("\(title): \(value)", forType: .string)
        withAnimation { showCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showCopied = false }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Terminal Chart Card Component
// ═══════════════════════════════════════════════════════════════════════════

struct TerminalChartCard<Content: View>: View {
    let title: String
    let subtitle: String?
    let onExport: (() -> Void)?
    @ViewBuilder let content: Content

    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        title: String,
        subtitle: String? = nil,
        onExport: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.onExport = onExport
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            // Header
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(title.uppercased())
                        .font(.terminalCaption)
                        .foregroundStyle(Color.noirTextSecondary)
                        .tracking(1)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.terminalCaptionSmall)
                            .foregroundStyle(Color.noirTextTertiary)
                    }
                }

                Spacer()

                if isHovered, let onExport = onExport {
                    Button(action: onExport) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.noirTextSecondary)
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }
            }

            // Chart content
            content
        }
        .padding(Spacing.xl)
        .background {
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .fill(Color.noirSurface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .strokeBorder(Color.noirStroke, lineWidth: 1)
        }
        .onHover { hovering in
            withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Terminal Section Header
// ═══════════════════════════════════════════════════════════════════════════

struct TerminalSectionHeader: View {
    let title: String
    let trailing: String?

    init(_ title: String, trailing: String? = nil) {
        self.title = title
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .bottom) {
            // Decorative line before
            Rectangle()
                .fill(Color.noirStroke)
                .frame(width: 16, height: 1)

            Text(title.uppercased())
                .font(.terminalCaption)
                .foregroundStyle(Color.noirTextSecondary)
                .tracking(2)

            // Decorative line after
            Rectangle()
                .fill(Color.noirStroke)
                .frame(height: 1)

            if let trailing = trailing {
                Text(trailing)
                    .font(.terminalDataSmall)
                    .foregroundStyle(Color.noirTextTertiary)
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Terminal Status Badge
// ═══════════════════════════════════════════════════════════════════════════

struct TerminalStatusBadge: View {
    let status: ConnectionStatus
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
                .phosphorGlow(statusColor, intensity: 0.6, isActive: status.isConnected)

            Text(status.displayText.uppercased())
                .font(.terminalCaptionSmall)
                .foregroundStyle(statusColor)
                .tracking(0.5)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background {
            Capsule()
                .fill(statusColor.opacity(0.15))
                .overlay {
                    Capsule()
                        .strokeBorder(statusColor.opacity(0.3), lineWidth: 1)
                }
        }
        .accessibilityLabel("Status: \(status.displayText)")
    }

    private var statusColor: Color {
        switch status {
        case .connected: return .phosphorGreen
        case .connecting: return .phosphorAmber
        case .disconnected: return .phosphorRed
        case .unknown: return .phosphorRed
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Terminal Empty State
// ═══════════════════════════════════════════════════════════════════════════

struct TerminalEmptyState: View {
    let title: String
    let message: String
    let icon: String
    var action: (() -> Void)? = nil
    var actionLabel: String? = nil

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 32, weight: .thin))
                .foregroundStyle(Color.noirTextTertiary)

            VStack(spacing: Spacing.xs) {
                Text(title)
                    .font(.terminalTitle)
                    .foregroundStyle(Color.noirTextSecondary)

                Text(message)
                    .font(.terminalBodySmall)
                    .foregroundStyle(Color.noirTextTertiary)
                    .multilineTextAlignment(.center)
            }

            if let action = action, let label = actionLabel {
                Button(action: action) {
                    Text(label.uppercased())
                        .font(.terminalCaptionSmall)
                        .tracking(1)
                }
                .buttonStyle(TerminalButtonStyle())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.xxl)
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Terminal Button Style
// ═══════════════════════════════════════════════════════════════════════════

struct TerminalButtonStyle: ButtonStyle {
    var color: Color = .phosphorCyan
    var isProminent: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.terminalCaption)
            .foregroundStyle(isProminent ? Color.noirBackground : color)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm)
            .background {
                if isProminent {
                    Capsule()
                        .fill(color)
                } else {
                    Capsule()
                        .strokeBorder(color.opacity(0.5), lineWidth: 1)
                }
            }
            .phosphorGlow(color, intensity: configuration.isPressed ? 0.8 : 0.3, isActive: true)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Terminal Progress Indicator
// ═══════════════════════════════════════════════════════════════════════════

struct TerminalLoadingIndicator: View {
    @State private var rotation: Double = 0
    let color: Color

    init(color: Color = .phosphorCyan) {
        self.color = color
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: 2)

            Circle()
                .trim(from: 0, to: 0.3)
                .stroke(color, lineWidth: 2)
                .rotationEffect(.degrees(rotation))
        }
        .frame(width: 20, height: 20)
        .phosphorGlow(color, intensity: 0.4, isActive: true)
        .onAppear {
            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Chart Styling Extensions
// ═══════════════════════════════════════════════════════════════════════════

extension Color {
    /// Creates a terminal-style gradient for charts
    static func chartGradient(for color: Color) -> LinearGradient {
        LinearGradient(
            colors: [color, color.opacity(0.7)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static func chartAreaGradient(for color: Color) -> LinearGradient {
        LinearGradient(
            colors: [color.opacity(0.3), color.opacity(0.05), .clear],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
