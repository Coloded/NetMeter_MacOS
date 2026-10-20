import AppKit

enum RuntimeDiagnostics {
    static func run() {
            let routing = """
            Destination Gateway Flags Netif Expire
            default 198.18.0.1 UGSc utun4
            default 192.0.2.1 UGScI en10
            default 192.0.2.1 UGSc en7 1200
            """
            precondition(NetworkDiscovery.choosePrimary(routeText: routing, active: ["utun4", "en7", "en10"], physical: ["en7", "en10"], preferred: nil) == "en7")
            precondition(NetworkDiscovery.choosePrimary(routeText: "default fe80::1 UGSc en8 7200", active: ["en8"], physical: ["en8"], preferred: nil) == "en8")
            precondition(NetworkDiscovery.choosePrimary(routeText: routing, active: [], physical: [], preferred: nil).isEmpty)
            precondition(NetworkDiscovery.choosePrimary(routeText: "", active: ["en9"], physical: ["en9"], preferred: "en9") == "en9")
            var translations: [String: String] = [:]
            for language in L10n.supported {
                let text = L10n.text("menu.settings", language: language)
                precondition(text != "menu.settings" && !text.isEmpty)
                translations[language] = text
            }
            let testID = "diagnostic-" + UUID().uuidString
            GraphAppearance.save(.red, id: testID, component: "line1")
            GraphAppearance.save(.blue, id: testID, component: "label1")
            precondition(GraphAppearance.color(id: testID, component: "line1", fallback: .black).isEqual(NSColor.red))
            precondition(GraphAppearance.color(id: testID, component: "label1", fallback: .black).isEqual(NSColor.blue))
            precondition(GraphAppearance.color(id: testID, component: "line2", fallback: .green).isEqual(NSColor.green))
            for component in ["line1", "label1"] { UserDefaults.standard.removeObject(forKey: "color-\(testID)-\(component)") }
            let metrics = SystemMetrics()
            _ = metrics.cpu()
            _ = metrics.cpuCores()
            _ = metrics.disk()
            Thread.sleep(forTimeInterval: 1)
            let cores = metrics.cpuCores() ?? []
            let values: [String: Any] = [
                "cpu": metrics.cpu()?.footer ?? "unavailable",
                "primaryInterface": defaultInterface(),
                "activeInterfaces": activeInterfaces(),
                "networkRoutingFixtures": true,
                "independentColorPersistence": true,
                "languages": translations,
                "updaterState": UpdateController.configurationIssue(Bundle.main.infoDictionary ?? [:]) ?? "configured",
                "cpuCoreCount": cores.count,
                "cpuCores": cores,
                "cpuCoresValid": !cores.isEmpty && cores.allSatisfy { $0.isFinite && (0...100).contains($0) },
                "cpuGridWide": ResourceGraphView.coreGrid(count: cores.count, size: NSSize(width: 1000, height: 300)).columns,
                "cpuGridTall": ResourceGraphView.coreGrid(count: cores.count, size: NSSize(width: 400, height: 700)).columns,
                "memory": metrics.memory()?.footer ?? "unavailable",
                "gpu": metrics.gpu()?.footer ?? "unavailable",
                "disk": metrics.diskName,
                "diskRates": metrics.disk()?.footer ?? "unavailable",
                "snapFourSides": [NSRect(x: 205, y: 0, width: 100, height: 100),
                                  NSRect(x: -105, y: 0, width: 100, height: 100),
                                  NSRect(x: 0, y: 205, width: 100, height: 100),
                                  NSRect(x: 0, y: -105, width: 100, height: 100)].allSatisfy {
                    WindowDocking.snapOffset($0, NSRect(x: 0, y: 0, width: 200, height: 200)) != nil
                }
            ]
            if let data = try? JSONSerialization.data(withJSONObject: values, options: [.prettyPrinted, .sortedKeys]),
               let output = String(data: data, encoding: .utf8) { print(output) }
    }
}
