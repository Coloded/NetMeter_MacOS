import AppKit

extension AppDelegate {
    func updateStatusRates(_ sample: NetworkSample) {
        guard let button = statusItem.button else { return }
        let down = "↓ \(formatRate(sample.down))"
        let up = "↑ \(formatRate(sample.up))"
        let font = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .medium)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black]
        let width = ceil(max((down as NSString).size(withAttributes: attributes).width,
                             (up as NSString).size(withAttributes: attributes).width))
        let image = NSImage(size: NSSize(width: width, height: 22), flipped: false) { _ in
            (down as NSString).draw(at: NSPoint(x: 0, y: 11), withAttributes: attributes)
            (up as NSString).draw(at: NSPoint(x: 0, y: 0), withAttributes: attributes)
            return true
        }
        image.isTemplate = true
        button.title = ""
        button.image = image
        button.imagePosition = .imageOnly
        let defaults = UserDefaults.standard
        func total(_ bytes: Double) -> String { formatByteCount(bytes) }
        let details = [
            L("status.interface", NetworkDiscovery.displayName(selectedInterface)),
            L("status.download", formatRate(sample.down)),
            L("status.upload", formatRate(sample.up)),
            L("settings.session", total(Double(sessionDown)), total(Double(sessionUp))),
            L("settings.all_time", total(defaults.double(forKey: "totalDown")), total(defaults.double(forKey: "totalUp")))
        ].joined(separator: "\n")
        button.toolTip = details
        button.setAccessibilityLabel(details)
    }
}
