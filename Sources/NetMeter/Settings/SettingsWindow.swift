import AppKit

extension AppDelegate {
    @objc func showSettings() {
        if settingsWindow == nil { makeSettingsWindow() }
        refreshLoginAtStartup()
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @discardableResult func label(_ text: String, x: CGFloat, y: CGFloat, width: CGFloat? = nil, in parent: NSView) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.frame = NSRect(x: x, y: y, width: width ?? max(parent.bounds.width - x - 24, 0), height: 22)
        parent.addSubview(field)
        return field
    }

    func check(_ title: String, key: String, initial: Bool, y: CGFloat, in parent: NSView, tag: Int) {
        let button = NSButton(checkboxWithTitle: title, target: self, action: #selector(changeCheck(_:)))
        button.frame = NSRect(x: 24, y: y, width: parent.bounds.width - 48, height: 25)
        button.state = (UserDefaults.standard.object(forKey: key) as? Bool ?? initial) ? .on : .off
        button.tag = tag
        parent.addSubview(button)
    }

    func makeSettingsWindow() {
        let window = NSWindow(contentRect: NSRect(x: 300, y: 300, width: 640, height: 400),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = L("settings.title")
        window.isReleasedWhenClosed = false
        window.setFrameUsingName("TrafficSettingsWindow")
        window.setFrameAutosaveName("TrafficSettingsWindow")
        if window.frame.width < 640 || window.contentLayoutRect.height < 400 { window.setContentSize(NSSize(width: 640, height: 400)) }
        let tabs = NSTabView(frame: NSRect(x: 12, y: 10, width: 616, height: 380))
        window.contentView?.addSubview(tabs)
        func tab(_ title: String) -> NSView {
            let item = NSTabViewItem(identifier: title)
            item.label = title
            let view = NSView(frame: NSRect(x: 0, y: 0, width: 610, height: 340))
            item.view = view
            tabs.addTabViewItem(item)
            return view
        }

        let general = tab(L("settings.general"))
        label(L("network.interface_summary", NetworkDiscovery.displayName(defaultInterface()), NetworkDiscovery.displayName(selectedInterface)), x: 24, y: 228, in: general)
        label(L("network.select_hint"), x: 24, y: 202, in: general)
        check(L("settings.top_all"), key: "alwaysOnTop", initial: true, y: 160, in: general, tag: 1)
        label(L("settings.opacity"), x: 24, y: 118, in: general)
        let opacity = NSSlider(value: UserDefaults.standard.object(forKey: "opacity") == nil ? 1 : UserDefaults.standard.double(forKey: "opacity"),
                               minValue: 0.35, maxValue: 1, target: self, action: #selector(changeOpacity(_:)))
        opacity.frame = NSRect(x: 24, y: 87, width: 280, height: 28)
        general.addSubview(opacity)
        label(L("menu.language"), x: 24, y: 43, width: 150, in: general)
        let language = NSPopUpButton(frame: NSRect(x: 200, y: 36, width: 280, height: 30))
        for (code, name) in L10n.choices {
            language.addItem(withTitle: name)
            language.lastItem?.representedObject = code
        }
        language.selectItem(at: L10n.choices.firstIndex { $0.0 == L10n.preference } ?? 0)
        language.target = self
        language.action = #selector(selectLanguagePopup(_:))
        general.addSubview(language)

        label(L("settings.style"), x: 24, y: 7, width: 150, in: general)
        let style = NSPopUpButton(frame: NSRect(x: 200, y: 0, width: 280, height: 30))
        style.addItems(withTitles: [L("style.classic"), "macOS"])
        style.selectItem(at: GraphAppearance.isMacOS ? 1 : 0)
        style.target = self
        style.action = #selector(changeGraphStyle(_:))
        general.addSubview(style)

        for view in general.subviews { view.frame.origin.y += 60 }
        addLoginAtStartupControls(to: general)

        let graphTab = tab(L("settings.graph"))
        check(L("settings.grid"), key: "grid", initial: true, y: 225, in: graphTab, tag: 2)
        check(L("settings.rates"), key: "rates", initial: true, y: 190, in: graphTab, tag: 3)
        check(L("settings.maximum"), key: "maximum", initial: true, y: 155, in: graphTab, tag: 4)
        label(L("settings.scale"), x: 24, y: 112, in: graphTab)
        let scale = NSPopUpButton(frame: NSRect(x: 24, y: 72, width: 230, height: 30))
        scale.addItems(withTitles: [L("settings.auto"), "1 MiB/s", "10 MiB/s", "100 MiB/s", "1 GiB/s"])
        scale.selectItem(at: [0, 1, 10, 100, 1024].firstIndex(of: Int(graph.fixedScale / 1048576)) ?? 0)
        scale.target = self
        scale.action = #selector(changeScale(_:))
        graphTab.addSubview(scale)

        let unitTab = tab(L("units.title"))
        for (index, entry) in [("rateUnit", "units.current"), ("maximumRateUnit", "units.maximum"), ("totalUnit", "units.totals")].enumerated() {
            let y = CGFloat(245 - index * 70)
            label(L10n.text(entry.1), x: 24, y: y, width: 150, in: unitTab)
            let popup = NSPopUpButton(frame: NSRect(x: 190, y: y - 5, width: 350, height: 30))
            popup.identifier = NSUserInterfaceItemIdentifier(entry.0)
            for (value, title) in rateUnitChoices {
                let display = title.hasPrefix("units.") ? L10n.text(title) : entry.0 == "totalUnit" ? title.replacingOccurrences(of: "/s", with: "") : title
                popup.addItem(withTitle: display)
                popup.lastItem?.representedObject = value
            }
            let preference = UserDefaults.standard.string(forKey: entry.0) ?? "auto_binary"
            popup.selectItem(at: rateUnitChoices.firstIndex { $0.0 == preference } ?? 0)
            popup.target = self
            popup.action = #selector(changeRateUnit(_:))
            unitTab.addSubview(popup)
        }
        graphFontButtons = [:]
        addFontControls(to: tab(L("fonts.title")))

        let colors = tab(L("settings.colors"))
        label(L("settings.download"), x: 24, y: 224, width: 150, in: colors)
        let downWell = NSColorWell(frame: NSRect(x: 190, y: 218, width: 90, height: 32))
        downWell.color = graph.downColor
        downWell.tag = 1
        downWell.target = self
        downWell.action = #selector(changeNetworkColor(_:))
        colors.addSubview(downWell)
        label(L("settings.upload"), x: 24, y: 174, width: 150, in: colors)
        let upWell = NSColorWell(frame: NSRect(x: 190, y: 168, width: 90, height: 32))
        upWell.color = graph.upColor
        upWell.tag = 2
        upWell.target = self
        upWell.action = #selector(changeNetworkColor(_:))
        colors.addSubview(upWell)

        let totals = tab(L("settings.totals"))
        totalsLabel = label("", x: 24, y: 155, width: 420, in: totals)
        totalsLabel?.maximumNumberOfLines = 0
        totalsLabel?.frame.size.height = 90
        updateTotalsLabel()
        let reset = NSButton(title: L("settings.reset_totals"), target: self, action: #selector(resetTotals))
        reset.frame = NSRect(x: 24, y: 90, width: 150, height: 30)
        totals.addSubview(reset)
        let updateTab = tab(L("settings.updates"))
        updates.addControls(to: updateTab, y: 230)
        L10n.applyDirection(to: window.contentView!)
        settingsWindow = window
    }

    @objc func changeCheck(_ sender: NSButton) {
        let enabled = sender.state == .on
        switch sender.tag {
        case 1: UserDefaults.standard.set(enabled, forKey: "alwaysOnTop"); panel.level = enabled ? .floating : .normal
        case 2: UserDefaults.standard.set(enabled, forKey: "grid"); graph.showGrid = enabled
        case 3: UserDefaults.standard.set(enabled, forKey: "rates"); graph.showRates = enabled
        case 4: UserDefaults.standard.set(enabled, forKey: "maximum"); graph.showMaximum = enabled
        default: break
        }
        for window in resourcePanels.values { window.level = panel.level }
        for view in resourceViews.values {
            view.showGrid = graph.showGrid
            view.showRates = graph.showRates
            view.needsDisplay = true
        }
    }

    @objc func changeOpacity(_ sender: NSSlider) {
        panel.alphaValue = sender.doubleValue
        for window in resourcePanels.values { window.alphaValue = sender.doubleValue }
        UserDefaults.standard.set(sender.doubleValue, forKey: "opacity")
    }

    @objc func changeScale(_ sender: NSPopUpButton) {
        let values: [Double] = [0, 1, 10, 100, 1024].map { $0 * 1048576 }
        graph.fixedScale = values[sender.indexOfSelectedItem]
        UserDefaults.standard.set(graph.fixedScale, forKey: "scale")
    }

    @objc func changeNetworkColor(_ source: Any) {
        guard let sender = source as? NSColorWell else { return }
        let key = sender.tag == 1 ? "downColor" : "upColor"
        if sender.tag == 1 { graph.downColor = sender.color } else { graph.upColor = sender.color }
        GraphAppearance.save(sender.color, id: "network", component: sender.tag == 1 ? "line1" : "line2")
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: sender.color, requiringSecureCoding: true) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func updateTotalsLabel() {
        let defaults = UserDefaults.standard
        func total(_ bytes: Double) -> String { formatByteCount(bytes) }
        totalsLabel?.stringValue = L("settings.session", total(Double(sessionDown)), total(Double(sessionUp))) + "\n" + L("settings.all_time", total(defaults.double(forKey: "totalDown")), total(defaults.double(forKey: "totalUp")))
    }

    @objc func resetTotals() {
        UserDefaults.standard.set(0, forKey: "totalDown")
        UserDefaults.standard.set(0, forKey: "totalUp")
        sessionDown = 0
        sessionUp = 0
        updateTotalsLabel()
    }
}
