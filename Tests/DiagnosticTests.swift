import Foundation

@main
struct DiagnosticTests {
    static var checks = 0
    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        checks += 1
        guard condition() else { fputs("FAIL: \(message)\n", stderr); exit(1) }
    }
    static func main() throws {
        let suite = "netmeter.qa.diagnostics." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = SettingsStore(defaults: defaults)
        let privateValues = ["qa_TOKEN_8397_private", "/Users/qa/secret/private.txt", "Private-WiFi-SSID", "aa:bb:cc:dd:ee:ff", "198.51.100.123"]
        for (index, value) in privateValues.enumerated() { defaults.set(value, forKey: "private-fixture-\(index)") }
        defaults.set(privateValues[0], forKey: "language")
        defaults.set(privateValues[1], forKey: "graphStyle")
        defaults.set(privateValues[2], forKey: "rateUnit")
        defaults.set("GiB/s", forKey: "totalUnit")
        defaults.set("ru", forKey: "maximumRateUnit") // wrong enum type must also be excluded.
        let center = DiagnosticCenter.shared
        center.record("command", "failed", detail: privateValues[1], interval: 0)
        center.record("command", "failed", detail: "https://example.invalid/?token=" + privateValues[0], interval: 0)
        center.record("command", "failed", detail: privateValues[0], interval: 0)
        center.record("command", "failed", detail: privateValues[4], interval: 0)
        center.record(privateValues[0], privateValues[4], interval: 0)
        center.sensor(privateValues[2], available: true)
        center.sensor("gpu", available: false)
        center.sensor("gpu", available: false)
        center.sensor("gpu", available: true)
        center.record("network", "baseline_reset", detail: "network")
        center.record("network", "baseline_reset", detail: "network")
        let info: [String: Any] = ["CFBundleShortVersionString": "1.1.4", "CFBundleVersion": "6", "SUPublicEDKey": privateValues[0], "arbitrarySecret": privateValues[1]]
        var report = center.report(settings: store, info: info)
        let data = try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys])
        let text = String(data: data, encoding: .utf8)!
        for value in privateValues { expect(!text.contains(value), "diagnostic export excludes private fixture \(value)") }
        expect(!text.contains("SUPublicEDKey"), "diagnostics omit update keys")
        expect(report["version"] as? String == "1.1.4" && report["build"] as? String == "6", "version and build included")
        expect(["arm64", "x86_64"].contains(report["architecture"] as? String ?? ""), "architecture included")
        expect(!(report["macOS"] as? String ?? "").isEmpty, "macOS version included")
        let settings = report["settings"] as? [String: Any] ?? [:]
        expect(settings["totalUnit"] as? String == "GiB/s", "valid enum preference retained")
        expect(settings["language"] == nil && settings["graphStyle"] == nil && settings["rateUnit"] == nil && settings["maximumRateUnit"] == nil, "invalid or private enum values omitted")
        let events = report["events"] as? [[String: String]] ?? []
        expect(events.filter { $0["category"] == "command" && $0["detail"] == "redacted" }.count == 4, "bare token/IP and paths are explicitly redacted")
        expect((report["sensors"] as? [String: Bool])?[privateValues[2]] == nil, "private sensor name rejected")
        expect(events.filter { $0["code"] == "baseline_reset" }.count == 1, "repeated errors are throttled")
        expect(events.filter { $0["category"] == "sensor" && $0["detail"] == "gpu" }.count == 2, "sensor events record transitions, not every poll")
        expect((report["sensors"] as? [String: Bool])?["gpu"] == true, "current sensor availability included")
        for _ in 0..<240 { center.record("metrics", "sampling_gap", interval: 0) }
        report = center.report(settings: store, info: info)
        expect((report["events"] as? [[String: String]])?.count == 200, "diagnostic ring buffer is bounded to 200 events")
        print("PASS: \(checks) diagnostic privacy, throttle, availability and bounded-history assertions")
    }
}
