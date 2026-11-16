#!/usr/bin/env python3
"""Live, read-only comparison of production counters() with bracketed netstat totals.

No traffic is generated. The production function body is compiled unchanged into a
small command-line executable; this does not launch or replace NetMeter.app.
"""
import argparse
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
QA = ROOT / ".build/qa/network-live"
QA.mkdir(parents=True, exist_ok=True)
(QA / "module-cache").mkdir(exist_ok=True)
source = (ROOT / "Sources/NetMeter/Monitoring/NetworkMonitor.swift").read_text()
start = source.index("func counters()")
end = source.index("\nfunc activeInterfaces()", start)
body = source[start:end]
program = "import Foundation\nimport Darwin\n" + body + r'''
let values = counters().mapValues { ["received": $0.received, "sent": $0.sent] }
let data = try JSONSerialization.data(withJSONObject: values, options: [.sortedKeys])
print(String(data: data, encoding: .utf8)!)
'''
(QA / "main.swift").write_text(program)
sdk = subprocess.check_output(["xcrun", "--sdk", "macosx", "--show-sdk-path"], text=True).strip()
subprocess.run(["swiftc", "-sdk", sdk, "-module-cache-path", str(QA / "module-cache"),
                str(QA / "main.swift"), "-o", str(QA / "network-live")], check=True)


def netstat():
    output = subprocess.check_output(["/usr/sbin/netstat", "-ibn"], text=True)
    readings = {}
    for line in output.splitlines():
        parts = line.split()
        if len(parts) >= 10 and parts[2].startswith("<Link#"):
            readings[parts[0]] = {"received": int(parts[6]), "sent": int(parts[9])}
    return readings


parser = argparse.ArgumentParser()
parser.add_argument("--interface", required=True, help="Actual active interface under test; never assume en0 on another Mac")
arguments = parser.parse_args()
before = netstat()
actual = json.loads(subprocess.check_output([str(QA / "network-live")], text=True))
after = netstat()
interfaces = sorted({arguments.interface} & actual.keys() & before.keys() & after.keys())
assert interfaces, "No comparable interface readings (check sysctl/netstat access)"
checked = 0
large = 0
for interface in interfaces:
    for direction in ("received", "sent"):
        low, value, high = before[interface][direction], actual[interface][direction], after[interface][direction]
        if high < low:
            print(f"SKIP: {interface} {direction} reset during comparison")
            continue
        assert low <= value <= high, f"{interface} {direction}: production={value} outside netstat [{low}, {high}]"
        checked += 1
        large += value > 2**32
        print(f"PASS: {interface} {direction}: {low} <= {value} <= {high}")
assert checked, "All live intervals reset"
print(f"PASS: {checked} live totals; {large} values exceed 2^32. Timing tolerance is the bracket, not a guessed percentage.")
