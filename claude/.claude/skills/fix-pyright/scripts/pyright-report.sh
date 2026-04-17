#!/usr/bin/env bash
# Run pyright on a target path and emit the JSON diagnostics on stdout.
#
# Usage: pyright-report.sh <path>
#
# Exit codes:
#   0  — pyright ran successfully (errors or no errors; JSON is on stdout)
#   2  — tooling failure: pyright missing, bad target, or non-standard pyright exit
#
# pyright's normal exit codes are 0 (clean) or 1 (errors found). Anything else
# (2 = config/fatal, 3 = invalid args) is treated as a tooling failure.

set -uo pipefail

TARGET="${1:-}"

if [[ -z "$TARGET" ]]; then
  echo "usage: $(basename "$0") <path>" >&2
  exit 2
fi

if ! command -v pyright >/dev/null 2>&1; then
  echo "pyright not on PATH. Install with: npm install -g pyright" >&2
  exit 2
fi

if [[ ! -e "$TARGET" ]]; then
  echo "Target does not exist: $TARGET" >&2
  exit 2
fi

pyright --outputjson "$TARGET"
rc=$?

if (( rc > 1 )); then
  echo "pyright invocation failed (exit $rc)" >&2
  exit 2
fi

exit 0
