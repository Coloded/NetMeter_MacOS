import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSMenuItemValidation {
    var statusItem: NSStatusItem!
    var panel: NSPanel!
    var graph: NetworkGraphView!
    var timer: Timer?
    var selection = UserDefaults.standard.string(forKey: "interface") ?? "auto"
    var selectionGeneration = 0
    var selectedInterface = ""
    var interfaceMenu: NSMenu!
    var refreshCount = 0
    var loginAtStartupButton: NSButton?
    var loginAtStartupApprovalButton: NSButton?
    var graphFontButtons: [String: NSButton] = [:]
    var selectedFontRole = "values"
    var settingsWindow: NSWindow?
    var networkSummaryLabel: NSTextField?
    var sessionDown: UInt64 = 0
    var sessionUp: UInt64 = 0
    var totalsLabel: NSTextField?
    let collector = MetricsCollector()
    let settings = SettingsStore()
    var gpuAvailable = false
    private var gpuPresented = false
    let docking = WindowDocking()
    var resourcePanels: [String: NSPanel] = [:]
    var resourceViews: [String: ResourceGraphView] = [:]
    var graphItems: [String: NSMenuItem] = [:]
    var glueMenuItem: NSMenuItem!
    var openNetworkItem: NSMenuItem!
    var updates: UpdateController!
    var aboutWindow: NSWindow?
    var lastSnapshot: MetricsSnapshot?
    var colorSelection: (id: String, component: String)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        updates = UpdateController()
        createNetworkPanel()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateStatusRates(nil)
        buildStatusMenu()
        makeResourcePanels()
        applyGraphAppearance()
        updateGraphMinimumSizes()
        docking.onClose = { [weak self] id in
            UserDefaults.standard.set(false, forKey: "graphEnabled-\(id)")
            self?.graphItems[id]?.state = .off
        }
        updateGraphMenu()
        DiagnosticCenter.shared.record("application", "started", detail: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown", interval: 0)
        timer = Timer(timeInterval: 1, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
        RunLoop.main.add(timer!, forMode: .common)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(didWake), name: NSWorkspace.didWakeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(containGraphWindows), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        tick()
        if !UserDefaults.standard.bool(forKey: "settingsSeen") || CommandLine.arguments.contains("--settings") {
            UserDefaults.standard.set(true, forKey: "settingsSeen")
            showSettings()
        }
    }

    @objc func tick() {
        let requestedSelection = selection
        let generation = selectionGeneration
        collector.collect(selection: requestedSelection) { [weak self] snapshot in
            guard let self, selection == requestedSelection, generation == selectionGeneration else { return }
            lastSnapshot = snapshot
            selectedInterface = snapshot.interface
            graph.interfaceName = snapshot.interfaceTitle
            if snapshot.gap || snapshot.network.discontinuity { graph.samples = [] }
            graph.isNetworkAvailable = snapshot.network.sample != nil
            if let sample = snapshot.network.sample {
                graph.samples.append(sample)
                if graph.samples.count > 60 { graph.samples.removeFirst() }
                sessionDown &+= snapshot.network.receivedDelta
                sessionUp &+= snapshot.network.sentDelta
                let defaults = settings.defaults
                defaults.set(defaults.double(forKey: "totalDown") + Double(snapshot.network.receivedDelta), forKey: "totalDown")
                defaults.set(defaults.double(forKey: "totalUp") + Double(snapshot.network.sentDelta), forKey: "totalUp")
            }
            updateStatusRates(snapshot.network.sample)
            updateTotalsLabel()
            refreshNetworkSummary()
            let wasAvailable = gpuAvailable
            gpuAvailable = snapshot.readings["gpu"] != nil
            if gpuAvailable && !gpuPresented {
                gpuPresented = true
                if settings.defaults.object(forKey: "graphEnabled-gpu") as? Bool ?? true { resourcePanels["gpu"]?.orderFrontRegardless() }
            }
            if wasAvailable != gpuAvailable { updateGraphMenu() }
            for (id, view) in resourceViews {
                if snapshot.gap { view.history = []; view.coreHistory = [] }
                view.append(snapshot.readings[id])
                if resourcePanels[id]?.isVisible != true { view.needsDisplay = false }
            }
            resourceViews["cpu"]?.appendCores(snapshot.cores)
            for (id, view) in resourceViews where resourcePanels[id]?.isVisible != true { view.needsDisplay = false }
        }
    }

    @objc func didWake() { collector.didWake() }
    func refreshPresentation() {
        graph.needsDisplay = true
        for view in resourceViews.values { view.needsDisplay = true }
        updateStatusRates(lastSnapshot?.network.sample)
        updateTotalsLabel()
        refreshNetworkSummary()
    }

    @objc func quit() { NSApp.terminate(nil) }
}
