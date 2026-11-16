#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
qa_root="${NETMETER_QA_ROOT:-$PWD/.build/qa/command}"
mkdir -p "$qa_root/module-cache"
swiftc -sdk "$(xcrun --sdk macosx --show-sdk-path)" -module-cache-path "$qa_root/module-cache" \
  Sources/NetMeter/Monitoring/BoundedCommand.swift Tests/BoundedCommandTests.swift -o "$qa_root/BoundedCommandTests"
"$qa_root/BoundedCommandTests"
