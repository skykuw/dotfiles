#!/usr/bin/env bash
# Verify a batch of edited files didn't regress pyright errors.
#
# One pyright invocation per batch instead of one per file — cuts startup
# overhead on multi-file batches.
#
# Usage:
#   echo -e "5\tfoo.py\n3\tbar.py" | verify-batch.sh
#
# Stdin: TSV rows of `<baseline_error_count>\t<file>`. Pass absolute paths
#        (matching triage-report.sh's `file` column) to avoid path-matching
#        headaches between input and pyright's JSON output.
#
# Stdout: TSV rows of `<status>\t<file>`, one per input row:
#   ok        — current error count <= baseline; keep the edits
#   regress   — current > baseline; caller should `git checkout HEAD -- <file>`
#   tool-fail — per-file count unavailable or non-numeric baseline
#
# Exit codes:
#   0 — batch ran; per-file statuses on stdout
#   2 — batch-level tooling failure (pyright/jq missing, pyright crashed,
#       or jq couldn't parse pyright's output)

set -uo pipefail

for cmd in pyright jq; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "$cmd not on PATH" >&2
    exit 2
  fi
done

BASELINES=()
FILES=()
while IFS=$'\t' read -r base file; do
  [[ -z "${file:-}" ]] && continue
  BASELINES+=("$base")
  FILES+=("$file")
done

if (( ${#FILES[@]} == 0 )); then
  echo "no input on stdin" >&2
  exit 2
fi

OUT="$(pyright --outputjson "${FILES[@]}")"
rc=$?
if (( rc > 1 )); then
  echo "pyright invocation failed (exit $rc)" >&2
  exit 2
fi

if ! COUNTS="$(printf '%s' "$OUT" | jq -r '
  [ (.generalDiagnostics // [])[] | select(.severity=="error") | .file ]
  | group_by(.) | map({key: .[0], value: length}) | from_entries
  | to_entries[] | "\(.value)\t\(.key)"
')"; then
  echo "jq failed to parse pyright output" >&2
  exit 2
fi

for i in "${!FILES[@]}"; do
  f="${FILES[$i]}"
  base="${BASELINES[$i]}"
  cur="$(printf '%s\n' "$COUNTS" | awk -F'\t' -v f="$f" '$2==f {print $1; exit}')"
  cur="${cur:-0}"
  if [[ ! "$cur" =~ ^[0-9]+$ ]] || [[ ! "$base" =~ ^[0-9]+$ ]]; then
    printf 'tool-fail\t%s\n' "$f"
    continue
  fi
  if (( cur <= base )); then
    printf 'ok\t%s\n' "$f"
  else
    printf 'regress\t%s\n' "$f"
  fi
done
