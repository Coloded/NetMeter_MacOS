import AppKit

final class WindowDocking: NSObject, NSWindowDelegate {
    private(set) var windows: [String: NSPanel] = [:]
    private var buttons: [NSButton] = []
    private var links = UserDefaults.standard.array(forKey: "windowLinks") as? [[String]] ?? []
    private(set) var enabled = UserDefaults.standard.bool(forKey: "glueWindows")
    private var movingID: String?
    private var previousOrigin = NSPoint.zero
    private var applying = false
    private var endTimer: Timer?
    var onClose: ((String) -> Void)?

    func register(_ window: NSPanel, id: String) {
        windows[id] = window
        window.delegate = self
        let accessory = NSTitlebarAccessoryViewController()
        let button = NSButton(checkboxWithTitle: L("window.snap"), target: self, action: #selector(toggle))
        button.font = .systemFont(ofSize: 10)
        button.frame = NSRect(x: 0, y: 0, width: 78, height: 22)
        button.state = enabled ? .on : .off
        button.toolTip = L("window.snap_hint")
        accessory.view = button
        accessory.layoutAttribute = .right
        window.addTitlebarAccessoryViewController(accessory)
        buttons.append(button)
    }

    @objc func toggle() {
        enabled.toggle()
        if !enabled { links = [] }
        buttons.forEach { $0.state = enabled ? .on : .off }
        save()
    }

    func localizeButtons() {
        for button in buttons {
            button.title = L("window.snap")
            button.toolTip = L("window.snap_hint")
            button.userInterfaceLayoutDirection = L10n.direction
        }
    }

    @objc func separateAll() {
        links = []
        save()
    }

    func separate(_ id: String) {
        links.removeAll { $0.contains(id) }
        save()
    }

    private func id(for window: NSWindow) -> String? { windows.first { $0.value === window }?.key }

    private func group(_ id: String) -> Set<String> {
        var result: Set<String> = [id]
        var changed = true
        while changed {
            changed = false
            for link in links where link.count == 2 && !result.isDisjoint(with: link) {
                for member in link where windows[member]?.isVisible == true {
                    if result.insert(member).inserted { changed = true }
                }
            }
        }
        return result
    }

    func windowWillMove(_ notification: Notification) {
        guard !applying, let window = notification.object as? NSWindow, let id = id(for: window) else { return }
        if NSEvent.modifierFlags.contains(.option) {
            links.removeAll { $0.contains(id) }
            save()
        }
        movingID = id
        previousOrigin = window.frame.origin
    }

    func windowDidMove(_ notification: Notification) {
        guard !applying, let window = notification.object as? NSWindow,
              let id = id(for: window), id == movingID else { return }
        let delta = NSPoint(x: window.frame.minX - previousOrigin.x, y: window.frame.minY - previousOrigin.y)
        previousOrigin = window.frame.origin
        if enabled {
            applying = true
            for member in group(id) where member != id {
                guard let other = windows[member] else { continue }
                other.setFrameOrigin(NSPoint(x: other.frame.minX + delta.x, y: other.frame.minY + delta.y))
            }
            applying = false
        }
        scheduleEnd()
    }

    private func scheduleEnd() {
        endTimer?.invalidate()
        let timer = Timer(timeInterval: 0.12, repeats: false) { [weak self] _ in self?.finishMove() }
        endTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func finishMove() {
        if NSEvent.pressedMouseButtons & 1 != 0 { scheduleEnd(); return }
        guard let id = movingID else { return }
        if enabled && !NSEvent.modifierFlags.contains(.option) { snap(id) }
        movingID = nil
        save()
    }

    // The returned translation joins one pair of outer edges, preserving the
    // perpendicular offset unless their corners are already near each other.
    static func snapOffset(_ a: NSRect, _ b: NSRect, threshold: CGFloat = 18) -> NSPoint? {
        var choices: [NSPoint] = []
        if min(a.maxY, b.maxY) - max(a.minY, b.minY) > 25 {
            let alignY = [b.minY - a.minY, b.maxY - a.maxY].min { abs($0) < abs($1) } ?? 0
            for dx in [b.minX - a.maxX, b.maxX - a.minX] where abs(dx) <= threshold {
                choices.append(NSPoint(x: dx, y: abs(alignY) <= threshold ? alignY : 0))
            }
        }
        if min(a.maxX, b.maxX) - max(a.minX, b.minX) > 25 {
            let alignX = [b.minX - a.minX, b.maxX - a.maxX].min { abs($0) < abs($1) } ?? 0
            for dy in [b.minY - a.maxY, b.maxY - a.minY] where abs(dy) <= threshold {
                choices.append(NSPoint(x: abs(alignX) <= threshold ? alignX : 0, y: dy))
            }
        }
        return choices.min { hypot($0.x, $0.y) < hypot($1.x, $1.y) }
    }

    private func snap(_ id: String) {
        let members = group(id)
        var best: (String, String, NSPoint)?
        for member in members {
            guard let window = windows[member] else { continue }
            for (targetID, target) in windows where target.isVisible && !members.contains(targetID) {
                guard let offset = Self.snapOffset(window.frame, target.frame) else { continue }
                // Do not pull a third window through an unrelated window.
                let collision = members.contains { moving in
                    guard let frame = windows[moving]?.frame else { return false }
                    let moved = frame.offsetBy(dx: offset.x, dy: offset.y).insetBy(dx: 1, dy: 1)
                    return windows.contains { key, value in
                        !members.contains(key) && value.isVisible && moved.intersects(value.frame.insetBy(dx: 1, dy: 1))
                    }
                }
                if collision { continue }
                if best == nil || hypot(offset.x, offset.y) < hypot(best!.2.x, best!.2.y) {
                    best = (member, targetID, offset)
                }
            }
        }
        guard let best else { return }
        applying = true
        for member in members {
            guard let window = windows[member] else { continue }
            window.setFrameOrigin(NSPoint(x: window.frame.minX + best.2.x, y: window.frame.minY + best.2.y))
        }
        applying = false
        links.append([best.0, best.1])
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, let id = id(for: window) else { return }
        save()
        onClose?(id)
    }

    private func save() {
        UserDefaults.standard.set(links, forKey: "windowLinks")
        UserDefaults.standard.set(enabled, forKey: "glueWindows")
        for (id, window) in windows {
            window.saveFrame(usingName: id == "network" ? "TrafficGraphWindow" : "ResourceWindow-\(id)")
        }
    }
}
