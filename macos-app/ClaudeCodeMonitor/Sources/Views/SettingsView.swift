import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var sparkleService: SparkleUpdaterService
    @State private var testingConnection = false
    @State private var connectionTestResult: String?
    @State private var selectedTab = SettingsTab.general

    enum SettingsTab {
        case general, connection, filters, updates
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            generalSettings
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(SettingsTab.general)

            connectionSettings
                .tabItem {
                    Label("Connection", systemImage: "network")
                }
                .tag(SettingsTab.connection)

            filterSettings
                .tabItem {
                    Label("Filters", systemImage: "line.3.horizontal.decrease.circle")
                }
                .tag(SettingsTab.filters)

            updatesSettings
                .tabItem {
                    Label("Updates", systemImage: "arrow.triangle.2.circlepath")
                }
                .tag(SettingsTab.updates)
        }
        .frame(minWidth: 480, idealWidth: 540, maxWidth: 600,
               minHeight: 400, idealHeight: 480, maxHeight: .infinity)
    }

    // MARK: - General Settings

    private var generalSettings: some View {
        Form {
            GroupBox {
                VStack(alignment: .leading, spacing: 16) {
                    LabeledContent("Default Time Range") {
                        Picker("", selection: $settingsManager.defaultTimeRangeRaw) {
                            ForEach(TimeRangePreset.allCases.filter { $0 != .custom }, id: \.rawValue) { preset in
                                Text(preset.displayName).tag(preset.rawValue)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 180)
                    }

                    LabeledContent("Refresh Interval") {
                        HStack(spacing: 8) {
                            Slider(
                                value: $settingsManager.refreshInterval,
                                in: 5...300,
                                step: 5
                            ) {
                                EmptyView()
                            } minimumValueLabel: {
                                Text("5s")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } maximumValueLabel: {
                                Text("5m")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 200)

                            Text("\(Int(settingsManager.refreshInterval))s")
                                .font(.system(.body, design: .monospaced))
                                .frame(width: 45, alignment: .trailing)
                        }
                    }
                }
            } label: {
                Label("Dashboard", systemImage: "chart.xyaxis.line")
                    .font(.headline)
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(isOn: $settingsManager.showMenuBarCost) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Show Cost in Menu Bar")
                            Text("Display total cost in the menu bar popup")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.switch)

                    Toggle(isOn: $settingsManager.showMenuBarTokens) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Show Tokens in Menu Bar")
                            Text("Display token usage in the menu bar popup")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                }
            } label: {
                Label("Menu Bar", systemImage: "menubar.rectangle")
                    .font(.headline)
            }

            Spacer(minLength: 20)

            HStack {
                Spacer()
                Button("Reset to Defaults") {
                    settingsManager.resetToDefaults()
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }
        }
        .formStyle(.grouped)
        .padding(20)
    }

    // MARK: - Connection Settings

    private var connectionSettings: some View {
        Form {
            GroupBox {
                VStack(alignment: .leading, spacing: 16) {
                    LabeledContent("Base URL") {
                        TextField("http://localhost:9090", text: $settingsManager.prometheusBaseURLString)
                            .textFieldStyle(.roundedBorder)
                            .frame(minWidth: 250)
                    }

                    HStack(spacing: 12) {
                        Button(action: testConnection) {
                            HStack(spacing: 6) {
                                if testingConnection {
                                    ProgressView()
                                        .scaleEffect(0.5)
                                        .frame(width: 14, height: 14)
                                } else {
                                    Image(systemName: "network")
                                }
                                Text("Test Connection")
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                        .disabled(testingConnection)

                        if let result = connectionTestResult {
                            HStack(spacing: 4) {
                                Image(systemName: result.contains("Success") ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(result.contains("Success") ? .green : .red)
                                Text(result)
                                    .font(.caption)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                (result.contains("Success") ? Color.green : Color.red).opacity(0.1)
                            )
                            .clipShape(Capsule())
                        }

                        Spacer()
                    }
                }
            } label: {
                Label("Prometheus Configuration", systemImage: "server.rack")
                    .font(.headline)
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    ModernEndpointInfo(
                        name: "Default (Local Docker)",
                        url: "http://localhost:9090",
                        description: "Standard Prometheus port"
                    )

                    Divider()

                    ModernEndpointInfo(
                        name: "OTel Collector Direct",
                        url: "http://localhost:8889",
                        description: "OpenTelemetry collector endpoint"
                    )
                }
            } label: {
                Label("Quick Connect", systemImage: "link.circle")
                    .font(.headline)
            }

            Spacer()
        }
        .formStyle(.grouped)
        .padding(20)
    }

    // MARK: - Filter Settings

    private var filterSettings: some View {
        Form {
            GroupBox {
                VStack(alignment: .leading, spacing: 16) {
                    LabeledContent("Terminal Type") {
                        TextField("e.g., claude-code", text: $settingsManager.terminalTypeFilter)
                            .textFieldStyle(.roundedBorder)
                            .frame(minWidth: 200)
                    }

                    LabeledContent("Model") {
                        TextField("e.g., sonnet-4.5", text: $settingsManager.modelFilter)
                            .textFieldStyle(.roundedBorder)
                            .frame(minWidth: 200)
                    }

                    LabeledContent("App Version") {
                        TextField("e.g., 1.0.0", text: $settingsManager.appVersionFilter)
                            .textFieldStyle(.roundedBorder)
                            .frame(minWidth: 200)
                    }
                }
            } label: {
                Label("Metric Filters", systemImage: "line.3.horizontal.decrease.circle")
                    .font(.headline)
            }

            if !settingsManager.activeFilters.isEmpty {
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(settingsManager.activeFilters), id: \.key) { key, value in
                            HStack(spacing: 8) {
                                Label(key, systemImage: "tag.fill")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)

                                Spacer()

                                Text(value)
                                    .font(.system(.caption, design: .monospaced, weight: .medium))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                } label: {
                    Label("Active Filters", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.green)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                    Text("Filter Information")
                        .font(.caption.weight(.medium))
                }
                Text("Leave filters empty to include all values. Filters are applied to all dashboard queries and metrics.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.blue.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Spacer()
        }
        .formStyle(.grouped)
        .padding(20)
    }

    // MARK: - Updates Settings

    private var updatesSettings: some View {
        Form {
            GroupBox {
                VStack(alignment: .leading, spacing: 16) {
                    Toggle(isOn: Binding(
                        get: { sparkleService.automaticallyChecksForUpdates },
                        set: { sparkleService.automaticallyChecksForUpdates = $0 }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Check for Updates Automatically")
                            Text("Checks for updates when the app launches")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.switch)

                    Divider()

                    HStack(spacing: 12) {
                        Button(action: {
                            sparkleService.checkForUpdates()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text("Check Now")
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                        .disabled(!sparkleService.canCheckForUpdates)

                        Spacer()

                        if let lastCheck = sparkleService.lastUpdateCheckDate {
                            Text("Last checked: \(lastCheck, style: .relative) ago")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } label: {
                Label("Automatic Updates", systemImage: "arrow.triangle.2.circlepath.circle")
                    .font(.headline)
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.secondary)
                        Text("How Updates Work")
                            .font(.caption.weight(.medium))
                    }
                    Text("When an update is available, you'll see a notification with release notes. You can choose when to download and install.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(4)
            } label: {
                Label("Information", systemImage: "questionmark.circle")
                    .font(.headline)
            }

            Spacer()
        }
        .formStyle(.grouped)
        .padding(20)
    }

    // MARK: - Actions

    private func testConnection() {
        testingConnection = true
        connectionTestResult = nil

        Task {
            guard let url = settingsManager.prometheusURL else {
                connectionTestResult = "Invalid URL"
                testingConnection = false
                return
            }

            let client = PrometheusClient(baseURL: url)
            do {
                let buildInfo = try await client.checkConnection()
                await MainActor.run {
                    connectionTestResult = "Success! Prometheus v\(buildInfo.version)"
                    testingConnection = false
                }
            } catch {
                await MainActor.run {
                    connectionTestResult = "Failed: \(error.localizedDescription)"
                    testingConnection = false
                }
            }
        }
    }
}

// MARK: - Modern Endpoint Info

struct ModernEndpointInfo: View {
    let name: String
    let url: String
    let description: String
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.system(.body, weight: .medium))
                Text(url)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.blue)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: {
                settingsManager.prometheusBaseURLString = url
            }) {
                Text("Use")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .opacity(isHovered ? 1.0 : 0.7)
        }
        .padding(12)
        .background(isHovered ? Color.gray.opacity(0.08) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(SettingsManager())
    }
}
#endif
