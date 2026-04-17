#!/usr/bin/env bash
# Verify that a subagent's edits didn't regress pyright errors on a single file.
#
# Usage: verify.sh <file> <baseline_error_count>
#
# Re-runs pyright on just the target file and compares the current error count
# to the baseline. No set comparison — a cross-file regression is caught by the
# whole-package sanity check at the end of the run.
#
# Exit codes:
#   0 — current error count <= baseline (accept the edits)
#   1 — current error count >  baseline (reject; orchestrator should rollback)
#   2 — tooling failure: pyright or jq missing, or pyright returned non-standard exit

set -uo pipefail

FILE="${1:-}"
BASELINE="${2:-}"

if [[ -z "$FILE" || -z "$BASELINE" ]]; then
  echo "usage: $(basename "$0") <file> <baseline_error_count>" >&2
  exit 2
fi

if ! command -v pyright >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
  echo "pyright and jq must be on PATH" >&2
  exit 2
fi

if [[ ! -f "$FILE" ]]; then
  echo "File not found: $FILE" >&2
  exit 2
fi

OUT="$(pyright --outputjson "$FILE")"
rc=$?
if (( rc > 1 )); then
  echo "pyright invocation failed (exit $rc)" >&2
  exit 2
fi

COUNT="$(printf '%s' "$OUT" | jq '[.generalDiagnostics[]? | select(.severity=="error")] | length' 2>/dev/null)"
COUNT="${COUNT:-0}"

if [[ ! "$COUNT" =~ ^[0-9]+$ ]] || [[ ! "$BASELINE" =~ ^[0-9]+$ ]]; then
  echo "Non-numeric count: current=$COUNT baseline=$BASELINE" >&2
  exit 2
fi

if (( COUNT <= BASELINE )); then
  echo "OK: $FILE errors $BASELINE -> $COUNT"
  exit 0
else
  echo "REGRESSION: $FILE errors $BASELINE -> $COUNT"
  exit 1
fi
