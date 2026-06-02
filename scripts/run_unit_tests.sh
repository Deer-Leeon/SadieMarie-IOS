#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PROJECT="SadieMarie.xcodeproj"
SCHEME="SadieMarieTests"
DESTINATION="${DESTINATION:-platform=iOS Simulator,name=iPhone 16}"

xcodebuild test \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  -only-testing:SadieMarieTests \
  | xcpretty || true
