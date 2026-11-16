import AppKit
import OSLog

final class DiagnosticCenter {
    static let shared = DiagnosticCenter()
    private let lock = NSLock()
    private let logger = Logger(subsystem: "local.traffic.meter", category: "diagnostics")
    private var events: [[String: String]] = []
    private var last: [String: TimeInterval] = [:]
    private var sensors: [String: Bool] = [:]
    func record(_ category: String, _ code: String, detail: String = "", interval: Double = 30) {
        let codes: [String: Set<String>] = [
            "application": ["started"], "settings": ["graph_setting_changed"],
            "network": ["interface_changed", "baseline_reset"], "metrics": ["sampling_gap"],
            "sensor": ["restored", "unavailable"], "command": ["launch_failed", "failed", "timeout"],
            "export": ["write_failed"], "update": ["configuration_invalid", "cycle_failed"],
            "activity_monitor": ["application_unavailable", "launch_failed", "selection_action_succeeded", "selection_failed", "accessibility_unavailable"]]
        guard codes[category]?.contains(code) == true else { return }
        let knownDetails: Set<String> = ["network", "cpu", "memory", "gpu", "disk", "grid", "rates", "top", "ifconfig", "netstat", "networksetup", "diskutil", "sh", "sleep", "true", "false"]
        let numericError = category == "update" && detail.range(of: #"^-?[0-9]{1,10}$"#, options: .regularExpression) != nil
        let version = category == "application" && detail.range(of: #"^[0-9]{1,4}(\.[0-9]{1,4}){0,3}$"#, options: .regularExpression) != nil
        let safe = detail.isEmpty || knownDetails.contains(detail) || numericError || version ? detail : "redacted"
        lock.lock()
        let key = category + ":" + code + ":" + safe
        let now = ProcessInfo.processInfo.systemUptime
        guard now - (last[key] ?? -.infinity) >= interval else { lock.unlock(); return }
        last[key] = now
        if last.count > 256 { last = [key: now] }
        // Only internal symbolic codes are retained. Never store localized OS errors,
        // URLs, command arguments, hardware addresses or user-provided strings.

        events.append(["time": ISO8601DateFormatter().string(from: Date()), "category": category, "code": code, "detail": safe])
        if events.count > 200 { events.removeFirst(events.count - 200) }
        lock.unlock()
        logger.notice("\(category, privacy: .public): \(code, privacy: .public) \(safe, privacy: .public)")
    }
    func sensor(_ name: String, available: Bool) {
        guard ["network", "cpu", "memory", "gpu", "disk"].contains(name) else { return }
        lock.lock(); let changed = sensors[name] != available; sensors[name] = available; lock.unlock()
        if changed { record("sensor", available ? "restored" : "unavailable", detail: name, interval: 0) }
    }
    func report(settings: SettingsStore, info: [String: Any] = Bundle.main.infoDictionary ?? [:]) -> [String: Any] {
        lock.lock(); let log = events; let state = sensors; lock.unlock()
        #if arch(arm64)
        let architecture = "arm64"
        #else
        let architecture = "x86_64"
        #endif
        return ["application": "NetMeter", "version": info["CFBundleShortVersionString"] as? String ?? "unknown",
                "build": info["CFBundleVersion"] as? String ?? "unknown", "architecture": architecture,
                "macOS": ProcessInfo.processInfo.operatingSystemVersionString,
                "sensors": state, "settings": settings.diagnosticSummary, "events": log]
    }
}

extension AppDelegate {
    @objc func exportDiagnostics() {
        let chooser = NSSavePanel()
        chooser.nameFieldStringValue = "NetMeter-diagnostics.json"
        chooser.begin { [weak self] response in
            guard response == .OK, let url = chooser.url, let self else { return }
            do {
                let data = try JSONSerialization.data(withJSONObject: DiagnosticCenter.shared.report(settings: self.settings), options: [.prettyPrinted, .sortedKeys])
                try data.write(to: url, options: .atomic)
            } catch {
                DiagnosticCenter.shared.record("export", "write_failed")
                let alert = NSAlert(); alert.messageText = L("diagnostics.export_failed"); alert.runModal()
            }
        }
    }
}
