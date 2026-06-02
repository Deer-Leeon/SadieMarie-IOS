#!/usr/bin/env bash
set -euo pipefail

available_devices="$(xcrun simctl list devices available)"

preferred_names=(
  "iPhone 17 Pro"
  "iPhone 17"
  "iPhone 16 Pro"
  "iPhone 16"
  "iPhone 15 Pro"
  "iPhone 15"
)

for name in "${preferred_names[@]}"; do
  if printf '%s\n' "$available_devices" | rg -q "${name} \\("; then
    echo "platform=iOS Simulator,name=${name}"
    exit 0
  fi
done

echo "No supported iOS simulator device found for CI tests." >&2
exit 1
