import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSMenuItemValidation {
    var statusItem: NSStatusItem!
    var panel: NSPanel!
    var graph: NetworkGraphView!
    var timer: Timer?
    var previous: (received: UInt64, sent: UInt64)?
    var previousTime: Date?
    var selection = UserDefaults.standard.string(forKey: "interface") ?? "auto"
    var selectedInterface = defaultInterface()
    var interfaceMenu: NSMenu!
    var refreshCount = 0
    var settingsWindow: NSWindow?
    var sessionDown: UInt64 = 0
    var sessionUp: UInt64 = 0
    var totalsLabel: NSTextField?
    let metrics = SystemMetrics()
    let docking = WindowDocking()
    var resourcePanels: [String: NSPanel] = [:]
    var resourceViews: [String: ResourceGraphView] = [:]
    var graphItems: [String: NSMenuItem] = [:]
    var glueMenuItem: NSMenuItem!
    var openNetworkItem: NSMenuItem!
    var updates: UpdateController!
    var aboutWindow: NSWindow?
    var colorSelection: (id: String, component: String)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        updates = UpdateController()
        createNetworkPanel()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        statusItem.button?.title = "↓ 0 B/s  ↑ 0 B/s"
        buildStatusMenu()
        makeResourcePanels()
        applyGraphAppearance()
        docking.onClose = { [weak self] id in
            UserDefaults.standard.set(false, forKey: "graphEnabled-\(id)")
            self?.graphItems[id]?.state = .off
        }
        updateGraphMenu()
        timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
        tick()
        if !UserDefaults.standard.bool(forKey: "settingsSeen") || CommandLine.arguments.contains("--settings") {
            UserDefaults.standard.set(true, forKey: "settingsSeen")
            showSettings()
        }
    }

    @objc func tick() {
        refreshCount += 1
        if selection == "auto", refreshCount % 5 == 0 {
            let current = defaultInterface()
            if current != selectedInterface {
                selectedInterface = current
                previous = nil
                graph.samples = []
                graph.interfaceName = NetworkDiscovery.displayName(current)
            }
        }
        let now = Date()
        let value = counters()[selectedInterface]
        var sample = NetworkSample(down: 0, up: 0)
        if let value, let previous, let previousTime {
            let seconds = now.timeIntervalSince(previousTime)
            if seconds > 0, value.received >= previous.received, value.sent >= previous.sent {
                let received = value.received - previous.received
                let sent = value.sent - previous.sent
                sample = NetworkSample(down: Double(received) / seconds, up: Double(sent) / seconds)
                sessionDown += received
                sessionUp += sent
                let defaults = UserDefaults.standard
                defaults.set(defaults.double(forKey: "totalDown") + Double(received), forKey: "totalDown")
                defaults.set(defaults.double(forKey: "totalUp") + Double(sent), forKey: "totalUp")
            }
        }
        previous = value
        previousTime = now
        graph.samples.append(sample)
        if graph.samples.count > 60 { graph.samples.removeFirst() }
        statusItem.button?.title = "↓ \(formatRate(sample.down))  ↑ \(formatRate(sample.up))"
        updateTotalsLabel()
        let readings = ["cpu": metrics.cpu(), "memory": metrics.memory(), "gpu": metrics.gpuAvailable ? metrics.gpu() : nil, "disk": metrics.disk()]
        for (id, view) in resourceViews { view.append(readings[id] ?? nil) }
        resourceViews["cpu"]?.appendCores(metrics.cpuCores())
    }

    @objc func quit() { NSApp.terminate(nil) }
}
