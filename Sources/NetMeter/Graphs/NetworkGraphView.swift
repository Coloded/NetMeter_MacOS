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
        let plot = NSRect(x: 12, y: 37, width: bounds.width - 24, height: bounds.height - (showMaximum ? 80 : 65))
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
            drawText("↓ \(formatRate(latest.down))", x: 12, y: 10, color: GraphAppearance.color(id: graphID, component: "label1", fallback: .systemRed))
            drawText("↑ \(formatRate(latest.up))", x: bounds.width / 2, y: 10, color: GraphAppearance.color(id: graphID, component: "label2", fallback: .systemGreen))
        }
        let titleColor = GraphAppearance.color(id: graphID, component: "title", fallback: GraphAppearance.text)
        let header = NSAttributedString(string: interfaceName, attributes: [.foregroundColor: titleColor, .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)])
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        let fitted = NSMutableAttributedString(attributedString: header)
        fitted.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: fitted.length))
        fitted.draw(in: NSRect(x: 12, y: bounds.height - 25, width: bounds.width - 24, height: 17))
        if showMaximum { drawText(L("graph.max", formatRate(scale)), x: 12, y: bounds.height - 40, color: titleColor) }
    }

    private func drawText(_ value: String, x: CGFloat, y: CGFloat, color: NSColor) {
        (value as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: [
            .foregroundColor: color,
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        ])
    }
}

