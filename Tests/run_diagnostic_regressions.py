#!/usr/bin/env python3
"""Compile production diagnostic model without the interactive NSSavePanel extension."""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
qa = ROOT / ".build/qa/diagnostics"
(qa / "module-cache").mkdir(parents=True, exist_ok=True)
source = (ROOT / "Sources/NetMeter/Monitoring/DiagnosticCenter.swift").read_text()
(qa / "DiagnosticCenter.swift").write_text(source.split("\nextension AppDelegate", 1)[0])
sdk = subprocess.check_output(["xcrun", "--sdk", "macosx", "--show-sdk-path"], text=True).strip()
subprocess.run(["swiftc", "-sdk", sdk, "-module-cache-path", str(qa / "module-cache"),
                str(qa / "DiagnosticCenter.swift"), str(ROOT / "Sources/NetMeter/Settings/SettingsStore.swift"),
                str(ROOT / "Sources/NetMeter/Models/Formatters.swift"), str(ROOT / "Tests/DiagnosticTests.swift"),
                "-o", str(qa / "DiagnosticTests")], check=True)
subprocess.run([str(qa / "DiagnosticTests")], check=True)
