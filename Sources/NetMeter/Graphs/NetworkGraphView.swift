import AppKit

final class NetworkGraphView: NSView {
    var contextMenuProvider: (() -> NSMenu)?
    override func menu(for event: NSEvent) -> NSMenu? { contextMenuProvider?() ?? super.menu(for: event) }
    var samples: [NetworkSample] = [] { didSet { needsDisplay = true } }
    var interfaceName = "" { didSet { needsDisplay = true } }
    var showGrid = true { didSet { needsDisplay = true } }
    var showRates = true { didSet { needsDisplay = true } }
    var showMaximum = true { didSet { needsDisplay = true } }
    var fixedScale: Double = 0 { didSet { needsDisplay = true } }
    var downColor: NSColor = .systemRed { didSet { needsDisplay = true } }
    var upColor: NSColor = .systemGreen { didSet { needsDisplay = true } }
    override var isOpaque: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let bounds = self.bounds
        NSColor(calibratedRed: 0.07, green: 0.09, blue: 0.13, alpha: 1).setFill()
        bounds.fill()
        let plot = NSRect(x: 12, y: 37, width: bounds.width - 24, height: bounds.height - 65)
        NSColor(calibratedRed: 0.12, green: 0.16, blue: 0.21, alpha: 1).setFill()
        plot.fill()
        if showGrid {
            NSColor.white.withAlphaComponent(0.12).setStroke()
            for fraction in [0.25, 0.5, 0.75] {
                let line = NSBezierPath()
                let y = plot.minY + plot.height * fraction
                line.move(to: NSPoint(x: plot.minX, y: y))
                line.line(to: NSPoint(x: plot.maxX, y: y))
                line.stroke()
            }
        }
        let scale = fixedScale > 0 ? fixedScale : max(samples.map { max($0.down, $0.up) }.max() ?? 0, 1024)
        for (color, value) in [(downColor, { (s: NetworkSample) in s.down }), (upColor, { (s: NetworkSample) in s.up })] {
            let path = NSBezierPath()
            path.lineWidth = 2
            for (index, sample) in samples.enumerated() {
                let x = plot.maxX - CGFloat(samples.count - 1 - index) * plot.width / 59
                let y = plot.minY + CGFloat(min(value(sample) / scale, 1)) * plot.height
                if index == 0 { path.move(to: NSPoint(x: x, y: y)) }
                else { path.line(to: NSPoint(x: x, y: y)) }
            }
            color.setStroke()
            path.stroke()
        }
        let latest = samples.last ?? NetworkSample(down: 0, up: 0)
        if showRates {
            drawText("↓ \(formatRate(latest.down))", x: 12, y: 10, color: downColor)
            drawText("↑ \(formatRate(latest.up))", x: bounds.width / 2, y: 10, color: upColor)
        }
        drawText(showMaximum ? "\(interfaceName) · \(L("graph.max", formatRate(scale)))" : interfaceName,
                 x: 12, y: bounds.height - 23, color: .white)
    }

    private func drawText(_ value: String, x: CGFloat, y: CGFloat, color: NSColor) {
        (value as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: [
            .foregroundColor: color,
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        ])
    }
}

