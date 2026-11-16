import AppKit

final class NetworkGraphView: NSView {
    var contextMenuProvider: (() -> NSMenu)?
    override func menu(for event: NSEvent) -> NSMenu? { contextMenuProvider?() ?? super.menu(for: event) }
    var isNetworkAvailable = false { didSet { needsDisplay = true } }
    var samples: [NetworkSample] = [] { didSet { needsDisplay = true } }
    var interfaceName = "" { didSet { needsDisplay = true } }
    var showGrid = true { didSet { needsDisplay = true } }
    var showRates = true { didSet { needsDisplay = true } }
    var showMaximum = true { didSet { needsDisplay = true } }
    var fixedScale: Double = 0 { didSet { needsDisplay = true } }
    var downColor: NSColor = .systemRed { didSet { needsDisplay = true } }
    var upColor: NSColor = .systemGreen { didSet { needsDisplay = true } }
    override var isOpaque: Bool { true }
    override func viewDidChangeEffectiveAppearance() { super.viewDidChangeEffectiveAppearance(); needsDisplay = true }

    var graphID = "network"
    var openMonitor: (() -> Void)?
    override var mouseDownCanMoveWindow: Bool { false }
    override func mouseDown(with event: NSEvent) { }
    override func mouseUp(with event: NSEvent) {
        if bounds.contains(convert(event.locationInWindow, from: nil)) { openMonitor?() }
    }

    override func draw(_ dirtyRect: NSRect) {
        let bounds = self.bounds
        GraphAppearance.background.setFill()
        bounds.fill()
        let headingHeight = GraphTextLayout.rowHeight("heading", fallback: 11, availableHeight: bounds.height)
        let valueHeight = GraphTextLayout.rowHeight("values", fallback: 12, availableHeight: bounds.height)
        let footerHeight = showRates ? valueHeight + 12 : 8
        let plot = NSRect(x: 12, y: footerHeight, width: max(bounds.width - 24, 1), height: max(bounds.height - footerHeight - headingHeight - 18, 1))
        GraphAppearance.plot.setFill()
        plot.fill()
        if showGrid {
            GraphAppearance.grid.setStroke()
            for fraction in [0.25, 0.5, 0.75] {
                let line = NSBezierPath()
                let y = plot.minY + plot.height * fraction
                line.move(to: NSPoint(x: plot.minX, y: y))
                line.line(to: NSPoint(x: plot.maxX, y: y))
                line.stroke()
            }
        }
        let scale = fixedScale > 0 ? fixedScale : max(samples.map { max($0.down, $0.up) }.max() ?? 0, 1024)
        for (color, value) in [(downColor, { (s: NetworkSample) in s.downAvailable ? s.down : Double.nan }), (upColor, { (s: NetworkSample) in s.upAvailable ? s.up : Double.nan })] {
            let path = NSBezierPath()
            path.lineWidth = 2
            var started = false
            for (index, sample) in samples.enumerated() {
                guard value(sample).isFinite else { started = false; continue }
                let x = plot.maxX - CGFloat(samples.count - 1 - index) * plot.width / 59
                let y = plot.minY + CGFloat(min(value(sample) / scale, 1)) * plot.height
                if !started { path.move(to: NSPoint(x: x, y: y)); started = true }
                else { path.line(to: NSPoint(x: x, y: y)) }
            }
            color.setStroke()
            path.stroke()
        }
        let latest = samples.last ?? NetworkSample(down: 0, up: 0)
        if showRates {
            GraphTextLayout.draw(isNetworkAvailable && latest.downAvailable ? "↓ \(formatRate(latest.down))" : "↓ —", rect: NSRect(x: 12, y: 6, width: bounds.width / 2 - 18, height: valueHeight), role: "values", fallback: 12, color: GraphAppearance.color(id: graphID, component: "label1", fallback: .systemRed))
            GraphTextLayout.draw(isNetworkAvailable && latest.upAvailable ? "↑ \(formatRate(latest.up))" : "↑ —", rect: NSRect(x: bounds.width / 2 + 6, y: 6, width: bounds.width / 2 - 18, height: valueHeight), role: "values", fallback: 12, color: GraphAppearance.color(id: graphID, component: "label2", fallback: .systemGreen))
        }
        let titleColor = GraphAppearance.color(id: graphID, component: "title", fallback: GraphAppearance.text)
        let title = showMaximum ? "\(interfaceName) · \(L("graph.max", formatRate(scale, unit: UserDefaults.standard.string(forKey: "maximumRateUnit") ?? "auto_binary")))" : interfaceName
        toolTip = title
        GraphTextLayout.draw(title, rect: NSRect(x: 12, y: bounds.height - headingHeight - 8, width: bounds.width - 24, height: headingHeight), role: "heading", fallback: 11, color: titleColor)
    }
}
