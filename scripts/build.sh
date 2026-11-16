#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
exec python3 scripts/build_lock.py "$PWD/.build/build.lock" /bin/bash "$PWD/scripts/build_app.sh" "$@"
