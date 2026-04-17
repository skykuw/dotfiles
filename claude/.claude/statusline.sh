#!/usr/bin/env bash
# Claude Code status line.
#
# Reads session JSON on stdin (schema: https://code.claude.com/docs/en/statusline#available-data)
# and prints TWO lines:
#   line 1 — identity:   [profile] model  git-branch*  ~$cost  elapsed
#   line 2 — pressure:   ctx used/max pct%  cache m:ss  [5h pct%  7d pct%]
# Runs locally, consumes no tokens.
#
# Cost is always prefixed with `~` because it's a client-side estimate against
# Anthropic's public price list — actual billing (subscription credits or
# proxy-brokered API spend) may differ.
#
# Args:
#   $1  profile name baked in by each settings template (e.g. "personal",
#       "work/polaris"). Drives the tag color. Defaults to "unknown".
#
# Env:
#   CLAUDE_STATUSLINE_RATELIMITS  on|off (default on). Set to off when
#       Claude Code talks through a proxy (e.g. LiteLLM) that strips the
#       Anthropic rate-limit headers, so the 5h/7d segments would otherwise
#       sit at 0% and mislead.

set -uo pipefail

PROFILE="${1:-unknown}"
STATE_FILE="$HOME/.claude/.statusline_state"
CACHE_TTL_S=300   # Anthropic default prompt-cache TTL (5 min)

# ANSI color codes are deliberate (not 24-bit truecolor): the local terminal
# theme — catppuccin mocha here — remaps them, so the statusline inherits the
# active palette automatically without hard-coding hex values.
BOLD=$'\033[1m'
DIM=$'\033[2m'
RESET=$'\033[0m'
RED=$'\033[1;31m'
GREEN=$'\033[1;32m'
YELLOW=$'\033[1;33m'
MAGENTA=$'\033[1;35m'
CYAN=$'\033[1;36m'

case "$PROFILE" in
  personal) TAG_COLOR="$GREEN" ;;
  work/*)   TAG_COLOR="$YELLOW" ;;
  *)        TAG_COLOR="$BOLD" ;;
esac

# --- Icons (nerd-font) -------------------------------------------------------
# Set CLAUDE_STATUSLINE_ICONS=0 to fall back to text labels. Default on; the
# off path matters when the local terminal isn't using a nerd font (icons
# would render as tofu boxes), or when piping the statusline somewhere
# log-grep-friendly. Only the genuinely-clarifying labels (ctx, cache) get
# replaced — branch icon is decorative on top of the branch name.
if [[ "${CLAUDE_STATUSLINE_ICONS:-1}" == "1" ]]; then
  # UTF-8 byte escapes (not \uXXXX) so this works on macOS's stock bash 3.2,
  # which doesn't expand \u in $'...'. Each glyph is from a nerd-font (any
  # patched font set; JetBrainsMono Nerd Font is the one we install).
  ICON_GIT=$'\xee\x9c\xa5 '            # U+E725  nf-dev-git_branch
  CTX_LABEL=$'\xef\x82\x80  '          # U+F080  nf-fa-bar_chart
  CACHE_LABEL=$'\xef\x80\x97  '        # U+F017  nf-fa-clock_o
else
  ICON_GIT=''
  CTX_LABEL='ctx '
  CACHE_LABEL='cache '
fi

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
    ((.context_window.context_window_size // 200000) * (.context_window.used_percentage // 0) / 100),
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
    DIRTY=""
    if [[ -n "$(git -C "$CWD" --no-optional-locks status --porcelain 2>/dev/null | head -c1)" ]]; then
      DIRTY="*"
    fi
    # Branch always yellow (catppuccin yellow under mocha) — `*` carries the
    # dirty signal so the color stays stable across clean/dirty transitions.
    GIT_STR="${YELLOW}${ICON_GIT}${BRANCH}${DIRTY}${RESET}"
  fi
fi

# --- Pressure colors ---------------------------------------------------------
if   (( PCT >= 80 )); then CTX_COLOR="$RED"
elif (( PCT >= 50 )); then CTX_COLOR="$YELLOW"
else                       CTX_COLOR="$CYAN"
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

COST_H=$(awk -v c="$COST" 'BEGIN{ printf "~$%.2f", c+0 }')

DUR_S=$((DUR_MS / 1000))
DUR_H=$(printf '%dm%02ds' $((DUR_S / 60)) $((DUR_S % 60)))

# --- Render ------------------------------------------------------------------
line1="${TAG_COLOR}[${PROFILE}]${RESET} ${MAGENTA}${MODEL}${RESET}"
[[ -n "$GIT_STR" ]] && line1="${line1}  ${GIT_STR}"
line1="${line1}  ${GREEN}${COST_H}${RESET}  ${DIM}${DUR_H}${RESET}"

line2="${CTX_COLOR}${CTX_LABEL}${USED_H}/${MAX_H} ${PCT}%${RESET}"
line2="${line2}  ${CACHE_COLOR}${CACHE_LABEL}${CACHE_STR}${RESET}"
if [[ "${CLAUDE_STATUSLINE_RATELIMITS:-on}" == "on" ]]; then
  line2="${line2}  ${RL5_COLOR}5h ${RL5}%${RESET}  ${RL7_COLOR}7d ${RL7}%${RESET}"
fi

printf '%s\n%s' "$line1" "$line2"

# --- iTerm2 pane badge ------------------------------------------------------
# Pane-corner overlay visible even when Claude Code is fullscreen or when the
# user has switched to another tmux pane. Kept deliberately minimal — just
# the cache countdown, optionally prefixed with a 4-char event token (perm,
# idle, done) read from a state file written by notify.sh. Profile, ctx,
# cost are intentionally omitted: they're already in the statusline below
# and would just clutter the badge.
#
# State file uses mtime as TTL: notify.sh drops the file on each event;
# statusline ignores entries older than NOTIFY_TTL_S so the badge auto-
# clears once the user has had time to react. No explicit "clear" hook
# required, which keeps notify.sh simple.
NOTIFY_TTL_S=60
if [[ "${TERM_PROGRAM:-}" == "iTerm.app" || "${LC_TERMINAL:-}" == "iTerm2" ]]; then
  reason=""
  reason_file="$HOME/.claude/.notify_reason"
  if [[ -r "$reason_file" ]]; then
    # macOS uses `stat -f %m`, GNU stat (Linux) uses `stat -c %Y`. Try both.
    file_mtime=$(stat -f %m "$reason_file" 2>/dev/null || stat -c %Y "$reason_file" 2>/dev/null || echo 0)
    if (( NOW - file_mtime < NOTIFY_TTL_S )); then
      reason=$(head -c 8 "$reason_file" | tr -d '[:space:]')
    fi
  fi
  if [[ -n "$reason" ]]; then
    badge=$(printf '%s %s' "$reason" "$CACHE_STR")
  else
    badge="$CACHE_STR"
  fi
  badge_b64=$(printf '%s' "$badge" | base64 | tr -d '\n')
  { printf '\e]1337;SetBadgeFormat=%s\a' "$badge_b64" >/dev/tty; } 2>/dev/null || true
fi
