import AppKit

enum GraphFonts {
    static func font(_ role: String, fallbackSize: CGFloat) -> NSFont {
        let defaults = UserDefaults.standard
        let size = defaults.object(forKey: "font-size-\(role)") as? Double ?? Double(fallbackSize)
        let name = defaults.string(forKey: "font-name-\(role)") ?? ""
        return NSFont(name: name, size: CGFloat(size)) ?? .monospacedDigitSystemFont(ofSize: CGFloat(size), weight: .medium)
    }
    static var autoFit: Bool { UserDefaults.standard.object(forKey: "fontAutoFit") as? Bool ?? true }
}

extension AppDelegate {
    func addFontControls(to parent: NSView) {
        for (index, role) in ["heading", "values"].enumerated() {
            let y = CGFloat(245 - index * 70)
            label(L("fonts.\(role)"), x: 24, y: y, width: 150, in: parent)
            let font = GraphFonts.font(role, fallbackSize: role == "heading" ? 11 : 12)
            let button = NSButton(title: "\(font.displayName ?? font.fontName) · \(Int(font.pointSize))", target: self, action: #selector(chooseGraphFont(_:)))
            button.identifier = NSUserInterfaceItemIdentifier(role)
            button.frame = NSRect(x: 190, y: y - 5, width: 350, height: 30)
            parent.addSubview(button)
            graphFontButtons[role] = button
        }
        let fit = NSButton(checkboxWithTitle: L("fonts.auto_fit"), target: self, action: #selector(changeFontAutoFit(_:)))
        fit.frame = NSRect(x: 24, y: 100, width: parent.bounds.width - 48, height: 28)
        fit.state = GraphFonts.autoFit ? .on : .off
        parent.addSubview(fit)
        let reset = NSButton(title: L("fonts.reset"), target: self, action: #selector(resetGraphFonts))
        reset.frame = NSRect(x: 24, y: 45, width: 250, height: 30)
        parent.addSubview(reset)
    }

    @objc func chooseGraphFont(_ sender: NSButton) {
        selectedFontRole = sender.identifier?.rawValue ?? "values"
        let manager = NSFontManager.shared
        manager.target = self
        manager.action = #selector(changeGraphFont(_:))
        manager.setSelectedFont(GraphFonts.font(selectedFontRole, fallbackSize: selectedFontRole == "heading" ? 11 : 12), isMultiple: false)
        manager.orderFrontFontPanel(nil)
        NSFontPanel.shared.level = .floating
        NSFontPanel.shared.makeKeyAndOrderFront(nil)
    }

    @objc func changeGraphFont(_ sender: NSFontManager) {
        let font = sender.convert(GraphFonts.font(selectedFontRole, fallbackSize: selectedFontRole == "heading" ? 11 : 12))
        UserDefaults.standard.set(font.fontName, forKey: "font-name-\(selectedFontRole)")
        UserDefaults.standard.set(Double(min(max(font.pointSize, 6), 48)), forKey: "font-size-\(selectedFontRole)")
        refreshGraphFonts()
    }

    @objc func changeFontAutoFit(_ sender: NSButton) {
        UserDefaults.standard.set(sender.state == .on, forKey: "fontAutoFit")
        refreshGraphFonts()
    }

    @objc func resetGraphFonts() {
        for role in ["heading", "values"] {
            for part in ["name", "size"] { UserDefaults.standard.removeObject(forKey: "font-\(part)-\(role)") }
        }
        refreshGraphFonts()
    }

    func refreshGraphFonts() {
        for (role, button) in graphFontButtons {
            let font = GraphFonts.font(role, fallbackSize: role == "heading" ? 11 : 12)
            button.title = "\(font.displayName ?? font.fontName) · \(Int(font.pointSize))"
        }
        graph.needsDisplay = true
        for view in resourceViews.values { view.needsDisplay = true }
    }

    @objc func changeRateUnit(_ sender: NSPopUpButton) {
        guard let key = sender.identifier?.rawValue, ["rateUnit", "maximumRateUnit", "totalUnit"].contains(key),
              let value = sender.selectedItem?.representedObject as? String else { return }
        UserDefaults.standard.set(value, forKey: key)
        tick()
    }
}
