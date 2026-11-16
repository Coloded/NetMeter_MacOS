import AppKit
import ApplicationServices

extension AppDelegate {
    func openActivityMonitor(id: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.ActivityMonitor") else {
            DiagnosticCenter.shared.record("activity_monitor", "application_unavailable"); return
        }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { [weak self] application, _ in
            DispatchQueue.main.async {
                guard let application else { DiagnosticCenter.shared.record("activity_monitor", "launch_failed"); return }
                guard AXIsProcessTrusted() else { self?.explainMonitorPermission(); return }
                self?.selectMonitorSection(id: id, pid: application.processIdentifier, attempts: 6)
            }
        }
    }

    private func selectMonitorSection(id: String, pid: pid_t, attempts: Int) {
        let application = AXUIElementCreateApplication(pid)
        func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
            return value
        }
        func descendants(_ root: AXUIElement) -> [AXUIElement] {
            var queue: [(AXUIElement, Int)] = [(root, 0)], result: [AXUIElement] = []
            while !queue.isEmpty && result.count < 500 {
                let (element, depth) = queue.removeFirst()
                result.append(element)
                if depth < 8 {
                    for child in attribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? [] {
                        let role = attribute(child, kAXRoleAttribute) as? String
                        // Process tables can contain thousands of rows; section controls
                        // live in window toolbars, never in a process row or cell.
                        if id != "gpu" && [kAXTableRole, kAXOutlineRole, kAXRowRole, kAXCellRole].contains(role ?? "") { continue }
                        queue.append((child, depth + 1))
                    }
                }
            }
            return result
        }
        let bundle = Bundle(path: "/System/Applications/Utilities/Activity Monitor.app")
        let names: [String: [String]] = [
            "cpu": ["CPU", "ЦП", "المعالج", "处理器"], "memory": ["Memory", "Память", "الذاكرة", "内存"],
            "disk": ["Disk", "Диск", "القرص", "磁盘"], "network": ["Network", "Сеть", "الشبكة", "网络"],
            "gpu": ["GPU History", "История графического процессора", "سجل GPU", "GPU 历史记录"]]
        let key = id == "gpu" ? "HISTORY_PANEL_GPU_TITLE" : names[id]?.first ?? "CPU"
        var wanted = Set(names[id] ?? [])
        if let localized = bundle?.localizedString(forKey: key, value: nil, table: "Localizable") { wanted.insert(localized) }
        let roots: [AXUIElement]
        if id == "gpu", let value = attribute(application, kAXMenuBarAttribute), CFGetTypeID(value) == AXUIElementGetTypeID() {
            roots = [unsafeBitCast(value, to: AXUIElement.self)]
        } else { roots = [application] }
        let matches = roots.flatMap(descendants).filter { element in
            let role = attribute(element, kAXRoleAttribute) as? String
            guard role == (id == "gpu" ? kAXMenuItemRole : kAXRadioButtonRole) else { return false }
            return [kAXTitleAttribute, kAXDescriptionAttribute, kAXIdentifierAttribute].contains {
                guard let label = attribute(element, $0) as? String else { return false }
                return wanted.contains(label)
            }
        }
        if let item = matches.first, AXUIElementPerformAction(item, kAXPressAction as CFString) == .success {
            DiagnosticCenter.shared.record("activity_monitor", "selection_action_succeeded", detail: id)
        } else if attempts > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in self?.selectMonitorSection(id: id, pid: pid, attempts: attempts - 1) }
        } else {
            DiagnosticCenter.shared.record("activity_monitor", "selection_failed", detail: id)
            if !UserDefaults.standard.bool(forKey: "monitorSelectionFailureExplained") {
                UserDefaults.standard.set(true, forKey: "monitorSelectionFailureExplained")
                let alert = NSAlert(); alert.messageText = L("monitor.selection_failed"); alert.informativeText = L("monitor.permission_body"); alert.runModal()
            }
        }
    }

    @objc func showMonitorAccessHelp() { explainMonitorPermission(force: true) }

    private func explainMonitorPermission(force: Bool = false) {
        DiagnosticCenter.shared.record("activity_monitor", "accessibility_unavailable")
        guard force || !UserDefaults.standard.bool(forKey: "monitorPermissionExplained") else { return }
        UserDefaults.standard.set(true, forKey: "monitorPermissionExplained")
        let alert = NSAlert()
        alert.messageText = L("monitor.permission_title")
        alert.informativeText = L("monitor.permission_body")
        alert.addButton(withTitle: L("monitor.open_settings"))
        alert.addButton(withTitle: L("monitor.just_open"))
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") { NSWorkspace.shared.open(url) }
    }
}
