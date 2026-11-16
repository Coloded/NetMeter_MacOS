import AppKit

extension AppDelegate {
    func createNetworkPanel() {
        let frame = NSRect(x: 200, y: 500, width: 280, height: 150)
        panel = NSPanel(contentRect: frame, styleMask: [.titled, .closable, .resizable, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = L("graph.network")
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.minSize = NSSize(width: 220, height: 120)
        panel.isReleasedWhenClosed = false
        panel.setFrameUsingName("TrafficGraphWindow")
        panel.setFrameAutosaveName("TrafficGraphWindow")
        panel.hidesOnDeactivate = false
        graph = NetworkGraphView(frame: panel.contentView!.bounds)
        graph.autoresizingMask = [.width, .height]
        if selection != "auto" { selectedInterface = selection }
        graph.interfaceName = NetworkDiscovery.displayName(selectedInterface)
        graph.showGrid = settings.bool(property: .grid, graphID: "network")
        graph.showRates = settings.bool(property: .rates, graphID: "network")
        graph.showMaximum = UserDefaults.standard.object(forKey: "maximum") as? Bool ?? true
        graph.fixedScale = UserDefaults.standard.double(forKey: "scale")
        if let data = UserDefaults.standard.data(forKey: "downColor"), let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) { graph.downColor = color }
        if let data = UserDefaults.standard.data(forKey: "upColor"), let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) { graph.upColor = color }
        graph.openMonitor = { [weak self] in self?.openActivityMonitor(id: "network") }
        panel.contentView = graph
        panel.alphaValue = UserDefaults.standard.object(forKey: "opacity") == nil ? 1 : UserDefaults.standard.double(forKey: "opacity")
        panel.level = settings.bool(property: .top, graphID: "network") ? .floating : .normal
        docking.register(panel, id: "network")
        containGraphWindow(panel)
        if UserDefaults.standard.object(forKey: "graphEnabled-network") as? Bool ?? true { panel.orderFrontRegardless() }

    }

    func makeResourcePanels() {
        let definitions: [(String, String, NSColor)] = [("memory", L("graph.memory"), .systemPurple), ("cpu", L("graph.cpu"), .systemBlue), ("gpu", L("graph.gpu"), .systemGreen), ("disk", L("graph.disk"), .systemCyan)]
        let screen = panel.screen?.visibleFrame ?? NSScreen.main!.visibleFrame
        for (index, definition) in definitions.enumerated() {
            let (id, title, color) = definition
            let width: CGFloat = 280
            let height = panel.frame.height
            let x = min(max(screen.minX + 20 + CGFloat(index % 2) * (width + 12), screen.minX), screen.maxX - width)
            let y = max(screen.minY + 20, screen.maxY - 40 - CGFloat(index / 2 + 1) * (height + 12))
            let window = NSPanel(contentRect: NSRect(x: x, y: y, width: width, height: 150),
                                 styleMask: [.titled, .closable, .resizable, .nonactivatingPanel], backing: .buffered, defer: false)
            window.title = title
            window.isReleasedWhenClosed = false
            window.isMovableByWindowBackground = true
            window.hidesOnDeactivate = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.level = panel.level
            window.level = settings.bool(property: .top, graphID: id) ? .floating : .normal
            window.alphaValue = panel.alphaValue
            window.minSize = NSSize(width: 260, height: 120)
            window.setFrameUsingName("ResourceWindow-\(id)")
            window.setFrameAutosaveName("ResourceWindow-\(id)")
            let view = ResourceGraphView(frame: window.contentView!.bounds)
            view.autoresizingMask = [.width, .height]
            view.graphID = id
            view.openMonitor = { [weak self] in self?.openActivityMonitor(id: id) }
            view.percentage = id != "disk"
            view.color = color
            view.showGrid = settings.bool(property: .grid, graphID: id)
            view.showRates = settings.bool(property: .rates, graphID: id)
            view.contextMenuProvider = { [weak self] in
                self?.makeGraphContextMenu(id: id) ?? NSMenu()
            }
            if id == "cpu" {
                view.showAllCores = UserDefaults.standard.bool(forKey: "cpuAllCores")
            }
            window.contentView = view
            resourcePanels[id] = window
            resourceViews[id] = view
            containGraphWindow(window)
            docking.register(window, id: id)
            if id != "gpu", UserDefaults.standard.object(forKey: "graphEnabled-\(id)") as? Bool ?? true { window.orderFrontRegardless() }
        }
    }

    func containGraphWindow(_ window: NSWindow) {
        let screens = NSScreen.screens.map(\.visibleFrame)
        guard let area = screens.first(where: { $0.intersects(window.frame) }) ?? screens.first else { return }
        let width = min(window.frame.width, area.width), height = min(window.frame.height, area.height)
        let x = max(area.minX, min(window.frame.minX, area.maxX - width))
        let y = max(area.minY, min(window.frame.minY, area.maxY - height))
        window.setFrame(NSRect(x: x, y: y, width: width, height: height), display: false)
    }

    @objc func containGraphWindows() {
        containGraphWindow(panel)
        for window in resourcePanels.values { containGraphWindow(window) }
        updateGraphMinimumSizes()
    }

    @objc func toggleAllCores() {
        guard let view = resourceViews["cpu"], let window = resourcePanels["cpu"] else { return }
        view.showAllCores.toggle()
        UserDefaults.standard.set(view.showAllCores, forKey: "cpuAllCores")
        if view.showAllCores && (window.frame.width < 450 || window.frame.height < 280) { enlargeCPU() }
        if !view.showAllCores { compactCPU() }
    }

    @objc func enlargeCPU() {
        guard let window = resourcePanels["cpu"] else { return }
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: "cpuExpanded") {
            defaults.set(NSStringFromRect(window.frame), forKey: "cpuCompactFrame")
        }
        defaults.set(true, forKey: "cpuExpanded")
        let screen = window.screen?.visibleFrame ?? NSScreen.main!.visibleFrame
        let width = min(screen.width, max(680, window.frame.width * 1.25))
        let height = min(screen.height, max(430, window.frame.height * 1.25))
        let x = max(screen.minX, min(window.frame.minX, screen.maxX - width))
        let y = max(screen.minY, min(window.frame.maxY - height, screen.maxY - height))
        window.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
        window.saveFrame(usingName: "ResourceWindow-cpu")
    }

    @objc func compactCPU() {
        guard let window = resourcePanels["cpu"] else { return }
        let size = window.frameRect(forContentRect: NSRect(x: 0, y: 0, width: 280, height: 150)).size
        let origin = NSPoint(x: window.frame.minX, y: window.frame.maxY - size.height)
        window.setFrame(NSRect(origin: origin, size: size), display: true)
        UserDefaults.standard.set(false, forKey: "cpuExpanded")
        window.saveFrame(usingName: "ResourceWindow-cpu")
    }

}
