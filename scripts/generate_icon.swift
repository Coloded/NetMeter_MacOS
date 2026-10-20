import AppKit

// Vector source: Resources/Branding/logo.svg. Render every icon size directly.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconset = root.appendingPathComponent(".build/NetMeter.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func render(_ size: Int) -> Data {
    let image = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                                 bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                 isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: image)
    let transform = NSAffineTransform()
    transform.scale(by: CGFloat(size) / 1024)
    transform.concat()
    let shape = NSBezierPath(roundedRect: NSRect(x: 64, y: 64, width: 896, height: 896), xRadius: 210, yRadius: 210)
    let top = NSColor(calibratedRed: 36/255, green: 52/255, blue: 77/255, alpha: 1)
    let bottom = NSColor(calibratedRed: 16/255, green: 23/255, blue: 34/255, alpha: 1)
    NSGradient(starting: bottom, ending: top)!.draw(in: shape, angle: 90)
    NSColor.white.withAlphaComponent(0.08).setStroke()
    for y in [306, 444, 582, 720] {
        let line = NSBezierPath()
        line.lineWidth = 4
        line.move(to: NSPoint(x: 196, y: y)); line.line(to: NSPoint(x: 828, y: y)); line.stroke()
    }
    let colors = [NSColor(calibratedRed: 50/255, green: 182/255, blue: 1, alpha: 1),
                  NSColor(calibratedRed: 68/255, green: 226/255, blue: 153/255, alpha: 1)]
    let graphs = [[NSPoint(x: 208, y: 650), NSPoint(x: 330, y: 650), NSPoint(x: 445, y: 450), NSPoint(x: 560, y: 550), NSPoint(x: 680, y: 340), NSPoint(x: 816, y: 340)],
                  [NSPoint(x: 208, y: 360), NSPoint(x: 340, y: 360), NSPoint(x: 440, y: 500), NSPoint(x: 560, y: 390), NSPoint(x: 680, y: 590), NSPoint(x: 816, y: 590)]]
    for (index, points) in graphs.enumerated() {
        let path = NSBezierPath()
        path.lineWidth = 46; path.lineCapStyle = .round; path.lineJoinStyle = .round
        path.move(to: points[0]); points.dropFirst().forEach { path.line(to: $0) }
        colors[index].setStroke(); path.stroke()
    }
    NSGraphicsContext.restoreGraphicsState()
    return image.representation(using: .png, properties: [:])!
}

for size in [16, 32, 128, 256, 512] {
    try render(size).write(to: iconset.appendingPathComponent("icon_\(size)x\(size).png"))
    try render(size * 2).write(to: iconset.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
try render(512).write(to: root.appendingPathComponent("Resources/Branding/icon.png"))
