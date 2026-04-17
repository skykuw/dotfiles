#!/usr/bin/env bash
# Pull the latest dotfiles and re-stow the claude package.
# Use this on the consumer machine (work) to pick up new skills, agents,
# or commands developed on the personal machine without re-running the full
# bootstrap. Safe to re-run.

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DOTFILES_DIR"

if ! command -v stow >/dev/null 2>&1; then
  echo "stow not found on PATH. Run bootstrap.sh first." >&2
  exit 1
fi

echo "==> Fetching latest from git"
git fetch --quiet

LOCAL="$(git rev-parse @)"
REMOTE="$(git rev-parse '@{u}' 2>/dev/null || true)"

if [[ -z "$REMOTE" ]]; then
  {
    echo "No upstream configured for the current branch. Set one with:"
    echo "  git branch --set-upstream-to=origin/main"
  } >&2
  exit 1
fi

if [[ "$LOCAL" == "$REMOTE" ]]; then
  echo "==> Already up to date"
else
  BEFORE="$LOCAL"
  echo "==> Pulling changes"
  git pull --ff-only

  echo "==> Claude package commits since last sync:"
  git --no-pager log --oneline "$BEFORE..HEAD" -- claude/ || true

  echo "==> Files changed under claude/:"
  git --no-pager diff --stat "$BEFORE..HEAD" -- claude/ || true
fi

echo "==> Re-stowing claude package"
stow --restow --target="$HOME" claude

echo "==> Done."
