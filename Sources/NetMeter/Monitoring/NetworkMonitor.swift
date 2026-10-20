import Foundation
import Darwin
import SystemConfiguration

enum NetworkDiscovery {
    static func isTunnel(_ name: String) -> Bool {
        ["utun", "tun", "tap", "ppp", "ipsec", "gif", "stf"].contains { name.hasPrefix($0) }
    }

    static func hardware() -> [String: String] {
        var result: [String: String] = [:]
        for interface in SCNetworkInterfaceCopyAll() as? [SCNetworkInterface] ?? [] {
            guard let name = SCNetworkInterfaceGetBSDName(interface) as String? else { continue }
            let type = SCNetworkInterfaceGetInterfaceType(interface) as String?
            if type == kSCNetworkInterfaceTypeIEEE80211 as String { result[name] = "Wi-Fi" }
            else if type == kSCNetworkInterfaceTypeEthernet as String { result[name] = "Ethernet" }
            else if type == kSCNetworkInterfaceTypeWWAN as String { result[name] = L("network.cellular") }
        }
        return result
    }

    // Interpret Netif by its column, never by the last field (which may be Expire).
    static func choosePrimary(routeText: String, active: Set<String>, physical: Set<String>, preferred: String?) -> String {
        func physicalInterface(_ name: String) -> Bool {
            physical.contains(name) || (!isTunnel(name) && !["lo", "awdl", "llw", "ap", "anpi", "nan"].contains { name.hasPrefix($0) })
        }
        if let preferred, active.contains(preferred), physicalInterface(preferred) { return preferred }
        let routes = routeText.split(separator: "\n").compactMap { line -> (String, String)? in
            let parts = line.split(whereSeparator: \.isWhitespace).map(String.init)
            guard parts.count >= 4, parts[0] == "default", active.contains(parts[3]) else { return nil }
            return (parts[3], parts[2])
        }
        let physicalRoutes = routes.filter { physicalInterface($0.0) }
        return physicalRoutes.first { !$0.1.contains("I") }?.0
            ?? physicalRoutes.first?.0
            ?? routes.first { !$0.1.contains("I") }?.0
            ?? routes.first?.0 ?? ""
    }

    static func primary() -> String {
        let active = Set(activeInterfaces())
        let physical = Set(hardware().keys)
        var preferred: String?
        if let store = SCDynamicStoreCreate(nil, L("app.name") as CFString, nil, nil) {
            for family in ["IPv4", "IPv6"] {
                if let state = SCDynamicStoreCopyValue(store, "State:/Network/Global/\(family)" as CFString) as? [String: Any],
                   let name = state[kSCDynamicStorePropNetPrimaryInterface as String] as? String,
                   active.contains(name), physical.contains(name) { preferred = name; break }
            }
        }
        if let preferred { return preferred }
        var tables = ""
        for family in ["inet", "inet6"] {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/netstat")
            process.arguments = ["-rn", "-f", family]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice
            guard (try? process.run()) != nil else { continue }
            tables += String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            tables += "\n"
            process.waitUntilExit()
        }
        return choosePrimary(routeText: tables, active: active, physical: physical, preferred: preferred)
    }

    static func displayName(_ name: String) -> String {
        if name.isEmpty { return L("network.offline") }
        if let type = hardware()[name] { return "\(type) (\(name))" }
        return isTunnel(name) ? "VPN (\(name))" : name
    }
}

func defaultInterface() -> String { NetworkDiscovery.primary() }

func counters() -> [String: (received: UInt64, sent: UInt64)] {
    var result: [String: (received: UInt64, sent: UInt64)] = [:]
    var head: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&head) == 0, let first = head else { return result }
    defer { freeifaddrs(head) }
    var current: UnsafeMutablePointer<ifaddrs>? = first
    while let item = current {
        let entry = item.pointee
        if let address = entry.ifa_addr, address.pointee.sa_family == UInt8(AF_LINK),
           let data = entry.ifa_data?.assumingMemoryBound(to: if_data.self) {
            result[String(cString: entry.ifa_name)] = (UInt64(data.pointee.ifi_ibytes), UInt64(data.pointee.ifi_obytes))
        }
        current = entry.ifa_next
    }
    return result
}

func activeInterfaces() -> [String] {
    var result = Set<String>()
    var head: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&head) == 0, let first = head else { return [] }
    defer { freeifaddrs(head) }
    var current: UnsafeMutablePointer<ifaddrs>? = first
    while let item = current {
        defer { current = item.pointee.ifa_next }
        let entry = item.pointee
        let name = String(cString: entry.ifa_name)
        guard entry.ifa_flags & UInt32(IFF_UP | IFF_RUNNING) == UInt32(IFF_UP | IFF_RUNNING),
              entry.ifa_flags & UInt32(IFF_LOOPBACK) == 0,
              let address = entry.ifa_addr else { continue }
        if address.pointee.sa_family == UInt8(AF_INET) { result.insert(name) }
        if address.pointee.sa_family == UInt8(AF_INET6) {
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(address, socklen_t(address.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 {
                let ip = String(cString: host)
                if !ip.hasPrefix("fe80:") && !ip.hasPrefix("ff") && ip != "::1" { result.insert(name) }
            }
        }
    }
    return result.sorted()
}
