import Foundation
import Darwin
import SystemConfiguration

enum NetworkDiscovery {
    private static let lock = NSLock()
    private static var knownHardware: [String: String] = [:]
    private static var knownPrimary = ""
    private static var knownActive: [String] = []
    static func cachedActive() -> [String] { lock.lock(); defer { lock.unlock() }; return knownActive }

    static func isTunnel(_ name: String) -> Bool {
        ["utun", "tun", "tap", "ppp", "ipsec", "gif", "stf"].contains { name.hasPrefix($0) }
    }

    static func hardware() -> [String: String] {
        if Thread.isMainThread { lock.lock(); defer { lock.unlock() }; return knownHardware }

        var result: [String: String] = [:]
        for interface in SCNetworkInterfaceCopyAll() as? [SCNetworkInterface] ?? [] {
            guard let name = SCNetworkInterfaceGetBSDName(interface) as String? else { continue }
            let type = SCNetworkInterfaceGetInterfaceType(interface) as String?
            if type == kSCNetworkInterfaceTypeIEEE80211 as String { result[name] = "Wi-Fi" }
            else if type == kSCNetworkInterfaceTypeEthernet as String { result[name] = "Ethernet" }
            else if type == kSCNetworkInterfaceTypeWWAN as String { result[name] = L("network.cellular") }
        }
        lock.lock(); knownHardware = result; lock.unlock()
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
        if Thread.isMainThread { lock.lock(); defer { lock.unlock() }; return knownPrimary }

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
        if let preferred {
            lock.lock(); knownPrimary = preferred; knownActive = Array(active).sorted(); lock.unlock()
            return preferred
        }
        var tables = ""
        for family in ["inet", "inet6"] {
            if let output = BoundedCommand.run("/usr/sbin/netstat", ["-rn", "-f", family]) { tables += output + "\n" }
        }
        let selected = choosePrimary(routeText: tables, active: active, physical: physical, preferred: preferred)
        lock.lock(); knownPrimary = selected; knownActive = Array(active).sorted(); lock.unlock()
        return selected
    }

    static func displayName(_ name: String) -> String {
        if name.isEmpty { return L("network.offline") }
        if let type = hardware()[name] {
            let base = "\(type) (\(name))"
            if type == "Ethernet" || type == "Wi-Fi" {
                return base + " · " + NetworkLinkSpeed.label(interface: name, wifi: type == "Wi-Fi")
            }
            return base
        }
        return isTunnel(name) ? "VPN (\(name))" : name
    }
}

func defaultInterface() -> String { NetworkDiscovery.primary() }

func counters() -> [String: (received: UInt64, sent: UInt64)] {
    guard let interfaces = if_nameindex() else { return [:] }
    defer { if_freenameindex(interfaces) }
    var result: [String: (received: UInt64, sent: UInt64)] = [:]
    var cursor = interfaces
    while cursor.pointee.if_index != 0, let name = cursor.pointee.if_name {
        defer { cursor = cursor.advanced(by: 1) }
        var data = ifmibdata()
        var size = MemoryLayout<ifmibdata>.size
        var mib: [Int32] = [CTL_NET, PF_LINK, NETLINK_GENERIC, IFMIB_IFDATA, Int32(cursor.pointee.if_index), IFDATA_GENERAL]
        // IFMIB_IFDATA returns the kernel's full if_data64 statistics. On modern
        // macOS NET_RT_IFLIST2 can still expose truncated compatibility values.
        if sysctl(&mib, UInt32(mib.count), &data, &size, nil, 0) == 0 {
            result[String(cString: name)] = (data.ifmd_data.ifi_ibytes, data.ifmd_data.ifi_obytes)
        }
    }
    return result
}

func activeInterfaces() -> [String] {
    if Thread.isMainThread { return NetworkDiscovery.cachedActive() }
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
