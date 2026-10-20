import AppKit
import ServiceManagement

extension AppDelegate {
    func addLoginAtStartupControls(to parent: NSView) {
        let button = NSButton(checkboxWithTitle: L("startup.launch"), target: self, action: #selector(changeLoginAtStartup(_:)))
        button.allowsMixedState = true
        button.frame = NSRect(x: 24, y: 32, width: parent.bounds.width - 48, height: 25)
        parent.addSubview(button)
        loginAtStartupButton = button

        let approval = NSButton(title: L("startup.approve"), target: self, action: #selector(openLoginItemsSettings))
        approval.bezelStyle = .inline
        approval.frame = NSRect(x: 24, y: 3, width: parent.bounds.width - 48, height: 25)
        parent.addSubview(approval)
        loginAtStartupApprovalButton = approval
        refreshLoginAtStartup()
    }

    func refreshLoginAtStartup() {
        // macOS owns this preference; do not keep a second, possibly stale defaults flag.
        let status = SMAppService.mainApp.status
        loginAtStartupButton?.state = status == .enabled ? .on : status == .requiresApproval ? .mixed : .off
        loginAtStartupApprovalButton?.isHidden = status != .requiresApproval
    }

    @objc func changeLoginAtStartup(_ sender: NSButton) {
        let service = SMAppService.mainApp
        do {
            // A pending registration can also be cancelled from this checkbox.
            if service.status == .enabled || service.status == .requiresApproval {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = L("startup.error_title")
            alert.informativeText = L("startup.error_body")
            alert.addButton(withTitle: L("common.ok"))
            alert.runModal()
        }
        refreshLoginAtStartup()
    }

    @objc func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        refreshLoginAtStartup()
    }
}
