import AppKit

enum L10n {
    #if DIAGNOSTICS
    static var diagnosticLanguage: String?
    #endif
    static let supported = ["en", "ru", "ar", "zh-Hans"]
    static var preference: String { UserDefaults.standard.string(forKey: "language") ?? "system" }
    static var code: String {
        #if DIAGNOSTICS
        if let diagnosticLanguage { return diagnosticLanguage }
        #endif
        if supported.contains(preference) { return preference }
        for language in Locale.preferredLanguages {
            if language.hasPrefix("zh") { return "zh-Hans" }
            if let match = supported.first(where: { language.hasPrefix($0) }) { return match }
        }
        return "en"
    }
    static var direction: NSUserInterfaceLayoutDirection { code == "ar" ? .rightToLeft : .leftToRight }
    static var choices: [(String, String)] { [("system", L("language.system")), ("en", "English"), ("ru", "Русский"), ("ar", "العربية"), ("zh-Hans", "简体中文")] }
    static func text(_ key: String, language: String? = nil) -> String {
        let selected = language ?? code
        guard let path = Bundle.main.path(forResource: selected, ofType: "lproj"), let bundle = Bundle(path: path) else { return key }
        return bundle.localizedString(forKey: key, value: nil, table: nil)
    }

    static func applyDirection(to view: NSView) {
        view.userInterfaceLayoutDirection = direction
        for child in view.subviews {
            if direction == .rightToLeft { child.frame.origin.x = view.bounds.width - child.frame.maxX }
            if let field = child as? NSTextField { field.alignment = direction == .rightToLeft ? .right : .left }
            applyDirection(to: child)
        }
    }
}

func L(_ key: String, _ arguments: CVarArg...) -> String {
    let format = L10n.text(key)
    return arguments.isEmpty ? format : String(format: format, locale: Locale(identifier: L10n.code), arguments: arguments)
}

extension AppDelegate {
    func languageMenu() -> NSMenuItem {
        let parent = NSMenuItem(title: L("menu.language"), action: nil, keyEquivalent: "")
        let menu = NSMenu()
        menu.userInterfaceLayoutDirection = L10n.direction
        for (code, name) in L10n.choices {
            let item = NSMenuItem(title: name, action: #selector(selectLanguage(_:)), keyEquivalent: "")
            item.representedObject = code
            item.target = self
            item.state = code == L10n.preference ? .on : .off
            menu.addItem(item)
        }
        parent.submenu = menu
        return parent
    }

    @objc func selectLanguagePopup(_ sender: NSPopUpButton) {
        if let item = sender.selectedItem { selectLanguage(item) }
    }

    @objc func selectLanguage(_ sender: NSMenuItem) {
        guard let code = sender.representedObject as? String, code == "system" || L10n.supported.contains(code) else { return }
        UserDefaults.standard.set(code, forKey: "language")
        buildStatusMenu()
        panel.title = L("graph.network")
        for (id, window) in resourcePanels { window.title = L("graph.\(id)") }
        docking.localizeButtons()
        graph.interfaceName = NetworkDiscovery.displayName(selectedInterface)
        let showPreferences = settingsWindow?.isVisible == true
        let showInformation = aboutWindow?.isVisible == true
        settingsWindow?.close()
        aboutWindow?.close()
        settingsWindow = nil
        aboutWindow = nil
        if showPreferences { showSettings() }
        if showInformation { showAbout() }
        graph.needsDisplay = true
        for view in resourceViews.values { view.needsDisplay = true }
        tick()
    }
}
