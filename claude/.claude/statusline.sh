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
# Cache TTL state is per-session: multiple concurrent Claude Code sessions
# would otherwise clobber each other's state, making every tick look like a
# session mismatch and pinning the countdown at 5:00. Actual path is set
# after SESSION_ID is parsed below.
STATE_FILE=""
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
BLUE=$'\033[1;34m'
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
  ICON_DIR=$'\xef\x81\xbb '            # U+F07B  nf-fa-folder
  CTX_LABEL=$'\xef\x82\x80  '          # U+F080  nf-fa-bar_chart
  CACHE_LABEL=$'\xef\x80\x97  '        # U+F017  nf-fa-clock_o
else
  ICON_GIT=''
  ICON_DIR=''
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
  SESSION_ID MODEL CWD PCT USED MAX COST DUR_MS API_DUR_MS RL5 RL7 RL5_RESETS RL7_RESETS \
  CACHE_READ CACHE_CREATE INPUT_TOK LINES_ADD LINES_DEL \
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
    (.rate_limits.seven_day.used_percentage // 0),
    (.rate_limits.five_hour.resets_at // ""),
    (.rate_limits.seven_day.resets_at // ""),
    (.context_window.current_usage.cache_read_input_tokens // 0),
    (.context_window.current_usage.cache_creation_input_tokens // 0),
    (.context_window.current_usage.input_tokens // 0),
    (.cost.total_lines_added // 0),
    (.cost.total_lines_removed // 0)
  ] | @tsv' <<<"$INPUT" 2>/dev/null
)"

PCT="${PCT%%.*}"; PCT="${PCT:-0}"
USED="${USED%%.*}"; USED="${USED:-0}"
MAX="${MAX%%.*}"; MAX="${MAX:-200000}"
DUR_MS="${DUR_MS%%.*}"; DUR_MS="${DUR_MS:-0}"
API_DUR_MS="${API_DUR_MS%%.*}"; API_DUR_MS="${API_DUR_MS:-0}"
RL5="${RL5%%.*}"; RL5="${RL5:-0}"
RL7="${RL7%%.*}"; RL7="${RL7:-0}"
CACHE_READ="${CACHE_READ%%.*}"; CACHE_READ="${CACHE_READ:-0}"
CACHE_CREATE="${CACHE_CREATE%%.*}"; CACHE_CREATE="${CACHE_CREATE:-0}"
INPUT_TOK="${INPUT_TOK%%.*}"; INPUT_TOK="${INPUT_TOK:-0}"
LINES_ADD="${LINES_ADD%%.*}"; LINES_ADD="${LINES_ADD:-0}"
LINES_DEL="${LINES_DEL%%.*}"; LINES_DEL="${LINES_DEL:-0}"
MODEL="${MODEL:-?}"
COST="${COST:-0}"

# --- Cache TTL tracking ------------------------------------------------------
# refreshInterval re-runs us every N seconds during idle. We must distinguish
# a refresh tick from a real API call so the countdown only resets when the
# cache was actually refreshed. total_api_duration_ms is monotonic across API
# calls within a session — when it changes, a new API call happened.

NOW=$(date +%s)
STATE_FILE="$HOME/.claude/.statusline_state.${SESSION_ID:-unknown}"
PREV_API_DUR=-1; PREV_TS="$NOW"
if [[ -r "$STATE_FILE" ]]; then
  read -r PREV_API_DUR PREV_TS < "$STATE_FILE" || true
fi

if [[ "$API_DUR_MS" != "$PREV_API_DUR" ]]; then
  LAST_API_TS="$NOW"
  printf '%s %s\n' "$API_DUR_MS" "$NOW" >"$STATE_FILE" 2>/dev/null || true
else
  LAST_API_TS="$PREV_TS"
fi

# Opportunistic cleanup: drop per-session state files older than 1 day so the
# .claude dir doesn't accumulate one entry per historical session forever.
# Runs at most every 10 min (gated by age of a sentinel file) to keep the
# 5-second tick cheap.
CLEANUP_SENTINEL="$HOME/.claude/.statusline_state.cleanup"
if [[ ! -f "$CLEANUP_SENTINEL" ]] || (( NOW - $(stat -f %m "$CLEANUP_SENTINEL" 2>/dev/null || stat -c %Y "$CLEANUP_SENTINEL" 2>/dev/null || echo 0) > 600 )); then
  find "$HOME/.claude" -maxdepth 1 -name '.statusline_state.*' -type f -mtime +1 -delete 2>/dev/null || true
  : > "$CLEANUP_SENTINEL" 2>/dev/null || true
fi

REMAINING=$((CACHE_TTL_S - (NOW - LAST_API_TS)))
# Same 4-tier ramp as rate limits (green→cyan→yellow→red). Cache is 5 min
# total, so the warn band covers the last minute when you can still squeeze
# in a cache-hitting turn; below that it's already effectively cold.
if   (( REMAINING >= 180 )); then CACHE_COLOR="$GREEN"
elif (( REMAINING >=  60 )); then CACHE_COLOR="$CYAN"
elif (( REMAINING >    0 )); then CACHE_COLOR="$YELLOW"
else                              CACHE_COLOR="$RED"
fi
if (( REMAINING > 0 )); then
  CACHE_STR=$(printf '%d:%02d' $((REMAINING / 60)) $((REMAINING % 60)))
else
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
    fi
    # Branch always yellow (catppuccin yellow under mocha) — `*` carries the
    # dirty signal so the color stays stable across clean/dirty transitions.
    GIT_STR="${YELLOW}${ICON_GIT}${BRANCH}${DIRTY}${RESET}"
  fi
fi

# --- Pressure colors ---------------------------------------------------------
# Aggressive ramp: cyan <10%, yellow 10–14%, red ≥15%. Even 15% of a 1M
# window is 150k tokens — large enough that compaction risk and per-turn
# cost are already worth flagging early.
if   (( PCT >= 15 )); then CTX_COLOR="$RED"
elif (( PCT >= 10 )); then CTX_COLOR="$YELLOW"
else                       CTX_COLOR="$CYAN"
fi

rl_color() {
  # 4-tier: green <30, cyan 30–59, yellow 60–79, red ≥80. Mirrors the cache
  # timer ramp so both bottom-line signals use the same visual language.
  local v="$1"
  if   (( v >= 80 )); then printf '%s' "$RED"
  elif (( v >= 60 )); then printf '%s' "$YELLOW"
  elif (( v >= 30 )); then printf '%s' "$CYAN"
  else                     printf '%s' "$GREEN"
  fi
}
RL5_COLOR=$(rl_color "$RL5")
RL7_COLOR=$(rl_color "$RL7")

# Compact duration until a reset timestamp: 2d3h / 4h23m / 45m / 30s.
# Empty for missing, unparseable, or past timestamps — caller falls back to
# pct-only rendering. Accepts either Unix epoch seconds (what Claude Code
# actually sends as of 2.1.116) or ISO 8601 (per the 2.1.80 changelog, in
# case the format changes back).
fmt_remaining() {
  local raw="$1"
  [[ -z "$raw" ]] && return 0
  local epoch=""
  if [[ "$raw" =~ ^[0-9]+$ ]]; then
    epoch="$raw"
  else
    # Strip fractional seconds (".123") and trailing Z; BSD date -j -f can't
    # parse them with the format below.
    local clean="${raw%.*}"
    clean="${clean%Z}"
    if ! epoch=$(date -u -j -f "%Y-%m-%dT%H:%M:%S" "$clean" "+%s" 2>/dev/null); then
      epoch=$(date -u -d "$raw" "+%s" 2>/dev/null)
    fi
  fi
  [[ -z "$epoch" ]] && return 0
  local delta=$(( epoch - NOW ))
  (( delta <= 0 )) && return 0
  if   (( delta >= 86400 )); then
    printf '%dd%dh' $(( delta / 86400 )) $(( (delta % 86400) / 3600 ))
  elif (( delta >= 3600 )); then
    printf '%dh%dm' $(( delta / 3600 )) $(( (delta % 3600) / 60 ))
  elif (( delta >= 60 )); then
    printf '%dm' $(( delta / 60 ))
  else
    printf '%ds' "$delta"
  fi
}
RL5_LEFT=$(fmt_remaining "$RL5_RESETS")
RL7_LEFT=$(fmt_remaining "$RL7_RESETS")

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

# Cache hit ratio for the current turn: how much of the model's input was
# served from the prompt cache vs. built fresh / sent as new input. High is
# good (cheap turn). Empty when the denominator is 0 (no input yet).
CACHE_HIT_STR=""
CACHE_HIT_DENOM=$(( CACHE_READ + CACHE_CREATE + INPUT_TOK ))
if (( CACHE_HIT_DENOM > 0 )); then
  CACHE_HIT_STR=$(( CACHE_READ * 100 / CACHE_HIT_DENOM ))"%"
fi

# Session churn: +added/-removed, green/red like git diff --stat. Suppressed
# when nothing has been edited yet so a fresh session stays clean.
LINES_STR=""
if (( LINES_ADD > 0 || LINES_DEL > 0 )); then
  LINES_STR="${GREEN}+${LINES_ADD}${RESET}${DIM}/${RESET}${RED}-${LINES_DEL}${RESET}"
fi

# Compact cwd: $HOME → ~, then if still > 30 chars shrink to …/<last two>.
# Keeps the identity line narrow without losing the leaf directory name,
# which is what actually tells you where you're working.
CWD_H=""
if [[ -n "$CWD" ]]; then
  if [[ "$CWD" == "$HOME" ]]; then
    CWD_H="~"
  elif [[ "$CWD" == "$HOME"/* ]]; then
    CWD_H="~${CWD#"$HOME"}"
  else
    CWD_H="$CWD"
  fi
  if (( ${#CWD_H} > 30 )); then
    parent="${CWD_H%/*}"
    parent_base="${parent##*/}"
    leaf="${CWD_H##*/}"
    CWD_H="…/${parent_base}/${leaf}"
  fi
fi

# --- Render ------------------------------------------------------------------
line1="${TAG_COLOR}[${PROFILE}]${RESET} ${MAGENTA}${MODEL}${RESET}"
[[ -n "$CWD_H" ]] && line1="${line1}  ${BLUE}${ICON_DIR}${CWD_H}${RESET}"
[[ -n "$GIT_STR" ]] && line1="${line1}  ${GIT_STR}"
line1="${line1}  ${GREEN}${COST_H}${RESET}  ${DIM}${DUR_H}${RESET}"
[[ -n "$LINES_STR" ]] && line1="${line1}  ${LINES_STR}"

line2="${CTX_COLOR}${CTX_LABEL}${USED_H}/${MAX_H} ${PCT}%${RESET}"
cache_seg="${CACHE_COLOR}${CACHE_LABEL}${CACHE_STR}${RESET}"
[[ -n "$CACHE_HIT_STR" ]] && cache_seg="${cache_seg} ${DIM}${CACHE_HIT_STR}${RESET}"
line2="${line2}  ${cache_seg}"
if [[ "${CLAUDE_STATUSLINE_RATELIMITS:-on}" == "on" ]]; then
  rl5_seg="${RL5_COLOR}5h ${RL5}%${RESET}"
  [[ -n "$RL5_LEFT" ]] && rl5_seg="${rl5_seg} ${DIM}${RL5_LEFT}${RESET}"
  rl7_seg="${RL7_COLOR}7d ${RL7}%${RESET}"
  [[ -n "$RL7_LEFT" ]] && rl7_seg="${rl7_seg} ${DIM}${RL7_LEFT}${RESET}"
  line2="${line2}  ${rl5_seg}  ${rl7_seg}"
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
