import Foundation

enum GraphSetting: String, CaseIterable {
    case grid, rates, top
    var globalKey: String { self == .top ? "alwaysOnTop" : rawValue }
    func key(_ graph: String) -> String { graph == "network" ? globalKey : "window-\(rawValue)-\(graph)" }
}

final class SettingsStore {
    static let graphIDs = ["network", "cpu", "memory", "gpu", "disk"]
    let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    func bool(property: GraphSetting, graphID: String) -> Bool {
        defaults.object(forKey: property.key(graphID)) as? Bool
            ?? defaults.object(forKey: property.globalKey) as? Bool ?? true
    }
    // Existing keys remain authoritative. No destructive migration is necessary.
    func set(_ value: Bool, for property: GraphSetting, graphID: String? = nil) {
        if let graphID {
            // The legacy network key is also the fallback for resource windows.
            // Freeze their effective values before changing only the network graph.
            if graphID == "network" {
                let preserved = Self.graphIDs.filter { $0 != "network" }.map { ($0, bool(property: property, graphID: $0)) }
                for (id, existing) in preserved { defaults.set(existing, forKey: property.key(id)) }
            }
            defaults.set(value, forKey: property.key(graphID))
        }
        else {
            defaults.set(value, forKey: property.globalKey)
            for id in Self.graphIDs { defaults.set(value, forKey: property.key(id)) }
        }
        DiagnosticCenter.shared.record("settings", "graph_setting_changed", detail: property.rawValue)
    }
    var diagnosticSummary: [String: Any] {
        var result: [String: Any] = [:]
        for id in Self.graphIDs {
            result[id] = Dictionary(uniqueKeysWithValues: GraphSetting.allCases.map { ($0.rawValue, bool(property: $0, graphID: id)) })
        }
        let allowed: [String: Set<String>] = [
            "graphStyle": ["classic", "macos"], "language": ["system", "en", "ru", "ar", "zh-Hans"],
            "rateUnit": Set(rateUnitChoices.map { $0.0 }), "maximumRateUnit": Set(rateUnitChoices.map { $0.0 }),
            "totalUnit": Set(rateUnitChoices.map { $0.0 })]
        for (key, values) in allowed {
            if let value = defaults.string(forKey: key), values.contains(value) { result[key] = value }
        }
        result["fontAutoFit"] = defaults.object(forKey: "fontAutoFit") as? Bool ?? true
        return result
    }
}
