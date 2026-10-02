#!/bin/bash
set -euo pipefail
SCRIPT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
swift build --package-path "$SCRIPT_ROOT/native" -c release --jobs 6
python3 "$SCRIPT_ROOT/scripts/package-app.py"
