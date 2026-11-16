import Foundation
import Darwin
import IOKit

final class SystemMetrics {
    private var cpuTicks: [UInt32]?
    private var perCoreTicks: [[UInt32]]?
    private var diskDriver: io_registry_entry_t = 0
    private var diskIdentifier = ""
    private var diskDiscoveryTime = -Double.infinity
    var diskName: String { diskIdentifier.isEmpty ? L("disk.unknown") : L("disk.summary", diskIdentifier) }
    private var diskPrevious: (UInt64, UInt64, TimeInterval)?
    private(set) var gpuAvailable = false

    init() {
        findSystemDisk()
        gpuAvailable = gpu() != nil
    }

    func resetBaselines() {
        cpuTicks = nil; perCoreTicks = nil; diskPrevious = nil
        if diskDriver != 0 { IOObjectRelease(diskDriver); diskDriver = 0 }
        diskDiscoveryTime = -.infinity
    }

    deinit { if diskDriver != 0 { IOObjectRelease(diskDriver) } }

    func cpu() -> ResourceReading? {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        let status = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard status == KERN_SUCCESS else { return nil }
        let ticks = [info.cpu_ticks.0, info.cpu_ticks.1, info.cpu_ticks.2, info.cpu_ticks.3]
        defer { cpuTicks = ticks }
        guard let old = cpuTicks else { return nil }
        let delta = zip(ticks, old).map { Double($0 &- $1) }
        let total = delta.reduce(0, +)
        guard total > 0 else { return nil }
        let busy = (delta[0] + delta[1] + delta[3]) / total * 100
        return ResourceReading(first: busy, header: L("cpu.summary", ProcessInfo.processInfo.activeProcessorCount),
                               footer: L("cpu.load", busy))
    }

    func cpuCores() -> [Double]? {
        var processorCount: natural_t = 0
        var info: processor_info_array_t?
        var count: mach_msg_type_number_t = 0
        guard host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &processorCount, &info, &count) == KERN_SUCCESS,
              let info else { return nil }
        defer { vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: info)), vm_size_t(Int(count) * MemoryLayout<integer_t>.size)) }
        guard count >= processorCount * UInt32(CPU_STATE_MAX) else { return nil }
        let ticks: [[UInt32]] = (0..<Int(processorCount)).map { core in
            (0..<Int(CPU_STATE_MAX)).map { UInt32(bitPattern: info[core * Int(CPU_STATE_MAX) + $0]) }
        }
        defer { perCoreTicks = ticks }
        guard let old = perCoreTicks, old.count == ticks.count else { return nil }
        return zip(ticks, old).map { current, previous in
            let delta = zip(current, previous).map { Double($0 &- $1) }
            let total = delta.reduce(0, +)
            return total > 0 ? (total - delta[Int(CPU_STATE_IDLE)]) / total * 100 : 0
        }
    }

    func memory() -> ResourceReading? {
        var info = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let status = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard status == KERN_SUCCESS else { return nil }
        var pageSize: vm_size_t = 0
        guard host_page_size(mach_host_self(), &pageSize) == KERN_SUCCESS else { return nil }
        let pages = Double(info.active_count) + Double(info.inactive_count) + Double(info.wire_count)
            + Double(info.compressor_page_count) - Double(info.purgeable_count) - Double(info.external_page_count)
        let total = Double(ProcessInfo.processInfo.physicalMemory)
        let used = min(max(pages * Double(pageSize), 0), total)
        return ResourceReading(first: used / total * 100, header: L("memory.summary"),
                               footer: String(format: "%.1f / %.0f GiB", used / 1073741824, total / 1073741824),
                               secondary: String(format: "%.1f%%", used / total * 100), details: memoryDetails())
    }

    func gpu() -> ResourceReading? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &iterator) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }
        var values: [(usage: Double, cores: Int?)] = []
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            if let stats = IORegistryEntryCreateCFProperty(service, "PerformanceStatistics" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? [String: Any],
               let value = stats["Device Utilization %"] as? NSNumber,
               value.doubleValue.isFinite, (0...100).contains(value.doubleValue) {
                let reported = IORegistryEntryCreateCFProperty(service, "gpu-core-count" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? NSNumber
                let cores = reported.flatMap { $0.intValue > 0 ? $0.intValue : nil }
                values.append((value.doubleValue, cores))
            }
        }
        guard let device = values.max(by: { $0.usage < $1.usage }) else { gpuAvailable = false; return nil }
        gpuAvailable = true
        return ResourceReading(first: device.usage, header: device.cores.map { L("gpu.cores", $0) } ?? L("gpu.summary"),
                               footer: L("cpu.load", device.usage))
    }

    private func memoryDetails() -> String {
        var swap = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        let swapText = sysctlbyname("vm.swapusage", &swap, &size, nil, 0) == 0
            ? String(format: "%.1f GiB", Double(swap.xsu_used) / 1073741824) : L("metric.unavailable")
        var level: Int32 = 0
        size = MemoryLayout<Int32>.size
        let status = sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &size, nil, 0)
        let key = status != 0 ? "metric.unavailable" : level == 1 ? "memory.normal" : level == 2 ? "memory.warning" : level == 4 ? "memory.critical" : "metric.unavailable"
        return L("memory.details", swapText, L10n.text(key))
    }

    private func findSystemDisk() {
        diskDiscoveryTime = ProcessInfo.processInfo.systemUptime
        var filesystem = statfs()
        guard statfs("/", &filesystem) == 0 else { return }
        let source = withUnsafePointer(to: &filesystem.f_mntfromname) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) { String(cString: $0) }
        }
        let root = source.replacingOccurrences(of: "/dev/", with: "")
        let entry = IOServiceGetMatchingService(kIOMainPortDefault, IOBSDNameMatching(kIOMainPortDefault, 0, root))
        guard entry != 0 else { return }
        var current = entry
        var physical = root
        while current != 0 {
            if let bsd = IORegistryEntryCreateCFProperty(current, "BSD Name" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? String {
                physical = bsd
            }
            if IOObjectConformsTo(current, "IOBlockStorageDriver") != 0 {
                diskDriver = current
                diskIdentifier = physical
                return
            }
            var parent: io_registry_entry_t = 0
            let result = IORegistryEntryGetParentEntry(current, kIOServicePlane, &parent)
            IOObjectRelease(current)
            if result != KERN_SUCCESS { return }
            current = parent
        }
    }

    func disk() -> ResourceReading? {
        if diskDriver == 0 && ProcessInfo.processInfo.systemUptime - diskDiscoveryTime >= 5 { findSystemDisk() }
        guard diskDriver != 0,
              let stats = IORegistryEntryCreateCFProperty(diskDriver, "Statistics" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? [String: Any],
              let read = (stats["Bytes (Read)"] as? NSNumber)?.uint64Value,
              let write = (stats["Bytes (Write)"] as? NSNumber)?.uint64Value else {
            if diskDriver != 0 { IOObjectRelease(diskDriver); diskDriver = 0; diskIdentifier = ""; diskPrevious = nil; diskDiscoveryTime = ProcessInfo.processInfo.systemUptime }
            return nil
        }
        let now = ProcessInfo.processInfo.systemUptime
        defer { diskPrevious = (read, write, now) }
        guard let old = diskPrevious, now > old.2, read >= old.0, write >= old.1 else { return nil }
        let reading = Double(read - old.0) / (now - old.2)
        let writing = Double(write - old.1) / (now - old.2)
        return ResourceReading(first: reading, second: writing, header: diskName,
                               footer: L("disk.read", formatRate(reading, unit: "auto_binary")), secondary: L("disk.write", formatRate(writing, unit: "auto_binary")))
    }
}

