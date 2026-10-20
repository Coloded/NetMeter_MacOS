import AppKit

extension ResourceGraphView {
    static func coreGrid(count: Int, size: NSSize) -> (columns: Int, rows: Int) {
        let columns = min(max(count, 1), max(1, Int(ceil(sqrt(Double(max(count, 1)) * Double(max(size.width, 1) / max(size.height, 1)) * 0.6)))))
        return (columns, (max(count, 1) + columns - 1) / columns)
    }

    func drawCores() {
        let count = max(coreHistory.count, ProcessInfo.processInfo.activeProcessorCount)
        let inset: CGFloat = 10
        let area = bounds.insetBy(dx: inset, dy: inset)
        let grid = Self.coreGrid(count: count, size: area.size)
        let gap: CGFloat = 8
        let cellWidth = (area.width - CGFloat(grid.columns - 1) * gap) / CGFloat(grid.columns)
        let cellHeight = (area.height - CGFloat(grid.rows - 1) * gap) / CGFloat(grid.rows)
        for index in 0..<count {
            let x = area.minX + CGFloat(index % grid.columns) * (cellWidth + gap)
            let y = area.maxY - CGFloat(index / grid.columns + 1) * cellHeight - CGFloat(index / grid.columns) * gap
            let plot = NSRect(x: x, y: y, width: cellWidth, height: max(cellHeight - 20, 1))
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
            if coreHistory.indices.contains(index) {
                let path = NSBezierPath()
                path.lineWidth = 1.5
                let history = coreHistory[index]
                for (i, value) in history.enumerated() {
                    let point = NSPoint(x: plot.maxX - CGFloat(history.count - 1 - i) * plot.width / 59,
                                        y: plot.minY + CGFloat(min(max(value, 0), 100) / 100) * plot.height)
                    if i == 0 { path.move(to: point) } else { path.line(to: point) }
                }
                color.setStroke()
                path.stroke()
            }
            let value = currentCores?.indices.contains(index) == true ? String(format: " %.0f%%", currentCores![index]) : " —"
            let label = L("cpu.core", index + 1) + (showRates ? value : "")
            (label as NSString).draw(at: NSPoint(x: x, y: y + cellHeight - 15), withAttributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium), .foregroundColor: GraphAppearance.color(id: graphID, component: "label1", fallback: GraphAppearance.text)
            ])
        }
    }
}
