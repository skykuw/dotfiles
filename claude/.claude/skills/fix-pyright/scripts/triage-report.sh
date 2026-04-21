#!/usr/bin/env bash
# Triage pyright errors for a target into per-error TSV rows.
#
# Usage: triage-report.sh <path> [--include-tests]
#
# Emits one TSV row per error:
#   <tier>\t<file>\t<line>\t<col>\t<rule>\t<message>
#
# tier is one of mechanical, ambiguous, escalate. The "skip" tier from
# triage.json is dropped silently. Unknown rules default to escalate so the
# orchestrator surfaces them instead of guessing.
#
# Test files (tests/**, test_*.py, *_test.py, conftest.py) are excluded
# unless --include-tests is passed.
#
# Exit codes:
#   0 — pyright ran; TSV on stdout (may be empty)
#   2 — tooling failure: pyright/jq missing, bad target, or non-standard exit

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TRIAGE_JSON="$SCRIPT_DIR/../triage.json"

TARGET="${1:-}"
INCLUDE_TESTS=0
if [[ "${2:-}" == "--include-tests" ]]; then
  INCLUDE_TESTS=1
fi

if [[ -z "$TARGET" ]]; then
  echo "usage: $(basename "$0") <path> [--include-tests]" >&2
  exit 2
fi

for cmd in pyright jq; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "$cmd not on PATH" >&2
    exit 2
  fi
done

if [[ ! -e "$TARGET" ]]; then
  echo "target does not exist: $TARGET" >&2
  exit 2
fi

if [[ ! -f "$TRIAGE_JSON" ]]; then
  echo "triage.json not found at $TRIAGE_JSON" >&2
  exit 2
fi

OUT="$(pyright --outputjson "$TARGET")"
rc=$?
if (( rc > 1 )); then
  echo "pyright invocation failed (exit $rc)" >&2
  exit 2
fi

printf '%s' "$OUT" | jq -r \
  --slurpfile triage "$TRIAGE_JSON" \
  --argjson include_tests "$INCLUDE_TESTS" \
  '
    ( $triage[0]
      | to_entries
      | map(select(.key | startswith("_") | not))
      | map(.key as $tier | .value | map({key: ., value: $tier}))
      | add // []
      | from_entries
    ) as $tiers
    | (.generalDiagnostics // [])[]
    | select(.severity == "error")
    | . as $d
    | ($d.rule // "") as $rule
    | ($tiers[$rule] // "escalate") as $tier
    | select($tier != "skip")
    | select(
        $include_tests == 1
        or ($d.file | test("(^|/)tests/|/test_[^/]*\\.py$|/[^/]*_test\\.py$|/conftest\\.py$") | not)
      )
    | [
        $tier,
        $d.file,
        (($d.range.start.line // 0) + 1),
        (($d.range.start.character // 0) + 1),
        $rule,
        (($d.message // "") | gsub("\t"; " ") | gsub("\n"; " "))
      ] | @tsv
  '
