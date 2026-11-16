#!/usr/bin/env python3
"""Read-only live memory probe: actual production methods, no application launch."""
from pathlib import Path
import subprocess
ROOT = Path(__file__).resolve().parents[1]
qa = ROOT / '.build/qa/memory'
(qa / 'module-cache').mkdir(parents=True, exist_ok=True)
source = (ROOT / 'Sources/NetMeter/Monitoring/SystemMetrics.swift').read_text()
def method(name):
    start = source.index(name)
    brace = source.index('{', start)
    depth = 1
    end = brace + 1
    while depth:
        depth += (source[end] == '{') - (source[end] == '}')
        end += 1
    return source[start:end]
fixture = '''import Foundation
import Darwin
func L(_ key: String, _ values: CVarArg...) -> String {
 if key == "memory.details" { return String(format: "%@|%@", arguments: values) }
 return key
}
enum L10n { static func text(_ key: String) -> String { key } }
final class Probe {
'''+method('func memory()')+'\n'+method('private func memoryDetails()')+'''
}
@main struct Main {
 static func main() {
  guard let reading = Probe().memory() else { fatalError("host memory probe unavailable") }
  precondition(reading.first.isFinite && (0...100).contains(reading.first))
  precondition(reading.footer.contains("GiB"))
  var level: Int32 = 0; var size = MemoryLayout<Int32>.size
  let status = sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &size, nil, 0)
  let expected = status != 0 ? "metric.unavailable" : level == 1 ? "memory.normal" : level == 2 ? "memory.warning" : level == 4 ? "memory.critical" : "metric.unavailable"
  precondition(reading.details.hasSuffix("|" + expected))
  precondition(reading.details.contains("GiB|") || reading.details.hasPrefix("metric.unavailable|"))
  print("PASS: 4 live memory assertions: percent range, GiB, swap availability and independent kernel pressure=\\(expected)")
 }
}
'''
(qa/'MemoryProbe.swift').write_text(fixture)
sdk=subprocess.check_output(['xcrun','--sdk','macosx','--show-sdk-path'],text=True).strip()
subprocess.run(['swiftc','-sdk',sdk,'-module-cache-path',str(qa/'module-cache'),str(ROOT/'Sources/NetMeter/Models/ResourceReading.swift'),str(qa/'MemoryProbe.swift'),'-o',str(qa/'MemoryProbe')],check=True,timeout=120)
subprocess.run([str(qa/'MemoryProbe')],check=True,timeout=10)
