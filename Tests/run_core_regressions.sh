#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
qa_root="${NETMETER_QA_ROOT:-$PWD/.build/qa/core}"
mkdir -p "$qa_root/module-cache"
sdk_path="$(xcrun --sdk macosx --show-sdk-path)"
swiftc -sdk "$sdk_path" -module-cache-path "$qa_root/module-cache" -D MODEL_TEST_STUB_LOGGER \
  Sources/NetMeter/Models/NetworkSample.swift \
  Sources/NetMeter/Models/Formatters.swift \
  Sources/NetMeter/Models/NetworkRateTracker.swift \
  Sources/NetMeter/Settings/SettingsStore.swift Tests/CoreRegressionTests.swift \
  -o "$qa_root/CoreRegressionTests"
"$qa_root/CoreRegressionTests"
