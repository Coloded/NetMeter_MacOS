import AppKit

extension AppDelegate {
    @objc func showAbout() {
        if aboutWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 320, y: 320, width: 560, height: 280),
                                  styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = L("about.title")
            window.isReleasedWhenClosed = false
            let content = window.contentView!
            label(L("app.name"), x: 24, y: 233, in: content).font = .boldSystemFont(ofSize: 20)
            let info = Bundle.main.infoDictionary ?? [:]
            let version = info["CFBundleShortVersionString"] as? String ?? "—"
            let build = info["CFBundleVersion"] as? String ?? "—"
            label(L("about.version", version, build), x: 24, y: 201, in: content)
            updates.addControls(to: content, y: 172)
            L10n.applyDirection(to: content)
            aboutWindow = window
        }
        aboutWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func checkForUpdates() { updates.checkForUpdates() }

}
