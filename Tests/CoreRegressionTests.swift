import Foundation

#if MODEL_TEST_STUB_LOGGER
// Isolate settings semantics from OS logging in this small CLI test target.
final class DiagnosticCenter {
    static let shared = DiagnosticCenter()
    func record(_ category: String, _ event: String, detail: String = "") {}
}
#endif

@main
struct CoreRegressionTests {
    static var checks = 0
    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        checks += 1
        guard condition() else { fputs("FAIL: \(message)\n", stderr); exit(1) }
    }
    static func close(_ actual: Double?, _ expected: Double, _ message: String) {
        expect(actual.map { abs($0 - expected) < 0.000001 } ?? false, message)
    }
    static func main() {
        networkRegressions()
        settingsRegressions()
        print("PASS: \(checks) core regression assertions (network deltas + isolated settings restart)")
    }

    static func networkRegressions() {
        var tracker = NetworkRateTracker()
        let boundary = UInt64(UInt32.max)
        var result = tracker.sample(interface: "en7", counters: (boundary - 100, boundary - 50), uptime: 10)
        expect(result.sample == nil && result.receivedDelta == 0 && result.sentDelta == 0, "first reading is baseline, not idle or traffic")
        result = tracker.sample(interface: "en7", counters: (boundary + 900, boundary + 1950), uptime: 12)
        close(result.sample?.down, 500, "RX crosses 2^32 without a false zero")
        close(result.sample?.up, 1000, "TX crosses 2^32 without a false zero")
        expect(result.receivedDelta == 1000 && result.sentDelta == 2000 && !result.discontinuity, "64-bit deltas retained for totals")

        result = tracker.sample(interface: "en7", counters: (3, boundary + 2450), uptime: 13)
        expect(result.receivedDelta == 0 && result.sentDelta == 500 && result.discontinuity, "RX reset must preserve valid TX traffic")
        close(result.sample?.up, 500, "RX reset does not zero TX speed")
        expect(result.sample?.downAvailable == false && result.sample?.upAvailable == true, "RX reset is marked unavailable while TX remains available")
        result = tracker.sample(interface: "en7", counters: (103, 5), uptime: 14)
        expect(result.receivedDelta == 100 && result.sentDelta == 0 && result.discontinuity, "TX reset must preserve valid RX traffic")
        close(result.sample?.down, 100, "TX reset does not zero RX speed")
        expect(result.sample?.downAvailable == true && result.sample?.upAvailable == false, "TX reset is marked unavailable while RX remains available")

        result = tracker.sample(interface: "en7", counters: nil, uptime: 15)
        expect(result.sample == nil && result.discontinuity, "missing data is unavailable, not a zero sample")
        result = tracker.sample(interface: "en7", counters: (5000, 5000), uptime: 16)
        expect(result.sample == nil && result.receivedDelta == 0, "reconnect rebaselines instead of charging the outage")
        result = tracker.sample(interface: "en8", counters: (500000, 500000), uptime: 17)
        expect(result.sample == nil && result.receivedDelta == 0, "interface switch cannot mix device counters")
        result = tracker.sample(interface: "en8", counters: (500000, 500000), uptime: 18)
        close(result.sample?.down, 0, "known unchanged RX counter is confirmed idle")
        close(result.sample?.up, 0, "known unchanged TX counter is confirmed idle")
        expect(!result.discontinuity, "confirmed idle has no missing-data flag")

        result = tracker.sample(interface: "en8", counters: (600000, 600000), uptime: 18)
        expect(result.sample == nil && result.receivedDelta == 0, "zero interval is rejected")
        result = tracker.sample(interface: "en8", counters: (700000, 700000), uptime: 17)
        expect(result.sample == nil && result.receivedDelta == 0, "negative interval is rejected")
        result = tracker.sample(interface: "en8", counters: (900000, 900000), uptime: 19)
        close(result.sample?.down, 400000, "invalid timestamps do not replace last valid baseline or discard RX bytes")
        close(result.sample?.up, 400000, "invalid timestamps do not replace last valid baseline or discard TX bytes")
        result = tracker.sample(interface: "en8", counters: (900001, 900001), uptime: .nan)
        expect(result.sample == nil && result.receivedDelta == 0, "nonfinite interval is rejected")
        result = tracker.sample(interface: "en8", counters: (901000, 901000), uptime: 21)
        expect(result.sample == nil, "invalid nonfinite clock is followed by a fresh baseline")
        result = tracker.sample(interface: "en8", counters: (999000, 999000), uptime: 100)
        expect(result.sample == nil && result.discontinuity && result.receivedDelta == 0, "long pause is a gap, not continuous sample or billed traffic")
        result = tracker.sample(interface: "en8", counters: (1000000, 1000000), uptime: 101)
        close(result.sample?.down, 1000, "sampling resumes after long pause")
        result = tracker.sample(interface: "", counters: (1001000, 1001000), uptime: 102)
        expect(result.sample == nil, "empty interface remains unavailable")

        tracker.reset()
        let huge = UInt64.max - 10000
        _ = tracker.sample(interface: "en9", counters: (huge, huge), uptime: 200)
        result = tracker.sample(interface: "en9", counters: (huge + 1000, huge + 2000), uptime: 201)
        expect(result.receivedDelta == 1000 && result.sentDelta == 2000, "very large 64-bit totals keep small deltas exact")
        close(result.sample?.up, 2000, "very large 64-bit totals keep speed finite")
    }

    static func settingsRegressions() {
        let domain = "netmeter.qa." + UUID().uuidString
        guard let defaults = UserDefaults(suiteName: domain) else { fatalError("Cannot create isolated suite") }
        defaults.removePersistentDomain(forName: domain)
        defer { defaults.removePersistentDomain(forName: domain) }
        // An individual network edit must not change resources still using legacy fallback.
        for property in GraphSetting.allCases {
            defaults.set(true, forKey: property.globalKey)
            let legacyStore = SettingsStore(defaults: defaults)
            legacyStore.set(false, for: property, graphID: "network")
            expect(!legacyStore.bool(property: property, graphID: "network"), "network individual setting changes")
            for id in SettingsStore.graphIDs where id != "network" {
                expect(legacyStore.bool(property: property, graphID: id), "network edit freezes absent legacy fallback for \(id)")
            }
        }
        defaults.removePersistentDomain(forName: domain)
        let preserved: [String: Any] = [
            "color-memory-title": Data([1, 2, 3]), "font-name-values": "Menlo", "font-size-values": 13,
            "rateUnit": "Mbit/s", "maximumRateUnit": "MiB/s", "totalUnit": "GiB/s",
            "NSWindow Frame TrafficGraphWindow": "111 222 280 172 0 0 1920 1080 ",
            "graphEnabled-gpu": false, "windowLinks": [["cpu", "network"]], "glueWindows": true,
            "totalDown": 123456789.0, "totalUp": 345678901.0
        ]
        for (key, value) in preserved { defaults.set(value, forKey: key) }
        defaults.set(false, forKey: "grid")
        defaults.set(true, forKey: "window-grid-memory")
        defaults.set(false, forKey: "window-top-gpu")
        defaults.set(true, forKey: "alwaysOnTop")
        defaults.set(false, forKey: "window-rates-cpu")
        let store = SettingsStore(defaults: defaults)
        expect(store.bool(property: .grid, graphID: "memory"), "legacy per-graph override wins over global grid")
        expect(!store.bool(property: .grid, graphID: "disk"), "legacy absent override inherits global grid")
        expect(!store.bool(property: .top, graphID: "gpu"), "legacy GPU top preference remains")

        store.set(true, for: .grid, graphID: "cpu")
        expect(store.bool(property: .grid, graphID: "memory"), "individual grid changes preserve another graph")
        expect(!store.bool(property: .top, graphID: "gpu"), "grid changes preserve independent top state")
        expect(!store.bool(property: .rates, graphID: "cpu"), "grid changes preserve independent value visibility")
        store.set(false, for: .rates)
        for id in SettingsStore.graphIDs { expect(!store.bool(property: .rates, graphID: id), "global rates applies to \(id)") }
        expect(store.bool(property: .grid, graphID: "cpu"), "global rates does not change grid")
        expect(!store.bool(property: .top, graphID: "gpu"), "global rates does not change top")
        store.set(false, for: .grid)
        store.set(true, for: .grid, graphID: "memory")
        store.set(false, for: .top)
        store.set(true, for: .top, graphID: "disk")
        defaults.synchronize()
        let reopened = SettingsStore(defaults: UserDefaults(suiteName: domain)!)
        for id in SettingsStore.graphIDs {
            expect(reopened.bool(property: .grid, graphID: id) == (id == "memory"), "restart retains intended grid state for \(id)")
            expect(reopened.bool(property: .top, graphID: id) == (id == "disk"), "restart retains intended top state for \(id)")
            expect(!reopened.bool(property: .rates, graphID: id), "restart retains global rates state for \(id)")
        }
        for (key, value) in preserved {
            expect(NSDictionary(dictionary: ["value": defaults.object(forKey: key)!]).isEqual(to: ["value": value]), "unrelated legacy preference preserved: \(key)")
        }
    }
}
