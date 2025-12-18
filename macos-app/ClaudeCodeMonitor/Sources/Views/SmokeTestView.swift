import SwiftUI

struct SmokeTestView: View {
    @ObservedObject var metricsService: MetricsService
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var isRunningTest = false
    @State private var testResults: [TestResult] = []

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
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Results
            ScrollView {
                VStack(spacing: 16) {
                    if testResults.isEmpty && !isRunningTest {
                        emptyState
                    } else {
                        testResultsList
                    }

                    if !metricsService.discoveredMetrics.isEmpty {
                        discoveredMetricsSection
                    }

                    nextStepsSection
                }
                .padding()
            }
        }
        .frame(minWidth: 600, minHeight: 500)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Connectivity & Smoke Test")
                    .font(.title2.bold())
                Text("Validate Prometheus connection and discover Claude Code metrics")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: runSmokeTest) {
                Label(isRunningTest ? "Running..." : "Run Tests", systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(isRunningTest)
        }
        .padding()
        .background(.bar)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Test Results", systemImage: "checkmark.shield")
        } description: {
            Text("Click 'Run Tests' to validate your Prometheus connection and discover available metrics")
        } actions: {
            Button("Run Tests", action: runSmokeTest)
                .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Test Results List

    private var testResultsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Test Results")
                .font(.headline)

            ForEach(testResults) { result in
                TestResultRow(result: result)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Discovered Metrics

    private var discoveredMetricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Discovered Claude Metrics")
                    .font(.headline)
                Text("(\(metricsService.discoveredMetrics.count))")
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 280))], spacing: 8) {
                ForEach(metricsService.discoveredMetrics, id: \.self) { metric in
                    MetricRow(name: metric)
                }
            }
        }
        .padding()
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Next Steps

    private var nextStepsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Setup Guide")
                .font(.headline)

            VStack(alignment: .leading, spacing: 16) {
                SetupStep(
                    number: 1,
                    title: "Start the monitoring stack",
                    code: "docker-compose up -d"
                )

                SetupStep(
                    number: 2,
                    title: "Enable Claude Code telemetry",
                    code: """
                    export CLAUDE_CODE_ENABLE_TELEMETRY=1
                    export OTEL_METRICS_EXPORTER=otlp
                    export OTEL_EXPORTER_OTLP_PROTOCOL=grpc
                    export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317
                    """
                )

                SetupStep(
                    number: 3,
                    title: "Use Claude Code normally",
                    code: "claude"
                )

                SetupStep(
                    number: 4,
                    title: "Verify metrics in Prometheus",
                    code: "open http://localhost:9090/graph"
                )
            }
        }
        .padding()
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
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

// MARK: - Test Result Row

struct TestResultRow: View {
    let result: SmokeTestView.TestResult

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
                .font(.title3)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(result.name)
                    .font(.headline)
                Text(result.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let duration = result.duration {
                Text(String(format: "%.0fms", duration * 1000))
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var iconName: String {
        switch result.status {
        case .passed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .pending: return "circle.dashed"
        }
    }

    private var iconColor: Color {
        switch result.status {
        case .passed: return .green
        case .failed: return .red
        case .warning: return .orange
        case .pending: return .gray
        }
    }

    private var backgroundColor: Color {
        switch result.status {
        case .passed: return .green.opacity(0.1)
        case .failed: return .red.opacity(0.1)
        case .warning: return .orange.opacity(0.1)
        case .pending: return .gray.opacity(0.1)
        }
    }
}

// MARK: - Metric Row

struct MetricRow: View {
    let name: String
    @State private var isHovered = false
    @State private var showCopied = false

    var body: some View {
        HStack {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .foregroundStyle(.blue)
            Text(name)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
            Spacer()

            if showCopied {
                Text("Copied!")
                    .font(.caption2)
                    .foregroundStyle(.green)
                    .transition(.opacity.combined(with: .scale))
            } else if isHovered {
                Button(action: copyToClipboard) {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isHovered ? Color.blue.opacity(0.1) : Color(NSColor.tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
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

// MARK: - Setup Step

struct SetupStep: View {
    let number: Int
    let title: String
    let code: String

    @State private var isHovered = false
    @State private var showCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(number).")
                    .font(.headline)
                    .foregroundStyle(.blue)
                Text(title)
                    .font(.subheadline)
                    .textSelection(.enabled)
            }

            HStack(spacing: 0) {
                // Code block with selectable text
                Text(code)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Copy button
                VStack {
                    Button(action: copyToClipboard) {
                        Group {
                            if showCopied {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.green)
                            } else {
                                Image(systemName: "doc.on.doc")
                                    .foregroundStyle(isHovered ? .white : .gray)
                            }
                        }
                        .font(.caption)
                        .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.plain)
                    .help("Copy to clipboard")

                    Spacer()
                }
                .padding(8)
            }
            .background(.black.opacity(0.85))
            .foregroundStyle(.green)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isHovered ? Color.green.opacity(0.5) : Color.clear, lineWidth: 1)
            )
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
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
        // Format as shell script with shebang
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

#if DEBUG
struct SmokeTestView_Previews: PreviewProvider {
    static var previews: some View {
        SmokeTestView(metricsService: MetricsService())
            .environmentObject(SettingsManager())
    }
}
#endif
