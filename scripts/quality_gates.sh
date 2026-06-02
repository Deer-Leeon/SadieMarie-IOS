#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> Debug build"
bash scripts/run_debug_build.sh

echo "==> Unit tests"
bash scripts/run_unit_tests.sh

echo "Quality gates passed."
