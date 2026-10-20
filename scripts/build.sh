#!/bin/bash
set -euo pipefail
export COPYFILE_DISABLE=1
cd "$(dirname "$0")/.."
bash scripts/setup_sparkle.sh
sparkle_root="$PWD/.build/deps/Sparkle-2.9.2"
staging_app="$PWD/.build/staging/NetMeter.app"
mkdir -p .build/module-cache "$staging_app/Contents/MacOS" "$staging_app/Contents/Resources" "$staging_app/Contents/Frameworks"
sdk_path="${NETMETER_SDK_PATH:-$(xcrun --sdk macosx --show-sdk-path)}"
if [[ ! -f Resources/AppIcon.icns || scripts/generate_icon.swift -nt Resources/AppIcon.icns ]]; then
  swiftc -sdk "$sdk_path" -module-cache-path .build/module-cache scripts/generate_icon.swift -o .build/generate_icon
  .build/generate_icon
  python3 - <<'PY'
from pathlib import Path
for path in Path('.build/NetMeter.iconset').glob('._*'):
    path.unlink()
PY
  iconutil -c icns .build/NetMeter.iconset -o Resources/AppIcon.icns
fi
sources=()
while IFS= read -r source; do sources+=("$source"); done < <(find Sources/NetMeter -name '*.swift' ! -name '._*' | sort)
extra_flags=()
if [[ "${1:-}" == "--probe" ]]; then
  sources+=(Tests/RuntimeDiagnostics.swift)
  extra_flags+=(-D DIAGNOSTICS)
fi
architectures=(arm64 x86_64)
if [[ "${NETMETER_ARCH:-universal}" != "universal" ]]; then architectures=("$NETMETER_ARCH"); fi
binaries=()
for architecture in "${architectures[@]}"; do
  [[ "$architecture" == arm64 || "$architecture" == x86_64 ]] || { echo 'Unsupported architecture' >&2; exit 1; }
  binary="$PWD/.build/NetMeter-$architecture"
  swiftc -sdk "$sdk_path" \
    -target "$architecture-apple-macos13.0" -module-cache-path .build/module-cache -O \
    -F "$sparkle_root" -framework Sparkle \
    -Xlinker -rpath -Xlinker @executable_path/../Frameworks \
    "${extra_flags[@]}" "${sources[@]}" -o "$binary"
  binaries+=("$binary")
done
lipo -create "${binaries[@]}" -output "$staging_app/Contents/MacOS/NetMeter"
python3 scripts/build_info.py "$staging_app/Contents/Info.plist"
for language in Resources/Localization/*.lproj; do
  python3 scripts/copy_bundle.py "$language" "$staging_app/Contents/Resources/$(basename "$language")"
done
if [[ -f Resources/AppIcon.icns ]]; then cp Resources/AppIcon.icns "$staging_app/Contents/Resources/AppIcon.icns"; fi
python3 scripts/copy_bundle.py "$sparkle_root/Sparkle.framework" "$staging_app/Contents/Frameworks/Sparkle.framework"
cp "$sparkle_root/LICENSE" "$staging_app/Contents/Resources/Sparkle-LICENSE.txt"
# The workspace may be on exFAT; AppleDouble files are metadata, not bundles.
python3 - "$staging_app" <<'PY'
from pathlib import Path
import sys
for path in Path(sys.argv[1]).rglob('._*'):
    if path.is_file():
        path.unlink()
PY
codesign --force --sign - "$staging_app"
codesign --verify --deep --strict "$staging_app"
if [[ "${1:-}" == "--probe" ]]; then
  "$staging_app/Contents/MacOS/NetMeter" --probe
elif [[ "${1:-}" != "--no-install" ]]; then
  python3 scripts/copy_bundle.py "$staging_app" NetMeter.app
fi
