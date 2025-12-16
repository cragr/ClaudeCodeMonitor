import SwiftUI

@MainActor
class AppState: ObservableObject {
    @Published var showSettings = false
    @Published var isConnected = false
    @Published var lastError: String?
    @Published var discoveredMetrics: [String] = []

    init() {}
}
