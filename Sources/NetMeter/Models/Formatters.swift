import Foundation

func formatRate(_ bytesPerSecond: Double) -> String {
    let units = ["B/s", "KB/s", "MB/s", "GB/s"]
    var value = max(0, bytesPerSecond)
    var index = 0
    while value >= 1024 && index < units.count - 1 { value /= 1024; index += 1 }
    return String(format: value >= 100 || index == 0 ? "%.0f %@" : "%.1f %@", value, units[index])
}

