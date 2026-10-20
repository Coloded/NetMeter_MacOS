import AppKit

final class ResourceGraphView: NSView {
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

    override func draw(_ dirtyRect: NSRect) {
        NSColor(calibratedRed: 0.07, green: 0.09, blue: 0.13, alpha: 1).setFill()
        bounds.fill()
        if showAllCores { drawCores(); return }
        let plot = NSRect(x: 12, y: 37, width: bounds.width - 24, height: bounds.height - 65)
        NSColor(calibratedRed: 0.12, green: 0.16, blue: 0.21, alpha: 1).setFill()
        plot.fill()
        if showGrid {
            NSColor.white.withAlphaComponent(0.12).setStroke()
            for fraction in [0.25, 0.5, 0.75] {
                let line = NSBezierPath()
                line.move(to: NSPoint(x: plot.minX, y: plot.minY + plot.height * fraction))
                line.line(to: NSPoint(x: plot.maxX, y: plot.minY + plot.height * fraction))
                line.stroke()
            }
        }
        let scale = percentage ? 100 : max(1024, history.map { max($0.0, $0.1) }.max() ?? 0)
        for (index, lineColor) in [color, NSColor.systemOrange].enumerated() {
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
        let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        func text(_ value: String, x: CGFloat, y: CGFloat, color: NSColor) {
            (value as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: [.font: font, .foregroundColor: color])
        }
        text(reading?.header ?? L("graph.no_sensor"), x: 12, y: bounds.height - 23, color: .white)
        if showRates {
            text(reading?.footer ?? "—", x: 12, y: 10, color: color)
            text(reading?.secondary ?? "", x: bounds.width / 2 + 10, y: 10, color: percentage ? color : .systemOrange)
        }
    }

}
