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
        toolTip = [value?.header, value?.footer, value?.secondary, value?.details].compactMap { $0 }.joined(separator: "\n")
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
        let headingHeight = min(GraphTextLayout.rowHeight("heading", fallback: 11, availableHeight: bounds.height), max(bounds.height * 0.25, 1))
        let valueHeight = min(GraphTextLayout.rowHeight("values", fallback: 11, availableHeight: bounds.height), max(bounds.height * 0.22, 1))
        let extra: CGFloat = reading?.details.isEmpty == false ? valueHeight + 4 : 0
        let footerHeight = showRates ? valueHeight + extra + 12 : 8
        let plot = NSRect(x: 12, y: footerHeight, width: max(bounds.width - 24, 1), height: max(bounds.height - footerHeight - headingHeight - 18, 1))
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
        GraphTextLayout.draw(reading?.header ?? L("graph.no_sensor"), rect: NSRect(x: 12, y: bounds.height - headingHeight - 8, width: bounds.width - 24, height: headingHeight), role: "heading", fallback: 11, color: GraphAppearance.color(id: graphID, component: "title", fallback: GraphAppearance.text))
        if showRates {
            GraphTextLayout.draw(reading?.footer ?? "—", rect: NSRect(x: 12, y: 6 + extra, width: bounds.width / 2 - 18, height: valueHeight), role: "values", fallback: 11, color: GraphAppearance.color(id: graphID, component: "label1", fallback: GraphAppearance.defaultLine(id: graphID)))
            GraphTextLayout.draw(reading?.secondary ?? "", rect: NSRect(x: bounds.width / 2 + 6, y: 6 + extra, width: bounds.width / 2 - 18, height: valueHeight), role: "values", fallback: 11, color: GraphAppearance.color(id: graphID, component: percentage ? "label1" : "label2", fallback: GraphAppearance.defaultLine(id: graphID, second: !percentage)))
            if let details = reading?.details, !details.isEmpty {
                GraphTextLayout.draw(details, rect: NSRect(x: 12, y: 2, width: bounds.width - 24, height: valueHeight), role: "values", fallback: 9, color: GraphAppearance.text)
            }
        }
    }

}
