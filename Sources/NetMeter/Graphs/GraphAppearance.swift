import AppKit

enum GraphAppearance {
    static var isMacOS: Bool { UserDefaults.standard.string(forKey: "graphStyle") == "macos" }
    static var background: NSColor { isMacOS ? .windowBackgroundColor : NSColor(calibratedRed: 0.07, green: 0.09, blue: 0.13, alpha: 1) }
    static var plot: NSColor { isMacOS ? .controlBackgroundColor : NSColor(calibratedRed: 0.12, green: 0.16, blue: 0.21, alpha: 1) }
    static var text: NSColor { isMacOS ? .labelColor : .white }
    static var grid: NSColor { isMacOS ? .separatorColor : NSColor.white.withAlphaComponent(0.12) }
    static func defaultLine(id: String, second: Bool = false) -> NSColor {
        if second { return id == "network" ? .systemGreen : .systemOrange }
        return ["network": NSColor.systemRed, "cpu": .systemBlue, "memory": .systemPurple, "gpu": .systemGreen, "disk": .systemCyan][id] ?? .systemBlue
    }
    static func color(id: String, component: String, fallback: NSColor) -> NSColor {
        guard let data = UserDefaults.standard.data(forKey: "color-\(id)-\(component)"),
              let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) else { return fallback }
        return color
    }
    static func save(_ color: NSColor, id: String, component: String) {
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: true) {
            UserDefaults.standard.set(data, forKey: "color-\(id)-\(component)")
        }
    }
}

extension AppDelegate {
    func applyGraphAppearance() {
        graph.downColor = GraphAppearance.color(id: "network", component: "line1", fallback: graph.downColor)
        graph.upColor = GraphAppearance.color(id: "network", component: "line2", fallback: graph.upColor)
        for (id, view) in resourceViews {
            view.color = GraphAppearance.color(id: id, component: "line1", fallback: view.color)
            view.needsDisplay = true
        }
        graph.needsDisplay = true
    }

    @objc func changeGraphStyle(_ sender: NSPopUpButton) {
        UserDefaults.standard.set(sender.indexOfSelectedItem == 1 ? "macos" : "classic", forKey: "graphStyle")
        applyGraphAppearance()
    }

    func graphColorMenu(id: String) -> NSMenuItem {
        let parent = NSMenuItem(title: L("color.menu"), action: nil, keyEquivalent: "")
        let menu = NSMenu()
        menu.userInterfaceLayoutDirection = L10n.direction
        for (title, prefix) in [(L("color.graph"), "line"), (L("color.label"), "label")] {
            let category = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            let submenu = NSMenu()
            submenu.userInterfaceLayoutDirection = L10n.direction
            func add(_ title: String, _ component: String) {
                let item = NSMenuItem(title: title, action: #selector(selectGraphColor(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = id + ":" + component
                submenu.addItem(item)
            }
            if id == "network" || id == "disk" {
                add(L(id == "network" ? "settings.download" : "color.read"), prefix + "1")
                add(L(id == "network" ? "settings.upload" : "color.write"), prefix + "2")
            } else { add(L("color.choose"), prefix + "1") }
            if prefix == "label" { add(L("color.title"), "title") }
            category.submenu = submenu
            menu.addItem(category)
        }
        parent.submenu = menu
        return parent
    }

    @objc func selectGraphColor(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? String else { return }
        let values = value.components(separatedBy: ":")
        guard values.count == 2 else { return }
        let id = values[0], component = values[1]
        colorSelection = (id, component)
        let first = component.hasPrefix("label") ? GraphAppearance.defaultLine(id: id) : id == "network" ? graph.downColor : resourceViews[id]?.color ?? .systemBlue
        let second = component.hasPrefix("label") ? GraphAppearance.defaultLine(id: id, second: true) : id == "network" ? graph.upColor : NSColor.systemOrange
        let fallback = component == "title" ? GraphAppearance.text : component.hasSuffix("2") ? second : first
        let picker = NSColorPanel.shared
        // End an active color well before assigning the shared panel to this graph.
        func deactivateWells(_ view: NSView) {
            (view as? NSColorWell)?.deactivate()
            view.subviews.forEach(deactivateWells)
        }
        if let content = settingsWindow?.contentView { deactivateWells(content) }
        picker.isContinuous = true
        picker.showsAlpha = false
        picker.setTarget(nil)
        picker.setAction(nil)
        picker.color = GraphAppearance.color(id: id, component: component, fallback: fallback)
        picker.title = "\(L("graph.\(id)")) — \(L(component.hasPrefix("line") ? "color.graph" : "color.label"))"
        picker.setTarget(self)
        picker.setAction(#selector(changeGraphColor(_:)))
        picker.level = .floating
        NSApp.activate(ignoringOtherApps: true)
        picker.makeKeyAndOrderFront(nil)
    }

    @objc func changeGraphColor(_ sender: NSColorPanel) {
        guard let selection = colorSelection else { return }
        GraphAppearance.save(sender.color, id: selection.id, component: selection.component)
        applyGraphAppearance()
    }
}
