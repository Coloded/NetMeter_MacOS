import AppKit

extension AppDelegate {
    func buildStatusMenu() {
        graphItems.removeAll()
        let menu = NSMenu()
        menu.userInterfaceLayoutDirection = L10n.direction
        openNetworkItem = NSMenuItem(title: L("menu.open_network"), action: #selector(showGraph), keyEquivalent: "g")
        menu.addItem(openNetworkItem)
        menu.addItem(NSMenuItem(title: L("menu.settings"), action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: L("menu.network"), action: nil, keyEquivalent: ""))
        interfaceMenu = NSMenu(title: "networkInterfaces")
        interfaceMenu.userInterfaceLayoutDirection = L10n.direction
        interfaceMenu.delegate = self
        menu.setSubmenu(interfaceMenu, for: menu.item(at: 2)!)
        rebuildInterfaceMenu()
        let graphsItem = NSMenuItem(title: L("menu.graphs"), action: nil, keyEquivalent: "")
        let graphsMenu = NSMenu()
        graphsMenu.userInterfaceLayoutDirection = L10n.direction
        graphsMenu.autoenablesItems = false
        graphsMenu.delegate = self
        for (id, title) in [("network", L("graph.network")), ("memory", L("graph.memory")), ("cpu", L("graph.cpu")), ("gpu", L("graph.gpu")), ("disk", L("graph.disk"))] {
            let item = NSMenuItem(title: title, action: #selector(toggleGraph(_:)), keyEquivalent: "")
            item.representedObject = id
            item.target = self
            item.isEnabled = id != "gpu" || metrics.gpuAvailable
            if id == "gpu" && !metrics.gpuAvailable { item.title = L("menu.gpu_unavailable") }
            graphsMenu.addItem(item)
            graphItems[id] = item
        }
        graphsItem.submenu = graphsMenu
        menu.addItem(graphsItem)
        glueMenuItem = NSMenuItem(title: L("menu.glue"), action: #selector(toggleGlue), keyEquivalent: "")
        menu.addItem(glueMenuItem)
        menu.addItem(NSMenuItem(title: L("menu.separate_all"), action: #selector(separateWindows), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(languageMenu())
        menu.addItem(NSMenuItem(title: L("menu.about"), action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: L("menu.updates"), action: #selector(checkForUpdates), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: L("menu.quit"), action: #selector(quit), keyEquivalent: "q"))
        menu.items.filter { $0.action != nil }.forEach { $0.target = self }
        statusItem.menu = menu
        graph.contextMenuProvider = { [weak self] in
            self?.makeGraphContextMenu(id: "network") ?? NSMenu()
        }
        menu.delegate = self
        updateGraphMenu()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        if menu === interfaceMenu || menu.title == interfaceMenu.title { rebuildInterfaceMenu(menu) }
        else { updateGraphMenu() }
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(checkForUpdates) { return updates?.canCheckForUpdates == true }
        return true
    }

    func updateGraphMenu() {
        openNetworkItem?.isHidden = panel.isVisible
        graphItems["network"]?.state = panel.isVisible ? .on : .off
        for (id, item) in graphItems where id != "network" { item.state = resourcePanels[id]?.isVisible == true ? .on : .off }
        glueMenuItem?.state = docking.enabled ? .on : .off
    }

    @objc func selectInterface(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        selection = name
        selectedInterface = name == "auto" ? defaultInterface() : name
        UserDefaults.standard.set(selection, forKey: "interface")
        previous = nil
        graph.samples = []
        graph.interfaceName = NetworkDiscovery.displayName(selectedInterface)
        rebuildInterfaceMenu()
    }

    func rebuildInterfaceMenu(_ target: NSMenu? = nil) {
        let interfaceMenu = target ?? self.interfaceMenu!
        interfaceMenu.removeAllItems()
        let route = defaultInterface()
        let names = Array(Set(activeInterfaces() + [route, selectedInterface])).filter { !$0.isEmpty }.sorted()
        let options = [(L("network.auto", NetworkDiscovery.displayName(route)), "auto")] + names.map { name in
            (name == route ? L("network.primary", NetworkDiscovery.displayName(name)) : NetworkDiscovery.displayName(name), name)
        }
        for (title, name) in options {
            let item = NSMenuItem(title: title, action: #selector(selectInterface(_:)), keyEquivalent: "")
            item.representedObject = name
            item.state = name == selection ? .on : .off
            item.target = self
            interfaceMenu.addItem(item)
        }
    }

    @objc func toggleGraph(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let window = id == "network" ? panel : resourcePanels[id] else { return }
        if window.isVisible { window.orderOut(nil) } else { window.orderFrontRegardless() }
        UserDefaults.standard.set(window.isVisible, forKey: "graphEnabled-\(id)")
        updateGraphMenu()
    }

    @objc func toggleGlue() { docking.toggle(); updateGraphMenu() }
    @objc func separateWindows() { docking.separateAll() }

    @objc func showGraph() {
        panel.orderFrontRegardless()
        UserDefaults.standard.set(true, forKey: "graphEnabled-network")
    }
}
