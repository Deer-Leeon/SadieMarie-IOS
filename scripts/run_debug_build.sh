#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DESTINATION="${DESTINATION:-generic/platform=iOS}"

xcodebuild \
  -project SadieMarie.xcodeproj \
  -scheme SadieMarie \
  -destination "$DESTINATION" \
  build
