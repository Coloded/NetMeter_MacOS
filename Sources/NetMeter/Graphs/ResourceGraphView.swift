import AppKit

final class ResourceGraphView: NSView {
    override func viewDidChangeEffectiveAppearance() { super.viewDidChangeEffectiveAppearance(); needsDisplay = true }
    var history: [(Double, Double)] = []
    var reading: ResourceReading?
    var percentage = true
    var color: NSColor = .systemBlue
    var showGrid = true
    var showRates = true
    var showAllCores = false { didSet { needsDisplay = true } }
    var contextMenuProvider: (() -> NSMenu)?
    var coreHistory: [[Double]] = []
    var currentCores: [Double]?

    override func menu(for event: NSEvent) -> NSMenu? { contextMenuProvider?() ?? super.menu(for: event) }

    func appendCores(_ values: [Double]?) {
        currentCores = values
        if let values {
            if coreHistory.count != values.count { coreHistory = Array(repeating: [], count: values.count) }
            for (index, value) in values.enumerated() {
                coreHistory[index].append(value)
                if coreHistory[index].count > 60 { coreHistory[index].removeFirst() }
            }
        }
        if showAllCores { needsDisplay = true }
    }

    func append(_ value: ResourceReading?) {
        reading = value
        if let value {
            history.append((value.first, value.second))
            if history.count > 60 { history.removeFirst() }
        }
        needsDisplay = true
    }

    var graphID = "network"
    var openMonitor: (() -> Void)?
    override var mouseDownCanMoveWindow: Bool { false }
    override func mouseDown(with event: NSEvent) { }
    override func mouseUp(with event: NSEvent) {
        if bounds.contains(convert(event.locationInWindow, from: nil)) { openMonitor?() }
    }

    override func draw(_ dirtyRect: NSRect) {
        GraphAppearance.background.setFill()
        bounds.fill()
        if showAllCores { drawCores(); return }
        let plot = NSRect(x: 12, y: 37, width: bounds.width - 24, height: bounds.height - 65)
        GraphAppearance.plot.setFill()
        plot.fill()
        if showGrid {
            GraphAppearance.grid.setStroke()
            for fraction in [0.25, 0.5, 0.75] {
                let line = NSBezierPath()
                line.move(to: NSPoint(x: plot.minX, y: plot.minY + plot.height * fraction))
                line.line(to: NSPoint(x: plot.maxX, y: plot.minY + plot.height * fraction))
                line.stroke()
            }
        }
        let scale = percentage ? 100 : max(1024, history.map { max($0.0, $0.1) }.max() ?? 0)
        for (index, lineColor) in [color, GraphAppearance.color(id: graphID, component: "line2", fallback: .systemOrange)].enumerated() {
            if percentage && index == 1 { continue }
            let path = NSBezierPath()
            path.lineWidth = 2
            for (i, value) in history.enumerated() {
                let y = index == 0 ? value.0 : value.1
                let point = NSPoint(x: plot.maxX - CGFloat(history.count - 1 - i) * plot.width / 59,
                                    y: plot.minY + CGFloat(min(max(y / scale, 0), 1)) * plot.height)
                if i == 0 { path.move(to: point) } else { path.line(to: point) }
            }
            lineColor.setStroke()
            path.stroke()
        }
        let font = GraphFonts.font("values", fallbackSize: 11)
        func text(_ value: String, x: CGFloat, y: CGFloat, color: NSColor) {
            (value as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: [.font: y == bounds.height - 23 ? GraphFonts.font("heading", fallbackSize: 11) : font, .foregroundColor: color])
        }
        text(reading?.header ?? L("graph.no_sensor"), x: 12, y: bounds.height - 23, color: GraphAppearance.color(id: graphID, component: "title", fallback: GraphAppearance.text))
        if showRates {
            text(reading?.footer ?? "—", x: 12, y: 10, color: GraphAppearance.color(id: graphID, component: "label1", fallback: GraphAppearance.defaultLine(id: graphID)))
            text(reading?.secondary ?? "", x: bounds.width / 2 + 10, y: 10, color: GraphAppearance.color(id: graphID, component: percentage ? "label1" : "label2", fallback: GraphAppearance.defaultLine(id: graphID, second: !percentage)))
        }
    }

}
