#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
sparkle_version="$(python3 scripts/sparkle_config.py version)"
sparkle_sha="$(python3 scripts/sparkle_config.py sha256)"
sparkle_dir=".build/deps/Sparkle-$sparkle_version"
if [[ -d "$sparkle_dir/Sparkle.framework" && -x "$sparkle_dir/bin/generate_appcast" ]]; then
  codesign --verify --deep --strict "$sparkle_dir/Sparkle.framework"
  exit 0
fi
mkdir -p .build/deps
archive=".build/deps/Sparkle-$sparkle_version.tar.xz"
curl -fLsS --retry 2 --connect-timeout 20 \
  "https://github.com/sparkle-project/Sparkle/releases/download/$sparkle_version/Sparkle-$sparkle_version.tar.xz" \
  -o "$archive"
actual_sha=$(shasum -a 256 "$archive" | awk '{print $1}')
[[ "$actual_sha" == "$sparkle_sha" ]] || { echo 'Sparkle: неверная контрольная сумма.' >&2; exit 1; }
mkdir -p "$sparkle_dir"
tar -xJf "$archive" -C "$sparkle_dir"
codesign --verify --deep --strict "$sparkle_dir/Sparkle.framework"
