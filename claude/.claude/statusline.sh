#!/usr/bin/env bash
# Claude Code status line.
#
# Reads session JSON on stdin (schema: https://code.claude.com/docs/en/statusline#available-data)
# and prints TWO lines:
#   line 1 — identity:   [profile] model  git-branch*  $cost  elapsed
#   line 2 — pressure:   ctx used/max pct%  cache m:ss  5h pct%  7d pct%
# Runs locally, consumes no tokens.
#
# Args:
#   $1  profile name baked in by each settings template (e.g. "personal",
#       "work/polaris"). Drives the tag color. Defaults to "unknown".

set -uo pipefail

PROFILE="${1:-unknown}"
STATE_FILE="$HOME/.claude/.statusline_state"
CACHE_TTL_S=300   # Anthropic default prompt-cache TTL (5 min)

BOLD=$'\033[1m'
DIM=$'\033[2m'
RESET=$'\033[0m'
GREEN=$'\033[1;32m'
YELLOW=$'\033[1;33m'
RED=$'\033[1;31m'

case "$PROFILE" in
  personal) TAG_COLOR="$GREEN" ;;
  work/*)   TAG_COLOR="$YELLOW" ;;
  *)        TAG_COLOR="$BOLD" ;;
esac

if ! command -v jq >/dev/null 2>&1; then
  printf '%s[%s]%s  %s(install jq for cost/context)%s' \
    "$TAG_COLOR" "$PROFILE" "$RESET" "$DIM" "$RESET"
  exit 0
fi

INPUT="$(cat)"

# Single jq pass → TSV → bash read. IFS=$'\t' keeps model display names with
# spaces intact.
IFS=$'\t' read -r \
  SESSION_ID MODEL CWD PCT USED MAX COST DUR_MS API_DUR_MS RL5 RL7 \
  <<<"$(jq -r '[
    .session_id // "",
    .model.display_name // "?",
    .workspace.current_dir // .cwd // "",
    (.context_window.used_percentage // 0),
    ((.context_window.total_input_tokens // 0) + (.context_window.total_output_tokens // 0)),
    (.context_window.context_window_size // 200000),
    (.cost.total_cost_usd // 0),
    (.cost.total_duration_ms // 0),
    (.cost.total_api_duration_ms // 0),
    (.rate_limits.five_hour.used_percentage // 0),
    (.rate_limits.seven_day.used_percentage // 0)
  ] | @tsv' <<<"$INPUT" 2>/dev/null
)"

PCT="${PCT%%.*}"; PCT="${PCT:-0}"
USED="${USED%%.*}"; USED="${USED:-0}"
MAX="${MAX%%.*}"; MAX="${MAX:-200000}"
DUR_MS="${DUR_MS%%.*}"; DUR_MS="${DUR_MS:-0}"
API_DUR_MS="${API_DUR_MS%%.*}"; API_DUR_MS="${API_DUR_MS:-0}"
RL5="${RL5%%.*}"; RL5="${RL5:-0}"
RL7="${RL7%%.*}"; RL7="${RL7:-0}"
MODEL="${MODEL:-?}"
COST="${COST:-0}"

# --- Cache TTL tracking ------------------------------------------------------
# refreshInterval re-runs us every N seconds during idle. We must distinguish
# a refresh tick from a real API call so the countdown only resets when the
# cache was actually refreshed. total_api_duration_ms is monotonic across API
# calls within a session — when it changes, a new API call happened.

NOW=$(date +%s)
PREV_SESSION=""; PREV_API_DUR=-1; PREV_TS="$NOW"
if [[ -r "$STATE_FILE" ]]; then
  read -r PREV_SESSION PREV_API_DUR PREV_TS < "$STATE_FILE" || true
fi

if [[ "$SESSION_ID" != "$PREV_SESSION" ]] || [[ "$API_DUR_MS" != "$PREV_API_DUR" ]]; then
  LAST_API_TS="$NOW"
  printf '%s %s %s\n' "$SESSION_ID" "$API_DUR_MS" "$NOW" >"$STATE_FILE" 2>/dev/null || true
else
  LAST_API_TS="$PREV_TS"
fi

REMAINING=$((CACHE_TTL_S - (NOW - LAST_API_TS)))
if (( REMAINING > 60 )); then
  CACHE_COLOR="$DIM"
  CACHE_STR=$(printf '%d:%02d' $((REMAINING / 60)) $((REMAINING % 60)))
elif (( REMAINING > 0 )); then
  CACHE_COLOR="$YELLOW"
  CACHE_STR=$(printf '%d:%02d' $((REMAINING / 60)) $((REMAINING % 60)))
else
  CACHE_COLOR="$RED"
  CACHE_STR="cold"
fi

# --- Git branch + dirty ------------------------------------------------------
# --no-optional-locks skips the index refresh, making this fast and safe to
# run alongside user git operations. Silent when cwd isn't inside a repo.
GIT_STR=""
if [[ -n "$CWD" ]] && git -C "$CWD" --no-optional-locks rev-parse --git-dir >/dev/null 2>&1; then
  BRANCH=$(git -C "$CWD" --no-optional-locks symbolic-ref --short -q HEAD 2>/dev/null \
       || git -C "$CWD" --no-optional-locks rev-parse --short HEAD 2>/dev/null \
       || true)
  if [[ -n "$BRANCH" ]]; then
    DIRTY=""
    if [[ -n "$(git -C "$CWD" --no-optional-locks status --porcelain 2>/dev/null | head -c1)" ]]; then
      DIRTY="*"
      GIT_STR="${YELLOW}${BRANCH}${DIRTY}${RESET}"
    else
      GIT_STR="${DIM}${BRANCH}${RESET}"
    fi
  fi
fi

# --- Pressure colors ---------------------------------------------------------
if   (( PCT >= 80 )); then CTX_COLOR="$RED"
elif (( PCT >= 50 )); then CTX_COLOR="$YELLOW"
else                       CTX_COLOR="$DIM"
fi

rl_color() {
  local v="$1"
  if   (( v >= 80 )); then printf '%s' "$RED"
  elif (( v >= 50 )); then printf '%s' "$YELLOW"
  else                     printf '%s' "$DIM"
  fi
}
RL5_COLOR=$(rl_color "$RL5")
RL7_COLOR=$(rl_color "$RL7")

# --- Humanize ----------------------------------------------------------------
human_k() {
  awk -v n="$1" 'BEGIN{
    if (n+0 < 1000)         printf "%d",    n
    else if (n+0 < 1000000) printf "%.1fk", n/1000
    else                    printf "%.1fM", n/1000000
  }'
}
USED_H=$(human_k "$USED")
MAX_H=$(human_k "$MAX")

COST_H=$(awk -v c="$COST" 'BEGIN{ printf "$%.2f", c+0 }')

DUR_S=$((DUR_MS / 1000))
DUR_H=$(printf '%dm%02ds' $((DUR_S / 60)) $((DUR_S % 60)))

# --- Render ------------------------------------------------------------------
line1="${TAG_COLOR}[${PROFILE}]${RESET} ${MODEL}"
[[ -n "$GIT_STR" ]] && line1="${line1}  ${GIT_STR}"
line1="${line1}  ${DIM}${COST_H}  ${DUR_H}${RESET}"

line2="${CTX_COLOR}ctx ${USED_H}/${MAX_H} ${PCT}%${RESET}"
line2="${line2}  ${CACHE_COLOR}cache ${CACHE_STR}${RESET}"
line2="${line2}  ${RL5_COLOR}5h ${RL5}%${RESET}  ${RL7_COLOR}7d ${RL7}%${RESET}"

printf '%s\n%s' "$line1" "$line2"
