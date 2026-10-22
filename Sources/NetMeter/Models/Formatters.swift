import Foundation

let rateUnitChoices: [(String, String)] = [
    ("auto_binary", "units.auto_binary"), ("auto_decimal", "units.auto_decimal"), ("auto_bits", "units.auto_bits"),
    ("bit/s", "bit/s"), ("kbit/s", "kbit/s"), ("Mbit/s", "Mbit/s"), ("Gbit/s", "Gbit/s"),
    ("B/s", "B/s"), ("KB/s", "KB/s"), ("MB/s", "MB/s"), ("GB/s", "GB/s"),
    ("KiB/s", "KiB/s"), ("MiB/s", "MiB/s"), ("GiB/s", "GiB/s")
]

func formatRate(_ bytesPerSecond: Double, unit: String? = nil) -> String {
    let preference = unit ?? UserDefaults.standard.string(forKey: "rateUnit") ?? "auto_binary"
    let binary = ["auto_binary", "KiB/s", "MiB/s", "GiB/s"].contains(preference)
    let bits = preference == "auto_bits" || preference.contains("bit/s")
    let units = bits ? ["bit/s", "kbit/s", "Mbit/s", "Gbit/s"] : binary ? ["B/s", "KiB/s", "MiB/s", "GiB/s"] : ["B/s", "KB/s", "MB/s", "GB/s"]
    let base = binary ? 1024.0 : 1000.0
    var value = max(0, bytesPerSecond.isFinite ? bytesPerSecond : 0) * (bits ? 8 : 1)
    var index = 0
    if let fixed = units.firstIndex(of: preference) {
        index = fixed
        value /= pow(base, Double(index))
    } else {
        while value >= base && index < units.count - 1 { value /= base; index += 1 }
    }
    return String(format: index == 0 ? "%.0f %@" : value >= 100 ? "%.0f %@" : value >= 1 ? "%.1f %@" : "%.3f %@", value, units[index])
}

func formatByteCount(_ bytes: Double, unit: String? = nil) -> String {
    formatRate(bytes, unit: unit ?? UserDefaults.standard.string(forKey: "totalUnit") ?? "auto_binary").replacingOccurrences(of: "/s", with: "")
}
