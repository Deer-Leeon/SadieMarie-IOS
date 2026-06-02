#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT_DIR/docs/enterprise-refactor"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT_FILE="$OUT_DIR/baseline-snapshot-$STAMP.md"

mkdir -p "$OUT_DIR"

cd "$ROOT_DIR"

BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")"
COMMIT="$(git rev-parse HEAD 2>/dev/null || echo "unknown")"
STATUS_COUNT="$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')"

{
  echo "# Baseline Snapshot"
  echo
  echo "- Timestamp: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
  echo "- Branch: \`$BRANCH\`"
  echo "- Commit: \`$COMMIT\`"
  echo "- Dirty file count: \`$STATUS_COUNT\`"
  echo
  echo "## Largest Screen Files"
  echo
  echo '```'
  if ls PeriodTracker/Screens/*.swift >/dev/null 2>&1; then
    wc -l PeriodTracker/Screens/*.swift | sort -nr | head -n 12
  else
    echo "No screen files found."
  fi
  echo '```'
  echo
  echo "## SyncManager Size"
  echo
  echo '```'
  wc -l PeriodTracker/Managers/SyncManager.swift 2>/dev/null || true
  echo '```'
  echo
  echo "## Test Targets/Folders"
  echo
  echo '```'
  find . -maxdepth 4 -type d | grep -Ei 'Tests|UITests' || echo "No test directories found."
  echo '```'
  echo
  echo "## Notes"
  echo
  echo "- This snapshot is used as a refactor checkpoint."
  echo "- Validate using docs/enterprise-refactor/PHASE2_SMOKE_MATRIX.md"
} > "$OUT_FILE"

echo "Baseline snapshot written to:"
echo "$OUT_FILE"

