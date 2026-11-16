import AppKit
// Draw-only dependencies are stubbed; tested fittedFont/height are production methods.
enum GraphFonts {
 static func font(_ role: String, fallbackSize: CGFloat) -> NSFont { .systemFont(ofSize: fallbackSize) }
 static let autoFit = true
}
enum L10n { static let direction: NSUserInterfaceLayoutDirection = .leftToRight }
@main struct GraphTextLayoutTests {
 static var checks = 0
 static func check(_ value: Bool, _ message: String) { checks += 1; guard value else { fatalError(message) } }
 static func main() {
  for text in ["Ethernet (en0) · 1 Gbit/s · max. 117 MiB/s", "Память · занято / всего", "الذاكرة المستخدمة / الإجمالي", "内存 · 已用 / 总计"] {
   for size: CGFloat in [6, 12, 48] {
    let selected = NSFont.systemFont(ofSize: size)
    let rect = NSRect(x: 0, y: 0, width: 480, height: 30)
    let font = GraphTextLayout.fittedFont(text: text, rect: rect, selected: selected, autoFit: true)
    check(font.pointSize >= 6 && font.pointSize <= size, "autofit bounds")
    let measured = (text as NSString).size(withAttributes: [.font: font])
    check(measured.width <= rect.width + 1, "width fits for reasonable rectangle")
    check(GraphTextLayout.height(font) <= rect.height + 2, "height fits for reasonable rectangle")
    let fixed = GraphTextLayout.fittedFont(text: text, rect: rect, selected: selected, autoFit: false)
    check(fixed.pointSize == size, "disabled fit preserves font")
    let tiny = GraphTextLayout.fittedFont(text: text, rect: NSRect(x: 0, y: 0, width: 2, height: 2), selected: selected, autoFit: true)
    check(tiny.pointSize == 6, "tiny rectangle preserves documented truncation minimum")
   }
  }
  print("PASS: \(checks) text layout assertions; four scripts, 6/12/48pt, width/height/minimum policy")
 }
}
