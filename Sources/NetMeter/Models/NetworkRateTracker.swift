import Foundation

struct NetworkMeasurement {
    let sample: NetworkSample?
    let receivedDelta: UInt64
    let sentDelta: UInt64
    let discontinuity: Bool
}

struct NetworkRateTracker {
    private var previous: (interface: String, received: UInt64, sent: UInt64, time: Double)?
    mutating func reset() { previous = nil }
    mutating func sample(interface: String, counters: (received: UInt64, sent: UInt64)?, uptime: Double) -> NetworkMeasurement {
        guard !interface.isEmpty, let counters, uptime.isFinite else {
            previous = nil
            return NetworkMeasurement(sample: nil, receivedDelta: 0, sentDelta: 0, discontinuity: true)
        }
        if let old = previous, old.interface == interface, uptime <= old.time {
            return NetworkMeasurement(sample: nil, receivedDelta: 0, sentDelta: 0, discontinuity: true)
        }
        defer { previous = (interface, counters.received, counters.sent, uptime) }
        guard let old = previous, old.interface == interface, uptime > old.time, uptime - old.time <= 5 else {
            return NetworkMeasurement(sample: nil, receivedDelta: 0, sentDelta: 0, discontinuity: true)
        }
        let rxReset = counters.received < old.received, txReset = counters.sent < old.sent
        let rx = rxReset ? 0 : counters.received - old.received
        let tx = txReset ? 0 : counters.sent - old.sent
        return NetworkMeasurement(sample: NetworkSample(down: Double(rx) / (uptime - old.time), up: Double(tx) / (uptime - old.time), downAvailable: !rxReset, upAvailable: !txReset),
                                  receivedDelta: rx, sentDelta: tx, discontinuity: rxReset || txReset)
    }
}
