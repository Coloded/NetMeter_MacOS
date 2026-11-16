#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
qa_root="$PWD/.build/qa/layout"
mkdir -p "$qa_root/module-cache"
swiftc -sdk "$(xcrun --sdk macosx --show-sdk-path)" -module-cache-path "$qa_root/module-cache" \
 Sources/NetMeter/Graphs/GraphTextLayout.swift Tests/GraphTextLayoutTests.swift -o "$qa_root/GraphTextLayoutTests"
"$qa_root/GraphTextLayoutTests"
