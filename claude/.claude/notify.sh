#!/usr/bin/env bash
# Desktop notification dispatcher for Claude Code hooks.
# Usage: notify.sh <reason>
#   <reason> matches a Claude Code Notification matcher (idle_prompt,
#   permission_prompt, etc.) and selects the message text.
#
# Tiered delivery (best signal first, headless fallback last):
#   1. iTerm2 OSC sequences via /dev/tty — works locally AND over SSH (the
#      escape travels through the pty to the user's local iTerm2). Adds a
#      dock bounce + persistent pane badge on permission_prompt.
#   2. Native desktop notifier (osascript / notify-send + DBus check).
#   3. tmux display-message — works in any tmux session, no DBus needed.
#   4. stderr — last-resort log line so the event isn't lost entirely.

set -uo pipefail

REASON="${1:-unknown}"

case "$REASON" in
  idle_prompt)        TITLE="Claude Code"; MSG="waiting for input" ;;
  permission_prompt)  TITLE="Claude Code"; MSG="needs permission" ;;
  Stop)               TITLE="Claude Code"; MSG="finished" ;;
  *)                  TITLE="Claude Code"; MSG="$REASON" ;;
esac

is_iterm2() {
  # TERM_PROGRAM is set when iTerm2 is the local terminal. LC_TERMINAL is
  # iTerm2's own SSH-friendly variant — propagated when the client sends
  # LC_* (most ssh setups do) and the remote sshd accepts it.
  [[ "${TERM_PROGRAM:-}" == "iTerm.app" || "${LC_TERMINAL:-}" == "iTerm2" ]]
}

iterm_notify() {
  # Brace group + group-level 2>/dev/null so a missing controlling tty (which
  # bash reports before the redirected printf even runs) is swallowed instead
  # of leaking to the hook's stderr.
  {
    # OSC 9 ; text BEL → macOS Notification Center via iTerm2.
    printf '\e]9;%s: %s\a' "$TITLE" "$MSG" >/dev/tty
    # Permission prompts genuinely block the turn — bounce the dock and set
    # a persistent badge so the cue lasts until the user acts. The statusline
    # tick (every 5s) will eventually overwrite the badge, which is fine —
    # the dock bounce and notification have already done their job by then.
    if [[ "$REASON" == "permission_prompt" ]]; then
      printf '\e]1337;RequestAttention=yes\a' >/dev/tty
      local b64
      b64=$(printf 'perm needed' | base64 | tr -d '\n')
      printf '\e]1337;SetBadgeFormat=%s\a' "$b64" >/dev/tty
    fi
  } 2>/dev/null || true
}

native_notify() {
  case "$(uname -s)" in
    Darwin)
      local esc=${MSG//\"/\\\"}
      osascript -e "display notification \"$esc\" with title \"$TITLE\"" >/dev/null 2>&1
      ;;
    Linux)
      # notify-send needs DBus; on a headless box (SSH'd into a server) the
      # var is unset and the call would silently no-op. Skip explicitly so
      # the fallback chain progresses.
      [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]] && command -v notify-send >/dev/null 2>&1 \
        && notify-send "$TITLE" "$MSG"
      ;;
    *) return 1 ;;
  esac
}

tmux_notify() {
  [[ -n "${TMUX:-}" ]] && command -v tmux >/dev/null 2>&1 \
    && tmux display-message "$TITLE: $MSG"
}

if is_iterm2; then
  iterm_notify
  exit 0
fi
native_notify || tmux_notify || echo "[$TITLE] $MSG" >&2
exit 0
