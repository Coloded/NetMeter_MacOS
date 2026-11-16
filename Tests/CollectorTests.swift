import Foundation

final class DiagnosticCenter {
    static let shared = DiagnosticCenter()
    func record(_ category: String, _ code: String, detail: String = "") {}
    func sensor(_ name: String, available: Bool) {}
}
var workerChecks = 0
var resets = 0
var simulatedGPUAvailable = false
var counterValue: UInt64 = 1000
func worker() { precondition(!Thread.isMainThread); workerChecks += 1 }
func defaultInterface() -> String { worker(); return "fixture0" }
func counters() -> [String: (received: UInt64, sent: UInt64)] { worker(); counterValue += 100; return ["fixture0": (counterValue, counterValue)] }
enum NetworkDiscovery { static func displayName(_ name: String) -> String { worker(); return "Fixture (\(name))" } }
final class SystemMetrics {
    func resetBaselines() { worker(); resets += 1 }
    func cpu() -> ResourceReading? { worker(); return ResourceReading(first: 0.25, header: "cpu", footer: "25%") }
    func memory() -> ResourceReading? { worker(); return nil }
    func gpu() -> ResourceReading? { worker(); return simulatedGPUAvailable ? ResourceReading(first: 0.5, header: "gpu", footer: "50%") : nil }
    func disk() -> ResourceReading? { worker(); return nil }
    func cpuCores() -> [Double]? { worker(); return [0.25] }
}
@main struct CollectorTests {
    static var assertions = 0
    static func check(_ condition: Bool, _ message: String) { assertions += 1; guard condition else { fatalError(message) } }
    static func wait(_ finished: () -> Bool) {
        let deadline = Date().addingTimeInterval(3)
        while !finished(), Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.005)) }
        check(finished(), "collector completion deadline")
    }
    static func main() {
        let collector = MetricsCollector()
        var result: MetricsSnapshot?
        var completions = 0
        collector.collect(selection: "auto") { snapshot in
            check(Thread.isMainThread, "completion on main thread")
            completions += 1; result = snapshot
        }
        collector.collect(selection: "auto") { _ in fatalError("overlapping collect must be suppressed") }
        wait { result != nil }
        check(completions == 1, "one completion")
        check(workerChecks >= 8, "discovery and sensors executed off main")
        check(result?.interface == "fixture0", "auto selection uses primary discovery")
        check(result?.network.sample == nil, "first snapshot baseline unavailable")
        check(result?.readings["gpu"] == nil, "unavailable sensor remains absent")
        result = nil
        simulatedGPUAvailable = true
        collector.collect(selection: "auto") { result = $0 }
        wait { result != nil }
        check(result?.readings["gpu"]?.first == 0.5, "sensor recovers on subsequent sample")
        check(result?.network.receivedDelta == 100, "valid sample counts delta once")
        result = nil
        collector.didWake()
        collector.collect(selection: "auto") { result = $0 }
        wait { result != nil }
        check(result?.gap == true, "wake creates explicit gap")
        check(result?.network.sample == nil && result?.network.receivedDelta == 0, "wake rebases without totals jump")
        check(resets > 0, "wake resets sensor baselines")
        print("PASS: \(assertions) collector assertions; actual collector, simulated discovery/sensors")
    }
}
