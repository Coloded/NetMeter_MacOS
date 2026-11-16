import AppKit

enum GraphTextLayout {
    static func height(_ font: NSFont) -> CGFloat { ceil(font.ascender - font.descender + font.leading) + 2 }
    static func draw(_ text: String, rect: NSRect, role: String, fallback: CGFloat, color: NSColor) {
        guard rect.width > 0, rect.height > 0 else { return }
        let selected = GraphFonts.font(role, fallbackSize: fallback)
        let font = fittedFont(text: text, rect: rect, selected: selected, autoFit: GraphFonts.autoFit)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        paragraph.baseWritingDirection = L10n.direction == .rightToLeft ? .rightToLeft : .leftToRight
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: rect).addClip()
        defer { NSGraphicsContext.restoreGraphicsState() }
        (text as NSString).draw(in: rect, withAttributes: [.font: font, .foregroundColor: color, .paragraphStyle: paragraph])
    }
    // A 6pt minimum preserves legibility; undersized rectangles truncate and clip
    // inside their allocated row while the view tooltip retains the full value.
    static func fittedFont(text: String, rect: NSRect, selected: NSFont, autoFit: Bool) -> NSFont {
        var size = selected.pointSize
        if autoFit {
            let measured = (text as NSString).size(withAttributes: [.font: selected])
            let factor = min(1, rect.width / max(measured.width, 1), rect.height / max(height(selected), 1))
            size = max(6, size * factor)
        }
        return NSFont(descriptor: selected.fontDescriptor, size: size) ?? selected
    }
    static func rowHeight(_ role: String, fallback: CGFloat, availableHeight: CGFloat) -> CGFloat {
        let natural = height(GraphFonts.font(role, fallbackSize: fallback))
        return GraphFonts.autoFit ? min(natural, max(14, availableHeight * 0.23)) : natural
    }
}
