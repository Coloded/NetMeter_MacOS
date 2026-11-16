#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
qa_root="$PWD/.build/qa/collector"
mkdir -p "$qa_root/module-cache"
swiftc -sdk "$(xcrun --sdk macosx --show-sdk-path)" -module-cache-path "$qa_root/module-cache" \
 Sources/NetMeter/Models/NetworkSample.swift Sources/NetMeter/Models/NetworkRateTracker.swift \
 Sources/NetMeter/Models/ResourceReading.swift Sources/NetMeter/Monitoring/MetricsCollector.swift \
 Tests/CollectorTests.swift -o "$qa_root/CollectorTests"
"$qa_root/CollectorTests"
