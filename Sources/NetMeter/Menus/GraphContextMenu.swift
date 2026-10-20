import AppKit

extension AppDelegate {
    func makeGraphContextMenu(id: String) -> NSMenu {
        let result = NSMenu()
        result.userInterfaceLayoutDirection = L10n.direction
        result.autoenablesItems = false
        guard let window = id == "network" ? panel : resourcePanels[id] else { return result }
        func item(_ title: String, _ command: String, checked: Bool? = nil) {
            let item = NSMenuItem(title: title, action: #selector(graphContextAction(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = [id, command]
            if let checked { item.state = checked ? .on : .off }
            result.addItem(item)
        }
        if id == "network" {
            let network = NSMenuItem(title: L("network.interface"), action: nil, keyEquivalent: "")
            let interfaces = NSMenu(title: interfaceMenu.title)
            interfaces.userInterfaceLayoutDirection = L10n.direction
            interfaces.delegate = self
            rebuildInterfaceMenu(interfaces)
            network.submenu = interfaces
            result.addItem(network)
            item(L("network.settings"), "settings")
            result.addItem(.separator())
        }
        if id == "cpu" {
            item(L("cpu.all_cores"), "cores", checked: resourceViews[id]?.showAllCores == true)
            result.addItem(.separator())
        }
        result.addItem(graphColorMenu(id: id))
        item(L("graph.monitor"), "monitor")
        result.addItem(.separator())
        item(L("graph.grid"), "grid", checked: id == "network" ? graph.showGrid : resourceViews[id]?.showGrid == true)
        item(L("graph.values"), "rates", checked: id == "network" ? graph.showRates : resourceViews[id]?.showRates == true)
        item(L("graph.top"), "top", checked: window.level == .floating)
        result.addItem(.separator())
        item(L("graph.enlarge"), "enlarge")
        item(L("graph.compact"), "compact")
        item(L("graph.detach"), "detach")
        result.addItem(.separator())
        if id != "network" { item(L("settings.title"), "settings") }
        item(L("graph.hide"), "hide")
        return result
    }

    @objc func graphContextAction(_ sender: NSMenuItem) {
        guard let command = sender.representedObject as? [String], command.count == 2 else { return }
        let id = command[0]
        guard let window = id == "network" ? panel : resourcePanels[id] else { return }
        switch command[1] {
        case "monitor": openActivityMonitor(id: id)
        case "settings": showSettings()
        case "cores": toggleAllCores()
        case "grid":
            if id == "network" { graph.showGrid.toggle(); UserDefaults.standard.set(graph.showGrid, forKey: "grid") }
            else if let view = resourceViews[id] { view.showGrid.toggle(); view.needsDisplay = true; UserDefaults.standard.set(view.showGrid, forKey: "window-grid-\(id)") }
        case "rates":
            if id == "network" { graph.showRates.toggle(); UserDefaults.standard.set(graph.showRates, forKey: "rates") }
            else if let view = resourceViews[id] { view.showRates.toggle(); view.needsDisplay = true; UserDefaults.standard.set(view.showRates, forKey: "window-rates-\(id)") }
        case "top":
            window.level = window.level == .floating ? .normal : .floating
            UserDefaults.standard.set(window.level == .floating, forKey: id == "network" ? "alwaysOnTop" : "window-top-\(id)")
        case "enlarge":
            if id == "cpu" { enlargeCPU(); return }
            let screen = window.screen?.visibleFrame ?? NSScreen.main!.visibleFrame
            let size = NSSize(width: min(screen.width, window.frame.width * 1.3), height: min(screen.height, window.frame.height * 1.3))
            window.setFrame(NSRect(x: max(screen.minX, min(window.frame.minX, screen.maxX - size.width)), y: max(screen.minY, window.frame.maxY - size.height), width: size.width, height: size.height), display: true)
        case "compact":
            if id == "cpu" { compactCPU(); return }
            let size = window.frameRect(forContentRect: NSRect(x: 0, y: 0, width: 280, height: 150)).size
            window.setFrame(NSRect(x: window.frame.minX, y: window.frame.maxY - size.height, width: size.width, height: size.height), display: true)
        case "detach": docking.separate(id)
        case "hide": window.performClose(nil)
        default: break
        }
        window.saveFrame(usingName: id == "network" ? "TrafficGraphWindow" : "ResourceWindow-\(id)")
    }

}
