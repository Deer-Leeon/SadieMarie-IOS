#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ ! -d "PeriodTracker.xcodeproj" ]]; then
  echo "Project not found: PeriodTracker.xcodeproj"
  exit 1
fi

echo "==> Running quality gates"
bash scripts/quality_gates.sh

echo "==> Running Debug build smoke check"
bash scripts/run_debug_build.sh >/tmp/periodtracker-debug-build.log

echo "==> Running Release build smoke check"
bash scripts/run_release_build.sh >/tmp/periodtracker-release-build.log

echo "==> Quick architecture signals"
echo "Top large screens:"
wc -l PeriodTracker/Screens/*.swift | sort -nr | head -n 8
echo
echo "No. of print(...) debug statements:"
rg -n '\bprint\(' PeriodTracker -S | wc -l | tr -d ' '
echo
echo "Test directories:"
find . -maxdepth 4 -type d | grep -Ei 'Tests|UITests' || echo "None detected"

echo
echo "Build logs:"
echo "  /tmp/periodtracker-debug-build.log"
echo "  /tmp/periodtracker-release-build.log"
echo
echo "Next: run manual smoke matrix"
echo "  docs/enterprise-refactor/PHASE2_SMOKE_MATRIX.md"
