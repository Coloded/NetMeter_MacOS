import AppKit
import Sparkle

final class UpdateController: NSObject {
    private let controller: SPUStandardUpdaterController?
    var statusText: String { Self.configurationIssue(Bundle.main.infoDictionary ?? [:]) ?? L("updates.source") }

    static func configurationIssue(_ info: [String: Any]) -> String? {
        guard let feed = info["SUFeedURL"] as? String, !feed.isEmpty else {
            return L("updates.no_repository")
        }
        guard let url = URL(string: feed), url.scheme == "https", url.host != nil,
              url.user == nil, url.password == nil else {
            return L("updates.bad_url")
        }
        guard let key = info["SUPublicEDKey"] as? String, Data(base64Encoded: key)?.count == 32 else {
            return L("updates.no_key")
        }
        guard info["SURequireSignedFeed"] as? Bool == true,
              info["SUVerifyUpdateBeforeExtraction"] as? Bool == true else {
            return L("updates.no_signature_check")
        }
        guard let build = info["CFBundleVersion"] as? String, let number = Int(build), number > 0 else {
            return L("updates.no_build")
        }
        return nil
    }

    override init() {
        if Self.configurationIssue(Bundle.main.infoDictionary ?? [:]) != nil {
            controller = nil
        } else {
            controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        }
        super.init()
    }

    var isConfigured: Bool { controller != nil }
    var canCheckForUpdates: Bool { controller?.updater.canCheckForUpdates ?? false }
    var automaticallyChecksForUpdates: Bool { controller?.updater.automaticallyChecksForUpdates ?? false }

    @objc func checkForUpdates(_ sender: Any? = nil) {
        guard let controller else { return }
        controller.checkForUpdates(sender)
    }

    @objc func toggleAutomaticChecks(_ sender: NSButton) {
        controller?.updater.automaticallyChecksForUpdates = sender.state == .on
    }

    func addControls(to view: NSView, y: CGFloat) {
        let status = NSTextField(wrappingLabelWithString: statusText)
        status.frame = NSRect(x: 24, y: y - 35, width: view.bounds.width - 48, height: 42)
        view.addSubview(status)
        let check = NSButton(title: L("menu.updates"), target: self, action: #selector(checkForUpdates(_:)))
        check.frame = NSRect(x: 24, y: y - 85, width: 220, height: 32)
        check.isEnabled = isConfigured
        view.addSubview(check)
        let automatic = NSButton(checkboxWithTitle: L("updates.automatic"), target: self, action: #selector(toggleAutomaticChecks(_:)))
        automatic.frame = NSRect(x: 24, y: y - 135, width: view.bounds.width - 48, height: 30)
        automatic.isEnabled = isConfigured
        automatic.state = automaticallyChecksForUpdates ? .on : .off
        view.addSubview(automatic)
    }
}
