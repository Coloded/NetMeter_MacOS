import Foundation
import CoreWLAN

enum NetworkLinkSpeed {
    private static var cache: [String: (time: TimeInterval, megabits: Double?)] = [:]

    static func megabitsPerSecond(interface name: String, wifi: Bool) -> Double? {
        let now = ProcessInfo.processInfo.systemUptime
        if let cached = cache[name], now - cached.time < 5 { return cached.megabits }
        let rate: Double?
        if wifi {
            let measured = CWWiFiClient.shared().interface(withName: name)?.transmitRate() ?? 0
            rate = measured.isFinite && measured > 0 ? measured : nil
        } else {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/sbin/ifconfig")
            process.arguments = [name]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice
            if (try? process.run()) != nil {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                rate = process.terminationStatus == 0 ? ethernetRate(String(data: data, encoding: .utf8) ?? "") : nil
            } else { rate = nil }
        }
        cache[name] = (now, rate)
        return rate
    }

    static func ethernetRate(_ output: String) -> Double? {
        let lines = output.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        guard lines.contains("status: active"), let media = lines.first(where: { $0.hasPrefix("media:") }) else { return nil }
        // With autoselect, only the parenthesized *negotiated* medium is authoritative.
        let medium: String
        if media.contains("autoselect") {
            guard let start = media.firstIndex(of: "("), let end = media[start...].firstIndex(of: ")") else { return nil }
            medium = String(media[media.index(after: start)..<end])
        } else { medium = String(media.dropFirst("media:".count)) }
        guard let regex = try? NSRegularExpression(pattern: #"\b([0-9]+(?:\.[0-9]+)?)([GM]?)base"#, options: .caseInsensitive),
              let match = regex.firstMatch(in: medium, range: NSRange(medium.startIndex..., in: medium)),
              let numberRange = Range(match.range(at: 1), in: medium),
              let unitRange = Range(match.range(at: 2), in: medium),
              let number = Double(medium[numberRange]), number > 0 else { return nil }
        return number * (medium[unitRange].uppercased() == "G" ? 1000 : 1)
    }

    static func label(interface name: String, wifi: Bool) -> String {
        guard let rate = megabitsPerSecond(interface: name, wifi: wifi) else { return L("network.link_unknown") }
        let gigabit = rate >= 1000
        let value = gigabit ? rate / 1000 : rate
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: L10n.code)
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        let number = formatter.string(from: NSNumber(value: value)) ?? String(value)
        let speed = L(gigabit ? "network.link_gbps" : "network.link_mbps", number)
        return wifi ? L("network.wifi_tx", speed) : speed
    }
}
