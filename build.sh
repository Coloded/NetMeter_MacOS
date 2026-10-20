#!/bin/bash
set -euo pipefail
exec bash "$(dirname "$0")/scripts/build.sh" "$@"
