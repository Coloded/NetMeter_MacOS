import Foundation

struct MetricsSnapshot {
    let interface: String
    let interfaceTitle: String
    let network: NetworkMeasurement
    let readings: [String: ResourceReading]
    let cores: [Double]?
    let gap: Bool
}

final class MetricsCollector {
    private let queue = DispatchQueue(label: "local.traffic.meter.metrics", qos: .utility)
    private lazy var metrics = SystemMetrics()
    private var network = NetworkRateTracker()
    private var lastTime: Double?
    private var currentInterface = ""
    private var wakePending = false
    func didWake() { queue.async { [self] in wakePending = true; network.reset(); metrics.resetBaselines() } }
    private var inFlight = false // accessed on main only
    func collect(selection: String, completion: @escaping (MetricsSnapshot) -> Void) {
        precondition(Thread.isMainThread)
        guard !inFlight else { return }
        inFlight = true
        queue.async { [self] in
            let now = ProcessInfo.processInfo.systemUptime
            let gap = wakePending || (lastTime.map { now - $0 > 5 } ?? false)
            wakePending = false
            lastTime = now
            if gap { network.reset(); metrics.resetBaselines(); DiagnosticCenter.shared.record("metrics", "sampling_gap") }
            let primary = defaultInterface()
            let selected = selection == "auto" ? primary : selection
            if selected != currentInterface {
                currentInterface = selected
                DiagnosticCenter.shared.record("network", "interface_changed")
            }
            let measurement = network.sample(interface: selected, counters: counters()[selected], uptime: ProcessInfo.processInfo.systemUptime)
            if measurement.discontinuity { DiagnosticCenter.shared.record("network", "baseline_reset") }
            DiagnosticCenter.shared.sensor("network", available: measurement.sample != nil)
            let candidates = ["cpu": metrics.cpu(), "memory": metrics.memory(), "gpu": metrics.gpu(), "disk": metrics.disk()]
            var readings: [String: ResourceReading] = [:]
            for (id, reading) in candidates {
                if let reading { readings[id] = reading }
                DiagnosticCenter.shared.sensor(id, available: reading != nil)
            }
            let result = MetricsSnapshot(interface: selected, interfaceTitle: NetworkDiscovery.displayName(selected), network: measurement,
                                         readings: readings, cores: metrics.cpuCores(), gap: gap)
            DispatchQueue.main.async { [self] in inFlight = false; completion(result) }
        }
    }
}
