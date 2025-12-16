import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var testingConnection = false
    @State private var connectionTestResult: String?

    var body: some View {
        TabView {
            generalSettings
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            connectionSettings
                .tabItem {
                    Label("Connection", systemImage: "network")
                }

            filterSettings
                .tabItem {
                    Label("Filters", systemImage: "line.3.horizontal.decrease.circle")
                }
        }
        .frame(width: 500, height: 450)
    }

    // MARK: - General Settings

    private var generalSettings: some View {
        Form {
            Section("Dashboard") {
                Picker("Default Time Range", selection: $settingsManager.defaultTimeRangeRaw) {
                    ForEach(TimeRangePreset.allCases.filter { $0 != .custom }, id: \.rawValue) { preset in
                        Text(preset.displayName).tag(preset.rawValue)
                    }
                }

                HStack {
                    Text("Refresh Interval")
                    Spacer()
                    TextField("Seconds", value: $settingsManager.refreshInterval, format: .number)
                        .frame(width: 80)
                        .textFieldStyle(.roundedBorder)
                    Text("seconds")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Menu Bar") {
                Toggle("Show Cost in Menu Bar", isOn: $settingsManager.showMenuBarCost)
                Toggle("Show Tokens in Menu Bar", isOn: $settingsManager.showMenuBarTokens)
            }

            Section {
                Button("Reset to Defaults") {
                    settingsManager.resetToDefaults()
                }
                .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Connection Settings

    private var connectionSettings: some View {
        Form {
            Section("Prometheus") {
                TextField("Base URL", text: $settingsManager.prometheusBaseURLString)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    if testingConnection {
                        ProgressView()
                            .scaleEffect(0.7)
                    }

                    Button("Test Connection") {
                        testConnection()
                    }
                    .disabled(testingConnection)

                    if let result = connectionTestResult {
                        Text(result)
                            .font(.caption)
                            .foregroundStyle(result.contains("Success") ? .green : .red)
                    }
                }
            }

            Section("Common Endpoints") {
                VStack(alignment: .leading, spacing: 8) {
                    EndpointInfo(
                        name: "Default (Local Docker)",
                        url: "http://localhost:9090"
                    )
                    EndpointInfo(
                        name: "OTel Collector Direct",
                        url: "http://localhost:8889"
                    )
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Filter Settings

    private var filterSettings: some View {
        Form {
            Section("Metric Filters") {
                TextField("Terminal Type", text: $settingsManager.terminalTypeFilter)
                    .textFieldStyle(.roundedBorder)

                TextField("Model", text: $settingsManager.modelFilter)
                    .textFieldStyle(.roundedBorder)

                TextField("App Version", text: $settingsManager.appVersionFilter)
                    .textFieldStyle(.roundedBorder)
            }

            Section {
                Text("Leave filters empty to include all values. Filters apply to dashboard queries.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !settingsManager.activeFilters.isEmpty {
                Section("Active Filters") {
                    ForEach(Array(settingsManager.activeFilters), id: \.key) { key, value in
                        HStack {
                            Text(key)
                                .font(.caption.monospaced())
                            Text("=")
                                .foregroundStyle(.secondary)
                            Text(value)
                                .font(.caption.monospaced())
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
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

// MARK: - Endpoint Info

struct EndpointInfo: View {
    let name: String
    let url: String
    @EnvironmentObject var settingsManager: SettingsManager

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(name)
                    .font(.caption)
                Text(url)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Use") {
                settingsManager.prometheusBaseURLString = url
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
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
