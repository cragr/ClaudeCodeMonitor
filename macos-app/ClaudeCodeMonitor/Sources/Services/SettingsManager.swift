import Foundation
import SwiftUI

@MainActor
class SettingsManager: ObservableObject {
    @AppStorage("prometheusBaseURL") var prometheusBaseURLString: String = "http://localhost:9090"
    @AppStorage("refreshInterval") var refreshInterval: Double = 15.0
    @AppStorage("defaultTimeRange") var defaultTimeRangeRaw: String = TimeRangePreset.last15Minutes.rawValue
    @AppStorage("terminalTypeFilter") var terminalTypeFilter: String = ""
    @AppStorage("modelFilter") var modelFilter: String = ""
    @AppStorage("appVersionFilter") var appVersionFilter: String = ""
    @AppStorage("showMenuBarCost") var showMenuBarCost: Bool = true
    @AppStorage("showMenuBarTokens") var showMenuBarTokens: Bool = true
    @AppStorage("pricingProvider") var pricingProviderRaw: String = PricingProvider.anthropic.rawValue

    var prometheusURL: URL? {
        URL(string: prometheusBaseURLString)
    }

    var defaultTimeRange: TimeRangePreset {
        get { TimeRangePreset(rawValue: defaultTimeRangeRaw) ?? .last15Minutes }
        set { defaultTimeRangeRaw = newValue.rawValue }
    }

    var pricingProvider: PricingProvider {
        get { PricingProvider(rawValue: pricingProviderRaw) ?? .anthropic }
        set { pricingProviderRaw = newValue.rawValue }
    }

    var activeFilters: [String: String] {
        var filters: [String: String] = [:]
        if !terminalTypeFilter.isEmpty {
            filters["terminal_type"] = terminalTypeFilter
        }
        if !modelFilter.isEmpty {
            filters["model"] = modelFilter
        }
        if !appVersionFilter.isEmpty {
            filters["app_version"] = appVersionFilter
        }
        return filters
    }

    func resetToDefaults() {
        prometheusBaseURLString = "http://localhost:9090"
        refreshInterval = 15.0
        defaultTimeRangeRaw = TimeRangePreset.last15Minutes.rawValue
        terminalTypeFilter = ""
        modelFilter = ""
        appVersionFilter = ""
        showMenuBarCost = true
        showMenuBarTokens = true
        pricingProviderRaw = PricingProvider.anthropic.rawValue
    }
}
