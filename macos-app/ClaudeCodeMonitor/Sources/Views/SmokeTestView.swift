import SwiftUI

struct SmokeTestView: View {
    @ObservedObject var metricsService: MetricsService
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var isRunningTest = false
    @State private var testResults: [TestResult] = []
    @State private var appearAnimation = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    struct TestResult: Identifiable {
        let id = UUID()
        let name: String
        let status: TestStatus
        let message: String
        let duration: TimeInterval?

        enum TestStatus {
            case passed, failed, warning, pending
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                // Header
                headerSection
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 10)

                // Results
                if testResults.isEmpty && !isRunningTest {
                    emptyState
                        .opacity(appearAnimation ? 1 : 0)
                        .offset(y: appearAnimation ? 0 : 15)
                } else {
                    testResultsList
                        .opacity(appearAnimation ? 1 : 0)
                        .offset(y: appearAnimation ? 0 : 15)
                }

                if !metricsService.discoveredMetrics.isEmpty {
                    discoveredMetricsSection
                        .opacity(appearAnimation ? 1 : 0)
                        .offset(y: appearAnimation ? 0 : 20)
                }

                nextStepsSection
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 25)
            }
            .padding(Spacing.xl)
        }
        .frame(minWidth: 600, minHeight: 500)
        .background(Color.noirBackground)
        .onAppear {
            withAnimation(reduceMotion ? .none : .easeOut(duration: 0.5)) {
                appearAnimation = true
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.sm) {
                    Circle()
                        .fill(Color.phosphorAmber)
                        .frame(width: 8, height: 8)
                        .phosphorGlow(.phosphorAmber, intensity: 0.6, isActive: true)

                    Text("DIAGNOSTICS")
                        .font(.terminalCaptionSmall)
                        .foregroundStyle(Color.noirTextSecondary)
                        .tracking(2)
                }

                Text("Connectivity & Smoke Test")
                    .font(.terminalHeadline)
                    .foregroundStyle(Color.noirTextPrimary)

                Text("Validate Prometheus connection and discover Claude Code metrics")
                    .font(.terminalBodySmall)
                    .foregroundStyle(Color.noirTextTertiary)
            }

            Spacer()

            Button(action: runSmokeTest) {
                HStack(spacing: Spacing.sm) {
                    if isRunningTest {
                        TerminalLoadingIndicator(color: .phosphorAmber)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "play.fill")
                            .font(.system(size: 11))
                    }
                    Text(isRunningTest ? "RUNNING..." : "RUN TESTS")
                        .font(.terminalCaptionSmall)
                        .tracking(1)
                }
                .foregroundStyle(Color.noirBackground)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)
                .background {
                    Capsule()
                        .fill(Color.phosphorAmber)
                }
                .phosphorGlow(.phosphorAmber, intensity: 0.4, isActive: !isRunningTest)
            }
            .buttonStyle(.plain)
            .disabled(isRunningTest)
        }
        .padding(Spacing.lg)
        .background {
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .fill(Color.noirSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.phosphorAmber.opacity(0.06), .clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .strokeBorder(Color.noirStroke, lineWidth: 1)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "checkmark.shield")
                .font(.system(size: 40, weight: .thin))
                .foregroundStyle(Color.phosphorAmber)
                .phosphorGlow(.phosphorAmber, intensity: 0.4, isActive: true)

            VStack(spacing: Spacing.sm) {
                Text("NO TEST RESULTS")
                    .font(.terminalCaption)
                    .foregroundStyle(Color.noirTextPrimary)
                    .tracking(2)

                Text("Click 'Run Tests' to validate your Prometheus\nconnection and discover available metrics")
                    .font(.terminalBodySmall)
                    .foregroundStyle(Color.noirTextSecondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: runSmokeTest) {
                Text("RUN TESTS")
                    .font(.terminalCaptionSmall)
                    .tracking(1)
            }
            .buttonStyle(TerminalButtonStyle(color: .phosphorAmber, isProminent: true))
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.xxl)
        .background {
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .fill(Color.noirSurface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .strokeBorder(Color.noirStroke, lineWidth: 1)
        }
    }

    // MARK: - Test Results List

    private var testResultsList: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            TerminalSectionHeader("Test Results")

            VStack(spacing: Spacing.sm) {
                ForEach(testResults) { result in
                    TerminalTestResultRow(result: result)
                }
            }
        }
    }

    // MARK: - Discovered Metrics

    private var discoveredMetricsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                TerminalSectionHeader("Discovered Metrics")
                Spacer()
                Text("\(metricsService.discoveredMetrics.count)")
                    .font(.terminalDataSmall)
                    .foregroundStyle(Color.phosphorCyan)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xxs)
                    .background {
                        Capsule()
                            .fill(Color.phosphorCyan.opacity(0.15))
                    }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 280))], spacing: Spacing.sm) {
                ForEach(metricsService.discoveredMetrics, id: \.self) { metric in
                    TerminalMetricRow(name: metric)
                }
            }
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

    // MARK: - Next Steps

    private var nextStepsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            TerminalSectionHeader("Setup Guide")

            VStack(alignment: .leading, spacing: Spacing.lg) {
                TerminalSetupStep(
                    number: 1,
                    title: "Start the monitoring stack",
                    code: "docker-compose up -d"
                )

                TerminalSetupStep(
                    number: 2,
                    title: "Enable Claude Code telemetry",
                    code: """
                    export CLAUDE_CODE_ENABLE_TELEMETRY=1
                    export OTEL_METRICS_EXPORTER=otlp
                    export OTEL_EXPORTER_OTLP_PROTOCOL=grpc
                    export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317
                    """
                )

                TerminalSetupStep(
                    number: 3,
                    title: "Use Claude Code normally",
                    code: "claude"
                )

                TerminalSetupStep(
                    number: 4,
                    title: "Verify metrics in Prometheus",
                    code: "open http://localhost:9090/graph"
                )
            }
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

    // MARK: - Actions

    private func runSmokeTest() {
        isRunningTest = true
        testResults = []

        Task {
            var results: [TestResult] = []

            // Test 1: Connection
            let connectionStart = Date()
            do {
                await metricsService.checkConnection()
                if metricsService.connectionStatus.isConnected {
                    results.append(TestResult(
                        name: "Prometheus Connection",
                        status: .passed,
                        message: metricsService.connectionStatus.displayText,
                        duration: Date().timeIntervalSince(connectionStart)
                    ))
                } else {
                    results.append(TestResult(
                        name: "Prometheus Connection",
                        status: .failed,
                        message: metricsService.errorMessage ?? "Connection failed",
                        duration: Date().timeIntervalSince(connectionStart)
                    ))
                }
            }

            // Test 2: API Endpoints
            let apiStart = Date()
            if let prometheusURL = settingsManager.prometheusURL {
                let client = PrometheusClient(baseURL: prometheusURL)
                do {
                    _ = try await client.getTargets()
                    results.append(TestResult(
                        name: "Prometheus API",
                        status: .passed,
                        message: "API endpoints responding",
                        duration: Date().timeIntervalSince(apiStart)
                    ))
                } catch {
                    results.append(TestResult(
                        name: "Prometheus API",
                        status: .failed,
                        message: error.localizedDescription,
                        duration: Date().timeIntervalSince(apiStart)
                    ))
                }
            } else {
                results.append(TestResult(
                    name: "Prometheus API",
                    status: .failed,
                    message: "Invalid Prometheus URL configured",
                    duration: Date().timeIntervalSince(apiStart)
                ))
            }

            // Test 3: Metric Discovery
            let discoveryStart = Date()
            await metricsService.discoverClaudeMetrics()
            if metricsService.discoveredMetrics.isEmpty {
                results.append(TestResult(
                    name: "Claude Code Metrics",
                    status: .warning,
                    message: "No Claude Code metrics found. Enable telemetry and use Claude Code to generate metrics.",
                    duration: Date().timeIntervalSince(discoveryStart)
                ))
            } else {
                results.append(TestResult(
                    name: "Claude Code Metrics",
                    status: .passed,
                    message: "Found \(metricsService.discoveredMetrics.count) metrics",
                    duration: Date().timeIntervalSince(discoveryStart)
                ))
            }

            // Test 4: Query Execution
            let queryStart = Date()
            if let prometheusURL = settingsManager.prometheusURL {
                let queryClient = PrometheusClient(baseURL: prometheusURL)
                do {
                    let testQuery = "up"
                    _ = try await queryClient.query(testQuery)
                    results.append(TestResult(
                        name: "Query Execution",
                        status: .passed,
                        message: "PromQL queries working",
                        duration: Date().timeIntervalSince(queryStart)
                    ))
                } catch {
                    results.append(TestResult(
                        name: "Query Execution",
                        status: .failed,
                        message: error.localizedDescription,
                        duration: Date().timeIntervalSince(queryStart)
                    ))
                }
            } else {
                results.append(TestResult(
                    name: "Query Execution",
                    status: .failed,
                    message: "Invalid Prometheus URL configured",
                    duration: Date().timeIntervalSince(queryStart)
                ))
            }

            await MainActor.run {
                testResults = results
                isRunningTest = false
            }
        }
    }
}

// MARK: - Terminal Test Result Row

struct TerminalTestResultRow: View {
    let result: SmokeTestView.TestResult
    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: iconName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(statusColor)
                .frame(width: 24)
                .phosphorGlow(statusColor, intensity: 0.5, isActive: result.status == .passed)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(result.name)
                    .font(.terminalTitle)
                    .foregroundStyle(Color.noirTextPrimary)
                Text(result.message)
                    .font(.terminalCaptionSmall)
                    .foregroundStyle(Color.noirTextSecondary)
                    .lineLimit(2)
            }

            Spacer()

            if let duration = result.duration {
                Text(String(format: "%.0fms", duration * 1000))
                    .font(.terminalDataSmall)
                    .foregroundStyle(Color.noirTextTertiary)
            }
        }
        .padding(Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .fill(statusColor.opacity(isHovered ? 0.15 : 0.08))
                .overlay {
                    RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                        .strokeBorder(statusColor.opacity(0.25), lineWidth: 1)
                }
        }
        .onHover { hovering in
            withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }

    private var iconName: String {
        switch result.status {
        case .passed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .pending: return "circle.dashed"
        }
    }

    private var statusColor: Color {
        switch result.status {
        case .passed: return .phosphorGreen
        case .failed: return .phosphorRed
        case .warning: return .phosphorAmber
        case .pending: return .noirTextTertiary
        }
    }
}

// MARK: - Terminal Metric Row

struct TerminalMetricRow: View {
    let name: String
    @State private var isHovered = false
    @State private var showCopied = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 11))
                .foregroundStyle(Color.phosphorCyan)
                .phosphorGlow(.phosphorCyan, intensity: 0.3, isActive: isHovered)

            Text(name)
                .font(.terminalDataSmall)
                .foregroundStyle(Color.noirTextSecondary)
                .textSelection(.enabled)
                .lineLimit(1)

            Spacer()

            if showCopied {
                Text("COPIED")
                    .font(.terminalCaptionSmall)
                    .foregroundStyle(Color.phosphorGreen)
                    .transition(.opacity.combined(with: .scale))
            } else if isHovered {
                Button(action: copyToClipboard) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.noirTextTertiary)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background {
            RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                .fill(isHovered ? Color.phosphorCyan.opacity(0.08) : Color.noirBackground.opacity(0.5))
                .overlay {
                    RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                        .strokeBorder(isHovered ? Color.phosphorCyan.opacity(0.3) : Color.noirStroke, lineWidth: 1)
                }
        }
        .onHover { hovering in
            withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            copyToClipboard()
        }
        .contextMenu {
            Button(action: copyToClipboard) {
                Label("Copy Metric Name", systemImage: "doc.on.doc")
            }
        }
        .help("Click to copy metric name")
    }

    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(name, forType: .string)
        withAnimation(.spring(response: 0.3)) {
            showCopied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showCopied = false
            }
        }
    }
}

// MARK: - Terminal Setup Step

struct TerminalSetupStep: View {
    let number: Int
    let title: String
    let code: String

    @State private var isHovered = false
    @State private var showCopied = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Text("\(number)")
                    .font(.terminalDataSmall)
                    .foregroundStyle(Color.noirBackground)
                    .frame(width: 18, height: 18)
                    .background {
                        Circle()
                            .fill(Color.phosphorCyan)
                    }
                    .phosphorGlow(.phosphorCyan, intensity: 0.3, isActive: true)

                Text(title)
                    .font(.terminalCaption)
                    .foregroundStyle(Color.noirTextSecondary)
            }

            HStack(spacing: 0) {
                // Code block
                Text(code)
                    .font(.terminalDataSmall)
                    .foregroundStyle(Color.phosphorGreen)
                    .textSelection(.enabled)
                    .padding(Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Copy button
                VStack {
                    Button(action: copyToClipboard) {
                        Group {
                            if showCopied {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.phosphorGreen)
                            } else {
                                Image(systemName: "doc.on.doc")
                                    .foregroundStyle(isHovered ? Color.phosphorGreen : Color.noirTextTertiary)
                            }
                        }
                        .font(.system(size: 11))
                        .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.plain)
                    .help("Copy to clipboard")

                    Spacer()
                }
                .padding(Spacing.sm)
            }
            .background {
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .fill(Color.noirBackground)
                    .overlay {
                        RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                            .strokeBorder(isHovered ? Color.phosphorGreen.opacity(0.4) : Color.noirStroke, lineWidth: 1)
                    }
            }
            .onHover { hovering in
                withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }
            .contextMenu {
                Button(action: copyToClipboard) {
                    Label("Copy Command", systemImage: "doc.on.doc")
                }

                if code.contains("\n") {
                    Button(action: copyFirstLine) {
                        Label("Copy First Line", systemImage: "text.line.first.and.arrowtriangle.forward")
                    }

                    Button(action: copyAllLines) {
                        Label("Copy as Shell Script", systemImage: "terminal")
                    }
                }
            }
        }
    }

    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        withAnimation(.spring(response: 0.3)) {
            showCopied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showCopied = false
            }
        }
    }

    private func copyFirstLine() {
        let firstLine = code.components(separatedBy: "\n").first ?? code
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(firstLine, forType: .string)
        withAnimation(.spring(response: 0.3)) {
            showCopied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showCopied = false
            }
        }
    }

    private func copyAllLines() {
        let script = "#!/bin/bash\n\n" + code
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(script, forType: .string)
        withAnimation(.spring(response: 0.3)) {
            showCopied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showCopied = false
            }
        }
    }
}

// MARK: - Legacy Components (kept for compatibility)

struct TestResultRow: View {
    let result: SmokeTestView.TestResult

    var body: some View {
        TerminalTestResultRow(result: result)
    }
}

struct MetricRow: View {
    let name: String

    var body: some View {
        TerminalMetricRow(name: name)
    }
}

struct SetupStep: View {
    let number: Int
    let title: String
    let code: String

    var body: some View {
        TerminalSetupStep(number: number, title: title, code: code)
    }
}

#if DEBUG
struct SmokeTestView_Previews: PreviewProvider {
    static var previews: some View {
        SmokeTestView(metricsService: MetricsService())
            .environmentObject(SettingsManager())
    }
}
#endif
