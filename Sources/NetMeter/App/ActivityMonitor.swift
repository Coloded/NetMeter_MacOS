import AppKit
import ApplicationServices

extension AppDelegate {
    func openActivityMonitor(id: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.ActivityMonitor") else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { [weak self] application, _ in
            DispatchQueue.main.async {
                guard let application else { return }
                guard AXIsProcessTrusted() else {
                    self?.explainMonitorPermission()
                    return
                }
                // Allow a newly launched Monitor to finish constructing its toolbar.
                self?.selectMonitorSection(id: id, pid: application.processIdentifier, attempts: 8)
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
        func descendants(_ element: AXUIElement, depth: Int = 0) -> [AXUIElement] {
            guard depth < 5 else { return [] }
            let children = attribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
            return children + children.flatMap { descendants($0, depth: depth + 1) }
        }
        let elements = descendants(application)
        let buttons = elements.filter { (attribute($0, kAXRoleAttribute) as? String) == kAXRadioButtonRole }
        let index = ["cpu": 0, "memory": 1, "disk": 3, "network": 4][id] ?? 0
        if buttons.count == 5 {
            AXUIElementPerformAction(buttons[index], kAXPressAction as CFString)
            if id == "gpu", let bundle = Bundle(identifier: "com.apple.ActivityMonitor") ?? Bundle(path: "/System/Applications/Utilities/Activity Monitor.app") {
                let title = bundle.localizedString(forKey: "HISTORY_PANEL_GPU_TITLE", value: "GPU History", table: "Localizable")
                if let menu = attribute(application, kAXMenuBarAttribute) {
                    let menuElement = unsafeBitCast(menu, to: AXUIElement.self)
                    if let item = descendants(menuElement).first(where: { (attribute($0, kAXTitleAttribute) as? String) == title }) {
                        AXUIElementPerformAction(item, kAXPressAction as CFString)
                    }
                }
            }
        } else if attempts > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.selectMonitorSection(id: id, pid: pid, attempts: attempts - 1)
            }
        }
    }

    private func explainMonitorPermission() {
        // Opening the application itself never requires Accessibility access.
        guard !UserDefaults.standard.bool(forKey: "monitorPermissionExplained") else { return }
        UserDefaults.standard.set(true, forKey: "monitorPermissionExplained")
        let alert = NSAlert()
        alert.messageText = L("monitor.permission_title")
        alert.informativeText = L("monitor.permission_body")
        alert.addButton(withTitle: L("monitor.open_settings"))
        alert.addButton(withTitle: L("monitor.just_open"))
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
