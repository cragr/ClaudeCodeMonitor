import SwiftUI

// MARK: - Terminal Code Block

/// Displays code or file path with a copy-to-clipboard button
struct TerminalCodeBlock: View {
    let code: String
    @State private var showCopied = false

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Text(code)
                .font(.terminalDataSmall)
                .foregroundStyle(Color.phosphorGreen)
                .textSelection(.enabled)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background {
                    RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                        .fill(Color.noirBackground)
                        .overlay {
                            RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                                .strokeBorder(Color.noirStroke, lineWidth: 1)
                        }
                }

            Button(action: copyToClipboard) {
                Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 10))
                    .foregroundStyle(showCopied ? Color.phosphorGreen : Color.noirTextTertiary)
            }
            .buttonStyle(.plain)
        }
    }

    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        withAnimation { showCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showCopied = false }
        }
    }
}

// MARK: - Terminal Detail Row

/// Key-value row for displaying details (label on left, value on right)
struct TerminalDetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.terminalCaptionSmall)
                .foregroundStyle(Color.noirTextTertiary)
            Spacer()
            Text(value)
                .font(.terminalData)
                .foregroundStyle(Color.noirTextSecondary)
                .textSelection(.enabled)
        }
    }
}

// MARK: - Terminal Token Detail Row

/// Specialized row for token breakdown details
struct TerminalTokenDetailRow: View {
    let label: String
    let value: Int

    var body: some View {
        HStack {
            Text(label)
                .font(.terminalCaptionSmall)
                .foregroundStyle(Color.noirTextQuaternary)
            Spacer()
            Text(NumberFormatting.decimal(value))
                .font(.terminalDataSmall)
                .foregroundStyle(Color.noirTextTertiary)
        }
    }
}

// MARK: - Terminal Model Usage Row

/// Expandable row showing model token usage with cost breakdown
struct TerminalModelUsageRow: View {
    let modelName: String
    let usage: ModelUsage
    let fullName: String
    let color: Color

    @State private var isHovered = false
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                HStack(spacing: Spacing.sm) {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                        .phosphorGlow(color, intensity: 0.4, isActive: isHovered)

                    Text(modelName)
                        .font(.terminalCaption)
                        .foregroundStyle(Color.noirTextSecondary)
                }

                Spacer()

                Text(NumberFormatting.tokens(usage.totalTokens))
                    .font(.terminalData)
                    .foregroundStyle(isHovered ? color : Color.noirTextPrimary)

                Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.noirTextTertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .buttonStyle(.plain)
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    TerminalTokenDetailRow(label: "Input", value: usage.inputTokens)
                    TerminalTokenDetailRow(label: "Output", value: usage.outputTokens)
                    TerminalTokenDetailRow(label: "Cache Read", value: usage.cacheReadInputTokens)
                    TerminalTokenDetailRow(label: "Cache Write", value: usage.cacheCreationInputTokens)

                    Divider()
                        .background(Color.noirStroke)

                    HStack {
                        Text("Est. Cost")
                            .font(.terminalCaptionSmall)
                            .foregroundStyle(Color.noirTextTertiary)
                        Spacer()
                        Text(String(format: "$%.2f", usage.estimatedCost(for: fullName)))
                            .font(.terminalData)
                            .foregroundStyle(Color.phosphorGreen)
                            .phosphorGlow(.phosphorGreen, intensity: 0.3, isActive: true)
                    }
                }
                .padding(.leading, Spacing.lg)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(Spacing.sm)
        .background(isHovered ? color.opacity(0.05) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}
